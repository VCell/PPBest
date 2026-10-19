-- Modes.lua
-- 所有模式的实现，每个模式持有自己的全部状态与行为：
--   XiaoyiMode            小易模式（固定队伍 + 固定出招循环）
--   AIMode                AI 搜索模式
--   WantMode (x4)         互刷主刷方：WANT_PET_LEVEL / WANT_EXP / WANT_ALL / WANT_WIN
--   AssistMode            互刷辅助方
-- 互刷双方共用 Protocol（密语协议）和 ForfeitMode（投降 / 随机出招）

local _, PPBest = ...
local Strategy = PPBest.Strategy
local ModeBase = Strategy.ModeBase
local BattleUtils = PPBest.BattleUtils
local Const = PPBest.Const
local LogFrame = PPBest.LogFrame
local AII = PPBest.SearchInterface

---------------------------------------------------------------------
-- 公共小工具
---------------------------------------------------------------------
local function QueuePVP()
    C_PetBattles.StartPVPMatchmaking()
    C_PetBattles.AcceptQueuedPVPMatch()
    StaticPopupSpecial_Hide(PetBattleQueueReadyFrame)
end

local function PerformAction(action)
    LogFrame:AddLog("Perform action: " .. action.type .. " " .. action.value)
    if action.type == "change" then
        C_PetBattles.ChangePet(action.value)
    elseif action.type == "use" then
        C_PetBattles.UseAbility(action.value)
    elseif action.type == "standby" then
        C_PetBattles.SkipTurn()
    end
end

---------------------------------------------------------------------
-- 小易模式
---------------------------------------------------------------------
local XIAOYI_PET_ACTIONS = {
    [1180] = {2, 1, 3},     -- 赞达拉袭胫者
    [1211] = {3, 1, 2},     -- 赞达拉撕踝者
    [1152] = {2, 1, 3, 1},  -- 克罗马尼斯
}
local XIAOYI_PET_PRIORITY = {
    [1180] = 1,
    [1211] = 2,
    [1152] = 3,
}
local XIAOYI_PET_ABILITY = {
    [1180] = {921, 919, 917},  -- 狩猎小队 黑爪 血牙
    [1211] = {921, 364, 919},
    [1152] = {110, 362, 593},
}

-- 一键流程：
--   prepare  首次点击：按钮执行宏（选中小艺、复活、组队），热键临时改绑为"与目标互动"
--   interact 再次按键：游戏自带的交互进入宠物对战
-- 对战开始/结束、或超时未进入对战，都回到 prepare 并把热键绑回插件按钮
local STAGE_PREPARE = "prepare"
local STAGE_INTERACT = "interact"
local INTERACT_TIMEOUT = 5  -- 秒
-- 组队放在复活之后执行，所以通过 /run 调用，而不是在点击回调里直接组队
local XIAOYI_MACRO = "/target 幸运的小艺\n/use 复活战斗宠物\n/run PPBest_BuildXiaoyiTeam()"

local XiaoyiMode = ModeBase:Extend{
    stage = STAGE_PREPARE,
    token = 0,            -- 用于让已经过期的超时回调失效
    petID = 0,
    actionCount = 0,
    lastActRound = -1,
}

function XiaoyiMode:BuildTeam()
    BattleUtils:BuildTeamByProriority(XIAOYI_PET_PRIORITY)
    BattleUtils:SetPetsAbility(XIAOYI_PET_ABILITY)
end

_G.PPBest_BuildXiaoyiTeam = function()
    XiaoyiMode:BuildTeam()
end

function XiaoyiMode:ResetStage()
    self.stage = STAGE_PREPARE
    self.token = self.token + 1
    PPBest.Hotkey:UseButton()
end

