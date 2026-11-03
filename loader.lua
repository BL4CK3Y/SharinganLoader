-- Sharingan AP loader: checks the license key, then runs the script the server sends back.
local API_URL = "https://fgonzxlez.site/swarmrbx/api/ap_load.php"
local BACKGROUND_URL = "https://raw.githubusercontent.com/BL4CK3Y/SharinganLoader/main/key_background.jpg"
local KEY_FILE = "sharingan_key.txt"
local OFFLINE_MESSAGE = "Key server is offline. Try again later."

local WINDOW_WIDTH, WINDOW_HEIGHT = 400, 310
local WINDOW_RADIUS = 14
local FIELD_RADIUS = 9
local FADE_TIME = 0.18
local MAX_KEY_LENGTH = 30
local MENU_TAB_NAME = "Sharingan Key"
local VK_BACKSPACE, VK_ENTER, VK_ESCAPE, VK_MINUS = 0x08, 0x0D, 0x1B, 0xBD

local PANEL = Color3.fromRGB(14, 14, 17)
local FIELD = Color3.fromRGB(24, 24, 29)
local FIELD_BORDER = Color3.fromRGB(54, 54, 62)
local ACCENT = Color3.fromRGB(190, 30, 38)
local ACCENT_HOVER = Color3.fromRGB(216, 46, 54)
local SHADOW = Color3.fromRGB(0, 0, 0)
local TEXT = Color3.fromRGB(238, 238, 242)
local MUTED = Color3.fromRGB(142, 142, 152)
local ERROR_TEXT = Color3.fromRGB(238, 104, 104)

local FONT_REGULAR = Drawing.Fonts.System
local FONT_BOLD = Drawing.Fonts.SystemBold

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

-- Uses game:HttpGet because it carries the full script in Matcha, unlike httppost
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

local function setGameInput(enabled)
    pcall(setrobloxinput, enabled)
end

local function isWindowActive()
    local ok, active = pcall(isrbxactive)
    return not ok or active
end

