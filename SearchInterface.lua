local _, PPBest = ...
local AI = PPBest.AI
local LogFrame = PPBest.LogFrame
local SearchInterface = {
    game = nil,
}

local function get_team(player) 
    local team = {}
    local count = C_PetBattles.GetNumPets(player)
    assert (count == 3, "每队必须有3只宠物")
    for i=1,3 do
        local id = C_PetBattles.GetPetSpeciesID(player, i)
        local health = C_PetBattles.GetMaxHealth(player, i)
        local power = C_PetBattles.GetPower(player, i)
        local speed = C_PetBattles.GetSpeed(player, i)
        local type = C_PetBattles.GetPetType(player, i)
        local pet = AI.Pet.new(id, health, power, speed, type)
        --pvp中己方可以获取ability，敌方没有
        if player == LE_BATTLE_PET_ALLY then
            for ab_index = 1,3 do
                local ab_id, _, _, cooldown, _, turns, ab_type = C_PetBattles.GetAbilityInfo(player, i, ab_index)
                local ability = pet:install_ability_by_id(ab_id, i)
                if ability then
                    assert(ability.cooldown == cooldown, string.format("技能%d冷却不匹配: %d vs %d", ab_id, ability.cooldown, cooldown))
                    assert(ability.duration == turns or (ability.duration == 0 and turns == 1), 
                            string.format("技能%d持续回合数不匹配: %d vs %d", ab_id, ability.turns, turns))
                    assert(ability.type == ab_type, string.format("技能%d类型不匹配: %d vs %d", ab_id, ability.type, ab_type))

                end
            end
        end
        if pet.abilitys[1] == nil then
            pet:install_default_ability()
        end
        table.insert(team, pet)
    end
    return team
end

function SearchInterface:InitRule()
    if not C_PetBattles.IsInBattle() then
        return false
    end
    self.game = AI.Game.new()
    self.game.Rule.teams = {
        get_team(LE_BATTLE_PET_ALLY),
        get_team(LE_BATTLE_PET_ENEMY)
    }
end

function SearchInterface:InitState(round)
    self.game.State.round = round
    for player = 1, 2 do
        local team_state = AI.TeamState.new()
        for pet_index = 1,3 do
            local health = C_PetBattles.GetHealth(player, pet_index)
            local pet_state = AI.PetState.new(health)
            table.insert(team_state.pets, pet_state)
            local aura_count = C_PetBattles.GetNumAuras(player, pet_index)
            for aura_index = 1, aura_count do
                local aura_id, _, duration = C_PetBattles.GetAuraInfo(player, pet_index, aura_index)
                LogFrame:AddLog(string.format("宠物%d aura:%d duration:%d",pet_index, aura_id, duration))
                local aura = AI.Aura.new_aura_by_id(aura_id, 280)
                if aura then
                    aura.duration = duration
                    if aura.keep_front then
                        team_state.active_auras[aura_id] = aura
                    else
                        pet_state.auras[aura_id] = aura
                    end
                end
            end
            --获取技能cd情况
            if player == LE_BATTLE_PET_ALLY then
                for ab_index = 1,3 do
                    local _, cooldown = C_PetBattles.GetAbilityState(player,pet_index, ab_index)
                    -- local ability = team_state.pets[ab_index].abilitys[1]
                    -- if ability then
                    --     ability.cooldown = cooldown
                    -- end
                    LogFrame:AddLog(string.format("宠物%d技能%d冷却: %d",pet_index, ab_index, cooldown))
                end
            end
        end
        self.game.State.team_states[player] = team_state
    end

    local weather_id, _, duration = C_PetBattles.GetAuraInfo(LE_BATTLE_PET_WEATHER, 0, 1)
    if weather_id then
        local weather = AI.Aura.new_aura_by_id(weather_id, 280)
        weather.duration = duration
        if weather then
            self.game.State.weather = weather
        end
        LogFrame:AddLog(string.format("天气: %s, 持续回合数: %d", weather.name, weather.duration))
    end
  
end

function SearchInterface:SetChangePetState(round)
    if round == 0 then 
        --开局先选人
        self.game.State.change_round = 3
    else
        local change_round = 0
        for player = 1, 2 do
            local active = C_PetBattles.GetActivePet(player)
            if C_PetBattles.GetHealth(player, active) <= 0 then
                change_round = player + change_round
            end
        end
        if not change_round then
            self.game.State.change_round = round
        end
    end
end

function SearchInterface:DecideActions()
    if not self.game then
        print("未初始化游戏规则")
        return
    end
    local root = AI.DUCT_MCTS.Searcher.run_search(self.game.State, self.game.Rule, {
                iterations = 500,
                exploration_c = 1.414,
            })
    local acction, info = AI.DUCT_MCTS.Searcher.select_best_action(root, LE_BATTLE_PET_ALLY)
    for _, line in ipairs(info) do
        LogFrame:AddLog(string.format("DUCT_MCTS %d  %s", round, line))
    end
    return acction
end

PPBest.SearchInterface = SearchInterface