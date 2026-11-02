-- Lua 5.1: run from the game directory. No connection to WoW or chat sending.
local frames, sent, focus, timers = {}, {}, nil, {}
local methods = {}
local checks = 0
local now = 10
local modified, alt, combat = true, false, false
local savedBindings, overrides = {}, {}
function GetTime() return now end
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:SetText(text)
    self.text = text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function methods:Paste(text)
    self.text = text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, true) end
end
function methods:GetText() return self.text or "" end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetAlpha(value) self.alpha = value end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetFocus() focus = self end
function methods:ClearFocus()
    if focus ~= self then return end
    focus = nil
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
local function newFrame(name)
    local f = { scripts = {} }
    setmetatable(f, { __index = function(_, key) return methods[key] or function() end end })
    if name then frames[name] = f end
    return f
end
function methods:CreateFontString() return newFrame() end
function CreateFrame(_, name) return newFrame(name) end
UIParent = newFrame()
SlashCmdList = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
function GetCurrentKeyBoardFocus() return focus end
function InCombatLockdown() return combat end
function IsControlKeyDown() return modified end
function IsAltKeyDown() return alt end
function IsShiftKeyDown() return modified end
function ClearOverrideBindings() overrides = {} end
function GetBindingAction(key, includeOverride)
    return (includeOverride and overrides[key]) or savedBindings[key] or ""
end
function SetOverrideBindingClick(_, _, key, target, button)
    assert(not combat)
    overrides[key] = "CLICK " .. target .. ":" .. button
