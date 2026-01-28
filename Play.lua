local Search = require "Search"
local PD = require "PetsData"

local Action = {
    type = '',  -- 'use' or 'change' or 'none'
    value = 0,  -- 技能索引或宠物索引
}
Action.__index = Action
function Action:new(type, value)
    local action = setmetatable({}, Action)
    action.type = type
    action.value = value
    return action
end

local PetState = {
    current_health = 0,
    auras = {},
}
PetState.__index = PetState
function PetState:new(health)
    local pet_state = setmetatable({}, PetState)
    pet_state.current_health = health
    pet_state.auras = {}
    return pet_state
end
function PetState:get_speed_rate()
    for i, aura in ipairs(self.auras) do
        -- 根据光环调整速度倍率

    end
    return 1.0  -- 示例：返回默认速度倍率
end

local TeamState = {
    pets = {},  -- 包含该队伍宠物状态的列表
    active_auras = {},
    ability_state = {}, -- 保存多回合技能状态
    active_index = 0, -- 当前出战宠物的索引
}

function get_active_speed(state, player)
    
end

local Game = {
    Background = {
        teams = {}, -- 包含双方宠物信息的列表
    },
    State = {
        team_states = {}, -- 包含双方宠物状态的列表
        round = 0,
        weather_id = 0,
        weather_turns = 0,
        change_round = 0, --0 非换宠回合 1 我方选择宠物 2 敌方选择宠物 3 双方选择宠物

        get_pets_by_player = function(self, player)
            return pets_state[player]
        end,
        get_act_order = function(self)
            local team1 = self.team_states[1], team2 = self.team_states[2]
            local active_pet1 = team1.pets[team1.active_index]
            local active_pet2 = team2.pets[team2.active_index]
            --处理aura
            local speed1 = active_pet1:get_speed_rate() * self.Background.teams[1][team1.active_index].speed
            local speed2 = active_pet2:get_speed_rate() * self.Background.teams[2][team2.active_index].speed
            if speed1 > speed2 then
                return 1, 2
            else
                return 2, 1
            end
        end,
    },
    Rule = {
        constant_sum = 1,  -- 常和游戏的总奖励

        get_legal_actions = function(state, player)
            -- 返回玩家在给定状态下的合法动作列表
            if state.changeRound > 0 and (state.changeRound == player or state.changeRound == 3) then
                -- 在宠物死亡时触发换宠回合
                local actions = {}
                local pets = state:getPetsByPlayer(player)
                for i, petState in ipairs(pets) do
                    if petState.current_health > 0 then
                        table.insert(actions, Action:new('change', i))  -- 动作为选择宠物的索引
                    end
                end
                return actions
            else
            
            end
        end,
    
        apply_joint_action = function(state, action1, action2)
            
            local player_done = {false, false}
            --首先执行主动换人
            if action1.type == 'change' then
                -- 玩家1换宠
                -- 设置当前宠物为actionValue1
                state.active_id = action_value_1
                player_done[1] = true
            end
            if action1.type == 'change' then
                -- 玩家2换宠
                -- 设置当前宠物为actionValue2
                state.active_id = action_value_2
                player_done[2] = true
            end
            if player1_done and player2_done then
                return
            end
            local first_player, second_player = state:get_act_order()

            -- 检查技能类型，判断有没有必先手类型


        end,
    
        is_terminal = function(state)
            -- 检查状态是否为终局
            error("is_terminal not implemented")
        end,
    
        get_winner = function(state)
            -- 返回赢家：1或2，或3表示平局
            error("get_winner not implemented")
        end,
    
        get_utility = function(state)
            -- 返回玩家1的奖励值（玩家2的奖励为 constant_sum - utility）
            error("get_utility not implemented")
        end
    },
}

function InitStateByGame(state, game)
    -- 初始化状态
    for i, pet in ipairs(game.Background.allyTeam) do
        local petState = setmetatable({}, PetState)
        petState.current_health = pet.health
        petState.auras = {}
        table.insert(state.allyPets, petState)
    end
    for i, pet in ipairs(game.Background.enemyTeam) do
        local petState = setmetatable({}, PetState)
        petState.current_health = pet.health
        petState.auras = {}
        table.insert(state.enemyPets, petState)
    end
    state.round = 1
    state.weatherId = 0
    state.weatherTurns = 0
    state.activeAuras = {}
    state.changeRound = 0
end