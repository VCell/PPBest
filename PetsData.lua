

local AbilityID = {
    BURROW = 159, --兔子 钻地
    DODGE = 312, --兔子 闪避
    FLURRY = 360, --兔子 乱舞
    SAND_STORM = 453, --沙暴
    ARCANE_SRORM = 589, --奥术风暴
    MOON_FIRE = 595, --月火术
    ICE_TOMB = 624,  --阿尔福斯
    BONE_BITE = 648,    --阿尔福斯
    ARFUS_2 = 2530, --阿尔福斯 致命梦境
    ARFUS_3 = 2531, --阿尔福斯 狂飙
    ARFUS_4 = 2532,  --阿尔福斯 横扫
    ARFUS_6 = 2533,  --阿尔福斯 宠物游行
    
}

local AuraID = {
    UNDEAD = 242, --亡灵
    DODGE = 311, --闪避
    UNDERGROUND = 340, --钻地
    STUN = 927, --眩晕
    SHATTER_DEFENSE = 542, --破碎防御
    ICE_TOMB = 623 -- 阿尔福斯 寒冰之墓
}

local WeatherID = {
    BURNT_EARTH = 171, --焦土 前排每轮受到龙类伤害61，被点燃
    ARCANE_SRORM = 590, --奥术风暴 免疫控制
    MOONLIGHT = 596, --月光 治疗+25%，魔法伤害+10%
    DARKNESS = 257, --黑暗 治疗-50%，命中-10%，被致盲
    SANDSTORM = 454, --沙暴 命中-10%，所有伤害降低74 
    BLIZZARD = 0, --暴风雪
    MUD = 0, --泥泞
    RAIN = 0, --降雨
    SUNLIGHT = 403, --晴天 最大生命+50%，治疗+25%
    LIGHTNING_STORM = 0, --闪电风暴
    WINDY = 0, --大风
}

local PetID = {
    MOJO = 165, --魔汁
    SPRING_RABBIT = 200, --春兔
    PANDAREN_MONK = 248, --熊猫人僧侣
    PERSONAL_WORLD_DESTROYER = 261,  --便携式世界毁灭者
    PEBBLE = 265, --配波
    FOSSILIZED_HATCHLING = 266, --化石幼兽
    DARKMOON_ZEPPELIN = 339, --暗月飞艇
    MOUNTAIN_COTTONTAIL = 391, -- 高山短尾兔
    SCOURGED_WHELPLING = 538, -- 痛苦的雏龙
    FEL_FLAME = 519, -- 邪焰
    ANUBISATH_IDOL = 1155, -- 阿奴比萨斯
    STUNTED_DIREHORN = 1184, -- 瘦弱恐角龙
    UNBORN_VALKYR = 1238, --幼年瓦格里
    ARFUS = 1561, --阿尔福斯
    SCAVENGING_PINCHER = 4532, -- 劫掠者小钳
}

local TypeID = {
    HUMANOID = 1,
    DRAGONKIN = 2,
    FLYING = 3, --血量高于50%时速度提升50%
    UNDEAD = 4, --亡灵 在受到致命伤害后能继续战斗一回合
    CRITTER = 5, --免疫一切控制效果
    MAGIC = 6, --单次伤害不会超过生命上限1/3
    ELEMENTAL = 7, --
    BEAST = 8, --生命低于50%时，伤害提升50%
    AQUATIC = 9,    
    MECHANICAL = 10,

 
}
function TypeID.GetEffectiveness(attackType, targetType)
    local strongTable = {
        [TypeID.HUMANOID] = TypeID.DRAGONKIN,
        [TypeID.DRAGONKIN] = TypeID.MAGIC,
        [TypeID.MAGIC] = TypeID.FLYING,
        [TypeID.FLYING] = TypeID.AQUATIC,
        [TypeID.AQUATIC] = TypeID.ELEMENTAL,
        [TypeID.ELEMENTAL] = TypeID.MECHANICAL,
        [TypeID.MECHANICAL] = TypeID.BEAST,
        [TypeID.BEAST] = TypeID.CRITTER,
        [TypeID.CRITTER] = TypeID.UNDEAD,
        [TypeID.UNDEAD] = TypeID.HUMANOID,
    }
    local weakTable = {
        [TypeID.HUMANOID] = TypeID.BEAST,
        [TypeID.BEAST] = TypeID.FLYING,
        [TypeID.FLYING] = TypeID.DRAGONKIN,
        [TypeID.DRAGONKIN] = TypeID.UNDEAD,
        [TypeID.UNDEAD] = TypeID.AQUATIC,
        [TypeID.AQUATIC] = TypeID.MAGIC,
        [TypeID.MAGIC] = TypeID.MECHANICAL,
        [TypeID.MECHANICAL] = TypeID.ELEMENTAL,
        [TypeID.ELEMENTAL] = TypeID.CRITTER,
        [TypeID.CRITTER] = TypeID.HUMANOID,
    }
    if strongTable[attackType] == targetType then
        return 1.5
    elseif weakTable[attackType] == targetType then
        return 0.66
    else
        return 1.0
    end
