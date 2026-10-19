-- PPBest.lua
local _, PPBest = ...
local LogFrame = PPBest.LogFrame
local StateFrame = PPBest.StateFrame
local OptionPanel = PPBest.OptionPanel
local BattleUtils = PPBest.BattleUtils
local Strategy = PPBest.Strategy
local AII = PPBest.SearchInterface

local PPBestFrame = CreateFrame("Frame")
PPBestFrame:RegisterEvent("ADDON_LOADED")

local PPBEST_TITLE = "PPBest"

-- 按钮创建
local autoButton
local isInPetBattle = false

---------------------------------------------------------------------
-- 热键：绑定到插件按钮，或临时绑定到"与目标互动"（小艺一键模式使用）
---------------------------------------------------------------------
local Hotkey = { interact = false }
PPBest.Hotkey = Hotkey

function Hotkey:Apply()
    local key = PPBestConfig.hotkey
    if not autoButton or not key or key == "" then
        return
    end
    -- 战斗中无法修改绑定，等 PLAYER_REGEN_ENABLED 再补
    if InCombatLockdown() then
        return
    end

    ClearOverrideBindings(autoButton)
    if self.interact then
        SetOverrideBinding(autoButton, true, key, "INTERACTTARGET")
    else
        SetOverrideBindingClick(autoButton, true, key, "PPBestAutoButton", "LeftButton")
    end
end

function Hotkey:UseButton()
    self.interact = false
    self:Apply()
end

function Hotkey:UseInteract()
    self.interact = true
    self:Apply()
end

---------------------------------------------------------------------
-- 自动战斗入口
---------------------------------------------------------------------
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
        Strategy:PerformOutBattle(autoButton)
    end
end

-- 创建自动按钮
local function CreateAutoButton()
    autoButton = CreateFrame("Button", "PPBestAutoButton", UIParent, "UIPanelButtonTemplate, SecureActionButtonTemplate")
    autoButton:RegisterForClicks("AnyUp", "AnyDown")
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
            -- 清掉上一次可能设置的宏，避免之后每次点击都重复执行
            if not InCombatLockdown() then
                self:SetAttribute("type", nil)
            end
            PerformAutoBattle()
        end
    end)

    -- 更新按钮显示状态
    autoButton:SetShown(isInPetBattle)
end

-- 键盘快捷键设置
local function PPBest_SetupHotkey()
    _G["BINDING_NAME_CLICK PPBestAutoButton:LeftButton"] = "PPBest 自动对战"
    Hotkey:UseButton()
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
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
            OptionPanel:Initialize()
            CreateAutoButton()
            PPBest_SetupHotkey()
            print("|cFF00FF00PPBest 已加载|r")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- 战斗中没能改成功的绑定，在这里补上
        Hotkey:Apply()
    elseif event == "PET_BATTLE_OPENING_START" then
        PPBestLastLog = {}
        LogFrame:Create()
        StateFrame:Create()
        LogFrame:AddLog("EVENT: PET_BATTLE_OPENING_START")
        isInPetBattle = true
        if autoButton then
            autoButton:SetShown(true)
        end
        Strategy:Init()
    elseif event == "PET_BATTLE_CLOSE" then
        isInPetBattle = false
        if autoButton then
            autoButton:SetShown(false)
        end
        Strategy:OnBattleClose()
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
        local msg, sender = ...
        Strategy:OnWhisper(msg, sender)
    elseif event == "CHAT_MSG_PET_BATTLE_COMBAT_LOG" then
        local msg = ...
        table.insert(PPBestLastLog, msg)
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

_G.PPBest_Run = PerformAutoBattle