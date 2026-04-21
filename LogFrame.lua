local _,PPBest = ...

local LogFrame = {
    logs = "", -- 存储日志历史
    frame = nil,
}

function LogFrame:Create()
    if not PPBestConfig.enableLogWindow then return end
    local selfRef = self
    if self.frame then
        self.frame:Show()
        return
    end
    -- 创建主框架
    local logFrame = CreateFrame("Frame", "PPBestLogFrame", UIParent, "UIPanelDialogTemplate")
    logFrame:SetSize(400, 500)
    logFrame:SetPoint("LEFT")
    logFrame:SetMovable(true)
    logFrame:EnableMouse(true)
    logFrame:SetClampedToScreen(true)
    logFrame:SetFrameStrata("DIALOG") -- 设置层级，避免被其他UI遮挡
    --logFrame:Hide() -- 默认隐藏

    -- 设置标题
    logFrame.title = logFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    logFrame.title:SetPoint("TOP", logFrame, "TOP", 0, -5)
    logFrame.title:SetText("插件日志窗口")

    -- 设置关闭按钮
    if logFrame.CloseButton then
        logFrame.CloseButton:SetScript("OnClick", function()
            logFrame:Hide()
        end)
    end

    local scrollArea = CreateFrame("ScrollFrame", "MyAddonLogScroll", logFrame, "UIPanelScrollFrameTemplate")
    scrollArea:SetPoint("TOPLEFT", 10, -30)
    scrollArea:SetPoint("BOTTOMRIGHT", -30, 30)

    -- 创建用于显示文本的子框架（实际内容放在这里）
    local scrollChild = CreateFrame("Frame", "MyAddonLogChild", scrollArea)
    scrollChild:SetSize(360, 300) -- 宽度匹配，高度可扩展
    scrollArea:SetScrollChild(scrollChild)

    -- 创建显示日志的文本框
    local logText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    logText:SetPoint("TOPLEFT", 0, 0)
    logText:SetPoint("TOPRIGHT", 0, 0)
    logText:SetJustifyH("LEFT")
    logText:SetJustifyV("TOP")
    logText:SetText("") -- 初始为空
    local fontName, fontSize, fontFlags = logText:GetFont()
    logText:SetFont(fontName, 10, fontFlags) --设置字号
    logText:SetWidth(360)
    logText:SetHeight(1500) -- 初始高度，会根据内容自动扩展

    -- 清空日志按钮
    local clearButton = CreateFrame("Button", nil, logFrame, "UIPanelButtonTemplate")
    clearButton:SetSize(80, 22)
    clearButton:SetPoint("BOTTOMRIGHT", -10, 5)
    clearButton:SetText("清空")
    clearButton:SetScript("OnClick", function()
        logText:SetText("")
        selfRef.logs = "" -- 清空日志历史
        scrollChild:SetHeight(20) -- 重置高度
    end)

    self.frame = logFrame
    self.text = logText
    self.scrollChild = scrollChild
    self.scrollArea = scrollArea

end

-- 刷新日志显示
function LogFrame:RefreshLogDisplay()
    local lines = {}
    local totalHeight = 0
    
    -- 更新文本显示
    self.text:SetText(self.logs)
    
    -- -- 自动滚动到底部（显示最新消息）
    -- self.scrollArea:SetVerticalScroll(self.scrollChild:GetHeight())
end

function LogFrame:AddLog()
    if not PPBestConfig.enableLogWindow then return end

end

local StateFrame = {
    frame = nil,
}

function StateFrame:Create()
    if not PPBestConfig.enableLogWindow then return end
    if self.frame then
        self.frame:Show()
        return
    end
    local stateFrame = CreateFrame("Frame", "PPBestStateFrame", UIParent, "UIPanelDialogTemplate")
    stateFrame:SetSize(400, 500)
    stateFrame:SetPoint("RIGHT")
    stateFrame:SetMovable(true)
    stateFrame:EnableMouse(true)
    stateFrame:SetClampedToScreen(true)
    stateFrame:SetFrameStrata("DIALOG") -- 设置层级，避免被其他UI遮挡
    stateFrame.title = stateFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stateFrame.title:SetPoint("TOP", stateFrame, "TOP", 0, -5)
    stateFrame.title:SetText("对战状态窗口")

   local stateText = stateFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stateText:SetPoint("TOPLEFT", 0, 0)
    stateText:SetPoint("TOPRIGHT", 0, 0)
    stateText:SetJustifyH("LEFT")
    stateText:SetJustifyV("TOP")
    stateText:SetText("") -- 初始为空
    local fontName, fontSize, fontFlags = stateText:GetFont()
    stateText:SetFont(fontName, 10, fontFlags) --设置字号

    self.frame = stateFrame
    self.text = stateText
end

function StateFrame:SetState(state)
    self.text:SetText(state)
end

PPBest.LogFrame = LogFrame
PPBest.StateFrame = StateFrame