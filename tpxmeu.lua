
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local G = getgenv()

for _, name in ipairs({
    "__GuiGunCursorOnly",
    "SoruX_V3",
    "SoruX_V4",
    "SoruX_V5",
    "SoruX_V6",
    "SoruX_V7",
    "SoruX_V8",
    "__SoruGuiGunCombined",
    "SoruPixelV1",
    "SoruPixelV2"
}) do
    local previous = G[name]

    if previous and previous.Stop then
        pcall(previous.Stop)
    end
end

if not hookmetamethod
    or not getnamecallmethod
    or not newcclosure then
    return
end

local CommE = RS:WaitForChild("Remotes"):WaitForChild("CommE")

local state = {
    active = true,
    pending = 0,
    pixelToken = 0,
    connections = {}
}

G.__SoruGuiGunCombined = state

local keys = {
    Enum.KeyCode.X,
    Enum.KeyCode.Z,
    Enum.KeyCode.C
}

local currentKey = 1
local displayToken = 0

local originalMouseIconEnabled = UIS.MouseIconEnabled
local originalMouseIcon = mouse.Icon

local GUN_CURSOR = "rbxasset://textures/GunCursor.png"
local RELOAD_CURSOR = "rbxasset://textures/GunWaitCursor.png"

local cursorActive = false
local saved = {}

for _, name in ipairs({
    "SoruSkillSelector",
    "SoruPixelV2_GUI",
    "SoruPixelDetector",
    "SoruX_V8_Status"
}) do
    local old = playerGui:FindFirstChild(name)
    if old then
        old:Destroy()
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "SoruSkillSelector"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "SelectedSkill"
label.Size = UDim2.fromOffset(70, 40)
label.Position = UDim2.new(0.5, -35, 0.8, 0)
label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
label.BackgroundTransparency = 0.45
label.BorderSizePixel = 0
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Text = ""
label.Visible = false
label.ZIndex = 100
label.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

local pixelGui = Instance.new("ScreenGui")
pixelGui.Name = "SoruPixelV2_GUI"
pixelGui.IgnoreGuiInset = true
pixelGui.ResetOnSpawn = false
pixelGui.DisplayOrder = 2147483647
pixelGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
pixelGui.Parent = playerGui

local pixel = Instance.new("Frame")
pixel.Name = "SoruSignal"
pixel.Position = UDim2.fromOffset(1919, 270)
pixel.Size = UDim2.fromOffset(1, 1)
pixel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
pixel.BackgroundTransparency = 0
pixel.BorderSizePixel = 0
pixel.Visible = false
pixel.ZIndex = 100
pixel.Parent = pixelGui

local function showPixel()
    if not state.active then
        return
    end

    state.pixelToken += 1
    local token = state.pixelToken

    pixel.Visible = true

    task.delay(0.5, function()
        if state.active and token == state.pixelToken then
            pixel.Visible = false
        end
    end)
end

local function updateLabel()
    displayToken += 1
    local token = displayToken

    if not state.active or not label.Parent then
        return
    end

    label.Text = keys[currentKey].Name
    label.Visible = true

    task.delay(0.8, function()
        if state.active
            and token == displayToken
            and label.Parent then
            label.Visible = false
        end
    end)
end

local function getGun()
    local character = player.Character
    if not character then
        return nil
    end

    for _, obj in ipairs(character:GetChildren()) do
        if obj:IsA("Tool")
            and string.lower(tostring(obj.ToolTip)) == "gun" then
            return obj
        end
    end

    return nil
end

local function save(obj, property)
    if not saved[obj] then
        saved[obj] = {}
    end

    if saved[obj][property] == nil then
        local ok, value = pcall(function()
            return obj[property]
        end)

        if ok then
            saved[obj][property] = value
        end
    end
end

local function hideGuiObject(obj)
    if not obj then
        return
    end

    if obj:IsA("ImageLabel")
        or obj:IsA("ImageButton") then
        save(obj, "ImageTransparency")
        obj.ImageTransparency = 1
    end

    if obj:IsA("TextLabel")
        or obj:IsA("TextButton") then
        save(obj, "TextTransparency")
        obj.TextTransparency = 1
    end

    if obj:IsA("Frame") then
        save(obj, "BackgroundTransparency")
        obj.BackgroundTransparency = 1
    end

    if obj:IsA("UIStroke") then
        save(obj, "Transparency")
        obj.Transparency = 1
    end
