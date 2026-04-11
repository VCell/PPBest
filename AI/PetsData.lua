local _,PPBest = ...
local AI = PPBest.AI
local Bit = PPBest.Bit

local AbilityID = {
    NONE = 1, --用于技能不明时的默认技能
    BURROW = 159, --兔子 钻地
    ION_CANNON = 209, --离子炮 
    SHADOW_SLASH = 210, --暗影鞭笞 90命中率亡灵普攻
    CURSE_OF_DOOM = 218, --厄运诅咒 
    CALL_DARKNESS = 256, --召唤黑暗
    DODGE = 312, --兔子 闪避
    FLURRY = 360, --兔子 乱舞
    SHADOW_SHOCK = 422, --暗影震击 85命中率亡灵普攻
    SAND_STORM = 453, --沙暴
    ALPHA_STRIKE = 504, --突然袭击
    NOCTURNAL_STRIKE = 517, --夜袭
    ARCANE_SRORM = 589, --奥术风暴
    MOON_FIRE = 595, --月火术
    STONE_RUSH = 621, --巨石奔袭 配波
    ICE_TOMB = 624,  --阿尔福斯 寒冰之墓
    ROCK_BARRAGE = 628, --岩石弹幕 配波
    MINEFIELD = 634, --雷区
    QUAKE = 644, --地震
    BONE_BITE = 648,    --噬骨 100命中率亡灵普攻
    HAUNT = 652, --鬼影缠身 
    MISSILE = 777, -- 导弹 90命中机械普攻
    STONE_SHOT = 801, --投石 配波
    RUPTURE = 814, --割裂 配波
    ARFUS_2 = 2530, --阿尔福斯 致命梦境
    ARFUS_3 = 2531, --阿尔福斯 狂飙
    ARFUS_4 = 2532,  --阿尔福斯 横扫
    ARFUS_6 = 2533,  --阿尔福斯 宠物游行
    
}

local AuraID = {
    CURSE_OF_DOOM = 217, --厄运诅咒
    FLYING = 239, --飞行 血量高于50%时速度提升50%
    UNDEAD = 242, --亡灵
    MECHANICAL = 244, --机械,表明该机械已经触发过意外防护
    DODGE = 311, --闪避
    BURROW = 340, --钻地
    BLIND = 496, --半盲
    STUN = 927, --眩晕
    SHATTER_DEFENSE = 542, --破碎防御
    ICE_TOMB = 623, -- 阿尔福斯 寒冰之墓
    ROCK_BARRAGE = 627, -- 配波 岩石弹幕
    MINEFIELD = 635, -- 雷区
    HAUNT = 653, -- 鬼影缠身
    -- 天气类
    WEATHER_BURNT_EARTH = 171, --焦土 前排每轮受到龙类伤害61，被点燃
    WEATHER_ARCANE_SRORM = 590, --奥术风暴 免疫控制
    WEATHER_MOONLIGHT = 596, --月光 治疗+25%，魔法伤害+10%
    WEATHER_DARKNESS = 257, --黑暗 治疗-50%，命中-10%，被致盲
    WEATHER_SANDSTORM = 454, --沙暴 命中-10%，所有伤害降低74 
    WEATHER_BLIZZARD = 0, --暴风雪
    WEATHER_MUD = 0, --泥泞
    WEATHER_RAIN = 0, --降雨
    WEATHER_SUNLIGHT = 403, --晴天 最大生命+50%，治疗+25%
    WEATHER_LIGHTNING_STORM = 0, --闪电风暴
    WEATHER_WINDY = 0, --大风
}

