local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local env = getgenv()

if env.__ThreeSystemsCombined then
    pcall(function()
        env.__ThreeSystemsCombined:Close()
    end)
end

local running = true
local connections = {}
local combinedState = {}
local closeCursor

env.__ThreeSystemsCombined = combinedState

local character
local root
local previousPosition

local keys = {
    Enum.KeyCode.X,
    Enum.KeyCode.Z,
    Enum.KeyCode.C
}

local currentKey = 1

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

local oldGui = playerGui:FindFirstChild("SoruSkillSelector")

if oldGui then
    oldGui:Destroy()
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
label.ZIndex = 999999
label.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

local displayToken = 0

local function setCharacter(newCharacter)
    character = newCharacter

    root =
        character:WaitForChild(
            "HumanoidRootPart",
            10
        )

    if root then
        previousPosition = root.Position
    else
        previousPosition = nil
    end

    lastR = -math.huge
    lastF = -math.huge
    lastTrigger = -math.huge
end

local function updateLabel()
    displayToken += 1

    local token = displayToken

    if not label or not label.Parent then
        return
    end

    label.Text = keys[currentKey].Name
    label.Visible = true

    task.delay(0.8, function()
        if running
            and token == displayToken
            and label
            and label.Parent then

            label.Visible = false
        end
    end)
end

local function fireSkill()
    if not running then
        return
    end

    local now = os.clock()

    if now - lastTrigger <
        TRIGGER_COOLDOWN then

        return
    end

    lastTrigger = now
    lastR = -math.huge

    local key = keys[currentKey]

    pcall(function()
        VIM:SendKeyEvent(
            true,
            key,
            false,
            game
        )

        VIM:SendKeyEvent(
            false,
            key,
            false,
            game
        )
    end)
end

do
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local running = true
local active = false
local saved = {}
local originalMouseIconEnabled = UIS.MouseIconEnabled
local originalMouseIcon = mouse.Icon

local GUN_CURSOR = "rbxasset://textures/GunCursor.png"
local RELOAD_CURSOR = "rbxasset://textures/GunWaitCursor.png"

local function getGun()
	local character = player.Character

	if not character then
		return nil
	end

	for _, obj in ipairs(character:GetChildren()) do
		if obj:IsA("Tool") and string.lower(tostring(obj.ToolTip)) == "gun" then
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

	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		save(obj, "ImageTransparency")
		obj.ImageTransparency = 1
	end

	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
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
	local gui = getCustomCursor()

	if not gui then
		return false
	end

	local reloadCursor = gui:FindFirstChild("ReloadCursor", true)

	if reloadCursor and reloadCursor:IsA("GuiObject") then
		return reloadCursor.Visible
	end

	return false
end

local function suppressBloxCursor()
	local gui = getCustomCursor()

	if not gui then
		return
	end

	local cursor = gui:FindFirstChild("Cursor", true)
	local reloadCursor = gui:FindFirstChild("ReloadCursor", true)

	if cursor then
		suppressObject(cursor)
	end

	if reloadCursor then
		suppressObject(reloadCursor)
	end

	for _, obj in ipairs(gui:GetDescendants()) do
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

pcall(function()
	RunService:UnbindFromRenderStep("NativeGunCursor")
end)

RunService:BindToRenderStep(
	"NativeGunCursor",
	Enum.RenderPriority.Last.Value + 2000,
	function()
		if not running then
			return
		end

		local gun = getGun()

		if gun then
			active = true

			local reloading = getReloadState()

			suppressBloxCursor()

			UIS.MouseIconEnabled = true

			if reloading then
				mouse.Icon = RELOAD_CURSOR
			else
				mouse.Icon = GUN_CURSOR
			end
		else
			if active then
				active = false
				restore()
			end

			mouse.Icon = ""

			suppressBloxCursor()
		end
	end
)

closeCursor = function()
    if not running then
        return
    end

    running = false

    RunService:UnbindFromRenderStep("NativeGunCursor")
    restore()
    mouse.Icon = originalMouseIcon
    UIS.MouseIconEnabled = originalMouseIconEnabled
end
end

local function shutdown()
    if not running then
        return
    end

    running = false

    if closeCursor then
        pcall(closeCursor)
    end

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(connections)

    for _, key in ipairs(keys) do
        pcall(function()
            VIM:SendKeyEvent(
                false,
                key,
                false,
                game
            )
        end)
    end

    if gui then
        gui:Destroy()
    end

    if env.__ThreeSystemsCombined == combinedState then
        env.__ThreeSystemsCombined = nil
    end
end

function combinedState:Close()
    shutdown()
end

if player.Character then
    setCharacter(player.Character)
end
connections[#connections + 1] =
    RunService.Heartbeat:Connect(function()

        if not running then
            return
        end

        if not root or not root.Parent then
            return
        end

        if not previousPosition then
            previousPosition = root.Position
            return
        end

        local position = root.Position

        local distance =
            (position - previousPosition).Magnitude

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
            local velocity =
                root.AssemblyLinearVelocity.Magnitude

            if velocity >= PORTAL_MIN_VELOCITY
                and velocity <= PORTAL_MAX_VELOCITY then

                lastF = -math.huge
                return
            end
        end

        fireSkill()
    end)

connections[#connections + 1] =
    UIS.InputBegan:Connect(function(input)

        if not running then
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

        if input.KeyCode == Enum.KeyCode.H then
            currentKey += 1

            if currentKey > #keys then
                currentKey = 1
            end

            updateLabel()
            return
        end

    end)

connections[#connections + 1] =
    player.CharacterAdded:Connect(function(newCharacter)

        task.spawn(function()

            setCharacter(newCharacter)

        end)
    end)
