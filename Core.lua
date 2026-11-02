local _, ns = ...
local phase, elapsed = "idle", 0
local receivedInput, lastInputAt = false, 0
local expanded, submittedText = false, nil
local frame = CreateFrame("Frame", "VoicePadFrame", UIParent, "BackdropTemplate")
frame:SetSize(244, 60)
frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180)
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 } })
frame:SetBackdropColor(0.063, 0.082, 0.11, 0.96)
frame:SetBackdropBorderColor(0.46, 0.88, 0.79, 0.9)
frame:Hide()
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOPLEFT", 16, -12)
title:SetText("VOICEBIND  /say")
title:SetTextColor(0.46, 0.88, 0.79)
local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", 16, -32)
status:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
status:SetJustifyH("LEFT")
local edit = CreateFrame("EditBox", "VoicePadEditBox", frame, "InputBoxTemplate")
edit:SetSize(280, 26)
edit:SetPoint("BOTTOMLEFT", 20, 18)
edit:SetAutoFocus(false)
edit:SetMaxLetters(4096)
edit:SetFontObject(ChatFontNormal or GameFontHighlight)
-- An alpha-zero, still-shown editor keeps WoW's text focus and catches the native
-- paste. Hiding it would return letter keys to gameplay bindings.
local function Expand(value)
    expanded = value
    frame:SetSize(value and 320 or 244, value and 114 or 60)
    edit:SetAlpha(value and 1 or 0)
    edit:EnableMouse(value)
end
Expand(false)
frame:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
        Expand(not expanded)
        if phase ~= "idle" and phase ~= "submitted" and phase ~= "sent" then edit:SetFocus() end
    end
end)
frame:SetScript("OnDragStart", function() if IsShiftKeyDown() then frame:StartMoving() end end)
frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    VoicePadDB = { point = point, relativePoint = relativePoint, x = x, y = y }
end)
local function SetPhase(value, message)
    phase, elapsed = value, 0
    status:SetText(message or "")
end
local function Review(message)
    SetPhase("review", message)
    Expand(true)
end
function VoicePad_Cancel()
    SetPhase("idle")
    receivedInput, submittedText = false, nil
    edit:ClearFocus()
    edit:SetText("")
    frame:Hide()
end
function VoicePad_Start()
    -- Do not erase an earlier draft on a repeated or delayed start command.
    if phase ~= "idle" and phase ~= "sent" then return end
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus and focus ~= edit then return end
    SetPhase("recording", "Listening · tap again to finish")
    receivedInput, submittedText = false, nil
    edit:SetText("")
    Expand(false)
    frame:Show()
    edit:SetFocus()
end
function VoicePad_Wait()
    if phase ~= "recording" then return end
    receivedInput = false
    edit:SetText("")
    SetPhase("waiting", "Transcribing…")
end
function VoicePad_Receive()
    if phase ~= "waiting" or GetCurrentKeyBoardFocus() ~= edit then return end
    SetPhase("receiving", "Finishing your message…")
end
function VoicePad_Send(manual)
    if phase ~= "receiving" and not (manual and (phase == "review" or phase == "waiting")) then return end
    if GetCurrentKeyBoardFocus() ~= edit then return end
    if not receivedInput then Review("No text yet · wait for OpenWhispr"); return end
    if not manual and GetTime() - lastInputAt < 0.35 then
        Review("Text still arriving · review, then Enter")
        return
    end
    local text, problem = ns.Model.Message(edit:GetText())
    if not text then Review(problem); return end
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if not send then Review("Chat unavailable · draft kept"); return end
    -- Exactly one request in a hardware key event. Slash-like speech is literal SAY.
    submittedText = text
    SetPhase("submitted", "Sending…")
    local ok = pcall(send, text, "SAY")
    if not ok then Review("Send blocked · Enter to retry"); return end
    edit:ClearFocus()
end
frame:RegisterEvent("CHAT_MSG_SAY")
frame:SetScript("OnEvent", function(_, event, text, author, language, channel, target, flags, zoneID, channelIndex, channelName, unused, lineID, guid)
    if event == "CHAT_MSG_SAY" and phase == "submitted" and guid == UnitGUID("player") and text == submittedText then
        SetPhase("sent", "Said nearby")
        receivedInput = false
        edit:SetText("")
        Expand(false)
    end
end)
local keys = {
    F6 = VoicePad_Start, F7 = VoicePad_Receive, F8 = VoicePad_Send,
    F9 = VoicePad_Wait, F10 = VoicePad_Cancel,
}
edit:SetScript("OnKeyDown", function(_, key)
    if keys[key] and IsControlKeyDown() and IsShiftKeyDown() and not IsAltKeyDown() then keys[key]() end
end)
edit:SetScript("OnTextChanged", function(_, userInput)
    if userInput and (phase == "waiting" or phase == "receiving" or phase == "review") then
        receivedInput, lastInputAt = true, GetTime()
    end
end)
edit:SetScript("OnEnterPressed", function() VoicePad_Send(true) end)
edit:SetScript("OnEscapePressed", function()
    if phase == "review" or phase == "sent" then VoicePad_Cancel()
    else
        -- Keep the paste target alive while OpenWhispr may still be processing.
        Review("Paused · Enter reviews; Esc dismisses")
    end
end)
-- Clicking away disarms submission; a late helper key cannot send a draft.
edit:SetScript("OnEditFocusLost", function()
    if phase ~= "idle" and phase ~= "submitted" and phase ~= "sent" then Review("Draft kept · click text to review") end
end)
frame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if phase == "sent" and elapsed > 1.6 then VoicePad_Cancel()
    elseif phase == "submitted" and elapsed > 5 then Review("Unconfirmed · check chat before retry")
    elseif (phase == "recording" and elapsed > 125) or ((phase == "waiting" or phase == "receiving") and elapsed > 65) then
        Review("Timed out · late text stays here")
    end