end
function SetCVar() end
C_ChatInfo = { SendChatMessage = function(text, channel) sent[#sent + 1] = { text, channel } end }

function UnitGUID() return "player-guid" end
local ns = {}
assert(loadfile("Interface/AddOns/VoicePad/Model.lua"))("VoicePad", ns)
assert(loadfile("Interface/AddOns/VoicePad/Core.lua"))("VoicePad", ns)
local edit, panel = frames.VoicePadEditBox, frames.VoicePadFrame
local function press(key)
    local target, button = (overrides[key] or ""):match("^CLICK ([^:]+):(.+)$")
    if target then frames[target].scripts.OnClick(frames[target], button) end
end
local function ack(text, guid)
    panel.scripts.OnEvent(panel, "CHAT_MSG_SAY", text, "Player", nil, nil, nil, nil, nil, nil, nil, nil, 1, guid or "player-guid")
end
local function fresh(text)
    VoicePad_Cancel()
    VoicePad_Start()
    VoicePad_Wait()
    if text then edit:Paste(text) end
    VoicePad_Receive()
    now = now + 1
end
local function finish()
    local last = sent[#sent]
    ack(last[1])
    panel.scripts.OnUpdate(panel, 2)
end
frames.VoicePadBindingOwner.scripts.OnEvent()
for index, command in ipairs({ "START", "RECEIVE", "SEND", "WAIT", "CANCEL" }) do
    check(overrides["CTRL-SHIFT-F" .. (index + 5)] == "CLICK VoicePadSignal" .. command .. ":LeftButton", "safe function-key protocol agrees with helper")
end
check(overrides.F6 == nil and overrides.F13 == nil, "ordinary game keys are unchanged")
frames.VoicePadSignalSTART.scripts.OnClick(frames.VoicePadSignalSTART, "LeftButton", true)
check(not panel.shown, "ignore down half of button click")
press("CTRL-SHIFT-F6")
check(panel.shown and focus == edit, "start opens focused paste target")
check(panel.width == 244 and panel.height == 60 and edit.alpha == 0, "listening is a small bubble with hidden but focused text input")
panel.scripts.OnMouseUp(panel, "LeftButton")
check(panel.width == 320 and edit.alpha == 1 and focus == edit, "opening the draft keeps its paste focus")
panel.scripts.OnMouseUp(panel, "LeftButton")
check(panel.width == 244 and edit.alpha == 0 and focus == edit, "collapsing the draft keeps its paste focus")
edit:Paste("old input")
press("CTRL-SHIFT-F9")
check(edit:GetText() == "", "stop clears input preceding this transcript")
press("CTRL-SHIFT-F10")
check(not panel.shown and focus == nil, "explicit dismiss releases keyboard focus")
-- Override bindings fire UPDATE_BINDINGS themselves: with everything in place, the event
-- must not rebind (that would loop once per frame).
local binds, realSetOverride = 0, SetOverrideBindingClick
SetOverrideBindingClick = function(...) binds = binds + 1; realSetOverride(...) end
frames.VoicePadBindingOwner.scripts.OnEvent(nil, "UPDATE_BINDINGS")
check(binds == 0, "UPDATE_BINDINGS with the overrides in place rebinds nothing")
savedBindings["CTRL-SHIFT-F6"] = "USER_ACTION"
frames.VoicePadBindingOwner.scripts.OnEvent()
check(overrides["CTRL-SHIFT-F6"] == nil, "saved key conflicts are never replaced")
check(binds == 4, "a new conflict rebinds the other four keys once")
frames.VoicePadBindingOwner.scripts.OnEvent(nil, "UPDATE_BINDINGS")
check(binds == 4, "a standing conflict does not rebind again")
savedBindings["CTRL-SHIFT-F6"] = nil
frames.VoicePadBindingOwner.scripts.OnEvent()
combat = true
frames.VoicePadBindingOwner.scripts.OnEvent()
combat = false
check(overrides["CTRL-SHIFT-F6"] ~= nil, "combat does not attempt protected rebinding")

check(ns.Model.Message(nil) == nil, "missing transcript rejected")
check(ns.Model.Message(" \n\t ") == nil, "blank transcript rejected")
check(ns.Model.Message("Bonjour\n tout le monde!") == "Bonjour tout le monde!", "newlines normalized")
check(ns.Model.Message(string.rep("a", 255)) ~= nil, "255 bytes accepted")
check(ns.Model.Message(string.rep("a", 256)) == nil, "256 bytes rejected")
check(ns.Model.Message(string.rep("\195\169", 128)) == nil, "UTF8 counted in bytes")
check(ns.Model.Message("|cffff0000hello|r") == "cffff0000hellor", "formatting escapes removed")
VoicePad_Send()
check(#sent == 0, "idle send ignored")
VoicePad_Start()
edit:Paste("speaking")
VoicePad_Send()
check(#sent == 0, "recording cannot send")
VoicePad_Wait()
edit:Paste("/run this stays literal")
VoicePad_Send()
check(#sent == 0, "paste without helper confirmation cannot send")
VoicePad_Receive()
VoicePad_Send()
check(#sent == 0 and panel.width == 320, "still-arriving input is kept for review")
now = now + 1
VoicePad_Send()
check(#sent == 0, "late automatic command cannot submit a review draft")
edit.scripts.OnEnterPressed()
check(#sent == 1 and sent[1][1] == "/run this stays literal" and sent[1][2] == "SAY", "manual send is literal SAY")
check(panel.shown and edit:GetText() ~= "" and focus == nil, "retain transcript until own chat event confirms delivery")
VoicePad_Send()
check(#sent == 1, "duplicate commit never resends")
ack(sent[1][1], "someone-else")
check(edit:GetText() ~= "", "another player's same message is not confirmation")
ack("different text")
check(edit:GetText() ~= "", "another own message is not confirmation")
ack(sent[1][1])
check(edit:GetText() == "" and panel.width == 244, "own matching chat event confirms and compacts bubble")
panel.scripts.OnUpdate(panel, 2)
check(not panel.shown, "confirmed bubble fades after a brief status")

fresh("safe automatic send")
modified = false
edit.scripts.OnKeyDown(edit, "F8")
check(#sent == 1, "plain F8 cannot submit")
modified = true; alt = true
edit.scripts.OnKeyDown(edit, "F8")
check(#sent == 1, "extra Alt does not match command")
alt = false
edit.scripts.OnKeyDown(edit, "F8")
check(#sent == 2, "safe chord sends settled transcript")
finish()
fresh("escape draft")
edit.scripts.OnEscapePressed()
VoicePad_Send()
check(#sent == 2 and panel.shown and focus == edit, "Escape disarms but keeps a target for late paste")
edit:Paste("late after escape")
VoicePad_Send()
check(#sent == 2 and edit:GetText() == "late after escape", "late paste after Escape stays a draft")
VoicePad_Start()
check(edit:GetText() == "late after escape", "new start cannot erase a recovery draft")
edit.scripts.OnEscapePressed()
check(not panel.shown and focus == nil, "second Escape explicitly dismisses")
fresh("focus lost")
edit:ClearFocus()
VoicePad_Send()
check(#sent == 2 and edit:GetText() == "focus lost", "focus loss disarms and retains draft")
edit:SetFocus()
edit.scripts.OnEnterPressed()
check(#sent == 3, "retained draft can be reviewed and sent manually")
finish()
fresh("expired")
panel.scripts.OnUpdate(panel, 181)
VoicePad_Send()
check(#sent == 3 and panel.shown and edit:GetText() == "expired", "timeout preserves draft and disarms")
VoicePad_Cancel()
focus = newFrame("OtherEditor")
VoicePad_Start(); VoicePad_Wait(); VoicePad_Receive()
edit:Paste("must not replace another editor")
VoicePad_Send()
check(#sent == 3 and focus == frames.OtherEditor, "other editor preserved")
focus = nil
fresh(string.rep("a", 256))
VoicePad_Send()
check(#sent == 3 and panel.shown and edit.alpha == 1, "long text expanded for editing without truncation")
edit:Paste("shortened")
edit.scripts.OnEnterPressed()
check(#sent == 4 and sent[4][1] == "shortened", "manual shortening works")
finish()
local realSend = C_ChatInfo.SendChatMessage
C_ChatInfo.SendChatMessage = function() error("protected") end
fresh("blocked")
VoicePad_Send()
check(#sent == 4 and edit:GetText() == "blocked" and focus == edit, "protected send failure keeps focused draft")
C_ChatInfo.SendChatMessage = realSend
edit.scripts.OnEnterPressed()
check(#sent == 5, "blocked draft may be retried manually")
finish()
fresh("unconfirmed")
VoicePad_Send()
panel.scripts.OnUpdate(panel, 6)
VoicePad_Send()
check(#sent == 6 and edit:GetText() == "unconfirmed" and panel.width == 320, "missing chat acknowledgement never causes automatic retry or draft loss")
VoicePad_Cancel()
focus = frames.OtherEditor
SlashCmdList.VOICEPAD("test")
check(#timers == 1, "slash test waits for chat editor to finish closing")
focus = nil; timers[1]()
check(panel.shown and edit:GetText() == "VoicePad is ready." and #sent == 6, "test opens a review draft without publishing")
fresh()
VoicePad_Send()
check(#sent == 6 and panel.shown, "missing paste remains available")
edit:SetText("programmatic text")
edit.scripts.OnEnterPressed()
check(#sent == 6, "programmatic text cannot qualify as native input")
edit:Paste("delayed paste")
VoicePad_Send()
check(#sent == 6, "late paste does not revive auto-send")
edit.scripts.OnEnterPressed()
check(#sent == 7 and sent[7][1] == "delayed paste", "late paste can be explicitly sent")
finish()
print("VoiceBind addon: " .. checks .. " checks passed")
