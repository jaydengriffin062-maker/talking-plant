--!strict
-- Thin access layer over the remotes listed in Remotes.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(script.Parent.Remotes)

local FOLDER_NAME = "Remotes"

local Net = {}

function Net.setup()
	assert(RunService:IsServer(), "Net.setup is server-only")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in Remotes.Events do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in Remotes.Functions do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

local function getRemote(name: string): Instance
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name)
end

function Net.event(name: string): RemoteEvent
	local remote = getRemote(name)
	assert(remote:IsA("RemoteEvent"), `{name} is not a RemoteEvent`)
	return remote
end

function Net.func(name: string): RemoteFunction
	local remote = getRemote(name)
	assert(remote:IsA("RemoteFunction"), `{name} is not a RemoteFunction`)
	return remote
end

return Net
