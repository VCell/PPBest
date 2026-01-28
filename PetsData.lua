

local AbilityID = {
    ICE_TOMB = 624,  --阿尔福斯
    BONE_BITE = 648,    --阿尔福斯
    ARFUS_2 = 2530, --阿尔福斯 致命梦境
    ARFUS_3 = 2531, --阿尔福斯 狂飙
    ARFUS_4 = 2532,  --阿尔福斯 横扫
    ARFUS_6 = 2533,  --阿尔福斯 宠物游行
    
}

local PetID = {
    MOJO = 165, --魔汁
    SPRING_RABBIT = 200, --春兔
    PANDAREN_MONK = 248, --熊猫人僧侣
    PERSONAL_WORLD_DESTROYER = 261  --便携式世界毁灭者
    PEBBLE = 265, --配波
    FOSSILIZED_HATCHLING = 266, --化石幼兽
    DARKMOON_ZEPPELIN = 339, --暗月飞艇
    MOUNTAIN_COTTONTAIL = 391 -- 高山短尾兔
    SCOURGED_WHELPLING = 538 -- 痛苦的雏龙
    FEL_FLAME = 519 -- 邪焰
    ANUBISATH_IDOL = 1155 -- 阿奴比萨斯
    STUNTED_DIREHORN = 1184 -- 瘦弱恐角龙
    UNBORN_VALKYR = 1238 --幼年瓦格里
    ARFUS = 1561, --阿尔福斯
    SCAVENGING_PINCHER = 4532 -- 劫掠者小钳
}

local TypeID = {
    HUMANOID = 1,
    DRAGONKIN = 2,
    FLYING = 3,
    UNDEAD = 4,
    CRITTER = 5,
    MAGIC = 6,
    ELEMENTAL = 7,
    BEAST = 8,
    AQUATIC = 9,
    MECHANICAL = 10,
}
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

local AbilityEffectType = {
    DAMAGE = 1,
    HEAL = 2,
    AURA = 3,
    OTHER = 4,
}

local Ability = {
    id = 0,
    type = 0,
    effect_type = 0,
    value = 0,
    accuracy = 0,
    aways_first = false,
}
Ability.__index = Ability

function Ability:new(id)
    local ability = setmetatable({}, Ability)
    ability.id = id
    return ability
end

function Pet:install_ability_by_id(id, index)
    if id == AbilityID.BONE_BITE then
        local ability = Ability:new(id)
        ability.type = TypeID.UNDEAD
        ability.effect_type = AbilityEffectType.DAMAGE
        ability.accuracy = 100
        ability.value = self.power + 20
        ability.aways_first = false
        return ability
    elseif id == AbilityID.ICE_TOMB then
        local ability = Ability:new(id)
        ability.type = TypeID.ELEMENTAL
        ability.effect_type = AbilityEffectType.DAMAGE
        ability.accuracy = 100
        ability.aways_first = false
        return ability
    end

local Aura = {
    id = 0,
    type = 0,
    duration = 0,
    value = 0,
    expire = 0,
}
Aura.__index = Aura

local AuraType = {
    DAMAGE = 1,
    DAMAGE_ONCE = 2,
    HEAL = 3,
    HEAL_ONCE = 4,
    SPEED = 5,
    DAMAGE_TAKEN = 6,
    DAMAGE_DEALT = 7,
    ACCURACY = 8,
    DODGE = 9,
    STUN = 10,
    AMBUSH = 11,
    BLOCK = 12,
}

function Aura:new(id, type, duration, value)
    local aura = setmetatable({}, Aura)
    aura.id = id
    aura.type = type
    aura.duration = duration
    aura.value = value
    return aura
end

return {
    Pet = Pet,
    Ability = Ability,
    Aura = Aura,
    AbilityID = AbilityID,
    TypeID = TypeID,
    AbilityEffectType = AbilityEffectType,
    AuraType = AuraType,
}