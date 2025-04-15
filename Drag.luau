local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DragSystem = require(ReplicatedStorage:WaitForChild("DragSystem"))

-- Wait for the draggable part to be available in the workspace
local part = workspace:WaitForChild("MovingPart")

-- Create a new drag system instance with custom configuration
local dragInstance = DragSystem.new(part, {
	-- Basic movement options
	smoothness = 0.1,              -- Smoother, more responsive movement
	maxDistance = 150,             -- Increase maximum drag distance
	gridSnap = Vector3.new(1, 1, 1), -- Snap movement to whole stud increments
	heightOffset = 2,              -- Hover 2 studs above the drag point

	-- Collision Options: "Default", "Ghost", "Bounce", "Stop"
	collisionMode = "Bounce",      -- Bounce off obstacles

	-- Rotation Options: "Free", "Locked", "AxisLocked"
	rotationMode = "AxisLocked",   -- Lock rotation on the Y-axis for example
	axisLock = { X = false, Y = true, Z = false },
	rotationSpeed = 0.2,
	rotationLimits = {            -- Optional rotation limits (in radians)
		minPitch = -math.pi/4,
		maxPitch = math.pi/4,
		minYaw = -math.pi/2,
		maxYaw = math.pi/2,
	},

	-- Effects
	enableHighlight = true,        -- Highlight part when selected
	enableHoverEffect = true,      -- Enlarge part slightly on mouse hover
	enableTrailEffect = true,      -- Display a trail effect while dragging
	enableGlowEffect = true,       -- Add a glow effect (PointLight) during dragging

	-- Constraints
	boundaryZones = {              -- Define a region for allowed movement
		min = Vector3.new(-50, 0, -50),
		max = Vector3.new(50, 50, 50)
	},
	snapPoints = {                 -- Snap to these positions when close
		Vector3.new(0, 10, 0),
		Vector3.new(10, 10, 10)
	},
	snapThreshold = 2,             -- Distance threshold for snapping

	enableLogging = true,          -- Output status messages to the console
	enableTouch = true             -- Enable touch support
})

-- Optional: Clean up the drag system after some time or when no longer needed
-- wait(60)
-- dragInstance:Destroy()
