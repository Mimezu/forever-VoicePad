local _, ns = ...
-- The settings window, its page in Esc > Options > AddOns, and the minimap icon.
-- Keys are set here: click a keycap, press a key or controller button.

local TEAL = { 0.46, 0.88, 0.79 }
local ACTIONS = {
    { "VOICEPAD_START", "Start" },
    { "VOICEPAD_WAIT", "Wait" },
    { "VOICEPAD_RECEIVE", "Receive" },
    { "VOICEPAD_SEND", "Send" },
    { "VOICEPAD_CANCEL", "Cancel" },
    { "VOICEPAD_OPTIONS", "Window" },
}
ns.keyActions = ACTIONS
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }

local function DB()
    if type(VoicePadDB) ~= "table" then VoicePadDB = {} end
    return VoicePadDB
end

---------------------------------------------------------------------------
-- Keys
---------------------------------------------------------------------------
local Keys = {}
ns.Keys = Keys

function Keys.Text(action)
    local key = GetBindingKey(action)
    if not key then return nil end
    return GetBindingText and GetBindingText(key) or key
end

-- The pressed key with its held modifiers, as bindings write it.
function Keys.Combo(key)
    local mods = ""
    if IsAltKeyDown() then mods = mods .. "ALT-" end
    if IsControlKeyDown() then mods = mods .. "CTRL-" end
    if IsShiftKeyDown() then mods = mods .. "SHIFT-" end
    if IsMetaKeyDown and IsMetaKeyDown() then mods = mods .. "META-" end
    return mods .. key
end

-- What `key` does now, when that is something other than `action`.
function Keys.Taken(action, key)
    local before = GetBindingAction(key)
    if not before or before == "" or before == action then return nil end
    return _G["BINDING_NAME_" .. before] or before
end

-- Why `key` cannot be used; nil when it can.
function Keys.Refused(key)
    if InCombatLockdown() then return "Not in combat" end
    if ns.helperKeys[key] then return "Helper key" end
    return nil
end

-- Binds `key` to `action` alone, in place of the action's old keys.
function Keys.Bind(action, key)
    if InCombatLockdown() then return false end
    for _, old in ipairs({ GetBindingKey(action) }) do SetBinding(old) end
    if key then SetBinding(key, action) end
    SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
    return true
end

if StaticPopupDialogs then
    StaticPopupDialogs.VOICEPAD_REPLACE_KEY = {
        text = "%s is %s.\nReplace?",
        button1 = "Replace",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data) if data then data() end end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end

-- One listener at a time, across the window and the Settings page.
local catcher = CreateFrame("Frame", "VoicePadKeyCatcher", UIParent)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("FULLSCREEN_DIALOG")
catcher:Hide()
local listening
local rows = {}

local function RefreshRows()
    for _, row in ipairs(rows) do row:Refresh() end
end
ns.RefreshRows = RefreshRows

function Keys.Stop()
    if not listening then return end
    listening = nil
    catcher:EnableKeyboard(false)
    if catcher.EnableGamePadButton then catcher:EnableGamePadButton(false) end
    catcher:EnableMouse(false)
    catcher:Hide()
    RefreshRows()
end

-- A key or controller button pressed while listening.
function Keys.Pressed(key)
    local row = listening
    if not row or MODIFIERS[key] then return end
    if key == "ESCAPE" or key == "BUTTON1" or key == "BUTTON2" then Keys.Stop(); return end
    local combo = Keys.Combo(key)
    Keys.Stop()
    local refused = Keys.Refused(combo)
    if refused then row:Say(refused); return end
    local function take()
        if Keys.Bind(row.action, combo) then row:Say("") else row:Say("Not in combat") end
        RefreshRows()
    end
    local taken = Keys.Taken(row.action, combo)
    if taken and StaticPopup_Show then
        StaticPopup_Show("VOICEPAD_REPLACE_KEY", GetBindingText and GetBindingText(combo) or combo, taken, take)
    else
        take()
    end
end