function XiaoyiMode:EnterInteractStage()
    self.stage = STAGE_INTERACT
    self.token = self.token + 1
    local token = self.token
    PPBest.Hotkey:UseInteract()

    -- 超时仍未进入对战（距离太远、没选中目标等），恢复热键，避免卡在交互绑定上
    C_Timer.After(INTERACT_TIMEOUT, function()
        if self.token == token and self.stage == STAGE_INTERACT then
            self:ResetStage()
        end
    end)
end

function XiaoyiMode:OutBattle(ctx, button)
    if self.stage ~= STAGE_PREPARE then
        return
    end
    -- 真实战斗中无法修改安全按钮属性，等战斗结束后的下次点击再处理
    if not button or InCombatLockdown() then
        return
    end

    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", XIAOYI_MACRO)
    self:EnterInteractStage()
end

function XiaoyiMode:OnBattleClose()
    self:ResetStage()
end

function XiaoyiMode:OnBattleStart()
    self:ResetStage()
    self.petID = 0
    self.actionCount = 0
    -- 用 -1 而不是 0：Strategy.round 从 0 开始，初始为 0 会导致第一回合被当成"已出过招"
    self.lastActRound = -1
end

function XiaoyiMode:Select()
    BattleUtils:SwitchPetByOrder()
end