end

local Pet = {
    id = 0,
    health = 0,
    power = 0,
    speed = 0,
    type = 0,
    abilitys = {},
}
Pet.__index = Pet
function Pet:new(id, health, power, speed, pettype)
    local pet = setmetatable({}, Pet)
    pet.id = id
    pet.health = health
    pet.power = power
    pet.speed = speed
    pet.type = pettype
    return pet
end

function Pet:SetAbility(ability, index)
    self.abilitys[index] = ability
end

function Pet:GetAbility(index)
    return self.abilitys[index]
end

local EffectType = {
    DAMAGE = 1,
    HEAL = 2,
    PERCENTAGE_HEAL = 3,
    AURA = 4,
    WEATHER = 5,
    OTHER = 6,
}

local EffectDynamicType = {
    FLURRY = 1, -- 攻击1-2次，如果比对方快则额外攻击一次

}
local TargetType = {
    ALLY = 1, --我方单体
    ENEMY = 2, -- 敌方单体
    ALLY_TEAM = 3, --我方全体
    ENEMY_TEAM = 4, --敌方全体
    ENEMY_BACK = 5, --敌方后排
}
local Effect = {
    type = 0, -- 伤害属性
    effect_type = 0,
    accuracy = 0,
    value = 0,
    --duration = 0,
    target_type = 0,
    certain = false, -- 无需判定
    dynamic_type = 0, -- 动态伤害的类型
}
Effect.__index = Effect
function Effect:new_damage(type, value, accuracy, target_type)
    local effect = setmetatable({}, Effect)
    effect.type = type
    effect.effect_type = EffectType.DAMAGE
    effect.accuracy = accuracy or 100
    effect.value = value
    effect.target_type = target_type or TargetType.ENEMY
    return effect
end

function Effect:new(type, effect_type, accuracy, value, target_type)
    local effect = setmetatable({}, Effect)
    effect.type = type
    effect.effect_type = effect_type
    effect.accuracy = accuracy 
    effect.value = value
    effect.target_type = target_type 
    return effect
end

local Ability = {
    id = 0,
    type = 0,
    cooldown = 0,
    duration = 0,   --持续回合数
    aways_first = false,
    effect_list = {}, --二维数组 第一层是回合数，第二层是该回合的效果

}
Ability.__index = Ability

function Ability:new(id, type, cooldown, duration)
    local ability = setmetatable({}, Ability)
    ability.id = id
    ability.type = type
    ability.cooldown = cooldown
    ability.duration = duration
    ability.effect_list = {}
    ability.aways_first = false
    return ability
end

local Aura = {
    id = 0,
    type = 0,
    duration = 0, --持续回合数，认为触发回合是第1回合。例如duration=2，代表触发回合之后还会持续1回合
    value = 0,
    expire = 0,
    keep_front = false,
    effect = nil,
}
Aura.__index = Aura

local AuraType = {
    DOT = 1,
    HOT = 2,
    DAMAGE_TAKEN = 3, --百分比影响受到的伤害
    DAMAGE_DEALT = 4, --百分比影响造成的伤害
    ACCURACY = 5, --命中
    DODGE = 6, --闪避
    STUN = 7,
    MINE_FIELD = 8, --换人时触发伤害
    BLOCK = 9, --按伤害次数格挡
    DEFEND = 10, --按数值减伤
    SPEED = 11,
    MAX_HEALTH = 12,
    FLYING = 13,
    UNDERGROUND = 14,
    UNDEAD = 15,
    END_EFFECT = 16, --特殊效果 
}

