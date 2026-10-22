--!strict
-- Authoritative plant state: needs, care actions, touch affection, talking and coins.
-- Clients only ever *ask*; every request is type-checked, rate-limited and
-- cooldown-gated here before it touches the profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local NeedsMath = require(Shared.Util.NeedsMath)
local PlantConfig = require(Shared.Config.PlantConfig)
local TalkConfig = require(Shared.Config.TalkConfig)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local PlantService = {}

local careLimiter = RateLimiter.new(6, 2)
local interactLimiter = RateLimiter.new(12, 6)
local talkLimiter = RateLimiter.new(3, 0.5)
local stateLimiter = RateLimiter.new(3, 0.2)

local lastActionAt: { [Player]: { [string]: number } } = {}
local dirty: { [Player]: boolean } = {}
local welcomeBack: { [Player]: boolean } = {}
local canChat: { [Player]: boolean } = {}

local stateUpdate: RemoteEvent

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Brings the stored plant up to date and returns it (the profile's own table).
local function currentPlant(profile: Types.Profile): Types.PlantState
	profile.plant = NeedsMath.advance(profile.plant, now())
	return profile.plant
end

local function snapshot(player: Player, profile: Types.Profile): Types.Snapshot
	return {
		coins = profile.coins,
		plant = currentPlant(profile),
		tutorialDone = profile.tutorialDone,
		canChat = canChat[player] == true,
	}
end

local function pushState(player: Player)
	local profile = DataService.getProfile(player)
	if profile then
		dirty[player] = nil
		stateUpdate:FireClient(player, snapshot(player, profile))
	end
end

-- Small changes (affection from petting) are batched and pushed once a second.
local function markDirty(player: Player)
	dirty[player] = true
end

-- True if `key` was used less than `seconds` ago; otherwise records the use.
local function onCooldown(player: Player, key: string, seconds: number): boolean
	local times = lastActionAt[player]
	if not times then
		times = {}
		lastActionAt[player] = times
	end
	local t = os.clock()
	local last = times[key]
	if last and t - last < seconds then
		return true
	end
	times[key] = t
	return false
end

local function addAffection(plant: Types.PlantState, amount: number)
	plant.affection = math.clamp(plant.affection + amount, 0, 100)
end

local function handleSleep(player: Player, plant: Types.PlantState): Types.CareResult
	if onCooldown(player, "Sleep", PlantConfig.Sleep.Cooldown) then
		return { ok = false, reason = "cooldown" }
	end
	if plant.asleep then
		plant.asleep = false
		pushState(player)
		return { ok = true, reaction = "WakeUp" }
	end
	if plant.needs.energy > PlantConfig.Sleep.RefuseAboveEnergy then
		return { ok = false, reason = "notSleepy", reaction = "NotSleepy" }
	end
	plant.asleep = true
	pushState(player)
	return { ok = true, reaction = "FallAsleep" }
end

local function handleCare(player: Player, action: unknown): Types.CareResult
	if typeof(action) ~= "string" then
		return { ok = false, reason = "invalid" }
	end
	if not careLimiter:allow(player) then
		return { ok = false, reason = "busy" }
	end
	local profile = DataService.getProfile(player)
	if not profile then
		return { ok = false, reason = "loading" }
	end
	local plant = currentPlant(profile)

	if action == "Sleep" then
		return handleSleep(player, plant)
	end

	local care = PlantConfig.Care[action]
	if not care then
		return { ok = false, reason = "invalid" }
	end
	if onCooldown(player, action, care.cooldown) then
		return { ok = false, reason = "cooldown" }
	end
	if plant.asleep then
		return { ok = false, reason = "asleep", reaction = "SleepTalk" }
	end

	local before = plant.needs[care.need]
	if before >= care.fullAt then
		return { ok = false, reason = "full", reaction = care.fullReaction }
	end
	plant.needs[care.need] = math.min(PlantConfig.Needs.Max, before + care.amount)

	local coins = if PlantConfig.Needs.Max - before >= care.rewardMinDeficit then care.coinReward else 0
	local reaction = care.reaction
	if action == "Water" and not profile.tutorialDone then
		profile.tutorialDone = true
		coins += PlantConfig.Tutorial.CoinReward
		reaction = "Celebrate"
	end
	profile.coins += coins
	profile.stats[care.stat] = (profile.stats[care.stat] or 0) + 1

	pushState(player)
	return { ok = true, reaction = reaction, coins = coins }
end

local function handleInteract(player: Player, kind: unknown)
	if typeof(kind) ~= "string" then
		return
	end
	local def = PlantConfig.Interactions[kind]
	if not def or not interactLimiter:allow(player) then
		return
	end
	if onCooldown(player, "interact_" .. kind, def.cooldown) then
		return
	end
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	local plant = currentPlant(profile)
	if plant.asleep and PlantConfig.WakingInteractions[kind] then
		plant.asleep = false
	end
	addAffection(plant, def.affection)
	if kind == "Pet" then
		profile.stats.pets = (profile.stats.pets or 0) + 1
	end
	markDirty(player)
end

local function filterForPlayer(player: Player, text: string): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForUserAsync(player.UserId)
	end)
	if ok and typeof(result) == "string" then
		return result
	end
	warn(`[PlantService] text filter failed: {result}`)
	return nil
