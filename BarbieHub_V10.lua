--// BARBIE HUB V10
--// FOR YOUR OWN ROBLOX GAME / ROBLOX STUDIO
--// Put this LocalScript in StarterPlayer > StarterPlayerScripts.
--
--// V10:
--// • Compact Barbie UI
--// • Stronger Silent Aim for your OWN weapon system
--// • FOV, sticky target, team check, hit-part selection and prediction
--// • Red target highlight + target line
--// • Player ESP names / health / distance
--// • Player target selector, spectate and teleport helpers
--// • Camlock with a true locked target
--// • Teleport: ON -> T -> left click -> teleport
--// • Real local speed macro with editable speed
--// • Barbie lighting presets
--// • Custom keybinds
--// • Clean respawn handling
--
--// IMPORTANT:
--// Roblox does not let a LocalScript globally replace the built-in Mouse.Hit
--// property for every arbitrary weapon. For your own weapon, use:
--//     _G.BarbieHubGetAimPosition()
--// when calculating the shot position.
--// This keeps the system reliable instead of pretending an arbitrary weapon
--// can be intercepted by a GUI alone.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Mouse = LocalPlayer:GetMouse()

--==================================================
-- COLORS
--==================================================

local C = {
    Pink = Color3.fromRGB(239, 61, 142),
    Pink2 = Color3.fromRGB(255, 112, 177),
    Pale = Color3.fromRGB(255, 226, 240),
    Pale2 = Color3.fromRGB(255, 241, 248),
    White = Color3.fromRGB(255, 255, 255),
    Text = Color3.fromRGB(105, 35, 70),
    Muted = Color3.fromRGB(170, 100, 137),
    Border = Color3.fromRGB(245, 165, 205),
    Red = Color3.fromRGB(255, 48, 63),
    Green = Color3.fromRGB(65, 190, 119),
}

--==================================================
-- STATE
--==================================================

local State = {
    SilentAim = false,
    Camlock = false,
    Teleport = false,
    Macro = false,
    ESP = false,
    ESPHealth = true,
    ESPDistance = true,

    VisibleCheck = true,
    Highlight = true,
    TargetLine = false,
    TeamCheck = false,
    StickyAim = false,
    Prediction = true,

    FOV = 220,
    Smoothness = 0.18,
    PredictionAmount = 0.08,
    MaxDistance = 2000,
    TargetPart = "Head",
    MacroDelay = 0.04,
}

local Binds = {
    SilentAim = Enum.KeyCode.Q,
    Camlock = Enum.KeyCode.E,
    Teleport = Enum.KeyCode.T,
    Macro = Enum.KeyCode.G,
}

local SelectedTarget = nil
local LockedTarget = nil
local TeleportArmed = false
local WaitingBind = nil
local TargetHighlight = nil
local SavedWalkSpeed = 16
local TargetLine = nil
local MacroPulse = false

local Camera = workspace.CurrentCamera

local function GetHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

--==================================================
-- GUI HELPERS
--==================================================

local Gui = Instance.new("ScreenGui")
Gui.Name = "BarbieHubV7"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local function Corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = obj
    return c
end

local function Stroke(obj, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.Border
    s.Thickness = thickness or 1
    s.Transparency = 0
    s.Parent = obj
    return s
end

local function Label(parent, value, size, position, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = value
    l.TextSize = size or 12
    l.Font = font or Enum.Font.Gotham
    l.TextColor3 = color or C.Text
    l.Position = position or UDim2.new()
    l.Size = UDim2.new(1, 0, 0, 22)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function Button(parent, value, size, position)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = false
    b.Text = value
    b.TextSize = 11
    b.Font = Enum.Font.GothamMedium
    b.TextColor3 = C.Text
    b.BackgroundColor3 = C.White
    b.Size = size
    b.Position = position
    b.Parent = parent
    Corner(b, 9)
    Stroke(b)

    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {
            BackgroundColor3 = C.Pale
        }):Play()
    end)

    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {
            BackgroundColor3 = C.White
        }):Play()
    end)

    return b
end

local function Card(parent, y, height)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = C.White
    f.Size = UDim2.new(1, -20, 0, height)
    f.Position = UDim2.fromOffset(10, y)
    f.Parent = parent
    Corner(f, 11)
    Stroke(f)
    return f
end

--==================================================
-- MAIN WINDOW
--==================================================

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(650, 430)
Main.Position = UDim2.new(0.5, -325, 0.5, -215)
Main.BackgroundColor3 = C.Pale2
Main.Parent = Gui
Corner(Main, 18)
Stroke(Main, C.Pink, 2)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 68)
Header.BackgroundColor3 = C.White
Header.Parent = Main
Corner(Header, 18)

Label(
    Header,
    "BARBIE",
    24,
    UDim2.fromOffset(22, 10),
    C.Pink,
    Enum.Font.GothamBlack
)

Label(
    Header,
    "PINK COLLECTION",
    9,
    UDim2.fromOffset(24, 39),
    C.Muted,
    Enum.Font.GothamBold
)

local Close = Button(
    Header,
    "X",
    UDim2.fromOffset(34, 32),
    UDim2.new(1, -46, 0.5, -16)
)
Close.TextColor3 = C.Pink

local Reopen = Button(
    Gui,
    "B",
    UDim2.fromOffset(38, 38),
    UDim2.new(0, 15, 1, -54)
)
Reopen.BackgroundColor3 = C.Pink
Reopen.TextColor3 = C.White
Reopen.Visible = false

Close.MouseButton1Click:Connect(function()
    Gui.Enabled = false
    Reopen.Visible = true
end)

Reopen.MouseButton1Click:Connect(function()
    Gui.Enabled = true
    Reopen.Visible = false
end)

