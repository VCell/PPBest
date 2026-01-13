

local TARGET_EXP = '我要经验'
local TARGET_WIN = '我要胜场'
local TARGET_ASSIST = '我要送'

local COOPERATE_TARGETS = {
    TARGET_EXP,
    TARGET_WIN,
    TARGET_ASSIST,
}

local MAX_RECORDS = 200
local LOSS_REST_TIME = 30  -- 失败后休息时间，单位秒

local PET_ID_NEXUS_WHELPLING = 1165 --节点雏龙
local PET_ID_FOSSILIZED_HATCHLING = 266 --化石幼兽
local PET_ID_PERSONAL_WORLD_DESTROYER = 261  --便携式世界毁灭者
local PET_ID_CROW = 1068    --乌鸦
local PET_ID_CHROMINIUS = 1152  --克罗马尼斯
local PET_ID_ARFUS = 4329  --阿尔福斯
local PET_ID_DARKMOON_ZEPPELIN = 339  --暗月飞艇
local PET_ID_PANDAREN_MONK = 248  --熊猫人僧侣
local PET_ID_UNBORN_VALKYR = 1238 --幼年瓦格里
local PET_ID_FEL_FLAME = 519 --邪焰
local PET_ID_PEBBLE = 265 -- 配波
local PET_ID_MOJO = 165 --魔汁
local PET_ID_SPRINT_RABBIT = 200 -- 春兔
local PET_ID_MOUNTAIN_COTTONTAIL = 391 -- 高山短尾兔
local PET_ID_SCOURGED_WHELPLING = 538 -- 痛苦的雏龙
local PET_ID_KUNLAI_RUNR = 1166 -- 昆莱小雪人
local PET_ID_GRASSLANDS_COTTONTAIL = 443 -- 草地短尾兔
local PET_ID_TOLAI_HARE = 729 -- 多莱野兔
local PET_ID_SCAVENGING_PINCHER = 4532 -- 劫掠者小钳

local BattleUtils = _G.PPBestBattleUtils

PPBestHistory = PPBestHistory or {
    version = 1,
    records = {},
    totalBattles = 0,
    wins = 0,
    losses = 0,
}

local Strategy = {
    startTime = nil,
    opponentTeam = nil,
    recording = false,
    round = 0,
    scheme = nil,
    forfeited = false,
    lossTime = nil,
}

function Strategy:Forfeit()
    self.forfeited = true
    C_PetBattles.ForfeitGame()
end

function GetCooperateScheme(myTarget, enemyTarget)
    local startTime = time()
    return {
        schemeName = "CooperateScheme",

        Select = function(self)
            if not enemyTarget then
                Strategy:Forfeit()
                return
            end
            BattleUtils:SwitchToHighestHealthPet()
        end,
        Battle = function(self, round)
            if myTarget == TARGET_ASSIST then
                if enemyTarget == TARGET_EXP and time() - startTime < 60 then
                    return
                end
                Strategy:Forfeit()
            else
                local skillSlot = math.random(1,3)
                BattleUtils:UseSkillByPriority({skillSlot, ((skillSlot)%3)+1, ((skillSlot+1)%3)+1})
            end
        end,
    }
end

