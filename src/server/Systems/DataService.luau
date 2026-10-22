--!strict
-- Owns player save data. Gameplay code reads and mutates the in-memory profile
-- (DataService.getProfile) and never touches DataStores directly.
--
-- Safety: every call is retried with backoff; loads claim a session lock inside
-- UpdateAsync so two servers can never own the same profile; saves happen on an
-- autosave timer, on leave, and on shutdown. If a load fails in a live game the
-- player is kicked rather than handed a blank profile that would overwrite theirs.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Shared.Types)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ProfileTemplate = require(script.Parent.Parent.Data.ProfileTemplate)

local STORE_NAME = "PlayerProfiles_v1"
local SCHEMA_VERSION = 1
local AUTOSAVE_INTERVAL = 60
local LOCK_STALE_SECONDS = AUTOSAVE_INTERVAL * 2.5
local IS_STUDIO = RunService:IsStudio()
local LOAD_ATTEMPTS = if IS_STUDIO then 2 else 6
local SAVE_ATTEMPTS = 4
local LOCKED_RETRY_SECONDS = 5
local SHUTDOWN_TIMEOUT = if IS_STUDIO then 5 else 25

-- Unique per server (game.JobId is empty in Studio).
local SESSION_ID = HttpService:GenerateGUID(false)

-- [fromVersion] = function(data) -> data at fromVersion + 1
local MIGRATIONS: { [number]: (any) -> any } = {}

type Lock = { sessionId: string, time: number }
type Record = { data: any?, lock: Lock? }

local DataService = {}

DataService.ProfileLoaded = Signal.new() :: Signal.Signal<Player, Types.Profile>

local store: DataStore? = nil
local profiles: { [Player]: Types.Profile } = {}
-- Studio-only fallback profiles that must never be written back.
local unsaved: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}
local nextAutosave: { [Player]: number } = {}
local beforeSaveHooks: { (Player, Types.Profile) -> () } = {}

local function deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[key] = deepCopy(child)
	end
	return copy :: any
end

-- Fills in any keys the template has that the saved data lacks.
local function reconcile(data: { [any]: any }, template: { [any]: any })
	for key, default in template do
		if data[key] == nil then
			data[key] = deepCopy(default)
		elseif typeof(default) == "table" and typeof(data[key]) == "table" then
			reconcile(data[key], default)
		end
	end
end

local function migrate(data: any): Types.Profile
	data.version = data.version or 1
	while data.version < SCHEMA_VERSION do
		local step = MIGRATIONS[data.version]
		if not step then
			error(`missing data migration from v{data.version}`)
		end
		data = step(data)
		data.version += 1
	end
	reconcile(data, ProfileTemplate :: any)
	return data
end

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

local function loadProfile(player: Player): (Types.Profile?, string)
	local dataStore = store
	if not dataStore then
		return nil, "DataStore unavailable"
	end

	local status = "error"
	for attempt = 1, LOAD_ATTEMPTS do
		local loaded: Types.Profile? = nil
		local ok, err = pcall(function()
			dataStore:UpdateAsync(keyFor(player), function(stored: Record?): Record?
				local now = os.time()
				local record: Record = stored or {}
				local lock = record.lock
				if lock and lock.sessionId ~= SESSION_ID and now - lock.time < LOCK_STALE_SECONDS then
					status = "locked"
					return nil
				end
				local data = if record.data then migrate(record.data) else deepCopy(ProfileTemplate)
				record.data = data
				record.lock = { sessionId = SESSION_ID, time = now }
				status = "ok"
				loaded = data
				return record
			end)
		end)

		if ok and status == "ok" and loaded then
			return loaded, status
		end
		if not ok then
			status = tostring(err)
			warn(`[DataService] load attempt {attempt}/{LOAD_ATTEMPTS} for {player.Name} failed: {err}`)
		end
		if not player.Parent then
			return nil, "left"
		end
		if attempt < LOAD_ATTEMPTS then
			task.wait(if status == "locked" then LOCKED_RETRY_SECONDS else math.min(2 ^ (attempt - 1), 16))
		end
	end
	return nil, status
end

local function saveProfile(player: Player, release: boolean): boolean
	local dataStore = store
	local profile = profiles[player]
	if not dataStore or not profile or unsaved[player] then
		return false
	end

	-- Never run two saves for one player at once; wait for the current one.
	local waited = 0
	while saving[player] and waited < 30 do
		waited += task.wait(0.1)
	end
	saving[player] = true

	for _, hook in beforeSaveHooks do
		local ok, err = pcall(function(): any
			hook(player, profile)
			return nil
		end)
		if not ok then
			warn(`[DataService] before-save hook failed: {err}`)
		end
	end

	local saved = false
	for attempt = 1, SAVE_ATTEMPTS do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(keyFor(player), function(stored: Record?): Record?
				local record: Record = stored or {}
				local lock = record.lock
				if lock and lock.sessionId ~= SESSION_ID then
					-- Another server took over this profile; never overwrite its data.
					return nil
				end
				record.data = profile
				record.lock = if release then nil else { sessionId = SESSION_ID, time = os.time() }
				return record
			end)
		end)
		if ok then
			saved = true
			break
		end
		warn(`[DataService] save attempt {attempt}/{SAVE_ATTEMPTS} for {player.Name} failed: {err}`)
		if attempt < SAVE_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end

	saving[player] = nil
	return saved
end

local function onPlayerAdded(player: Player)
	local profile, reason = loadProfile(player)

	if not player.Parent then
		-- Left while loading: release the lock we just claimed.
		if profile then
			profiles[player] = profile
			saveProfile(player, true)
			profiles[player] = nil
		end
		return
	end

	if not profile then
		if IS_STUDIO then
			warn(`[DataService] using a temporary UNSAVED profile in Studio ({reason}). Enable Studio API access to test saving.`)
			profile = deepCopy(ProfileTemplate)
			unsaved[player] = true
		else
			player:Kick("We couldn't load your plant right now. Please rejoin in a moment!")
			return
		end
	end

	local loadedProfile = profile :: Types.Profile
	profiles[player] = loadedProfile
	-- Stagger autosaves so players don't all save on the same tick.
	nextAutosave[player] = os.clock() + AUTOSAVE_INTERVAL + (player.UserId % AUTOSAVE_INTERVAL)
	DataService.ProfileLoaded:Fire(player, loadedProfile)
end

local function onPlayerRemoving(player: Player)
	nextAutosave[player] = nil
	if profiles[player] then
		saveProfile(player, true)
	end
	profiles[player] = nil
	unsaved[player] = nil
end

function DataService.getProfile(player: Player): Types.Profile?
	return profiles[player]
end

-- Yields until the player's profile is loaded; nil if they leave or it times out.
function DataService.waitForProfile(player: Player, timeout: number): Types.Profile?
	local waited = 0
	while not profiles[player] and player.Parent and waited < timeout do
		waited += task.wait(0.1)
	end
	return profiles[player]
end

-- Runs right before every save, e.g. to bring time-based state up to date.
function DataService.addBeforeSaveHook(hook: (Player, Types.Profile) -> ())
	table.insert(beforeSaveHooks, hook)
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[DataService] could not open DataStore: {result}`)
	end
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < SHUTDOWN_TIMEOUT do
			task.wait(0.1)
		end
	end)

	while true do
		task.wait(5)
		local now = os.clock()
		for player, dueAt in nextAutosave do
			if now >= dueAt and not saving[player] then
				nextAutosave[player] = now + AUTOSAVE_INTERVAL
				task.spawn(saveProfile, player, false)
			end
		end
	end
end

return DataService
