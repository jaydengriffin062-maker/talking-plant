--!strict
-- Types that cross the client/server boundary or are shared between systems.

export type NeedName = "water" | "nutrients" | "energy" | "cleanliness"

export type PlantState = {
	needs: { [string]: number },
	affection: number,
	asleep: boolean,
	-- Unix time (workspace:GetServerTimeNow) the needs were last brought up to date.
	updatedAt: number,
}

export type Profile = {
	version: number,
	coins: number,
	tutorialDone: boolean,
	plant: PlantState,
	stats: { [string]: number },
}

-- What the client is told about its own player.
export type Snapshot = {
	coins: number,
	plant: PlantState,
	tutorialDone: boolean,
	canChat: boolean,
	welcomeBack: boolean?,
}

export type CareAction = "Water" | "Feed" | "Clean" | "Sleep"

export type CareResult = {
	ok: boolean,
	reason: string?,
	reaction: string?,
	coins: number?,
}

export type TalkResult = {
	reaction: string,
	say: string?,
}

export type InteractKind = "Pet" | "Rub" | "Tickle" | "Poke" | "TapPot" | "Shake" | "PullLeaf"

return {}
