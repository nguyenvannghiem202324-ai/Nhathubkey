--============================================================
-- NHAT HUB | PLATOBOOST KEY SYSTEM
-- Delta Executor Android - UI redesign + click sound
-- Save key + automatic activation
--============================================================
-- IMPORTANT:
-- 1) Rotate the old PlatoBoost Secret: it was present in the uploaded file.
-- 2) Replace SECRET_HERE with the newly rotated Secret.
-- 3) A client-side Secret can be extracted from any distributed script.
--    For production security, verify keys through your own server.

local service = 33297
local secret = "SECRET_HERE" -- Do not distribute a real Secret inside a client-side script
local useNonce = true

repeat task.wait(0.5) until game:IsLoaded()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Executor compatibility helpers
local fRequest = request or http_request or (syn and syn.request)
local fSetClipboard = setclipboard or toclipboard
local fGetHwid = gethwid or function() return tostring(player.UserId) end
local function lEncode(value) return HttpService:JSONEncode(value) end
local function lDecode(value) return HttpService:JSONDecode(value) end
local function lDigest(value)
    -- Match the digest/identifier routine in the integration code you supplied.
    local input = tostring(value)
    local out = {}
    for i = 1, #input do out[i] = string.format("%02x", string.byte(input, i)) end
    return table.concat(out)
end

if not fRequest then error("This executor does not provide request/http_request.") end

local requestSending = false
local cachedLink, cachedTime = "", 0
local HOST = "https://api.platoboost.net"
local savedKeyFile = "NHAT_HUB_KEY.txt"
local UI_ACCENT = Color3.fromRGB(42, 205, 255)
local UI_ACCENT2 = Color3.fromRGB(105, 104, 255)
local BG = Color3.fromRGB(10, 14, 25)
local PANEL = Color3.fromRGB(17, 23, 39)
local PANEL2 = Color3.fromRGB(23, 31, 51)
local TEXT = Color3.fromRGB(240, 246, 255)
local MUTED = Color3.fromRGB(142, 158, 184)
local GREEN = Color3.fromRGB(73, 226, 153)
local RED = Color3.fromRGB(255, 94, 116)
local gui -- Forward declaration so activation can destroy the key UI.

local function notify(message)
    message = tostring(message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "NHAT HUB | GETKEY",
            Text = message,
            Duration = 4
        })
    end)
    warn("[NHAT HUB | GETKEY] " .. message)
end

-- Only called after PlatoBoost explicitly confirms the key is valid.
local MAIN_SCRIPT_URLS = {
    "https://raw.githubusercontent.com/nguyenvannghiem202324-ai/Script/refs/heads/main/script",
    "https://raw.githubusercontent.com/nguyenvannghiem202324-ai/NhatHub/refs/heads/main/Okok"
}

local function activateMainScripts()
    -- Remove the key interface before launching the main scripts.
    if gui and gui.Parent then
        gui:Destroy()
    end

    -- Load in order; a failure in one script will not block the next.
    for index, url in ipairs(MAIN_SCRIPT_URLS) do
        local ok, err = pcall(function()
            local response = game:HttpGet(url)
            local loader, compileError = loadstring(response)
            if not loader then
                error(compileError or "Could not compile downloaded script")
            end
            loader()
        end)

        if not ok then
            warn(("[NHAT HUB] Script %d failed to load: %s"):format(index, tostring(err)))
            notify(("Script %d failed to load. Check the URL or executor permissions."):format(index))
        end
    end
end

local function requestJSON(options)
    local ok, response = pcall(function() return fRequest(options) end)
    if not ok then error(tostring(response)) end
    if not response then error("PlatoBoost returned no response.") end
    return response
end
local function cacheLink()
    if cachedLink ~= "" and cachedTime + 600 > os.time() then
        return true, cachedLink
    end
    local response = requestJSON({
        Url = HOST .. "/public/start",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = lEncode({ service = service, identifier = lDigest(fGetHwid()) })
    })
    if response.StatusCode == 200 then
        local decoded = lDecode(response.Body)
        if decoded.success == true and decoded.data and decoded.data.url then
            cachedLink, cachedTime = decoded.data.url, os.time()
            return true, cachedLink
        end
        return false, (decoded and decoded.message) or "PlatoBoost did not return a key URL."
    end
    return false, "PlatoBoost HTTP " .. tostring(response.StatusCode) .. ". Check service ID and API availability."
