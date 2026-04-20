local _, PPBest = ...

local PetCombatLogType = {
    DAMAGE = 1,
    AURA = 2,
    IMMUNE = 3,
    BLOCK = 4,
    WEATHER = 5,
    UNKNOWN = 6,
}

local function new_ability_log_info(id, health, power, speed)
    return {
        id = id,
        health = health,
        power = power,
        speed = speed,
    }
end

local PetCombatLog = {
    type = 0,
    abilityInfo1 = nil,
    abilityInfo2 = nil,
    target = 0,
}
PetCombatLog.__index = PetCombatLog

function PetCombatLog.Parse(msg) 
    local log = setmetatable({}, PetCombatLog)
    local targetKeywords = {
        ["对敌方的"] = LE_BATTLE_PET_ENEMY,
        ["对敌方队伍"] = LE_BATTLE_PET_ENEMY,
        ["被敌方的"] = LE_BATTLE_PET_ENEMY,
        ["未命中敌方的"] = LE_BATTLE_PET_ENEMY,
        ["为敌方的"] = LE_BATTLE_PET_ENEMY,
        ["对你的"] = LE_BATTLE_PET_ALLY,
        ["对你的队伍"] = LE_BATTLE_PET_ALLY,
        ["被你的"] = LE_BATTLE_PET_ALLY,
        ["未命中你的"] = LE_BATTLE_PET_ALLY,
        ["为你的"] = LE_BATTLE_PET_ALLY,
        ["将天气转变为"] = LE_BATTLE_PET_WEATHER,
    }
    local keyPos = nil
    for keyword, target in pairs(targetKeywords) do
        keyPos = string.find(msg, keyword)
        if keyPos ~= nil then
            log.target = target
            break
        end
    end
    if keyPos == nil then
        return nil
    end
    local abilityPart = string.sub(msg, 0, keyPos)
    for id, health, power, speed in abilityPart:gmatch("|HbattlePetAbil:(%d+):(%d+):(%d+):(%d+)|h") do
        assert(log.abilityInfo1 == nil)
        log.abilityInfo1 = new_ability_log_info(tonumber(id), tonumber(health), tonumber(power), tonumber(speed))
    end
    local typeKeywords = {
        ["施放了"] = PetCombatLogType.AURA,
        ["效果"] = PetCombatLogType.AURA,
        ["点伤害"] = PetCombatLogType.DAMAGE,
        ["将天气转变为"] = PetCombatLogType.WEATHER,
        ["未命中敌方的"] = PetCombatLogType.IMMUNE,
        ["未命中你的"] = PetCombatLogType.IMMUNE,
        ["格挡了"] = PetCombatLogType.BLOCK,
        ["躲闪了"] = PetCombatLogType.IMMUNE,
    }
    for keyword, type in pairs(typeKeywords) do
        if string.find(msg, keyword) then
            log.type = type
            break
        end
    end
    if log.type == nil then
        log.type = PetCombatLogType.UNKNOWN
    end
    if log.type == PetCombatLogType.AURA or log.type == PetCombatLogType.WEATHER then
        local auraPart = string.sub(msg, keyPos)
        for id, health, power, speed in auraPart:gmatch("|HbattlePetAbil:(%d+):(%d+):(%d+):(%d+)|h") do
            assert(log.abilityInfo2 == nil)
            log.abilityInfo2 = new_ability_log_info(tonumber(id), tonumber(health), tonumber(power), tonumber(speed))
        end
        assert(log.abilityInfo2 ~= nil)
    end
    return log
end

PPBest.PetCombatLog = PetCombatLog
PPBest.PetCombatLogType = PetCombatLogType