local _, PPBest = ...
local Const = PPBest.Const


local OptionPanel = {}

-- 模块的局部变量
local PPBestOptions
local hotkeyText
local captureFrame
local isCapturingKey = false

-- 辅助函数：检查是否是有效的按键
local function IsValidKey(key)
    -- 排除不能作为快捷键的键
    local invalidKeys = {
        "UNKNOWN", "LSHIFT", "RSHIFT", "LCTRL", "RCTRL", 
        "LALT", "RALT", "PRINTSCREEN", "SCROLLLOCK",
        "CAPSLOCK", "NUMLOCK", "PAUSE", "INSERT", 
        "HOME", "END", "PAGEUP", "PAGEDOWN"
    }
    
    for _, invalidKey in ipairs(invalidKeys) do
        if key == invalidKey then
            return false
        end
    end
    
    -- 允许功能键、字母键、数字键等
    return true
end

-- 初始化设置面板
function OptionPanel:Initialize()
    PPBestOptions = CreateFrame("Frame", "PPBestOptionsPanel", InterfaceOptionsFramePanelContainer)
    PPBestOptions.name = "PPBest"
    
    -- 创建UI元素
    self:CreateUI()
    
    -- 注册到接口选项
    --InterfaceOptions_AddCategory(PPBestOptions)
    local category, layout = Settings.RegisterCanvasLayoutCategory(PPBestOptions, PPBestOptions.name)
    Settings.RegisterAddOnCategory(category)

    return true
end


local function GetDropDownMenuItemInfo(text, key)
    local info = UIDropDownMenu_CreateInfo()

end

-- 创建UI元素
function OptionPanel:CreateUI()
    -- 标题
    local title = PPBestOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("PPBest 宠物对战一键助手")
    
    -- 分隔线
    local line = PPBestOptions:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    line:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    line:SetSize(600, 1)
    
    -- 当前快捷键显示
    local hotkeyLabel = PPBestOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hotkeyLabel:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -20)
    hotkeyLabel:SetText("当前快捷键:")
    
    hotkeyText = PPBestOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hotkeyText:SetPoint("LEFT", hotkeyLabel, "RIGHT", 10, 0)
    hotkeyText:SetText(PPBestConfig and PPBestConfig.hotkey or "F8")
    
    -- 设置快捷键按钮
    local setHotkeyButton = CreateFrame("Button", nil, PPBestOptions, "UIPanelButtonTemplate")
    setHotkeyButton:SetPoint("TOPLEFT", hotkeyLabel, "BOTTOMLEFT", 0, -10)
    setHotkeyButton:SetSize(120, 25)
    setHotkeyButton:SetText("设置快捷键")
    self.captureButton = setHotkeyButton
    -- 设置按钮点击事件
    setHotkeyButton:SetScript("OnClick", function(self)
        if not isCapturingKey then
            OptionPanel:StartKeyCapture()
        end
    end)
    
    -- 添加一个文本标签
    local modLabel = PPBestOptions:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modLabel:SetPoint("TOPLEFT", setHotkeyButton, "BOTTOMLEFT", 0, -10)
    modLabel:SetText("使用模式:")
    
    local modDropdownFrame = CreateFrame("Frame", nil, PPBestOptions, "UIDropDownMenuTemplate")
    modDropdownFrame:SetPoint("TOPLEFT", modLabel, "BOTTOMLEFT", 0, -10)
    modDropdownFrame:SetSize(120, 25)
    modDropdownFrame:SetScript("OnShow", function(self)
        UIDropDownMenu_SetWidth(self, 150) -- 设置宽度
        UIDropDownMenu_SetButtonWidth(self, 124) -- 标准宽度
        UIDropDownMenu_Initialize(self, 
            function (self, level)
                local options = {
                    { text = "单刷-默认策略", value = Const.MODE_DEFAULT },
                    { text = "单刷-AI", value = Const.MODE_AI },
                    { text = "互刷-协助方", value = Const.MODE_ASSIST },
                    { text = "互刷-我要角色经验", value = Const.MODE_WANT_EXP },
                    { text = "互刷-我要胜场数", value = Const.MODE_WANT_WIN },
                    { text = "互刷-我要宠物等级", value = Const.MODE_WANT_PET_LEVEL },
                }
                for _, option in ipairs(options) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = option.text
                    info.value = option.value
                    info.func = function(self)
                        UIDropDownMenu_SetSelectedValue(modDropdownFrame, self.value)
                        PPBestConfig.mode = self.value
                    end
                    UIDropDownMenu_AddButton(info,level)
                end
            end
        )
        local currentValue = PPBestConfig.mode or "default" 
        UIDropDownMenu_SetSelectedValue(self, currentValue)
    end)

    local targetNameLabel = PPBestOptions:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetNameLabel:SetPoint("TOPLEFT", modDropdownFrame, "BOTTOMLEFT", 0, -10)
    targetNameLabel:SetText("辅助目标ID(只有辅助方需要填写，格式：名字-服务器)：")

    local targetNameBox = CreateFrame("EditBox", nil, PPBestOptions, "InputBoxTemplate")
    targetNameBox:SetSize(200, 20)
    targetNameBox:SetPoint("TOPLEFT", targetNameLabel, "BOTTOMLEFT", 0, -10)
    targetNameBox:SetAutoFocus(false)                -- 不自动获得焦点
    targetNameBox:SetText(PPBestConfig.assistTarget or "")       -- 显示保存的内容
    targetNameBox:SetScript("OnEnterPressed", function(self)
        PPBestConfig.assistTarget = self:GetText()
        -- print("已保存: " .. self:GetText())
    end)

    -- 创建确认按钮
    local targetNameButton = CreateFrame("Button", nil, PPBestOptions, "GameMenuButtonTemplate")
    targetNameButton:SetSize(80, 25)
    targetNameButton:SetPoint("LEFT", targetNameBox, "RIGHT", 10, 0)
    targetNameButton:SetText("保存")
    targetNameButton:SetScript("OnClick", function()
        local text = targetNameBox:GetText()
        PPBestConfig.assistTarget = text
        -- print("已保存: " .. text)
        targetNameBox:ClearFocus()  -- 保存后取消焦点
    end)
    
    local logLaber = PPBestOptions:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    logLaber:SetPoint("TOPLEFT", targetNameBox, "BOTTOMLEFT", 0, -10)
    logLaber:SetText("日志")

    local logCheckButton = CreateFrame("CheckButton", nil, PPBestOptions, "ChatConfigCheckButtonTemplate")
    logCheckButton:SetPoint("TOPLEFT", logLaber, "BOTTOMLEFT", 0, -10)
    logCheckButton.Text:SetText("开启日志窗口")
    logCheckButton.tooltip = "开启/关闭开启日志窗口"
    logCheckButton:SetChecked(PPBestConfig.enableLogWindow or false)
    logCheckButton:SetScript("OnClick", function(self)
        PPBestConfig.enableLogWindow = self:GetChecked()
    end)
