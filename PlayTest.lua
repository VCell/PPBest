local PD = require "PetsData"
local Play = require "Play"
local Search = require "Search"

local TestPlay = {}

function TestPlay.create_test_pets(petlist)
    local res = {}
    for i, pet_id in ipairs(petlist or {}) do
        if pet_id == PD.PetID.SPRING_RABBIT then
            -- 春兔
            local rabbit = PD.Pet.new(PD.PetID.SPRING_RABBIT, 1400, 227, 357, PD.TypeID.CRITTER)
            rabbit:install_ability_by_id(PD.AbilityID.FLURRY, 1)  -- 乱舞
            rabbit:install_ability_by_id(PD.AbilityID.DODGE, 2)   -- 闪避
            rabbit:install_ability_by_id(PD.AbilityID.BURROW, 3)  -- 钻地
            table.insert(res, rabbit)
        elseif pet_id == PD.PetID.ARFUS then
                -- 阿尔福斯
            local arfus = PD.Pet.new(PD.PetID.ARFUS, 1319, 341, 260, PD.TypeID.UNDEAD)
            arfus:install_ability_by_id(PD.AbilityID.BONE_BITE, 1)   -- 啃骨头
            arfus:install_ability_by_id(PD.AbilityID.ICE_TOMB, 2)    -- 寒冰之墓
            arfus:install_ability_by_id(PD.AbilityID.ARFUS_6, 3)     -- 宠物游行
            table.insert(res, arfus)
        end
    end
    return res
end

function TestPlay.init_game_state()
    local pets1 = TestPlay.create_test_pets({PD.PetID.SPRING_RABBIT,PD.PetID.SPRING_RABBIT,PD.PetID.SPRING_RABBIT})
    local pets2 = TestPlay.create_test_pets({PD.PetID.ARFUS,PD.PetID.ARFUS,PD.PetID.ARFUS})
    local game = Play.Game.new()
    assert (#pets1 == 3 and #pets2 == 3, "每队必须有3只宠物")
    game.Rule.teams[1] = pets1
    game.Rule.teams[2] = pets2
        -- 初始化队伍状态
    for player = 1, 2 do
        local team_state =  Play.TeamState.new()
        for i, pet in ipairs(game.Rule.teams[player]) do
            print(pet.id)
            local pet_state = Play.PetState.new(pet.health)
            table.insert(team_state.pets, pet_state)
        end
        team_state.active_index = 1  -- 默认第一只宠物出战
        game.State.team_states[player] = team_state
        print("x", #team_state.pets)
    end
    setmetatable(game.State, {__index = Play.Game.State})
    
    return game
end
function print_actions(actions)
    for i, action in ipairs(actions) do
        print(string.format("  %d: %s技能%d", i, action.type, action.value))
    end
    
end
function TestPlay.manual_simulation()
    print("===== 开始手动对局模拟 =====")
    
    local game = TestPlay.init_game_state()
    local state = game.State
    
    -- 显示初始状态
    TestPlay.print_state(game)
    
    local round = 1
    local action_list = {
        {Play.Action.new('use', 3), Play.Action.new('use', 2)},
        {Play.Action.new('use', 3), Play.Action.new('use', 3)},
        {Play.Action.new('use', 1), Play.Action.new('use', 3)},
        {Play.Action.new('use', 1), Play.Action.new('use', 3)},
        {Play.Action.new('use', 1), Play.Action.new('use', 3)},
        {Play.Action.new('use', 1), Play.Action.new('use', 3)},
        {Play.Action.new('change', 3), Play.Action.new('change', 2)},
        {Play.Action.new('use', 3), Play.Action.new('use', 2)},
        {Play.Action.new('use', 3), Play.Action.new('use', 3)},
        {Play.Action.new('use', 2), Play.Action.new('use', 3)},
        {Play.Action.new('use', 1), Play.Action.new('use', 3)},
        {Play.Action.new('use', 1), Play.Action.new('use', 3)},
        {Play.Action.new('use', 1), Play.Action.new('use', 3)},
    }

    for round = 1, #action_list do  -- 最多模拟10回合
        local p1_la = game.Rule.get_legal_actions(game.State,1)
        local p2_la = game.Rule.get_legal_actions(game.State, 2)

        print(string.format("\n===== 第 %d 回合 =====", round))
        print("玩家1可选行动:")
        print_actions(p1_la)
        print("玩家2可选行动:")
        print_actions(p2_la)
        -- 玩家1行动（假设使用兔子乱舞技能）
        
        local action1 = action_list[round][1] -- 使用第一个技能（乱舞）
        
        -- 玩家2行动（假设使用化石幼兽沙暴技能） 
        local action2 = action_list[round][2]  -- 使用第一个技能（沙暴）
        
        print(string.format("玩家1行动: %s技能%d", action1.type, action1.value))
        print(string.format("玩家2行动: %s技能%d", action2.type, action2.value))
        
        -- 应用行动

        local new_state = game.Rule:apply_joint_action(game.State, action1, action2)
        game.State = new_state
        -- 显示结果
        TestPlay.print_state(game)
        
        -- 检查是否终局
        local terminal, winner = game.Rule.is_terminal(new_state)
        if terminal then
            print(string.format("\n游戏结束! 胜利者: %s", 
                  winner == 1 and "玩家1" or winner == 2 and "玩家2" or "平局"))
            break
        end
        
        round = round + 1
    end
    
    if round > 10 then
        print("达到回合数限制，游戏结束")
    end
    
    print("===== 手动模拟结束 =====")
end

function TestPlay.print_state(game)
    local state = game.State

    print("\n当前状态:")
    print(string.format("回合: %d, 天气: %d (剩余%d回合)", 
          state.round, state.weather_id, state.weather_turns))
    
    for player = 1, 2 do
        local team_state = state.team_states[player]
        print(string.format("\n玩家%d:", player))
        print(string.format("  活跃宠物: %d", team_state.active_index))
        
        for i, pet_state in ipairs(team_state.pets) do
            local prefix = (i == team_state.active_index) and "→ " or "  "
            print(string.format("%s宠物%d: 生命 %d", 
                  prefix, i, pet_state.current_health))
            
            -- 显示光环
            local aura_str = TestPlay.auras_to_string(pet_state.auras)
            if #aura_str >0 then
                print("      光环: ", TestPlay.auras_to_string(pet_state.auras))
            end
            
        end
    end
    
    -- 显示评估值
    local utility = game.Rule.get_utility(state)
    print(string.format("\n局面评估值: %.3f (玩家1优势)", utility))
end

function TestPlay.auras_to_string(auras)
    local res = ""
    for i,aura in pairs(auras) do
        res = res .. string.format("id:%d,expire:%d ", aura.id,aura.expire)
    end
    return res
end


function TestPlay.simulation()
    local game = TestPlay.init_game_state()
    local result = Search.Searcher.simulate_game(game.State,  
        game.Rule,           
            {
                iterations = 500,
                exploration_c = 1.414,
            },20)
end


--TestPlay.manual_simulation()
TestPlay.simulation()