function SimplePerform()
    local idx = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
    local id = C_PetBattles.GetPetSpeciesID(LE_BATTLE_PET_ALLY, idx)
    local enemyIdx = C_PetBattles.GetActivePet(LE_BATTLE_PET_ENEMY)
    local enemyId = C_PetBattles.GetPetSpeciesID(LE_BATTLE_PET_ENEMY, enemyIdx)

    if id == PET_ID_NEXUS_WHELPLING then
        local duration = BattleUtils:GetWeatherDuration(BattleUtils.WEATHER_ID_ARCANE_STORM)
        local enemyType = BattleUtils:GetEnemyPetType()
        if BattleUtils:IsUndeadRound(LE_BATTLE_PET_ENEMY) then
            BattleUtils:UseSkillByPriority({3, 1})
        elseif enemyType == BattleUtils.TYPE_MECHANICAL then
            BattleUtils:UseSkillByPriority({1, 3})
        elseif BattleUtils:GetAliveNum(LE_BATTLE_PET_ENEMY) == 1 and BattleUtils:GetAliveNum(LE_BATTLE_PET_ALLY) == 1 then
            BattleUtils:UseSkillByPriority({2, 1,3})
        elseif duration < 3 then 
            BattleUtils:UseSkillByPriority({3, 2, 1})
        else
            BattleUtils:UseSkillByPriority({2, 1, 3})
        end
    elseif id == PET_ID_FOSSILIZED_HATCHLING then
        BattleUtils:UseSkillByPriority({3,2,1})
    elseif id == PET_ID_PERSONAL_WORLD_DESTROYER then
        BattleUtils:UseSkillByPriority({3,2,1})
    elseif id == PET_ID_CROW then
        if BattleUtils:GetWeatherDuration(BattleUtils.WEATHER_ID_DARKNESS) then
            BattleUtils:UseSkillByPriority({2,3,1})
        else
            BattleUtils:UseSkillByPriority({2,1,3})
        end
    elseif id == PET_ID_ARFUS then
        if BattleUtils:IsAbilityWeakToEnemy(BattleUtils.TYPE_ELEMENTAL) then
            BattleUtils:UseSkillByPriority({3,1})
        elseif BattleUtils:IsAbilityStrongToEnemy(BattleUtils.TYPE_UNDEAD) then
            BattleUtils:UseSkillByPriority({1,3})
        else 
            BattleUtils:UseSkillByPriority({2,3,1})
        end
    elseif id == PET_ID_DARKMOON_ZEPPELIN then
        BattleUtils:UseSkillByPriority({3,2,1})
    elseif id == PET_ID_PANDAREN_MONK then
        BattleUtils:UseSkillByPriority({3,1,2})
    elseif id == PET_ID_UNBORN_VALKYR then
        if BattleUtils:IsUndeadRound(LE_BATTLE_PET_ALLY) then
            BattleUtils:UseSkillByPriority({3})
        else
            BattleUtils:UseSkillByPriority({2,1})
        end
    elseif id == PET_ID_PEBBLE then
        if BattleUtils:IsUndeadRound(LE_BATTLE_PET_ENEMY) then
            BattleUtils:UseSkillByPriority({3,1,2})
        elseif BattleUtils:GetWeatherDuration( BattleUtils.WEATHER_ID_SANDSTORM) > 0 then
            BattleUtils:UseSkillByPriority({2,1})
        else
            BattleUtils:UseSkillByPriority({3,2,1})
        end
    elseif id == PET_ID_MOJO then
        if BattleUtils:GetActivePetHealth() < 1000 then
            BattleUtils:UseSkillByPriority({2,3})
        else
            BattleUtils:UseSkillByPriority({3})
        end
    elseif id == PET_ID_SPRINT_RABBIT or id == PET_ID_GRASSLANDS_COTTONTAIL or 
            id == PET_ID_MOUNTAIN_COTTONTAIL or id == PET_ID_TOLAI_HARE then
        if enemyId == PET_ID_FOSSILIZED_HATCHLING or enemyId == PET_ID_SCOURGED_WHELPLING or
                enemyId == PET_ID_PERSONAL_WORLD_DESTROYER then
            if BattleUtils:IsUndeadRound(LE_BATTLE_PET_ENEMY) then 
                BattleUtils:UseSkillByPriority({3,2,1})
            else
                BattleUtils:UseSkillByPriority({1})
            end
        else 
            BattleUtils:UseSkillByPriority({3,2,1})
        end
    elseif id == PET_ID_KUNLAI_RUNR then
        if BattleUtils:IsAbilityWeakToEnemy(BattleUtils.TYPE_ELEMENTAL) or 
                BattleUtils:IsAbilityStrongToEnemy(BattleUtils.TYPE_HUMANOID) then
            BattleUtils:UseSkillByPriority({1,3})
        else
            if BattleUtils:CanKillEnemy(324, BattleUtils.TYPE_HUMANOID) or 
                    BattleUtils:GetAuraRemaining(LE_BATTLE_PET_ENEMY, BattleUtils.AURA_ID_STUN) > 0 then
                BattleUtils:UseSkillByPriority({1,2})
            elseif BattleUtils:GetAuraRemaining(LE_BATTLE_PET_ENEMY, BattleUtils.AURA_ID_FROST_SHOCK) > 0 then
                BattleUtils:UseSkillByPriority({3,1})
            elseif BattleUtils:GetAbilityCooldown(3) <= 1 then
                BattleUtils:UseSkillByPriority({2,1})
            else
                BattleUtils:UseSkillByPriority({1,2})
            end
        end
    elseif id==PET_ID_SCOURGED_WHELPLING then
        if  BattleUtils:GetAliveNum(LE_BATTLE_PET_ENEMY) == 1 then
            BattleUtils:UseSkillByPriority({2,1})
        else
            BattleUtils:UseSkillByPriority({3,1})
        end
    elseif id==PET_ID_SCAVENGING_PINCHER then
        if  BattleUtils:GetAliveNum(LE_BATTLE_PET_ENEMY) == 1 then
            BattleUtils:UseSkillByPriority({3,1})
        else 
            BattleUtils:UseSkillByPriority({2,3,1})
        end
    else 
        local skillSlot = math.random(1,3)
        BattleUtils:UseSkillByPriority({skillSlot, ((skillSlot)%3)+1, ((skillSlot+1)%3)+1})
    end

