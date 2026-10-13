--[[
    ██████╗     ██╗
    ██╔══██╗    ██║
    ██║  ██║    ██║
    ██║  ██║██   ██║
    ╚██████╔╝╚█████╔╝
     ╚═════╝  ╚════╝
    FISH IT! | KEY SYSTEM
    Author : CJ
    Build  : v3.0
--]]

--============================================================
-- KEY CONFIG
--============================================================
-- Cara pakai:
-- 1. Buka https://azam-key-generator.vercel.app/
-- 2. Nonton 3 iklan → dapet key XXXX-XXXX-XXXX-XXXX
-- 3. Copy key
-- 4. Ganti "PASTE_KEY_DISINI" di bawah
-- 5. Execute script

local USER_KEY = "PASTE_KEY_DISINI"

--============================================================
-- KEY VALIDATION
--============================================================
local ValidKeyPattern = "^[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$"

local function notifyKey(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = text, Duration = 6,
        })
    end)
end

local function validateKey(key)
    if not key or key == "" or key == "PASTE_KEY_DISINI" then
        return false, "❌ Key belum diisi!"
    end
    if not string.match(key, ValidKeyPattern) then
        return false, "❌ Format key salah! Contoh: ABCD-1234-EFGH-5678"
    end
    return true, "✅ Key valid!"
end

local valid, msg = validateKey(USER_KEY)

if not valid then
    notifyKey("AZAM FISH IT", msg)
    warn("============================================")
    warn("[AZAM] KEY VALIDATION FAILED")
    warn("[AZAM] " .. msg)
    warn("[AZAM] Ambil key di:")
    warn("[AZAM] https://azam-key-generator.vercel.app/")
    warn("============================================")
    return
end

notifyKey("AZAM FISH IT", "✅ Key valid! Loading script...")

--============================================================
-- SERVICES
--============================================================
local VirtualUser       = game:GetService("VirtualUser")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

--============================================================
-- CONFIG
--============================================================
local Config = {
    -- Fishing
    AutoCast        = false,
    AutoReel        = false,
    FastMode        = false,
    ClickDelay      = 0.15,
    FastDelay       = 0.05,
    ReelSpeed       = 0.10,
    HoldDuration    = 0.04,
    TapX            = 0.5,
    TapY            = 0.5,

    -- Anti-Detect
    AntiDetect      = true,
    RandomizeDelay  = true,
    HumanizeMove    = true,
    BehaviorMode    = true,
    SessionLimit    = 45,
    CooldownEvery   = 15,
    CooldownTime    = 30,

    -- Auto Break
    AutoBreak       = true,
    BreakEvery      = 10,
    BreakMin        = 60,
    BreakMax        = 180,

    -- Anti AFK
    AntiAFK         = true,

    -- Stats
    StartTime       = os.time(),
    LastBreak       = os.time(),
    LastAutoBreak   = os.time(),
    TotalCasts      = 0,
    TotalBreaks     = 0,
}

local State = {
    Running         = true,
    InCooldown      = false,
    InAutoBreak     = false,
    SessionMinutes  = 0,
}

--============================================================
-- HELPER
--============================================================
local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 3,
        })
    end)
end

local function randFloat(a, b)
    return a + math.random() * (b - a)
end

--============================================================
-- TAP
--============================================================
local function tap()
    local viewport = Camera.ViewportSize

    local offsetX = Config.HumanizeMove and randFloat(-0.02, 0.02) or 0
    local offsetY = Config.HumanizeMove and randFloat(-0.02, 0.02) or 0

    local holdTime = Config.HoldDuration
    if Config.BehaviorMode then
        holdTime = randFloat(0.02, 0.09)
    end

    local pos = Vector2.new(
        viewport.X * (Config.TapX + offsetX),
        viewport.Y * (Config.TapY + offsetY)
    )

    pcall(function()
        VirtualUser:Button1Down(pos)
        task.wait(holdTime)
        VirtualUser:Button1Up(pos)
    end)

    Config.TotalCasts = Config.TotalCasts + 1
end

--============================================================
-- DELAY
--============================================================
local function getDelay(mode)
    local base
    if mode == "reel" then
        base = Config.ReelSpeed
    elseif Config.FastMode then
        base = Config.FastDelay
    else
        base = Config.ClickDelay
    end

    if Config.AntiDetect and Config.RandomizeDelay then
        base = base * randFloat(0.6, 1.4)
    end

    if Config.BehaviorMode then
        local rand = math.random(1, 100)
        if rand <= 5 then
            base = base + randFloat(1, 3)
        elseif rand <= 15 then
            base = base + randFloat(0.3, 0.8)
        end
    end

    return base
