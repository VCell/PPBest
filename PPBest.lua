-- PPBest.lua

local _, PPBest = ...
local Const = PPBest.Const
local LogFrame = PPBest.LogFrame
local OptionPanel = PPBest.OptionPanel
local BattleUtils = PPBest.BattleUtils
local Strategy = PPBest.Strategy
local AII = PPBest.SearchInterface

local PPBestFrame = CreateFrame("Frame")
PPBestFrame:RegisterEvent("ADDON_LOADED")

local PPBEST_TITLE = "PPBest"
local MIN_QUERY_INTERVAL = 10

local PPBEST_MSG_PREFIX = "PPBestAutoInfo"

-- 按钮创建
local autoButton
local isInPetBattle = false
local lastQueryTime = 0

local STATE_WAITING_INFO = "waiting_info"
local STATE_WAITING_START = "waiting_start"
local STATE_PLAYING = "playing"
local CooperateController = {
    state = STATE_WAITING_INFO,
    assistId = "",
    targetMode = "",
    targetLevel = {},
    startTime = time()
}
function CooperateController:Reset()
    self.state = STATE_WAITING_INFO
    self.assist_id = ""
    self.targetMode = ""
    self.targetLevel = {}
    self.startTime = time()
end


-- 执行自动战斗
local function PerformAutoBattle()
    if C_PetBattles.IsInBattle() then 
        if C_PetBattles.ShouldShowPetSelect() then
            Strategy:PerformSelect()
            return
        end

        if C_PetBattles.IsSkipAvailable() then
            Strategy:PerformBattle()
            return
        end
    else 
        if  Const.isCooperateMainMode(PPBestConfig.mode) then
            if CooperateController.state == STATE_WAITING_INFO then
                print("等待队友消息中...")
            elseif CooperateController.state == STATE_WAITING_START then
                --回复队友消息，告知目标等级
                BattleUtils:checkTeamByMode(PPBestConfig.mode)
                local levels = {}
                for i=1,3 do
                    local guid = C_PetJournal.GetPetLoadOutInfo(i)
                    local _,_,level = C_PetJournal.GetPetInfoByPetID(guid)
                    table.insert(levels, level)
                end
                local msg = string.format("%s %s %d %d %d", PPBEST_MSG_PREFIX, PPBestConfig.mode, 
                        levels[1], levels[2], levels[3])  
                SendChatMessage(msg, "WHISPER", nil, CooperateController.assistId)
                CooperateController.state = STATE_PLAYING
            elseif CooperateController.state == STATE_PLAYING then
                C_PetBattles.StartPVPMatchmaking()
                C_PetBattles.AcceptQueuedPVPMatch()
                StaticPopupSpecial_Hide(PetBattleQueueReadyFrame)
            end
        elseif PPBestConfig.mode == Const.MODE_ASSIST then
            if CooperateController.state == STATE_WAITING_INFO then
                if time() - lastQueryTime > MIN_QUERY_INTERVAL then 
                    CooperateController.startTime = time()
                    -- 发送查询消息给队友
                    local target = PPBestConfig.assistTarget
                    if target and target ~= "" then
                        SendChatMessage(PPBEST_MSG_PREFIX .. " query", "WHISPER", nil, target)
                        lastQueryTime = time()
                    else
                        print("请在设置中填写互刷目标ID（名字-服务器）")
                    end
                end
            elseif CooperateController.state == STATE_WAITING_START then
                BattleUtils:BuildTeamByLevel(CooperateController.targetLevel)
                CooperateController.state = STATE_PLAYING
            elseif CooperateController.state == STATE_PLAYING then
                if time() - CooperateController.startTime >120 then
                    print("等待队友过久，重新开始匹配")
                    C_PetBattles.StopPVPMatchmaking()
                    CooperateController:Reset()
                else
                    C_PetBattles.StartPVPMatchmaking()
                    C_PetBattles.AcceptQueuedPVPMatch()
                    StaticPopupSpecial_Hide(PetBattleQueueReadyFrame)
                end
            end
        else 
            if not Strategy:ShouldRest() then
                C_PetBattles.StartPVPMatchmaking()
                C_PetBattles.AcceptQueuedPVPMatch()
                StaticPopupSpecial_Hide(PetBattleQueueReadyFrame)
            end
        end
    end

end

