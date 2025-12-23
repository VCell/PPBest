-- PPBest.lua
local PPBest = CreateFrame("Frame")
PPBest:RegisterEvent("ADDON_LOADED")

local PPBest_TITLE = "PPBest"
local BattleUtils = _G.PPBestBattleUtils
local OptionPanel = _G.PPBestOptionPanel
-- 配置变量
PPBestConfig = PPBestConfig or {
    hotkey = "F8",
    
}
PPBestHistory = PPBestHistory or {
    version = 1,
    records = {},
    totalBattles = 0,
    wins = 0,
    losses = 0,
}

-- 当前对战信息
local currentBattleInfo = nil

-- 按钮创建
local autoButton
local isInPetBattle = false
local round = 0

-- 记录当前对战信息
local function RecordCurrentBattleInfo()
    currentBattleInfo = {
        startTime = time(),
        opponentTeam = {},
        opponentQualities = {},
        result = nil,
        duration = 0,
    }
    
    -- 获取对手宠物信息
    for petIndex = 1, C_PetBattles.GetNumPets(LE_BATTLE_PET_ENEMY) do
        local name = C_PetBattles.GetName(LE_BATTLE_PET_ENEMY, petIndex)
        local petType = C_PetBattles.GetPetType(LE_BATTLE_PET_ENEMY, petIndex)
        local level = C_PetBattles.GetLevel(LE_BATTLE_PET_ENEMY, petIndex)
        local quality = C_PetBattles.GetBreedQuality(LE_BATTLE_PET_ENEMY, petIndex)
        local id = C_PetBattles.GetPetSpeciesID(LE_BATTLE_PET_ENEMY, petIndex)
        table.insert(currentBattleInfo.opponentTeam, {
            name = name,
            type = petType,
            level = level,
            quality = quality,
            id = id,
        })
        
        table.insert(currentBattleInfo.opponentQualities, quality)
    end
end

-- 添加对战记录
local function AddBattleRecord()
    if not currentBattleInfo or not currentBattleInfo.result then
        return
    end
    
    -- 更新统计数据
    PPBestHistory.totalBattles = (PPBestHistory.totalBattles or 0) + 1
    if currentBattleInfo.result == "win" then
        PPBestHistory.wins = (PPBestHistory.wins or 0) + 1
    elseif currentBattleInfo.result == "loss" then
        PPBestHistory.losses = (PPBestHistory.losses or 0) + 1
    end
    
    record = string.format("%s, %s, %d, %d, [%s-%s-%s],[%d-%d-%d]", 
        date("%Y-%m-%d %H:%M:%S", currentBattleInfo.startTime), currentBattleInfo.result, round, time() - currentBattleInfo.startTime, 
        currentBattleInfo.opponentTeam[1].name, currentBattleInfo.opponentTeam[2].name, currentBattleInfo.opponentTeam[3].name,
        currentBattleInfo.opponentTeam[1].id, currentBattleInfo.opponentTeam[2].id, currentBattleInfo.opponentTeam[3].id
    )
    
    -- 添加到记录列表
    table.insert(PPBestHistory.records, record)

    BattleUtils.Debug(record)

    -- 限制记录数量
    local maxRecords = PPBestConfig.maxHistoryRecords or 100
    while #PPBestHistory.records > maxRecords do
        table.remove(PPBestHistory.records, 1)
    end
    currentBattleInfo = nil
end



-- 执行自动战斗
local function PerformAutoBattle()
    if not C_PetBattles.IsInBattle() then 
        BattleUtils:Debug("PerformAutoBattle Not IsInBattle")
        return
    end

    if C_PetBattles.ShouldShowPetSelect() then
        BattleUtils:SwitchToHighestHealthPet()
        return
    end

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
        round = 0
        if not C_PetBattles.IsPlayerNPC(LE_BATTLE_PET_ENEMY) then
            RecordCurrentBattleInfo()
        end
    elseif event == "PET_BATTLE_CLOSE" then
        isInPetBattle = false
        if autoButton then
            autoButton:SetShown(false)
        end
    elseif event == "PET_BATTLE_ACTION_SELECTED" then
        
    elseif event == "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE" then
        round = round+1
    elseif event == "PET_BATTLE_FINAL_ROUND" then
        if currentBattleInfo then
            -- 对战结束，记录结果
            local winner = ...
            -- PET_BATTLE_FINAL_ROUND会在对手投降时返回2
            if winner == 1 or round < 5 then
                currentBattleInfo.result = "win"
            else
                currentBattleInfo.result = "loss"
            end

            AddBattleRecord()
        end

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