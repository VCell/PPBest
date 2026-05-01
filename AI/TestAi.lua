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
    "AI/Aura.lua", 
    "AI/Search.lua", 
    "AI/GameState.lua", 
    "AI/GameRule.lua", 
    "AI/explain.lua"}
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
            pet:install_ability_by_id(AI.AbilityID.FLURRY, 1) -- 乱舞
            pet:install_ability_by_id(AI.AbilityID.DODGE, 2) -- 闪避
            pet:install_ability_by_id(AI.AbilityID.BURROW, 3) -- 钻地
            table.insert(res, pet)
        elseif pet_id == AI.PetID.ARFUS then
            -- 阿尔福斯
            local pet = AI.Pet.new(AI.PetID.ARFUS, 1319, 341, 260, AI.TypeID.UNDEAD)
            pet:install_ability_by_id(AI.AbilityID.BONE_BITE, 1) -- 啃骨头
            pet:install_ability_by_id(AI.AbilityID.DEADLY_DREAM, 2)
            pet:install_ability_by_id(AI.AbilityID.SPRINT, 3)
            table.insert(res, pet)
        elseif pet_id == AI.PetID.PEBBLE then
            local pet = AI.Pet.new(AI.PetID.ARFUS, 1969, 260, 211, AI.TypeID.ELEMENTAL)
            pet:install_ability_by_id(AI.AbilityID.STONE_SHOT, 1) -- 投石
            pet:install_ability_by_id(AI.AbilityID.RUPTURE, 2) -- 割裂
            pet:install_ability_by_id(AI.AbilityID.ROCK_BARRAGE, 3) -- 岩石弹幕
            table.insert(res, pet)
        elseif pet_id == AI.PetID.UNBORN_VALKYR then
            local pet = AI.Pet.new(AI.PetID.UNBORN_VALKYR, 1563, 293, 244, AI.TypeID.UNDEAD)
            pet:install_ability_by_id(AI.AbilityID.SHADOW_SHOCK, 1)
            pet:install_ability_by_id(AI.AbilityID.CURSE_OF_DOOM, 2)
            pet:install_ability_by_id(AI.AbilityID.HAUNT, 3)
            table.insert(res, pet)
        elseif pet_id == AI.PetID.DARKMOON_TONK then
            local pet = AI.Pet.new(AI.PetID.DARKMOON_TONK, 1627, 273, 260, AI.TypeID.MECHANICAL)
            pet:install_ability_by_id(AI.AbilityID.MISSILE, 1)
            pet:install_ability_by_id(AI.AbilityID.MINEFIELD, 2)
            pet:install_ability_by_id(AI.AbilityID.ION_CANNON, 3)
            table.insert(res, pet)
        elseif pet_id == AI.PetID.CROW then
            local pet = AI.Pet.new(AI.PetID.CROW, 1465, 289, 273, AI.TypeID.FLYING)
            pet:install_ability_by_id(AI.AbilityID.ALPHA_STRIKE, 1) -- 乱舞
            pet:install_ability_by_id(AI.AbilityID.CALL_DARKNESS, 2) -- 召唤
            pet:install_ability_by_id(AI.AbilityID.NOCTURNAL_STRIKE, 3) -- 钻地
            table.insert(res, pet)
        elseif pet_id == AI.PetID.FIENDISH_LMP then
            local pet = AI.Pet.new(AI.PetID.FIENDISH_LMP, 1359, 260, 333, AI.TypeID.HUMANOID)
            pet:install_ability_by_id(AI.AbilityID.BURN, 1)
            pet:install_ability_by_id(AI.AbilityID.IMMOLATION, 2)
            pet:install_ability_by_id(AI.AbilityID.NETHER_GATE, 3)
            table.insert(res, pet)
        elseif pet_id == AI.PetID.EMPERPR_CRAB then
            local pet = AI.Pet.new(AI.PetID.EMPERPR_CRAB, 1481, 358, 211, AI.TypeID.AQUATIC)
            pet:install_ability_by_id(AI.AbilityID.SURGE, 1)
            pet:install_ability_by_id(AI.AbilityID.HEALING_WAVE, 2)
            pet:install_ability_by_id(AI.AbilityID.SHELL_SHIELD, 3)
            table.insert(res, pet)
        elseif pet_id == AI.PetID.SCAVENGING_PINCHER then
            local pet = AI.Pet.new(AI.PetID.SCAVENGING_PINCHER, 1287, 289, 249, AI.TypeID.AQUATIC)
            pet:install_ability_by_id(AI.AbilityID.BUBBLE_BURST, 1)
            pet:install_ability_by_id(AI.AbilityID.SHELL_RUSH, 2)
            pet:install_ability_by_id(AI.AbilityID.BUBBLE, 3)
            table.insert(res, pet)
        end
    end
    return res
