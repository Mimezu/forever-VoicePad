local _, ns = ...
ns.Model = {}

-- OpenWhispr pastes directly into our dedicated editor. Never parse commands.
function ns.Model.Message(text)
    if type(text) ~= "string" then return nil, "Waiting for pasted speech." end
    text = text:gsub("[%z\1-\31\127]", " ")
    text = text:gsub("|", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
    if text == "" then return nil, "No speech was detected." end
    -- WoW's chat limit is bytes, not Unicode characters. Never silently cut
    -- off a sentence or split one controller action into multiple messages.
    if #text > 255 then
        return nil, "Too long for /say (255 bytes). Shorten the text, then press Enter."
    end
    return text
end