function Aura:new(id, type, duration, value)
    local aura = setmetatable({}, Aura)
    aura.id = id
    aura.type = type
    aura.duration = duration 
    aura.value = value

    return aura
end

function get_aura_by_id(aura_id, power)
    if aura_id == AuraID.ICE_TOMB then
        local aura = Aura:new(aura_id, AuraType.END_EFFECT, 2, 0)
        local ef1 = Effect:new(EffectType.DAMAGE, 100, 30 + 1.5 * self.power, 2, TargetType.ENEMY)
        local ef2 = Effect:new(EffectType.AURA, 100, 0, AuraID.STUN, TargetType.ENEMY) 
        aura.effect = {ef1, ef2}
        return aura
    elseif aura_id == AuraID.UNDEAD then
        local aura = Aura:new(aura_id, AuraType.UNDEAD, 2, 0)
        return aura
    elseif aura_id == AuraID.SHATTER_DEFENSE then
        local aura = Aura:new(aura_id, AuraType.DAMAGE_TAKEN, 3, 100)
        return aura
    elseif aura_id == AuraID.DODGE then
        local aura = Aura:new(aura_id, AuraType.DODGE, 2, 0)
        return aura
    else
        return nil
    end
    
end

function Pet:install_ability_by_id(id, index)
    local ability = nil
    if id == AbilityID.BONE_BITE then
        ability = Ability:new(id, TypeID.UNDEAD, 0, 0)
        local ef = Effect:new_damage(TypeID.UNDEAD, 100, 20+self.power)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.ICE_TOMB then
        ability = Ability:new(id, TypeID.ELEMENTAL, 5, 0)
        local ef = Effect:new(TypeID.ELEMENTAL, EffectType.AURA, 100, AuraID.ICE_TOMB, TargetType.ENEMY)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.ARFUS_6 then
        ability = Ability:new(id, TypeID.BEAST, 0, 3)
        ability.effect_list = {
            [1] = {Effect:new_damage(TypeID.BEAST, 54), Effect:new_damage(TypeID.BEAST, 54), Effect:new_damage(TypeID.BEAST, 54),
                        Effect:new(TypeID.BEAST, EffectType.AURA,100, AuraID.SHATTER_DEFENSE,TargetType.ENEMY)},
            [2] = {Effect:new_damage(TypeID.BEAST, 90), Effect:new_damage(TypeID.BEAST, 90), Effect:new_damage(TypeID.BEAST, 90),
                        Effect:new(TypeID.BEAST, EffectType.AURA,100, AuraID.SHATTER_DEFENSE,TargetType.ENEMY)},
            [3] = {Effect:new_damage(TypeID.BEAST, 54), Effect:new_damage(TypeID.BEAST, 126), Effect:new_damage(TypeID.BEAST, 54),
                        Effect:new(TypeID.BEAST, EffectType.AURA,100, AuraID.SHATTER_DEFENSE,TargetType.ENEMY)},
        }

    elseif id == AbilityID.FLURRY then
        local ability = Ability:new(id, TypeID.CRITTER, 0, 0)
        local ef = Effect:new(TypeID.CRITTER, EffectType.DAMAGE, 100, 10+self.power/2.0, TargetType.ENEMY)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.DODGE then
        ability = Ability:new(id, TypeID.CRITTER, 4, 0)
        local ef = Effect:new(TypeID.CRITTER, EffectType.AURA, 100, AuraID.DODGE, TargetType.ALLY)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.BURROW then
        ability = Ability:new(id, TypeID.CRITTER, 4, 2)
        local ef1 = Effect:new(TypeID.CRITTER, EffectType.AURA, 100, AuraID.UNDERGROUND, TargetType.ALLY)
        local ef2 = Effect:new_damage(TypeID.CRITTER, 2*self.power - 25, 80)
        ability.effect_list = {ef1, ef2}
    end
    if ability == nil then
        
    end

    self.abilitys[index] = ability
    return 
end



return {
    Pet = Pet,
    PetID = PetID,
    WeatherID = WeatherID,
    Ability = Ability,
    Aura = Aura,
    AbilityID = AbilityID,
    TypeID = TypeID,
    EffectType = EffectType,
    AuraType = AuraType,
    TargetType = TargetType,
    EffectDynamicType = EffectDynamicType,
}