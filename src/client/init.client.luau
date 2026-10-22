--!strict
-- The only LocalScript. Boots each controller in order: every init() runs
-- before any start().

local Controllers = script:WaitForChild("Controllers")

local ORDER = {
	"StateController",
	"RoomBuilder",
	"PlantController",
	"CameraController",
	"ActionController",
	"InteractionController",
	"UIController",
	"TutorialController",
}

local controllers: { any } = {}
for _, name in ORDER do
	table.insert(controllers, require(Controllers:WaitForChild(name) :: ModuleScript) :: any)
end

for _, controller in controllers do
	if typeof(controller.init) == "function" then
		controller.init()
	end
end
for _, controller in controllers do
	if typeof(controller.start) == "function" then
		task.spawn(controller.start)
	end
end
