--!strict
-- Minimal signal for module-to-module events. Handlers run in their own thread,
-- so one erroring or yielding handler never blocks the others.

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { [Connection]: (T...) -> () } = {}

	local signal = {}

	function signal.Connect(_self: Signal<T...>, handler: (T...) -> ()): Connection
		local connection = {} :: Connection
		function connection.Disconnect(_conn: Connection)
			handlers[connection] = nil
		end
		handlers[connection] = handler
		return connection
	end

	function signal.Fire(_self: Signal<T...>, ...: T...)
		for _, handler in table.clone(handlers) do
			task.spawn(handler, ...)
		end
	end

	return (signal :: any) :: Signal<T...>
end

return Signal
