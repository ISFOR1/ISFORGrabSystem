--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║     ╔══╗╔══╗╔═══╗╔═══╗╔═══╗╔═══╗     Drag System v1.1                      ║
║     ║╔╗║╚╣╠╝║╔═╗║║╔═╗║║╔═╗║║╔══╝                                           ║
║     ║║║║ ║║ ║╚══╗║║ ║║║╚═╝║║╚══╗     Created by: ISFOR                    ║
║     ║║║║ ║║ ╚══╗║║║ ║║║╔╗╔╝║╔══╝     Last Updated: 2025                   ║
║     ║╚╝║╔╣╠╗║╚═╝║║╚═╝║║║║╚╗║╚══╗                                           ║
║     ╚══╝╚══╝╚═══╝╚═══╝╚╝╚═╝╚═══╝                                           ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

⚠️ IMPORTANT NOTICE ⚠️
======================
! DO NOT MODIFY THIS SCRIPT UNLESS YOU FULLY UNDERSTAND ITS FUNCTIONALITY !
! INCORRECT MODIFICATIONS MAY BREAK THE ENTIRE SYSTEM !

New Features Added:
-------------------
Collision Modes:
  - "Default": Normal collision
  - "Ghost": Passes through other parts
  - "Bounce": Bounces off other parts
  - "Stop": Stops at collision

Rotation Modes:
  - "Free": Full rotation control (based on mouse movement)
  - "Locked": No rotation changes during dragging
  - "AxisLocked": Only rotates on unlocked axes (see config.axisLock)

Effects:
  - Hover effect (enlarge part when mouse is over it)
  - Trail effect (a short-lived trail while dragging)
  - Glow effect (adds a light to the part during dragging)
  - Highlight on selection (adds a SelectionBox when selected)

Constraints:
  - Axis locking (via rotationMode "AxisLocked" and config.axisLock)
  - Rotation limits (via config.rotationLimits)
  - Boundary zones (limits movement to a defined region)
  - Snap points (snaps the target position when near predefined points)

Remember: Always backup before making changes!
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Print welcome message when module is required
local function printWelcome()
	local messages = {
		"Welcome to ISFOR's Drag System!",
		"Version: 1.1 (with extended features)",
		"Initialized and ready to use.",
		"Thank you for using ISFOR's Drag System!"
	}

	for _, msg in ipairs(messages) do
		print("【ISFOR】 " .. msg)
	end
end

local DragSystem = {}
DragSystem.__index = DragSystem

-- Default configuration including new options
local DEFAULT_CONFIG = {
	smoothness = 0.2,              -- Lower = smoother movement (0-1)
	maxDistance = 100,             -- Maximum drag distance
	minDistance = 2,               -- Minimum drag distance
	dragButton = Enum.UserInputType.MouseButton1,
	gridSnap = Vector3.new(0, 0, 0), -- Set non-zero values to snap to grid
	heightOffset = 0,              -- Y-axis offset while dragging
	enableLogging = true,          -- Enable status logging
	debugMode = false,             -- Enable debug visualization

	-- Collision Modes: "Default", "Ghost", "Bounce", "Stop"
	collisionMode = "Ghost",

	-- Rotation Modes: "Free", "Locked", "AxisLocked"
	rotationMode = "Free",         -- Change to "Locked" to keep initial orientation
	rotationSpeed = 0.2,           -- Sensitivity for mouse-driven rotation
	-- For AxisLocked mode: specify which axes to lock (true = locked)
	axisLock = { X = false, Y = false, Z = false },
	-- Optional rotation limits (angles in radians)
	rotationLimits = nil,          -- e.g., {minPitch = -math.pi/4, maxPitch = math.pi/4, minYaw = -math.pi, maxYaw = math.pi},

	-- Effects
	enableHighlight = true,        -- Highlight when selected (via SelectionBox)
	enableHoverEffect = false,     -- Enlarge part slightly on mouse hover (when not dragging)
	enableTrailEffect = false,     -- Show a trail effect during dragging
	enableGlowEffect = false,      -- Add a glow (PointLight) during dragging

	-- Constraints
	-- Boundary zone: define as {min = Vector3, max = Vector3} to clamp movement
	boundaryZones = nil,
	-- Snap points: an array of Vector3 positions; if within snapThreshold, targetPos snaps to that point
	snapPoints = nil,
	snapThreshold = 1,

	enableTouch = true,            -- Enable touch support
	version = "1.1"                -- System version
}

function DragSystem.new(part, config)
	local self = setmetatable({}, DragSystem)

	-- Validate inputs
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), 
		"【ISFOR】 Error: Invalid part provided. Must be a BasePart instance.")

	-- Initialize properties
	self.part = part
	self.config = setmetatable(config or {}, {__index = DEFAULT_CONFIG})
	self.player = Players.LocalPlayer
	self.camera = workspace.CurrentCamera
	self.dragging = false
	self.dragStart = nil
	self.startPos = nil
	self.distance = 0
	self.connections = {}

	-- Store original size for hover effect
	self.originalSize = part.Size

	-- For rotation
	self.initialMousePos = nil
	self.initialCFrame = nil

	-- Initialize part properties
	self.part.Anchored = true

	-- Setup connections (including input and effects)
	self:SetupConnections()

	-- Log initialization
	if self.config.enableLogging then
		print(string.format("【ISFOR】 Drag system initialized for part: %s", part.Name))
	end

	return self
