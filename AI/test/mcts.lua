-- duct_mcts_template.lua
-- 通用DUCT MCTS算法模板，适用于同时移动游戏

local math = require("math")

-- ==================== 导出模块 ====================

local DUCT_MCTS = {}

local Rules = {

    constant_sum = 1,  -- 常和游戏的总奖励

    get_legal_actions = function(state, player)
        -- 返回玩家在给定状态下的合法动作列表
        error("get_legal_actions not implemented")
    end,

    apply_joint_action = function(state, action1, action2)
        -- 应用两个玩家的动作，返回新状态
        error("apply_joint_action not implemented")
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
    
}  -- 游戏规则接口，需要用户实现

-- ==================== 配置 ====================
DUCT_MCTS.Config = {
    exploration_constant = 1.414,  -- 默认探索系数 √2
    max_simulation_depth = 100,    -- 模拟最大深度
    enable_debug_log = false       -- 调试日志开关
}

-- ==================== 树节点定义 ====================
DUCT_MCTS.Node = {
    state = nil,           -- 游戏状态
    children = {},         -- 子节点映射表
    stats = {[1] = {}, [2] = {}}, -- 玩家动作统计
    total_visits = 0,      -- 节点总访问次数
    is_terminal = false,   -- 是否为终局节点
    
    -- 构造函数
    new = function(self, state, game_rules)
        local node = {
            state = state,
            children = {},
            stats = {[1] = {}, [2] = {}},
            total_visits = 0,
            is_terminal = game_rules.is_terminal(state),
            _game_rules = game_rules  -- 保存游戏规则引用
        }
        setmetatable(node, {__index = self})
        
        -- 初始化统计信息
        if not node.is_terminal then
            for player = 1, 2 do
                local actions = game_rules.get_legal_actions(state, player)
                for _, action in ipairs(actions) do
                    node.stats[player][action] = {
                        total_reward = 0,
                        visits = 0,
                        average_reward = 0
                    }
                end
            end
        end
        
        return node
    end,
    
    -- 获取动作统计
    get_stats = function(self, player, action)
        return self.stats[player][action] or {
            total_reward = 0,
            visits = 0,
            average_reward = 0
        }
    end,
    
    -- 获取玩家总访问次数
    get_total_visits_for_player = function(self, player)
        local total = 0
        for _, stat in pairs(self.stats[player]) do
            total = total + stat.visits
        end
        return total
    end,
    
    -- 获取子节点
    get_child = function(self, action1, action2)
        local key = self:_make_child_key(action1, action2)
        return self.children[key]
    end,
    
    -- 添加子节点
    add_child = function(self, action1, action2, child_node)
        local key = self:_make_child_key(action1, action2)
        self.children[key] = child_node
    end,
    
    -- 检查是否完全展开
    is_fully_expanded = function(self)
        local actions1 = self._game_rules.get_legal_actions(self.state, 1)
        local actions2 = self._game_rules.get_legal_actions(self.state, 2)
        
        for _, a1 in ipairs(actions1) do
            for _, a2 in ipairs(actions2) do
                if not self:get_child(a1, a2) then
                    return false
                end
            end
        end
        return true
    end,
    
    -- 内部方法：生成子节点键
    _make_child_key = function(self, action1, action2)
        return string.format("%s|%s", tostring(action1), tostring(action2))
    end,
    
    -- 获取未展开的动作对
    get_unexpanded_pairs = function(self)
        local actions1 = self._game_rules.get_legal_actions(self.state, 1)
        local actions2 = self._game_rules.get_legal_actions(self.state, 2)
        local unexpanded = {}
        
        for _, a1 in ipairs(actions1) do
            for _, a2 in ipairs(actions2) do
                if not self:get_child(a1, a2) then
                    table.insert(unexpanded, {a1, a2})
                end
            end
        end
        
        return unexpanded
    end,
    
    -- 打印节点统计（调试用）
    print_stats = function(self, player)
        print(string.format("Node stats (total visits: %d):", self.total_visits))
        
        local player_to_show = player or 1
        local actions = self._game_rules.get_legal_actions(self.state, player_to_show)
        
        for _, action in ipairs(actions) do
            local stats = self:get_stats(player_to_show, action)
            print(string.format("  Player %d - %s: visits=%d, total=%.2f, avg=%.3f",
                  player_to_show, action, stats.visits, stats.total_reward, stats.average_reward))
        end
    end
}