end
local function generateNonce()
    local chars = "abcdefghijklmnopqrstuvwxyz"
    local result = {}
    for i = 1, 16 do
        local n = math.random(1, #chars)
        result[i] = chars:sub(n, n)
    end
    return table.concat(result)
end

local function verifyKey(key)
    if requestSending then return false, "A request is already in progress." end
    requestSending = true
    local ok, result, message = pcall(function()
        local nonce = generateNonce()
        local endpoint = HOST .. "/public/whitelist/" .. tostring(service)
            .. "?identifier=" .. HttpService:UrlEncode(lDigest(fGetHwid()))
            .. "&key=" .. HttpService:UrlEncode(key)
        if useNonce then endpoint = endpoint .. "&nonce=" .. HttpService:UrlEncode(nonce) end
        local response = requestJSON({ Url = endpoint, Method = "GET" })
        if response.StatusCode ~= 200 then
            return false, "PlatoBoost HTTP " .. tostring(response.StatusCode) .. "."
        end
        local decoded = lDecode(response.Body)
        if decoded.success == true and decoded.data and decoded.data.valid == true then
            return true
        end
        return false, (decoded and decoded.message) or "Invalid key."
    end)
    requestSending = false
    if not ok then return false, tostring(result) end
    return result, message
end
local function readSavedKey()
    if not (isfile and readfile) then return nil end
    local ok, value = pcall(function()
        if isfile(savedKeyFile) then return readfile(savedKeyFile) end
    end)
    if ok and type(value) == "string" and value:gsub("%s+", "") ~= "" then
        return value:gsub("^%s*(.-)%s*$", "%1")
    end
    return nil
end

local function saveKey(key)
    if writefile then
        local ok, err = pcall(function() writefile(savedKeyFile, key) end)
        return ok, err
    end
    return false, "This executor does not support writefile."
end

-- UI sound. Can be disabled by setting SOUND_ENABLED = false.
local SOUND_ENABLED = true
local CLICK_SOUND_ID = "rbxassetid://6895079853"
local function clickSound(parent)
    if not SOUND_ENABLED then return end
    pcall(function()
        local sound = Instance.new("Sound")
        sound.Name = "NHAT_Click"
        sound.SoundId = CLICK_SOUND_ID
        sound.Volume = 0.45
        sound.Parent = parent or SoundService
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)
        task.delay(3, function() if sound and sound.Parent then sound:Destroy() end end)
    end)
end

-- Remove duplicate UI on re-execution
pcall(function() playerGui:FindFirstChild("NHAT_Platoboost_KeyUI"):Destroy() end)
gui = Instance.new("ScreenGui")
gui.Name = "NHAT_Platoboost_KeyUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function make(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function corner(parent, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end
local function stroke(parent, color, transparency, thickness)
    make("UIStroke", { Color = color or UI_ACCENT, Transparency = transparency or 0.5, Thickness = thickness or 1 }, parent)
end
local function gradient(parent, c1, c2, rotation)
    make("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rotation or 0 }, parent)
end

local scale = make("UIScale", { Scale = math.clamp((workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 390) / 430, 0.78, 1.0) }, gui)
local main = make("Frame", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(340, 390), BackgroundColor3 = BG, BorderSizePixel = 0
}, gui)
corner(main, 18); stroke(main, UI_ACCENT, 0.28, 1.3)
gradient(main, Color3.fromRGB(15, 26, 46), Color3.fromRGB(8, 11, 21), 110)
make("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 15), PaddingRight = UDim.new(0, 15) }, main)

local top = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48) }, main)
local logo = make("Frame", { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(0, 1), BackgroundColor3 = UI_ACCENT, BorderSizePixel = 0 }, top)
corner(logo, 13); gradient(logo, UI_ACCENT, UI_ACCENT2, 45)
make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "N", Font = Enum.Font.GothamBlack, TextSize = 25, TextColor3 = Color3.new(1,1,1) }, logo)
make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(53, 2), Size = UDim2.new(1, -85, 0, 22), Text = "NHAT HUB", Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left }, top)
make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 24), Size = UDim2.new(1, -85, 0, 17), Text = "PLATOBOOST KEY SYSTEM", Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = UI_ACCENT, TextXAlignment = Enum.TextXAlignment.Left }, top)
local close = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = PANEL2, Text = "×", TextColor3 = MUTED, TextSize = 22, Font = Enum.Font.GothamBold, AutoButtonColor = false }, top)
corner(close, 10)

