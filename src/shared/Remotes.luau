--!strict
-- The single list of remotes. The server creates them all at startup (see Net.setup).
--
-- Events:
--   StateUpdate  server -> client  (Snapshot)
--   Interact     client -> server  (InteractKind)  touch gestures; affection only
-- Functions:
--   GetState     client -> server  -> Snapshot
--   Care         client -> server  (CareAction) -> CareResult
--   Talk         client -> server  (text) -> TalkResult

return {
	Events = { "StateUpdate", "Interact" },
	Functions = { "GetState", "Care", "Talk" },
}