end

function DragSystem:SetupConnections()
	-- Mouse button down / Touch begin
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == self.config.dragButton or 
			(self.config.enableTouch and input.UserInputType == Enum.UserInputType.Touch) then

			local mousePos = UserInputService:GetMouseLocation()
			local ray = self.camera:ViewportPointToRay(mousePos.X, mousePos.Y)

			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
			raycastParams.FilterDescendantsInstances = {self.part}

			local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)

			if raycastResult and raycastResult.Instance == self.part then
				self:StartDragging(raycastResult.Position)
			end
		end
	end))

	-- Mouse button up / Touch end
	table.insert(self.connections, UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == self.config.dragButton or 
			(self.config.enableTouch and input.UserInputType == Enum.UserInputType.Touch) then
			self:StopDragging()
		end
	end))

	-- Update loop
	table.insert(self.connections, RunService.RenderStepped:Connect(function()
		self:Update()
	end))

	-- Hover effect connection (if enabled and not dragging)
	if self.config.enableHoverEffect then
		local mouse = self.player:GetMouse()
		local hoverConn = mouse.Move:Connect(function()
			-- Only apply hover effect if not dragging
			if self.dragging then return end
			if mouse.Target == self.part then
				self.part.Size = self.originalSize * 1.05
			else
				self.part.Size = self.originalSize
			end
		end)
		table.insert(self.connections, hoverConn)
	end

	if self.config.enableLogging then
		print("【ISFOR】 Connections setup complete for: " .. self.part.Name)
	end
end

function DragSystem:StartDragging(hitPosition)
	self.dragging = true
	self.dragStart = hitPosition
	self.startPos = self.part.Position
	self.distance = (hitPosition - self.camera.CFrame.Position).Magnitude

	-- Record initial mouse position and CFrame for rotation
	self.initialMousePos = UserInputService:GetMouseLocation()
	self.initialCFrame = self.part.CFrame

	-- Effects: Highlight (via SelectionBox)
	if self.config.enableHighlight then
		-- Lower transparency (or add a SelectionBox)
		self.part.Transparency = 0.5
		local selectionBox = Instance.new("SelectionBox")
		selectionBox.Adornee = self.part
		selectionBox.Color3 = Color3.new(1, 1, 0) -- Yellow highlight
		selectionBox.Name = "DragSelectionBox"
		selectionBox.Parent = self.part
		self.selectionBox = selectionBox
	end

	-- Effects: Trail effect
	if self.config.enableTrailEffect then
		local att0 = Instance.new("Attachment")
		att0.Name = "TrailAttachment0"
		att0.Parent = self.part
		local att1 = Instance.new("Attachment")
		att1.Name = "TrailAttachment1"
		att1.Parent = self.part
		local trail = Instance.new("Trail")
		trail.Attachment0 = att0
		trail.Attachment1 = att1
		trail.Lifetime = 0.5
		trail.Color = ColorSequence.new(Color3.new(1, 0, 0))
		trail.Name = "DragTrail"
		trail.Parent = self.part
		self.trail = trail
		self.attachments = {att0, att1}
	end

	-- Effects: Glow effect
	if self.config.enableGlowEffect then
		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range = 8
		light.Name = "DragGlow"
		light.Parent = self.part
		self.glow = light
	end

	-- Collision mode: For Ghost, disable collisions immediately
	if self.config.collisionMode == "Ghost" then
		self.part.CanCollide = false
	end

	if self.config.enableLogging then
		print("【ISFOR】 Started dragging part: " .. self.part.Name)
	end
end

function DragSystem:StopDragging()
	self.dragging = false

	-- Remove highlight effect
	if self.config.enableHighlight then
		self.part.Transparency = 0
		if self.selectionBox then
			self.selectionBox:Destroy()
			self.selectionBox = nil
		end
	end

	-- Remove trail effect
	if self.config.enableTrailEffect and self.trail then
		for _, att in ipairs(self.attachments or {}) do
			att:Destroy()
		end
		self.trail:Destroy()
		self.trail = nil
		self.attachments = nil
	end

	-- Remove glow effect
	if self.config.enableGlowEffect and self.glow then
		self.glow:Destroy()
		self.glow = nil
	end

	-- Reset collision if in Ghost mode
	if self.config.collisionMode == "Ghost" then
		self.part.CanCollide = true
	end

	-- Ensure hover effect resets size
	if self.config.enableHoverEffect then
		self.part.Size = self.originalSize
	end

	if self.config.enableLogging then
		print("【ISFOR】 Stopped dragging part: " .. self.part.Name)
	end