end

--============================================================
-- ANTI-DETECT
--============================================================
local function checkSession()
    local elapsed = (os.time() - Config.StartTime) / 60
    State.SessionMinutes = elapsed

    if Config.AntiDetect and elapsed >= Config.SessionLimit then
        Config.AutoCast = false
        Config.AutoReel = false
        notify("Anti-Detect", "⏰ Session limit. Istirahat dulu.", 5)
        return false
    end

    if Config.AntiDetect then
        local sinceBreak = (os.time() - Config.LastBreak) / 60
        if sinceBreak >= Config.CooldownEvery and not State.InCooldown then
            State.InCooldown = true
            notify("Anti-Detect", "☕ Cooldown " .. Config.CooldownTime .. "s...", 3)

            task.spawn(function()
                task.wait(Config.CooldownTime)
                State.InCooldown = false
                Config.LastBreak = os.time()
                notify("Anti-Detect", "✅ Cooldown selesai.", 2)
            end)
        end
    end

    return true
end

--============================================================
-- AUTO BREAK
--============================================================
local function checkAutoBreak()
    if not Config.AutoBreak then return true end

    local sinceBreak = (os.time() - Config.LastAutoBreak) / 60

    if sinceBreak >= Config.BreakEvery and not State.InAutoBreak then
        State.InAutoBreak = true
        Config.TotalBreaks = Config.TotalBreaks + 1

        local breakTime = randFloat(Config.BreakMin, Config.BreakMax)
        notify("Auto Break", "😴 Istirahat " .. math.floor(breakTime) .. "s...", 3)

        local wasCast = Config.AutoCast
        local wasReel = Config.AutoReel
        Config.AutoCast = false
        Config.AutoReel = false

        task.spawn(function()
            task.wait(breakTime)
            State.InAutoBreak = false
            Config.LastAutoBreak = os.time()
            Config.AutoCast = wasCast
            Config.AutoReel = wasReel
            notify("Auto Break", "✅ Bangun. Lanjut.", 2)
        end)

        return false
    end

    return true
end

--============================================================
-- AUTO CAST LOOP
--============================================================
task.spawn(function()
    while State.Running do
        if Config.AutoCast and not State.InCooldown and not State.InAutoBreak then
            if checkSession() and checkAutoBreak() then
                tap()
                task.wait(getDelay("cast"))
            else
                task.wait(1)
            end
        else
            task.wait(0.1)
        end
    end
end)

--============================================================
-- AUTO REEL LOOP
--============================================================
task.spawn(function()
    while State.Running do
        if Config.AutoReel and not State.InCooldown and not State.InAutoBreak then
            tap()
            task.wait(getDelay("reel"))
        else
            task.wait(0.1)
        end
    end
end)

--============================================================
-- ANTI AFK
--============================================================
if Config.AntiAFK then
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0))
            task.wait(randFloat(0.8, 1.5))
            VirtualUser:Button2Up(Vector2.new(0, 0))
        end)
    end)
end

--============================================================
-- RESPAWN RESET
--============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(2)
    Config.StartTime = os.time()
    Config.LastBreak = os.time()
    Config.LastAutoBreak = os.time()
    Config.TotalCasts = 0
    Config.TotalBreaks = 0
end)

--============================================================
-- UI
--============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CJ_FishIt_v3"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 270, 0, 520)
Main.Position = UDim2.new(0, 20, 0, 80)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local MC = Instance.new("UICorner")
MC.CornerRadius = UDim.new(0, 10)
MC.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Title.BorderSizePixel = 0
Title.Text = "🎣 FISH IT | CJ v3.0"
Title.TextColor3 = Color3.fromRGB(255, 215, 0)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.Parent = Main

local TC = Instance.new("UICorner")
TC.CornerRadius = UDim.new(0, 10)
TC.Parent = Title

