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
local PlayPath = "AI/Play.lua"
local SearchPath = "AI/Search.lua"

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

-- 测试Pet类
function TestAI:testPetClass()
    print("\n=== 测试Pet类 ===")
    
    -- 创建测试宠物
    local pet = AI.Pet.new(AI.PetID.SPRING_RABBIT, 1000, 25, 200, AI.TypeID.CRITTER)
    print("创建宠物: 春兔 (ID: " .. pet.id .. ")")
    print("  生命值: " .. pet.health)
    print("  攻击力: " .. pet.power)
    print("  速度: " .. pet.speed)
    print("  类型: " .. pet.type)
    
    -- 测试安装技能
    print("\n测试安装技能:")
    local ability1 = pet:install_ability_by_id(AI.AbilityID.FLURRY, 1)
    local ability2 = pet:install_ability_by_id(AI.AbilityID.DODGE, 2)
    local ability3 = pet:install_ability_by_id(AI.AbilityID.BURROW, 3)
    
    if ability1 then
        print("  技能1: 乱舞 (ID: " .. ability1.id .. ")")
    end
    if ability2 then
        print("  技能2: 闪避 (ID: " .. ability2.id .. ")")
    end
    if ability3 then
        print("  技能3: 钻地 (ID: " .. ability3.id .. ")")
    end
    
    -- 测试默认技能
    print("\n测试默认技能:")
    pet:install_default_ability()
    local defaultAbility = pet:get_ability(1)
    if defaultAbility then
        print("  默认技能: ID=" .. defaultAbility.id)
    end
end

-- 测试TypeID模块
function TestAI:testTypeID()
    print("\n=== 测试TypeID模块 ===")
    
    local testCases = {
        {attack = AI.TypeID.HUMANOID, target = AI.TypeID.DRAGONKIN, expected = 1.5, desc = "人类对龙类"},
        {attack = AI.TypeID.DRAGONKIN, target = AI.TypeID.MAGIC, expected = 1.5, desc = "龙类对魔法"},
        {attack = AI.TypeID.MAGIC, target = AI.TypeID.FLYING, expected = 1.5, desc = "魔法对飞行"},
        {attack = AI.TypeID.FLYING, target = AI.TypeID.AQUATIC, expected = 1.5, desc = "飞行对水生"},
        {attack = AI.TypeID.AQUATIC, target = AI.TypeID.ELEMENTAL, expected = 1.5, desc = "水生对元素"},
        {attack = AI.TypeID.ELEMENTAL, target = AI.TypeID.MECHANICAL, expected = 1.5, desc = "元素对机械"},
        {attack = AI.TypeID.MECHANICAL, target = AI.TypeID.BEAST, expected = 1.5, desc = "机械对野兽"},
        {attack = AI.TypeID.BEAST, target = AI.TypeID.CRITTER, expected = 1.5, desc = "野兽对小动物"},
        {attack = AI.TypeID.CRITTER, target = AI.TypeID.UNDEAD, expected = 1.5, desc = "小动物对亡灵"},
        {attack = AI.TypeID.UNDEAD, target = AI.TypeID.HUMANOID, expected = 1.5, desc = "亡灵对人类"},
        
        {attack = AI.TypeID.HUMANOID, target = AI.TypeID.BEAST, expected = 0.66, desc = "人类对野兽"},
        {attack = AI.TypeID.BEAST, target = AI.TypeID.FLYING, expected = 0.66, desc = "野兽对飞行"},
        {attack = AI.TypeID.FLYING, target = AI.TypeID.DRAGONKIN, expected = 0.66, desc = "飞行对龙类"},
        {attack = AI.TypeID.DRAGONKIN, target = AI.TypeID.UNDEAD, expected = 0.66, desc = "龙类对亡灵"},
        {attack = AI.TypeID.UNDEAD, target = AI.TypeID.AQUATIC, expected = 0.66, desc = "亡灵对水生"},
        {attack = AI.TypeID.AQUATIC, target = AI.TypeID.MAGIC, expected = 0.66, desc = "水生对魔法"},
        {attack = AI.TypeID.MAGIC, target = AI.TypeID.MECHANICAL, expected = 0.66, desc = "魔法对机械"},
        {attack = AI.TypeID.MECHANICAL, target = AI.TypeID.ELEMENTAL, expected = 0.66, desc = "机械对元素"},
        {attack = AI.TypeID.ELEMENTAL, target = AI.TypeID.CRITTER, expected = 0.66, desc = "元素对小动物"},
        {attack = AI.TypeID.CRITTER, target = AI.TypeID.HUMANOID, expected = 0.66, desc = "小动物对人类"},
        
        {attack = AI.TypeID.HUMANOID, target = AI.TypeID.HUMANOID, expected = 1.0, desc = "人类对人类"},
    }
    
    for _, test in ipairs(testCases) do
        local result = AI.TypeID.GetEffectiveness(test.attack, test.target)
        local status = result == test.expected and "✓" or "✗"
        print(string.format("%s %s: 期望=%.2f, 实际=%.2f", status, test.desc, test.expected, result))
    end
