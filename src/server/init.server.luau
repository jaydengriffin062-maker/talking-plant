--!strict
-- The only server Script. Creates remotes, then boots each system in order:
-- every system's init() runs before any start().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

-- The game is camera-only; nobody needs an avatar. (Also set in default.project.json.)
Players.CharacterAutoLoads = false

Net.setup()

local Systems = script:WaitForChild("Systems")
local ORDER = { "DataService", "PlantService" }

local systems: { any } = {}
for _, name in ORDER do
	table.insert(systems, require(Systems:WaitForChild(name) :: ModuleScript) :: any)
end

for _, system in systems do
	if typeof(system.init) == "function" then
		system.init()
	end
end
for _, system in systems do
	if typeof(system.start) == "function" then
		task.spawn(system.start)
	end
end
