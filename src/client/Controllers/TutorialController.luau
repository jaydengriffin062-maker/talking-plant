--!strict
-- First-time experience, about a minute long: meet the sprout, water it, get coins.
-- The server marks the tutorial done (and pays the reward) on the first watering.

local StateController = require(script.Parent.StateController)
local PlantController = require(script.Parent.PlantController)
local UIController = require(script.Parent.UIController)

local TutorialController = {}

local function tutorialDone(): boolean
	local state = StateController.get()
	return state ~= nil and state.tutorialDone
end

function TutorialController.start()
	StateController.waitForLoad()
	if tutorialDone() then
		return
	end

	task.wait(0.6)
	UIController.showBanner("Meet your new plant! 🌱", 3)
	PlantController.react("Greet")
	task.wait(3.2)
	if tutorialDone() then
		return
	end

	UIController.showBanner("Your plant looks thirsty... 💧")
	UIController.openCare()
	UIController.highlightTool("Water", true)
	while not tutorialDone() do
		task.wait(0.25)
	end
	UIController.highlightTool("Water", false)

	task.wait(2.5)
	UIController.showBanner("+100 coins! Now tap, rub and talk to your plant 💬", 5)
end

return TutorialController