-- Draws the key window. Returns the script once a key is accepted, or nil if closed with Esc.
local function askForKey(startMessage)
    local screenWidth, screenHeight = 1920, 1080
    pcall(function()
        local viewport = workspace.CurrentCamera.ViewportSize
        screenWidth, screenHeight = viewport.X, viewport.Y
    end)
    local left = math.floor((screenWidth - WINDOW_WIDTH) / 2)
    local top = math.floor((screenHeight - WINDOW_HEIGHT) / 2)
    local centerX = left + WINDOW_WIDTH / 2

    local drawings = {}
    local zIndex = 100000
    local function draw(kind, properties, opacity)
        local drawing = Drawing.new(kind)
        zIndex = zIndex + 1
        properties.ZIndex = zIndex
        properties.Visible = true
        properties.Transparency = 0
        -- Each one is separate so one unsupported property can't lose the rest
        for name, value in pairs(properties) do
            pcall(function()
                drawing[name] = value
            end)
        end
        drawings[#drawings + 1] = { drawing = drawing, opacity = opacity or 1 }
        return drawing
    end

    local function drawBox(x, y, width, height, color, radius, opacity)
        return draw("Square", {
            Position = Vector2.new(x, y),
            Size = Vector2.new(width, height),
            Color = color,
            Filled = true,
            Corner = radius,
        }, opacity)
    end

    local function drawOutline(x, y, width, height, color, radius)
        return draw("Square", {
            Position = Vector2.new(x, y),
            Size = Vector2.new(width, height),
            Color = color,
            Filled = false,
            Thickness = 1,
            Corner = radius,
        })
    end

    -- With Center on, Matcha centers the text on y as well as x, so y is its middle
    local function drawText(text, x, y, size, color, font, centered)
        return draw("Text", {
            Text = text,
            Position = Vector2.new(x, y),
            -- Text stayed small in Matcha with only the documented FontSize
            Size = size,
            FontSize = size,
            Color = color,
            Font = font,
            Center = centered,
            Outline = false,
        })
    end

    -- Soft shadow, from widest and faintest to tightest
    for _, spread in ipairs({ 16, 11, 7, 3 }) do
        drawBox(left - spread, top - spread + 4, WINDOW_WIDTH + spread * 2, WINDOW_HEIGHT + spread * 2, SHADOW, WINDOW_RADIUS + spread, 0.09)
    end
    drawBox(left, top, WINDOW_WIDTH, WINDOW_HEIGHT, PANEL, WINDOW_RADIUS)

    -- The window still works if the image can't load
    pcall(function()
        local image = game:HttpGet(BACKGROUND_URL)
        draw("Image", {
            Data = image,
            Position = Vector2.new(left, top),
            Size = Vector2.new(WINDOW_WIDTH, WINDOW_HEIGHT),
            Rounding = WINDOW_RADIUS,
        })
    end)
    drawOutline(left, top, WINDOW_WIDTH, WINDOW_HEIGHT, FIELD_BORDER, WINDOW_RADIUS)

    drawText("Sharingan AP", centerX, top + 118, 26, TEXT, FONT_BOLD, true)
    -- Doubles as the status line, so nothing sits under the button
    local statusText = drawText("Enter your license key to continue", centerX, top + 150, 14, MUTED, FONT_REGULAR, true)

    local inputX, inputY, inputWidth, inputHeight = left + 40, top + 178, WINDOW_WIDTH - 80, 44
    local buttonX, buttonY, buttonWidth, buttonHeight = inputX, top + 234, inputWidth, 44

    drawBox(inputX, inputY, inputWidth, inputHeight, FIELD, FIELD_RADIUS)
    local inputBorder = drawOutline(inputX, inputY, inputWidth, inputHeight, FIELD_BORDER, FIELD_RADIUS)
    local keyText = drawText("", inputX + 14, inputY + 12, 16, MUTED, FONT_BOLD, false)

    local button = drawBox(buttonX, buttonY, buttonWidth, buttonHeight, ACCENT, FIELD_RADIUS)
    drawText("Submit", centerX, buttonY + buttonHeight / 2, 18, TEXT, FONT_BOLD, true)

    local function setStatus(message, color)
        statusText.Text = message
        statusText.Color = color or MUTED
    end
    if startMessage then
        setStatus(startMessage, ERROR_TEXT)
    end

    local mouse = game:GetService("Players").LocalPlayer:GetMouse()
    local function isHovering(x, y, width, height)
        return mouse.X >= x and mouse.X <= x + width and mouse.Y >= y and mouse.Y <= y + height
    end

    local typedKey = ""
    local pastedKey = nil
    local focused = true
    local checking = false
    local closed = false
    local source = nil
    local heldKeys = {}
    local backspaceRepeatAt = 0
    local mouseWasDown = false

    -- Matcha has no clipboard read, so paste relies on its menu's own text field
    pcall(function()
        UI.AddTab(MENU_TAB_NAME, function(tab)
            local section = tab:Section("License", "Left")
            section:InputText("sharingan_license_key", "Paste key, then click away", "", function(text)
                pastedKey = text
            end)
        end)
    end)

    local function wasPressed(keyCode)
        local down = iskeypressed(keyCode) == true
        local pressed = down and not heldKeys[keyCode]
        heldKeys[keyCode] = down
        return pressed
    end

    local function submit()
        if checking then return end
        if typedKey == "" then
            setStatus("Enter your key first", ERROR_TEXT)
            return
        end

        checking = true
        setStatus("Checking...")
        task.spawn(function()
            local result, payload = checkKey(typedKey)
            if result == "ok" then
                saveKey(typedKey)
                setStatus("Loading...")
                source = payload
            else
                setStatus(payload, ERROR_TEXT)
                checking = false
            end
        end)
    end

    local function readTyping()
        for keyCode = 0x30, 0x39 do
            if wasPressed(keyCode) and #typedKey < MAX_KEY_LENGTH then
                typedKey = typedKey .. string.char(keyCode)
            end
        end
        for keyCode = 0x41, 0x5A do
            if wasPressed(keyCode) and #typedKey < MAX_KEY_LENGTH then
                typedKey = typedKey .. string.char(keyCode)
            end
        end
        if wasPressed(VK_MINUS) and #typedKey < MAX_KEY_LENGTH then
            typedKey = typedKey .. "-"
        end

        local now = tick()
        if wasPressed(VK_BACKSPACE) then
            typedKey = string.sub(typedKey, 1, -2)
            backspaceRepeatAt = now + 0.4
        elseif heldKeys[VK_BACKSPACE] and now >= backspaceRepeatAt then
            typedKey = string.sub(typedKey, 1, -2)
            backspaceRepeatAt = now + 0.04
        end

        if wasPressed(VK_ENTER) then
            submit()
        end
    end

    local openedAt = tick()
    local faded = false

    setGameInput(false)
    repeat
        task.wait()

        if not faded then
            local progress = math.min((tick() - openedAt) / FADE_TIME, 1)
            for _, entry in ipairs(drawings) do
                entry.drawing.Transparency = entry.opacity * progress
            end
            faded = progress >= 1
        end

        if pastedKey and not checking then
            typedKey = string.sub(string.upper((string.gsub(pastedKey, "%s", ""))), 1, MAX_KEY_LENGTH)
            pastedKey = nil
            submit()
        end

        if isWindowActive() then
            if wasPressed(VK_ESCAPE) then
                closed = true
            end

            local mouseDown = ismouse1pressed() == true
            local overButton = isHovering(buttonX, buttonY, buttonWidth, buttonHeight)
            if mouseDown and not mouseWasDown then
                if overButton then
                    submit()
                elseif isHovering(inputX, inputY, inputWidth, inputHeight) then
                    focused = true
                else
                    focused = false
                end
                setGameInput(not focused)
            end
            mouseWasDown = mouseDown
            button.Color = overButton and ACCENT_HOVER or ACCENT

            if focused and not checking then
                readTyping()
            end
        end

        inputBorder.Color = focused and ACCENT or FIELD_BORDER
        if typedKey == "" then
            keyText.Text = "Your license key"
            keyText.Color = MUTED
        else
            local cursor = (focused and not checking and tick() % 1 < 0.5) and "|" or ""
            keyText.Text = typedKey .. cursor
            keyText.Color = TEXT
        end
    until source or closed

    pcall(function()
        UI.RemoveTab(MENU_TAB_NAME)
    end)
    setGameInput(true)
    for _, entry in ipairs(drawings) do
        pcall(function()
            entry.drawing.Visible = false
            entry.drawing:Remove()
        end)
    end
    return source
end

local function startFromWindow(startMessage)
    local source = askForKey(startMessage)
    if source then
        runScript(source)
    end
end

-- _G.SharinganKey is a fallback for anyone who can't type into the window
local presetKey = _G.SharinganKey
local savedKey = (type(presetKey) == "string" and presetKey ~= "") and presetKey or readSavedKey()

if not savedKey then
    startFromWindow()
else
    local result, payload = checkKey(savedKey)
    if result == "ok" then
        saveKey(savedKey)
        runScript(payload)
    else
        warn("[Sharingan] " .. payload)
        startFromWindow(payload)
    end
end