end

-- 测试Aura模块
function TestAI:testAura()
    print("\n=== 测试Aura模块 ===")
    
    local testCases = {
        {auraId = AI.AuraID.ICE_TOMB, power = 20, desc = "寒冰之墓"},
        {auraId = AI.AuraID.UNDEAD, power = 20, desc = "亡灵"},
        {auraId = AI.AuraID.SHATTER_DEFENSE, power = 20, desc = "破碎防御"},
        {auraId = AI.AuraID.DODGE, power = 20, desc = "闪避"},
        {auraId = AI.AuraID.UNDERGROUND, power = 20, desc = "钻地"},
        {auraId = AI.AuraID.STUN, power = 20, desc = "眩晕"},
        {auraId = AI.AuraID.ROCK_BARRAGE, power = 20, desc = "岩石弹幕"},
    }
    
    for _, test in ipairs(testCases) do
        local aura = AI.Aura.new_aura_by_id(test.auraId, test.power)
        if aura then
            print("  " .. test.desc .. ":")
            print("    ID: " .. aura.id)
            print("    类型: " .. aura.type)
            print("    持续时间: " .. aura.duration)
            print("    保持在前排: " .. (aura.keep_front and "是" or "否"))
            if aura.effects then
                print("    效果数量: " .. #aura.effects)
            end
        else
            print("  " .. test.desc .. ": 创建失败")
        end
    end
end

-- 测试Ability模块
function TestAI:testAbility()
    print("\n=== 测试Ability模块 ===")
    
    -- 创建测试宠物
    local pet = AI.Pet.new(AI.PetID.SPRING_RABBIT, 1000, 25, 200, AI.TypeID.CRITTER)
    
    -- 测试各种技能
    local abilities = {
        {id = AI.AbilityID.FLURRY, index = 1, desc = "乱舞"},
        {id = AI.AbilityID.DODGE, index = 2, desc = "闪避"},
        {id = AI.AbilityID.BURROW, index = 3, desc = "钻地"},
    }
    
    for _, abilityInfo in ipairs(abilities) do
        local ability = pet:install_ability_by_id(abilityInfo.id, abilityInfo.index)
        if ability then
            print("  " .. abilityInfo.desc .. ":")
            print("    ID: " .. ability.id)
            print("    类型: " .. ability.type)
            print("    冷却: " .. ability.cooldown)
            print("    持续时间: " .. ability.duration)
            print("    总是先手: " .. (ability.aways_first and "是" or "否"))
            print("    效果回合数: " .. #ability.effect_list)
        else
            print("  " .. abilityInfo.desc .. ": 安装失败")
        end
    end
end

-- 测试数据常量
function TestAI:testConstants()
    print("\n=== 测试数据常量 ===")
    
    print("PetID常量:")
    local petIds = {"MOJO", "SPRING_RABBIT", "PANDAREN_MONK", "PEBBLE", "ARFUS"}
    for _, id in ipairs(petIds) do
        print("  " .. id .. ": " .. AI.PetID[id])
    end
    
    print("\nAbilityID常量:")
    local abilityIds = {"NONE", "BURROW", "DODGE", "FLURRY", "STONE_SHOT", "RUPTURE"}
    for _, id in ipairs(abilityIds) do
        print("  " .. id .. ": " .. AI.AbilityID[id])
    end
    
    print("\nTypeID常量:")
    local typeIds = {"HUMANOID", "DRAGONKIN", "FLYING", "UNDEAD", "CRITTER", "MAGIC", "ELEMENTAL", "BEAST", "AQUATIC", "MECHANICAL"}
    for _, id in ipairs(typeIds) do
        print("  " .. id .. ": " .. AI.TypeID[id])
    end
end

-- 运行所有测试
function TestAI:runAllTests()
    print("==================================================")
    print(self.name .. " v" .. self.version)
    print("==================================================")
    
    self:testPetClass()
    self:testTypeID()
    self:testAura()
    self:testAbility()
    self:testConstants()
    
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
