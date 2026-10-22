local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local env = getgenv()

if env.__ThreeSystemsCombined then
    pcall(function()
        env.__ThreeSystemsCombined:Close()
    end)
end

local running = true
local connections = {}
local combinedState = {}
local closeSanguine
local closeCursor

env.__ThreeSystemsCombined = combinedState

local espEnabled = true
local espConnections = {}

local LAUNCH_Y = 500
local MIN_DASH_SPEED = 90
local DASH_FRAMES = 6

local PATH_UPDATE_INTERVAL = 0.025
local PATH_DISCOVERY_INTERVAL = 0.10
local PATH_CONFIRM_WINDOW = 0.30
local PATH_MOVEMENT_THRESHOLD_SQ = 0.0064
local PATH_ROOT_MAX_DISTANCE_SQ = 225
local FULL_RESCAN_COOLDOWN = 5

local clickFunctions = {}
local trackedPaths = setmetatable({}, {__mode = "k"})

local lastPathDiscovery = -math.huge
local lastFullScan = -math.huge

local character
local humanoid
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

local function isAlly(targetPlayer)
    if targetPlayer == player then
        return true
    end

    local ally = false

    pcall(function()
        ally =
            targetPlayer:HasTag("Ally" .. player.Name)
            or player:HasTag("Ally" .. targetPlayer.Name)
    end)

    return ally
end

local function removeESP(targetPlayer)
    local targetCharacter = targetPlayer.Character

    if not targetCharacter then
        return
    end

    local head = targetCharacter:FindFirstChild("Head")

    if not head then
        return
    end

    local esp = head:FindFirstChild("PlayerNameESP")

    if esp then
        esp:Destroy()
    end
end

local function createESP(targetPlayer)
    if not running or not espEnabled then
        return
    end

    if targetPlayer == player then
        return
    end

    removeESP(targetPlayer)

    if isAlly(targetPlayer) then
        return
    end

    local targetCharacter = targetPlayer.Character

    if not targetCharacter then
        return
    end

    local head =
        targetCharacter:FindFirstChild("Head")
        or targetCharacter:WaitForChild("Head", 5)

    if not head then
        return
    end

    if not running
        or not espEnabled
        or isAlly(targetPlayer) then

        return
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PlayerNameESP"
    billboard.Adornee = head
    billboard.Size = UDim2.fromOffset(220, 30)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 10000
    billboard.Parent = head

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.fromScale(1, 1)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = targetPlayer.DisplayName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Parent = billboard
end

local function refreshESP(targetPlayer)
    if targetPlayer == player then
        return
    end

    if not espEnabled or isAlly(targetPlayer) then
        removeESP(targetPlayer)
    else
        createESP(targetPlayer)
    end
end

local function refreshAllESP()
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            refreshESP(targetPlayer)
        end
    end
end

local function clearAllESP()
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            removeESP(targetPlayer)
        end
    end
end

local function disconnectESPPlayer(targetPlayer)
    local list = espConnections[targetPlayer]

    if not list then
        return
    end

    for _, connection in ipairs(list) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    espConnections[targetPlayer] = nil
end

