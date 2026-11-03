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
    local tag = string.sub(reply, 1, 3)
    if tag == "OK\n" then
        return "ok", string.sub(reply, 4)
    elseif string.sub(reply, 1, 4) == "ERR\n" then
        return "denied", string.sub(reply, 5)
    end
    return "offline", OFFLINE_MESSAGE
end

local function runScript(source)
    task.spawn(function()
        loadstring(source)()
    end)
end

local function showKeyWindow(startMessage)
    local UI = loadstring(httpget(UI_URL))() or INSui
    local window = UI:CreateWindow({
        title = "Sharingan",
        size = Vector2.new(420, 300),
        configFolder = "sharingan_loader",
        opacity = 1,
    })
    pcall(function() UI:SetAccent(Color3.fromRGB(210, 40, 40)) end)

    local section = window:Tab("License", "home"):Section("Enter your key", "Left")
    local typedKey = ""
    local checking = false

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
                UI:Destroy()
                -- Lets the window finish closing before the AP opens its own
                task.wait(0.2)
                runScript(payload)
            else
                status:SetText(payload)
                checking = false
            end
        end)
    end)
end

-- _G.SharinganKey is a fallback for anyone who can't paste into the window
local presetKey = _G.SharinganKey
local savedKey = (type(presetKey) == "string" and presetKey ~= "") and presetKey or readSavedKey()

if not savedKey then
    showKeyWindow()
else
    local result, payload = checkKey(savedKey)
    if result == "ok" then
        saveKey(savedKey)
        runScript(payload)
    elseif result == "offline" then
        warn("[Sharingan] " .. payload)
        showKeyWindow(payload)
    else
        showKeyWindow(payload)
    end
end
