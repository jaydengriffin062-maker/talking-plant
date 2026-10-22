--!strict
-- Talk to the plant: quick-phrase chips (always) plus a free-text box for
-- players whose account allows free-form text. Everything echoed back by the
-- plant is filtered on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TalkConfig = require(ReplicatedStorage.Shared.Config.TalkConfig)

local Build = require(script.Parent.Parent.Parent.Util.Build)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

export type TalkPanel = {
	setOpen: (self: TalkPanel, open: boolean) -> (),
	isOpen: (self: TalkPanel) -> boolean,
	setCanChat: (self: TalkPanel, canChat: boolean) -> (),
}

local WIDTH = 520
local CHIP_HEIGHT = 44
local INPUT_HEIGHT = 48
local OPEN_Y = -(Theme.Gap * 2 + Theme.NavHeight)

local TalkPanel = {}

function TalkPanel.new(parent: Instance, onSend: (text: string) -> ()): TalkPanel
	local frame = Widgets.panel({
		Name = "TalkPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(0, WIDTH, 0, CHIP_HEIGHT + 24),
		Position = UDim2.new(0.5, 0, 1, 200),
		Visible = false,
		Parent = parent,
	})
	Build.new("UISizeConstraint", { MaxSize = Vector2.new(WIDTH, math.huge), Parent = frame })
	Build.new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = frame,
	})

	local chips: ScrollingFrame = Build.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, CHIP_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = frame,
	})
	Build.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = chips,
	})
	for index, phrase in TalkConfig.QuickPhrases do
		local chip: TextButton = Build.new("TextButton", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, -4),
			BackgroundColor3 = Theme.Colors.Accent,
			AutoButtonColor = false,
			Font = Theme.Font,
			TextSize = 20,
			TextColor3 = Color3.new(1, 1, 1),
			Text = phrase,
			LayoutOrder = index,
			Parent = chips,
		})
		Widgets.corner(chip, UDim.new(1, 0))
		Build.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = chip })
		Widgets.pressEffect(chip)
		chip.Activated:Connect(function()
			onSend(phrase)
		end)
	end

	local inputRow = Build.new("Frame", {
		Size = UDim2.new(1, 0, 0, INPUT_HEIGHT),
		Position = UDim2.fromOffset(0, CHIP_HEIGHT + 10),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = frame,
	})
	local box: TextBox = Build.new("TextBox", {
		Size = UDim2.new(1, -60, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font,
		TextSize = 20,
		TextColor3 = Theme.Colors.Text,
		PlaceholderText = "Say something to your plant...",
		PlaceholderColor3 = Theme.Colors.SubtleText,
		Text = "",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = inputRow,
	})
	Widgets.corner(box, UDim.new(0, 14))
	Widgets.stroke(box, Theme.Colors.BarBackground, 2)
	Build.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = box })

	local send, _sendIcon = Widgets.iconButton({
		icon = "➤",
		size = UDim2.fromOffset(INPUT_HEIGHT, INPUT_HEIGHT),
		color = Theme.Colors.Accent,
		parent = inputRow,
	})
	send.AnchorPoint = Vector2.new(1, 0)
	send.Position = UDim2.fromScale(1, 0)

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if utf8.len(box.Text) and (utf8.len(box.Text) :: number) > TalkConfig.MaxLength then
			box.Text = string.sub(box.Text, 1, (utf8.offset(box.Text, TalkConfig.MaxLength + 1) :: number) - 1)
		end
	end)

	local function submit()
		local text = string.match(box.Text, "^%s*(.-)%s*$") or ""
		if text ~= "" then
			box.Text = ""
			onSend(text)
		end
	end
	send.Activated:Connect(submit)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)

	local open = false
	local canChat = false
	local panel = {}

	local function openHeight(): number
		return CHIP_HEIGHT + 24 + (if canChat then INPUT_HEIGHT + 10 else 0)
	end

	function panel.setOpen(_self: TalkPanel, value: boolean)
		if value == open then
			return
		end
		open = value
		if value then
			frame.Visible = true
			Widgets.tween(frame, 0.3, { Position = UDim2.new(0.5, 0, 1, OPEN_Y) }, Enum.EasingStyle.Back)
		else
			box:ReleaseFocus()
			local slide = Widgets.tween(frame, 0.2, { Position = UDim2.new(0.5, 0, 1, openHeight() + 40) })
			slide.Completed:Once(function()
				if not open then
					frame.Visible = false
				end
			end)
		end
	end

	function panel.isOpen(_self: TalkPanel): boolean
		return open
	end

	function panel.setCanChat(_self: TalkPanel, value: boolean)
		canChat = value
		inputRow.Visible = value
		frame.Size = UDim2.new(1, -Theme.Gap * 2, 0, openHeight())
	end

	panel.setCanChat(panel :: any, false)
	return (panel :: any) :: TalkPanel
end

return TalkPanel
