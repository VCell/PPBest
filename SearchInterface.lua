local _, PPBest = ...
local AI = PPBest.AI
local LogFrame = PPBest.LogFrame
local BattleUtils = PPBest.BattleUtils
local SearchInterface = {
    game = nil,
    enemy_ability_hints = {}, -- 存储敌方技能使用记录 {pet_index = {ability_id = count}}
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
    LogFrame:AddLog("SearchInterface: 游戏队伍初始化完成")
    return true
end

-- 更新血量信息（每回合调用）
function SearchInterface:UpdateHealth()
    for player = 1, 2 do
        for pet_index = 1, 3 do
            local health = C_PetBattles.GetHealth(player, pet_index)
            self.game.State.team_states[player].pets[pet_index].current_health = health
        end
    end
end

-- 更新活跃宠物索引
function SearchInterface:UpdateActivePet()
    for player = 1, 2 do
        local active_index = C_PetBattles.GetActivePet(player)
        if self.game.State.team_states[player] then
            self.game.State.team_states[player].active_index = active_index
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

function SearchInterface:UpdateState(round)
    self.game.State.round = round
    self.game.State.change_round = 0
    self:UpdateHealth()
    self:UpdateActivePet()
    self:UpdateCooldowns(round)
    self:CleanExpiredAuras()
end

-- 处理战斗日志消息
-- 格式示例: "|T136122:14|t|cff4e96f7|HbattlePetAbil:218:1806:276:227|h[厄运诅咒]|h|r对敌方的 |T646059:14|t超能浣熊 造成了|T136122:14|t|cff4e96f7|HbattlePetAbil:217:1806:276:227|h[厄运诅咒]|h|r效果."
function SearchInterface:ProcessCombatLog(msg)
    if not self.game then
        return
    end
    local state = self.game.State
    -- 提取技能信息
    -- 格式: |HbattlePetAbil:ability_id:health:power:speed|h[skill_name]|h|r
    local ab_info = {}
    for ability_id, health, power, speed in msg:gmatch("|HbattlePetAbil:(%d+):(%d+):(%d+):(%d+)|h") do
        ability_id = tonumber(ability_id)
        health = tonumber(health)
        power = tonumber(power)
        speed = tonumber(speed)
        table.insert(ab_info, {
            ability_id = ability_id,
            health = health,
            power = power,
            speed = speed,
        })
    end
    assert(#ab_info < 3)
    if string.find(msg, "施放了") then
        assert(#ab_info == 2)
        local from_index = 0
        local target_team = 0
        local target_index = 0
        --from_index参数目前只对附身类技能有用，因此只考虑敌方激活宠物的index
        if string.find(msg, "对敌方的") or string.find(msg, "对敌方队伍") then
            from_index = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
            target_index = C_PetBattles.GetActivePet(LE_BATTLE_PET_ENEMY)
            target_team = LE_BATTLE_PET_ENEMY
        elseif string.find(msg, "对你的") or string.find(msg, "对我方队伍")  then
            from_index = C_PetBattles.GetActivePet(LE_BATTLE_PET_ENEMY)
            target_index = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
            target_team = LE_BATTLE_PET_ALLY
        end
        assert(target_team > 0)
        local aura
        if #ab_info == 1 then 
            aura = AI.Aura.new_aura_by_id(ab_info[1].ability_id, ab_info[1].power, from_index)
        else 
            aura = AI.Aura.new_aura_by_id(ab_info[2].ability_id, ab_info[2].power, from_index)
        end
        if aura then 
            state:install_aura(self.game.Rule.teams, target_team, target_index, aura)
            LogFrame:AddLog(string.format("添加宠物光环: player=%d, pet=%d, aura_id=%d", target_team, target_index, ab_info[2].ability_id))
            if aura.id == AI.AuraID.HAUNT then
                --添加鬼影缠身时处理假死状态
                local pet = state.team_states[3-target_team].pets[from_index]
                if AI.AuraProcessor.is_undead(state, 3-target_team, from_index) then
                    pet.tmp_health = 0
                else 
                    pet.tmp_health = pet.current_health
                end
            end
        else 
            LogFrame:AddLog(string.format("未知光环: player=%d, pet=%d, aura_id=%d", target_team, target_index, ab_info[2].ability_id))
        end
    elseif  string.find(msg, "将天气转变为") then
        assert(#ab_info == 2)
        local weather = AI.Aura.new_aura_by_id(ab_info[2].ability_id, ab_info[2].power)
        if weather then
            state:install_weather(weather)
            LogFrame:AddLog(string.format("安装天气: %d", weather.id))
        else 
            LogFrame:AddLog(string.format("未知天气: %d", ab_info[2].ability_id))
        end
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
                iterations = 1500,
                exploration_c = 1.414,
            })
    local action, info = AI.DUCT_MCTS.Searcher.select_best_action(root, LE_BATTLE_PET_ALLY)

    for _, line in ipairs(info) do
        LogFrame:AddLog(string.format("DUCT_MCTS %d  %s", round, line))
    end
    return action
end

PPBest.SearchInterface = SearchInterface