local function setupESPPlayer(targetPlayer)
    if targetPlayer == player then
        return
    end

    disconnectESPPlayer(targetPlayer)

    local list = {}
    espConnections[targetPlayer] = list

    list[#list + 1] =
        targetPlayer.CharacterAdded:Connect(function(targetCharacter)

            task.spawn(function()
                targetCharacter:WaitForChild("Head", 5)

                task.wait(0.1)

                if running and espEnabled then
                    refreshESP(targetPlayer)
                end
            end)
        end)

    if targetPlayer.Character then
        task.spawn(function()
            targetPlayer.Character:WaitForChild("Head", 5)

            if running and espEnabled then
                refreshESP(targetPlayer)
            end
        end)
    end
end

local function toggleESP()
    espEnabled = not espEnabled

    if espEnabled then
        refreshAllESP()
    else
        clearAllESP()
    end
end

local function getUps(fn)
    local getter = debug.getupvalues or getupvalues

    if not getter then
        return {}
    end

    local ok, result = pcall(getter, fn)

    if ok and type(result) == "table" then
        return result
    end

    return {}
end

local function getSource(fn)
    local ok, info = pcall(debug.getinfo, fn)

    if ok and info then
        return string.lower(tostring(info.source or ""))
    end

    return ""
end

local function isRealPath(value)
    if type(value) ~= "table" then
        return false
    end

    local ok, valid = pcall(function()
        return
            typeof(value.CurrentHumanoidPosition) == "Vector3"
            and typeof(value.CurrentHumanoidVelocity) == "Vector3"
            and typeof(value.OriginPoint) == "Vector3"
            and type(value.AgentCanFollowPath) == "boolean"
            and type(value.PathComputing) == "boolean"
            and type(value.Recomputing) == "boolean"
    end)

    return ok and valid == true
end

local function pathUsable(path)
    if not isRealPath(path) then
        return false
    end

    local ok, usable = pcall(function()
        return
            path.AgentCanFollowPath == true
            and path.PathComputing == false
            and path.Recomputing == false
    end)

    return ok and usable == true
end

local function clearTrackedPaths()
    trackedPaths = setmetatable({}, {__mode = "k"})
    lastPathDiscovery = -math.huge
end

local function scanClickToMove(force)
    local now = os.clock()

    if not force and now - lastFullScan < FULL_RESCAN_COOLDOWN then
        return #clickFunctions > 0
    end

    lastFullScan = now

    local ok, objects = pcall(getgc, true)

    if not ok or type(objects) ~= "table" then
        return false
    end

    local found = {}

    for _, obj in ipairs(objects) do
        if type(obj) == "function" then
            local source = getSource(obj)

            if string.find(
                source,
                "clicktomovecontroller",
                1,
                true
            ) then
                found[#found + 1] = obj
            end
        end
    end

    if #found == 0 then
        return false
    end

    clickFunctions = found

    return true
end

local function registerPath(path)
    if not isRealPath(path) then
        return
    end

    local data = trackedPaths[path]

    if data then
        data.lastSeen = os.clock()
        return
    end

    local ok, position = pcall(function()
        return path.CurrentHumanoidPosition
    end)

    if not ok or typeof(position) ~= "Vector3" then
        return
    end

    trackedPaths[path] = {
        lastPosition = position,
        lastMove = -math.huge,
        lastSeen = os.clock()
    }
end

local function discoverPaths(force)
    local now = os.clock()

    if not force
        and now - lastPathDiscovery < PATH_DISCOVERY_INTERVAL then
        return
    end

    lastPathDiscovery = now

    if #clickFunctions == 0 then
        scanClickToMove(false)
    end

    for _, fn in ipairs(clickFunctions) do
        local ups = getUps(fn)

        for _, value in pairs(ups) do
            if isRealPath(value) then
                registerPath(value)
            end
        end
    end
end

local function pathNearCharacter(path)
    if not root then
        return false
    end

    local ok, position = pcall(function()
        return path.CurrentHumanoidPosition
    end)

    if not ok or typeof(position) ~= "Vector3" then
        return false
    end

    local dx = position.X - root.Position.X
    local dz = position.Z - root.Position.Z

    local distanceSq =
        dx * dx +
        dz * dz

    return distanceSq <= PATH_ROOT_MAX_DISTANCE_SQ
end

local function sampleTrackedPaths()
    local now = os.clock()

    for path, data in pairs(trackedPaths) do
        if isRealPath(path) then
            local ok, position = pcall(function()
                return path.CurrentHumanoidPosition
            end)

            if ok and typeof(position) == "Vector3" then
                if data.lastPosition then
                    local dx =
                        position.X -
                        data.lastPosition.X

                    local dz =
                        position.Z -
                        data.lastPosition.Z

                    local movementSq =
                        dx * dx +
                        dz * dz

                    if movementSq >
                        PATH_MOVEMENT_THRESHOLD_SQ then

                        if pathUsable(path)
                            and pathNearCharacter(path) then

                            data.lastMove = now
                        end
                    end
                end

                data.lastPosition = position
            end
        else
            trackedPaths[path] = nil
        end
    end
end

local function getBestActivePath()
    local now = os.clock()

    discoverPaths(true)
    sampleTrackedPaths()

    local bestPath = nil
    local bestMove = -math.huge
    local bestDistance = math.huge

    for path, data in pairs(trackedPaths) do
        if pathUsable(path)
            and pathNearCharacter(path)
            and data.lastMove > -math.huge then

            local age =
                now - data.lastMove

            if age <= PATH_CONFIRM_WINDOW then
                local distanceSq = math.huge

                local ok, position = pcall(function()
                    return path.CurrentHumanoidPosition
                end)

                if ok
                    and typeof(position) == "Vector3"
                    and root then

                    local dx =
                        position.X -
                        root.Position.X

                    local dz =
                        position.Z -
                        root.Position.Z

                    distanceSq =
                        dx * dx +
                        dz * dz
                end

                if data.lastMove > bestMove then
                    bestPath = path
                    bestMove = data.lastMove
                    bestDistance = distanceSq

                elseif data.lastMove == bestMove
                    and distanceSq < bestDistance then

                    bestPath = path
                    bestMove = data.lastMove
                    bestDistance = distanceSq
                end
            end
        end
    end

    return bestPath, bestMove
end

local function grounded()
    if not humanoid or not root then
        return false
    end

    if humanoid.FloorMaterial == Enum.Material.Air then
        return false
    end

    local state = humanoid:GetState()

    if state == Enum.HumanoidStateType.Jumping then
        return false
    end

    if state == Enum.HumanoidStateType.Freefall then
        return false
    end

    if root.AssemblyLinearVelocity.Y > 3 then
        return false
    end

    return true
end

local function setCharacter(newCharacter)
    character = newCharacter

    humanoid =
        character:WaitForChild(
            "Humanoid",
            10
        )

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

    clearTrackedPaths()

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
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local env = getgenv()

if env.__SanguineNaturalZ then
    pcall(function()
        env.__SanguineNaturalZ:Close()
    end)
end

local ZClient =
    playerGui
    :WaitForChild("MovesetModules")
    :WaitForChild("Sanguine Art")
    :WaitForChild("Sanguine Art")
    :WaitForChild("Z")
    :WaitForChild("Client")

local Z = require(ZClient)

local ClampCharacterPhysics =
    require(ReplicatedStorage.Util.ClampCharacterPhysics)

local Effects =
    require(ReplicatedStorage.MovesetUtil.Effects)

local Client =
    require(ZClient.Parent.Parent.Client)

local Anims =
    require(ReplicatedStorage.Util.Anims)

local BodyMover =
    require(ReplicatedStorage.Util.BodyMover)

local Ray =
    require(ReplicatedStorage.Util.Ray)

local Cast =
    require(ReplicatedStorage.MovesetUtil.Cast)

local originalOnInput =
    env.__SanguineNaturalOriginal
    or Z.onInput

env.__SanguineNaturalOriginal =
    originalOnInput

local state = {
    Running = true,
    Connections = {}
}

env.__SanguineNaturalZ = state

local MULTIPLIER = 1.3
local DASH_TIME = 0.35

Z.onInput = function(u1, p2, p3, p4)
    if not state.Running then
        return originalOnInput(u1, p2, p3, p4)
    end

    local character = u1.character
    local rootPart = u1.rootPart
    local humanoid = u1.humanoid

    local chargeAnim =
        Anims:Get(character, "GhoulZCharge")

    chargeAnim:Play()

    humanoid.AutoRotate = false

    local aimCFrame =
        CFrame.new(
            rootPart.CFrame.Position,
            u1:aim()
                + Vector3.new(
                    0,
                    rootPart.Size.Y * 1.5,
                    0
                )
        )

    local gyro =
        BodyMover.new(character):Create(
            "BodyGyro",
            {
                CFrame = aimCFrame
            }
        )

    local position =
        BodyMover.new(character):Create(
            "BodyPosition",
            {
                Position = rootPart.Position
            }
        )

    Client.syncAim(u1)

    rootPart.CFrame =
        CFrame.new(
            rootPart.Position,
            u1:aim()
        )

    Effects.replicateLocal(
        "Ghoul.Grab",
        {
            Root = rootPart,
            Holding = u1.holdingInstance
        }
    )

    local finished = false

    task.spawn(function()
        while Cast.isActive(u1, finished) do
            local aim =
                Client.syncAim(u1)

            gyro:Set(
                CFrame.new(
                    rootPart.CFrame.Position,
                    aim
                )
            )

            task.wait()
        end
    end)

    task.spawn(function()
        RunService.Stepped:Wait()

        if u1.holdingInstance.Value then
            u1.holdingInstance.Changed:Wait()
        end

        if not state.Running then
            return
        end

        chargeAnim:Stop()

        Anims:Get(
            character,
            "GhoulZ"
        ):Play(
            nil,
            nil,
            1.35
        )

        aimCFrame =
            CFrame.new(
                rootPart.CFrame.Position,
                u1:aim()
                    + Vector3.new(
                        0,
                        rootPart.Size.Y * 1.5,
                        0
                    )
            )

        local _, dashPosition =
            Ray(
                rootPart.CFrame.Position,
                aimCFrame.LookVector
                    * 75
                    * MULTIPLIER,
                {
                    workspace.Characters,
                    workspace.Enemies
                }
            )

        Effects.replicateLocal(
            "Ghoul.Grab",
            {
                Root = rootPart,
                DashPosition = dashPosition
            }
        )

        task.wait()

        finished = true

        Cast.destroyBodyMover(position)

        local velocity =
            BodyMover.new(character):Create(
                "BodyVelocity",
                {
                    Velocity =
                        aimCFrame.LookVector
                        * 75
                        * MULTIPLIER
                        * 5
                }
            )

        local started = tick()

        local previous =
            tick()
            - 0.016666666666666666

        while
            tick() - started
            < DASH_TIME
        do
            local delta =
                tick() - previous

            if Ray(
                rootPart.CFrame.Position,
                aimCFrame.LookVector
                    * (
                        5
                        + rootPart.Velocity.Magnitude
                        * delta
                    ),
                {
                    workspace.Enemies,
                    workspace.Characters
                }
            ) then
                break
            end

            previous = tick()

            RunService.Stepped:Wait()
        end

        velocity:Set(
            aimCFrame.LookVector
            * 75
            * MULTIPLIER
            * 5
            * 0.1
        )

        RunService.Stepped:Wait()

        velocity:Destroy()

        Cast.destroyBodyMover(gyro)
    end)

    if not u1.remotes.func:InvokeServer(
        "Z",
        aimCFrame
    ) then
        Effects.replicateLocal(
            "Ghoul.Grab",
            {
                Hit = false,
                Grab = true,
                Root = rootPart,
                DashPosition = rootPart.Position,
                DashCFrame = rootPart.CFrame
            }
        )
    end

    finished = true

    Cast.destroyBodyMover(position)
    Cast.destroyBodyMover(gyro)

    ClampCharacterPhysics(
        rootPart,
        300
    )

    humanoid.AutoRotate = true
end

function state:Close()
    if not self.Running then
        return
    end

    self.Running = false

    Z.onInput = originalOnInput

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    self.Connections = {}

    if env.__SanguineNaturalZ == self then
        env.__SanguineNaturalZ = nil
    end
end

closeSanguine = function()
    state:Close()
end
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

    if closeSanguine then
        pcall(closeSanguine)
    end

    if closeCursor then
        pcall(closeCursor)
    end

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(connections)
    table.clear(clickFunctions)

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

    for targetPlayer, list in pairs(espConnections) do
        for _, connection in ipairs(list) do
            pcall(function()
                connection:Disconnect()
            end)
        end

        espConnections[targetPlayer] = nil
    end

    clearAllESP()
    clearTrackedPaths()

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

scanClickToMove(true)
discoverPaths(true)

local clickAccumulator = 0
local discoveryAccumulator = 0

connections[#connections + 1] =
    RunService.Heartbeat:Connect(function(dt)

        if not running then
            return
        end

        clickAccumulator += dt
        discoveryAccumulator += dt

        if discoveryAccumulator >=
            PATH_DISCOVERY_INTERVAL then

            discoveryAccumulator = 0
            discoverPaths(true)
        end

        if clickAccumulator >=
            PATH_UPDATE_INTERVAL then

            clickAccumulator = 0
            sampleTrackedPaths()
        end
    end)

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

        if input.KeyCode == Enum.KeyCode.F6 then
            toggleESP()
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

        if input.KeyCode ~= Enum.KeyCode.Q then
            return
        end

        if not humanoid or not root then
            return
        end

        if not grounded() then
            return
        end

        local confirmedPath, confirmedMove =
            getBestActivePath()

        if not confirmedPath then
            return
        end

        local dashRoot = root
        local dashHumanoid = humanoid

        task.spawn(function()

            for _ = 1, DASH_FRAMES do

                if not running then
                    return
                end

                if not dashRoot
                    or not dashRoot.Parent then

                    return
                end

                if dashHumanoid ~= humanoid then
                    return
                end

                RunService.PreSimulation:Wait()

                local velocity =
                    dashRoot.AssemblyLinearVelocity

                local horizontal =
                    Vector3.new(
                        velocity.X,
                        0,
                        velocity.Z
                    ).Magnitude

                if horizontal >= MIN_DASH_SPEED then

                    local data =
                        trackedPaths[confirmedPath]

                    if not data then
                        return
                    end

                    if not pathUsable(confirmedPath) then
                        return
                    end

                    if not pathNearCharacter(confirmedPath) then
                        return
                    end

                    if data.lastMove ~= confirmedMove
                        and data.lastMove > confirmedMove then

                        confirmedMove =
                            data.lastMove
                    end

                    if os.clock() - confirmedMove >
                        PATH_CONFIRM_WINDOW then

                        return
                    end

                    dashRoot.AssemblyLinearVelocity =
                        Vector3.new(
                            velocity.X,
                            LAUNCH_Y,
                            velocity.Z
                        )

                    return
                end
            end
        end)
    end)

connections[#connections + 1] =
    player.CharacterAdded:Connect(function(newCharacter)

        task.spawn(function()

            setCharacter(newCharacter)

            task.wait(1)

            if running then
                scanClickToMove(true)
                discoverPaths(true)
            end
        end)
    end)

for _, targetPlayer in ipairs(Players:GetPlayers()) do
    setupESPPlayer(targetPlayer)
end

connections[#connections + 1] =
    Players.PlayerAdded:Connect(function(targetPlayer)
        setupESPPlayer(targetPlayer)
    end)

connections[#connections + 1] =
    Players.PlayerRemoving:Connect(function(targetPlayer)
        removeESP(targetPlayer)
        disconnectESPPlayer(targetPlayer)
    end)

task.spawn(function()
    while running do
        if espEnabled then
            for _, targetPlayer in ipairs(Players:GetPlayers()) do
                if targetPlayer ~= player then
                    local targetCharacter = targetPlayer.Character
                    local head =
                        targetCharacter
                        and targetCharacter:FindFirstChild("Head")

                    local esp =
                        head
                        and head:FindFirstChild("PlayerNameESP")

                    if isAlly(targetPlayer) then
                        if esp then
                            esp:Destroy()
                        end
                    elseif not esp then
                        createESP(targetPlayer)
                    end
                end
            end
        end

        task.wait(0.25)
    end
end)

