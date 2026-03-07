-- charge_attack_game.lua
-- 蓄力进攻游戏的具体实现

local DUCT_MCTS = require("mcts")

-- ==================== 游戏定义 ====================
local ChargeAttackGame = {
    name = "蓄力进攻游戏",
    version = "1.0",
    author = "Game AI"
}

-- ==================== 游戏规则实现 ====================
ChargeAttackGame.Rules = {
    constant_sum = 1,  -- 常和博弈
    
    -- 获取当前玩家（同时移动游戏，双方都行动）
    get_current_player = function(state)
        return 1  -- 同时移动，返回1表示双方都行动
    end,
    
    -- 获取玩家合法动作
    get_legal_actions = function(state, player)
        -- 三种动作：防御(D)，进攻(A)，蓄力(C)
        -- 注意：没有蓄力时不能进攻
        local actions = {"D", "C"}  -- 总是可以防御或蓄力
        
        -- 检查是否可以进攻
        local player_data = (player == 1) and state.player1 or state.player2
        if player_data.charge > 0 then
            table.insert(actions, "A")
        end
        
        return actions
    end,
    
    -- 应用联合动作，返回新状态
    apply_joint_action = function(state, action1, action2)
        -- 创建新状态的深拷贝
        local new_state = {
            player1 = {
                charge = state.player1.charge,
                has_attack_opportunity = state.player1.has_attack_opportunity,
                last_action = action1
            },
            player2 = {
                charge = state.player2.charge,
                has_attack_opportunity = state.player2.has_attack_opportunity,
                last_action = action2
            },
            round = state.round + 1,
            game_over = false,
            winner = 0,  -- 0: 无, 1: 玩家1胜, 2: 玩家2胜, 3: 平局
            history = state.history or {}
        }
        
        -- 添加历史记录
        table.insert(new_state.history, {
            round = state.round,
            action1 = action1,
            action2 = action2,
            charge1 = state.player1.charge,
            charge2 = state.player2.charge
        })
        
        -- 处理玩家1的动作
        if action1 == "C" then  -- 蓄力
            new_state.player1.charge = new_state.player1.charge + 1
            new_state.player1.has_attack_opportunity = true
        elseif action1 == "A" then  -- 进攻
            if new_state.player1.charge > 0 then
                new_state.player1.charge = new_state.player1.charge - 1
                -- 进攻逻辑在下面统一处理
            else
                -- 没有蓄力不能进攻，自动转为防御
                action1 = "D"
                new_state.player1.last_action = "D"
            end
        end
        -- 防御(D)不做特殊处理
        
        -- 处理玩家2的动作
        if action2 == "C" then  -- 蓄力
            new_state.player2.charge = new_state.player2.charge + 1
            new_state.player2.has_attack_opportunity = true
        elseif action2 == "A" then  -- 进攻
            if new_state.player2.charge > 0 then
                new_state.player2.charge = new_state.player2.charge - 1
            else
                action2 = "D"
                new_state.player2.last_action = "D"
            end
        end
        
        -- 检查蓄力胜利条件（3次蓄力直接获胜）
        local charge_win = false
        
        if new_state.player1.charge >= 3 and new_state.player2.charge >= 3 then
            -- 双方同时达到3蓄力，平局
            new_state.game_over = true
            new_state.winner = 3
            new_state.win_reason = "双方同时达到3次蓄力"
            charge_win = true
        elseif new_state.player1.charge >= 3 then
            -- 玩家1达到3蓄力获胜
            new_state.game_over = true
            new_state.winner = 1
            new_state.win_reason = "玩家1达到3次蓄力"
            charge_win = true
        elseif new_state.player2.charge >= 3 then
            -- 玩家2达到3蓄力获胜
            new_state.game_over = true
            new_state.winner = 2
            new_state.win_reason = "玩家2达到3次蓄力"
            charge_win = true
        end
        
        -- 如果不是蓄力胜利，检查攻击结果
        if not charge_win then
            -- 玩家1进攻，玩家2不防御
            if action1 == "A" and action2 ~= "D" then
                new_state.game_over = true
                new_state.winner = 1
                new_state.win_reason = "玩家1进攻，玩家2未防御"
            -- 玩家2进攻，玩家1不防御
            elseif action2 == "A" and action1 ~= "D" then
                new_state.game_over = true
                new_state.winner = 2
                new_state.win_reason = "玩家2进攻，玩家1未防御"
            -- 双方同时进攻
            elseif action1 == "A" and action2 == "A" then
                new_state.game_over = true
                new_state.winner = 3
                new_state.win_reason = "双方同时进攻"
            end
        end
        
        -- 防止无限循环，最多20回合
        if new_state.round >= 20 and not new_state.game_over then
            new_state.game_over = true
            if new_state.player1.charge > new_state.player2.charge then
                new_state.winner = 1
                new_state.win_reason = "回合数达到上限，玩家1蓄力更多"
            elseif new_state.player2.charge > new_state.player1.charge then
                new_state.winner = 2
                new_state.win_reason = "回合数达到上限，玩家2蓄力更多"
            else
                new_state.winner = 3
                new_state.win_reason = "回合数达到上限，双方蓄力相同"
            end
        end
        
        return new_state
    end,
    
    -- 判断是否终局
    is_terminal = function(state)
        return state.game_over or state.round >= 20
    end,
    
    -- 获取获胜者
    get_winner = function(state)
        return state.winner or 0
    end,
    
    -- 获取终局奖励（玩家1视角）
    get_utility = function(state)
        if not state.game_over and state.round >= 20 then
            -- 超时情况，根据蓄力多少判断
            if state.player1.charge > state.player2.charge then
                return 0.7  -- 略有优势
            elseif state.player2.charge > state.player1.charge then
                return 0.3  -- 略有劣势
            else
                return 0.5  -- 平局
            end
        end
        
        if state.winner == 1 then
            return 1.0  -- 玩家1胜利
        elseif state.winner == 2 then
            return 0.0  -- 玩家1失败
        elseif state.winner == 3 then
            return 0.5  -- 平局
        else
            return 0.5  -- 默认平局
        end
    end,
    
    -- 打印游戏状态
    print_state = function(state)
        print(string.format("  回合: %d", state.round))
        print(string.format("  玩家1: 蓄力%d次, 上次动作: %s", 
              state.player1.charge, state.player1.last_action or "-"))
        print(string.format("  玩家2: 蓄力%d次, 上次动作: %s", 
              state.player2.charge, state.player2.last_action or "-"))
        
        if state.game_over then
            print(string.format("  游戏结束! 原因: %s", state.win_reason or "未知"))
        end
    end,
    
    -- 创建初始状态
    create_initial_state = function()
        return {
            player1 = {
                charge = 0,
                has_attack_opportunity = false,
                last_action = nil
            },
            player2 = {
                charge = 0,
                has_attack_opportunity = false,
                last_action = nil
            },
            round = 1,
            game_over = false,
            winner = 0,
            history = {}
        }
    end,
    
    -- 动作说明
    get_action_description = function(action)
        local descriptions = {
            D = "防御 - 抵挡对方的进攻",
            A = "进攻 - 消耗1次蓄力攻击对方",
            C = "蓄力 - 积累1次蓄力，为进攻做准备"
        }
        return descriptions[action] or "未知动作"
    end,
    
    -- 游戏规则说明
    print_rules = function()
        print("\n=== 蓄力进攻游戏规则 ===")
        print("动作类型:")
        print("  D - 防御: " .. ChargeAttackGame.Rules.get_action_description("D"))
        print("  A - 进攻: " .. ChargeAttackGame.Rules.get_action_description("A"))
        print("  C - 蓄力: " .. ChargeAttackGame.Rules.get_action_description("C"))
        print("\n胜利条件:")
        print("  1. 进攻时对方没有防御 → 立即获胜")
        print("  2. 累积3次蓄力 → 下回合自动获胜")
        print("  3. 双方同时达到3蓄力或同时进攻 → 平局")
        print("  4. 20回合未分胜负 → 根据蓄力数量判断胜负")
        print("\n限制:")
        print("  - 没有蓄力时不能进攻")
        print("  - 每次进攻消耗1次蓄力")
        print("  - 蓄力可以累积，最多3次")
    end
}

