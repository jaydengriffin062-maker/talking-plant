--!strict
-- Sends care and talk requests to the server and plays the plant's answer.
-- Both the HUD and the touch tools go through here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local PlantController = require(script.Parent.PlantController)

local ActionController = {}

ActionController.CoinsEarned = Signal.new() :: Signal.Signal<number>

local careRemote: RemoteFunction
local talkRemote: RemoteFunction
local pending: { [string]: boolean? } = {}

-- Yields for the server's answer. Returns nil if a request is already in flight.
function ActionController.care(action: Types.CareAction): Types.CareResult?
	if pending[action] then
		return nil
	end
	pending[action] = true
	local ok, result = pcall(function()
		return careRemote:InvokeServer(action)
	end)
	pending[action] = nil
	if not ok or typeof(result) ~= "table" then
		return nil
	end
	local careResult = result :: Types.CareResult
	if careResult.reaction then
		PlantController.react(careResult.reaction)
	end
	if action == "Water" and careResult.ok then
		PlantController.wetSoil()
	end
	if careResult.coins and careResult.coins > 0 then
		ActionController.CoinsEarned:Fire(careResult.coins)
	end
	return careResult
end

function ActionController.talk(text: string)
	if pending.Talk then
		return
	end
	pending.Talk = true
	local ok, result = pcall(function()
		return talkRemote:InvokeServer(text)
	end)
	pending.Talk = nil
	if ok and typeof(result) == "table" and typeof(result.reaction) == "string" then
		local talkResult = result :: Types.TalkResult
		PlantController.react(talkResult.reaction, talkResult.say)
	end
end

function ActionController.init()
	careRemote = Net.func("Care")
	talkRemote = Net.func("Talk")
end

return ActionController