end

-- 开始捕获按键
function OptionPanel:StartKeyCapture()
    if not captureFrame then
        self:CreateCaptureFrame()
    end
    
    isCapturingKey = true
    captureFrame:Show()
    
    -- 捕获所有键盘输入
    captureFrame:SetPropagateKeyboardInput(false)
    captureFrame:EnableKeyboard(true)
    captureFrame:SetScript("OnKeyDown", function(self, key)
        self:SetPropagateKeyboardInput(false)
        
        -- 处理 ESC 键取消
        if key == "ESCAPE" then
            captureFrame:Hide()
            isCapturingKey = false
            return
        end
        
        -- 检查是否是有效的快捷键
        if IsValidKey(key) then
            -- 获取修饰键状态
            local modifiers = ""
            if IsShiftKeyDown() then
                modifiers = modifiers .. "SHIFT-"
            end
            if IsControlKeyDown() then
                modifiers = modifiers .. "CTRL-"
            end
            if IsAltKeyDown() then
                modifiers = modifiers .. "ALT-"
            end
            
            local newHotkey = modifiers .. key
            
            -- 更新配置
            if PPBestConfig then
                PPBestConfig.hotkey = newHotkey
                
                -- 更新显示
                if hotkeyText then
                    hotkeyText:SetText(newHotkey)
                end
                
                -- 调用主模块的快捷键设置函数
                if _G.PPBest_SetupHotkey then
                    _G.PPBest_SetupHotkey()
                end
                
                -- 显示确认信息
                print("PPBest: 快捷键已设置为 |cFFFFFF00" .. newHotkey .. "|r")
            end
            
            -- 隐藏捕获界面
            captureFrame:Hide()
            isCapturingKey = false
        end
    end)
    
    -- 鼠标点击取消
    captureFrame.captureOverlay:SetScript("OnMouseDown", function(self, button)
        captureFrame:Hide()
        isCapturingKey = false
    end)
end

-- 创建按键捕获框架
function OptionPanel:CreateCaptureFrame()
    captureFrame = CreateFrame("Frame", "PPBestKeyCaptureFrame", UIParent)
    captureFrame:Hide()
    
    -- 按键捕获覆盖层
    captureFrame.captureOverlay = CreateFrame("Frame", nil, captureFrame)
    captureFrame.captureOverlay:SetAllPoints(UIParent)
    captureFrame.captureOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
    captureFrame.captureOverlay:EnableMouse(true)
    
    local captureBackground = captureFrame.captureOverlay:CreateTexture(nil, "BACKGROUND")
    captureBackground:SetAllPoints()
    captureBackground:SetColorTexture(0, 0, 0, 0.7)
    
    local captureText = captureFrame.captureOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    captureText:SetPoint("CENTER", captureFrame.captureOverlay, "CENTER", 0, 50)
    captureText:SetText("请按下新的快捷键...")
    captureText:SetTextColor(1, 1, 1, 1)
    
    local captureHint = captureFrame.captureOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    captureHint:SetPoint("CENTER", captureFrame.captureOverlay, "CENTER", 0, 0)
    captureHint:SetText("按 ESC 取消")
    captureHint:SetTextColor(0.8, 0.8, 0.8, 1)
end

-- 刷新设置面板
function OptionPanel:Refresh()
    if hotkeyText and PPBestConfig then
        hotkeyText:SetText(PPBestConfig.hotkey or "F8")
    end
end

-- 打开设置面板
function OptionPanel:Open()
    InterfaceOptionsFrame_OpenToCategory("PPBest")
    --InterfaceOptionsFrame_OpenToCategory("PPBest") -- 调用两次确保展开
end

PPBest.OptionPanel = OptionPanel