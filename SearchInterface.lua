local _, PPBest = ...
local AI = PPBest.AI
local LogFrame = PPBest.LogFrame
local StateFrame = PPBest.StateFrame
local BattleUtils = PPBest.BattleUtils
local PetCombatLog = PPBest.PetCombatLog
local PetCombatLogType = PPBest.PetCombatLogType
local Explain = PPBest.AI.Explain

local SearchInterface = {
    game = nil,
    last_enemy_ability_round = 0,
}

-- 根据宠物ID设置可能的技能组合（用于敌方宠物）
local function set_possible_abilitys(pet)
    if pet.id == AI.PetID.SPRING_RABBIT or pet.id == AI.PetID.MOUNTAIN_COTTONTAIL or
             pet.id == AI.PetID.TOLAI_HARE_PUP or pet.id == AI.PetID.TOLAI_HARE  then 
        pet:install_ability_by_id(AI.AbilityID.FLURRY, 1)  -- 乱舞
        pet:install_ability_by_id(AI.AbilityID.DODGE, 2)   -- 闪避
        pet:install_ability_by_id(AI.AbilityID.BURROW, 3)  -- 钻地
    elseif pet.id == AI.PetID.PEBBLE then
        pet:install_ability_by_id(AI.AbilityID.STONE_SHOT, 1)   -- 投石
        pet:install_ability_by_id(AI.AbilityID.RUPTURE, 2)    -- 割裂
        pet:install_ability_by_id(AI.AbilityID.ROCK_BARRAGE, 3)     -- 岩石弹幕
    elseif pet.id == AI.PetID.UNBORN_VALKYR then
        pet:install_ability_by_id(AI.AbilityID.SHADOW_SHOCK, 1) 
        pet:install_ability_by_id(AI.AbilityID.CURSE_OF_DOOM, 2) 
        pet:install_ability_by_id(AI.AbilityID.HAUNT, 3) 
    elseif pet.id == AI.PetID.ARFUS then 
        pet:install_ability_by_id(AI.AbilityID.BONE_BITE, 1) 
        pet:install_ability_by_id(AI.AbilityID.ARFUS_2, 2) 
        pet:install_ability_by_id(AI.AbilityID.SPRINT, 3) 
    else 
        local abilitys = BattleUtils:GetAbilitysByPetID(pet.id)
        if abilitys then
            for ab_index = 1,3 do
                pet:install_ability_by_id(abilitys[ab_index], ab_index)
                if not pet:get_ability(ab_index) then
                    pet:install_ability_by_id(abilitys[ab_index + 3], ab_index)
                end
            end
        end
    end
end

-- 获取队伍信息
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

                local ability = pet:install_ability_by_id(ab_id, ab_index)
                if ability then
                    assert(ability.cooldown == cooldown, string.format("技能%d冷却不匹配: %d vs %d", ab_id, ability.cooldown, cooldown))
                    assert(ability.duration == turns or (ability.duration == 0 and turns == 1), 
                            string.format("技能%d持续回合数不匹配: %d vs %d", ab_id, ability.turns, turns))
                    assert(ability.type == ab_type, string.format("技能%d类型不匹配: %d vs %d", ab_id, ability.type, ab_type))
                else 
                    LogFrame:AddLog(string.format("未知技能：玩家%d 宠物%d 技能%d id:%d", player,i,ab_index, ab_id))
                end
            end
        else
            set_possible_abilitys(pet)
        end
        pet:install_default_ability()
        table.insert(team, pet)
        LogFrame:AddLog(string.format("玩家%d 宠物%d 技能1:%d 技能2:%d 技能3:%d", player, i,
                pet:get_ability(1).id, pet:get_ability(2).id, pet:get_ability(3).id))
        
    end
    return team
end

-- 初始化游戏规则（只在开局调用一次）
function SearchInterface:InitGame()
    if not C_PetBattles.IsInBattle() then
        return false
    end
    self.game = AI.Game.new()
    self.game.Rule.teams = {
        get_team(LE_BATTLE_PET_ALLY),
        get_team(LE_BATTLE_PET_ENEMY)
    }
   self.game.State.round = 0
    for player = 1, 2 do
        local team_state = AI.TeamState.new()
        for pet_index = 1,3 do
            local health = C_PetBattles.GetHealth(player, pet_index)
            local pet_state = AI.PetState.new(health)
            table.insert(team_state.pets, pet_state)
        end
        team_state.active_index = C_PetBattles.GetActivePet(player) --？
        self.game.State.team_states[player] = team_state
    end
    self.last_enemy_ability_round = 0
    LogFrame:AddLog("SearchInterface: 游戏队伍初始化完成")
    return true
