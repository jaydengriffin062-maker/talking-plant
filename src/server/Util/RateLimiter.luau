--!strict
-- Per-player token bucket for remote handlers.

export type RateLimiter = {
	allow: (self: RateLimiter, player: Player) -> boolean,
	remove: (self: RateLimiter, player: Player) -> (),
}

type Bucket = { tokens: number, updatedAt: number }

local RateLimiter = {}

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	local buckets: { [Player]: Bucket } = {}
	local limiter = {}

	function limiter.allow(_self: RateLimiter, player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket then
			bucket = { tokens = capacity, updatedAt = now }
			buckets[player] = bucket
		end
		bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.updatedAt) * refillPerSecond)
		bucket.updatedAt = now
		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end

	function limiter.remove(_self: RateLimiter, player: Player)
		buckets[player] = nil
	end

	return (limiter :: any) :: RateLimiter
end

return RateLimiter
