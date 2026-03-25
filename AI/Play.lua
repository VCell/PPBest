--local Search = require "Search"
--local PD = require "PetsData"

local _,PPBest = ...
local AI = PPBest.AI
local Bit = PPBest.Bit

-- 辅助函数：深拷贝表
local function DeepCopy(object)
    local lookup_table = {} -- 用于记录已复制的表，防止循环引用
    
    local function _copy(obj)
        if type(obj) ~= "table" then
            return obj -- 非表类型直接返回
        elseif lookup_table[obj] then
            return lookup_table[obj] -- 如果已复制过，直接返回副本
        end
        
        local new_table = {}
        lookup_table[obj] = new_table -- 记录已复制的表
        
        for k, v in pairs(obj) do
            new_table[_copy(k)] = _copy(v) -- 递归复制键和值
        end
        
        return setmetatable(new_table, getmetatable(obj)) -- 复制元表
    end
    
    return _copy(object)
end

local function update_change_round(old, player)
    if old == 0 or old == 3-player then 
        return old + player
    else 
        return old
    end
end

local AuraProcessor = {}

function AuraProcessor.get_active_speed_modifier(state, team_index)
    local rate = 100.0
    local team_state = state.team_states[team_index]
    for i, aura in pairs(team_state.active_auras) do
        if aura.type == AI.AuraType.SPEED then
            rate = rate + aura.value
        end
    end
    
    local ps = team_state.pets[team_state.active_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.SPEED then
            rate = rate + aura.value
        end
    end
    return rate
    
end

function AuraProcessor.is_stunned(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.STUN then
            return true
        end
    end
    return false
    
end

function AuraProcessor.get_active_accuracy_modifier(state, team_index)
    if team_index == nil then
        --没有来源时，预期是buff触发，返回100%
        return 100
    end
    local rate = 0
    local team_state = state.team_states[team_index]
    for i, aura in pairs(team_state.active_auras) do
        if aura.type == AI.AuraType.ACCURACY then
            rate = rate + aura.value
        end
    end
    local ps = team_state.pets[team_state.active_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.ACCURACY then
            rate = rate + aura.value
        end
    end
    if state.weather_id == AI.WeatherID.DARKNESS or state.weather_id == AI.WeatherID.SANDSTORM then
        rate = rate - 10
    end
    return rate
    
end

function AuraProcessor.is_immune(state, team_index, pet_index, ignore_bit)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.FLYING and not Bit.band(ignore_bit, AI.IgnoreBit.FLYING) then
            return true
        end
        if aura.type == AI.AuraType.BURROW and not Bit.band(ignore_bit, AI.IgnoreBit.BURROW) then
            return true
        end
        if aura.type == AI.AuraType.BLOCK and not Bit.band(ignore_bit, AI.IgnoreBit.BLOCK) then
            --todo 计算格挡次数
            return true
        end
    end
    return false
end

function AuraProcessor.is_undead(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.id == AI.AuraID.UNDEAD then
            return true
        end
    end
    return false
    
end

function AuraProcessor.get_dodge_modifier(state, team_index, pet_index)
    local rate = 0
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.DODGE then
            rate = rate + 100
        end
    end
    return rate
end

function AuraProcessor.get_active_modifier_by_type(state, team_index, aura_type)
    if team_index == nil then
        --没有来源时，预期是buff触发，返回0%
        return 0
    end
    local rate = 0
    local team_state = state.team_states[team_index]
    for i, aura in pairs(team_state.active_auras) do
        if aura.type == aura_type then
            rate = rate + aura.value
        end
    end
    local ps = team_state.pets[team_state.active_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == aura_type then
            rate = rate + aura.value
        end
    end
    return rate
    
end

function AuraProcessor.get_defand(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    local defend = 0
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.DEFEND then
            defend = defend + aura.value
        end
    end
    if state.weather_id == AI.WeatherID.SANDSTORM then
        defend = defend + 74
    end
    return defend
end

function AuraProcessor.process_block(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.BLOCK then
            aura.value = aura.value - 1
            if aura.value <= 0 then
                ps.auras[i] = nil
            end
            return true
        end
    end
    return false
end

local Action = {
    type = '',  -- 'use' or 'change' or 'standby'
    value = 0,  -- 技能索引或宠物索引
}
Action.__index = Action
Action.__tostring = function (self)
    return self.type .. self.value
end
function Action.new(type, value)
    local action = setmetatable({}, Action)
    action.type = type
    action.value = value
    return action
end

local PetState = {
    current_health = 0,
    auras = {},
    cooldown_at = {} --冷却回合数组。cooldown_at[i]=x表示第i个技能在x+1回合中才可以用
}
PetState.__index = PetState
function PetState.new(health)
    local pet_state = setmetatable({}, PetState)
    pet_state.current_health = health
    pet_state.auras = {}
    pet_state.cooldown_at = {0, 0, 0}
    return pet_state
end

local TeamState = {
    pets = {},  -- 包含该队伍宠物状态的列表
    active_auras = {},
    ability_round = 0, --多轮技能的当前轮次
    ability_index = 0, -- 多轮技能的技能id
    active_index = 0, -- 当前出战宠物的索引
    interrupted = false, -- 当前回合是否被打断
}
TeamState.__index = TeamState
function TeamState.new()
    local team_state = setmetatable({}, TeamState)
    team_state.pets = {}
    team_state.active_auras = {}
    team_state.active_index = 1
    team_state.ability_round = 0
    team_state.ability_index = 0
    return team_state
end
function TeamState:change_pet(new_index)
    self.active_index = new_index
    --检查是否有雷区
    for i, aura in pairs(self.active_auras) do
        if aura.type == AI.AuraType.MINE_FIELD then

            -- 移除雷区光环
            self.active_auras[i] = nil
        end
    end
    
end

function TeamState:check_type_talent()
    -- 检查并应用种族天赋
    -- 飞行在血量高于50%时速度提升50%
    return
end

function TeamState:check_loss()
    for i, petState in ipairs(self.pets) do
        if petState.current_health > 0 then
            return false
        end
    end
    return true
    
end

function TeamState:remove_aura(aura_id, pet_index)
    local auras = self.pets[pet_index].auras
    auras[aura_id] = nil
end

local GameStateTemplate = {}
function GameStateTemplate:pre_step()
    -- 每回合开始前的处理逻辑
    self.team_states[1]:check_type_talent()
    self.team_states[2]:check_type_talent()
    self.team_states[1].interrupted = false 
    self.team_states[2].interrupted = false 
end

function GameStateTemplate:pet_dead(player)
    self.change_round = update_change_round(self.change_round, player)
    self.team_states[player].ability_round = 0
    self.team_states[player].ability_index = 0
    self.team_states[player].interrupted = true
    local active = self.team_states[player].active_index
    self.team_states[player].pets[active].auras = {}
end

function GameStateTemplate:install_aura(teams, from_player, target_player, pet_index, aura_id)
    local aura
    if from_player == nil then
        aura = AI.Aura.new_aura_by_id(aura_id)
    else
        local from_pet_index = self.team_states[from_player].active_index
        local power = teams[from_player][from_pet_index].power
        local health = self.team_states[from_player].pets[from_pet_index].current_health
        aura = AI.Aura.new_aura_by_id(aura_id, power, health, from_pet_index)
    end
    aura.expire = aura.duration + self.round - 1
    local ts = self.team_states[target_player]
    if aura.keep_front then
        ts.active_auras[aura.id] = aura
    else
        if aura.type == AI.AuraType.STUN then
            if teams[target_player][pet_index].type == AI.TypeID.CRITTER then
                return false
            end
            if self.weather_id == AI.WeatherID.ARCANE_SRORM then
                return false
            end
        end
        ts.pets[pet_index].auras[aura.id] = aura
    end

end

function GameStateTemplate:post_step(teams)

    for player = 1,2 do
        local team_state = self.team_states[player]
        for i, aura in pairs(team_state.active_auras) do
            if aura.expire <= self.round then
                team_state.active_auras[i] = nil
                if aura.type == AI.AuraType.END_EFFECT then
                    self:process_effects(teams, player, aura.effects)
                end
            end
        end
        for pet_index,pet in ipairs(team_state.pets) do
            for i, aura in pairs(pet.auras) do
                if aura.expire <= self.round then
                    --处理buff到期时的特殊效果
                    pet.auras[i] = nil
                    --print("aura removed", aura.id, round, pet.auras[i])
                    if aura.type == AI.AuraType.UNDEAD then
                        pet.current_health = 0
                        if pet_index == team_state.active_index then
                            self:pet_dead(player)
                        end
                    elseif aura.type == AI.AuraType.END_EFFECT then
                        self:process_effects(teams, player, aura.effects)
                    elseif aura.type == AI.AuraType.POSSESSION then
                        local opponent = 3 - player
                        self.team_states[opponent].pets[aura.from_index].current_health = aura.value
                    end
                    
                else 
                    --处理dot类扣血
                    if aura.type == AI.AuraType.POSSESSION  or 
                            aura.type == AI.AuraType.DOT then
                        assert(aura.effects[1].effect_type == AI.EffectType.DAMAGE)
                        self:apply_effect(teams, aura.effects[1], nil, player, pet_index)
                    end
                end
            end
        end
        
    end
    if self.change_round == 0 then 
        self.round = self.round + 1 
    end
end

function GameStateTemplate:get_action_order(teams, action1, action2)
    --有换人先换人，都换人次序无所谓
    if action1.type == 'change' then
        return 1,2
    elseif action2.type == 'change' then
        return 2,1
    end

    local team1, team2 = self.team_states[1], self.team_states[2]
 
    --处理aura
    local speed1 = AuraProcessor.get_active_speed_modifier(self, 1) * teams[1][team1.active_index].speed /100.0
    local speed2 = AuraProcessor.get_active_speed_modifier(self, 2) * teams[2][team2.active_index].speed /100.0
    --总是先手属性的技能+1000速度
    if action1.type == 'use' then
        local ability1 = teams[1][team1.active_index]:get_ability(action1.value)
        if ability1.aways_first then
            speed1 = speed1 + 1000
        end
    end
    if action2.type == 'use' then
        local ability2 = teams[2][team2.active_index]:get_ability(action2.value)
        if ability2.aways_first then
            speed2 = speed2 + 1000
        end
    end
    if speed1 > speed2 then
        return 1, 2
    else
        return 2, 1
    end
end

function GameStateTemplate:process_effects(teams, player, effects)
    --print("process_effects", player)
    local opponent = 3 - player
    local ally_pet_index = self.team_states[player].active_index
    local hit_count = 0 --用于记录follow_hit为false的命中次数
    -- 处理效果列表
    for i, effect in ipairs(effects) do
        if effect.target_type == AI.TargetType.ALLY then 
            self.apply_effect(self,teams, effect, player, player, ally_pet_index)
        elseif effect.target_type == AI.TargetType.ENEMY then --调整HIT_AURA一类伴随效果的实现方式
            hit_count = self.apply_effect(self,teams, effect,player, opponent, self.team_states[opponent].active_index, hit_count)

            if effect.dynamic_type == AI.EffectDynamicType.FLURRY then
                local roll = math.random(1, 2)
                if roll == 2 then
                    --print(string.format("player %d pet %d flurry triggered extra attack", opponent, self.team_states[opponent].active_index))
                    hit = self.apply_effect(self,teams, effect,player, opponent, self.team_states[opponent].active_index) or hit
                end
                --对手速度慢则额外攻击一次
                if AuraProcessor.get_active_speed_modifier(self, player) * 
                    teams[player][ally_pet_index].speed >
                   AuraProcessor.get_active_speed_modifier(self, opponent) * 
                    teams[opponent][self.team_states[opponent].active_index].speed then
                    --print(string.format("player %d pet %d flurry triggered extra attack due to speed", opponent, self.team_states[opponent].active_index))
                    hit = self.apply_effect(self,teams, effect,player, opponent, self.team_states[opponent].active_index) or hit
                end
            elseif effect.dynamic_type == AI.EffectDynamicType.BURROW then
                --钻地状态在攻击后结束 
                self.team_states[player]:remove_aura(AI.AuraID.UNDERGROUND, ally_pet_index)
            end
            
        elseif effect.target_type == AI.TargetType.ALLY_TEAM then
            for i, petState in ipairs(self.team_states[player].pets) do
                self.apply_effect(self,teams, effect, player,player, i)
            end
        elseif effect.target_type == AI.TargetType.ENEMY_TEAM then
            local opponent = 3 - player
            for i, petState in ipairs(self.team_states[opponent].pets) do
                self.apply_effect(self,teams,effect,player, opponent, i)
            end
        elseif effect.target_type == AI.TargetType.ENEMY_BACK then
            local opponent = 3 - player
            for i, petState in ipairs(self.team_states[opponent].pets) do
                if i ~= self.team_states[opponent].active_index then
                    self.apply_effect(self,teams,effect,player, opponent, i)
                end
            end
        end
            
       
    end
end

local function roll(point)
    local roll = math.random(1, 100)
    return roll <= point
end

-- 处理单个效果
function GameStateTemplate:apply_effect(teams, effect, from_player, target_player, target_index, hit_count)
    
    if hit_count > 0 and effect.follow_hit then
        --伴随命中时，只考虑自身命中率
        if not roll(effect.accuracy) then
            return hit_count
        end
    else
        if effect.effect_type == AI.EffectType.DAMAGE or effect.effect_type == AI.EffectType.AURA then
            if AuraProcessor.is_immune(self, target_player, target_index, effect.ignore_bit) then
                --print(string.format("player %d pet %d is immune to damage", target_player, target_index))
                return hit_count
            end
            local accuracy = effect.accuracy + AuraProcessor.get_active_accuracy_modifier(self, from_player)
            accuracy = accuracy - AuraProcessor.get_dodge_modifier(self, target_player, target_index)
            local roll = math.random(1, 100)
            if roll > accuracy then
                --print(string.format("player %d pet %d attack missed (roll %d > accuracy %d)", from_player, target_index, roll, accuracy))
                return hit_count
            end
        end
    end
    if effect.effect_type == AI.EffectType.DAMAGE then
        local damage = effect.value
        local damage_dealt_modifier = AuraProcessor.get_active_modifier_by_type(self, from_player, AI.AuraType.DAMAGE_DEALT)
        local damage_taken_modifier = AuraProcessor.get_active_modifier_by_type(self, target_player, AI.AuraType.DAMAGE_TAKEN)
        local effective_rate = AI.TypeID.GetEffectiveness(
            effect.type, teams[target_player][target_index].type
        )
        local real_damage = damage * (100 + damage_dealt_modifier)*(100 + damage_taken_modifier) * effective_rate / 10000.0
        --print("damage", damage, "real_damage",real_damage,"damage_dealt_modifier", damage_dealt_modifier, "damage_taken_modifier",damage_taken_modifier,"effective_rate",effective_rate)
        local defend = AuraProcessor.get_defand(self, target_player, target_index)
        real_damage = real_damage - defend
        if real_damage <= 0 then
            return hit_count
        end
        self.team_states[target_player].pets[target_index].current_health = 
            self.team_states[target_player].pets[target_index].current_health - real_damage
        --print(string.format("player %d pet %d took %d damage, health now %d", target_player, target_index, real_damage, self.team_states[target_player].pets[target_index].current_health))
    elseif effect.effect_type == AI.EffectType.HEAL then

    elseif effect.effect_type == AI.EffectType.PERCENTAGE_HEAL then
        
    elseif effect.effect_type == AI.EffectType.AURA or effect.effect_type == AI.EffectType.HIT_AURA then
        self:install_aura(teams, from_player, target_player, target_index, effect.value)
    elseif effect.effect_type == AI.EffectType.WEATHER then

    elseif effect.effect_type == AI.EffectType.OTHER then
        
    end
    
    
    if self.team_states[target_player].pets[target_index].current_health <= 0 then 
        --处理亡灵
        if AuraProcessor.is_undead(self, target_player, target_index) then
            --已经是不死状态
            self.team_states[target_player].pets[target_index].current_health = 1
            return
        elseif teams[target_player][target_index].type == AI.TypeID.UNDEAD then
            --亡灵死后进入不死状态
            self.team_states[target_player].pets[target_index].current_health = 1
            self:install_aura(teams, nil, target_player, target_index, AI.AuraID.UNDEAD)
            --(string.format("player %d pet %d revived by Undying", target_player, target_index))
            return
        else 
            --真死了
            --print(string.format("player %d pet %d has fainted", target_player, target_index))
            --触发换人回合
            self:pet_dead(target_player)
            
        end
    end
    return hit_count+1
end
function GameStateTemplate:process_player_action(teams, player, action, opponent)
    --print("process_player_action ", action.type)
    local team_state = self.team_states[player]
    if action.type == 'change' then
        team_state:change_pet(action.value)
    elseif action.type == 'use' then
        local ability = teams[player][team_state.active_index]:get_ability(action.value)
        -- 使用技能逻辑
        local effects = nil
        if team_state.ability_round > 1 then
            -- 多轮技能逻辑
            assert (action.value == team_state.ability_index)
            effects = ability.effect_list[team_state.ability_round]
            team_state.ability_round = team_state.ability_round + 1
            if team_state.ability_round > ability.duration then
                team_state.ability_round = 0
                team_state.ability_index = 0
            end
        else
            -- 单轮技能逻辑，或多轮技能的第一轮
            effects = ability.effect_list[1]
            if ability.duration > 1 then
                team_state.ability_round = 2
                team_state.ability_index = action.value
            end
        end
        self:process_effects(teams, player, effects)
        team_state.pets[team_state.active_index].cooldown_at[action.value] = self.round + ability.cooldown
    end
end

local GameRuleTemplate = {}
function GameRuleTemplate:evaluate_action(state, player, action)
    -- 评估玩家在给定状态下的动作
   local score = 0
    
    if action.type == 'use' then
        -- 技能优先级评估
        local pet = self.teams[player][state.team_states[player].active_index]
        local ability = pet:get_ability(action.value)
        
        -- 考虑克制关系
        local opponent = self.teams[3-player][state.team_states[3-player].active_index]
        local effectiveness = AI.TypeID.GetEffectiveness(ability.type, opponent.type)
        score = score + effectiveness * 10
        
        -- 考虑技能冷却
        if ability.cooldown > 0 then
            score = score + ability.cooldown  -- 高冷却技能通常更强
        end
        
    elseif action.type == 'change' then
        -- 换宠评估
        local new_pet = self.teams[player][action.value]
        local opponent = self.teams[3-player][state.team_states[3-player].active_index]
        
        -- 克制关系
        local effectiveness = AI.TypeID.GetEffectiveness(new_pet.type, opponent.type)
        score = score + effectiveness * 15
        
    elseif action.type == 'standby' then
        score = -10  -- 待命通常不是好选择
    end
    return score
end

function GameRuleTemplate:get_legal_actions(state, player)
    -- 返回玩家在给定状态下的合法动作列表
    local actions = {}
    if state.change_round > 0 then
        if state.change_round == player or state.change_round == 3 then
            local pets = state.team_states[player].pets
            for i, petState in ipairs(pets) do
                if petState.current_health > 0 then
                    table.insert(actions, Action.new('change', i))  -- 动作为选择宠物的索引
                end
            end
        end
    else
        local active_index = state.team_states[player].active_index
        if state.team_states[player].ability_round > 0 then
            -- 多轮技能只能继续使用当前技能
            table.insert(actions, Action.new('use', state.team_states[player].ability_index))
        else
            if AuraProcessor.is_stunned(state, player, active_index) then
                table.insert(actions, Action.new('standby', 0))  -- 被晕时可以待命
            else 
                for i = 1, 3 do
                    if self.teams[player][active_index]:get_ability(i) and
                     state.team_states[player].pets[active_index].cooldown_at[i] < state.round then
                        table.insert(actions, Action.new('use', i))  -- 动作为使用技能的索引
                    end
                end
            end
            for i, petState in ipairs(state.team_states[player].pets) do
                if petState.current_health > 0 and i ~= state.team_states[player].active_index then
                    table.insert(actions, Action.new('change', i))  -- 动作为选择宠物的索引
                end
            end
        end 

    end
    if #actions == 0 then
        table.insert(actions, Action.new('standby', 0))  -- 无法换宠时只能待命
    end
    return actions
end

function GameRuleTemplate:apply_joint_action(old_state, action1, action2)
    local state = DeepCopy(old_state)
    setmetatable(state, {__index = GameStateTemplate})
    if state.change_round > 0 then
        --换人回合不触发其他逻辑
        if action1.type == 'change' then
            state.team_states[1]:change_pet(action1.value)
        end
        if action2.type == 'change' then
            state.team_states[2]:change_pet(action2.value)
        end
        state.change_round = 0
        state.round = state.round + 1
        return state
    end

    -- 预处理
    state:pre_step()

    local action = {action1, action2}
    local first_player, second_player = state:get_action_order(self.teams, action1, action2)
    state:process_player_action(self.teams, first_player, action[first_player], second_player)
    if not state.team_states[second_player].interrupted then
        state:process_player_action(self.teams, second_player, action[second_player], first_player)
    end

    state:post_step(self.teams)
    return state
end

function GameRuleTemplate.is_terminal(state)
    -- 检查状态是否为终局
    if state.team_states[1]:check_loss() or state.team_states[2]:check_loss() then
        return true
    end
end

function GameRuleTemplate.get_winner(state)
    -- 返回赢家：1或2，或3表示平局
    if state.team_states[1]:check_loss() and state.team_states[2]:check_loss() then
        return 3
    elseif state.team_states[1]:check_loss() then
        return 2
    elseif state.team_states[2]:check_loss() then
        return 1
    else
        return 0 -- 游戏未结束
    end
end

function GameRuleTemplate.get_utility(state)
    -- 返回玩家1的奖励值（玩家2的奖励为 constant_sum - utility）
    local p1_health = 0
    local p2_health = 0

    for i, petState in ipairs(state.team_states[1].pets) do
        if petState.current_health > 0 then
            p1_health = p1_health + petState.current_health
        end
    end
    for i, petState in ipairs(state.team_states[2].pets) do
        if petState.current_health > 0 then
            p2_health = p2_health + petState.current_health
        end
    end
    if p1_health+p2_health == 0 then
        return 0.5
    end
    return p1_health / (p1_health + p2_health)
end
local function auras_to_string(auras)
    local res = ""
    for i,aura in pairs(auras) do
        res = res .. string.format("id:%d,expire:%d ", aura.id,aura.expire)
    end
    return res
end
function GameRuleTemplate.print_state(state)
    print("\n当前状态:")
    print(string.format("回合: %d, 天气: %d (剩余%d回合)", 
          state.round, state.weather_id, state.weather_expire))
    
    for player = 1, 2 do
        local team_state = state.team_states[player]
        print(string.format("\n玩家%d:", player))
        print(string.format("  活跃宠物: %d", team_state.active_index))
        
        for i, pet_state in ipairs(team_state.pets) do
            local prefix = (i == team_state.active_index) and "→ " or "  "
            print(string.format("%s宠物%d: 生命 %d", 
                  prefix, i, pet_state.current_health))
            
            -- 显示光环
            local aura_str = auras_to_string(pet_state.auras)
            if #aura_str >0 then
                print("      光环: ", aura_str)
            end
            
        end
    end
    
    -- 显示评估值
    local utility = GameRuleTemplate.get_utility(state)
    print(string.format("\n局面评估值: %.3f（玩家1的胜率）", utility))
end

local Game = {
    State = {},
    Rule = {},
}

function Game.new()
    local game = {
        State = {
            team_states = {
                [1] = {},
                [2] = {},
            },
            round = 1,
            weather_id = 0,
            weather_expire = 0,
            change_round = 0,  --在一方死亡是临时添加的换宠回合。0 非换宠回合 1 我方选择宠物 2 敌方选择宠物 3 双方选择宠物
        },
        Rule = {
            constant_sum = 1,
            teams = {
                [1] = {},
                [2] = {},
            }
        }
    }
    
    -- 设置元表，让实例可以访问Game的方法
    setmetatable(game, Game)
    setmetatable(game.State, {__index = GameStateTemplate})
    setmetatable(game.Rule, {__index = GameRuleTemplate})
    return game
end

-- return {
--     Game = Game,
--     Action = Action,
--     PetState = PetState,
--     TeamState = TeamState,
-- }
AI.Game = Game
AI.Action = Action
AI.PetState = PetState
AI.TeamState = TeamState