local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
catcher:SetScript("OnKeyDown", function(_, key) Keys.Pressed(key) end)
catcher:SetScript("OnGamePadButtonDown", function(_, key) Keys.Pressed(key) end)
catcher:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" or button == "RightButton" then Keys.Stop() else Keys.Pressed(MOUSE[button] or button:upper()) end
end)

function Keys.Listen(row)
    if InCombatLockdown() then row:Say("Not in combat"); return end
    Keys.Stop()
    listening = row
    row:Say("")
    catcher:Show()
    catcher:EnableKeyboard(true)
    catcher:SetPropagateKeyboardInput(false)
    if catcher.EnableGamePadButton then catcher:EnableGamePadButton(true) end
    catcher:EnableMouse(true)
    RefreshRows()
end
function Keys.Listening() return listening end

-- One action: label, keycap (click to set), clear, and a note on the right.
local function KeyRow(parent, action, label, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, 24)
    row.action = action
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("LEFT")
    name:SetText(label)
    local cap = CreateFrame("Button", nil, row, "BackdropTemplate")
    cap:SetSize(120, 22)
    cap:SetPoint("LEFT", 76, 0)
    cap:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    cap:SetBackdropColor(1, 1, 1, 0.06)
    cap:SetBackdropBorderColor(TEAL[1], TEAL[2], TEAL[3], 0.55)
    cap.text = cap:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cap.text:SetPoint("CENTER")
    cap:SetScript("OnClick", function() if listening == row then Keys.Stop() else Keys.Listen(row) end end)
    cap:SetScript("OnEnter", function() cap:SetBackdropBorderColor(TEAL[1], TEAL[2], TEAL[3], 1) end)
    cap:SetScript("OnLeave", function() cap:SetBackdropBorderColor(TEAL[1], TEAL[2], TEAL[3], 0.55) end)
    row.cap = cap
    local clear = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    clear:SetSize(22, 22)
    clear:SetPoint("LEFT", cap, "RIGHT", 2, 0)
    clear:SetScript("OnClick", function()
        Keys.Stop()
        if Keys.Bind(action, nil) then row:Say("") else row:Say("Not in combat") end
        RefreshRows()
    end)
    row.clear = clear
    local note = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("LEFT", clear, "RIGHT", 4, 0)
    note:SetPoint("RIGHT")
    note:SetJustifyH("LEFT")
    row.note = note
    function row:Say(text) self.note:SetText(text or "") end
    function row:Refresh()
        if listening == self then
            self.cap.text:SetText("Press a key")
            self.cap.text:SetTextColor(TEAL[1], TEAL[2], TEAL[3])
            self.note:SetText("Esc cancels")
        else
            local text = Keys.Text(self.action)
            self.cap.text:SetText(text or "Not set")
            if text then self.cap.text:SetTextColor(1, 1, 1) else self.cap.text:SetTextColor(0.5, 0.5, 0.5) end
            if self.note:GetText() == "Esc cancels" then self.note:SetText("") end
        end
        self.clear:SetShown(Keys.Text(self.action) ~= nil and listening ~= self)
    end
    rows[#rows + 1] = row
    row:Refresh()
    return row
end
ns.KeyRow = KeyRow

---------------------------------------------------------------------------
-- Minimap icon
---------------------------------------------------------------------------
local icon
local function PlaceIcon()
    if not icon then return end
    local angle = math.rad(DB().minimapAngle or 200)
    local radius = (Minimap:GetWidth() / 2) + 6
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function BuildIcon()
    if icon or not Minimap then return end
    icon = CreateFrame("Button", "VoicePadMinimapButton", Minimap)
    icon:SetSize(31, 31)
    icon:SetFrameStrata("MEDIUM")
    icon:SetFrameLevel(8)
    icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    icon:RegisterForDrag("LeftButton")
    icon:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local background = icon:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
    local art = icon:CreateTexture(nil, "ARTWORK")
    art:SetSize(18, 18)
    art:SetPoint("TOPLEFT", 7, -6)
    if not (art.SetAtlas and art:SetAtlas("voicechat-icon-mic")) then
        art:SetTexture("Interface\\Icons\\Spell_Holy_Silence")
    end
    local border = icon:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    icon:SetScript("OnClick", function() VoicePadOptions_Toggle() end)
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("VoiceBind")
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icon:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            DB().minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            PlaceIcon()
        end)
    end)
    icon:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    PlaceIcon()
