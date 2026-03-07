local _,PPBest = ...

local LogFrame = {
    logHistory = {}, -- 存储日志历史
}

function LogFrame:Create()
    -- 创建主框架
    local logFrame = CreateFrame("Frame", "MyAddonLogFrame", UIParent, "UIPanelDialogTemplate")
    logFrame:SetSize(400, 300)
    logFrame:SetPoint("CENTER")
    logFrame:SetMovable(true)
    logFrame:EnableMouse(true)
    logFrame:SetClampedToScreen(true)
    logFrame:SetFrameStrata("DIALOG") -- 设置层级，避免被其他UI遮挡
    logFrame:Hide() -- 默认隐藏

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
    scrollChild:SetSize(360, 1000) -- 宽度匹配，高度可扩展
    scrollArea:SetScrollChild(scrollChild)

    -- 创建显示日志的文本框
    local logText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    logText:SetPoint("TOPLEFT", 0, 0)
    logText:SetPoint("TOPRIGHT", 0, 0)
    logText:SetJustifyH("LEFT")
    logText:SetJustifyV("TOP")
    logText:SetText("") -- 初始为空

    -- 调整文本区域大小以适应父框架
    logText:SetWidth(360)
    logText:SetHeight(1000) -- 初始高度，会根据内容自动扩展

    -- 清空日志按钮
    local clearButton = CreateFrame("Button", nil, logFrame, "UIPanelButtonTemplate")
    clearButton:SetSize(80, 22)
    clearButton:SetPoint("BOTTOMRIGHT", -10, 5)
    clearButton:SetText("清空")
    clearButton:SetScript("OnClick", function()
        logText:SetText("")
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
    local lineHeight = 14 -- 每行高度
    
    -- 从最新的开始显示（倒序）
    for i = #self.logHistory, 1, -1 do
        local entry = self.logHistory[i]
        local timeStr = date("%H:%M:%S", entry.time)
        local coloredLine = string.format("|cFF%02x%02x%02x[%s]|r %s", 
            entry.r * 255, entry.g * 255, entry.b * 255,
            timeStr, entry.text)
        tinsert(lines, coloredLine)
    end
    
    -- 更新文本显示
    self.logText:SetText(table.concat(lines, "\n"))
    
    -- 计算总高度并调整滚动区域
    local numLines = #lines
    totalHeight = numLines * lineHeight + 20
    self.scrollChild:SetHeight(math.max(totalHeight, 100))
    
    -- 自动滚动到底部（显示最新消息）
    self.scrollArea:SetVerticalScroll(self.scrollChild:GetHeight())
end

function LogFrame:AddLog(message, r, g, b)
    if not message then return end
    
    -- 保存到历史记录
    tinsert(self.logHistory, {
        text = message,
        time = time(),
        r = r or 1,
        g = g or 1,
        b = b or 1
    })
    
    -- 限制历史记录数量（可选，防止内存占用过大）
    if #self.logHistory > 1000 then
        tremove(self.logHistory, 1)
    end
    
    -- 更新显示窗口（如果可见）
    if self.logFrame:IsShown() then
        self:RefreshLogDisplay()
    end
end


PPBest.LogFrame = LogFrame