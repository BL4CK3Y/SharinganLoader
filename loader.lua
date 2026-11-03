-- Sharingan AP loader: checks the license key, then runs the script the server sends back.
local API_URL = "https://fgonzxlez.site/swarmrbx/api/ap_load.php"
local BACKGROUND_URL = "https://raw.githubusercontent.com/BL4CK3Y/SharinganLoader/main/key_background.jpg"
local KEY_FILE = "sharingan_key.txt"
local OFFLINE_MESSAGE = "Key server is offline. Try again later."

local WINDOW_WIDTH, WINDOW_HEIGHT = 420, 280
local MAX_KEY_LENGTH = 30
local VK_BACKSPACE, VK_ENTER, VK_ESCAPE, VK_MINUS = 0x08, 0x0D, 0x1B, 0xBD

local RED = Color3.fromRGB(200, 25, 30)
local RED_HOVER = Color3.fromRGB(235, 45, 50)
local BLACK = Color3.fromRGB(10, 10, 12)
local WHITE = Color3.fromRGB(240, 240, 240)
local GREY = Color3.fromRGB(150, 150, 155)

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

    local drawings = {}
    local zIndex = 100000
    local function draw(kind, properties)
        local drawing = Drawing.new(kind)
        zIndex = zIndex + 1
        properties.ZIndex = zIndex
        properties.Visible = true
        properties.Transparency = 1
        -- Each one is separate so one unsupported property can't lose the rest
        for name, value in pairs(properties) do
            pcall(function()
                drawing[name] = value
            end)
        end
        drawings[#drawings + 1] = drawing
        return drawing
    end

    local function drawText(text, y, size, color)
        return draw("Text", { Text = text, Position = Vector2.new(left, top + y), Size = size, Color = color, Outline = true })
    end

    -- Drawing text has no centering, so this uses an estimated character width
    local function centerText(drawing, text, y, size)
        drawing.Text = text
        drawing.Position = Vector2.new(left + (WINDOW_WIDTH - #text * size * 0.52) / 2, top + y)
    end

    draw("Square", {
        Position = Vector2.new(left, top),
        Size = Vector2.new(WINDOW_WIDTH, WINDOW_HEIGHT),
        Color = BLACK,
        Filled = true,
    })

    -- The window still works if the image can't load
    pcall(function()
        local image = game:HttpGet(BACKGROUND_URL)
        draw("Image", {
            Data = image,
            Position = Vector2.new(left, top),
            Size = Vector2.new(WINDOW_WIDTH, WINDOW_HEIGHT),
        })
    end)

    draw("Square", {
        Position = Vector2.new(left, top),
        Size = Vector2.new(WINDOW_WIDTH, WINDOW_HEIGHT),
        Color = RED,
        Filled = false,
        Thickness = 1,
    })

    local titleText = drawText("", 24, 24, WHITE)
    centerText(titleText, "ENTER YOUR KEY", 24, 24)

    local inputX, inputY, inputWidth, inputHeight = left + 60, top + 165, WINDOW_WIDTH - 120, 36
    local buttonX, buttonY, buttonWidth, buttonHeight = inputX, top + 209, inputWidth, 34

    draw("Square", {
        Position = Vector2.new(inputX, inputY),
        Size = Vector2.new(inputWidth, inputHeight),
        Color = BLACK,
        Filled = true,
    })
    local inputBorder = draw("Square", {
        Position = Vector2.new(inputX, inputY),
        Size = Vector2.new(inputWidth, inputHeight),
        Color = RED,
        Filled = false,
        Thickness = 1,
    })
    local keyText = drawText("", 174, 16, WHITE)

    local button = draw("Square", {
        Position = Vector2.new(buttonX, buttonY),
        Size = Vector2.new(buttonWidth, buttonHeight),
        Color = RED,
        Filled = true,
    })
    local buttonText = drawText("", 217, 16, WHITE)
    centerText(buttonText, "SUBMIT", 217, 16)

    local statusText = drawText("", 252, 14, GREY)
    local function setStatus(message)
        centerText(statusText, message, 252, 14)
    end
    setStatus(startMessage or "")

    local mouse = game:GetService("Players").LocalPlayer:GetMouse()
    local function isHovering(x, y, width, height)
        return mouse.X >= x and mouse.X <= x + width and mouse.Y >= y and mouse.Y <= y + height
    end

    local typedKey = ""
    local focused = true
    local checking = false
    local closed = false
    local source = nil
    local heldKeys = {}
    local backspaceRepeatAt = 0
    local mouseWasDown = false

    local function wasPressed(keyCode)
        local down = iskeypressed(keyCode) == true
        local pressed = down and not heldKeys[keyCode]
        heldKeys[keyCode] = down
        return pressed
    end

    local function submit()
        if checking then return end
        if typedKey == "" then
            setStatus("Enter your key first")
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
                setStatus(payload)
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

    setGameInput(false)
    repeat
        task.wait()

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
            button.Color = overButton and RED_HOVER or RED

            if focused and not checking then
                readTyping()
            end
        end

        inputBorder.Color = focused and RED_HOVER or RED
        local cursor = (focused and not checking and tick() % 1 < 0.5) and "_" or ""
        keyText.Text = typedKey .. cursor
        keyText.Position = Vector2.new(left + (WINDOW_WIDTH - #typedKey * 16 * 0.52) / 2, top + 174)
    until source or closed

    setGameInput(true)
    for _, drawing in ipairs(drawings) do
        pcall(function()
            drawing.Visible = false
            drawing:Remove()
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