-- ==================== 自定义模拟策略 ====================
local function smart_simulation_policy(state, game_rules)
    -- 比完全随机更智能的模拟策略
    local current_state = state
    local depth = 0
    local max_depth = 10  -- 模拟深度限制
    
    while not game_rules.is_terminal(current_state) and depth < max_depth do
        local actions1 = game_rules.get_legal_actions(current_state, 1)
        local actions2 = game_rules.get_legal_actions(current_state, 2)
        
        local a1, a2
        
        -- 智能选择：优先考虑有蓄力时的进攻，或对方没蓄力时的蓄力
        local p1_charge = current_state.player1.charge
        local p2_charge = current_state.player2.charge
        
        if p1_charge >= 2 then
            -- 有2次以上蓄力，可以冒险进攻
            a1 = (math.random() < 0.6) and "A" or (math.random() < 0.5 and "C" or "D")
        elseif p1_charge == 1 then
            -- 有1次蓄力，小心选择
            if p2_charge == 0 then
                a1 = (math.random() < 0.7) and "C" or "D"  -- 对方没蓄力，优先蓄力
            else
                a1 = (math.random() < 0.4) and "A" or (math.random() < 0.6 and "C" or "D")
            end
        else
            -- 没蓄力，只能防御或蓄力
            a1 = (math.random() < 0.7) and "C" or "D"
        end
        
        -- 确保选择的动作合法
        if a1 == "A" and not table.contains(actions1, "A") then
            a1 = (math.random() < 0.5) and "C" or "D"
        end
        
        -- 玩家2的智能选择（类似逻辑）
        if p2_charge >= 2 then
            a2 = (math.random() < 0.6) and "A" or (math.random() < 0.5 and "C" or "D")
        elseif p2_charge == 1 then
            if p1_charge == 0 then
                a2 = (math.random() < 0.7) and "C" or "D"
            else
                a2 = (math.random() < 0.4) and "A" or (math.random() < 0.6 and "C" or "D")
            end
        else
            a2 = (math.random() < 0.7) and "C" or "D"
        end
        
        if a2 == "A" and not table.contains(actions2, "A") then
            a2 = (math.random() < 0.5) and "C" or "D"
        end
        
        current_state = game_rules.apply_joint_action(current_state, a1, a2)
        depth = depth + 1
    end
    
    return game_rules.get_utility(current_state)
