local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local env = getgenv and getgenv() or _G

if env.__ThreeSystemsCombined then
    pcall(function()
        env.__ThreeSystemsCombined:Close()
    end)
end

if env.DmgCounterSafe and env.DmgCounterSafe.Stop then
    pcall(function()
        env.DmgCounterSafe.Stop()
    end)
end

if env.BFOptimizerV2 then
    pcall(function()
        env.BFOptimizerV2:Destroy()
    end)
end

pcall(function()
    RunService:UnbindFromRenderStep("NativeGunCursor")
    RunService:UnbindFromRenderStep("DmgCounterSafe")
end)

local state = {
    Running = true,
    Connections = {},
    SavedCursor = {},
    CursorActive = false,
    OriginalMouseIcon = mouse.Icon,
    OriginalMouseEnabled = UIS.MouseIconEnabled
}

env.__ThreeSystemsCombined = state

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(state.Connections, connection)
    return connection
end

local keys = {
    Enum.KeyCode.X,
    Enum.KeyCode.Z,
    Enum.KeyCode.C
}

local currentKey = 1
local skillsEnabled = true

local NORMAL_DISTANCE = 10
local R_WINDOW = 0.050
local R_MIN_DELAY = 0.001
local PORTAL_F_WINDOW = 0.7
local PORTAL_MIN_VELOCITY = 67
local PORTAL_MAX_VELOCITY = 73
local TRIGGER_COOLDOWN = 0.08

local lastR = -math.huge
local lastF = -math.huge
local lastTrigger = -math.huge

local character
local root
local previousPosition
local characterToken = 0

local oldGui = playerGui:FindFirstChild("SoruSkillSelector")

if oldGui then
    oldGui:Destroy()
end

local selectorGui = Instance.new("ScreenGui")
selectorGui.Name = "SoruSkillSelector"
selectorGui.ResetOnSpawn = false
selectorGui.IgnoreGuiInset = true
selectorGui.DisplayOrder = 999999
selectorGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
selectorGui.Parent = playerGui

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
label.ZIndex = 999999
label.Parent = selectorGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

local displayToken = 0

local function setCharacter(newCharacter)
    characterToken += 1
    local token = characterToken

    character = newCharacter
    root = nil
    previousPosition = nil

    lastR = -math.huge
    lastF = -math.huge
    lastTrigger = -math.huge

    task.spawn(function()
        local newRoot = newCharacter:WaitForChild(
            "HumanoidRootPart",
            10
        )

        if not state.Running or token ~= characterToken then
            return
        end

        root = newRoot

        if root then
            previousPosition = root.Position
        end
    end)
end

local function updateLabel()
    displayToken += 1
    local token = displayToken

    if not label.Parent then
        return
    end

    label.Text = skillsEnabled and keys[currentKey].Name or "OFF"
    label.Visible = true

    task.delay(0.8, function()
        if state.Running
            and token == displayToken
            and label.Parent then
            label.Visible = false
        end
    end)
end

local function fireSkill()
    if not state.Running or not skillsEnabled then
        return
    end

    local now = os.clock()

    if now - lastTrigger < TRIGGER_COOLDOWN then
        return
    end

    lastTrigger = now
    lastR = -math.huge

    local key = keys[currentKey]

    pcall(function()
        VIM:SendKeyEvent(true, key, false, game)
        VIM:SendKeyEvent(false, key, false, game)
    end)
end

local GUN_CURSOR = "rbxasset://textures/GunCursor.png"
local RELOAD_CURSOR = "rbxasset://textures/GunWaitCursor.png"

local function getGun()
    local currentCharacter = player.Character

    if not currentCharacter then
        return nil
    end

    for _, obj in ipairs(currentCharacter:GetChildren()) do
        if obj:IsA("Tool")
            and string.lower(tostring(obj.ToolTip)) == "gun" then
            return obj
        end
    end

    return nil
end

