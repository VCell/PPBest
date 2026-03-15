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

function SearchInterface:InitState()
    for player = 1, 2 do
        local team_state = Play.TeamState.new()
        for pet_index = 1,3 do
            local health = C_PetBattles.GetHealth(player, pet_index)
            local pet_state = Play.PetState.new(health)
            table.insert(team_state.pets, pet_state)
            local aura_count = C_PetBattles.GetNumAuras(player, pet_index)
            for aura_index = 1, aura_count do
                local aura_id, _, duration = C_PetBattles.GetAuraInfo(player, pet_index, aura_index)
                local aura = AI.Aura.new_aura_by_id(aura_id, 280)
                aura.duration = duration
                if aura then
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
                    local _, _, _, cooldown, _, _, _ = C_PetBattles.GetAbilityInfo(player, ab_index)
                    local ability = team_state.pets[ab_index].abilitys[1]
                    if ability then
                        ability.cooldown = cooldown
                    end
                    LogFrame:AddLog(string.format("宠物%d技能%d冷却: %d",pet_index, ab_index, ability.cooldown))
                end
            end
        end
        
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

function SearchInterface:search(result_callback)
    if not self.game then
        print("未初始化游戏规则")
        return
    end
    local searcher = AI.Searcher.new(self.game)
    local best_action = searcher:search()
    result_callback(best_action)
    
end

PPBest.SearchInterface = SearchInterface