-- ==================== UCB计算函数 ====================
local function calculate_uct_value(node, player, action, exploration_c)
    local stats = node:get_stats(player, action)
    
    -- 从未访问过的动作，给予最高优先级
    if stats.visits == 0 then
        return math.huge
    end
    
    -- 利用项：平均奖励
    local exploitation = stats.average_reward
    
    -- 探索项
    local total_visits = node:get_total_visits_for_player(player)
    if total_visits <= 0 then
        return exploitation
    end
    
    local exploration = exploration_c * math.sqrt(math.log(total_visits) / stats.visits)
    
    return exploitation + exploration
end

-- ==================== DUCT选择策略 ====================
local function select_joint_action_duct(node, exploration_c)
    local game_rules = node._game_rules
    local actions1 = game_rules.get_legal_actions(node.state, 1)
    local actions2 = game_rules.get_legal_actions(node.state, 2)
    
    local best_action1, best_action2
    local best_ucb1, best_ucb2 = -math.huge, -math.huge
    
    -- 玩家1独立选择
    for _, a1 in ipairs(actions1) do
        local ucb = calculate_uct_value(node, 1, a1, exploration_c)
        if ucb > best_ucb1 then
            best_ucb1 = ucb
            best_action1 = a1
        end
    end
    
    -- 玩家2独立选择
    for _, a2 in ipairs(actions2) do
        local ucb = calculate_uct_value(node, 2, a2, exploration_c)
        if ucb > best_ucb2 then
            best_ucb2 = ucb
            best_action2 = a2
        end
    end
    
    -- 回退机制：如果没有有效动作，随机选择
    if not best_action1 and #actions1 > 0 then
        best_action1 = actions1[math.random(#actions1)]
    end
    
    if not best_action2 and #actions2 > 0 then
        best_action2 = actions2[math.random(#actions2)]
    end
    
    return best_action1, best_action2
end

-- ==================== 默认模拟策略 ====================
local function default_simulation_policy(state, game_rules)
    local current_state = state
    local depth = 0
    
    while not game_rules.is_terminal(current_state) and depth < DUCT_MCTS.Config.max_simulation_depth do
        local actions1 = game_rules.get_legal_actions(current_state, 1)
        local actions2 = game_rules.get_legal_actions(current_state, 2)
        
        -- 随机选择动作
        local a1 = actions1[math.random(#actions1)]
        local a2 = actions2[math.random(#actions2)]
        
        current_state = game_rules.apply_joint_action(current_state, a1, a2)
        depth = depth + 1
    end
    
    return game_rules.get_utility(current_state)
end

-- ==================== 单次MCTS模拟 ====================
local function run_simulation(root_node, exploration_c, simulation_policy)
    local path = {}  -- 记录路径：{node, action1, action2}
    local node = root_node
    local game_rules = node._game_rules
    
    -- === 选择阶段 ===
    while not node.is_terminal do
        if not node:is_fully_expanded() then
            break
        end
        
        local action1, action2 = select_joint_action_duct(node, exploration_c)
        local child = node:get_child(action1, action2)
        
        if not child then
            break
        end
        
        table.insert(path, {
            node = node,
            action1 = action1,
            action2 = action2,
            child = child
        })
        node = child
    end
    
    -- === 扩展阶段 ===
    if not node.is_terminal then
        local unexpanded = node:get_unexpanded_pairs()
        
        if #unexpanded > 0 then
            -- 随机选择一个未展开的动作对
            local pair = unexpanded[math.random(#unexpanded)]
            local action1, action2 = pair[1], pair[2]
            
            -- 创建新状态和子节点
            local new_state = game_rules.apply_joint_action(node.state, action1, action2)
            local child_node = DUCT_MCTS.Node:new(new_state, game_rules)
            
            node:add_child(action1, action2, child_node)
            
            table.insert(path, {
                node = node,
                action1 = action1,
                action2 = action2,
                child = child_node
            })
            node = child_node
        end
    end
    
    -- === 模拟阶段 ===
    local utility = 0
    if node.is_terminal then
        utility = game_rules.get_utility(node.state)
    else
        utility = simulation_policy(node.state, game_rules)
    end
    
    local constant_sum = game_rules.constant_sum or 1
    local utility2 = constant_sum - utility  -- 玩家2的奖励
    
    -- === 回溯阶段 ===
    for i = #path, 1, -1 do
        local step = path[i]
        local current_node = step.node
        local action1, action2 = step.action1, step.action2
        
        -- 更新节点总访问次数
        current_node.total_visits = current_node.total_visits + 1
        
        -- 更新玩家1统计
        local stats1 = current_node:get_stats(1, action1)
        stats1.total_reward = stats1.total_reward + utility
        stats1.visits = stats1.visits + 1
        stats1.average_reward = stats1.total_reward / stats1.visits
        
        -- 更新玩家2统计
        local stats2 = current_node:get_stats(2, action2)
        stats2.total_reward = stats2.total_reward + utility2
        stats2.visits = stats2.visits + 1
        stats2.average_reward = stats2.total_reward / stats2.visits
    end
    
    -- 更新当前节点（如果不在路径中）
    if #path == 0 or path[#path].child ~= node then
        node.total_visits = node.total_visits + 1
    end
    
    if DUCT_MCTS.Config.enable_debug_log then
        print(string.format("Simulation completed. Utility: %.3f, Path length: %d", utility, #path))
    end
end

-- ==================== MCTS搜索器 ====================
DUCT_MCTS.Searcher = {
    -- 运行MCTS搜索
    run_search = function(initial_state, game_rules, options)
        options = options or {}
        local iterations = options.iterations or 1000
        local exploration_c = options.exploration_c or DUCT_MCTS.Config.exploration_constant
        local simulation_policy = options.simulation_policy or default_simulation_policy
        local time_budget_ms = options.time_budget_ms
        
        print(string.format("Starting DUCT-MCTS search (%d iterations)...", iterations))
        
        local root_node = DUCT_MCTS.Node:new(initial_state, game_rules)
        local start_time = os.clock()
        local completed_iterations = 0
        
        for i = 1, iterations do
            -- 检查时间预算
            if time_budget_ms then
                local current_time = os.clock()
                if (current_time - start_time) * 1000 >= time_budget_ms then
                    print(string.format("Time budget exceeded after %d iterations", i-1))
                    break
                end
            end
            
            run_simulation(root_node, exploration_c, simulation_policy)
            completed_iterations = i
            
            -- 进度显示
            if i % 500 == 0 then
                local elapsed = (os.clock() - start_time) * 1000
                print(string.format("  Completed %d iterations (%.1f ms)", i, elapsed))
            end
        end
        
        local total_time = (os.clock() - start_time) * 1000
        print(string.format("Search completed: %d iterations in %.1f ms (%.1f iter/sec)", 
              completed_iterations, total_time, completed_iterations / (total_time / 1000)))
        
        return root_node
    end,
    
    -- 选择最佳动作（基于最高平均奖励）
    select_best_action = function(node, player)
        local game_rules = node._game_rules
        local actions = game_rules.get_legal_actions(node.state, player)
        
        local best_action = nil
        local best_avg_reward = -math.huge
        
        for _, action in ipairs(actions) do
            local stats = node:get_stats(player, action)
            if stats.visits > 0 and stats.average_reward > best_avg_reward then
                best_avg_reward = stats.average_reward
                best_action = action
            end
        end
        
        -- 回退：随机选择
        if not best_action and #actions > 0 then
            best_action = actions[math.random(#actions)]
        end
        
        return best_action
    end,
    
    -- 选择UCT值最高的动作（用于tree policy）
    select_uct_action = function(node, player, exploration_c)
        exploration_c = exploration_c or DUCT_MCTS.Config.exploration_constant
        local game_rules = node._game_rules
        local actions = game_rules.get_legal_actions(node.state, player)
        
        local best_action = nil
        local best_uct = -math.huge
        
        for _, action in ipairs(actions) do
            local uct = calculate_uct_value(node, player, action, exploration_c)
            if uct > best_uct then
                best_uct = uct
                best_action = action
            end
        end
        
        return best_action
    end,
    
    -- 获取动作的概率分布（基于访问次数）
    get_action_distribution = function(node, player, temperature)
        temperature = temperature or 1.0  -- 温度参数，1.0为原始分布
        local game_rules = node._game_rules
        local actions = game_rules.get_legal_actions(node.state, player)
        local distribution = {}
        local total_visits = 0
        
        -- 计算总访问次数
        for _, action in ipairs(actions) do
            local stats = node:get_stats(player, action)
            total_visits = total_visits + stats.visits
        end
        
        -- 计算分布
        for _, action in ipairs(actions) do
            local stats = node:get_stats(player, action)
            local prob
            if total_visits > 0 then
                prob = (stats.visits / total_visits) ^ (1 / temperature)
            else
                prob = 1 / #actions  -- 均匀分布
            end
            distribution[action] = prob
        end
        
        -- 归一化
        local sum = 0
        for _, prob in pairs(distribution) do
            sum = sum + prob
        end
        for action, prob in pairs(distribution) do
            distribution[action] = prob / sum
        end
        
        return distribution
    end,
    
    -- 模拟完整游戏
    simulate_game = function(initial_state, game_rules, search_options, max_rounds)
        max_rounds = max_rounds or 20
        search_options = search_options or {iterations = 1000}
        
        print("=== 游戏模拟开始 ===")
        
        local state = initial_state
        local round_history = {}
        
        for round = 1, max_rounds do
            print(string.format("\n回合 %d:", round))
            
            if game_rules.is_terminal(state) then
                local winner = game_rules.get_winner(state)
                if winner == 1 then
                    print("游戏结束！玩家1获胜！")
                elseif winner == 2 then
                    print("游戏结束！玩家2获胜！")
                elseif winner == 3 then
                    print("游戏结束！平局！")
                end
                break
            end
            
            -- 显示当前状态
            if game_rules.print_state then
                game_rules.print_state(state)
            end
            
            -- 为当前状态运行MCTS
            local root_node = DUCT_MCTS.Searcher.run_search(state, game_rules, search_options)
            
            -- 选择动作
            local action1 = DUCT_MCTS.Searcher.select_best_action(root_node, 1)
            local action2 = DUCT_MCTS.Searcher.select_best_action(root_node, 2)
            
            print(string.format("  玩家1选择: %s", action1))
            print(string.format("  玩家2选择: %s", action2))
            
            -- 记录历史
            table.insert(round_history, {
                round = round,
                state = state,
                action1 = action1,
                action2 = action2
            })
            
            -- 应用动作
            state = game_rules.apply_joint_action(state, action1, action2)
        end
        
        if not game_rules.is_terminal(state) then
            print("\n达到最大回合数，游戏结束！")
        end
        
        print("\n=== 游戏模拟结束 ===")
        
        return {
            final_state = state,
            history = round_history,
            total_rounds = #round_history
        }
    end
}

return DUCT_MCTS