--==================================================
-- SIDEBAR
--==================================================

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.fromOffset(150, 346)
Sidebar.Position = UDim2.fromOffset(12, 75)
Sidebar.BackgroundColor3 = C.Pale
Sidebar.Parent = Main
Corner(Sidebar, 14)
Stroke(Sidebar)

Label(
    Sidebar,
    "MENU",
    9,
    UDim2.fromOffset(14, 9),
    C.Muted,
    Enum.Font.GothamBold
)

local Tabs = {
    "Home",
    "Silent Aim",
    "Camlock",
    "Teleport",
    "Fake Macro",
    "ESP",
    "Fog & Sky",
    "Settings",
}

local Pages = {}
local TabButtons = {}

for i, name in ipairs(Tabs) do
    local b = Button(
        Sidebar,
        name:upper(),
        UDim2.new(1, -18, 0, 31),
        UDim2.fromOffset(9, 31 + ((i - 1) * 38))
    )

    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Text = "   " .. name:upper()

    TabButtons[name] = b

    local p = Instance.new("ScrollingFrame")
    p.Name = name
    p.Size = UDim2.new(1, -174, 1, -80)
    p.Position = UDim2.fromOffset(162, 74)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = C.Pink
    p.CanvasSize = UDim2.new()
    p.Visible = false
    p.Parent = Main

    Pages[name] = p

    b.MouseButton1Click:Connect(function()
        for tab, page in pairs(Pages) do
            page.Visible = tab == name
        end

        for tab, tabButton in pairs(TabButtons) do
            if tab == name then
                tabButton.BackgroundColor3 = C.White
                tabButton.TextColor3 = C.Pink
            else
                tabButton.BackgroundColor3 = C.Pale
                tabButton.TextColor3 = C.Text
            end
        end
    end)
end

--==================================================
-- TOGGLE / KEYBIND
--==================================================

local function MakeToggle(parent, title, description, y, key)
    local c = Card(parent, y, 58)

    Label(
        c,
        title,
        13,
        UDim2.fromOffset(13, 7),
        C.Text,
        Enum.Font.GothamBold
    )

    Label(
        c,
        description,
        9,
        UDim2.fromOffset(13, 28),
        C.Muted,
        Enum.Font.Gotham
    )

    local sw = Instance.new("TextButton")
    sw.Text = ""
    sw.AutoButtonColor = false
    sw.Size = UDim2.fromOffset(46, 23)
    sw.Position = UDim2.new(1, -59, 0.5, -11)
    sw.BackgroundColor3 = C.Pale
    sw.Parent = c
    Corner(sw, 12)
    Stroke(sw)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(17, 17)
    knob.Position = UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = C.White
    knob.Parent = sw
    Corner(knob, 10)

    local function Refresh()
        if State[key] then
            sw.BackgroundColor3 = C.Pink
            knob.Position = UDim2.new(1, -20, 0, 3)
        else
            sw.BackgroundColor3 = C.Pale
            knob.Position = UDim2.fromOffset(3, 3)
        end
    end

    sw.MouseButton1Click:Connect(function()
        State[key] = not State[key]

        if key == "Teleport" and not State.Teleport then
            TeleportArmed = false
        end

        if key == "Camlock" then
            if State.Camlock then
                RefreshTarget()
                LockedTarget = SelectedTarget
                if not LockedTarget then
                    State.Camlock = false
                end
            else
                LockedTarget = nil
            end
        elseif key == "Macro" then
            local humanoid = GetHumanoid and GetHumanoid() or nil

            if State.Macro then
                if humanoid then
                    SavedWalkSpeed = humanoid.WalkSpeed
                end
            elseif humanoid then
                humanoid.WalkSpeed = SavedWalkSpeed
            end
        end

        Refresh()
    end)

    Refresh()
end

local function MakeBind(parent, title, description, y, key)
    local c = Card(parent, y, 58)

    Label(
        c,
        title,
        13,
        UDim2.fromOffset(13, 7),
        C.Text,
        Enum.Font.GothamBold
    )

    Label(
        c,
        description,
        9,
        UDim2.fromOffset(13, 28),
        C.Muted,
        Enum.Font.Gotham
    )

    local b = Button(
        c,
        Binds[key].Name,
        UDim2.fromOffset(76, 33),
        UDim2.new(1, -90, 0.5, -16)
    )

    b.MouseButton1Click:Connect(function()
        WaitingBind = key
        b.Text = "PRESS KEY"

        task.delay(5, function()
            if WaitingBind == key then
                WaitingBind = nil
                b.Text = Binds[key].Name
            end
        end)
    end)
end

--==================================================
-- HOME
--==================================================

local Home = Pages.Home

local HomeCard = Card(Home, 10, 125)

Label(
    HomeCard,
    "BARBIE HUB",
    21,
    UDim2.fromOffset(16, 13),
    C.Pink,
    Enum.Font.GothamBlack
)

Label(
    HomeCard,
    "compact controls for your own game",
    10,
    UDim2.fromOffset(17, 45),
    C.Muted
)

Label(
    HomeCard,
    "Q AIM  •  E LOCK  •  T TELEPORT  •  G SPEED",
    9,
    UDim2.fromOffset(17, 70),
    C.Text,
    Enum.Font.GothamBold
)

Label(
    HomeCard,
    "Silent Aim redirects YOUR weapon's aim position without moving the cursor.",
    9,
    UDim2.fromOffset(17, 88),
    C.Muted
)

local StatusLabel = Label(
    HomeCard,
    "READY",
    9,
    UDim2.new(1, -90, 0, 17),
    C.Green,
    Enum.Font.GothamBold
)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Right

--==================================================
-- SILENT AIM FOV CIRCLE
--==================================================

