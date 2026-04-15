local _, PPBest = ...
local AI = PPBest.AI

local Explain = {}

-- 计算字典长度的辅助函数
local function table_length(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- 技能ID到中文名称的映射
local abilityNames = {
    [1] = "默认技能",
    [113] = "燃烧",
    [123] = "治疗波",
    [159] = "钻地",
    [209] = "离子炮",
    [210] = "暗影鞭笞",
    [218] = "厄运诅咒",
    [228] = "毒舌鞭笞",
    [233] = "青蛙的吻",
    [256] = "召唤黑暗",
    [310] = "甲壳盾",
    [312] = "闪避",
    [334] = "诱饵",
    [360] = "乱舞",
    [409] = "献祭",
    [422] = "暗影震击",
    [453] = "沙暴",
    [466] = "虚空之门",
    [504] = "突然袭击",
    [509] = "汹涌",
    [517] = "夜袭",
    [589] = "奥术风暴",
    [595] = "月火术",
    [621] = "巨石奔袭",
    [624] = "寒冰之墓",
    [628] = "岩石弹幕",
    [634] = "雷区",
    [644] = "地震",
    [648] = "噬骨",
    [652] = "鬼影缠身",
    [777] = "导弹",
    [801] = "投石",
    [814] = "割裂",
    [2530] = "致命梦境",
    [2531] = "狂飙",
    [2532] = "横扫",
    [2533] = "宠物游行"
}

-- 光环ID到中文名称的映射
local auraNames = {
    [217] = "厄运诅咒",
    [239] = "飞行",
    [242] = "亡灵",
    [244] = "机械",
    [309] = "甲壳盾",
    [311] = "闪避",
    [333] = "诱饵",
    [340] = "钻地",
    [408] = "献祭",
    [496] = "半盲",
    [542] = "破碎防御",
    [623] = "寒冰之墓",
    [627] = "岩石弹幕",
    [635] = "雷区",
    [653] = "鬼影缠身",
    [822] = "变形",
    [831] = "速度提升",
    [927] = "眩晕",
    [171] = "焦土",
    [590] = "奥术风暴",
    [596] = "月光",
    [257] = "黑暗",
    [454] = "沙暴",
    [0] = "未知光环",
    [403] = "晴天"
}

-- 宠物ID到中文名称的映射
local petNames = {
    [95] = "逼真的蟾蜍",
    [165] = "魔汁",
    [200] = "春兔",
    [248] = "熊猫人僧侣",
    [261] = "便携式世界毁灭者",
    [265] = "配波",
    [266] = "化石幼兽",
    [338] = "暗月坦克",
    [339] = "暗月飞艇",
    [391] = "高山短尾兔",
    [538] = "痛苦的雏龙",
    [519] = "邪焰",
    [729] = "多莱野兔",
    [730] = "多莱兔仔",
    [746] = "君王蟹",
    [1068] = "乌鸦",
    [1155] = "阿奴比萨斯",
    [1184] = "瘦弱恐角龙",
    [1229] = "恶魔小鬼",
    [1238] = "幼年瓦格里",
    [4329] = "阿尔福斯",
    [4532] = "劫掠者小钳"
}

-- 类型ID到中文名称的映射
local typeNames = {
    [1] = "人型",
    [2] = "龙类",
    [3] = "飞行",
    [4] = "亡灵",
    [5] = "小动物",
    [6] = "魔法",
    [7] = "元素",
    [8] = "野兽",
    [9] = "水栖",
    [10] = "机械"
}

-- 效果类型到中文名称的映射
local effectTypeNames = {
    [1] = "伤害",
    [2] = "治疗",
    [3] = "百分比治疗",
    [4] = "光环",
    [6] = "天气",
    [7] = "假死",
    [8] = "强制换人",
    [9] = "其他"
}

-- 效果动态类型到中文名称的映射
local effectDynamicTypeNames = {
    [1] = "乱舞",
    [2] = "钻地",
    [3] = "突然袭击",
    [4] = "夜袭"
}

-- 目标类型到中文名称的映射
local targetTypeNames = {
    [1] = "我方单体",
    [2] = "敌方单体",
    [3] = "我方全体",
    [4] = "敌方全体",
    [5] = "敌方后排"
}

-- 获取技能名称
function Explain.getAbilityName(id)
    return abilityNames[id] or string.format("技能%d", id)
end

-- 获取光环名称
function Explain.getAuraName(id)
    return auraNames[id] or string.format("光环%d", id)
end

-- 获取宠物名称
function Explain.getPetName(id)
    return petNames[id] or string.format("宠物%d", id)
end

-- 获取类型名称
function Explain.getTypeName(id)
    return typeNames[id] or string.format("类型%d", id)
end

-- 获取效果类型名称
function Explain.getEffectTypeName(id)
    return effectTypeNames[id] or string.format("效果类型%d", id)
end

-- 获取效果动态类型名称
function Explain.getEffectDynamicTypeName(id)
    return effectDynamicTypeNames[id] or string.format("动态效果%d", id)
end

-- 获取目标类型名称
function Explain.getTargetTypeName(id)
    return targetTypeNames[id] or string.format("目标类型%d", id)
end

-- 打印宠物信息
function Explain.printPet(pet)
    if not pet then
        print("宠物信息: nil")
        return
    end
    print(string.format("宠物: %s (ID: %d)", Explain.getPetName(pet.id), pet.id))
    print(string.format("  类型: %s", Explain.getTypeName(pet.type)))
    print(string.format("  生命: %d", pet.health))
    print(string.format("  力量: %d", pet.power))
    print(string.format("  速度: %d", pet.speed))
    print("  技能:")
    for i, ability in ipairs(pet.abilitys) do
        if ability then
            print(string.format("    %d: %s (ID: %d)", i, Explain.getAbilityName(ability.id), ability.id))
        end
    end
end

-- 打印光环信息
function Explain.printAura(aura)
    if not aura then
        print("光环信息: nil")
        return
    end
    print(string.format("光环: %s (ID: %d)", Explain.getAuraName(aura.id), aura.id))
    print(string.format("  类型: %s", Explain.getTypeName(aura.type)))
    print(string.format("  持续时间: %d", aura.duration))
    print(string.format("  效果值: %d", aura.value))
    print(string.format("  过期回合: %d", aura.expire))
    print(string.format("  前置: %s", aura.keep_front and "是" or "否"))
end

-- 打印技能信息
function Explain.printAbility(ability)
    if not ability then
        print("技能信息: nil")
        return
    end
    print(string.format("技能: %s (ID: %d)", Explain.getAbilityName(ability.id), ability.id))
    print(string.format("  类型: %s", Explain.getTypeName(ability.type)))
    print(string.format("  冷却: %d", ability.cooldown))
    print(string.format("  持续回合: %d", ability.duration))
    print("  效果:")
    for round, effects in ipairs(ability.effect_list) do
        print(string.format("    第%d回合:", round))
        for _, effect in ipairs(effects) do
            print(string.format("      %s", Explain.getEffectTypeName(effect.effect_type)))
            print(string.format("        类型: %s", Explain.getTypeName(effect.type)))
            print(string.format("        命中: %d%%", effect.accuracy))
            print(string.format("        数值: %s", effect.value))
            print(string.format("        目标: %s", Explain.getTargetTypeName(effect.target_type)))
            if effect.dynamic_type then
                print(string.format("        动态效果: %s", Explain.getEffectDynamicTypeName(effect.dynamic_type)))
            end
        end
    end
end

-- 打印队伍状态信息
function Explain.printTeamState(teamState)
    if not teamState then
        print("队伍状态: nil")
        return
    end
    print("队伍状态:")
    print(string.format("  活跃宠物: %d", teamState.active_index))
    print(string.format("  速度优势: %s", teamState.is_faster and "是" or "否"))
    print(string.format("  多轮技能回合: %d", teamState.ability_round))
    print(string.format("  多轮技能索引: %d", teamState.ability_index))
    print(string.format("  被打断: %s", teamState.interrupted and "是" or "否"))
    print("  宠物状态:")
    for i, petState in ipairs(teamState.pets) do
        if petState then
            print(string.format("    宠物%d:", i))
            print(string.format("      当前生命: %d", petState.current_health))
            print(string.format("      死亡: %s", petState.is_dead and "是" or "否"))
            print("      冷却:")
            for abilityIndex, cooldown in pairs(petState.cooldown_at) do
                print(string.format("        技能%d: 回合%d", abilityIndex, cooldown))
            end
            print("      光环:")
            for _, aura in pairs(petState.auras) do
                print(string.format("        %s (ID: %d)", Explain.getAuraName(aura.id), aura.id))
            end
        end
    end
    print("  活跃光环:")
    for _, aura in pairs(teamState.active_auras) do
        print(string.format("    %s (ID: %d)", Explain.getAuraName(aura.id), aura.id))
    end
end

-- 打印游戏状态信息
function Explain.printState(state, teams)
    if not state then
        print("游戏状态: nil")
        return
    end
    print(string.format("\n当前第%d回合:", state.round))
    if state.weather then
        print(string.format("天气: %s (持续到回合%d)", Explain.getAuraName(state.weather.id), state.weather.expire))
    end

    for player = 1, 2 do
        local team_state = state.team_states[player]
        print(string.format("\n玩家%d:", player))

        for i, pet_state in ipairs(team_state.pets) do
            local prefix = (i == team_state.active_index) and "→ " or "  "
            local pet_name = "未知宠物"
            if teams and teams[player] and teams[player][i] then
                pet_name = Explain.getPetName(teams[player][i].id)
            end
            print(string.format("%s%s (宠物%d): 生命 %d", prefix, pet_name, i, pet_state.current_health))

            -- 显示光环
            if table_length(pet_state.auras) > 0 then
                print("      光环: ")
                for _, aura in pairs(pet_state.auras) do
                    print(string.format("        - %s (持续到回合%d)", Explain.getAuraName(aura.id), aura.expire))
                end
            end

        end
        if table_length(team_state.active_auras) > 0 then
            print("      队伍光环: ")
            for _, aura in pairs(team_state.active_auras) do
                print(string.format("        - %s (持续到回合%d)", Explain.getAuraName(aura.id), aura.expire))
            end
        end
    end

    -- 显示评估值
    local utility = 0
    if AI.Game and AI.Game.Rule and AI.Game.Rule.get_utility then
        utility = AI.Game.Rule.get_utility(state)
    end
    print(string.format("\n局面评估值: %.3f（玩家1的胜率）", utility))
end

AI.Explain = Explain
return Explain