local function saveProperty(obj, property)
    local saved = state.SavedCursor

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

    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        saveProperty(obj, "ImageTransparency")
        obj.ImageTransparency = 1
    end

    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        saveProperty(obj, "TextTransparency")
        obj.TextTransparency = 1
    end

    if obj:IsA("Frame") then
        saveProperty(obj, "BackgroundTransparency")
        obj.BackgroundTransparency = 1
    end

    if obj:IsA("UIStroke") then
        saveProperty(obj, "Transparency")
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
    local cursorGui = getCustomCursor()

    if not cursorGui then
        return false
    end

    local reloadCursor = cursorGui:FindFirstChild(
        "ReloadCursor",
        true
    )

    return reloadCursor ~= nil
        and reloadCursor:IsA("GuiObject")
        and reloadCursor.Visible
end

local function suppressBloxCursor()
    local cursorGui = getCustomCursor()

    if not cursorGui then
        return
    end

    local cursor = cursorGui:FindFirstChild("Cursor", true)
    local reloadCursor = cursorGui:FindFirstChild(
        "ReloadCursor",
        true
    )

    if cursor then
        suppressObject(cursor)
    end

    if reloadCursor then
        suppressObject(reloadCursor)
    end

    for _, obj in ipairs(cursorGui:GetDescendants()) do
        local name = string.lower(obj.Name)

        if name == "bluedot"
            or name == "centerdot"
            or name == "overlayholder"
            or name == "reloadoverlayholder" then

            suppressObject(obj)

            if obj:IsA("GuiObject") then
                saveProperty(obj, "Visible")
                obj.Visible = false
            end
        end
    end
end

local function restoreCursor()
    for obj, properties in pairs(state.SavedCursor) do
        if obj and obj.Parent then
            for property, value in pairs(properties) do
                pcall(function()
                    obj[property] = value
                end)
            end
        end
    end

    table.clear(state.SavedCursor)
end

local function updateCursor()
    if not state.Running then
        return
    end

    local gun = getGun()

    if gun then
        state.CursorActive = true

        local reloading = getReloadState()

        suppressBloxCursor()

        UIS.MouseIconEnabled = true
        mouse.Icon = reloading and RELOAD_CURSOR or GUN_CURSOR
    else
        if state.CursorActive then
            state.CursorActive = false
            restoreCursor()
        end

        mouse.Icon = ""
        suppressBloxCursor()
    end
end

local MAX_EXTRA_X = 4.5
local MAX_EXTRA_Y_UP = 2.5
local MAX_EXTRA_Y_DOWN = 7
local MAX_EXTRA_ROTATION = 3.5
local HORIZONTAL_MULT = 2
local BASE_WIDTH_SCALE = 0.15
local MOTION_DURATION = 0.35

local damageGui = playerGui
    :WaitForChild("Main")
    :WaitForChild("DmgCounter")

local damage = {
    Writing = false,
    OriginalPosition = damageGui.Position,
    OriginalRotation = damageGui.Rotation,
    AppliedPosition = nil,
    AppliedRotation = nil,
    MotionStart = nil,
    LastWidth = nil
}

local function captureDamagePosition()
    if not state.Running or damage.Writing then
        return
    end

    local value = damageGui.Position

    if value ~= damage.AppliedPosition then
        damage.OriginalPosition = value
    end
end

local function captureDamageRotation()
    if not state.Running or damage.Writing then
        return
    end

    local value = damageGui.Rotation

    if value ~= damage.AppliedRotation then
        damage.OriginalRotation = value
    end
end

connect(
    damageGui:GetPropertyChangedSignal("Position"),
    captureDamagePosition
)

connect(
    damageGui:GetPropertyChangedSignal("Rotation"),
    captureDamageRotation
)

