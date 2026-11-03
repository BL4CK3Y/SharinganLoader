-- Sharingan AP loader: checks the license key, then runs the script the server sends back.
local API_URL = "https://fgonzxlez.site/swarmrbx/api/ap_load.php"
local UI_URL = "https://raw.githubusercontent.com/artxficial/INS-ui/main/uilib.min.lua"
local KEY_FILE = "sharingan_key.txt"
local OFFLINE_MESSAGE = "Key server is offline. Try again later."

local HttpService = game:GetService("HttpService")

local function readSavedKey()
    local ok, key = pcall(readfile, KEY_FILE)
    if ok and type(key) == "string" and key ~= "" then
        return key
    end
    return nil
end

local function saveKey(key)
    pcall(writefile, KEY_FILE, key)
end

-- Uses game:HttpGet because the old loader proved it carries the full script in Matcha
local function downloadScript(token, expectedSize)
    local ok, reply = pcall(function()
        return game:HttpGet(API_URL .. "?token=" .. token)
    end)
    if not ok or type(reply) ~= "string" then
        return "offline", OFFLINE_MESSAGE
    end
    if string.sub(reply, 1, 4) == "ERR\n" then
        return "denied", string.sub(reply, 5)
    end
    if string.sub(reply, 1, 3) ~= "OK\n" then
        return "offline", OFFLINE_MESSAGE
    end

    local source = string.sub(reply, 4)
    if #source ~= expectedSize then
        return "denied", "Download cut off (" .. #source .. " of " .. tostring(expectedSize) .. " bytes)"
    end
    return "ok", source
end

-- Returns "ok" + script, "denied" + message, or "offline" + message
local function checkKey(key)
    local okHwid, hwid = pcall(gethwid)
    if not okHwid or not hwid then
        return "denied", "Could not read your PC ID"
    end

    local body = HttpService:JSONEncode({ key = key, hwid = hwid })
    local okPost, reply = pcall(httppost, API_URL, body, "application/json")
    if not okPost or type(reply) ~= "string" then
        return "offline", OFFLINE_MESSAGE
    end

    -- Anything else is an offline server or a Cloudflare page
    if string.sub(reply, 1, 3) == "OK\n" then
        local token, size = string.match(reply, "^OK\n(%x+)\n(%d+)")
        if not token then
            return "offline", OFFLINE_MESSAGE
        end
        return downloadScript(token, tonumber(size))
    elseif string.sub(reply, 1, 4) == "ERR\n" then
        return "denied", string.sub(reply, 5)
    end
    return "offline", OFFLINE_MESSAGE
end

local function runScript(source)
    print("[Sharingan] Starting (" .. #source .. " bytes)")
    local ok, err = pcall(loadstring(source))
    if not ok then
        warn("[Sharingan] Failed to start: " .. tostring(err))
    end
end

-- Returns the script once a key is accepted
local function askForKey(startMessage)
    local UI = loadstring(httpget(UI_URL))() or INSui
    local window = UI:CreateWindow({
        title = "Sharingan",
        size = Vector2.new(420, 300),
        configFolder = "sharingan_loader",
        opacity = 1,
    })
    pcall(function() UI:SetAccent(Color3.fromRGB(210, 40, 40)) end)

    local tab = window:Tab("License", "home")
    local section = tab:Section("Enter your key", "Left")
    local typedKey = ""
    local checking = false
    local source = nil

    section:Textbox("License Key", "", function(text)
        typedKey = text
    end)
    local status = section:Label(startMessage or "Paste or type your key")

    section:Button("Submit", function()
        if checking then return end
        local key = string.gsub(typedKey, "%s", "")
        if key == "" then
            status:SetText("Enter your key first")
            return
        end

        checking = true
        status:SetText("Checking...")
        task.spawn(function()
            local result, payload = checkKey(key)
            if result == "ok" then
                saveKey(key)
                status:SetText("Loading...")
                source = payload
            else
                status:SetText(payload)
                checking = false
            end
        end)
    end)

    repeat
        task.wait(0.05)
    until source

    UI:Destroy()
    -- Lets the window finish closing before the AP opens its own
    task.wait(0.2)
    -- The library's Destroy leaves the highlighted tab icon behind
    pcall(function()
        tab._tab._imgA.Visible = false
        tab._tab._imgA:Remove()
    end)
    return source
end

-- _G.SharinganKey is a fallback for anyone who can't paste into the window
local presetKey = _G.SharinganKey
local savedKey = (type(presetKey) == "string" and presetKey ~= "") and presetKey or readSavedKey()

if not savedKey then
    runScript(askForKey())
else
    local result, payload = checkKey(savedKey)
    if result == "ok" then
        saveKey(savedKey)
        runScript(payload)
    else
        warn("[Sharingan] " .. payload)
        runScript(askForKey(payload))
    end
end
