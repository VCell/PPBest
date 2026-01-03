

local TARGET_EXP = '我要经验'
local TARGET_WIN = '我要胜场'

local TEAM_3NEXUS = {1165, 1165, 1165}

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
    opponentTeam = nil,
    recording = false,
    round = 0,
    scheme = nil,
}

function GetForfeiScheme()
    return {
        Select = function()
            BattleUtils:SwitchToHighestHealthPet()
        end,
        Battle = function(...)
            C_PetBattles.ForfeitGame()
        end,
    }
end

function Get1MinScheme()
    local startTime = time()
    return {
        Select = function()
            BattleUtils:SwitchToHighestHealthPet()
        end,
        Battle = function(...)
            if time() - startTime > 60 then
                C_PetBattles.ForfeitGame()
            end
        end,
    }
end

function GetRandomScheme()
    return {
        Select = function()
            BattleUtils:SwitchToHighestHealthPet()
        end,
        Battle = function(...)
            local skillSlot = math.random(1,3)
            BattleUtils:UseSkillByPriority({skillSlot, ((skillSlot)%3)+1, ((skillSlot+1)%3)+1})
        end,
    }
end

function Get3PPScheme()
    local forfeit = false
    local forfeitTeam = {
        {1165, 1525, 1526},  -- 化石幼兽 便携式世界毁灭者 乌鸦
    }
    for _, team in ipairs(forfeitTeam) do
        if BattleUtils:EnemyTeamIs(team) then
            forfeit = true
        end
    end

    return {
        forfeit = forfeit,
        Select = function()
            BattleUtils:SwitchToHighestHealthPet()
        end,
        Battle = function(round)
            if self.forfeit and round>1 then
                C_PetBattles.ForfeitGame()
                return
            end
            if C_PetBattles.IsSkipAvailable() then
                local duration = BattleUtils:GetWeatherDuration(BattleUtils.WEATHER_ID_ARCANE_STORM)
                local enemyType = BattleUtils:GetEnemyPetType()
                if self.round > 1 then
                    for _, team in ipairs(forfeitTeam) do
                        if BattleUtils:EnemyTeamIs(team) then
                            C_PetBattles.ForfeitGame()
                            return
                        end
                    end
                end
        
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

    BattleUtils.Debug(record)

    -- 限制记录数量
    while #PPBestHistory.records > MAX_RECORDS do
        table.remove(PPBestHistory.records, 1)
    end
end


function Strategy:Init()
    self.startTime = time()
    self.scheme = GetRandomScheme()
    self.opponentTeam = {}
    self.recording = false
    self.round = 0
    
    -- 处理己方宠物信息
    if BattleUtils:AllyTeamIs(TEAM_3NEXUS) then
        self.scheme = Get3PPScheme()
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
        if name == TARGET_EXP then
            self.scheme = Get1MinScheme()
        elseif name == TARGET_WIN then
            self.scheme = GetForfeiScheme()
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
    self.scheme.Select()
end

function Strategy:PerformBattle()
    self.scheme.Battle(self.round)
end

_G.PPBestStrategy = Strategy