end

function DragSystem:Update()
	if not self.dragging then return end

	local mousePos = UserInputService:GetMouseLocation()
	local ray = self.camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	-- Calculate target position from mouse ray
	local targetPos = ray.Origin + ray.Direction * math.clamp(
		self.distance,
		self.config.minDistance,
		self.config.maxDistance
	)

	-- Apply height offset
	targetPos = targetPos + Vector3.new(0, self.config.heightOffset, 0)

	-- Apply grid snapping if enabled
	if self.config.gridSnap ~= Vector3.new(0, 0, 0) then
		targetPos = Vector3.new(
			math.round(targetPos.X / self.config.gridSnap.X) * self.config.gridSnap.X,
			math.round(targetPos.Y / self.config.gridSnap.Y) * self.config.gridSnap.Y,
			math.round(targetPos.Z / self.config.gridSnap.Z) * self.config.gridSnap.Z
		)
	end

	-- Apply boundary zone constraint if provided
	if self.config.boundaryZones then
		local minB = self.config.boundaryZones.min
		local maxB = self.config.boundaryZones.max
		targetPos = Vector3.new(
			math.clamp(targetPos.X, minB.X, maxB.X),
			math.clamp(targetPos.Y, minB.Y, maxB.Y),
			math.clamp(targetPos.Z, minB.Z, maxB.Z)
		)
	end

	-- Apply snap points if provided
	if self.config.snapPoints then
		for _, snapPoint in ipairs(self.config.snapPoints) do
			if (targetPos - snapPoint).Magnitude < self.config.snapThreshold then
				targetPos = snapPoint
				break
			end
		end
	end

	-- --- Collision handling for "Stop" and "Bounce" modes ---
	if self.config.collisionMode == "Stop" or self.config.collisionMode == "Bounce" then
		local direction = targetPos - self.part.Position
		local distance = direction.Magnitude
		if distance > 0 then
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
			raycastParams.FilterDescendantsInstances = {self.part}
			local hitResult = workspace:Raycast(self.part.Position, direction, raycastParams)
			if hitResult then
				if self.config.collisionMode == "Stop" then
					-- Stop the part at the collision point (offset slightly)
					targetPos = hitResult.Position - direction.Unit * 0.1
				elseif self.config.collisionMode == "Bounce" then
					-- Compute a simple reflection (bounce) off the surface normal
					local bounceFactor = 0.5
					local dirUnit = direction.Unit
					local reflection = dirUnit - 2 * (dirUnit:Dot(hitResult.Normal)) * hitResult.Normal
					targetPos = self.part.Position + reflection * distance * bounceFactor
				end
			end
		end
	end
	-- --- End collision handling ---

	-- Smoothly update position
	local newPos = self.part.Position:Lerp(targetPos, self.config.smoothness)

	-- Determine new rotation based on rotation mode
	local newRot
	if self.config.rotationMode == "Locked" then
		-- Keep the initial rotation from when dragging started
		newRot = self.initialCFrame - self.initialCFrame.Position
	else
		-- Compute rotation delta from initial mouse position
		local currentMousePos = UserInputService:GetMouseLocation()
		local delta = currentMousePos - self.initialMousePos
		-- Convert pixel delta to radians using rotationSpeed multiplier
		local yaw = math.rad(delta.X * self.config.rotationSpeed)
		local pitch = math.rad(-delta.Y * self.config.rotationSpeed) -- invert Y for natural feel

		-- Apply rotation limits if set
		if self.config.rotationLimits then
			yaw = math.clamp(yaw, self.config.rotationLimits.minYaw, self.config.rotationLimits.maxYaw)
			pitch = math.clamp(pitch, self.config.rotationLimits.minPitch, self.config.rotationLimits.maxPitch)
		end

		-- If using AxisLocked mode, zero out rotations on locked axes
		if self.config.rotationMode == "AxisLocked" then
			if self.config.axisLock.X then pitch = 0 end
			if self.config.axisLock.Y then yaw = 0 end
			-- (Z rotation is not computed in this example.)
		end

		-- Create a rotation delta CFrame and combine with the initial rotation
		local rotationDelta = CFrame.Angles(pitch, yaw, 0)
		newRot = self.initialCFrame - self.initialCFrame.Position
		newRot = rotationDelta * newRot
	end

	-- Update the part's full CFrame
	self.part.CFrame = CFrame.new(newPos) * newRot
end

function DragSystem:Destroy()
	-- Cleanup connections
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}

	-- Reset part properties
	if self.config.collisionMode == "Ghost" then
		self.part.CanCollide = true
	end
	self.part.Transparency = 0
	self.part.Size = self.originalSize

	if self.config.enableLogging then
		print("【ISFOR】 Drag system destroyed for part: " .. self.part.Name)
	end
end

-- Print welcome message when module is loaded
printWelcome()

return DragSystem