local FOVCircle = Instance.new("Frame")
FOVCircle.Name = "SilentAimFOV"
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Size = UDim2.fromOffset(State.FOV * 2, State.FOV * 2)
FOVCircle.ZIndex = 50
FOVCircle.Visible = false
FOVCircle.Parent = Gui
Corner(FOVCircle, State.FOV)

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Color = C.Pink
FOVStroke.Thickness = 1
FOVStroke.Transparency = 0.15
FOVStroke.Parent = FOVCircle

--==================================================
-- SILENT AIM
--==================================================

local Aim = Pages["Silent Aim"]

Label(
    Aim,
    "SILENT AIM",
    19,
    UDim2.fromOffset(10, 7),
    C.Pink,
    Enum.Font.GothamBlack
)

Label(
    Aim,
    "Mouse-nearest target selection inside your FOV.",
    9,
    UDim2.fromOffset(10, 32),
    C.Muted
)

MakeToggle(
    Aim,
    "Enable Silent Aim",
    "Uses the selected target through your own weapon system.",
    56,
    "SilentAim"
)

MakeBind(
    Aim,
    "Keybind",
    "Default Q.",
    122,
    "SilentAim"
)

MakeToggle(
    Aim,
    "Visible Check",
    "Ignore players hidden behind map geometry.",
    188,
    "VisibleCheck"
)

MakeToggle(
    Aim,
    "Red Target Highlight",
    "Show the current selected target.",
    254,
    "Highlight"
)

MakeToggle(
    Aim,
    "Target Line",
    "Draw a line from the cursor to the target.",
    320,
    "TargetLine"
)

MakeToggle(
    Aim,
    "Sticky Target",
    "Keep the same target until they become invalid.",
    386,
    "StickyAim"
)

MakeToggle(
    Aim,
    "Team Check",
    "Ignore players on the same Roblox team.",
    452,
    "TeamCheck"
)

MakeToggle(
    Aim,
    "Prediction",
    "Lead moving targets using their current velocity.",
    518,
    "Prediction"
)

local FOVCard = Card(Aim, 584, 72)

Label(
    FOVCard,
    "FOV",
    13,
    UDim2.fromOffset(13, 8),
    C.Text,
    Enum.Font.GothamBold
)

local FOVValue = Label(
    FOVCard,
    tostring(State.FOV),
    13,
    UDim2.fromOffset(13, 31),
    C.Pink,
    Enum.Font.GothamBold
)

local FOVMinus = Button(
    FOVCard,
    "-",
    UDim2.fromOffset(34, 30),
    UDim2.new(1, -86, 0.5, -15)
)

local FOVPlus = Button(
    FOVCard,
    "+",
    UDim2.fromOffset(34, 30),
    UDim2.new(1, -45, 0.5, -15)
)

local function RefreshFOV()
    State.FOV = math.clamp(math.floor(State.FOV), 40, 600)
    FOVValue.Text = tostring(State.FOV)
    FOVCircle.Size = UDim2.fromOffset(State.FOV * 2, State.FOV * 2)
end

FOVMinus.MouseButton1Click:Connect(function()
    State.FOV -= 10
    RefreshFOV()
end)

FOVPlus.MouseButton1Click:Connect(function()
    State.FOV += 10
    RefreshFOV()
end)

local AimOptions = Card(Aim, 666, 130)

Label(
    AimOptions,
    "AIM OPTIONS",
    12,
    UDim2.fromOffset(13, 8),
    C.Text,
    Enum.Font.GothamBold
)

local PartButton = Button(
    AimOptions,
    "PART: " .. State.TargetPart,
    UDim2.fromOffset(125, 30),
    UDim2.fromOffset(13, 34)
)

PartButton.MouseButton1Click:Connect(function()
    if State.TargetPart == "Head" then
        State.TargetPart = "UpperTorso"
    elseif State.TargetPart == "UpperTorso" then
        State.TargetPart = "HumanoidRootPart"
    else
        State.TargetPart = "Head"
    end

    PartButton.Text = "PART: " .. State.TargetPart
end)

local PredMinus = Button(
    AimOptions,
    "-",
    UDim2.fromOffset(30, 30),
    UDim2.fromOffset(153, 34)
)

local PredPlus = Button(
    AimOptions,
    "+",
    UDim2.fromOffset(30, 30),
    UDim2.fromOffset(188, 34)
)

local PredValue = Label(
    AimOptions,
    string.format("LEAD %.2f", State.PredictionAmount),
    10,
    UDim2.fromOffset(13, 70),
    C.Muted,
    Enum.Font.GothamBold
)

local MaxDistanceLabel = Label(
    AimOptions,
    "MAX DISTANCE " .. State.MaxDistance,
    10,
    UDim2.fromOffset(13, 94),
    C.Muted,
    Enum.Font.GothamBold
)

PredMinus.MouseButton1Click:Connect(function()
    State.PredictionAmount = math.max(0, State.PredictionAmount - 0.01)
    PredValue.Text = string.format("LEAD %.2f", State.PredictionAmount)
end)

PredPlus.MouseButton1Click:Connect(function()
    State.PredictionAmount = math.min(1, State.PredictionAmount + 0.01)
    PredValue.Text = string.format("LEAD %.2f", State.PredictionAmount)
end)

Aim.CanvasSize = UDim2.fromOffset(0, 815)

--==================================================
-- CAMLOCK
--==================================================

local Camlock = Pages.Camlock

Label(
    Camlock,
    "CAMLOCK",
    19,
    UDim2.fromOffset(10, 7),
    C.Pink,
    Enum.Font.GothamBlack
)

