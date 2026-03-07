-- PPBest_Options.lua
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
    InterfaceOptions_AddCategory(PPBestOptions)
    
    return true
end


-- 创建下拉框的初始化函数
local function InitializeDropDown(self, level)
    local info = UIDropDownMenu_CreateInfo()
    
    -- 选项1
    info.text = "默认"
    info.value = "default"
    info.func = function(self) 
        -- 当选择该项时触发
        UIDropDownMenu_SetSelectedValue(dropdownFrame, self.value)
        _G.PPBestConfig.mode = self.value
        print("选择了: " .. self.text)
    end
    info.checked = function() 
        return _G.PPBestConfig.mode ==  "default"
    end
    UIDropDownMenu_AddButton(info, level)
    
    -- 选项2
    info = UIDropDownMenu_CreateInfo()
    info.text = "使用AI"
    info.value = "ai"
    info.func = function(self)
        UIDropDownMenu_SetSelectedValue(dropdownFrame, self.value)
        _G.PPBestConfig.mode = self.value
        print("选择了: " .. self.text)
    end
    info.checked = function()
        return MyAddonSettings.option ==  "ai"
    end
    UIDropDownMenu_AddButton(info, level)
end


-- 创建UI元素
function OptionPanel:CreateUI()
    -- 标题
    local title = PPBestOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("PPBest 宠物对战助手")
    
    -- 描述
    local description = PPBestOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    description:SetText("简单的宠物对战自动插件")
    
    -- 分隔线
    local line = PPBestOptions:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    line:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -10)
    line:SetSize(600, 1)
    
    -- 当前快捷键显示
    local hotkeyLabel = PPBestOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hotkeyLabel:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -20)
    hotkeyLabel:SetText("当前快捷键:")
    
    hotkeyText = PPBestOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hotkeyText:SetPoint("LEFT", hotkeyLabel, "RIGHT", 10, 0)
    hotkeyText:SetText(_G.PPBestConfig and _G.PPBestConfig.hotkey or "F8")
    
    -- 设置快捷键按钮
    local setHotkeyButton = CreateFrame("Button", nil, PPBestOptions, "UIPanelButtonTemplate")
    setHotkeyButton:SetPoint("TOPLEFT", hotkeyLabel, "BOTTOMLEFT", 0, -10)
    setHotkeyButton:SetSize(120, 25)
    setHotkeyButton:SetText("设置快捷键")
    
    -- 设置按钮点击事件
    setHotkeyButton:SetScript("OnClick", function(self)
        if not isCapturingKey then
            OptionPanel:StartKeyCapture()
        end
    end)
    
    local modDropdownFrame = CreateFrame("Frame", nil, PPBestOptions, "UIDropDownMenuTemplate")
    modDropdownFrame:SetPoint("TOPLEFT", hotkeyLabel, "BOTTOMLEFT", 0, -10)
    setHotkeyButton:SetSize(120, 25)
    modDropdownFrame:SetScript("OnShow", function(self)
        UIDropDownMenu_SetWidth(self, 150) -- 设置宽度
        UIDropDownMenu_SetButtonWidth(self, 124) -- 标准宽度
        UIDropDownMenu_Initialize(self, InitializeDropDown)
        
        -- 设置当前选中的值（从保存的变量中读取）
        local currentValue = _G.PPBestConfig.mode or "default" -- 默认C
        UIDropDownMenu_SetSelectedValue(self, currentValue)
    end)
    
    -- 添加一个文本标签
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", dropdownFrame, "RIGHT", 5, 0)
    label:SetText("请选择一个选项:")
    -- 创建按键捕获框架（延迟创建，避免不必要的开销）
    self.captureButton = setHotkeyButton
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
            if _G.PPBestConfig then
                _G.PPBestConfig.hotkey = newHotkey
                
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
    if hotkeyText and _G.PPBestConfig then
        hotkeyText:SetText(_G.PPBestConfig.hotkey or "F8")
    end
end

-- 打开设置面板
function OptionPanel:Open()
    InterfaceOptionsFrame_OpenToCategory("PPBest")
    --InterfaceOptionsFrame_OpenToCategory("PPBest") -- 调用两次确保展开
end

-- 暴露模块到全局
_G.PPBestOptionPanel = OptionPanel

-- 自动初始化
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "PPBest" then
        self:UnregisterEvent("ADDON_LOADED")
        
        -- 初始化设置面板
        if OptionPanel:Initialize() then
            --print("PPBest: 设置面板已加载")
        end
    end
end)

return OptionPanel