local function updateDamage()
    if not state.Running or not damageGui.Parent then
        return
    end

    local parentSize = damageGui.Parent.AbsoluteSize

    if parentSize.X <= 0 or parentSize.Y <= 0 then
        return
    end

    local original = damage.OriginalPosition

    local width =
        damageGui.Size.X.Scale * parentSize.X
        + damageGui.Size.X.Offset

    local baseWidth = BASE_WIDTH_SCALE * parentSize.X

    local widthDifference = math.abs(width - baseWidth)

    local extraX = math.clamp(
        widthDifference * HORIZONTAL_MULT,
        0,
        MAX_EXTRA_X
    )

    if widthDifference < 0.5 then
        extraX = 0
    end

    if damage.LastWidth == nil then
        damage.LastWidth = widthDifference
    end

    if widthDifference > damage.LastWidth + 0.5
        and damage.MotionStart == nil then
        damage.MotionStart = os.clock()
    end

    damage.LastWidth = widthDifference

    local extraY = 0
    local extraRotation = 0

    if damage.MotionStart then
        local elapsed = os.clock() - damage.MotionStart

        local progress = math.clamp(
            elapsed / MOTION_DURATION,
            0,
            1
        )

        if progress >= 1 then
            damage.MotionStart = nil
        else
            local wave = -math.sin(progress * math.pi * 2)

            if wave < 0 then
                extraY = wave * MAX_EXTRA_Y_UP
            else
                extraY = wave * MAX_EXTRA_Y_DOWN
            end

            extraRotation = wave * MAX_EXTRA_ROTATION
        end
    end

    local targetPosition = UDim2.new(
        original.X.Scale,
        original.X.Offset - extraX,
        original.Y.Scale,
        original.Y.Offset + extraY
    )

    local targetRotation =
        damage.OriginalRotation + extraRotation

    damage.Writing = true

    damage.AppliedPosition = targetPosition
    damage.AppliedRotation = targetRotation

    damageGui.Position = targetPosition
    damageGui.Rotation = targetRotation

    damage.Writing = false
end

local Optimizer = {
    ativo = false,
    destroyed = false,
    connections = {},
    originals = {},
    generation = 0
}

env.BFOptimizerV2 = Optimizer

local EFFECT_CLASSES = {
    BloomEffect = true,
    BlurEffect = true,
    DepthOfFieldEffect = true,
    SunRaysEffect = true,
    ColorCorrectionEffect = true
}

local function saveAndSet(obj, property, value)
    if Optimizer.destroyed or not Optimizer.ativo then
        return
    end

    local ok, current = pcall(function()
        return obj[property]
    end)

    if not ok then
        return
    end

    local properties = Optimizer.originals[obj]

    if not properties then
        properties = {}
        Optimizer.originals[obj] = properties
    end

    if properties[property] == nil then
        properties[property] = current
    end

    if current ~= value then
        pcall(function()
            obj[property] = value
        end)
    end
end

local function optimizeObject(obj)
    if not Optimizer.ativo or Optimizer.destroyed then
        return
    end

    if obj:IsA("ParticleEmitter") then
        saveAndSet(obj, "Enabled", false)
        saveAndSet(obj, "Rate", 0)
    elseif obj:IsA("Trail") or obj:IsA("Beam") then
        saveAndSet(obj, "Enabled", false)
    elseif obj:IsA("PointLight")
        or obj:IsA("SpotLight")
        or obj:IsA("SurfaceLight") then
        saveAndSet(obj, "Enabled", false)
    elseif obj:IsA("BasePart") then
        saveAndSet(obj, "CastShadow", false)
    elseif obj:IsA("PostEffect") then
        if EFFECT_CLASSES[obj.ClassName] then
            saveAndSet(obj, "Enabled", false)
        end
    end
end

local function optimizeLighting()
    if not Optimizer.ativo or Optimizer.destroyed then
        return
    end

    saveAndSet(Lighting, "GlobalShadows", false)
    saveAndSet(Lighting, "EnvironmentDiffuseScale", 0)
    saveAndSet(Lighting, "EnvironmentSpecularScale", 0)

    for _, obj in ipairs(Lighting:GetDescendants()) do
        if not Optimizer.ativo or Optimizer.destroyed then
            return
        end

        optimizeObject(obj)
    end
end

local function optimizeWorkspace(generation)
    local descendants = Workspace:GetDescendants()

    for index, obj in ipairs(descendants) do
        if not Optimizer.ativo
            or Optimizer.destroyed
            or Optimizer.generation ~= generation then
            return
        end

        optimizeObject(obj)

        if index % 350 == 0 then
            task.wait()
        end
    end
end

local function restoreOptimizer()
    for obj, properties in pairs(Optimizer.originals) do
        for property, value in pairs(properties) do
            pcall(function()
                obj[property] = value
            end)
        end
    end

    table.clear(Optimizer.originals)
end

function Optimizer:Enable()
    if self.destroyed or self.ativo then
        return
    end

    self.ativo = true
    self.generation += 1

    local generation = self.generation

    task.spawn(function()
        if self.ativo and self.generation == generation then
            optimizeLighting()
            optimizeWorkspace(generation)
        end
    end)