Label(
    Camlock,
    "Smoothly follow the same mouse-selected target.",
    9,
    UDim2.fromOffset(10, 32),
    C.Muted
)

MakeToggle(
    Camlock,
    "Enable Camlock",
    "Camera follows the selected target.",
    56,
    "Camlock"
)

MakeBind(
    Camlock,
    "Keybind",
    "Default E.",
    122,
    "Camlock"
)

local TargetCard = Card(Camlock, 188, 74)

Label(
    TargetCard,
    "CURRENT TARGET",
    9,
    UDim2.fromOffset(13, 9),
    C.Muted,
    Enum.Font.GothamBold
)

local TargetName = Label(
    TargetCard,
    "None",
    14,
    UDim2.fromOffset(13, 31),
    C.Pink,
    Enum.Font.GothamBold
)

--==================================================
-- TELEPORT
--==================================================

local Teleport = Pages.Teleport

Label(
    Teleport,
    "TELEPORT",
    19,
    UDim2.fromOffset(10, 7),
    C.Pink,
    Enum.Font.GothamBlack
)

Label(
    Teleport,
    "Enable → press T → left click a location.",
    9,
    UDim2.fromOffset(10, 32),
    C.Muted
)

MakeToggle(
    Teleport,
    "Enable Teleport",
    "Teleport will not react to clicks while disabled.",
    56,
    "Teleport"
)

MakeBind(
    Teleport,
    "Arm Keybind",
    "Default T.",
    122,
    "Teleport"
)

local TeleportCard = Card(Teleport, 188, 88)

Label(
    TeleportCard,
    "STATUS",
    9,
    UDim2.fromOffset(13, 10),
    C.Muted,
    Enum.Font.GothamBold
)

local TeleportStatus = Label(
    TeleportCard,
    "NOT ARMED",
    14,
    UDim2.fromOffset(13, 33),
    C.Muted,
    Enum.Font.GothamBold
)

Label(
    TeleportCard,
    "Left click is ignored until T arms it.",
    9,
    UDim2.fromOffset(13, 61),
    C.Muted
)

--==================================================
-- SPEED MACRO
--==================================================

local Macro = Pages["Fake Macro"]

Label(
    Macro,
    "SPEED MACRO",
    19,
    UDim2.fromOffset(10, 7),
    C.Pink,
    Enum.Font.GothamBlack
)

Label(
    Macro,
    "Hold your chosen speed value while the macro is enabled.",
    9,
    UDim2.fromOffset(10, 32),
    C.Muted
)

MakeToggle(
    Macro,
    "Enable Speed Macro",
    "Sets your own character's WalkSpeed to the selected value.",
    56,
    "Macro"
)

MakeBind(
    Macro,
    "Keybind",
    "Default G. Tap it to toggle the speed macro.",
    122,
    "Macro"
)

local SpeedCard = Card(Macro, 188, 100)

Label(
    SpeedCard,
    "SPEED",
    9,
    UDim2.fromOffset(13, 9),
    C.Muted,
    Enum.Font.GothamBold
)

local SpeedValue = Label(
    SpeedCard,
    "100",
    16,
    UDim2.fromOffset(13, 30),
    C.Pink,
    Enum.Font.GothamBlack
)

local Minus = Button(
    SpeedCard,
    "-",
    UDim2.fromOffset(34, 30),
    UDim2.new(1, -115, 0.5, -15)
)

local Plus = Button(
    SpeedCard,
    "+",
    UDim2.fromOffset(34, 30),
    UDim2.new(1, -72, 0.5, -15)
)

local SpeedBox = Instance.new("TextBox")
SpeedBox.ClearTextOnFocus = false
SpeedBox.Text = "100"
SpeedBox.PlaceholderText = "speed"
SpeedBox.TextSize = 12
SpeedBox.Font = Enum.Font.GothamBold
SpeedBox.TextColor3 = C.Pink
SpeedBox.BackgroundColor3 = C.Pale2
SpeedBox.Size = UDim2.fromOffset(62, 30)
SpeedBox.Position = UDim2.new(1, -184, 0.5, -15)
SpeedBox.Parent = SpeedCard
Corner(SpeedBox, 8)
Stroke(SpeedBox)

local Speed = 100

local function RefreshSpeed()
    Speed = math.clamp(math.floor(Speed), 16, 500)
    SpeedValue.Text = tostring(Speed)
    SpeedBox.Text = tostring(Speed)
end

SpeedBox.FocusLost:Connect(function()
    local number = tonumber(SpeedBox.Text)
    if number then
        Speed = number
    end
    RefreshSpeed()
    ApplySpeed()
end)

Minus.MouseButton1Click:Connect(function()
    Speed -= 5
    RefreshSpeed()
end)

Plus.MouseButton1Click:Connect(function()
    Speed += 5
    RefreshSpeed()
end)

local SpeedHint = Label(
    SpeedCard,
    "16–500 • customize with + / -",
    9,
    UDim2.fromOffset(13, 68),
    C.Muted
)

local function ApplySpeed()
    local humanoid = GetHumanoid()
    if not humanoid then
        return
    end

    if State.Macro then
        if humanoid.WalkSpeed ~= Speed then
            humanoid.WalkSpeed = Speed
        end
    else
        humanoid.WalkSpeed = SavedWalkSpeed
    end
end

--==================================================
-- FOG & SKY
--==================================================

local Fog = Pages["Fog & Sky"]

Label(
    Fog,
    "FOG & SKY",
    19,
    UDim2.fromOffset(10, 7),
    C.Pink,
    Enum.Font.GothamBlack
)

Label(
    Fog,
    "Barbie atmosphere presets.",
    9,
    UDim2.fromOffset(10, 32),
    C.Muted
)

