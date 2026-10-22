--!strict
-- Visual feedback around the plant: speech bubble, thought bubble, floating
-- emoji, particle bursts and the occasional fly. Everything is created on demand
-- and cleaned up, except a few reusable emitters and bubbles.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Build = require(script.Parent.Parent.Parent.Util.Build)

local FONT = Enum.Font.FredokaOne
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

export type Effects = {
	say: (self: Effects, text: string, seconds: number) -> (),
	emoji: (self: Effects, symbols: { string }, count: number) -> (),
	play: (self: Effects, name: string) -> (),
	burst: (self: Effects, name: string, amount: number) -> (),
	setThought: (self: Effects, icon: string?) -> (),
	setSleeping: (self: Effects, on: boolean) -> (),
	spawnFly: (self: Effects) -> BasePart,
}

local EMOJI_EFFECTS: { [string]: { symbols: { string }, count: number } } = {
	Hearts = { symbols = { "❤️", "💕", "💖" }, count = 5 },
	Anger = { symbols = { "💢" }, count = 2 },
	Stars = { symbols = { "⭐", "💫" }, count = 4 },
	Notes = { symbols = { "🎵", "🎶" }, count = 4 },
	Zzz = { symbols = { "💤" }, count = 2 },
}

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local defaults: { [string]: any } = {
		Texture = SPARKLE_TEXTURE,
		Rate = 0,
		Enabled = true,
		LightEmission = 0.6,
		SpreadAngle = Vector2.new(180, 180),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(4, 7),
		Size = NumberSequence.new(0.4, 0),
		Parent = parent,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Build.new("ParticleEmitter", defaults)
end

local Effects = {}

function Effects.new(head: BasePart): Effects
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local container = Build.new("Folder", { Name = "PlantEffects", Parent = playerGui })

	-- Particles come from the front of the face.
	local mouthAttachment: Attachment = Build.new("Attachment", {
		Position = Vector3.new(0, -0.4, -1.1),
		Parent = head,
	})
	local emitters: { [string]: ParticleEmitter } = {
		Sparkles = emitter(mouthAttachment, {
			Color = ColorSequence.new(Color3.fromRGB(255, 245, 160)),
			LightEmission = 1,
		}),
		Pollen = emitter(mouthAttachment, {
			Color = ColorSequence.new(Color3.fromRGB(255, 225, 80)),
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(25, 25),
			Speed = NumberRange.new(6, 10),
			Acceleration = Vector3.new(0, -4, 0),
			Size = NumberSequence.new(0.25, 0.1),
		}),
		Bubbles = emitter(mouthAttachment, {
			Color = ColorSequence.new(Color3.fromRGB(200, 235, 255)),
			Speed = NumberRange.new(2, 4),
			Lifetime = NumberRange.new(0.8, 1.4),
			Acceleration = Vector3.new(0, 3, 0),
			Size = NumberSequence.new(0.35, 0.5),
			Transparency = NumberSequence.new(0.2, 1),
		}),
		Confetti = emitter(mouthAttachment, {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 130)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 90)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(110, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 230, 120)),
			}),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(60, 60),
			Speed = NumberRange.new(12, 18),
			Acceleration = Vector3.new(0, -16, 0),
			Lifetime = NumberRange.new(1.2, 1.8),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-200, 200),
			Size = NumberSequence.new(0.35),
		}),
	}

	-- Speech bubble (reused).
	local speech: BillboardGui = Build.new("BillboardGui", {
		Name = "Speech",
		Adornee = head,
		Size = UDim2.fromOffset(320, 160),
		StudsOffset = Vector3.new(0, 3.4, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		Parent = container,
	})
	local bubble: Frame = Build.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = speech,
	}, {
		Build.new("UICorner", { CornerRadius = UDim.new(0, 18) }),
		Build.new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(90, 150, 80) }),
		Build.new("UIPadding", {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
	})
	local bubbleScale: UIScale = Build.new("UIScale", { Scale = 0, Parent = bubble })
	local speechLabel: TextLabel = Build.new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 24,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(50, 60, 50),
		Text = "",
		Parent = bubble,
	}, {
		Build.new("UISizeConstraint", { MaxSize = Vector2.new(280, 140) }),
	})
	local speechToken = 0

	-- Thought bubble for a low need (reused).
	local thought: BillboardGui = Build.new("BillboardGui", {
		Name = "Thought",
		Adornee = head,
		Size = UDim2.fromOffset(64, 64),
		StudsOffset = Vector3.new(2.6, 1.8, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		Parent = container,
	})
	local thoughtFrame: Frame = Build.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = thought,
	}, {
		Build.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Build.new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(150, 170, 200) }),
	})
	local thoughtLabel: TextLabel = Build.new("TextLabel", {
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.15, 0.15),
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = "",
		Parent = thoughtFrame,
	})
	TweenService:Create(
		thought,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffset = Vector3.new(2.6, 2.1, 0) }
	):Play()

	local sleeping = false

	local effects = {}

	function effects.say(_self: Effects, text: string, seconds: number)
		speechToken += 1
		local token = speechToken
		speechLabel.Text = text
		speech.Enabled = true
		bubbleScale.Scale = 0.3
		TweenService:Create(bubbleScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(seconds, function()
			if token == speechToken then
				local shrink = TweenService:Create(bubbleScale, TweenInfo.new(0.15), { Scale = 0 })
				shrink:Play()
				shrink.Completed:Wait()
				if token == speechToken then
					speech.Enabled = false
				end
			end
		end)
	end

	function effects.emoji(_self: Effects, symbols: { string }, count: number)
		for i = 1, count do
			task.delay((i - 1) * 0.12, function()
				local start = Vector3.new((math.random() - 0.5) * 3, math.random() * 0.8 + 0.4, 0)
				local gui: BillboardGui = Build.new("BillboardGui", {
					Adornee = head,
					Size = UDim2.fromOffset(44, 44),
					StudsOffset = start,
					AlwaysOnTop = true,
					LightInfluence = 0,
					Parent = container,
				})
				local label: TextLabel = Build.new("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					TextScaled = true,
					Text = symbols[math.random(1, #symbols)],
					Parent = gui,
				})
				local info = TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				TweenService:Create(gui, info, { StudsOffset = start + Vector3.new((math.random() - 0.5) * 1.5, 2.6, 0) }):Play()
				TweenService:Create(label, info, { TextTransparency = 1, Rotation = (math.random() - 0.5) * 40 }):Play()
				Debris:AddItem(gui, 1.4)
			end)
		end
	end

	function effects.burst(_self: Effects, name: string, amount: number)
		local particle = emitters[name]
		if particle then
			particle:Emit(amount)
		end
	end

	function effects.play(self: Effects, name: string)
		local emoji = EMOJI_EFFECTS[name]
		if emoji then
			self:emoji(emoji.symbols, emoji.count)
		elseif name == "Confetti" then
			self:burst("Confetti", 60)
			self:burst("Sparkles", 20)
		elseif name == "Bubbles" then
			self:burst("Bubbles", 25)
			self:burst("Sparkles", 10)
		else
			self:burst(name, 18)
		end
	end

	function effects.setThought(_self: Effects, icon: string?)
		thought.Enabled = icon ~= nil
		thoughtLabel.Text = icon or ""
	end

	-- Drifting "z"s while asleep.
	function effects.setSleeping(self: Effects, on: boolean)
		if on == sleeping then
			return
		end
		sleeping = on
		if on then
			task.spawn(function()
				while sleeping do
					self:emoji({ "💤" }, 1)
					task.wait(1.6)
				end
			end)
		end
	end

	-- A little fly that buzzes around the head; the caller decides its fate.
	function effects.spawnFly(_self: Effects): BasePart
		local fly = Build.ellipsoid({
			Name = "Fly",
			Size = Vector3.new(0.22, 0.18, 0.18),
			Color = Color3.fromRGB(30, 30, 35),
			CFrame = head.CFrame * CFrame.new(3, 1.5, -1.5),
			Parent = workspace,
		})
		for _, side in { 1, -1 } do
			Build.ellipsoid({
				Size = Vector3.new(0.14, 0.04, 0.2),
				Color = Color3.fromRGB(220, 240, 255),
				Transparency = 0.3,
				CFrame = fly.CFrame * CFrame.new(side * 0.1, 0.1, 0),
				Parent = fly,
			})
		end
		for _, wing in fly:GetChildren() do
			if wing:IsA("BasePart") then
				Build.new("WeldConstraint", { Part0 = fly, Part1 = wing, Parent = wing })
				wing.Anchored = false
			end
		end
		return fly
	end

	return (effects :: any) :: Effects
end

return Effects
