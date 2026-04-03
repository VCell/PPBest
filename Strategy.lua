local _, PPBest = ...
local AII = PPBest.SearchInterface
local BattleUtils = PPBest.BattleUtils
local Const = PPBest.Const
local LogFrame = PPBest.LogFrame
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
local PET_ID_TOLAI_RABBIT = 730 -- 多莱兔子
local PET_ID_SCAVENGING_PINCHER = 4532 -- 劫掠者小钳
local PET_ID_GILNEAN_RAVEN = 630 -- 吉尔尼斯渡鸦
local PET_ID_STUNTED_DIREHORN = 1184 -- 瘦弱恐角龙
local PET_ID_ANUBISATH_IDOL = 1155 -- 阿努比斯
local PET_ID_LIFELIKE_TOAD = 95 -- 逼真蟾蜍

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

local lossCount = 0 --互刷模式下 连续失败次数，辅助的一方每10场要赢一场

function Strategy:Forfeit()
    self.forfeited = true
    C_PetBattles.ForfeitGame()
end

local function GetCooperateForfeitScheme(timeout, firstPetIndex)
    local startTime = time()
    return {
        schemeName = "CooperateForfeitScheme",

        Select = function(self)
            C_PetBattles.ChangePet(firstPetIndex)
        end,
        Battle = function(self, round)
            if lossCount >=10 then 
                local skillSlot = math.random(1,3)
                BattleUtils:UseSkillByPriority({skillSlot, ((skillSlot)%3)+1, ((skillSlot+1)%3)+1})
                return
            end
            if time() - startTime > timeout then
                Strategy:Forfeit()
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
        elseif BattleUtils:CanKillEnemy(361, BattleUtils.TYPE_UNDEAD) then
            BattleUtils:UseSkillByPriority({1})
        elseif BattleUtils:CanKillEnemy(432, BattleUtils.TYPE_BEAST) then
            BattleUtils:UseSkillByPriority({3,1})
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
        elseif BattleUtils:GetWeatherDuration(BattleUtils.WEATHER_ID_SANDSTORM) > 0 then
            BattleUtils:UseSkillByPriority({2,1})
        else
            BattleUtils:UseSkillByPriority({3,2,1})
        end
    elseif id == PET_ID_SPRINT_RABBIT or id == PET_ID_GRASSLANDS_COTTONTAIL or 
            id == PET_ID_MOUNTAIN_COTTONTAIL or id == PET_ID_TOLAI_HARE
            or id == PET_ID_TOLAI_RABBIT then
        if  enemyId == PET_ID_SCOURGED_WHELPLING or enemyId == PET_ID_PERSONAL_WORLD_DESTROYER then
            if BattleUtils:IsUndeadRound(LE_BATTLE_PET_ENEMY) then 
                BattleUtils:UseSkillByPriority({3,2,1})
            else
                BattleUtils:UseSkillByPriority({1})
            end
        elseif enemyId == PET_ID_FOSSILIZED_HATCHLING then 
            if BattleUtils:GetAbilityCooldown(LE_BATTLE_PET_ALLY, 3) == 0 and 
                    BattleUtils:GetAbilityCooldown(LE_BATTLE_PET_ALLY, 2) == 0 then
                BattleUtils:UseSkillByPriority({2,1})
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
            elseif BattleUtils:GetAbilityCooldown(LE_BATTLE_PET_ALLY, 3) <= 1 then
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
    elseif id==PET_ID_LIFELIKE_TOAD or id == PET_ID_MOJO then
        if BattleUtils:IsAbilityWeakToEnemy(BattleUtils.TYPE_AQUATIC) or 
                BattleUtils:IsAbilityStrongToEnemy(BattleUtils.TYPE_CRITTER) then
            if BattleUtils:GetActivePetHealth(LE_BATTLE_PET_ALLY) < 1000 then
                BattleUtils:UseSkillByPriority({2,1})
            else 
                BattleUtils:UseSkillByPriority({1,2})
            end
        else 
            if BattleUtils:GetActivePetHealth(LE_BATTLE_PET_ALLY) < 1100 then
                BattleUtils:UseSkillByPriority({2,3})
            else 
                BattleUtils:UseSkillByPriority({3,2})
            end
        end
        BattleUtils:UseSkillByPriority({3,2,1})
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

    if BattleUtils:EnemyTeamIs({PET_ID_SCAVENGING_PINCHER, PET_ID_SCOURGED_WHELPLING, PET_ID_SCOURGED_WHELPLING}) or
             BattleUtils:EnemyTeamIs({PET_ID_STUNTED_DIREHORN, PET_ID_ARFUS, PET_ID_ANUBISATH_IDOL}) then
        order = {3,1,2}  -- 阿尔福斯->兔->配波
    elseif undeadCount == 0 then
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
            if BattleUtils:EnemyTeamIs({PET_ID_FOSSILIZED_HATCHLING, PET_ID_PERSONAL_WORLD_DESTROYER, PET_ID_GILNEAN_RAVEN}) and
                    BattleUtils:IsUndeadRound(LE_BATTLE_PET_ENEMY) then
                C_PetBattles.ChangePet(2)
                return 
            end
            SimplePerform()
        end
    }