local OriginalLighting = {
    ClockTime = Lighting.ClockTime,
    Brightness = Lighting.Brightness,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
}

local function ApplyAtmosphere(name)
    local atmosphere = Lighting:FindFirstChild("BarbieHubAtmosphere")

    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Name = "BarbieHubAtmosphere"
        atmosphere.Parent = Lighting
    end

    if name == "BARBIE DAY" then
        Lighting.ClockTime = 14
        Lighting.Brightness = 2
        atmosphere.Color = Color3.fromRGB(255, 190, 220)
        atmosphere.Decay = Color3.fromRGB(255, 155, 205)
        atmosphere.Density = 0.20
        atmosphere.Haze = 0.45
        atmosphere.Glare = 0.05

    elseif name == "PINK NIGHT" then
        Lighting.ClockTime = 22
        Lighting.Brightness = 1
        atmosphere.Color = Color3.fromRGB(255, 100, 180)
        atmosphere.Decay = Color3.fromRGB(95, 30, 85)
        atmosphere.Density = 0.34
        atmosphere.Haze = 0.9
        atmosphere.Glare = 0.12

    elseif name == "SOFT PINK" then
        Lighting.ClockTime = 18
        Lighting.Brightness = 2
        atmosphere.Color = Color3.fromRGB(255, 215, 232)
        atmosphere.Decay = Color3.fromRGB(245, 150, 195)
        atmosphere.Density = 0.16
        atmosphere.Haze = 0.35
        atmosphere.Glare = 0.03

    elseif name == "RESET" then
        Lighting.ClockTime = OriginalLighting.ClockTime
        Lighting.Brightness = OriginalLighting.Brightness
        Lighting.FogEnd = OriginalLighting.FogEnd
        Lighting.FogStart = OriginalLighting.FogStart

        if atmosphere then
            atmosphere:Destroy()
        end
    end
end

for i, preset in ipairs({
    "BARBIE DAY",
    "PINK NIGHT",
    "SOFT PINK",
    "RESET",
}) do
    local b = Button(
        Fog,
        preset,
        UDim2.new(1, -20, 0, 40),
        UDim2.fromOffset(10, 56 + ((i - 1) * 47))
    )

    b.MouseButton1Click:Connect(function()
        ApplyAtmosphere(preset)
    end)
end

--==================================================
-- ESP
--==================================================

local ESP = Pages.ESP

Label(
    ESP,
    "PLAYER ESP",
    19,
    UDim2.fromOffset(10, 7),
    C.Pink,
    Enum.Font.GothamBlack
)

Label(
    ESP,
    "Lightweight player labels for your own game.",
    9,
    UDim2.fromOffset(10, 32),
    C.Muted
)

MakeToggle(
    ESP,
    "Player ESP",
    "Show player names, health and distance.",
    56,
    "ESP"
)

MakeToggle(
    ESP,
    "ESP Health",
    "Show current humanoid health.",
    122,
    "ESPHealth"
)

MakeToggle(
    ESP,
    "ESP Distance",
    "Show distance from your character.",
    188,
    "ESPDistance"
)

local PlayerListCard = Card(ESP, 254, 260)

Label(
    PlayerListCard,
    "PLAYERS",
    10,
    UDim2.fromOffset(13, 8),
    C.Muted,
    Enum.Font.GothamBold
)

local PlayerList = Instance.new("ScrollingFrame")
PlayerList.BackgroundTransparency = 1
PlayerList.BorderSizePixel = 0
PlayerList.Position = UDim2.fromOffset(10, 31)
PlayerList.Size = UDim2.new(1, -20, 1, -41)
PlayerList.ScrollBarThickness = 3
PlayerList.ScrollBarImageColor3 = C.Pink
PlayerList.CanvasSize = UDim2.new()
PlayerList.Parent = PlayerListCard