end

-- 3节点雏龙
function GetScheme3Nexus()
    local forfeit = false
    local forfeitTeam = {
        {266, 261, 1068},  -- 化石幼兽 便携式世界毁灭者 乌鸦
    }
    for _, team in ipairs(forfeitTeam) do
        if BattleUtils:EnemyTeamIs(team) then
            forfeit = true
        end
    end

    return {
        schemeName = "3NexusScheme",
        forfeit = forfeit,
        Select = function(self)
            BattleUtils:SwitchPetByOrder()
        end,
        Battle = function(self, round)
            if self.forfeit and round>1 then
                Strategy:Forfeit()
                return
            end
            if C_PetBattles.IsSkipAvailable() then
                SimplePerform()
            end
        end,
    }
end

function GetSimpleScheme()
    return {
        schemeName = "SimpleScheme",
        Select = function(self)
            BattleUtils:SwitchPetByOrder()
        end,
        Battle = function(self, round)
            SimplePerform()
        end
    }
end

function GetSchemeRabbitPebbleArfus()
    local undeadCount = 0
    local mechanicalCount = 0
    local order = {1,2,3}
    for petIndex = 1, C_PetBattles.GetNumPets(LE_BATTLE_PET_ENEMY) do
        local type = C_PetBattles.GetPetType(LE_BATTLE_PET_ENEMY, petIndex)
        if type == BattleUtils.TYPE_UNDEAD then
            undeadCount = undeadCount + 1
        elseif type == BattleUtils.TYPE_MECHANICAL then
            mechanicalCount = mechanicalCount + 1
        end
    end

    if undeadCount == 0 then
        order = {3,2,1}  -- 阿尔福斯->配波->兔
    elseif undeadCount > 0 and mechanicalCount > 0 then
        order = {1,2,3}  --  兔->配波->阿尔福斯
    elseif undeadCount > 0 then
        order = {1,3,2}  -- 兔->阿尔福斯->配波
    end

    return {
        schemeName = "RPAScheme",
        Select = function(self)
            BattleUtils:SwitchPetByOrder(order[1],order[2],order[3])
        end,
        Battle = function(self, round)
            SimplePerform()
        end
    }
end

function GetSchemeAAB()
    return {
        schemeName = "AABScheme",
        Select = function(self)
            BattleUtils:SwitchPetByOrder(order[1],order[2],order[3])
        end,
        Battle = function(self, round)
            SimplePerform()
        end
    }
end

-- 添加对战记录
function Strategy:AddBattleRecord(result)
    if not self.recording then
        return
    end
    
    -- 更新统计数据
    PPBestHistory.totalBattles = (PPBestHistory.totalBattles or 0) + 1
    if result == "win" then
        PPBestHistory.wins = (PPBestHistory.wins or 0) + 1
    elseif result == "loss" then
        PPBestHistory.losses = (PPBestHistory.losses or 0) + 1
    end
    
    local record = string.format("%s, %s, %d, %d, [%s-%s-%s],[%d-%d-%d]", 
        date("%Y-%m-%d %H:%M:%S", self.startTime), result, self.round, time() - self.startTime, 
        self.opponentTeam[1].name, self.opponentTeam[2].name, self.opponentTeam[3].name,
        self.opponentTeam[1].id, self.opponentTeam[2].id, self.opponentTeam[3].id
    )
    
    -- 添加到记录列表
    table.insert(PPBestHistory.records, record)

    BattleUtils:Debug(record)

    -- 限制记录数量
    while #PPBestHistory.records > MAX_RECORDS do
        table.remove(PPBestHistory.records, 1)
    end