end)

BINDING_HEADER_VOICEPAD = "VoiceBind"
BINDING_NAME_VOICEPAD_START = "Helper: start dictation"
BINDING_NAME_VOICEPAD_RECEIVE = "Helper: receive transcript"
BINDING_NAME_VOICEPAD_SEND = "Helper: send transcript to /say"
BINDING_NAME_VOICEPAD_WAIT = "Helper: wait for transcript"
BINDING_NAME_VOICEPAD_CANCEL = "Helper: cancel"

local owner = CreateFrame("Frame", "VoicePadBindingOwner")
local commands = { "START", "RECEIVE", "SEND", "WAIT", "CANCEL" }
-- Standard LeftButton clicks avoid custom mouse-button names whose handling
-- differs between clients. Each binding has one dedicated callback.
for index, command in ipairs(commands) do
    local action = keys["F" .. (index + 5)]
    local signal = CreateFrame("Button", "VoicePadSignal" .. command, UIParent)
    signal:SetSize(1, 1)
    signal:SetPoint("BOTTOMLEFT")
    signal:SetAlpha(0)
    signal:RegisterForClicks("AnyUp")
    signal:SetScript("OnClick", function(_, _, down) if not down then action() end end)
end
local function SignalKey(index) return "CTRL-SHIFT-F" .. (index + 5) end
local function InstallBindings()
    if InCombatLockdown() then return end
    ClearOverrideBindings(owner)
    for index, command in ipairs(commands) do
        local key = SignalKey(index)
        local existing = GetBindingAction(key)
        if existing == "" or existing == "VOICEPAD_" .. command then
            -- Bind directly to our button; signal delivery does not depend on
            -- custom XML binding registration. Ordinary F6-F10 stay untouched.
            SetOverrideBindingClick(owner, false, key, "VoicePadSignal" .. command, "LeftButton")
        else
            print("|cff66d9c6VoicePad:|r " .. key .. " is already bound. Free Ctrl+Shift+F6-F10 for the helper.")
        end
    end
end
owner:RegisterEvent("PLAYER_LOGIN")
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:RegisterEvent("UPDATE_BINDINGS")
owner:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" and type(VoicePadDB) == "table" and type(VoicePadDB.x) == "number" and type(VoicePadDB.y) == "number" then
        local points = { TOP = true, BOTTOM = true, LEFT = true, RIGHT = true, CENTER = true, TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
        if points[VoicePadDB.point] and points[VoicePadDB.relativePoint] then
            frame:ClearAllPoints()
            frame:SetPoint(VoicePadDB.point, UIParent, VoicePadDB.relativePoint, VoicePadDB.x, VoicePadDB.y)
        end
    end
    InstallBindings()
end)

SLASH_VOICEPAD1 = "/voicepad"
SLASH_VOICEPAD2 = "/vp"
SlashCmdList.VOICEPAD = function(message)
    message = (message or ""):lower():match("^%s*(.-)%s*$")
    if message == "cancel" then VoicePad_Cancel()
    elseif message == "bubbles" then
        SetCVar("chatBubbles", "1")
        print("VoicePad: speech bubbles enabled for your client.")
    elseif message == "status" then
        print("|cff66d9c6VoiceBind 0.4.0:|r phase=" .. phase .. "; editor=" .. (GetCurrentKeyBoardFocus() == edit and "focused" or "not focused"))
        for index, command in ipairs(commands) do
            local key = SignalKey(index)
            local expected = "CLICK VoicePadSignal" .. command .. ":LeftButton"
            print(key .. ": " .. (GetBindingAction(key, true) == expected and "ready" or "NOT READY"))
        end
    elseif message == "test" then
        -- Let the slash-command chat editor finish closing before taking focus.
        C_Timer.After(0, function()
            VoicePad_Start()
            VoicePad_Wait()
            VoicePad_Receive()
            if phase ~= "receiving" then return end
            edit:SetText("VoicePad is ready.")
            receivedInput, lastInputAt = true, GetTime()
            Review("Test draft · Enter sends; Esc closes")
        end)
    else
        print("|cff66d9c6VoicePad:|r Start Utils\\VoicePad\\VoicePad.exe, then learn your controller button.")
        print("OpenWhispr: Tap mode, automatic paste ON. Keep your usual clipboard preference.")
        print("/vp test = test draft; /vp status = check helper keys; /vp cancel = close; /vp bubbles = show speech bubbles.")
    end
end