end

-- 辅助函数：检查表中是否包含元素
table.contains = function(t, value)
    for _, v in ipairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

-- ==================== 示例和测试函数 ====================
ChargeAttackGame.Examples = {
    -- 示例1：基础游戏模拟
    run_basic_simulation = function()
        print("\n" .. string.rep("=", 50))
        print("蓄力进攻游戏 - 基础模拟")
        print(string.rep("=", 50))
        
        ChargeAttackGame.Rules.print_rules()
        
        local initial_state = ChargeAttackGame.Rules.create_initial_state()
        
        local result = DUCT_MCTS.Searcher.simulate_game(
            initial_state,
            ChargeAttackGame.Rules,
            {
                iterations = 800,
                exploration_c = 1.414,
                simulation_policy = smart_simulation_policy
            },
            15  -- 最多15回合
        )
        
        print(string.format("\n游戏持续了 %d 回合", result.total_rounds))
        
        -- 打印历史记录
        print("\n=== 游戏历史 ===")
        for i, record in ipairs(result.history) do
            print(string.format("回合 %d: 玩家1(%s, 蓄力%d) vs 玩家2(%s, 蓄力%d)",
                  record.round,
                  record.action1, record.charge1 or 0,
                  record.action2, record.charge2 or 0))
        end
    end,
    
    -- 示例2：策略分析
    analyze_strategy = function()
        print("\n" .. string.rep("=", 50))
        print("策略分析")
        print(string.rep("=", 50))
        
        local test_cases = {
            {
                name = "开局局面",
                state = ChargeAttackGame.Rules.create_initial_state()
            },
            {
                name = "玩家1有1次蓄力",
                state = function()
                    local s = ChargeAttackGame.Rules.create_initial_state()
                    s.player1.charge = 1
                    s.player1.has_attack_opportunity = true
                    return s
                end
            },
            {
                name = "玩家1有2次蓄力",
                state = function()
                    local s = ChargeAttackGame.Rules.create_initial_state()
                    s.player1.charge = 2
                    s.player1.has_attack_opportunity = true
                    return s
                end
            },
            {
                name = "双方各有1次蓄力",
                state = function()
                    local s = ChargeAttackGame.Rules.create_initial_state()
                    s.player1.charge = 1
                    s.player2.charge = 1
                    s.player1.has_attack_opportunity = true
                    s.player2.has_attack_opportunity = true
                    return s
                end
            }
        }
        
        for _, test_case in ipairs(test_cases) do
            print(string.format("\n分析: %s", test_case.name))
            
            local state
            if type(test_case.state) == "function" then
                state = test_case.state()
            else
                state = test_case.state
            end
            
            ChargeAttackGame.Rules.print_state(state)
            
            -- 运行MCTS分析
            local root_node = DUCT_MCTS.Searcher.run_search(
                state,
                ChargeAttackGame.Rules,
                {
                    iterations = 2000,
                    exploration_c = 1.414
                }
            )
            
            -- 分析玩家1的策略
            print("  玩家1策略分析:")
            local dist1 = DUCT_MCTS.Searcher.get_action_distribution(root_node, 1)
            for action, prob in pairs(dist1) do
                local desc = ChargeAttackGame.Rules.get_action_description(action)
                print(string.format("    %s: %.1f%% - %s", 
                      action, prob * 100, desc))
            end
            
            -- 分析玩家2的策略
            print("  玩家2策略分析:")
            local dist2 = DUCT_MCTS.Searcher.get_action_distribution(root_node, 2)
            for action, prob in pairs(dist2) do
                local desc = ChargeAttackGame.Rules.get_action_description(action)
                print(string.format("    %s: %.1f%% - %s", 
                      action, prob * 100, desc))
            end
        end
    end,
    
    -- 示例3：性能测试
    run_performance_test = function()
        print("\n" .. string.rep("=", 50))
        print("性能测试")
        print(string.rep("=", 50))
        
        local initial_state = ChargeAttackGame.Rules.create_initial_state()
        
        local test_cases = {
            {iterations = 500, name = "快速测试 (500次)"},
            {iterations = 2000, name = "标准测试 (2000次)"},
            {iterations = 5000, name = "深度测试 (5000次)"}
        }
        
        for _, test in ipairs(test_cases) do
            print(string.format("\n%s:", test.name))
            
            local start_time = os.clock()
            local root_node = DUCT_MCTS.Searcher.run_search(
                initial_state,
                ChargeAttackGame.Rules,
                {
                    iterations = test.iterations,
                    exploration_c = 1.414,
                    simulation_policy = smart_simulation_policy
                }
            )
            local end_time = os.clock()
            
            local elapsed_ms = (end_time - start_time) * 1000
            print(string.format("  时间: %.1f ms", elapsed_ms))
            print(string.format("  速度: %.1f 迭代/秒", test.iterations / (elapsed_ms / 1000)))
            
            -- 显示根节点统计
            print("  根节点统计:")
            root_node:print_stats(1)
        end
    end
}

-- ==================== 主函数 ====================
local function main()
    math.randomseed(os.time())
    
    print("蓄力进攻游戏 AI 模拟系统")
    print("版本: " .. ChargeAttackGame.version)
    print("作者: " .. ChargeAttackGame.author)
    
    -- 运行示例
    ChargeAttackGame.Examples.run_basic_simulation()
    ChargeAttackGame.Examples.analyze_strategy()
    ChargeAttackGame.Examples.run_performance_test()
    
    print("\n" .. string.rep("=", 50))
    print("所有测试完成！")
    print(string.rep("=", 50))
end

-- 运行主函数（如果直接执行此文件）
main()

-- ==================== 导出模块 ====================
return {
    Game = ChargeAttackGame,
    Rules = ChargeAttackGame.Rules,
    Examples = ChargeAttackGame.Examples,
    main = main
}