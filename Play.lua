local Search = require "Search"
local PD = require "PetsData"

-- 辅助函数：深拷贝表
function DeepCopy(object)
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

function update_change_round(old, player)
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
        if aura.type == PD.AuraType.SPEED then
            rate = rate + aura.value
        end
    end
    
    local ps = team_state.pets[team_state.active_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == PD.AuraType.SPEED then
            rate = rate + aura.value
        end
    end
    return rate
    
end

function AuraProcessor.is_stunned(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == PD.AuraType.STUN then
            return true
        end
    end
    return false
    
end

function AuraProcessor.get_active_accuracy_modifier(state, team_index)
    local rate = 0
    local team_state = state.team_states[team_index]
    for i, aura in pairs(team_state.active_auras) do
        if aura.type == PD.AuraType.ACCURACY then
            rate = rate + aura.value
        end
    end
    local ps = team_state.pets[team_state.active_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == PD.AuraType.ACCURACY then
            rate = rate + aura.value
        end
    end
    if state.weather_id == PD.WeatherID.DARKNESS or state.weather_id == PD.WeatherID.SANDSTORM then
        rate = rate - 10
    end
    return rate
    
end

function AuraProcessor.is_immune(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == PD.AuraType.FLYING or aura.type == PD.AuraType.UNDERGROUND then
            return true
        end
    end
    return false
end

function AuraProcessor.is_undead(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.id == PD.AuraID.UNDEAD then
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
        if aura.type == PD.AuraType.DODGE then
            rate = rate + 100
        end
    end
    return rate
end

function AuraProcessor.get_active_modifier_by_type(state, team_index, aura_type)
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
        if aura.type == PD.AuraType.DEFEND then
            defend = defend + aura.value
        end
    end
    if state.weather_id == PD.WeatherID.SANDSTORM then
        defend = defend + 74
    end
    return defend
end

function AuraProcessor.process_block(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == PD.AuraType.BLOCK then
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
function Action.new(type, value)
    local action = setmetatable({}, Action)
    action.type = type
    action.value = value
    return action
end

local PetState = {
    current_health = 0,
    auras = {},
    cooldown_at = {}
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
        if aura.type == PD.AuraType.MINE_FIELD then

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


function TeamState:is_dead_after_aura(round)
    -- 检查并移除过期的光环,返回当前宠物是否因为光环生效死亡
    local dead = false
    for i, aura in ipairs(self.active_auras) do
        if aura.expire <= round then
            self.active_auras[i] = nil
        end
    end
    for pet_index,pet in ipairs(self.pets) do
        for i, aura in pairs(pet.auras) do
            if aura.expire <= round then
                pet.auras[i] = nil
                print("aura removed", aura.id, round, pet.auras[i])
                if aura.id == PD.AuraID.UNDEAD then
                    pet.current_health = 0
                    if pet_index == self.active_index then
                        dead = true
                    end
                end
            end
        end
    end
    return dead
end

function TeamState:install_aura(aura_id, power, round)
    local aura = PD.get_aura_by_id(aura_id, power)
    aura.expire = aura.duration + round - 1
    local aura_list = nil
    if aura.keep_front then
        self.active_auras[aura.id] = aura
    else
        --print("install_aura",aura.id)
        self.pets[self.active_index].auras[aura.id] = aura
    end
    
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
end


function GameStateTemplate:post_step()

    for player = 1,2 do
        if self.team_states[player]:is_dead_after_aura(self.round) then
            self:pet_dead(player)
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
        local ability1 = teams[1][team1.active_index]:GetAbility(action1.value)
        if ability1.aways_first then
            speed1 = speed1 + 1000
        end
    end
    if action2.type == 'use' then
        local ability2 = teams[2][team2.active_index]:GetAbility(action2.value)
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
    local opponent = 3 - player
    local ally_pet_index = self.team_states[player].active_index
    -- 处理效果列表
    for i, effect in ipairs(effects) do
        if effect.target_type == PD.TargetType.ALLY then 
            self.apply_effect(self,teams, effect, player, player, ally_pet_index)
        elseif effect.target_type == PD.TargetType.ENEMY then
            
            self.apply_effect(self,teams, effect,player, opponent, self.team_states[opponent].active_index)
            if effect.dynamic_type == PD.EffectDynamicType.FLURRY then
                local roll = math.random(1, 2)
                if roll == 2 then
                    print(string.format("player %d pet %d flurry triggered extra attack", opponent, self.team_states[opponent].active_index))
                    self.apply_effect(self,teams, effect,player, opponent, self.team_states[opponent].active_index)
                end
                --对手速度慢则额外攻击一次
                if AuraProcessor.get_active_speed_modifier(self, player) * 
                    teams[player][ally_pet_index].speed >
                   AuraProcessor.get_active_speed_modifier(self, opponent) * 
                    teams[opponent][self.team_states[opponent].active_index].speed then
                    print(string.format("player %d pet %d flurry triggered extra attack due to speed", opponent, self.team_states[opponent].active_index))
                    self.apply_effect(self,teams, effect,player, opponent, self.team_states[opponent].active_index)
                end
            elseif effect.dynamic_type == PD.EffectDynamicType.BURROW then
                --钻地状态在攻击后结束 
                self.team_states[player]:remove_aura(PD.AuraID.UNDERGROUND, ally_pet_index)
            end
        elseif effect.target_type == PD.TargetType.ALLY_TEAM then
            for i, petState in ipairs(self.team_states[player].pets) do
                self.apply_effect(self,teams, effect, player,player, i)
            end
        elseif effect.target_type == PD.TargetType.ENEMY_TEAM then
            local opponent = 3 - player
            for i, petState in ipairs(self.team_states[opponent].pets) do
                self.apply_effect(self,teams,effect,player, opponent, i)
            end
        elseif effect.target_type == PD.TargetType.ENEMY_BACK then
            local opponent = 3 - player
            for i, petState in ipairs(self.team_states[opponent].pets) do
                if i ~= self.team_states[opponent].active_index then
                    self.apply_effect(self,teams,effect,player, opponent, i)
                end
            end
        end
            
       
    end
end

function GameStateTemplate:apply_effect(teams,  effect, from_player, target_player, target_index)
    -- 处理单个效果
    if effect.effect_type == PD.EffectType.DAMAGE then
        if AuraProcessor.process_block(self, target_player, target_index) then
            print(string.format("player %d pet %d blocked the attack", target_player, target_index))
            return
        end
        if AuraProcessor.is_immune(self, target_player, target_index) then
            print(string.format("player %d pet %d is immune to damage", target_player, target_index))
            return
        end
        local accuracy = effect.accuracy + AuraProcessor.get_active_accuracy_modifier(self, from_player)
        accuracy = accuracy - AuraProcessor.get_dodge_modifier(self, target_player, target_index)
        local roll = math.random(1, 100)
        if roll > accuracy then
            print(string.format("player %d pet %d attack missed (roll %d > accuracy %d)", from_player, target_index, roll, accuracy))
            return
        end
        print("accuracy",accuracy,"roll",roll)
        local damage = effect.value
        local damage_dealt_modifier = AuraProcessor.get_active_modifier_by_type(self, from_player, PD.AuraType.DAMAGE_DEALT)
        local damage_taken_modifier = AuraProcessor.get_active_modifier_by_type(self, target_player, PD.AuraType.DAMAGE_TAKEN)
        local effective_rate = PD.TypeID.GetEffectiveness(
            effect.type, teams[target_player][target_index].type
        )
        local real_damage = damage * (100 + damage_dealt_modifier)*(100 + damage_taken_modifier) * effective_rate / 10000.0
        --print("damage", damage, "real_damage",real_damage,"damage_dealt_modifier", damage_dealt_modifier, "damage_taken_modifier",damage_taken_modifier,"effective_rate",effective_rate)
        local defend = AuraProcessor.get_defand(self, target_player, target_index)
        real_damage = real_damage - defend
        if real_damage < 0 then
            real_damage = 0
        end
        self.team_states[target_player].pets[target_index].current_health = 
            self.team_states[target_player].pets[target_index].current_health - real_damage
        print(string.format("player %d pet %d took %d damage, health now %d", target_player, target_index, real_damage, self.team_states[target_player].pets[target_index].current_health))

    elseif effect.effect_type == PD.EffectType.HEAL then

    elseif effect.effect_type == PD.EffectType.PERCENTAGE_HEAL then
        
    elseif effect.effect_type == PD.EffectType.AURA then
        local ts = self.team_states[target_player]
        local power = teams[target_player][ts.active_index].power
        ts:install_aura(effect.value, power, self.round)
    elseif effect.effect_type == PD.EffectType.WEATHER then

    elseif effect.effect_type == PD.EffectType.OTHER then
        
    end
    
    
    if self.team_states[target_player].pets[target_index].current_health <= 0 then 
        --处理亡灵
        if AuraProcessor.is_undead(self, target_player, target_index) then
            --已经是不死状态
            self.team_states[target_player].pets[target_index].current_health = 1
            return
        elseif teams[target_player][target_index].type == PD.TypeID.UNDEAD then
            --亡灵死后进入不死状态
            self.team_states[target_player].pets[target_index].current_health = 1
            self.team_states[target_player]:install_aura(PD.AuraID.UNDEAD, 0, self.round)
            print(string.format("player %d pet %d revived by Undying", target_player, target_index))
            return
        else 
            --真死了
            print(string.format("player %d pet %d has fainted", target_player, target_index))
            --触发换人回合
            self:pet_dead(target_player)
            
        end
    end
end
function GameStateTemplate:process_player_action(teams, player, action, opponent)
    print("process_player_action ", action.type)
    local team_state = self.team_states[player]
    if action.type == 'change' then
        team_state:change_pet(action.value)
    elseif action.type == 'use' then
        local ability = teams[player][team_state.active_index]:GetAbility(action.value)
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
                    if state.team_states[player].pets[active_index].cooldown_at[i] < state.round then
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

    state:post_step()
    return state
end

function GameRuleTemplate:is_terminal(state)
    -- 检查状态是否为终局
    if state.team_states[1]:check_loss() or state.team_states[2]:check_loss() then
        return true
    end
end

function GameRuleTemplate:get_winner(state)
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

function GameRuleTemplate:get_utility(state)
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
    return p1_health / (p1_health + p2_health)
end


local Game = {
    State = {},
    Rule = {},
}

function Game.new()
    local state
    local game = {
        State = {
            team_states = {
                [1] = {},
                [2] = {},
            },
            round = 1,
            weather_id = 0,
            weather_turns = 0,
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

return {
    Game = Game,
    Action = Action,
    PetState = PetState,
    TeamState = TeamState,
    AuraProcessor = AuraProcessor,
}