local statusBar = make("Frame", { Position = UDim2.fromOffset(0, 57), Size = UDim2.new(1, 0, 0, 31), BackgroundColor3 = PANEL, BorderSizePixel = 0 }, main)
corner(statusBar, 9)
local statusDot = make("Frame", { Position = UDim2.fromOffset(10, 11), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = UI_ACCENT, BorderSizePixel = 0 }, statusBar); corner(statusDot, 99)
local statusText = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(25, 0), Size = UDim2.new(1, -35, 1, 0), Text = "SYSTEM READY  •  WAITING FOR KEY", Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left }, statusBar)

make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 25), Text = "Unlock your experience", Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left }, main)
make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 122), Size = UDim2.new(1, 0, 0, 20), Text = "Get a key, then verify it to continue.", Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left }, main)

local inputWrap = make("Frame", { Position = UDim2.fromOffset(0, 151), Size = UDim2.new(1, 0, 0, 47), BackgroundColor3 = PANEL2, BorderSizePixel = 0 }, main)
corner(inputWrap, 11); stroke(inputWrap, Color3.fromRGB(64, 82, 115), 0.45, 1)
local keyBox = make("TextBox", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1, ClearTextOnFocus = false, PlaceholderText = "Paste your key here...", PlaceholderColor3 = MUTED, Text = "", TextColor3 = TEXT, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }, inputWrap)

local function button(text, y, colorA, colorB)
    local b = make("TextButton", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 41), BackgroundColor3 = colorA, BorderSizePixel = 0, Text = text, TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false }, main)
    corner(b, 11); gradient(b, colorA, colorB or colorA, 0); stroke(b, colorA, 0.45, 1)
    b.MouseButton1Down:Connect(function() clickSound(b) end)
    b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = colorB or colorA }):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = colorA }):Play() end)
    return b
end
local getButton = button("↗   GET KEY  •  OPEN PLATOBOOST", 210, UI_ACCENT2, UI_ACCENT)
local verifyButton = button("✓   VERIFY KEY", 258, Color3.fromRGB(22, 145, 115), GREEN)
local pasteButton = button("▣   PASTE FROM CLIPBOARD", 306, PANEL2, Color3.fromRGB(39, 54, 80))

local saveToggle = make("TextButton", { Position = UDim2.fromOffset(0, 355), Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = "✓  SAVE KEY & AUTOMATIC ACTIVATION     ON", TextColor3 = GREEN, Font = Enum.Font.GothamMedium, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false }, main)
local saveEnabled = true
saveToggle.MouseButton1Down:Connect(function() clickSound(saveToggle) end)
saveToggle.MouseButton1Click:Connect(function()
    saveEnabled = not saveEnabled
    saveToggle.Text = saveEnabled and "✓  SAVE KEY & AUTOMATIC ACTIVATION     ON" or "○  SAVE KEY & AUTOMATIC ACTIVATION     OFF"
    saveToggle.TextColor3 = saveEnabled and GREEN or MUTED
end)