end


function Strategy:Init()
    self.startTime = time()
    self.scheme = GetSimpleScheme()
    self.opponentTeam = {}
    self.recording = false
    self.round = 0
    self.lossTime = nil
    self.forfeited = false
    
    -- 处理己方宠物信息
    if BattleUtils:AllyTeamIs({PET_ID_NEXUS_WHELPLING, PET_ID_NEXUS_WHELPLING, PET_ID_NEXUS_WHELPLING}) then
        self.scheme = GetScheme3Nexus()
    elseif BattleUtils:AllyTeamIs({PET_ID_SPRINT_RABBIT, PET_ID_PEBBLE, PET_ID_ARFUS}) then
        self.scheme = GetSchemeRabbitPebbleArfus()
    elseif BattleUtils:AllyTeamIs({PET_ID_MOUNTAIN_COTTONTAIL, PET_ID_PEBBLE, PET_ID_ARFUS}) then
        self.scheme = GetSchemeRabbitPebbleArfus()
    elseif BattleUtils:AllyTeamIs({PET_ID_TOLAI_HARE, PET_ID_PEBBLE, PET_ID_ARFUS}) then
        self.scheme = GetSchemeRabbitPebbleArfus()
    end

    local lowLevel = false
    local myTarget = nil
    local enemyTarget = nil

    for petIndex = 1, C_PetBattles.GetNumPets(LE_BATTLE_PET_ALLY) do
        local name = C_PetBattles.GetName(LE_BATTLE_PET_ALLY, petIndex)
        local level = C_PetBattles.GetLevel(LE_BATTLE_PET_ALLY, petIndex)
        if level < 25 then
            lowLevel = true
        end
        if name == TARGET_EXP or name == TARGET_WIN or name == TARGET_ASSIST then
            myTarget = name
        end
    end


    -- 处理对手宠物信息
    for petIndex = 1, C_PetBattles.GetNumPets(LE_BATTLE_PET_ENEMY) do
        local name = C_PetBattles.GetName(LE_BATTLE_PET_ENEMY, petIndex)
        local petType = C_PetBattles.GetPetType(LE_BATTLE_PET_ENEMY, petIndex)
        local level = C_PetBattles.GetLevel(LE_BATTLE_PET_ENEMY, petIndex)
        local quality = C_PetBattles.GetBreedQuality(LE_BATTLE_PET_ENEMY, petIndex)
        local id = C_PetBattles.GetPetSpeciesID(LE_BATTLE_PET_ENEMY, petIndex)
        table.insert(self.opponentTeam, {
            name = name,
            type = petType,
            level = level,
            quality = quality,
            id = id,
        })
        if name == TARGET_EXP or name == TARGET_WIN or name == TARGET_ASSIST then
            enemyTarget = name
        end
    end
    if lowLevel and myTarget ~= nil then
        self.scheme = GetCooperateScheme(myTarget, enemyTarget)
    end

    if not C_PetBattles.IsPlayerNPC(LE_BATTLE_PET_ENEMY) then
        self.recording = true
    end

    --BattleUtils:Debug("Using scheme: " .. self.scheme.schemeName)
end

function Strategy:OnRoundComplete()
    self.round = self.round + 1
end

function Strategy:OnFinalRound(...)
    local result 
    local winner = ...
    -- PET_BATTLE_FINAL_ROUND的参数时常会返回错误的结果
    -- if winner == 1 then
    --     result = "win"
    -- else
    --     result = "loss"
    -- end

    if self.forfeited then
        result = "loss"
    else
        local win = BattleUtils:DetermineWinner()
        
        if win >= 0 then
            result = "win"
        else
            result = "loss"
            self.lossTime = time()
        end
    end
    Strategy:AddBattleRecord(result)
end

function Strategy:ShouldRest()
    if not self.lossTime then
        return false
    end

    return (time() - self.lossTime) < LOSS_REST_TIME
end

function Strategy:PerformSelect()
    self.scheme:Select()
end

function Strategy:PerformBattle()
    self.scheme:Battle(self.round)
end

_G.PPBestStrategy = Strategy