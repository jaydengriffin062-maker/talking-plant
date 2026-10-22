--!strict
-- Client copy of this player's server state, plus local prediction of needs
-- between server updates (same NeedsMath the server uses).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local NeedsMath = require(Shared.Util.NeedsMath)
local Signal = require(Shared.Util.Signal)

local StateController = {}

StateController.Changed = Signal.new() :: Signal.Signal<Types.Snapshot>

local snapshot: Types.Snapshot? = nil

local function apply(state: Types.Snapshot)
	snapshot = state
	StateController.Changed:Fire(state)
end

function StateController.get(): Types.Snapshot?
	return snapshot
end

-- Yields until the first snapshot arrives.
function StateController.waitForLoad(): Types.Snapshot
	while not snapshot do
		task.wait(0.1)
	end
	return snapshot :: Types.Snapshot
end

-- The plant with needs predicted up to this moment.
function StateController.plantNow(): Types.PlantState?
	local state = snapshot
	if not state then
		return nil
	end
	return NeedsMath.advance(state.plant, workspace:GetServerTimeNow())
end

function StateController.mood(): NeedsMath.Mood
	local plant = StateController.plantNow()
	return if plant then NeedsMath.mood(plant) else "Neutral"
end

-- Optimistic local change (e.g. a poke waking the plant) until the server confirms.
function StateController.predict(mutate: (Types.PlantState) -> ())
	local state = snapshot
	if state then
		local copy = table.clone(state)
		copy.plant = NeedsMath.clonePlant(state.plant)
		mutate(copy.plant)
		copy.welcomeBack = nil
		apply(copy)
	end
end

function StateController.start()
	Net.event("StateUpdate").OnClientEvent:Connect(apply)

	local getState = Net.func("GetState")
	while not snapshot do
		local ok, result = pcall(function()
			return getState:InvokeServer()
		end)
		if ok and typeof(result) == "table" then
			-- A pushed update may have arrived first; the fetched one still
			-- carries the one-time welcomeBack flag.
			apply(result)
		else
			task.wait(2)
		end
	end
end

return StateController