local footer = make("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 9), Size = UDim2.new(1, 0, 0, 14), Text = "SECURE CHECK  •  POWERED BY PLATOBOOST", Font = Enum.Font.GothamMedium, TextSize = 8, TextColor3 = Color3.fromRGB(82, 101, 131) }, main)

-- Drag window on touch or mouse
local dragging, dragStart, startPos
 top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local function setStatus(message, good)
    statusText.Text = tostring(message):upper()
    statusText.TextColor3 = good and GREEN or (good == false and RED or MUTED)
    statusDot.BackgroundColor3 = good and GREEN or (good == false and RED or UI_ACCENT)
end
local busy = false
local function runVerify(key, automatic)
    if busy then return end
    key = (key or ""):gsub("^%s*(.-)%s*$", "%1")
    if key == "" then setStatus("PLEASE ENTER A KEY", false); return end
    busy = true
    verifyButton.Text = automatic and "◌  AUTO ACTIVATING..." or "◌  VERIFYING KEY..."
    setStatus(automatic and "CHECKING SAVED KEY" or "CONTACTING PLATOBOOST", nil)
    task.spawn(function()
        local ok, valid, reason = pcall(verifyKey, key)
        local success = ok and valid == true
        if success then
            if saveEnabled then
                local saved, err = saveKey(key)
                if not saved then notify("Key valid, but could not save: " .. tostring(err)) end
            end
            setStatus("KEY VALID  •  ACCESS GRANTED", true)
            verifyButton.Text = "✓  KEY VERIFIED"
            notify("Key verified successfully. Activating NHAT HUB...")
            task.wait(0.35)
            activateMainScripts()
        else
            local message = ok and (reason or "Key rejected.") or tostring(valid)
            setStatus("VERIFICATION FAILED", false)
            verifyButton.Text = "✓   VERIFY KEY"
            notify(message)
        end
        busy = false
    end)
end

getButton.MouseButton1Click:Connect(function()
    clickSound(getButton)
    setStatus("GENERATING YOUR KEY LINK", nil)
    task.spawn(function()
        local ok, linkOrError, err = pcall(cacheLink)
        if ok then
            local success, link = linkOrError, err
            if success then
                if fSetClipboard then pcall(fSetClipboard, link) end
                local opened = pcall(function() GuiService:OpenBrowserWindow(link) end)
                if not opened then notify("Key link copied if clipboard is supported. Open your browser to continue.") end
                setStatus("KEY LINK READY  •  COMPLETE CHECKPOINT", true)
                notify("PlatoBoost link ready. Complete the checkpoint, then paste your key here.")
            else
                setStatus("COULD NOT CREATE LINK", false); notify(link or "Could not create link.")
            end
        else
            setStatus("CONNECTION ERROR", false); notify(tostring(linkOrError))
        end
    end)
end)
verifyButton.MouseButton1Click:Connect(function() clickSound(verifyButton); runVerify(keyBox.Text, false) end)
pasteButton.MouseButton1Click:Connect(function()
    clickSound(pasteButton)
    -- Executors usually expose clipboard read under getclipboard; some do not.
    local getter = getclipboard or getclipboardtext
    if getter then
        local ok, value = pcall(getter)
        if ok and type(value) == "string" then keyBox.Text = value; setStatus("KEY PASTED  •  READY TO VERIFY", true); return end
    end
    setStatus("PASTE INTO THE KEY FIELD MANUALLY", nil)
end)
close.MouseButton1Down:Connect(function() clickSound(close) end)
close.MouseButton1Click:Connect(function()
    gui.Enabled = false
    local reopen = Instance.new("TextButton")
    reopen.Name = "NHAT_Key_Reopen"
    reopen.Size = UDim2.fromOffset(46, 46)
    reopen.Position = UDim2.new(1, -62, 0.55, 0)
    reopen.BackgroundColor3 = UI_ACCENT2
    reopen.Text = "N"
    reopen.TextColor3 = Color3.new(1,1,1)
    reopen.TextSize = 22
    reopen.Font = Enum.Font.GothamBlack
    reopen.Parent = gui
    corner(reopen, 15); gradient(reopen, UI_ACCENT, UI_ACCENT2, 45)
    reopen.MouseButton1Down:Connect(function() clickSound(reopen) end)
    reopen.MouseButton1Click:Connect(function() clickSound(reopen); gui.Enabled = true; reopen:Destroy() end)
end)

-- Auto-activate a previously saved key after the UI has initialized.
local savedKey = readSavedKey()
if savedKey then
    keyBox.Text = savedKey
    setStatus("SAVED KEY FOUND  •  AUTO ACTIVATING", nil)
    task.delay(0.8, function()
        if gui.Parent then runVerify(savedKey, true) end
    end)
else
    setStatus("SYSTEM READY  •  WAITING FOR KEY", nil)
end

-- Gentle entrance animation
main.Position = UDim2.fromScale(0.5, 0.54)
main.BackgroundTransparency = 1
TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
    Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0
}):Play()