local KeyLbl = Instance.new("TextLabel")
KeyLbl.Size = UDim2.new(0, 60, 0, 32)
KeyLbl.Position = UDim2.new(1, -66, 0, 4)
KeyLbl.BackgroundColor3 = Color3.fromRGB(20, 60, 40)
KeyLbl.BorderSizePixel = 0
KeyLbl.Text = "🔑 OK"
KeyLbl.TextColor3 = Color3.fromRGB(0, 255, 136)
KeyLbl.TextSize = 11
KeyLbl.Font = Enum.Font.GothamBold
KeyLbl.Parent = Title

local KC = Instance.new("UICorner")
KC.CornerRadius = UDim.new(0, 6)
KC.Parent = KeyLbl

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 1, -60)
Scroll.Position = UDim2.new(0, 10, 0, 50)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 5)
Layout.Parent = Scroll

local function makeSection(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = "── " .. text .. " ──"
    lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Scroll
end

local function makeToggle(text, key, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 32)
    btn.BackgroundColor3 = Config[key] and Color3.fromRGB(40, 90, 60) or Color3.fromRGB(30, 30, 40)
    btn.BorderSizePixel = 0
    btn.Text = "  " .. text .. " : " .. tostring(Config[key])
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = Scroll

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    btn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        btn.Text = "  " .. text .. " : " .. tostring(Config[key])
        btn.BackgroundColor3 = Config[key]
            and Color3.fromRGB(40, 90, 60)
            or Color3.fromRGB(30, 30, 40)
        if callback then callback(Config[key]) end
    end)
end

local function makeSlider(text, key, min, max)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -10, 0, 46)
    holder.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    holder.BorderSizePixel = 0
    holder.Parent = Scroll

    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(0, 6)
    hc.Parent = holder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 18)
    label.Position = UDim2.new(0, 5, 0, 2)
    label.BackgroundTransparency = 1
    label.Text = text .. " : " .. tostring(Config[key])
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = holder

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 8)
    bar.Position = UDim2.new(0, 10, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    bar.BorderSizePixel = 0
    bar.Parent = holder

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 4)
    bc.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((Config[key] - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    fill.BorderSizePixel = 0
    fill.Parent = bar

    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 4)
    fc.Parent = fill

    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            local val = math.floor(min + (max - min) * rel)
            Config[key] = val
            label.Text = text .. " : " .. tostring(val)
        end
    end)
end

local function makeInfo(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 22)
    lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    lbl.BorderSizePixel = 0
    lbl.Text = "  " .. text
    lbl.TextColor3 = Color3.fromRGB(150, 220, 255)
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Scroll

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = lbl

    return lbl
end

-- BUILD UI
makeSection("⚡ FISHING")
makeToggle("Auto Cast", "AutoCast")
makeToggle("Auto Reel", "AutoReel")
makeToggle("⚡ Fast Mode", "FastMode")
makeSlider("Cast Speed (ms x100)", "ClickDelay", 5, 50)
makeSlider("Reel Speed (ms x100)", "ReelSpeed", 2, 50)
makeSlider("Fast Delay (ms x100)", "FastDelay", 2, 20)

makeSection("🛡️ ANTI-DETECT")
makeToggle("Anti Detect", "AntiDetect")
makeToggle("Randomize Delay", "RandomizeDelay")
makeToggle("Humanize Tap", "HumanizeMove")
makeToggle("🧠 Behavior Mode", "BehaviorMode")
makeToggle("Anti AFK", "AntiAFK")
makeSlider("Session Limit (mnt)", "SessionLimit", 5, 120)
makeSlider("Cooldown Every (mnt)", "CooldownEvery", 5, 60)

makeSection("😴 AUTO BREAK")
makeToggle("Auto Break", "AutoBreak")
makeSlider("Break Every (mnt)", "BreakEvery", 5, 60)
makeSlider("Break Min (s)", "BreakMin", 30, 300)
makeSlider("Break Max (s)", "BreakMax", 60, 600)

makeSection("📊 STATS")
local statLbl   = makeInfo("Casts : 0")
local timeLbl   = makeInfo("Session : 0m")
local breakLbl  = makeInfo("Breaks : 0")

task.spawn(function()
    while State.Running do
        pcall(function()
            statLbl.Text    = "  Casts : " .. Config.TotalCasts
            timeLbl.Text    = "  Session : " .. math.floor(State.SessionMinutes) .. "m"
            breakLbl.Text   = "  Breaks : " .. Config.TotalBreaks
        end)
        task.wait(2)
    end
end)

--============================================================
-- START
--============================================================
notify("Fish It! CJ v3.0", "🔑 Key valid! Script loaded. Gas.", 4)