end

local function suppressObject(obj)
    if not obj then
        return
    end

    hideGuiObject(obj)

    for _, descendant in ipairs(obj:GetDescendants()) do
        hideGuiObject(descendant)
    end
end

local function getCustomCursor()
    return playerGui:FindFirstChild("CustomCursor")
end

local function getReloadState()
    local customGui = getCustomCursor()

    if not customGui then
        return false
    end

    local reloadCursor =
        customGui:FindFirstChild("ReloadCursor", true)

    return reloadCursor
        and reloadCursor:IsA("GuiObject")
        and reloadCursor.Visible or false
end

local function suppressBloxCursor()
    local customGui = getCustomCursor()

    if not customGui then
        return
    end

    local cursor = customGui:FindFirstChild("Cursor", true)
    local reloadCursor =
        customGui:FindFirstChild("ReloadCursor", true)

    if cursor then
        suppressObject(cursor)
    end

    if reloadCursor then
        suppressObject(reloadCursor)
    end

    for _, obj in ipairs(customGui:GetDescendants()) do
        local name = string.lower(obj.Name)

        if name == "bluedot"
            or name == "centerdot"
            or name == "overlayholder"
            or name == "reloadoverlayholder" then

            suppressObject(obj)

            if obj:IsA("GuiObject") then
                save(obj, "Visible")
                obj.Visible = false
            end
        end
    end
end

local function restore()
    for obj, properties in pairs(saved) do
        if obj and obj.Parent then
            for property, value in pairs(properties) do
                pcall(function()
                    obj[property] = value
                end)
            end
        end
    end

    table.clear(saved)
end

local function pressSkill()
    if not state.active then
        return
    end

    local key = keys[currentKey]

    pcall(function()
        for i = 1, 5 do
            VIM:SendKeyEvent(true, key, false, game)
            VIM:SendKeyEvent(false, key, false, game)
        end
    end)
end

local RENDER_NAME = "NativeGunCursor"

pcall(function()
    RunService:UnbindFromRenderStep(RENDER_NAME)
end)

RunService:BindToRenderStep(
    RENDER_NAME,
    Enum.RenderPriority.Last.Value + 2000,
    function()
        if not state.active then
            return
        end

        local gun = getGun()

        if gun then
            cursorActive = true

            local reloading = getReloadState()

            suppressBloxCursor()

            UIS.MouseIconEnabled = true
            mouse.Icon = reloading
                and RELOAD_CURSOR
                or GUN_CURSOR
        else
            if cursorActive then
                cursorActive = false
                restore()
            end

            mouse.Icon = ""
            suppressBloxCursor()
        end
    end
)

local function stop()
    if not state.active then
        return
    end

    state.active = false
    state.pending = 0
    state.pixelToken += 1

    for _, connection in ipairs(state.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(state.connections)

    RunService:UnbindFromRenderStep(RENDER_NAME)

    restore()

    mouse.Icon = originalMouseIcon
    UIS.MouseIconEnabled = originalMouseIconEnabled

    gui:Destroy()
    pixelGui:Destroy()

    if G.__SoruGuiGunCombined == state then
        G.__SoruGuiGunCombined = nil
    end
end

state.Stop = stop

local oldNamecall

oldNamecall = hookmetamethod(
    game,
    "__namecall",
    newcclosure(function(self, ...)
        if state.active
            and self == CommE
            and getnamecallmethod() == "FireServer"
            and select(1, ...) == "Soru" then

            state.pending += 1
        end

        return oldNamecall(self, ...)
    end)
)

state.connections[#state.connections + 1] =
    RunService.Heartbeat:Connect(function()
        if not state.active then
            return
        end

        if state.pending > 0 then
            state.pending = 0

            showPixel()
            pressSkill()
        end
    end)

state.connections[#state.connections + 1] =
    UIS.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.F7 then
            stop()
            return
        end

        if input.KeyCode == Enum.KeyCode.H then
            currentKey += 1

            if currentKey > #keys then
                currentKey = 1
            end

            updateLabel()
        end
    end)