-- 创建自动按钮
local function CreateAutoButton()
    autoButton = CreateFrame("Button", "PPBestAutoButton", UIParent, "UIPanelButtonTemplate")
    autoButton:SetSize(100, 40)
    autoButton:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    autoButton:SetMovable(true)
    autoButton:SetUserPlaced(true)
    autoButton:SetClampedToScreen(true)
    
    -- 文字
    autoButton.text = autoButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoButton.text:SetPoint("CENTER")
    autoButton.text:SetText("自动对战")
    
    -- 鼠标提示
    autoButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("PPBest 自动对战")
        GameTooltip:AddLine("点击或按 " .. (PPBestConfig.hotkey) .. " 自动使用技能", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    autoButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- 点击事件
    autoButton:SetScript("PreClick", function(self, button)
        if button == "LeftButton" then
            PerformAutoBattle()
        end
    end)
    
    -- 更新按钮显示状态
    autoButton:SetShown(isInPetBattle)
end

-- 键盘快捷键设置
local function PPBest_SetupHotkey()
    local key = PPBestConfig.hotkey
    if key and key ~= "" and autoButton then
        _G["BINDING_NAME_CLICK PPBestAutoButton:LeftButton"] = "PPBest 自动对战"
        SetOverrideBindingClick(autoButton, true, key, "PPBestAutoButton", "LeftButton")
    end
end

local function parseAutoMsgInfo(msg)
    local parts = {strsplit(" ", msg)}
    assert(#parts >= 2, "消息格式错误")
    local res = {
        target = parts[2],
    }

    if #parts == 5 then
        res.level1 = tonumber(parts[3])
        res.level2 = tonumber(parts[4])
        res.level3 = tonumber(parts[5])
    end
    return res
end
local round = 0
-- 事件处理
PPBestFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == PPBEST_TITLE then
            self:UnregisterEvent("ADDON_LOADED")
            self:RegisterEvent("PET_BATTLE_OPENING_START")
            self:RegisterEvent("PET_BATTLE_CLOSE")
            self:RegisterEvent("PET_BATTLE_ACTION_SELECTED")
            self:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")
            self:RegisterEvent("PET_BATTLE_FINAL_ROUND") 
            self:RegisterEvent("PET_BATTLE_PET_ROUND_RESULTS") 
            self:RegisterEvent("CHAT_MSG_WHISPER")
            self:RegisterEvent("CHAT_MSG_PET_BATTLE_COMBAT_LOG")
            OptionPanel:Initialize()
            CreateAutoButton()
            PPBest_SetupHotkey()
            print("|cFF00FF00PPBest 已加载|r")
        end
    elseif event == "PET_BATTLE_OPENING_START" then
        LogFrame:Create()
        LogFrame:AddLog("EVENT: PET_BATTLE_OPENING_START")
        isInPetBattle = true
        if autoButton then
            autoButton:SetShown(true)
        end
        Strategy:Init(CooperateController.targetMode)
    elseif event == "PET_BATTLE_CLOSE" then
        isInPetBattle = false
        if autoButton then
            autoButton:SetShown(false)
        end
        CooperateController:Reset()
        lastQueryTime = time()
    elseif event == "PET_BATTLE_ACTION_SELECTED" then
        LogFrame:AddLog("EVENT: PET_BATTLE_ACTION_SELECTED")
    elseif event == "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE" then
        LogFrame:AddLog("EVENT: PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")
        Strategy:OnRoundComplete(round)
    elseif event == "PET_BATTLE_PET_ROUND_RESULTS" then
        round = ...
        LogFrame:AddLog(string.format("EVENT: PET_BATTLE_PET_ROUND_RESULTS, round: [%d]", round))
    elseif event == "PET_BATTLE_FINAL_ROUND" then
        Strategy:OnFinalRound(...)
    elseif event == "CHAT_MSG_WHISPER" then
        local msg,sender = ...
        --消息开头是PPBestAutoInfo 说明是插件间的交互信息
        if string.sub(msg, 1, #PPBEST_MSG_PREFIX) == PPBEST_MSG_PREFIX then
            local res = parseAutoMsgInfo(msg)
            
            if res.target == "query" and Const.isCooperateMainMode(PPBestConfig.mode) then 
                CooperateController.assistId = sender
                CooperateController.state = STATE_WAITING_START
                --print("收到队友查询")
            elseif Const.isCooperateMainMode(res.target) and PPBestConfig.mode == Const.MODE_ASSIST then
                CooperateController.targetLevel = {res.level1, res.level2, res.level3}
                CooperateController.state = STATE_WAITING_START
                CooperateController.targetMode = res.target
                --print("收到队友目标等级:", res.level1, res.level2, res.level3)
            end

        end
        -- print("MSG:", msg, ", sender:", sender)
        -- SendChatMessage("ccc", "WHISPER", nil, sender)
    elseif event == "CHAT_MSG_PET_BATTLE_COMBAT_LOG" then
        local msg = ...
        LogFrame:AddLog(msg)
        -- 处理战斗日志，更新光环和推断敌方技能
        AII:ProcessCombatLog(msg)
    end
end)

-- 设置命令
SLASH_PPBEST1 = "/ppbest"
SLASH_PPBEST2 = "/ppb"
SlashCmdList["PPBEST"] = function(msg)
    local command, value = strsplit(" ", msg or "", 2)
    command = command and strlower(command) or ""
    
    if command == "help" then
        print("|cFFFF0000 PPBest :暂无|r")
    elseif command == "test" then 
        BattleUtils.debug = true
        print("|cFFFF0000 PPBest :开启日志|r")
    else
        print("|cFFFF0000未知命令。输入 /ppbest help 查看帮助|r")
    end
end