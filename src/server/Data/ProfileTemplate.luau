--!strict
-- Default save data for a brand-new player. Bump SCHEMA_VERSION in
-- DataService and add a migration whenever an existing field changes shape;
-- new fields are filled in from here automatically.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)

local template: Types.Profile = {
	version = 1,
	coins = 0,
	tutorialDone = false,
	plant = {
		needs = {
			-- Starts thirsty so the tutorial's first action is watering.
			water = PlantConfig.Tutorial.StartingWater,
			nutrients = 80,
			energy = 90,
			cleanliness = 100,
		},
		affection = 0,
		asleep = false,
		-- 0 = never simulated; set to "now" on first load.
		updatedAt = 0,
	},
	stats = {
		waters = 0,
		feeds = 0,
		cleans = 0,
		pets = 0,
		talks = 0,
	},
}

return template
