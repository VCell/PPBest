local _, PPBest = ...
local AI = PPBest.AI
local AuraProcessor = AI.AuraProcessor
local Utils = PPBest.Utils
local Action = AI.Action


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

local GameRule = {}
function GameRule:evaluate_action(state, player, action)
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

function GameRule:get_legal_actions(state, player)
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

function GameRule:apply_joint_action(old_state, action1, action2)
    local state = Utils.deepcopy(old_state)
    setmetatable(state, {
        __index = AI.GameState
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

function GameRule.is_terminal(state)
    -- 检查状态是否为终局
    if state.team_states[1]:check_loss() or state.team_states[2]:check_loss() then
        return true
    end
end

function GameRule.get_winner(state)
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

function GameRule.get_utility(state, depth)
    -- 返回玩家1的奖励值（玩家2的奖励为 constant_sum - utility）
    local winner = GameRule.get_winner(state)

    if winner == 1 then
        return 1 - 0.001 * depth
    elseif winner == 2 then
        return 0 + 0.001 * depth
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
function GameRule.print_state(state)
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
    local utility = GameRule.get_utility(state)
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
        __index = AI.GameState,
    })
    setmetatable(game.Rule, {
        __index = GameRule
    })
    return game
end

AI.Game = Game