function XiaoyiMode:Battle(ctx, round)
    if round == self.lastActRound then
        return
    end

    local petIndex = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
    local petID = C_PetBattles.GetPetSpeciesID(LE_BATTLE_PET_ALLY, petIndex)
    local actions = XIAOYI_PET_ACTIONS[petID]

    if petID ~= self.petID then
        self.petID = petID
        self.actionCount = 0
    end
    self.actionCount = self.actionCount + 1
    self.lastActRound = round

    if actions then
        local action = actions[(self.actionCount - 1) % #actions + 1]
        BattleUtils:UseSkillByPriority({action, 1})
    else
        BattleUtils:UseSkillByPriority({1, 2, 3})
    end
end

---------------------------------------------------------------------
-- AI 模式
---------------------------------------------------------------------
local LOSS_REST_TIME = 35  -- 失败后休息时间（秒）

local AIMode = ModeBase:Extend{
    roundSearcher = nil,
    lossTime = nil,
}

function AIMode:ShouldRest()
    return self.lossTime ~= nil and (time() - self.lossTime) < LOSS_REST_TIME
end

function AIMode:OutBattle()
    if not self:ShouldRest() then
        QueuePVP()
    end
end

function AIMode:OnBattleStart()
    self.roundSearcher = nil
    self.lossTime = nil
    AII:InitGame()
end

-- todo: 需要确认事件次序，确认回合结束时 buff 和 cd 的时间
-- 每次点击推进一步搜索；搜索完成或超时后返回决策，否则返回 nil
function AIMode:Perform(actionType, round)
    local key = actionType .. tostring(round)
    local searcher = self.roundSearcher

    if not searcher or searcher.key ~= key then
        AII:UpdateState(round)
        AII:SetChangePetState(round)
        self.roundSearcher = AII:NewSearch(key)
        self.roundSearcher:Search()
        return nil
    end

    if searcher:IsDone() then
        return searcher:DecideActions(round)
    end

    local timeRemaining, turnTime = C_PetBattles.GetTurnTimeInfo()
    if turnTime - timeRemaining > PPBestConfig.searchTime then
        return searcher:DecideActions(round)
    end

    searcher:Search(round)
    return nil
end

function AIMode:Select(ctx, round)
    local action = self:Perform("select", round)
    if action then
        assert(action.type == "change", "error action")
        PerformAction(action)
    end
end

function AIMode:Battle(ctx, round)
    local action = self:Perform("battle", round)
    if action then
        PerformAction(action)
    end
end

function AIMode:OnRoundComplete(ctx, round)
    AII:UpdateRound(round)
end

function AIMode:OnBattleEnd(ctx, result)
    self.lossTime = (result == "loss") and time() or nil
end

function AIMode:OnBattleClose()
    AII.game = nil
end

---------------------------------------------------------------------
-- 互刷：密语协议
--   查询：  "PPBestAutoInfo query"                     辅助 -> 主刷
--   应答：  "PPBestAutoInfo <mode> <l1> <l2> <l3>"      主刷 -> 辅助
---------------------------------------------------------------------
local PREFIX = "PPBestAutoInfo"

local Protocol = {}

-- 不是协议消息或格式错误时返回 nil（不再 assert，避免陌生人的密语触发报错）
function Protocol.Parse(msg)
    local parts = {strsplit(" ", msg)}
    if parts[1] ~= PREFIX or #parts < 2 then
        return nil
    end

    local res = { target = parts[2] }
    if #parts == 5 then
        local l1, l2, l3 = tonumber(parts[3]), tonumber(parts[4]), tonumber(parts[5])
        if l1 and l2 and l3 then
            res.levels = {l1, l2, l3}
        end
    end
    return res
end

function Protocol.SendQuery(target)
    SendChatMessage(PREFIX .. " query", "WHISPER", nil, target)
end

function Protocol.SendLevels(target, modeName, levels)
    local msg = string.format("%s %s %d %d %d", PREFIX, modeName, levels[1], levels[2], levels[3])
    SendChatMessage(msg, "WHISPER", nil, target)
end

---------------------------------------------------------------------
-- 互刷：公共基类 ForfeitMode
-- 战斗中按超时投降；连续失败达到上限时改为随机出招（保证辅助方每 10 场赢一场）
---------------------------------------------------------------------
local STATE_WAITING_INFO = "waiting_info"
local STATE_WAITING_START = "waiting_start"
local STATE_PLAYING = "playing"

local LOSS_STREAK_LIMIT = 10
local lossStreak = 0  -- 互刷双方共用的连续失败次数

local ForfeitMode = ModeBase:Extend{
    record = false,   -- 互刷不记录战绩
    timeout = 0,
    firstPet = 1,
    startTime = 0,
}

function ForfeitMode:OnBattleStart()
    self.startTime = time()
end

function ForfeitMode:Select()
    C_PetBattles.ChangePet(self.firstPet)
end

function ForfeitMode:Battle(ctx)
    if lossStreak >= LOSS_STREAK_LIMIT then
        local slot = math.random(1, 3)
        BattleUtils:UseSkillByPriority({slot, slot % 3 + 1, (slot + 1) % 3 + 1})
        return
    end
    if time() - self.startTime > self.timeout then
        ctx:Forfeit()
    end
end

function ForfeitMode:OnBattleEnd(ctx, result)
    if result == "loss" then
        lossStreak = lossStreak + 1
    else
        lossStreak = 0
    end
end

---------------------------------------------------------------------
-- 互刷：主刷方（WANT_*）
-- 状态机：等待辅助方查询 -> 回复目标等级 -> 排队
---------------------------------------------------------------------
local WantMode = ForfeitMode:Extend{
    state = STATE_WAITING_INFO,
    assistId = "",
}

function WantMode:Reset()
    self.state = STATE_WAITING_INFO
    self.assistId = ""
end

function WantMode:ReplyLevels()
    BattleUtils:CheckTeamByMode(self.name)
    local levels = {}
    for i = 1, 3 do
        local level = 0
        local guid = C_PetJournal.GetPetLoadOutInfo(i)
        if guid then
            local _, _, petLevel = C_PetJournal.GetPetInfoByPetID(guid)
            level = petLevel or 0
        end
        levels[i] = level
    end
    Protocol.SendLevels(self.assistId, self.name, levels)
end

function WantMode:OutBattle()
    if self.state == STATE_WAITING_INFO then
        print("等待队友消息中...")
    elseif self.state == STATE_WAITING_START then
        self:ReplyLevels()
        self.state = STATE_PLAYING
    elseif self.state == STATE_PLAYING then
        QueuePVP()
    end
end

function WantMode:OnWhisper(ctx, msg, sender)
    local info = Protocol.Parse(msg)
    if info and info.target == "query" then
        self.assistId = sender
        self.state = STATE_WAITING_START
    end
end

function WantMode:OnBattleClose()
    self:Reset()
end

-- 四个主刷模式只是参数不同：投降超时与首发宠物
local WANT_MODES = {
    -- 15s 投降：辅助方预期立刻投降
    [Const.MODE_WANT_PET_LEVEL] = { timeout = 15, firstPet = 3 },
    -- 70s 投降：辅助方预期 60s 投降
    [Const.MODE_WANT_EXP]       = { timeout = 70, firstPet = 1 },
    [Const.MODE_WANT_ALL]       = { timeout = 70, firstPet = 3 },
    [Const.MODE_WANT_WIN]       = { timeout = 15, firstPet = 1 },
}

for name, cfg in pairs(WANT_MODES) do
    Strategy:RegisterMode(name, WantMode:Extend{
        name = name,
        timeout = cfg.timeout,
        firstPet = cfg.firstPet,
    })
end

---------------------------------------------------------------------
-- 互刷：辅助方（ASSIST）
-- 状态机：向目标发查询 -> 收到目标等级 -> 按等级组队 -> 排队
---------------------------------------------------------------------
local MIN_QUERY_INTERVAL = 10   -- 两次查询的最小间隔（秒）
local ASSIST_WAIT_TIMEOUT = 120 -- 等待队友过久则重新开始（秒）

local AssistMode = ForfeitMode:Extend{
    name = Const.MODE_ASSIST,
    state = STATE_WAITING_INFO,
    targetMode = "",      -- 主刷方的模式，决定本方投降时机
    targetLevel = {},
    lastQueryTime = 0,
    waitStart = 0,        -- 战斗外等待的起点（区别于战斗内的 startTime）
}

function AssistMode:Reset()
    self.state = STATE_WAITING_INFO
    self.targetMode = ""
    self.targetLevel = {}
    self.waitStart = time()
end

function AssistMode:OutBattle()
    if self.state == STATE_WAITING_INFO then
        if time() - self.lastQueryTime > MIN_QUERY_INTERVAL then
            self.waitStart = time()
            local target = PPBestConfig.assistTarget
            if target and target ~= "" then
                Protocol.SendQuery(target)
                self.lastQueryTime = time()
            else
                print("请在设置中填写互刷目标ID（名字-服务器）")
            end
        end
    elseif self.state == STATE_WAITING_START then
        BattleUtils:BuildTeamByLevel(self.targetLevel)
        self.state = STATE_PLAYING
    elseif self.state == STATE_PLAYING then
        if time() - self.waitStart > ASSIST_WAIT_TIMEOUT then
            print("等待队友过久，重新开始匹配")
            C_PetBattles.StopPVPMatchmaking()
            self:Reset()
        else
            QueuePVP()
        end
    end
end

function AssistMode:OnWhisper(ctx, msg, sender)
    local info = Protocol.Parse(msg)
    if info and info.levels and Const.isCooperateMainMode(info.target) then
        self.targetLevel = info.levels
        self.targetMode = info.target
        self.state = STATE_WAITING_START
    end
end

function AssistMode:OnBattleStart(ctx)
    ForfeitMode.OnBattleStart(self, ctx)
    self.firstPet = 1
    if self.targetMode == Const.MODE_WANT_EXP or self.targetMode == Const.MODE_WANT_ALL then
        self.timeout = 65
    else
        self.timeout = 0
    end
end

function AssistMode:OnBattleClose()
    self:Reset()
    self.lastQueryTime = time()
end

---------------------------------------------------------------------
-- 注册
---------------------------------------------------------------------
Strategy:RegisterMode(Const.MODE_XIAOYI, XiaoyiMode)
Strategy:RegisterMode(Const.MODE_AI, AIMode)
Strategy:RegisterMode(Const.MODE_ASSIST, AssistMode)