end

local function init_game_state()
    local pets1 = create_test_pets({AI.PetID.ARFUS, AI.PetID.DARKMOON_TONK, AI.PetID.CROW})
    local pets2 = create_test_pets({AI.PetID.EMPERPR_CRAB, AI.PetID.ARFUS, AI.PetID.FIENDISH_LMP})
    local game = AI.Game.new()
    assert(#pets1 == 3 and #pets2 == 3, "每队必须有3只宠物")
    game.Rule.teams[1] = pets1
    game.Rule.teams[2] = pets2
    -- 初始化队伍状态
    for player = 1, 2 do
        local team_state = AI.TeamState.new()
        for i, pet in ipairs(game.Rule.teams[player]) do
            AI.Explain.printPet(pet)
            local pet_state = AI.PetState.new(pet.health)
            table.insert(team_state.pets, pet_state)
        end
        team_state.active_index = 0 -- 对局初始双方都未选择首发的状态
        game.State.team_states[player] = team_state

    end
    -- setmetatable(game.State, {__index = AI.Game.State})
    game.State.round = 0
    game.State.change_round = 3
    return game
end

function TestAI:simulation()
    local game = init_game_state()
    local result = AI.DUCT_MCTS.Searcher.simulate_game(game.State, game.Rule, {
        iterations = 2500,
        exploration_c = 1.414
    }, 50)
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
        AI.Explain.printState(state, rule.teams)

        -- 获取双方的合法动作
        local player_actions = rule:get_legal_actions(state, 1)
        local ai_actions = rule:get_legal_actions(state, 2)

        -- 计算每个动作的评分
        local function get_action_score(rule, state, player, action)
            return rule:evaluate_action(state, player, action)
        end

        -- 生成动作描述
        local function get_action_description(rule, state, player, action)
            if action.type == 'use' then
                local pet = rule.teams[player][state.team_states[player].active_index]
                local ability = pet:get_ability(action.value)
                return string.format("技能 %d: %s", action.value, AI.Explain.getAbilityName(ability.id))
            elseif action.type == 'change' then
                local pet = rule.teams[player][action.value]
                return string.format("换宠到 %d: %s", action.value, AI.Explain.getPetName(pet.id))
            elseif action.type == 'standby' then
                return "待命"
            else
                return "未知动作"
            end
        end

        -- 显示双方可选动作（横向排列）
        print("\n双方可选动作：")
        print("┌─────────────────────────────────────────┬─────────────────────────────────────────┐")
        print("│                玩家1 (你)               │                玩家2 (AI)               │")
        print("├─────────────────────────────────────────┼─────────────────────────────────────────┤")
        
        -- 计算最大行数
        local max_rows = math.max(#player_actions, #ai_actions)
        for i = 1, max_rows do
            local player_action = player_actions[i]
            local ai_action = ai_actions[i]
            
            local player_desc = ""
            local player_score = ""
            if player_action then
                player_desc = get_action_description(rule, state, 1, player_action)
                player_score = string.format("%.2f", get_action_score(rule, state, 1, player_action))
            end
            
            local ai_desc = ""
            local ai_score = ""
            if ai_action then
                ai_desc = get_action_description(rule, state, 2, ai_action)
                ai_score = string.format("%.2f", get_action_score(rule, state, 2, ai_action))
            end
            
            -- 格式化输出
            local player_str = string.format("%d. %s (%.2f)", i, player_desc, tonumber(player_score) or 0)
            local ai_str = string.format("%d. %s (%.2f)", i, ai_desc, tonumber(ai_score) or 0)
            
            -- 确保对齐
            player_str = string.sub(player_str, 1, 38)
            ai_str = string.sub(ai_str, 1, 38)
            
            print(string.format("│ %-38s │ %-38s │", player_str, ai_str))
        end
        print("└─────────────────────────────────────────┴─────────────────────────────────────────┘")

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
            iterations = 2500,
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
        print("应用动作后状态：change_round:", state.change_round)

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
        simulation = self.simulation, -- AI vs AI
        play = self.humanVsAi, -- 手动 vs AI
        manual = self.manual_simulation -- 手动 vs 手动
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

    print("\n" .. os.date("%Y-%m-%d %H:%M:%S") .. "\n运行模式: " .. mode)
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
