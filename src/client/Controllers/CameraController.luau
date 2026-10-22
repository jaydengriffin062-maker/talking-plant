--!strict
-- Fixed, front-facing camera framed so the plant sits in the center/lower-middle
-- of the screen on any aspect ratio (narrow phones pull the camera back).

local RoomBuilder = require(script.Parent.RoomBuilder)

local CameraController = {}

local FIELD_OF_VIEW = 40
-- Studs that must stay visible around the plant.
local FRAME_HEIGHT = 12
local FRAME_WIDTH = 10
-- Point the camera aims at, above the pot base (aiming high puts the plant lower on screen).
local AIM_HEIGHT = 4.2
local CAMERA_RISE = 1.2

local function frame(camera: Camera)
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
	local halfTan = math.tan(math.rad(FIELD_OF_VIEW / 2))
	local distance = math.max(FRAME_HEIGHT / (2 * halfTan), FRAME_WIDTH / (2 * halfTan * aspect))

	local root = RoomBuilder.getPlantRoot()
	local aim = root.Position + Vector3.new(0, AIM_HEIGHT, 0)
	local eye = aim + root.LookVector * distance + Vector3.new(0, CAMERA_RISE, 0)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FIELD_OF_VIEW
	camera.CFrame = CFrame.lookAt(eye, aim)
end

local function attach(camera: Camera)
	frame(camera)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		frame(camera)
	end)
	-- Some core scripts reset the camera type on spawn; keep it ours.
	camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			frame(camera)
		end
	end)
end

function CameraController.start()
	local camera = workspace.CurrentCamera
	if camera then
		attach(camera)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local newCamera = workspace.CurrentCamera
		if newCamera then
			attach(newCamera)
		end
	end)
end

return CameraController