local function RefreshPlayerList()
    for _, child in ipairs(PlayerList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local y = 0

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local b = Button(
                PlayerList,
                plr.Name,
                UDim2.new(1, -4, 0, 31),
                UDim2.fromOffset(0, y)
            )

            b.MouseButton1Click:Connect(function()
                SelectedTarget = plr
                TargetName.Text = plr.Name
                ApplyTargetHighlight()
            end)

            y += 35
        end
    end

    PlayerList.CanvasSize = UDim2.fromOffset(0, y)
end

task.spawn(function()
    while Gui.Parent do
        RefreshPlayerList()
        task.wait(2)
    end
end)

ESP.CanvasSize = UDim2.fromOffset(0, 535)

--==================================================
-- SETTINGS
--==================================================

local Settings = Pages.Settings

Label(
    Settings,
    "SETTINGS",
    19,
    UDim2.fromOffset(10, 7),
    C.Pink,
    Enum.Font.GothamBlack
)

Label(
    Settings,
    "Reset local Barbie Hub features.",
    9,
    UDim2.fromOffset(10, 32),
    C.Muted
)

local ResetButton = Button(
    Settings,
    "RESET FEATURES",
    UDim2.new(1, -20, 0, 42),
    UDim2.fromOffset(10, 56)
)

ResetButton.MouseButton1Click:Connect(function()
    State.SilentAim = false
    State.Camlock = false
    State.Teleport = false
    State.Macro = false
    State.StickyAim = false
    State.TeamCheck = false
    State.Prediction = true

    TeleportArmed = false
    SelectedTarget = nil
    LockedTarget = nil

    if TargetHighlight then
        TargetHighlight:Destroy()
        TargetHighlight = nil
    end

    if TargetLine then
        TargetLine.Visible = false
    end

    TeleportStatus.Text = "NOT ARMED"
    TeleportStatus.TextColor3 = C.Muted
end)

local HideButton = Button(
    Settings,
    "HIDE HUB",
    UDim2.new(1, -20, 0, 42),
    UDim2.fromOffset(10, 106)
)

HideButton.MouseButton1Click:Connect(function()
    Gui.Enabled = false
    Reopen.Visible = true
end)

--==================================================
-- TARGET SYSTEM
--==================================================

local function IsAlive(character)
    if not character then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")

    return humanoid
        and humanoid.Health > 0
end

local function IsVisible(character, head)
    if not State.VisibleCheck then
        return true
    end

    local origin = Camera.CFrame.Position
    local direction = head.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local ignored = {}

    if LocalPlayer.Character then
        table.insert(ignored, LocalPlayer.Character)
    end

    params.FilterDescendantsInstances = ignored

    local result = workspace:Raycast(
        origin,
        direction,
        params
    )

    if not result then
        return true
    end

    return result.Instance:IsDescendantOf(character)
end

local function IsSameTeam(plr)
    if not State.TeamCheck then
        return false
    end

    if not LocalPlayer.Team or not plr.Team then
        return false
    end

    return LocalPlayer.Team == plr.Team
end

local function GetTargetPart(character)
    if not character then
        return nil
    end

    return character:FindFirstChild(State.TargetPart)
        or character:FindFirstChild("Head")
        or character:FindFirstChild("HumanoidRootPart")
end

local function FindClosestToMouse()
    local bestPlayer = nil
    local bestDistance = State.FOV
    local mousePosition = UserInputService:GetMouseLocation()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not IsSameTeam(plr) then
            local character = plr.Character
            local part = GetTargetPart(character)
            local root = character and character:FindFirstChild("HumanoidRootPart")

            if part and root and IsAlive(character) then
                local worldDistance = (root.Position - Camera.CFrame.Position).Magnitude

                if worldDistance <= State.MaxDistance then
                    local screenPosition, onScreen =
                        Camera:WorldToViewportPoint(part.Position)

                    if onScreen and IsVisible(character, part) then
                        local distance =
                            (Vector2.new(screenPosition.X, screenPosition.Y) - mousePosition).Magnitude

                        if distance <= bestDistance then
                            bestDistance = distance
                            bestPlayer = plr
                        end
                    end
                end
            end
        end
    end

    return bestPlayer
end

local function ClearTargetHighlight()
    if TargetHighlight then
        TargetHighlight:Destroy()
        TargetHighlight = nil
    end
end

local function ApplyTargetHighlight()
    ClearTargetHighlight()

    if not State.Highlight then
        return
    end

    local target = (State.Camlock and LockedTarget) or SelectedTarget

    if not target then
        return
    end

    local character = target.Character

    if not character then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "BarbieTargetHighlight"
    highlight.Adornee = character
    highlight.FillColor = C.Red
    highlight.OutlineColor = C.Red
    highlight.FillTransparency = 0.72
    highlight.OutlineTransparency = 0.05
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = Gui

    TargetHighlight = highlight
end

local function RefreshTarget()
    if State.Camlock and LockedTarget then
        if LockedTarget.Parent == Players
            and LockedTarget.Character
            and IsAlive(LockedTarget.Character)
            and not IsSameTeam(LockedTarget) then

            SelectedTarget = LockedTarget
            TargetName.Text = LockedTarget.Name
            ApplyTargetHighlight()
            return
        end

        State.Camlock = false
        LockedTarget = nil
    end

    if State.StickyAim
        and SelectedTarget
        and SelectedTarget.Parent == Players
        and SelectedTarget.Character
        and IsAlive(SelectedTarget.Character)
        and not IsSameTeam(SelectedTarget) then

        local part = GetTargetPart(SelectedTarget.Character)
        local root = SelectedTarget.Character:FindFirstChild("HumanoidRootPart")

        if part and root
            and (root.Position - Camera.CFrame.Position).Magnitude <= State.MaxDistance
            and IsVisible(SelectedTarget.Character, part) then

            TargetName.Text = SelectedTarget.Name
            ApplyTargetHighlight()
            return
        end
    end

    local newTarget = FindClosestToMouse()

    if newTarget ~= SelectedTarget then
        SelectedTarget = newTarget
        ApplyTargetHighlight()
    elseif SelectedTarget and State.Highlight and not TargetHighlight then
        ApplyTargetHighlight()
    end

    TargetName.Text = SelectedTarget and SelectedTarget.Name or "None"
end

--==================================================
-- SILENT AIM / VIRTUAL MOUSE API
--==================================================
-- Roblox does not expose a supported way for one LocalScript to globally
-- overwrite every Tool's built-in Mouse.Hit property.
--
-- This API is the reliable way to make YOUR OWN weapon use Silent Aim.
--
-- In your own weapon's firing code, replace:
--     local position = mouse.Hit.Position
-- with:
--     local position = _G.BarbieHubGetAimPosition()
--
-- Or use:
--     local api = game.ReplicatedStorage:WaitForChild("BarbieHubAimAPI")
--     local position = api:Invoke()
--
-- The physical mouse never moves. The returned position is the selected
-- target's Head position while Silent Aim is enabled.

local function GetAimPart()
    local aimTarget = (State.Camlock and LockedTarget) or SelectedTarget

    if not aimTarget then
        return nil
    end

    local character = aimTarget.Character

    if not character or not IsAlive(character) or IsSameTeam(aimTarget) then
        return nil
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    local part = GetTargetPart(character)

    if not root or not part then
        return nil
    end

    if (root.Position - Camera.CFrame.Position).Magnitude > State.MaxDistance then
        return nil
    end

    if State.VisibleCheck and not IsVisible(character, part) then
        return nil
    end

    return part
end

local function GetAimPosition()
    if not State.SilentAim then
        return Mouse.Hit.Position
    end

    local aimPart = GetAimPart()

    if aimPart then
        local position = aimPart.Position

        if State.Prediction then
            position += aimPart.AssemblyLinearVelocity * State.PredictionAmount
        end

        return position
    end

    return Mouse.Hit.Position
end

local function GetAimCFrame()
    local position = GetAimPosition()
    return CFrame.lookAt(Camera.CFrame.Position, position)
end

local function GetAimTarget()
    if State.Camlock and LockedTarget then
        return LockedTarget
    end

    return SelectedTarget
end

local function GetAimRay(origin)
    local targetPosition = GetAimPosition()
    local direction = targetPosition - origin

    if direction.Magnitude <= 0.001 then
        direction = Camera.CFrame.LookVector
    end

    return Ray.new(origin, direction.Unit * 1000)
end

_G.BarbieHubGetAimPosition = GetAimPosition
_G.BarbieHubGetAimCFrame = GetAimCFrame
_G.BarbieHubGetAimRay = GetAimRay
_G.BarbieHubGetAimTarget = GetAimTarget

_G.BarbieHubSilentAimEnabled = function()
    return State.SilentAim
end

local AimAPI = ReplicatedStorage:FindFirstChild("BarbieHubAimAPI")

if not AimAPI then
    AimAPI = Instance.new("BindableFunction")
    AimAPI.Name = "BarbieHubAimAPI"
    AimAPI.Parent = ReplicatedStorage
end

AimAPI.OnInvoke = function()
    return GetAimPosition()
end

local AimTargetAPI = ReplicatedStorage:FindFirstChild("BarbieHubAimTargetAPI")

if not AimTargetAPI then
    AimTargetAPI = Instance.new("BindableFunction")
    AimTargetAPI.Name = "BarbieHubAimTargetAPI"
    AimTargetAPI.Parent = ReplicatedStorage
end

AimTargetAPI.OnInvoke = function()
    return GetAimTarget()
end

local AimRayAPI = ReplicatedStorage:FindFirstChild("BarbieHubAimRayAPI")

if not AimRayAPI then
    AimRayAPI = Instance.new("BindableFunction")
    AimRayAPI.Name = "BarbieHubAimRayAPI"
    AimRayAPI.Parent = ReplicatedStorage
end

AimRayAPI.OnInvoke = function(origin)
    return GetAimRay(origin or Camera.CFrame.Position)
end

--==================================================
-- PLAYER ESP RUNTIME
--==================================================

local ESPObjects = {}

local function RemoveESP(plr)
    local object = ESPObjects[plr]

    if object then
        if object.Gui then
            object.Gui:Destroy()
        end
        ESPObjects[plr] = nil
    end
end

local function EnsureESP(plr)
    if plr == LocalPlayer then
        return
    end

    local character = plr.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not character or not root then
        RemoveESP(plr)
        return
    end

    local object = ESPObjects[plr]

    if not object or not object.Gui or object.Gui.Parent ~= root then
        RemoveESP(plr)

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "BarbieESP"
        billboard.Adornee = root
        billboard.Size = UDim2.fromOffset(180, 42)
        billboard.StudsOffset = Vector3.new(0, 3.2, 0)
        billboard.AlwaysOnTop = true
        billboard.MaxDistance = State.MaxDistance
        billboard.Parent = root

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextColor3 = C.White
        label.TextStrokeTransparency = 0.35
        label.Parent = billboard

        object = {
            Gui = billboard,
            Label = label,
        }

        ESPObjects[plr] = object
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    local distanceText = ""
    if State.ESPDistance and localRoot then
        distanceText = string.format("  [%dst]", math.floor((root.Position - localRoot.Position).Magnitude))
    end

    local healthText = ""
    if State.ESPHealth and humanoid then
        healthText = string.format("  HP %d", math.floor(humanoid.Health))
    end

    object.Label.Text = plr.Name .. distanceText .. healthText
    object.Gui.Enabled = State.ESP
    object.Gui.MaxDistance = State.MaxDistance
end

Players.PlayerRemoving:Connect(RemoveESP)

local ESPTimer = 0

--==================================================
-- SPEED MACRO API
--==================================================

_G.BarbieHubSpeed = function()
    return Speed
end

_G.BarbieHubSpeedMacroEnabled = function()
    return State.Macro
end

--==================================================
-- KEYBINDS
--==================================================

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    if WaitingBind then
        Binds[WaitingBind] = input.KeyCode
        WaitingBind = nil
        return
    end

    for feature, key in pairs(Binds) do
        if input.KeyCode == key then

            if feature == "Teleport" then
                if State.Teleport then
                    TeleportArmed = true
                    TeleportStatus.Text = "ARMED — LEFT CLICK"
                    TeleportStatus.TextColor3 = C.Green
                end

            elseif feature == "Camlock" then
                -- Camlock is a true lock:
                -- first tap selects the current mouse target;
                -- later target scanning cannot replace it;
                -- second tap unlocks it.
                if State.Camlock then
                    State.Camlock = false
                    LockedTarget = nil
                    TargetName.Text = "None"
                else
                    RefreshTarget()
                    if SelectedTarget then
                        LockedTarget = SelectedTarget
                        State.Camlock = true
                    end
                end

            else
                State[feature] = not State[feature]

                if feature == "Macro" then
                    local humanoid = GetHumanoid and GetHumanoid() or nil

                    if State.Macro and humanoid then
                        SavedWalkSpeed = humanoid.WalkSpeed
                    end

                    ApplySpeed()
                end
            end

            break
        end
    end
end)