end

-- Shown unless turned off.
function ns.MinimapShown() return DB().minimapHidden ~= true end
local checks = {}
function ns.SetMinimapShown(shown)
    DB().minimapHidden = not shown or nil
    if shown then BuildIcon() end
    if icon then icon:SetShown(shown) end
    for _, check in ipairs(checks) do check:SetChecked(shown) end
end

local function MinimapCheck(parent)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    local text = check.Text or check.text or check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:ClearAllPoints()
    text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    text:SetFontObject("GameFontHighlightSmall")
    text:SetText("Minimap icon")
    check:SetScript("OnClick", function(self) ns.SetMinimapShown(self:GetChecked() and true or false) end)
    check:SetChecked(ns.MinimapShown())
    checks[#checks + 1] = check
    return check
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local window
local function HelperText()
    return ns.HelperReady() and "Helper keys ready" or "Helper keys blocked"
end

local function BuildWindow()
    window = CreateFrame("Frame", "VoicePadOptionsFrame", UIParent, "BackdropTemplate")
    window:SetSize(340, 330)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    window:SetBackdropColor(0.063, 0.082, 0.11, 0.96)
    window:SetBackdropBorderColor(TEAL[1], TEAL[2], TEAL[3], 0.9)
    window:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "VoicePadOptionsFrame") end
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("VOICEBIND")
    title:SetTextColor(TEAL[1], TEAL[2], TEAL[3])
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    local heading = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heading:SetPoint("TOPLEFT", 16, -44)
    heading:SetText("Keys")
    local y = -64
    for _, entry in ipairs(ACTIONS) do
        local row = KeyRow(window, entry[1], entry[2], 308)
        row:SetPoint("TOPLEFT", 16, y)
        y = y - 28
    end
    window.helper = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.helper:SetPoint("TOPLEFT", 16, y - 4)
    local check = MinimapCheck(window)
    check:SetPoint("TOPLEFT", 12, y - 24)
    local test = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    test:SetSize(90, 22)
    test:SetPoint("BOTTOMRIGHT", -14, 14)
    test:SetText("Test")
    test:SetScript("OnClick", function() window:Hide(); SlashCmdList.VOICEPAD("test") end)
    window:SetScript("OnShow", function()
        window.helper:SetText(HelperText())
        RefreshRows()
    end)
    window:SetScript("OnHide", function() Keys.Stop() end)
end

function VoicePadOptions_Toggle()
    if not window then BuildWindow() end
    window:SetShown(not window:IsShown())
end
function VoicePadOptions_Open()
    if not window then BuildWindow() end
    window:Show()
end

---------------------------------------------------------------------------
-- Esc > Options > AddOns
---------------------------------------------------------------------------
local function RegisterInSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetText("VoiceBind")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(140, 26)
    open:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
    open:SetText("Open")
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        VoicePadOptions_Open()
    end)
    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", open, "RIGHT", 12, 0)
    hint:SetText("/vp")
    local check = MinimapCheck(panel)
    check:SetPoint("TOPLEFT", open, "BOTTOMLEFT", -4, -12)
    local y = -120
    for _, entry in ipairs(ACTIONS) do
        local row = KeyRow(panel, entry[1], entry[2], 360)
        row:SetPoint("TOPLEFT", 16, y)
        y = y - 28
    end
    panel:SetScript("OnShow", RefreshRows)
    panel:SetScript("OnHide", function() Keys.Stop() end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "VoiceBind")
    Settings.RegisterAddOnCategory(category)
end

local loader = CreateFrame("Frame", "VoicePadOptionsLoader")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("UPDATE_BINDINGS")
loader:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if ns.MinimapShown() then BuildIcon() end
        pcall(RegisterInSettings)
    else
        if window then window.helper:SetText(HelperText()) end
        RefreshRows()
    end
end)
