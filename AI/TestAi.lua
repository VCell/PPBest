-- 测试AI模块的文件
-- 模拟魔兽插件的调用方式，保证 _,PPBest = ... 的有效性

-- 模拟全局PPBest对象
_G.PPBest = {}
_G.PPBest.AI = {}

-- 模拟魔兽插件的加载方式
local _, PPBest = ... or {}
if not PPBest then
    PPBest = _G.PPBest
end

-- 加载AI模块
local AI = PPBest.AI

-- 加载需要测试的模块
-- local PetsDataPath = "AI/PetsData.lua"
-- local SearchPath = "AI/Search.lua"
-- local PlayPath = "AI/Play.lua"

-- 模拟dofile函数
local function dofile(path)
    local fullPath = "/Users/lishiyuan/Work/PPBest/" .. path
    local file = io.open(fullPath, "r")
    if not file then
        error("无法打开文件: " .. fullPath)
    end
    local content = file:read("*a")
    file:close()
    
    -- 执行文件内容，使用当前环境并传递参数
    local func, err = loadstring(content, path)
    if not func then
        error("无法加载文件: " .. path .. "\n" .. err)
    end
    -- 传递参数，模拟魔兽插件的加载方式
    func("", _G.PPBest)
end

-- 加载模块
local dofile_list = {
    "Utils.lua",
    "AI/PetsData.lua",
    "AI/Search.lua",
    "AI/Play.lua",
}
for _, path in ipairs(dofile_list) do
    dofile(path)
end

-- 测试类
local TestAI = {
    name = "AI模块测试",
    version = "1.0"
}

local function create_test_pets(petlist)
    local res = {}
    for i, pet_id in ipairs(petlist or {}) do
        if pet_id == AI.PetID.SPRING_RABBIT then
            -- 春兔
            local pet = AI.Pet.new(AI.PetID.SPRING_RABBIT, 1400, 227, 357, AI.TypeID.CRITTER)
            pet:install_ability_by_id(AI.AbilityID.FLURRY, 1)  -- 乱舞
            pet:install_ability_by_id(AI.AbilityID.DODGE, 2)   -- 闪避
            pet:install_ability_by_id(AI.AbilityID.BURROW, 3)  -- 钻地
            table.insert(res, pet)
        elseif pet_id == AI.PetID.ARFUS then
                -- 阿尔福斯
            local pet = AI.Pet.new(AI.PetID.ARFUS, 1319, 341, 260, AI.TypeID.UNDEAD)
            pet:install_ability_by_id(AI.AbilityID.BONE_BITE, 1)   -- 啃骨头
            pet:install_ability_by_id(AI.AbilityID.ICE_TOMB, 2)    -- 寒冰之墓
            pet:install_ability_by_id(AI.AbilityID.ARFUS_6, 3)     -- 宠物游行
            table.insert(res, pet)
        elseif pet_id == AI.PetID.PEBBLE then
            local pet = AI.Pet.new(AI.PetID.ARFUS, 1969, 260, 211, AI.TypeID.ELEMENTAL)
            pet:install_ability_by_id(AI.AbilityID.STONE_SHOT, 1)   -- 投石
            pet:install_ability_by_id(AI.AbilityID.RUPTURE, 2)    -- 割裂
            pet:install_ability_by_id(AI.AbilityID.ROCK_BARRAGE, 3)     --岩石弹幕
            table.insert(res, pet)
        elseif pet_id == AI.PetID.UNBORN_VALKYR then
            local pet = AI.Pet.new(AI.PetID.UNBORN_VALKYR, 1563, 293, 244, AI.TypeID.UNDEAD)
            pet:install_ability_by_id(AI.AbilityID.SHADOW_SHOCK, 1) 
            pet:install_ability_by_id(AI.AbilityID.CURSE_OF_DOOM, 2) 
            pet:install_ability_by_id(AI.AbilityID.HAUNT, 3) 
            table.insert(res, pet)
        elseif pet_id == AI.PetID.DARKMOON_TONK then
            local pet = AI.Pet.new(AI.PetID.DARKMOON_TONK, 1627,273,260, AI.TypeID.MECHANICAL)
            pet:install_ability_by_id(AI.AbilityID.MISSILE, 1)  
            pet:install_ability_by_id(AI.AbilityID.MINEFIELD, 2) 
            pet:install_ability_by_id(AI.AbilityID.ION_CANNON, 3)
            table.insert(res, pet)
        elseif pet_id == AI.PetID.CROW then
            local pet = AI.Pet.new(AI.PetID.CROW, 1465, 289, 273, AI.TypeID.FLYING)
            pet:install_ability_by_id(AI.AbilityID.ALPHA_STRIKE, 1)  -- 乱舞
            pet:install_ability_by_id(AI.AbilityID.CALL_DARKNESS, 2)   -- 召唤
            pet:install_ability_by_id(AI.AbilityID.NOCTURNAL_STRIKE, 3)  -- 钻地
            table.insert(res, pet)
        end
    end
    return res