--==================================================
-- TELEPORT INPUT
--==================================================

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    if not State.Teleport then
        return
    end

    if not TeleportArmed then
        return
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root then
        return
    end

    local hit = Mouse.Hit

    if hit then
        root.CFrame = CFrame.new(
            hit.Position + Vector3.new(0, 3, 0)
        )
    end

    TeleportArmed = false
    TeleportStatus.Text = "NOT ARMED"
    TeleportStatus.TextColor3 = C.Muted
end)

--==================================================
-- TARGET LINE
--==================================================

local function UpdateTargetLine()
    if not State.TargetLine then
        if TargetLine then
            TargetLine.Visible = false
        end
        return
    end

    local lineTarget = (State.Camlock and LockedTarget) or SelectedTarget

    if not lineTarget or not lineTarget.Character then
        if TargetLine then
            TargetLine.Visible = false
        end
        return
    end

    local head = GetTargetPart(lineTarget.Character)

    if not head then
        if TargetLine then
            TargetLine.Visible = false
        end
        return
    end

    local targetScreen, visible =
        Camera:WorldToViewportPoint(head.Position)

    if not visible then
        if TargetLine then
            TargetLine.Visible = false
        end
        return
    end

    if not TargetLine then
        TargetLine = Instance.new("Frame")
        TargetLine.Name = "BarbieTargetLine"
        TargetLine.AnchorPoint = Vector2.new(0, 0.5)
        TargetLine.BackgroundColor3 = C.Red
        TargetLine.BorderSizePixel = 0
        TargetLine.ZIndex = 100
        TargetLine.Parent = Gui
    end

    local startPosition =
        UserInputService:GetMouseLocation()

    local endPosition =
        Vector2.new(targetScreen.X, targetScreen.Y)

    local difference =
        endPosition - startPosition

    TargetLine.Position =
        UDim2.fromOffset(
            startPosition.X,
            startPosition.Y
        )

    TargetLine.Size =
        UDim2.fromOffset(
            difference.Magnitude,
            2
        )

    TargetLine.Rotation =
        math.deg(
            math.atan2(
                difference.Y,
                difference.X
            )
        )

    TargetLine.Visible = true