end

-- 更新血量信息（每回合调用）
function SearchInterface:UpdateHealth()
    for player = 1, 2 do
        for pet_index = 1, 3 do
            local health = C_PetBattles.GetHealth(player, pet_index)
            self.game.State.team_states[player].pets[pet_index].current_health = health
            if health > 0 then
                self.game.State.team_states[player].pets[pet_index].tmp_health = nil
            end
            --LogFrame:AddLog(string.format("玩家%d 宠物%d 血量更新为%d", player, pet_index, health))
        end
    end
end

-- 更新活跃宠物索引
function SearchInterface:UpdateActivePet()
    for player = 1, 2 do
        local active_index = C_PetBattles.GetActivePet(player)
        if self.game.State.team_states[player] then
            if self.game.State.team_states[player].active_index ~= active_index then
                self.game.State:change_pet(self.game.Rule.teams, player, active_index)
            end
        end
    end
end

-- 更新技能冷却（仅己方）
function SearchInterface:UpdateCooldowns(round)
    for pet_index = 1, 3 do
        for ab_index = 1, 3 do
            local _, cooldown = C_PetBattles.GetAbilityState(LE_BATTLE_PET_ALLY, pet_index, ab_index)
            if self.game.State.team_states[LE_BATTLE_PET_ALLY].pets[pet_index] then
                self.game.State.team_states[LE_BATTLE_PET_ALLY].pets[pet_index].cooldown_at[ab_index] = round + cooldown - 1
            end
        end
    end
end

function SearchInterface:CleanExpiredAuras()
    --调用的时机是回合开始，因此只移除aura.expire<round的光环,保留aura.expire=round的光环
    for player = 1, 2 do
        local team_state = self.game.State.team_states[player]
        if team_state then
            for aura_id, aura in pairs(team_state.active_auras) do
                if aura.expire < self.game.State.round then
                    team_state.active_auras[aura_id] = nil
                    LogFrame:AddLog(string.format("移除队伍光环: player=%d, aura_id=%d", player, aura_id))
                end
            end
            for pet_index = 1, 3 do
                for aura_id, aura in pairs(team_state.pets[pet_index].auras) do
                    if aura.expire < self.game.State.round then
                        team_state.pets[pet_index].auras[aura_id] = nil
                        LogFrame:AddLog(string.format("移除宠物光环: player=%d, pet=%d, aura_id=%d", player, pet_index, aura_id))
                    end
                end
            end
        end
    end
end

function SearchInterface:UpdateRound(round)
    self.game.State.round = round
    StateFrame:SetState(Explain.getGameStateInfo(self.game.State, self.game.Rule.teams))
end

function SearchInterface:UpdateState(round)
    self.game.State.round = round
    self.game.State.change_round = 0
    self:UpdateActivePet() -- 变更宠物有可能触发伤害，最先计算避免bug
    self:UpdateHealth()
    self:UpdateCooldowns(round)
    self:CleanExpiredAuras()
end

function SearchInterface:UpdateEnemyAbilityState(pet_index, ab_index, round)
    if not round then 
        round = 1
    end
    if round <= self.last_enemy_ability_round then
        return
    end

    local ability = self.game.Rule.teams[LE_BATTLE_PET_ENEMY][pet_index].abilitys[ab_index]
    if not ability then
        return
    end
    local team_state = self.game.State.team_states[LE_BATTLE_PET_ENEMY]
    if team_state.ability_round > 1 then
            -- 多轮技能逻辑
        assert(ab_index == team_state.ability_index)
        team_state.ability_round = team_state.ability_round + 1
        if team_state.ability_round > ability.duration then
            team_state.ability_round = 0
            team_state.ability_index = 0
        end
    else
        if ability.duration > 1 then
            team_state.ability_round = 2
            team_state.ability_index = ab_index
        end
    end
    LogFrame:AddLog(string.format("敌方宠物%d技能%d 第%d轮", pet_index, ab_index, team_state.ability_round))

    team_state.pets[team_state.active_index].cooldown_at[ab_index] = self.game.State.round + ability.cooldown
end