end

function Optimizer:Disable()
    if self.destroyed or not self.ativo then
        return
    end

    self.ativo = false
    self.generation += 1

    restoreOptimizer()
end

function Optimizer:Toggle()
    if self.ativo then
        self:Disable()
    else
        self:Enable()
    end
end

function Optimizer:Destroy()
    if self.destroyed then
        return
    end

    self:Disable()
    self.destroyed = true

    for _, connection in ipairs(self.connections) do
        connection:Disconnect()
    end

    table.clear(self.connections)

    if env.BFOptimizerV2 == self then
        env.BFOptimizerV2 = nil
    end
end

local function optimizerConnect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Optimizer.connections, connection)
end

optimizerConnect(Workspace.DescendantAdded, function(obj)
    if Optimizer.ativo then
        optimizeObject(obj)
    end
end)

optimizerConnect(Lighting.DescendantAdded, function(obj)
    if Optimizer.ativo then
        optimizeObject(obj)
    end
end)

local function shutdown()
    if not state.Running then
        return
    end

    state.Running = false
    displayToken += 1
    characterToken += 1

    Optimizer:Destroy()

    pcall(function()
        RunService:UnbindFromRenderStep("NativeGunCursor")
    end)

    pcall(function()
        RunService:UnbindFromRenderStep("DmgCounterSafe")
    end)

    for _, connection in ipairs(state.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(state.Connections)

    for _, key in ipairs(keys) do
        pcall(function()
            VIM:SendKeyEvent(false, key, false, game)
        end)
    end

    restoreCursor()

    pcall(function()
        mouse.Icon = state.OriginalMouseIcon
        UIS.MouseIconEnabled = state.OriginalMouseEnabled
    end)

    pcall(function()
        if damageGui.Parent then
            damageGui.Position = damage.OriginalPosition
            damageGui.Rotation = damage.OriginalRotation
        end
    end)

    if selectorGui.Parent then
        selectorGui:Destroy()
    end

    if env.__ThreeSystemsCombined == state then
        env.__ThreeSystemsCombined = nil
    end
end

function state:Close()
    shutdown()
end

if player.Character then
    setCharacter(player.Character)
end

connect(player.CharacterAdded, function(newCharacter)
    setCharacter(newCharacter)
end)

connect(RunService.Heartbeat, function()
    if not state.Running or not root or not root.Parent then
        return
    end

    if not previousPosition then
        previousPosition = root.Position
        return
    end

    local position = root.Position
    local distance = (position - previousPosition).Magnitude

    previousPosition = position

    if distance <= NORMAL_DISTANCE then
        return
    end

    local now = os.clock()
    local timeSinceR = now - lastR

    if timeSinceR < R_MIN_DELAY then
        return
    end

    if timeSinceR > R_WINDOW then
        return
    end

    local timeSinceF = now - lastF

    if timeSinceF <= PORTAL_F_WINDOW then
        local velocity = root.AssemblyLinearVelocity.Magnitude

        if velocity >= PORTAL_MIN_VELOCITY
            and velocity <= PORTAL_MAX_VELOCITY then
            lastF = -math.huge
            return
        end
    end

    fireSkill()
end)

connect(UIS.InputBegan, function(input)
    if not state.Running then
        return
    end

    if input.KeyCode == Enum.KeyCode.F7 then
        shutdown()
        return
    end

    if input.KeyCode == Enum.KeyCode.R then
        lastR = os.clock()
        return
    end

    if input.KeyCode == Enum.KeyCode.F then
        lastF = os.clock()
        return
    end

    if input.KeyCode == Enum.KeyCode.F6 then
        skillsEnabled = not skillsEnabled

        lastR = -math.huge
        lastF = -math.huge
        lastTrigger = -math.huge

        updateLabel()
        return
    end

    if input.KeyCode == Enum.KeyCode.H then
        currentKey += 1

        if currentKey > #keys then
            currentKey = 1
        end

        updateLabel()
        return
    end
end)

RunService:BindToRenderStep(
    "NativeGunCursor",
    Enum.RenderPriority.Last.Value + 2000,
    updateCursor
)

RunService:BindToRenderStep(
    "DmgCounterSafe",
    Enum.RenderPriority.Last.Value,
    updateDamage
)

Optimizer:Enable()