end

function GetSchemeAAB()
    return {
        schemeName = "AABScheme",
        Select = function(self)
            C_PetBattles.ChangePet(1)
            BattleUtils:SwitchPetByOrder({1,2,3})
        end,
        Battle = function(self, round)
            SimplePerform()
        end
    }
end

local function performAction(action)
    LogFrame:AddLog("Perform action: " .. action.type .. " " .. action.value)
    if action.type == "change" then
        C_PetBattles.ChangePet(action.value)
    elseif action.type == "use" then
        C_PetBattles.UseAbility(action.value)
    elseif action.type == "standby" then
        C_PetBattles.SkipTurn()
    end
end

function GetSchemeAI()
    return {
        --todo 需要确认事件次序。确认回合结束时buff和cd的时间
        schemeName = "AIScheme",
        action_round = -1,
        change_round = -1,
        InitGame = function(self)
            AII:InitGame()
        end,
        Select = function(self, round)
            if round == self.change_round then
                return 
            end
            -- 使用增量更新机制
            AII:UpdateState(round)
            AII:SetChangePetState(round)
            local action = AII:DecideActions(round)
            assert(action and action.type == "change", "error action")
            performAction(action)
            self.change_round = round
        end,
        Battle = function(self, round)
            if round == self.action_round then
                return 
            end
            AII:UpdateState(round)
            local action = AII:DecideActions(round)
            performAction(action)
            self.action_round = round
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


function Strategy:Init(targetMode)
    self.startTime = time()
    self.scheme = nil
    self.opponentTeam = {}
    self.recording = false
    self.round = 0
    self.lossTime = nil
    self.forfeited = false
    
    if PPBestConfig.mode == Const.MODE_ASSIST then
        if targetMode == Const.MODE_WANT_EXP then
            self.scheme = GetCooperateForfeitScheme(62, 1)
            return
        else 
            self.scheme = GetCooperateForfeitScheme(0, 1)
            return
        end
    elseif PPBestConfig.mode == Const.MODE_WANT_PET_LEVEL then
        --15s投降 因为辅助方预期立刻投降
        self.scheme = GetCooperateForfeitScheme(15, 3)
        return
    elseif PPBestConfig.mode == Const.MODE_WANT_EXP then
        --70s投降，因为辅助方预期60s投降
        self.scheme = GetCooperateForfeitScheme(70, 1)
        return
    elseif PPBestConfig.mode == Const.MODE_WANT_WIN then
        --不投降，直到赢了才投降
        self.scheme = GetCooperateForfeitScheme(15, 1)
        return
    elseif PPBestConfig.mode == Const.MODE_AI then
        --15s投降 因为辅助方预期立刻投降
        self.scheme = GetSchemeAI()
    else 
        -- 处理己方宠物信息
        if BattleUtils:AllyTeamIs({PET_ID_NEXUS_WHELPLING, PET_ID_NEXUS_WHELPLING, PET_ID_NEXUS_WHELPLING}) then
            self.scheme = GetScheme3Nexus()
        elseif BattleUtils:AllyTeamIs({PET_ID_SPRINT_RABBIT, PET_ID_PEBBLE, PET_ID_ARFUS}) then
            self.scheme = GetSchemeRabbitPebbleArfus()
        elseif BattleUtils:AllyTeamIs({PET_ID_MOUNTAIN_COTTONTAIL, PET_ID_PEBBLE, PET_ID_ARFUS}) then
            self.scheme = GetSchemeRabbitPebbleArfus()
        elseif BattleUtils:AllyTeamIs({PET_ID_TOLAI_HARE, PET_ID_PEBBLE, PET_ID_ARFUS}) then
            self.scheme = GetSchemeRabbitPebbleArfus()
        elseif BattleUtils:AllyTeamIs({PET_ID_TOLAI_RABBIT, PET_ID_PEBBLE, PET_ID_ARFUS}) then
            self.scheme = GetSchemeRabbitPebbleArfus()
        elseif BattleUtils:AllyTeamIs({PET_ID_SCAVENGING_PINCHER, PET_ID_SCOURGED_WHELPLING, PET_ID_SCOURGED_WHELPLING}) then
            self.scheme = GetSchemeAAB()
        end
    end
    if not self.scheme then
        self.scheme = GetSimpleScheme()
    end

    local lowLevel = false
    local myTarget = nil
    local enemyTarget = nil

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

    end

    if not C_PetBattles.IsPlayerNPC(LE_BATTLE_PET_ENEMY) then
        self.recording = true
    end
    if type(self.scheme.InitGame) == "function" then
        self.scheme:InitGame()
    end
    BattleUtils:Debug("Using scheme: " .. self.scheme.schemeName)
end

function Strategy:OnRoundComplete(round)
    LogFrame.AddLog("OnRoundComplete")
    self.round = round + 1
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

    if result == "loss" then
        lossCount = lossCount + 1
    else
        lossCount = 0
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
    self.scheme:Select(self.round)
end

function Strategy:PerformBattle()
    self.scheme:Battle(self.round)
end

PPBest.Strategy = Strategy