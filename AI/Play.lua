-- local Search = require "Search"
-- local PD = require "PetsData"
local _, PPBest = ...
local AI = PPBest.AI
local AuraProcessor = AI.AuraProcessor
local Utils = PPBest.Utils

local function update_change_round(old, player)
    if old == 0 or old == 3 - player then
        return old + player
    else
        return old
    end
end

local Action = {
    type = '', -- 'use' or 'change' or 'standby'
    value = 0 -- 技能索引或宠物索引
}
Action.__index = Action
Action.__tostring = function(self)
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
    cooldown_at = {}, -- 冷却回合数组。cooldown_at[i]=x表示第i个技能在x+1回合中才可以用
    is_dead = false -- 是否死亡 目前主要用于机械
}
PetState.__index = PetState
function PetState.new(health)
    local pet_state = setmetatable({}, PetState)
    pet_state.current_health = health
    pet_state.auras = {}
    pet_state.cooldown_at = {0, 0, 0}
    pet_state.is_dead = false
    return pet_state
end

local TeamState = {
    pets = {}, -- 包含该队伍宠物状态的列表
    active_auras = {},
    ability_round = 0, -- 多轮技能的当前轮次
    ability_index = 0, -- 多轮技能的技能id
    active_index = 0, -- 当前出战宠物的索引
    is_faster = nil, -- 本轮是否先手，用来做动态判定
    interrupted = false, -- 当前回合是否被打断
    changed_pet = false -- 用于保证不连续两回合切换宠物
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

function GameStateTemplate:print_log(...)
    if self.is_logging then
        print("PlayLog ------ ", ...)
    end
end

function GameStateTemplate:change_pet(teams, player, new_index)
    assert(new_index > 0)
    local team_state = self.team_states[player]
    team_state.active_index = new_index
    team_state.ability_round = 0
    team_state.ability_index = 0
    -- 检查是否有雷区
    local to_remove = {}
    for i, aura in pairs(team_state.active_auras) do
        if aura.type == AI.AuraType.MINEFIELD then
            self:apply_effect(teams, aura.effects[1], nil, player, new_index, 0)
            table.insert(to_remove, i)
        end
    end
    for _, i in ipairs(to_remove) do
        team_state.active_auras[i] = nil
    end

end

function GameStateTemplate:pre_step(teams)
    -- 每回合开始前的处理逻辑
    for player = 1, 2 do
        self.team_states[player].interrupted = false
        local index = self.team_states[player].active_index
        if teams[player][index].type == AI.TypeID.FLYING then
            if self.team_states[player].pets[index].current_health > teams[player][index].health * 0.5 then
                local aura = AI.Aura.new_aura_by_id(AI.AuraID.FLYING)
                self:install_aura(teams, player, index, aura)
            end
        end
    end
end

function GameStateTemplate:pet_dead(player)
    self.change_round = update_change_round(self.change_round, player)
    self.team_states[player].ability_round = 0
    self.team_states[player].ability_index = 0
    self.team_states[player].interrupted = true
    local active = self.team_states[player].active_index
    -- 处理附身效果
    local aura = AuraProcessor.get_aura_by_type(self, player, active, AI.AuraType.POSSESSION)
    if aura then
        local pet_state = self.team_states[3 - player].pets[aura.value]
        -- assert(pet_state and pet_state.current_health <=0 and pet_state.tmp_health ~= nil, 
        --        string.format("玩家%d, 宠物%d 血量应为0", 3-player, aura.value))
        pet_state.current_health = pet_state.tmp_health
        pet_state.tmp_health = nil
    end
    self.team_states[player].pets[active].auras = {}
    self.team_states[player].pets[active].is_dead = true
    self:print_log(string.format("玩家%d, 宠物%d 死亡", player, active))
end

function GameStateTemplate:install_aura(teams, target_player, pet_index, aura)
    aura.expire = aura.duration + self.round
    local ts = self.team_states[target_player]
    if aura.keep_front then
        ts.active_auras[aura.id] = aura
    else
        if aura.type == AI.AuraType.STUN then
            if teams[target_player][pet_index].type == AI.TypeID.CRITTER then
                return false
            end
            -- 奥术风暴免控
            if AI.Aura.is_weather(self.weather, AI.AuraID.WEATHER_ARCANE_SRORM, self.round) then
                return false
            end
        end
        ts.pets[pet_index].auras[aura.id] = aura
    end
end

function GameStateTemplate:install_weather(weather)
    if weather then
        self.weather = weather
        self.weather.expire = weather.duration + self.round
    end
end

function GameStateTemplate:post_step(teams)

    for player = 1, 2 do
        local team_state = self.team_states[player]
        local to_remove = {}
        for i, aura in pairs(team_state.active_auras) do
            if aura.expire <= self.round then
                table.insert(to_remove, i)
            end
        end
        for _, i in ipairs(to_remove) do
            local aura = team_state.active_auras[i]
            team_state.active_auras[i] = nil
            if aura.type == AI.AuraType.END_EFFECT then
                self:process_effects(teams, player, aura.effects)
            end
        end

        for pet_index, pet in ipairs(team_state.pets) do
            local to_remove = {}
            for i, aura in pairs(pet.auras) do
                if aura.expire <= self.round then
                    -- 处理buff到期时的特殊效果
                    table.insert(to_remove, i)
                else
                    -- 处理dot类扣血
                    if aura.type == AI.AuraType.DOT then
                        assert(aura.effects[1].effect_type == AI.EffectType.DAMAGE)
                        self:apply_effect(teams, aura.effects[1], nil, player, pet_index, 0)
                    elseif aura.type == AI.AuraType.POSSESSION then
                        -- 实战中有buff提前结束了的情况
                        local pet_state = self.team_states[3 - player].pets[aura.value]
                        if pet_state.current_health > 1 then
                            table.insert(to_remove, i)
                        else 
                            self:apply_effect(teams, aura.effects[1], nil, player, pet_index, 0)
                        end
                    end
                end
            end
            if pet.auras then
                for _, i in ipairs(to_remove) do
                    local aura = pet.auras[i]
                    if aura then
                        pet.auras[i] = nil
                        self:print_log(string.format("光环到期 玩家%d, 宠物%d, 光环%d", player, pet_index,
                            aura.id))
                        if aura.type == AI.AuraType.UNDEAD then
                            pet.current_health = 0
                            if pet_index == team_state.active_index then
                                self:pet_dead(player)
                            end
                        elseif aura.type == AI.AuraType.END_EFFECT then
                            self:process_effects(teams, player, aura.effects)
                        elseif aura.type == AI.AuraType.POSSESSION then
                            local pet_state = self.team_states[3 - player].pets[aura.value]
                            if pet_state.current_health <= 0 then
                                pet_state.current_health = pet_state.tmp_health
                            end
                        end
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
    local team1, team2 = self.team_states[1], self.team_states[2]
    team1.is_faster = nil
    team2.is_faster = nil
    -- 处理aura
    local speed1 = AuraProcessor.get_active_speed_modifier(self, 1) * teams[1][team1.active_index].speed / 100.0
    local speed2 = AuraProcessor.get_active_speed_modifier(self, 2) * teams[2][team2.active_index].speed / 100.0
    -- 总是先手属性的技能+1000速度
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
        team1.is_faster = true
        return 1, 2
    elseif speed1 < speed2 then
        team2.is_faster = true
        return 2, 1
    else
        if math.random(1, 2) == 1 then
            return 1, 2
        else
            return 2, 1
        end
    end
end

function GameStateTemplate:process_effects(teams, player, effects)
    -- print("process_effects", player)
    local opponent = 3 - player
    local ally_pet_index = self.team_states[player].active_index
    local hit_count = 0 -- 用于记录follow_hit为false的命中次数
    -- 处理效果列表
    for i, effect in ipairs(effects) do
        if effect.target_type == AI.TargetType.ALLY then
            if not effect.dynamic_type or effect.dynamic_type == 0 then
                hit_count = self.apply_effect(self, teams, effect, player, player, ally_pet_index, hit_count)
            elseif effect.dynamic_type == AI.EffectDynamicType.SPRINT then
                effect.value = 10 * hit_count
                hit_count = self.apply_effect(self, teams, effect, player, player, ally_pet_index, hit_count)
            end
        elseif effect.target_type == AI.TargetType.ENEMY then -- 调整HIT_AURA一类伴随效果的实现方式
            if not effect.dynamic_type or effect.dynamic_type == 0 then
                hit_count = self.apply_effect(self, teams, effect, player, opponent,
                    self.team_states[opponent].active_index, hit_count)
            elseif effect.dynamic_type == AI.EffectDynamicType.FLURRY then
                local roll = math.random(1, 2)
                for _ = 1, roll do
                    hit_count = self.apply_effect(self, teams, effect, player, opponent,
                        self.team_states[opponent].active_index, hit_count)
                end
                -- 对手速度慢则额外攻击一次
                if self.team_states[player].is_faster then
                    hit_count = self.apply_effect(self, teams, effect, player, opponent,
                        self.team_states[opponent].active_index, hit_count)
                end
            elseif effect.dynamic_type == AI.EffectDynamicType.BURROW then
                -- 钻地状态在攻击后结束 
                hit_count = self.apply_effect(self, teams, effect, player, opponent,
                    self.team_states[opponent].active_index, hit_count)
                self.team_states[player]:remove_aura(AI.AuraID.BURROW, ally_pet_index)
            elseif effect.dynamic_type == AI.EffectDynamicType.ALPHA_STRIKE then
                -- alpha strike在先手时触发
                if self.team_states[player].is_faster then
                    hit_count = self.apply_effect(self, teams, effect, player, opponent,
                        self.team_states[opponent].active_index, hit_count)
                end
            elseif effect.dynamic_type == AI.EffectDynamicType.NOCTURNAL_STRIKE then
                -- night strike在目标被致盲时触发
                if AuraProcessor.is_blind(self, opponent, self.team_states[opponent].active_index) then
                    effect = Utils.deepcopy(effect)
                    effect.accuracy = 100
                end
                hit_count = self.apply_effect(self, teams, effect, player, opponent,
                    self.team_states[opponent].active_index, hit_count)
            end

        elseif effect.target_type == AI.TargetType.ALLY_TEAM then
            for i, pet_state in ipairs(self.team_states[player].pets) do
                if pet_state.current_health > 0 then
                    hit_count = self.apply_effect(self, teams, effect, player, player, i, hit_count)
                end
            end
        elseif effect.target_type == AI.TargetType.ENEMY_TEAM then
            local opponent = 3 - player
            for i, pet_state in ipairs(self.team_states[opponent].pets) do
                if pet_state.current_health > 0 then
                    hit_count = self.apply_effect(self, teams, effect, player, opponent, i, hit_count)
                end
            end
        elseif effect.target_type == AI.TargetType.ENEMY_BACK then
            local opponent = 3 - player
            for i, petState in ipairs(self.team_states[opponent].pets) do
                if i ~= self.team_states[opponent].active_index then
                    self.apply_effect(self, teams, effect, player, opponent, i, hit_count)
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
    -- print("apply_effect", hit_count)
    if effect.follow_hit then
        if hit_count > 0 then
            if not roll(effect.accuracy) then
                self:print_log(string.format("玩家%d, 宠物%d 伴随命中Roll失败", target_player, target_index))
                return hit_count
            end
        else
            self:print_log(string.format("玩家%d, 宠物%d 伴随命中失败", target_player, target_index))
            return hit_count
        end
    else
        if effect.effect_type == AI.EffectType.DAMAGE or effect.effect_type == AI.EffectType.AURA then
            if AuraProcessor.is_immune(self, target_player, target_index, effect.ignore_bit) then
                self:print_log(string.format("玩家%d, 宠物%d 免疫效果", target_player, target_index))
                return hit_count
            end
            local accuracy = effect.accuracy + AuraProcessor.get_active_accuracy_modifier(self, from_player)
            accuracy = accuracy - AuraProcessor.get_dodge_modifier(self, target_player, target_index)
            if not roll(accuracy) then
                self:print_log(string.format("玩家%d, 宠物%d 攻击命中失败", target_player, target_index))
                return hit_count
            end
        end
    end
    self:print_log(string.format("玩家%d, 宠物%d 判定通过", target_player, target_index))

    local pet_state = self.team_states[target_player].pets[target_index]
    if effect.effect_type == AI.EffectType.DAMAGE then
        local damage = effect.value
        local damage_dealt_modifier = AuraProcessor.get_active_modifier_by_type(self, from_player,
            AI.AuraType.DAMAGE_DEALT)
        local damage_taken_modifier = AuraProcessor.get_active_modifier_by_type(self, target_player,
            AI.AuraType.DAMAGE_TAKEN)
        local effective_rate = AI.TypeID.GetEffectiveness(effect.type, teams[target_player][target_index].type)
        local real_damage = damage * (100 + damage_dealt_modifier) * (100 + damage_taken_modifier) * effective_rate /
                                10000.0
        -- print("damage", damage, "real_damage",real_damage,"damage_dealt_modifier", damage_dealt_modifier, "damage_taken_modifier",damage_taken_modifier,"effective_rate",effective_rate)
        local defend = AuraProcessor.get_defand(self, target_player, target_index)
        real_damage = real_damage - defend
        if real_damage <= 0 then
            return hit_count
        end
        -- 魔法宠一次最多受35%的伤害
        if teams[target_player][target_index].type == AI.TypeID.MAGIC then
            local max_damage = teams[target_player][target_index].health * 0.35
            if real_damage > max_damage then
                real_damage = max_damage
            end
        end
        pet_state.current_health = pet_state.current_health - real_damage
        self:print_log(string.format("玩家%d, 宠物%d 受到%d点伤害", target_player, target_index, real_damage))
        -- print(string.format("player %d pet %d took %d damage, health now %d", target_player, target_index, real_damage, pet_state.current_health))
    elseif effect.effect_type == AI.EffectType.HEAL then
        local max_health = teams[target_player][target_index].health *
                               (100 + AuraProcessor.get_max_health_modifier(self, target_player, target_index)) / 100
        local heal = effect.value * (100 + AuraProcessor.get_heal_modifier(self, target_player, target_index)) / 100
        if pet_state.current_health + heal > max_health then
            pet_state.current_health = max_health
        else
            pet_state.current_health = pet_state.current_health + heal
        end
        self:print_log(string.format("玩家%d, 宠物%d 治疗%d点", target_player, target_index, heal))
        -- print(string.format("player %d pet %d healed %d, health now %d", target_player, target_index, heal, pet_state.current_health))
    elseif effect.effect_type == AI.EffectType.PERCENTAGE_HEAL then

    elseif effect.effect_type == AI.EffectType.AURA then
        local from_index = self.team_states[from_player].active_index
        local power = teams[from_player][from_index].power
        local aura = AI.Aura.new_aura_by_id(effect.value, power, from_index)
        self:install_aura(teams, target_player, target_index, aura)

    elseif effect.effect_type == AI.EffectType.WEATHER then
        local from_index = self.team_states[from_player].active_index
        local power = teams[from_player][from_index].power
        local weather = AI.Aura.new_aura_by_id(effect.value, power)
        self:install_weather(weather)
    elseif effect.effect_type == AI.EffectType.FEIGN_DEATH then
        self:print_log(string.format("玩家%d, 宠物%d 假死", target_player, target_index))
        pet_state.tmp_health = pet_state.current_health
        pet_state.current_health = 0
    elseif effect.effect_type == AI.EffectType.FORCE_CHANGE then
        local change_idx = 0
        for i = 1, 3 do
            if i ~= target_index and self.team_states[target_player].pets[i].current_health > 0 then
                change_idx = i
                break
            end
        end
        if change_idx > 0 then
            self:change_pet(teams, target_player, change_idx)
            self.team_states[target_player].interrupted = true
            self:print_log(
                string.format("玩家%d, 宠物%d 强制更换为%d", target_player, target_index, change_idx))
        end
    elseif effect.effect_type == AI.EffectType.HEALTHY_CHANGE then
        local max_health = 0
        local change_idx = 0
        for i = 1,3 do
            if i ~= target_index and self.team_states[target_player].pets[i].current_health > max_health then
                max_health = self.team_states[target_player].pets[i].current_health
                change_idx = i
                break
            end
        end
        if change_idx ~= target_index then 
            self:change_pet(teams, target_player, change_idx)
            self:print_log(
                string.format("玩家%d, 宠物%d 被更换为%d", target_player, target_index, change_idx))
        end
    elseif effect.effect_type == AI.EffectType.OTHER then

    end

    -- 处理死亡流程
    if pet_state.current_health <= 0 then
        local pet = teams[target_player][target_index]
        -- 处理亡灵
        if pet.type == AI.TypeID.UNDEAD then
            if AuraProcessor.get_aura_by_id(self, target_player, target_index, AI.AuraID.UNDEAD) ~= nil then
                -- 已经是不死状态
                pet_state.current_health = 1
                if pet_state.tmp_health and pet_state.tmp_health > 0 then
                    -- 不死轮假死不复活，也不进死亡状态
                    pet_state.current_health = 1
                    pet_state.tmp_health = 0
                    self:pet_dead(target_player)
                end
            elseif pet_state.tmp_health then
                -- 假死
                self:pet_dead(target_player)
            else
                -- 亡灵死后进入不死状态
                pet_state.current_health = 1
                local aura = AI.Aura.new_aura_by_id(AI.AuraID.UNDEAD)
                self:install_aura(teams, target_player, target_index, aura)
                -- (string.format("player %d pet %d revived by Undying", target_player, target_index))
            end
        elseif pet.type == AI.TypeID.MECHANICAL and not pet_state.is_dead then
            if AuraProcessor.get_aura_by_id(self, target_player, target_index, AI.AuraID.MECHANICAL) ~= nil then
                -- 修复过
                self:pet_dead(target_player)
            else
                -- 机械修复流程
                pet_state.current_health = 0.2 * pet.health
                local aura = AI.Aura.new_aura_by_id(AI.AuraID.MECHANICAL)
                self:install_aura(teams, target_player, target_index, aura)
                self:print_log(string.format("玩家%d, 宠物%d 触发机械修复", target_player, target_index))
            end
        else
            self:pet_dead(target_player)
        end
    end
    return hit_count + 1
end

function GameStateTemplate:process_use_action(teams, player, action)
    -- print("process_use_action ", action.type)
    local team_state = self.team_states[player]
    if team_state.is_faster then
        self:print_log(string.format("玩家%d 速度优势", player))
    end
    if action.type == 'use' then
        local ability = teams[player][team_state.active_index]:get_ability(action.value)
        -- 使用技能逻辑
        local effects = nil
        if team_state.ability_round > 1 then
            -- 多轮技能逻辑
            assert(action.value == team_state.ability_index)
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
        assert(effects, string.format("技能%d无效果", ability.id))
        self:process_effects(teams, player, effects)
        team_state.pets[team_state.active_index].cooldown_at[action.value] = self.round + ability.cooldown
    end
end

function GameStateTemplate:open_log()
    self.is_logging = true
end

function GameStateTemplate:close_log()
    self.is_logging = false
end

local function evaluate_ability_effectiveness(ability, opponent)
    local effectiveness = AI.TypeID.GetEffectiveness(ability.type, opponent.type)
    return 1 + (effectiveness - 1) * AI.Ability.get_effectiveness_rate(ability.id)
end

local function evaluate_pet_effectiveness(pet, opponent)
    return 0.5 * evaluate_ability_effectiveness(pet:get_ability(1), opponent) + 0.25 *
               evaluate_ability_effectiveness(pet:get_ability(2), opponent) + 0.25 *
               evaluate_ability_effectiveness(pet:get_ability(3), opponent)
end

local function fix_aura_score(ability, state, player)
    local index = state.team_states[player].active_index
    if ability.id == AI.AbilityID.IMMOLATION then
        if AuraProcessor.get_aura_by_id(state, player, index, AI.AuraID.IMMOLATION) == nil then
            return 15
        end
    elseif ability.id == AI.AbilityID.SHELL_SHIELD then
        if AuraProcessor.get_aura_by_id(state, player, index, AI.AuraID.SHELL_SHIELD) == nil then
            return 15
        end
    elseif ability.id == AI.AbilityID.HAUNT then
        return 10
    end
    return 0
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
        local opponent = self.teams[3 - player][state.team_states[3 - player].active_index]
        local effectiveness = evaluate_ability_effectiveness(ability, opponent)
        score = score + effectiveness * 10

        -- 考虑技能冷却
        if ability.cooldown > 0 then
            score = score + ability.cooldown * 2 -- 高冷却技能通常更强
        end
        score = score + fix_aura_score(ability, state, player)
    elseif action.type == 'change' then
        -- 换宠评估
        local my_pet = self.teams[player][action.value]
        local op_index = state.team_states[3 - player].active_index
        if op_index == 0 then
            op_index = 1
        end
        local op_pet = self.teams[3 - player][op_index]

        -- 克制关系
        local effectiveness = evaluate_pet_effectiveness(my_pet, op_pet) / evaluate_pet_effectiveness(op_pet, my_pet)
        local my_health_percent = state.team_states[player].pets[action.value].current_health / my_pet.health
        local op_health_percent = state.team_states[3 - player].pets[op_index].current_health / op_pet.health

        score = score + 10 + (effectiveness - 1) * my_health_percent * op_health_percent * 10

    elseif action.type == 'standby' then
        score = 10 
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
                    table.insert(actions, Action.new('change', i)) -- 动作为选择宠物的索引
                end
            end
        end
    else
        local active_index = state.team_states[player].active_index
        if state.team_states[player].ability_round > 0 then
            -- 多轮技能只能继续使用当前技能
            table.insert(actions, Action.new('use', state.team_states[player].ability_index))
        else
            local can_use = false
            if AuraProcessor.is_stunned(state, player, active_index) then
                table.insert(actions, Action.new('standby', 0)) -- 被晕时可以待命
            else
                for i = 1, 3 do
                    if self.teams[player][active_index]:get_ability(i) and
                        state.team_states[player].pets[active_index].cooldown_at[i] < state.round then
                        table.insert(actions, Action.new('use', i)) -- 动作为使用技能的索引
                        can_use = true
                    end
                end
            end
            --无可用技能，或上轮没有换宠时，才能换宠
            if not can_use or not state.team_states[player].changed_pet then
                for i, petState in ipairs(state.team_states[player].pets) do
                    if petState.current_health > 0 and i ~= state.team_states[player].active_index then
                        table.insert(actions, Action.new('change', i)) -- 动作为选择宠物的索引
                    end
                end
            end
        end

    end
    if #actions == 0 then
        table.insert(actions, Action.new('standby', 0)) -- 无法换宠时只能待命
    end
    return actions
end

function GameRuleTemplate:apply_joint_action(old_state, action1, action2)
    local state = Utils.deepcopy(old_state)
    setmetatable(state, {
        __index = GameStateTemplate
    })
    state.team_states[1].changed_pet = false
    state.team_states[2].changed_pet = false
    if state.change_round > 0 then
        -- 换人回合不触发其他逻辑
        if action1.type == 'change' then
            state:change_pet(self.teams, 1, action1.value)
        end
        if action2.type == 'change' then
            state:change_pet(self.teams, 2, action2.value)
        end
        state.change_round = 0
        state.round = state.round + 1
        return state
    end
    if action1.type == 'change' then
        state:change_pet(self.teams, 1, action1.value)
        state.team_states[1].changed_pet = true
    end
    if action2.type == 'change' then
        state:change_pet(self.teams, 2, action2.value)
        state.team_states[2].changed_pet = true
    end
    -- 预处理
    state:pre_step(self.teams)

    local action = {action1, action2}
    local first_player, second_player = state:get_action_order(self.teams, action1, action2)

    state:process_use_action(self.teams, first_player, action[first_player])
    if not state.team_states[second_player].interrupted then
        state:process_use_action(self.teams, second_player, action[second_player])
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

function GameRuleTemplate.get_utility(state, depth)
    -- 返回玩家1的奖励值（玩家2的奖励为 constant_sum - utility）
    local winner = GameRuleTemplate.get_winner(state)

    if winner == 1 then
        return 1 - 0.01 * depth
    elseif winner == 2 then
        return 0 + 0.01 * depth
    elseif winner == 3 then
        return 0.5
    end

    local p1_health = 0
    local p2_health = 0

    for i, petState in ipairs(state.team_states[1].pets) do
        if petState.current_health > 0 then
            p1_health = p1_health + petState.current_health
        elseif petState.tmp_health and petState.tmp_health > 0 then
            p1_health = p1_health + petState.tmp_health
        end
    end
    for i, petState in ipairs(state.team_states[2].pets) do
        if petState.current_health > 0 then
            p2_health = p2_health + petState.current_health
        elseif petState.tmp_health and petState.tmp_health > 0 then
            p2_health = p2_health + petState.tmp_health
        end
    end

    local diff = p1_health - p2_health
    local total = p1_health + p2_health
    assert(total > 0)

    return 0.5 + 0.5 * math.tanh(diff / total)
end

local function auras_to_string(auras)
    local res = ""
    for i, aura in pairs(auras) do
        res = res .. string.format("id:%d,expire:%d ", aura.id, aura.expire)
    end
    return res
end
function GameRuleTemplate.print_state(state)
    print(string.format("\n当前第%d回合:", state.round))
    if state.weather then
        print(string.format("天气: %d (持续到回合%d)", state.weather.id, state.weather.expire))
    end

    for player = 1, 2 do
        local team_state = state.team_states[player]
        print(string.format("\n玩家%d:", player))
        print(string.format("  活跃宠物: %d", team_state.active_index))

        for i, pet_state in ipairs(team_state.pets) do
            local prefix = (i == team_state.active_index) and "→ " or "  "
            print(string.format("%s宠物%d: 生命 %d", prefix, i, pet_state.current_health))

            -- 显示光环
            local aura_str = auras_to_string(pet_state.auras)
            if #aura_str > 0 then
                print("      光环: ", aura_str)
            end

        end
        local team_aura_str = auras_to_string(team_state.active_auras)
        if #team_aura_str > 0 then
            print("      队伍光环: ", team_aura_str)
        end
    end

    -- 显示评估值
    local utility = GameRuleTemplate.get_utility(state)
    print(string.format("\n局面评估值: %.3f（玩家1的胜率）", utility))
end

local Game = {
    State = {},
    Rule = {}
}

function Game.new()
    local game = {
        State = {
            team_states = {
                [1] = {},
                [2] = {}
            },
            round = 1,
            weather = nil,
            change_round = 0 -- 在一方死亡是临时添加的换宠回合。0 非换宠回合 1 我方选择宠物 2 敌方选择宠物 3 双方选择宠物
        },
        Rule = {
            constant_sum = 1,
            teams = {
                [1] = {},
                [2] = {}
            }
        }
    }

    -- 设置元表，让实例可以访问Game的方法
    setmetatable(game, Game)
    setmetatable(game.State, {
        __index = GameStateTemplate
    })
    setmetatable(game.Rule, {
        __index = GameRuleTemplate
    })
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
AI.AuraProcessor = AuraProcessor