function SearchInterface:GuessEnemyAbility(log)
    local abid = log.abilityInfo1.id
    local ally_index = self.game.State.team_states[LE_BATTLE_PET_ALLY].active_index
    local enemy_index = self.game.State.team_states[LE_BATTLE_PET_ENEMY].active_index
    local enemy_pet = self.game.Rule.teams[LE_BATTLE_PET_ENEMY][enemy_index]
    local ally_pet = self.game.Rule.teams[LE_BATTLE_PET_ALLY][ally_index]
    local abilitys = BattleUtils:GetAbilitysByPetID(enemy_pet.id)
    if not abilitys then
        return
    end
    local enemy_has, ally_has = false, false
    local ab_index = 0

    for i, ability in ipairs(abilitys) do 
        if ability == abid then
            enemy_has = true
            ab_index = i
        end
    end
    if not enemy_has then
        return
    end
    for i = 1,3 do
        if ally_pet.abilitys[i].id == abid then
            ally_has = true
        end
    end
    if not ally_has then
        if ab_index > 3 then
            ab_index = ab_index - 3
        end
        if enemy_pet.abilitys[ab_index].id == abid then
            enemy_pet.abilitys[ab_index].certain = true
            self:UpdateEnemyAbilityState(enemy_index, ab_index, self.game.State.round)
            return 
        end
        assert(not enemy_pet.abilitys[ab_index].certain)
        local ability = enemy_pet:install_ability_by_id(abid, ab_index)
        if ability then
            LogFrame:AddLog(string.format("确定敌方宠物%d 技能%d 为 %d", enemy_index, ab_index, abid))
            ability.certain = true
            self:UpdateEnemyAbilityState(enemy_index, ab_index)
        end

    end

end

function SearchInterface:ProcessCombatLog(msg)
    if not self.game then
        return
    end
    local state = self.game.State
    local log = PetCombatLog.Parse(msg)
    if log == nil then
        return
    end

    --添加光环
    if log.type == PetCombatLogType.AURA then 
        assert(log.abilityInfo2)
        assert(log.target == LE_BATTLE_PET_ALLY or log.target == LE_BATTLE_PET_ENEMY)
        local from_index = C_PetBattles.GetActivePet(3-log.target)
        local target_index = C_PetBattles.GetActivePet(log.target)
        local aura = AI.Aura.new_aura_by_id(log.abilityInfo2.id, log.abilityInfo2.power, from_index)
        if aura then 
            state:install_aura(self.game.Rule.teams, log.target, target_index, aura)
            LogFrame:AddLog(string.format("添加宠物光环: player=%d, pet=%d, aura_id=%d，expire=%d", log.target, target_index, aura.id, aura.expire))
            if aura.id == AI.AuraID.HAUNT then
                --添加鬼影缠身时处理假死状态
                local pet = state.team_states[3-log.target].pets[from_index]
                if AI.AuraProcessor.get_aura_by_id(state, 3-log.target, from_index, AI.AuraID.UNDEAD) ~= nil then
                    pet.tmp_health = 0
                else 
                    pet.tmp_health = log.abilityInfo2.health
                end
            end
        else 
            LogFrame:AddLog(string.format("未知光环: player=%d, pet=%d, aura_id=%d", log.target, target_index, log.abilityInfo2.id))
        end
    elseif log.type == PetCombatLogType.WEATHER then
        local weather = AI.Aura.new_aura_by_id(log.abilityInfo2.id, log.abilityInfo2.power)
        if weather then
            state:install_weather(weather)
            LogFrame:AddLog(string.format("安装天气: %d", weather.id))
        else 
            LogFrame:AddLog(string.format("未知天气: %d", log.abilityInfo2.id))
        end
    elseif log.type == PetCombatLogType.BLOCK then
        assert(log.target == LE_BATTLE_PET_ALLY or log.target == LE_BATTLE_PET_ENEMY)
        local pets = self.game.State.team_states[log.target].pets
        for index, pet in pairs(pets) do
            for aura_id, aura in pairs(pet.auras) do
                if aura.type == AI.AuraType.BLOCK then
                    aura.value = aura.value - 1
                    LogFrame:AddLog(string.format("玩家%d 宠物%d 消耗一次格挡，剩余：%d", log.target, index, aura.value))
                end
            end
        end
    end
    if log.abilityInfo1 then
        self:GuessEnemyAbility(log)
    end
end


-- 设置换人状态
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
        if change_round > 0 then
            self.game.State.change_round = change_round
        end
    end
end

-- 决定行动
function SearchInterface:DecideActions(round)
    if not self.game then
        print("未初始化游戏规则")
        return
    end

    local root = AI.DUCT_MCTS.Searcher.run_search(self.game.State, self.game.Rule, {
                iterations = 3000,
                exploration_c = 1.414,
            })
    local action, info = AI.DUCT_MCTS.Searcher.select_best_action(root, LE_BATTLE_PET_ALLY)

    for _, line in ipairs(info) do
        LogFrame:AddLog(string.format("DUCT_MCTS %d  %s", round, line))
    end
    return action
end

PPBest.SearchInterface = SearchInterface