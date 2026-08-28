local _, PPBest = ...
local AII = PPBest.SearchInterface
local BattleUtils = PPBest.BattleUtils
local Const = PPBest.Const
local LogFrame = PPBest.LogFrame
local MAX_RECORDS = 200
local LOSS_REST_TIME = 35  -- 失败后休息时间，单位秒


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

local function GetSchemeAI()
    return {
        --todo 需要确认事件次序。确认回合结束时buff和cd的时间
        schemeName = "AIScheme",
        InitGame = function(self)
            AII:InitGame()
        end,
        roundSearcher = nil,
        -- onPerform = function(self, round)
        -- end,
        perform = function(self, actionType, round)
            local key = actionType..tostring(round)
            if not self.roundSearcher or self.roundSearcher.key ~= key then
                AII:UpdateState(round)
                AII:SetChangePetState(round)
                self.roundSearcher = AII:NewSearch(key)
                self.roundSearcher:Search()
            elseif self.roundSearcher:IsDone() then
                return self.roundSearcher:DecideActions(round)
            else 
                local timeRemaining, turnTime = C_PetBattles.GetTurnTimeInfo()
                local timeCost = turnTime - timeRemaining
                if timeCost > PPBestConfig.searchTime then
                    return self.roundSearcher:DecideActions(round)
                else 
                    self.roundSearcher:Search(round)
                end
            end
            return nil
        end,
        Select = function(self, round)
            local action = self:perform("select", round)
            if action then
                assert(action and action.type == "change", "error action")
                performAction(action)
            end
        end,
        Battle = function(self, round)
            local action = self:perform("battle", round)
            if action then
                performAction(action)
            end
        end,
        OnRoundComplete = function(self, round)
            AII:UpdateRound(round)
        end
    }
end

local XiaoyiPetActions = {
    [1180] = {2,1,3},--赞达拉袭胫者
    [1211] = {3,1,2},--赞达拉撕踝者
    [1152] = {2,1,3,1}, --克罗马尼斯
}
local XiaoyiPetsPriority = {
    [1180] = 1,
    [1211] = 2,
    [1152] = 3,
}
local XiaoyiPetsAbility = {
    [1180] = {921,919,917},--狩猎小队 黑爪 血牙
    [1211] = {921,364,919},
    [1152] = {110,362,593},
}

local function GetSchemeXiaoyi()
    return {
        schemeName = "XiaoyiScheme",
        actionCount = 0,
        petID = 0,
        round = 0,
        Select = function(self)
            BattleUtils:SwitchPetByOrder()
        end,
        Battle = function(self, round)
            if round == self.round then 
                return nil
            end
        
            local petIndex = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
            local petID = C_PetBattles.GetPetSpeciesID(LE_BATTLE_PET_ALLY, petIndex)
            local actions = XiaoyiPetActions[petID]
            if petID ~= self.petID then
                self.petID = petID
                self.actionCount = 0
            end
            self.actionCount = self.actionCount + 1
            self.round = round
            if actions then
                local action = actions[(self.actionCount - 1) % #actions + 1]
                BattleUtils:UseSkillByPriority({action, 1})
            else 
                BattleUtils:UseSkillByPriority({1,2,3})
            end
        end,
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
        elseif targetMode == Const.MODE_WANT_ALL then
            self.scheme = GetCooperateForfeitScheme(62, 3)
            return
        else 
            self.scheme = GetCooperateForfeitScheme(0, 1)
            return
        end
    elseif PPBestConfig.mode == Const.MODE_WANT_PET_LEVEL then
        --15s投降 因为辅助方预期立刻投降
        self.scheme = GetCooperateForfeitScheme(15, 3)
        return
    elseif PPBestConfig.mode == Const.MODE_WANT_EXP or PPBestConfig.mode == Const.MODE_WANT_ALL then
        --70s投降，因为辅助方预期60s投降
        self.scheme = GetCooperateForfeitScheme(70, 1)
        return
    elseif PPBestConfig.mode == Const.MODE_WANT_WIN then
        self.scheme = GetCooperateForfeitScheme(15, 1)
        return
    elseif PPBestConfig.mode == Const.MODE_AI then
        self.scheme = GetSchemeAI()
    elseif PPBestConfig.mode == Const.MODE_XIAOYI then
        self.scheme = GetSchemeXiaoyi()
    end

    assert(self.scheme, "scheme scheme is nil")

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
    --在本轮回合无法操作时，没有点击事件触发。但是仍需正常更新轮次
    if type(self.scheme.OnRoundComplete) == "function" then
        self.scheme:OnRoundComplete(self.round)
    end
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

function Strategy:PerformOutBattle()
    --判断scheme是否有PerformOutBattle方法

    local mode = PPBestConfig.mode
    if mode == Const.MODE_XIAOYI then

        BattleUtils:BuildTeamByProriority(XiaoyiPetsPriority)
        BattleUtils:SetPetsAbility(XiaoyiPetsAbility)

    end
end

PPBest.Strategy = Strategy