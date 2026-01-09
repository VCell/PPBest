-- PPBest.lua
local PPBest = CreateFrame("Frame")
PPBest:RegisterEvent("ADDON_LOADED")

local PPBest_TITLE = "PPBest"
local BattleUtils = _G.PPBestBattleUtils
local OptionPanel = _G.PPBestOptionPanel
local Strategy = _G.PPBestStrategy

-- 配置变量
PPBestConfig = PPBestConfig or {
    hotkey = "F8",
    
}

-- 按钮创建
local autoButton
local isInPetBattle = false

-- 执行自动战斗
local function PerformAutoBattle()
    if not C_PetBattles.IsInBattle() then 
        if not Strategy:ShouldRest() then
            C_PetBattles.StartPVPMatchmaking()
            C_PetBattles.AcceptQueuedPVPMatch()
            StaticPopupSpecial_Hide(PetBattleQueueReadyFrame)
        end
        return
    end

    if C_PetBattles.ShouldShowPetSelect() then
        Strategy:PerformSelect()
        return
    end

    if C_PetBattles.IsSkipAvailable() then
        Strategy:PerformBattle()
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
function PPBest_SetupHotkey()
    local key = PPBestConfig.hotkey
    if key and key ~= "" and autoButton then
        _G["BINDING_NAME_CLICK PPBestAutoButton:LeftButton"] = "PPBest 自动对战"
        SetOverrideBindingClick(autoButton, true, key, "PPBestAutoButton", "LeftButton")
    end
end

-- 事件处理
PPBest:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == PPBest_TITLE then
            self:UnregisterEvent("ADDON_LOADED")
            self:RegisterEvent("PET_BATTLE_OPENING_START")
            self:RegisterEvent("PET_BATTLE_CLOSE")
            self:RegisterEvent("PET_BATTLE_ACTION_SELECTED")
            self:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")
            self:RegisterEvent("PET_BATTLE_FINAL_ROUND") 

            CreateAutoButton()
            PPBest_SetupHotkey()
            print("|cFF00FF00PPBest 已加载|r")
        end
    elseif event == "PET_BATTLE_OPENING_START" then
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
    elseif event == "PET_BATTLE_ACTION_SELECTED" then
        
    elseif event == "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE" then
        Strategy:OnRoundComplete()
    elseif event == "PET_BATTLE_FINAL_ROUND" then
        Strategy:OnFinalRound(...)
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