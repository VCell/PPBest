-- Strategy.lua
-- 模式调度器：
--   * 持有一场战斗内所有模式共用的状态（round、对手队伍、是否投降、战绩记录）
--   * 把生命周期事件转发给"当前模式"，自身不含任何具体模式的判断
--   * 具体模式在 Modes.lua 中实现，并通过 Strategy:RegisterMode 注册
--
-- 加载顺序（toc）：... Strategy.lua -> Modes.lua -> PPBest.lua

local _, PPBest = ...
local BattleUtils = PPBest.BattleUtils
local LogFrame = PPBest.LogFrame

local MAX_RECORDS = 200

PPBestHistory = PPBestHistory or {
    version = 1,
    records = {},
    totalBattles = 0,
    wins = 0,
    losses = 0,
}

---------------------------------------------------------------------
-- ModeBase：模式基类，所有钩子默认空实现
-- ctx 参数始终是 Strategy，模式通过它访问公共能力（Forfeit、round、opponentTeam 等）
---------------------------------------------------------------------
local ModeBase = {
    record = true, -- 是否记录战绩（对手是玩家时）
}
ModeBase.__index = ModeBase

function ModeBase:Extend(o)
    o = o or {}
    o.__index = o
    return setmetatable(o, self)
end

function ModeBase:OutBattle(ctx, button) end                    -- 不在战斗中，点击按钮
function ModeBase:OnBattleStart(ctx) end                -- 战斗开始，对手信息已采集
function ModeBase:Select(ctx, round) end                -- 需要选宠
function ModeBase:Battle(ctx, round) end                -- 需要出招
function ModeBase:OnRoundComplete(ctx, round) end       -- 回合播放结束
function ModeBase:OnBattleEnd(ctx, result) end          -- 胜负已判定，result = "win" / "loss"
function ModeBase:OnBattleClose(ctx) end                -- 战斗窗口关闭
function ModeBase:OnWhisper(ctx, msg, sender) end       -- 收到密语（未过滤，由模式自己识别）

---------------------------------------------------------------------
-- Strategy
---------------------------------------------------------------------
local Strategy = {
    ModeBase = ModeBase,
    modes = {},
    mode = nil,           -- 当前战斗锁定的模式
    startTime = nil,
    opponentTeam = {},
    recording = false,
    round = 0,
    forfeited = false,
}

function Strategy:RegisterMode(name, mode)
    assert(name, "RegisterMode: name is nil")
    assert(mode, "RegisterMode: mode is nil")
    self.modes[name] = mode
end

-- 按当前配置取模式（战斗外使用）；未知模式时返回空实现，避免报错
function Strategy:GetConfiguredMode()
    local mode = self.modes[PPBestConfig.mode]
    if not mode then
        print("|cFFFF0000PPBest: 未知模式 " .. tostring(PPBestConfig.mode) .. "|r")
        return ModeBase
    end
    return mode
end

---------------------------------------------------------------------
-- 公共能力
---------------------------------------------------------------------
function Strategy:Forfeit()
    self.forfeited = true
    C_PetBattles.ForfeitGame()
end

function Strategy:CollectOpponent()
    self.opponentTeam = {}
    for petIndex = 1, C_PetBattles.GetNumPets(LE_BATTLE_PET_ENEMY) do
        table.insert(self.opponentTeam, {
            name = C_PetBattles.GetName(LE_BATTLE_PET_ENEMY, petIndex),
            type = C_PetBattles.GetPetType(LE_BATTLE_PET_ENEMY, petIndex),
            level = C_PetBattles.GetLevel(LE_BATTLE_PET_ENEMY, petIndex),
            quality = C_PetBattles.GetBreedQuality(LE_BATTLE_PET_ENEMY, petIndex),
            id = C_PetBattles.GetPetSpeciesID(LE_BATTLE_PET_ENEMY, petIndex),
        })
    end
end

function Strategy:AddBattleRecord(result)
    if not self.recording then
        return
    end

    PPBestHistory.totalBattles = (PPBestHistory.totalBattles or 0) + 1
    if result == "win" then
        PPBestHistory.wins = (PPBestHistory.wins or 0) + 1
    elseif result == "loss" then
        PPBestHistory.losses = (PPBestHistory.losses or 0) + 1
    end

    local names, ids = {}, {}
    for i, pet in ipairs(self.opponentTeam) do
        names[i] = pet.name
        ids[i] = pet.id
    end

    local record = string.format("%s, %s, %d, %d, [%s],[%s]",
        date("%Y-%m-%d %H:%M:%S", self.startTime), result, self.round, time() - self.startTime,
        table.concat(names, "-"), table.concat(ids, "-"))

    table.insert(PPBestHistory.records, record)
    BattleUtils:Debug(record)

    while #PPBestHistory.records > MAX_RECORDS do
        table.remove(PPBestHistory.records, 1)
    end
end

---------------------------------------------------------------------
-- 生命周期（由 PPBest.lua 的事件转发调用）
---------------------------------------------------------------------

-- PET_BATTLE_OPENING_START
function Strategy:Init()
    -- 战斗开始时锁定模式，避免战斗中修改配置导致行为中途切换
    self.mode = self:GetConfiguredMode()
    self.startTime = time()
    self.round = 0
    self.forfeited = false

    -- 公共逻辑：所有模式都先采集对手信息，再交给模式
    self:CollectOpponent()
    self.recording = (self.mode.record ~= false) and not C_PetBattles.IsPlayerNPC(LE_BATTLE_PET_ENEMY)

    self.mode:OnBattleStart(self)
end

-- 点击按钮且不在战斗中
-- button：插件的安全按钮，需要在点击时执行宏的模式（如小艺）会用到
function Strategy:PerformOutBattle(button)
    self:GetConfiguredMode():OutBattle(self, button)
end

function Strategy:PerformSelect()
    if self.mode then
        self.mode:Select(self, self.round)
    end
end

function Strategy:PerformBattle()
    if self.mode then
        self.mode:Battle(self, self.round)
    end
end

-- PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE
-- 本轮无法操作时没有点击事件触发，但仍需正常更新轮次，所以放在事件里而不是点击里
function Strategy:OnRoundComplete(round)
    LogFrame:AddLog("OnRoundComplete")
    self.round = round + 1
    if self.mode then
        self.mode:OnRoundComplete(self, self.round)
    end
end

-- PET_BATTLE_FINAL_ROUND
-- 事件参数 winner 时常不可靠，改用 BattleUtils:DetermineWinner 判定
function Strategy:OnFinalRound()
    local result
    if self.forfeited then
        result = "loss"
    elseif BattleUtils:DetermineWinner() >= 0 then
        result = "win"
    else
        result = "loss"
    end

    self:AddBattleRecord(result)
    if self.mode then
        self.mode:OnBattleEnd(self, result)
    end
end

-- PET_BATTLE_CLOSE
function Strategy:OnBattleClose()
    if self.mode then
        self.mode:OnBattleClose(self)
    end
end

-- CHAT_MSG_WHISPER：战斗外也会收到，所以用当前配置的模式
function Strategy:OnWhisper(msg, sender)
    self:GetConfiguredMode():OnWhisper(self, msg, sender)
end

PPBest.Strategy = Strategy