local PetID = {
    MOJO = 165, --魔汁
    SPRING_RABBIT = 200, --春兔
    PANDAREN_MONK = 248, --熊猫人僧侣
    PERSONAL_WORLD_DESTROYER = 261,  --便携式世界毁灭者
    PEBBLE = 265, --配波
    FOSSILIZED_HATCHLING = 266, --化石幼兽
    DARKMOON_TONK = 338, --暗月坦克
    DARKMOON_ZEPPELIN = 339, --暗月飞艇
    MOUNTAIN_COTTONTAIL = 391, -- 高山短尾兔
    SCOURGED_WHELPLING = 538, -- 痛苦的雏龙
    FEL_FLAME = 519, -- 邪焰
    TOLAI_HARE = 729, -- 多莱野兔
    TOLAI_HARE_PUP = 730, -- 多莱兔仔
    CROW = 1068, --乌鸦
    ANUBISATH_IDOL = 1155, -- 阿奴比萨斯
    STUNTED_DIREHORN = 1184, -- 瘦弱恐角龙
    UNBORN_VALKYR = 1238, --幼年瓦格里
    ARFUS = 4329, --阿尔福斯
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
function Pet.new(id, health, power, speed, pettype)
    local pet = setmetatable({}, Pet)
    pet.id = id
    pet.health = health
    pet.power = power
    pet.speed = speed
    pet.type = pettype
    pet.abilitys = {}
    return pet
end

function Pet:set_ability(ability, index)
    self.abilitys[index] = ability
end

function Pet:get_ability(index)
    return self.abilitys[index]
end

local EffectType = {
    DAMAGE = 1,
    HEAL = 2,
    PERCENTAGE_HEAL = 3,
    AURA = 4,
    WEATHER = 6, 
    FEIGN_DEATH = 7, -- 假死
    OTHER = 8, -- 其他
}

local EffectDynamicType = {
    FLURRY = 1, -- 攻击1-2次，如果比对方快则额外攻击一次
    BURROW = 2, -- 钻地 触发时需要取消id=340的aura
    ALPHA_STRIKE = 3, --如果我方先手，则伤害提升2/3
    NOCTURNAL_STRIKE = 4, --如果目标被致盲，命中提升至100
}
local TargetType = {
    ALLY = 1, --我方单体
    ENEMY = 2, -- 敌方单体
    ALLY_TEAM = 3, --我方全体
    ENEMY_TEAM = 4, --敌方全体
    ENEMY_BACK = 5, --敌方后排
}

-- 描述Effect能够无视哪些免疫类效果
local IgnoreBit = {
    FLYING = 1, -- 浮空类效果
    DODGE = 2, -- 闪避
    BURROW = 4, -- 下潜
    BLOCK = 8, -- 按次数格挡
}

local IGNORE_BIT_ALL = Bit.bor(IgnoreBit.FLYING, IgnoreBit.DODGE, IgnoreBit.BLOCK, IgnoreBit.BURROW)

local Effect = {
    type = 0, -- 伤害属性
    effect_type = 0,
    accuracy = 0,
    value = 0,
    --duration = 0,
    target_type = 0,
    immune_bit = 0, -- 判定类型：0 判定全部生效。1 无视闪避 浮空 下潜 
    follow_hit = false, -- 是否是击中后触发的效果（true的时候无需判定直接生效）
    dynamic_type = 0, -- 动态伤害的类型
}
function Effect:SetDynamicType(dynamic_type)
    self.dynamic_type = dynamic_type
    return self
end
Effect.__index = Effect

function Effect.new_damage(type, value, accuracy, target_type)
    local effect = setmetatable({}, Effect)
    effect.type = type
    effect.effect_type = EffectType.DAMAGE
    effect.accuracy = accuracy or 100
    effect.value = value
    effect.target_type = target_type or TargetType.ENEMY
    effect.immune_bit = 0
    effect.follow_hit = false
    return effect
end

function Effect.new(type, effect_type, accuracy, value, target_type, ignore_bit, follow_hit)
    local effect = setmetatable({}, Effect)
    effect.type = type
    effect.effect_type = effect_type
    effect.accuracy = accuracy 
    effect.value = value
    effect.target_type = target_type 
    effect.ignore_bit = ignore_bit or 0
    effect.follow_hit = follow_hit or false
    return effect
end

local AuraType = {
    DOT = 1, -- effects预期有一个，每轮执行
    HOT = 2,
    DAMAGE_TAKEN = 3, --百分比影响受到的伤害
    DAMAGE_DEALT = 4, --百分比影响造成的伤害
    ACCURACY = 5, --命中
    DODGE = 6, --闪避
    STUN = 7,
    MINEFIELD = 8, --换人时触发伤害
    BLOCK = 9, --按伤害次数格挡
    DEFEND = 10, --按数值减伤
    SPEED = 11, --百分比修正速度
    MAX_HEALTH = 12,
    FLYING = 13,
    BURROW = 14,
    UNDEAD = 15,
    POSSESSION = 16, --附身类效果，例如鬼影缠身。用value保存转生前血量。其他类似于dot
    END_EFFECT = 17, --结束时生效 effects可以有多个，都在结束时生效
    WEATHER = 18, -- 天气类效果
    OTHER = 19, --其他不需要类型逻辑的效果，生效时根据id生效
}

local Ability = {
    id = 0,
    type = 0,
    cooldown = 0, --冷却回合数。例如第1回合释放，cooldown=1，代表第3回合才能再用
    duration = 0,   --持续回合数
    aways_first = false,
    effect_list = {}, --二维数组 第一层是回合数，第二层是该回合的效果

}

--返回技能受属性克制的影响程度，0-1
function Ability.get_effectiveness_rate(ability_id)
    local rate_map = {
        [AbilityID.ICE_TOMB] = 0.9,
        [AbilityID.NOCTURNAL_STRIKE] = 0.9,
        [AbilityID.BURROW] = 0.9,
        [AbilityID.ARFUS_6] = 0.8,
        [AbilityID.DODGE] = 0,
        [AbilityID.MINEFIELD] = 0,
    }
    if rate_map[ability_id] then
        return rate_map[ability_id]
    end
    return 1
end

Ability.__index = Ability

function Ability.new(id, type, cooldown, duration)
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
    duration = 0, --持续回合数，0：当前回合有效；1：下一回合结束时结束; 以此类推
    value = 0,
    expire = 0,
    keep_front = false,
    effects = nil,
}