end

--==================================================
-- CAMLOCK
--==================================================

local function UpdateCamlock()
    if not State.Camlock then
        return
    end

    if not SelectedTarget then
        return
    end

    local character = SelectedTarget.Character
    local part = GetTargetPart(character)

    if not part or not IsAlive(character) then
        return
    end

    Camera.CFrame = Camera.CFrame:Lerp(
        CFrame.lookAt(
            Camera.CFrame.Position,
            part.Position
        ),
        math.clamp(State.Smoothness, 0.01, 1)
    )
end

--==================================================
-- SPEED MACRO LOOP
--==================================================

task.spawn(function()
    while Gui.Parent do
        ApplySpeed()
        task.wait(0.05)
    end
end)

--==================================================
-- RENDER LOOP
--==================================================

local TargetUpdateTimer = 0

RunService.RenderStepped:Connect(function(deltaTime)
    TargetUpdateTimer += deltaTime

    -- Target selection is throttled slightly for performance.
    if TargetUpdateTimer >= 0.025 then
        TargetUpdateTimer = 0

        if State.SilentAim or State.Camlock or State.Highlight or State.TargetLine then
            RefreshTarget()
        else
            SelectedTarget = nil
            ClearTargetHighlight()
            TargetName.Text = "None"
        end
    end

    local mousePosition = UserInputService:GetMouseLocation()
    FOVCircle.Position = UDim2.fromOffset(mousePosition.X, mousePosition.Y)
    FOVCircle.Visible = State.SilentAim

    UpdateCamlock()
    UpdateTargetLine()

    ESPTimer += deltaTime
    if ESPTimer >= 0.12 then
        ESPTimer = 0

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                EnsureESP(plr)
            end
        end

        if not State.ESP then
            for plr, object in pairs(ESPObjects) do
                if object.Gui then
                    object.Gui.Enabled = false
                end
            end
        end
    end

    if State.Macro then
        StatusLabel.Text = "SPEED"
        StatusLabel.TextColor3 = C.Pink
    elseif State.SilentAim then
        StatusLabel.Text = "AIM"
        StatusLabel.TextColor3 = C.Pink
    elseif State.Camlock then
        StatusLabel.Text = "LOCK"
        StatusLabel.TextColor3 = C.Pink
    else
        StatusLabel.Text = "READY"
        StatusLabel.TextColor3 = C.Green
    end
end)

--==================================================
-- DRAGGING
--==================================================

local Dragging = false
local DragStart = nil
local StartPosition = nil

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = true
        DragStart = input.Position
        StartPosition = Main.Position
    end
end)

Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not Dragging then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end

    local delta = input.Position - DragStart

    Main.Position = UDim2.new(
        StartPosition.X.Scale,
        StartPosition.X.Offset + delta.X,
        StartPosition.Y.Scale,
        StartPosition.Y.Offset + delta.Y
    )
end)

--==================================================
-- RESPAWN CLEANUP
--==================================================

LocalPlayer.CharacterAdded:Connect(function()
    SelectedTarget = nil
    LockedTarget = nil
    TeleportArmed = false

    ClearTargetHighlight()

    if TargetLine then
        TargetLine.Visible = false
    end

    TeleportStatus.Text = "NOT ARMED"
    TeleportStatus.TextColor3 = C.Muted
end)

--==================================================
-- INITIAL PAGE
--==================================================

Pages.Home.Visible = true

for name, button in pairs(TabButtons) do
    if name == "Home" then
        button.BackgroundColor3 = C.White
        button.TextColor3 = C.Pink
    else
        button.BackgroundColor3 = C.Pale
        button.TextColor3 = C.Text
    end
end

print("[Barbie Hub V9] Loaded.")
