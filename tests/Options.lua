-- Lua 5.1: run from the game directory. Key setter, minimap toggle, Settings page.
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local frames, methods = {}, {}
local combat, ctrl, shift, alt = false, false, false, false
local bindings, overrides, saved, popups, categories = {}, {}, 0, {}, {}
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:GetScript(name) return self.scripts[name] end
function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide()
    local was = self.shown
    self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:SetText(t) self.text = t end
function methods:GetText() return self.text end
function methods:SetChecked(v) self.checked = v end
function methods:GetChecked() return self.checked end
function methods:EnableKeyboard(v) self.keyboard = v end
function methods:EnableGamePadButton(v) self.gamepad = v end
function methods:GetWidth() return 140 end
function methods:GetCenter() return 100, 100 end
function methods:GetEffectiveScale() return 1 end
function methods:SetAtlas() return true end
local function newFrame(name)
    local f = { scripts = {} }
    setmetatable(f, { __index = function(_, key)
        if key == "Text" or key == "text" then return nil end
        return methods[key] or function() end
    end })
    if name then frames[name] = f end
    return f
end
function methods:CreateFontString() return newFrame() end
function methods:CreateTexture() return newFrame() end
function CreateFrame(_, name) return newFrame(name) end
UIParent, Minimap, GameTooltip = newFrame(), newFrame(), newFrame()
SlashCmdList, UISpecialFrames, StaticPopupDialogs = {}, {}, {}
C_Timer = { After = function() end }
function GetTime() return 0 end
function InCombatLockdown() return combat end
function IsControlKeyDown() return ctrl end
function IsShiftKeyDown() return shift end
function IsAltKeyDown() return alt end
function GetCurrentKeyBoardFocus() return nil end
function GetBindingAction(key, includeOverride) return (includeOverride and overrides[key]) or bindings[key] or "" end
function GetBindingKey(action)
    local found = {}
    for key, a in pairs(bindings) do if a == action then found[#found + 1] = key end end
    table.sort(found)
    return unpack(found)
end
function GetBindingText(key) return key end
function SetBinding(key, action) bindings[key] = action end
function SaveBindings() saved = saved + 1 end
function GetCurrentBindingSet() return 1 end
function ClearOverrideBindings() overrides = {} end
function SetOverrideBindingClick(_, _, key, target, button) overrides[key] = "CLICK " .. target .. ":" .. button end
function StaticPopup_Show(which, a, b, data) popups[#popups + 1] = { which = which, a = a, b = b, data = data } end
function HideUIPanel(f) f:Hide() end
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) return { panel = panel, name = name } end,
    RegisterAddOnCategory = function(c) categories[#categories + 1] = c end,
}

local ns = {}
for _, file in ipairs({ "Model", "Core", "Options" }) do
    assert(loadfile("Interface/AddOns/VoicePad/" .. file .. ".lua"))("VoicePad", ns)
end
frames.VoicePadBindingOwner.scripts.OnEvent(nil, "PLAYER_LOGIN")
frames.VoicePadOptionsLoader.scripts.OnEvent(nil, "PLAYER_LOGIN")
check(#categories == 1 and categories[1].name == "VoiceBind", "page in Options > AddOns")
check(frames.VoicePadMinimapButton and frames.VoicePadMinimapButton.shown ~= false, "minimap icon at login")

check(type(VoicePadOptions_Toggle) == "function", "toggle exists for the binding")
check(BINDING_NAME_VOICEPAD_OPTIONS ~= nil, "window binding has a name")
local catcher = frames.VoicePadKeyCatcher
check(catcher ~= nil, "one shared key catcher")

-- Window opens, with a row per action.
VoicePadOptions_Toggle()
local window = frames.VoicePadOptionsFrame
check(window and window.shown, "window opens")
check(#ns.keyActions == 6, "six keys offered")
check(ns.HelperReady(), "helper keys installed after login")

-- Find the Start row through the catcher: listen on it, press a key.
local Keys = ns.Keys
local startRow = { action = "VOICEPAD_START", said = nil }
function startRow:Say(t) self.said = t end
function startRow:Refresh() end
Keys.Listen(startRow)
check(catcher.shown and catcher.keyboard and catcher.gamepad, "listening takes keyboard and controller")
catcher.scripts.OnKeyDown(catcher, "LSHIFT")
check(Keys.Listening() == startRow, "a modifier alone keeps listening")
ctrl = true
catcher.scripts.OnKeyDown(catcher, "J")
ctrl = false
check(bindings["CTRL-J"] == "VOICEPAD_START" and saved == 1, "key bound with its modifier and saved")
check(not catcher.shown and Keys.Listening() == nil, "listening ends after a key")

-- Controller button.
Keys.Listen(startRow)
catcher.scripts.OnGamePadButtonDown(catcher, "PAD3")
check(bindings.PAD3 == "VOICEPAD_START" and bindings["CTRL-J"] == nil, "controller button replaces the old key")

-- Escape cancels.
Keys.Listen(startRow)
catcher.scripts.OnKeyDown(catcher, "ESCAPE")
check(bindings.ESCAPE == nil and bindings.PAD3 == "VOICEPAD_START", "Escape cancels")

-- A taken key asks first; nothing changes until accepted.
bindings.K = "TOGGLEBACKPACK"
Keys.Listen(startRow)
catcher.scripts.OnKeyDown(catcher, "K")
check(#popups == 1 and popups[1].b == "TOGGLEBACKPACK" and bindings.K == "TOGGLEBACKPACK", "taken key asks before replacing")
popups[1].data()
check(bindings.K == "VOICEPAD_START" and bindings.PAD3 == nil, "accepting replaces")

-- Helper keys stay with the helper.
Keys.Listen(startRow)
ctrl, shift = true, true
catcher.scripts.OnKeyDown(catcher, "F7")
ctrl, shift = false, false
check(bindings["CTRL-SHIFT-F7"] == nil and startRow.said == "Helper key", "helper keys refused")

-- Combat refuses.
combat = true
Keys.Listen(startRow)
check(not catcher.shown and startRow.said == "Not in combat", "no listening in combat")
combat = false

-- Minimap icon: shown by default, toggle saved.
check(ns.MinimapShown(), "minimap icon shown by default")
ns.SetMinimapShown(true)
local icon = frames.VoicePadMinimapButton
check(icon and icon.shown, "minimap icon built")
icon.scripts.OnClick(icon, "LeftButton")
check(not window.shown, "icon click toggles the window")
ns.SetMinimapShown(false)
check(VoicePadDB.minimapHidden == true and not icon.shown, "hiding saved")
ns.SetMinimapShown(true)
check(VoicePadDB.minimapHidden == nil and icon.shown, "showing saved")

-- Moving the bubble keeps other saved settings.
VoicePadDB.minimapAngle = 45
local bubble = frames.VoicePadFrame
bubble.GetPoint = function() return "CENTER", nil, "CENTER", 1, 2 end
bubble.scripts.OnDragStop(bubble)
check(VoicePadDB.minimapAngle == 45 and VoicePadDB.x == 1, "bubble position does not wipe minimap settings")

-- /vp with no argument opens the window.
SlashCmdList.VOICEPAD("")
check(window.shown, "/vp opens the window")
print("VoiceBind options: " .. checks .. " checks passed")