function Aura:is_weather(weather_id, round)
    if self and self.type == AuraType.WEATHER and self.id == weather_id and self.expire >= round then
        return true
    end
    return false
end

Aura.__index = Aura


function Aura.new(id, type, duration, value)
    local aura = setmetatable({}, Aura)
    aura.id = id
    aura.type = type
    aura.duration = duration 
    aura.value = value
    aura.keep_front = false
    return aura
end

function Aura.new_aura_by_id(aura_id, power, from_index)
    if aura_id == AuraID.ICE_TOMB then
        local aura = Aura.new(aura_id, AuraType.END_EFFECT, 2, 0)
        aura.keep_front = true
        local ef1 = Effect.new(TypeID.ELEMENTAL, EffectType.DAMAGE, 100, 30 + 1.5 * power, TargetType.ALLY)
        local ef2 = Effect.new(TypeID.ELEMENTAL, EffectType.AURA, 100, AuraID.STUN, TargetType.ALLY, 0, true) 
        aura.effects = {ef1, ef2}
        return aura
    elseif aura_id == AuraID.UNDEAD then
        local aura = Aura.new(aura_id, AuraType.UNDEAD, 1, 0)
        return aura
    elseif aura_id == AuraID.SHATTER_DEFENSE then
        local aura = Aura.new(aura_id, AuraType.DAMAGE_TAKEN, 2, 100)
        return aura
    elseif aura_id == AuraID.DODGE then
        local aura = Aura.new(aura_id, AuraType.DODGE, 1, 0)
        return aura
    elseif aura_id == AuraID.BURROW then
        local aura = Aura.new(aura_id, AuraType.BURROW, 1, 0)
        return aura
    elseif aura_id == AuraID.STUN then
        local aura = Aura.new(aura_id, AuraType.STUN, 1, 0)
        return aura
    elseif aura_id == AuraID.ROCK_BARRAGE then
        local aura = Aura.new(aura_id, AuraType.DOT, 3, 0)
        aura.keep_front = true
        local ef = Effect.new(TypeID.ELEMENTAL, EffectType.DAMAGE, 100, (20+power) * 0.3, TargetType.ALLY)
        aura.effects = {ef}
        return aura
    elseif aura_id == AuraID.CURSE_OF_DOOM then
        local aura = Aura.new(aura_id, AuraType.END_EFFECT, 4, 100)
        aura.effects = {Effect.new(TypeID.UNDEAD, EffectType.DAMAGE, 100, 40+2*power, TargetType.ALLY)}
        return aura
    elseif aura_id == AuraID.HAUNT then
        local aura = Aura.new(aura_id, AuraType.POSSESSION, 4, 100)
        local ef1 = Effect.new(TypeID.UNDEAD, EffectType.DAMAGE, 100, 0.5*power+10, TargetType.ALLY, IGNORE_BIT_ALL)
        aura.effects = {ef1}
        aura.value = from_index
        return aura
    elseif aura_id == AuraID.MINEFIELD then
        local aura = Aura.new(aura_id, AuraType.MINEFIELD, 9, 0)
        aura.keep_front = true
        local ef = Effect.new(TypeID.MECHANICAL, EffectType.DAMAGE, 100, 40+power*2, TargetType.ALLY)
        aura.effects = {ef}
        return aura
    elseif aura_id == AuraID.MECHANICAL then
        local aura = Aura.new(aura_id, AuraType.OTHER, 99, 0)
        return aura
    elseif aura_id == AuraID.WEATHER_DARKNESS then
        return Aura.new(aura_id, AuraType.WEATHER, 5, 0)
    elseif aura_id == AuraID.FLYING then
        return Aura.new(aura_id, AuraType.SPEED, 0, 50)
    else
        return nil
    end
    