end

local function statusLine(plant: Types.PlantState): string
	local need, value = NeedsMath.lowestNeed(plant)
	if value < 50 then
		return TalkConfig.StatusLines[need]
	end
	return TalkConfig.StatusLines.fine
end

local function handleTalk(player: Player, text: unknown): Types.TalkResult
	if typeof(text) ~= "string" then
		return { reaction = "Confused" }
	end
	if not talkLimiter:allow(player) then
		return { reaction = "Busy" }
	end
	-- Reject invalid UTF-8 and over-long input outright.
	local length = utf8.len(text)
	if not length or length > TalkConfig.MaxLength then
		return { reaction = "Confused" }
	end
	local trimmed = string.match(text, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return { reaction = "Confused" }
	end
	local profile = DataService.getProfile(player)
	if not profile then
		return { reaction = "Confused" }
	end

	local plant = currentPlant(profile)
	profile.stats.talks = (profile.stats.talks or 0) + 1

	local phrase = TalkConfig.match(trimmed)
	if phrase then
		if phrase.affection and not onCooldown(player, "talkAffection", 3) then
			addAffection(plant, phrase.affection)
			markDirty(player)
		end
		if phrase.reaction == "Status" then
			return { reaction = "Status", say = statusLine(plant) }
		end
		return { reaction = phrase.reaction }
	end

	-- Unrecognised: the plant repeats it back. Only ever show filtered text,
	-- and only to players allowed to use free-form text.
	if not canChat[player] then
		return { reaction = "Confused" }
	end
	local filtered = filterForPlayer(player, trimmed)
	if not filtered then
		return { reaction = "Confused" }
	end
	return { reaction = "Echo", say = filtered }
end

local function handleGetState(player: Player): Types.Snapshot?
	if not stateLimiter:allow(player) then
		return nil
	end
	local profile = DataService.waitForProfile(player, 60)
	if not profile then
		return nil
	end
	local state = snapshot(player, profile)
	if welcomeBack[player] then
		welcomeBack[player] = nil
		state.welcomeBack = true
	end
	return state
end

local function onProfileLoaded(player: Player, profile: Types.Profile)
	local serverNow = now()
	local plant = profile.plant
	if plant.updatedAt <= 0 then
		plant.updatedAt = serverNow
	elseif serverNow - plant.updatedAt >= PlantConfig.WelcomeBackAfter then
		welcomeBack[player] = true
	end
	-- Time spent away decays at the gentler offline rate.
	profile.plant = NeedsMath.advance(plant, serverNow, true)

	local ok, allowed = pcall(function()
		return TextChatService:CanUserChatAsync(player.UserId)
	end)
	canChat[player] = if ok then allowed == true else RunService:IsStudio()
	if player.Parent then
		pushState(player)
	end
end

local function onPlayerRemoving(player: Player)
	careLimiter:remove(player)
	interactLimiter:remove(player)
	talkLimiter:remove(player)
	stateLimiter:remove(player)
	lastActionAt[player] = nil
	dirty[player] = nil
	welcomeBack[player] = nil
	canChat[player] = nil
end

function PlantService.init()
	stateUpdate = Net.event("StateUpdate")

	Net.func("GetState").OnServerInvoke = handleGetState
	Net.func("Care").OnServerInvoke = handleCare
	Net.func("Talk").OnServerInvoke = handleTalk
	Net.event("Interact").OnServerEvent:Connect(handleInteract)

	DataService.ProfileLoaded:Connect(onProfileLoaded)
	-- Save "online" decay up to the moment of saving, so the next load only
	-- applies offline rates to time actually spent away.
	DataService.addBeforeSaveHook(function(_player, profile)
		currentPlant(profile)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function PlantService.start()
	while true do
		task.wait(1)
		for player in dirty do
			pushState(player)
		end
	end
end

return PlantService
