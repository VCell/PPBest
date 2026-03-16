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
local PetsDataPath = "AI/PetsData.lua"
local SearchPath = "AI/Search.lua"
local PlayPath = "AI/Play.lua"

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
dofile(PetsDataPath)
dofile(PlayPath)
dofile(SearchPath)


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
            pet:install_ability_by_id(AI.AbilityID.STONE_SHOT, 1)   -- 石子护盾
            pet:install_ability_by_id(AI.AbilityID.RUPTURE, 2)    -- 石子猛击
            pet:install_ability_by_id(AI.AbilityID.ROCK_BARRAGE, 3)     -- 石子暴击
            table.insert(res, pet)
        end
    end
    return res
end

local function init_game_state()
    local pets1 = create_test_pets({AI.PetID.SPRING_RABBIT, AI.PetID.PEBBLE,AI.PetID.ARFUS})
    local pets2 = create_test_pets({AI.PetID.SPRING_RABBIT, AI.PetID.PEBBLE,AI.PetID.ARFUS})
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
        team_state.active_index = 0  -- 默认第一只宠物出战
        game.State.team_states[player] = team_state

    end
    setmetatable(game.State, {__index = AI.Game.State})
    game.State.round = 0
    game.State.change_round = 3
    return game
end

function TestAI:simulation()
    local game = init_game_state()
    local result = AI.DUCT_MCTS.Searcher.simulate_game(game.State,  
        game.Rule,           
            {
                iterations = 500,
                exploration_c = 1.414,
            },30)
end


-- 运行所有测试
function TestAI:runAllTests()
    print("==================================================")
    print(self.name .. " v" .. self.version)
    print("==================================================")
    
    self:simulation()

    print("\n==================================================")
    print("所有测试完成！")
    print("==================================================")
end

-- 运行测试
TestAI:runAllTests()

-- 导出测试模块
return {
    TestAI = TestAI
}
