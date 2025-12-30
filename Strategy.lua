
local MODE_3PP = '3pp'
local MODE_1MIN = '1min'
local MODE_FORFEIT = 'forfeit'

local TARGET_EXP = '我要经验'
local TARGET_WIN = '我要胜场'

local MAX_RECORDS = 200

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
    mode = nil,
    opponentTeam = nil,
    recording = false,
    round = 0,
}


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

    BattleUtils.Debug(record)

    -- 限制记录数量
    while #PPBestHistory.records > MAX_RECORDS do
        table.remove(PPBestHistory.records, 1)
    end
end


function Strategy:Init()
    self.startTime = time()
    self.mode = MODE_3PP
    self.opponentTeam = {}
    self.recording = false
    self.round = 0
        -- 获取对手宠物信息
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
        if name == TARGET_EXP then
            self.mode = MODE_1MIN
        elseif name == TARGET_WIN then
            self.mode = MODE_FORFEIT
        end
    end
    if not C_PetBattles.IsPlayerNPC(LE_BATTLE_PET_ENEMY) then
        self.recording = true
    end

end

function Strategy:OnRoundComplete()
    self.round = self.round + 1
end

function Strategy:OnFinalRound(...)
    local result 
    local winner = ...
    -- PET_BATTLE_FINAL_ROUND会在对手投降时返回2
    if winner == 1 or self.round < 5 then
        result = "win"
    else
        result = "loss"
    end
    Strategy:AddBattleRecord(result)
end

function Strategy:PerformSelect()
    BattleUtils:SwitchToHighestHealthPet()
end

function Strategy:PerformBattle()
    if self.mode == MODE_3PP then
        Strategy:Get3PPScheme()
    elseif self.mode == MODE_1MIN then
        if time() - self.startTime > 60 then
            C_PetBattles.ForfeitGame()
        end
        return
    elseif self.mode == MODE_FORFEIT then
        C_PetBattles.ForfeitGame()
    end
end


function Strategy:Get3PPScheme()
    if C_PetBattles.IsSkipAvailable() then
        local duration = BattleUtils:GetWeatherDuration(BattleUtils.WEATHER_ID_ARCANE_STORM)
        local enemyType = BattleUtils:GetEnemyPetType()

        if BattleUtils:IsUndeadRound() then
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
        return 
    end
end


_G.PPBestStrategy = Strategy