end

function Pet:install_ability_by_id(id, index)
    local ability = nil
    if id == AbilityID.BONE_BITE then
        ability = Ability.new(id, TypeID.UNDEAD, 0, 0)
        local ef = Effect.new_damage(TypeID.UNDEAD, 20+self.power)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.SHADOW_SHOCK then
        ability = Ability.new(id, TypeID.UNDEAD, 0, 0)
        local ef = Effect.new_damage(TypeID.UNDEAD, (20+self.power) * 1.3, 85)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.SHADOW_SLASH then
        ability = Ability.new(id, TypeID.UNDEAD, 0, 0)
        local ef = Effect.new_damage(TypeID.UNDEAD, (20+self.power) * 1.2, 90)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.ICE_TOMB then
        ability = Ability.new(id, TypeID.ELEMENTAL, 5, 0)
        local ef = Effect.new(TypeID.ELEMENTAL, EffectType.AURA, 999, AuraID.ICE_TOMB, TargetType.ENEMY, IGNORE_BIT_ALL)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.ARFUS_6 then
        ability = Ability.new(id, TypeID.BEAST, 0, 3)
        ability.effect_list = {
            [1] = {Effect.new_damage(TypeID.BEAST, 54), Effect.new_damage(TypeID.BEAST, 54), Effect.new_damage(TypeID.BEAST, 54),
                        Effect.new(TypeID.BEAST, EffectType.AURA,100, AuraID.SHATTER_DEFENSE,TargetType.ENEMY, 0, true)},
            [2] = {Effect.new_damage(TypeID.BEAST, 90), Effect.new_damage(TypeID.BEAST, 90), Effect.new_damage(TypeID.BEAST, 90),
                        Effect.new(TypeID.BEAST, EffectType.AURA,100, AuraID.SHATTER_DEFENSE,TargetType.ENEMY, 0, true)},
            [3] = {Effect.new_damage(TypeID.BEAST, 126), Effect.new_damage(TypeID.BEAST, 126), Effect.new_damage(TypeID.BEAST, 126),
                        Effect.new(TypeID.BEAST, EffectType.AURA,100, AuraID.SHATTER_DEFENSE,TargetType.ENEMY, 0, true)},
        }
    elseif id == AbilityID.FLURRY then
        ability = Ability.new(id, TypeID.CRITTER, 0, 0)
        ability.effect_list[1] = {Effect.new_damage(TypeID.CRITTER, 10+self.power/2.0):SetDynamicType(EffectDynamicType.FLURRY)}
    elseif id == AbilityID.DODGE then
        ability = Ability.new(id, TypeID.HUMANOID, 4, 0)
        local ef = Effect.new(TypeID.CRITTER, EffectType.AURA, 100, AuraID.DODGE, TargetType.ALLY, IGNORE_BIT_ALL)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.BURROW then
        ability = Ability.new(id, TypeID.BEAST, 4, 2)
        local ef1 = Effect.new(TypeID.BEAST, EffectType.AURA, 100, AuraID.BURROW, TargetType.ALLY)
        local ef2 = Effect.new_damage(TypeID.BEAST, 1.75*(self.power + 20), 80)
        ef2.dynamic_type = EffectDynamicType.BURROW
        ability.effect_list[1] = {ef1}
        ability.effect_list[2] = {ef2}
    elseif id == AbilityID.STONE_SHOT then
        ability = Ability.new(id, TypeID.ELEMENTAL, 0, 0)
        local ef = Effect.new_damage(TypeID.ELEMENTAL, (20+self.power) * 1.1, 95, TargetType.ENEMY)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.RUPTURE then
        ability = Ability.new(id, TypeID.ELEMENTAL, 4, 0)
        local ef1 = Effect.new_damage(TypeID.ELEMENTAL, 30+self.power*1.5, 95, TargetType.ENEMY)
        local ef2 = Effect.new(TypeID.ELEMENTAL, EffectType.AURA,25, AuraID.STUN,TargetType.ENEMY,0, true)
        ability.effect_list[1] = {ef1,ef2}    
    elseif id == AbilityID.ROCK_BARRAGE then
        ability = Ability.new(id, TypeID.ELEMENTAL, 2, 0)
        ability.effect_list = {
            [1] = {Effect.new_damage(TypeID.ELEMENTAL, (20+self.power) * 0.4, 50),
                     Effect.new_damage(TypeID.ELEMENTAL, (20+self.power) * 0.4, 50),
                     Effect.new_damage(TypeID.ELEMENTAL, (20+self.power) * 0.4, 50),
                     Effect.new_damage(TypeID.ELEMENTAL, (20+self.power) * 0.4, 50),
                     Effect.new(TypeID.ELEMENTAL, EffectType.AURA,999, AuraID.ROCK_BARRAGE,TargetType.ENEMY, IGNORE_BIT_ALL),
                    },
        }
    elseif id == AbilityID.CURSE_OF_DOOM then
        ability = Ability.new(id, TypeID.UNDEAD, 5, 0)
        local ef = Effect.new(TypeID.UNDEAD, EffectType.AURA, 100, AuraID.CURSE_OF_DOOM, TargetType.ENEMY)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.HAUNT then
        ability = Ability.new(id, TypeID.UNDEAD, 0, 0)
        ability.effect_list = {
            [1] = {
                Effect.new(TypeID.UNDEAD, EffectType.AURA, 100, AuraID.HAUNT, TargetType.ENEMY),
                Effect.new(TypeID.UNDEAD, EffectType.FEIGN_DEATH, 100, 0, TargetType.ALLY, 0, true),
            }
        }
    elseif id == AbilityID.MISSILE then
        ability = Ability.new(id, TypeID.MECHANICAL, 0, 0)
        local ef = Effect.new_damage(TypeID.MECHANICAL, (20+self.power) * 1.2, 90)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.MINEFIELD then
        ability = Ability.new(id, TypeID.MECHANICAL, 5, 0)
        local ef = Effect.new(TypeID.MECHANICAL, EffectType.AURA, 999, AuraID.MINEFIELD, TargetType.ENEMY, IGNORE_BIT_ALL)
        ability.effect_list[1] = {ef}
    elseif id == AbilityID.ION_CANNON then
        ability = Ability.new(id, TypeID.MECHANICAL, 5, 3)
        local ef = Effect.new_damage(TypeID.MECHANICAL, 50+self.power*2.5, 100)
        ability.effect_list = {{ef}, {}, {}}
    elseif id == AbilityID.ALPHA_STRIKE then
        ability = Ability.new(id, TypeID.FLYING, 0, 0)
        ability.effect_list[1] = {
            Effect.new_damage(TypeID.FLYING, (20+self.power) * 0.75, 95),
            Effect.new(TypeID.FLYING, EffectType.DAMAGE, 100, (20+self.power)*0.5, TargetType.ENEMY, 0, true):SetDynamicType(EffectDynamicType.ALPHA_STRIKE),
        }
    elseif id == AbilityID.CALL_DARKNESS then
        ability = Ability.new(id, TypeID.HUMANOID, 5, 0)
        ability.effect_list[1] = {
            Effect.new_damage(TypeID.HUMANOID, 1.5 * (self.power+20)),
            Effect.new(TypeID.HUMANOID, EffectType.WEATHER, 100, AuraID.WEATHER_DARKNESS, TargetType.ENEMY),
        }
    elseif id == AbilityID.NOCTURNAL_STRIKE then
        ability = Ability.new(id, TypeID.FLYING, 3, 0)
        ability.effect_list[1] = {
            Effect.new_damage(TypeID.FLYING, (20+self.power) * 2, 50):SetDynamicType(EffectDynamicType.NOCTURNAL_STRIKE),
        }
    end
    if ability then 
        self.abilitys[index] = ability
        return ability
    end
end

function Pet:install_default_ability()
    for ab_index = 1, 3 do
        if self.abilitys[ab_index] == nil then
            local ab = Ability.new(AbilityID.NONE, self.type, 0, 0)
            ab.effect_list[1] = {Effect.new_damage(self.type, (20+self.power)*1.5)}
            self.abilitys[ab_index] = ab
        end
    end
end

-- return {
--     Pet = Pet,
--     PetID = PetID,
--     WeatherID = WeatherID,
--     Ability = Ability,
--     Aura = Aura,
--     AuraID = AuraID,
--     AbilityID = AbilityID,
--     TypeID = TypeID,
--     EffectType = EffectType,
--     AuraType = AuraType,
--     TargetType = TargetType,
--     EffectDynamicType = EffectDynamicType,
--     get_aura_by_id = get_aura_by_id
-- }

AI.Pet = Pet
AI.PetID = PetID
AI.Ability = Ability
AI.Aura = Aura
AI.AuraID = AuraID
AI.AbilityID = AbilityID
AI.TypeID = TypeID
AI.EffectType = EffectType
AI.AuraType = AuraType
AI.TargetType = TargetType
AI.EffectDynamicType = EffectDynamicType
AI.IgnoreBit = IgnoreBit