end

local function init_game_state()
    local pets2 = create_test_pets({AI.PetID.SPRING_RABBIT, AI.PetID.PEBBLE,AI.PetID.ARFUS})
    local pets1 = create_test_pets({AI.PetID.CROW, AI.PetID.DARKMOON_TONK,AI.PetID.UNBORN_VALKYR })
    local game = AI.Game.new()
    assert (#pets1 == 3 and #pets2 == 3, "每队必须有3只宠物")
    game.Rule.teams[1] = pets1
    game.Rule.teams[2] = pets2
        -- 初始化队伍状态
    for player = 1, 2 do
        local team_state =  AI.TeamState.new()
        for i, pet in ipairs(game.Rule.teams[player]) do
            print(pet.id)
            local pet_state = AI.PetState.new(pet.health)
            table.insert(team_state.pets, pet_state)
        end
        team_state.active_index = 0 --对局初始双方都未选择首发的状态
        game.State.team_states[player] = team_state

    end
    --setmetatable(game.State, {__index = AI.Game.State})
    game.State.round = 0
    game.State.change_round = 3
    return game
end

function TestAI:simulation()
    local game = init_game_state()
    local result = AI.DUCT_MCTS.Searcher.simulate_game(game.State,  
        game.Rule,           
            {
                iterations = 1000,
                exploration_c = 1.414,
            },50)
end

-- 人机对战函数
function TestAI:humanVsAi()
    local game = init_game_state()
    local max_rounds = 50
    
    print("==================================================")
    print("人机对战模式")
    print("==================================================")
    print("你是玩家1，使用阵容：春兔、配波、阿尔福斯")
    print("AI是玩家2，使用相同阵容")
    print("每回合选择一个动作，输入对应数字即可")
    print("==================================================")
    
    local state = game.State
    local rule = game.Rule
    
    for round = 1, max_rounds do
        print(string.format("\n=== 回合 %d （游戏回合：%d） ===", round, state.round))
        
        -- 检查游戏是否结束
        if rule.is_terminal(state) then
            local winner = rule.get_winner(state)
            if winner == 1 then
                print("🎉 游戏结束！你获胜了！")
            elseif winner == 2 then
                print("😢 游戏结束！AI获胜了！")
            else
                print("🤝 游戏结束！平局！")
            end
            break
        end
        
        -- 显示当前状态
        rule.print_state(state)
        
        -- 获取玩家1的合法动作
        local player_actions = rule:get_legal_actions(state, 1)
        
        -- 显示玩家可选择的动作
        print("\n你的可用动作：")
        for i, action in ipairs(player_actions) do
            local action_desc
            if action.type == 'use' then
                action_desc = string.format("技能 %d", action.value)
            elseif action.type == 'change' then
                action_desc = string.format("换宠到 %d", action.value)
            elseif action.type == 'standby' then
                action_desc = "待命"
            else
                action_desc = "未知动作"
            end
            print(string.format("%d. %s", i, action_desc))
        end
        
        -- 获取玩家输入
        local player_choice
        while true do
            print("请输入选择的动作编号：")
            local input = io.read()
            local choice = tonumber(input)
            if choice and choice >= 1 and choice <= #player_actions then
                player_choice = player_actions[choice]
                break
            else
                print("输入无效，请重新输入！")
            end
        end
        
        -- 使用MCTS为AI选择动作
        print("\nAI思考中...")
        local root_node = AI.DUCT_MCTS.Searcher.run_search(state, rule, {
            iterations = 1000,
            exploration_c = 1.414
        })
        local ai_choice = AI.DUCT_MCTS.Searcher.select_best_action(root_node, 2)
        
        -- 显示双方选择
        local player_action_desc
        if player_choice.type == 'use' then
            player_action_desc = string.format("使用技能 %d", player_choice.value)
        elseif player_choice.type == 'change' then
            player_action_desc = string.format("换宠到 %d", player_choice.value)
        else
            player_action_desc = "待命"
        end
        
        local ai_action_desc
        if ai_choice.type == 'use' then
            ai_action_desc = string.format("使用技能 %d", ai_choice.value)
        elseif ai_choice.type == 'change' then
            ai_action_desc = string.format("换宠到 %d", ai_choice.value)
        else
            ai_action_desc = "待命"
        end
        
        print(string.format("你选择：%s", player_action_desc))
        print(string.format("AI选择：%s", ai_action_desc))
        
        -- 应用动作
        state:open_log()
        state = rule:apply_joint_action(state, player_choice, ai_choice)
        state:close_log()
        print("应用动作后状态：change_round:",state.change_round)
        
    end
    
    if not rule.is_terminal(state) then
        print("\n达到最大回合数，游戏结束！")
    end
    
    print("\n==================================================")
    print("对战结束！")
    print("==================================================")
end

-- 手动模拟测试函数
function TestAI:manual_simulation()
    print("==================================================")
    print("手动模拟测试")
    print("==================================================")
    
    local game = init_game_state()
    local state = game.State
    local rule = game.Rule
    
    -- 显示初始状态
    rule.print_state(state)
    
    local max_rounds = 50
    
    for round = 1, max_rounds do
        -- 检查游戏是否结束
        if rule.is_terminal(state) then
            local winner = rule.get_winner(state)
            if winner == 1 then
                print("🎉 游戏结束！玩家1获胜了！")
            elseif winner == 2 then
                print("😢 游戏结束！玩家2获胜了！")
            else
                print("🤝 游戏结束！平局！")
            end
            break
        end
        
        -- 获取双方的合法动作
        local p1_la = rule:get_legal_actions(state, 1)
        local p2_la = rule:get_legal_actions(state, 2)
        
        print(string.format("\n=== 第 %d 回合 （游戏回合：%d）===", round, state.round))
        
        -- 获取玩家1的选择
        print("玩家1可选行动:")
        for i, action in ipairs(p1_la) do
            local action_desc
            if action.type == 'use' then
                action_desc = string.format("技能 %d", action.value)
            elseif action.type == 'change' then
                action_desc = string.format("换宠到 %d", action.value)
            elseif action.type == 'standby' then
                action_desc = "待命"
            else
                action_desc = "未知动作"
            end
            print(string.format("  %d. %s", i, action_desc))
        end
        
        local action1
        while true do
            print("请输入玩家1的选择：")
            local input = io.read()
            local choice = tonumber(input)
            if choice and choice >= 1 and choice <= #p1_la then
                action1 = p1_la[choice]
                break
            else
                print("输入无效，请重新输入！")
            end
        end
        
        -- 获取玩家2的选择
        print("\n玩家2可选行动:")
        for i, action in ipairs(p2_la) do
            local action_desc
            if action.type == 'use' then
                action_desc = string.format("技能 %d", action.value)
            elseif action.type == 'change' then
                action_desc = string.format("换宠到 %d", action.value)
            elseif action.type == 'standby' then
                action_desc = "待命"
            else
                action_desc = "未知动作"
            end
            print(string.format("  %d. %s", i, action_desc))
        end
        
        local action2
        while true do
            print("请输入玩家2的选择：")
            local input = io.read()
            local choice = tonumber(input)
            if choice and choice >= 1 and choice <= #p2_la then
                action2 = p2_la[choice]
                break
            else
                print("输入无效，请重新输入！")
            end
        end
        
        -- 显示双方选择
        local player_action_desc
        if action1.type == 'use' then
            player_action_desc = string.format("使用技能 %d", action1.value)
        elseif action1.type == 'change' then
            player_action_desc = string.format("换宠到 %d", action1.value)
        else
            player_action_desc = "待命"
        end
        
        local ai_action_desc
        if action2.type == 'use' then
            ai_action_desc = string.format("使用技能 %d", action2.value)
        elseif action2.type == 'change' then
            ai_action_desc = string.format("换宠到 %d", action2.value)
        else
            ai_action_desc = "待命"
        end
        
        print(string.format("\n玩家1选择：%s", player_action_desc))
        print(string.format("玩家2选择：%s", ai_action_desc))
        
        -- 应用动作
        state:open_log()
        state = rule:apply_joint_action(state, action1, action2)
        state:close_log()
        
        -- 显示结果
        rule.print_state(state)
    end
    
    if not rule.is_terminal(state) then
        print("\n达到最大回合数，游戏结束！")
    end
    
    print("\n==================================================")
    print("手动模拟测试结束！")
    print("==================================================")
end

-- 运行所有测试
function TestAI:runAllTests()
    -- 解析命令行参数
    math.randomseed(os.time()) 
    local mode = arg[1] or "manual"
    
    local mode_map = {
        simulation = self.simulation,         -- AI vs AI
        play = self.humanVsAi,      -- 手动 vs AI
        manual = self.manual_simulation,   -- 手动 vs 手动
    }
    
    if not mode_map[mode] then
        print("用法: lua TestAi.lua <模式>")
        print("可用模式:")
        print("  simulation      - AI vs AI 模式")
        print("  play   - 手动 vs AI 模式")
        print("  manual  - 手动 vs 手动 模式")
        print("\n默认模式: manual")
        mode = "manual"
        return
    end
    
    print("\n"..os.date("%Y-%m-%d %H:%M:%S").."\n运行模式: " .. mode)
    print("==================================================")
    
    -- 运行对应模式
    mode_map[mode](self)
    
    print("\n==================================================")
    print("测试完成！")
    print("==================================================")
end
TestAI:runAllTests()
-- 导出测试模块
return {
    TestAI = TestAI
}
