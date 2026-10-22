--!strict
-- Reusable HUD building blocks: rounded panels, icon buttons, tweens and pulses.

local TweenService = game:GetService("TweenService")

local Build = require(script.Parent.Parent.Parent.Util.Build)
local Theme = require(script.Parent.Theme)

local Widgets = {}

function Widgets.tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

function Widgets.corner(parent: Instance, radius: UDim?)
	Build.new("UICorner", { CornerRadius = radius or UDim.new(0, 18), Parent = parent })
end

function Widgets.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return Build.new("UIStroke", {
		Color = color or Theme.Colors.PanelStroke,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Widgets.panel(props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Colors.Panel
	props.BorderSizePixel = 0
	props.Active = true
	local frame = Build.new("Frame", props)
	Widgets.corner(frame)
	Widgets.stroke(frame)
	return frame
end

function Widgets.label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or Theme.Font
	props.TextColor3 = props.TextColor3 or Theme.Colors.Text
	return Build.new("TextLabel", props)
end

-- Squashes a button slightly while pressed.
function Widgets.pressEffect(button: GuiButton)
	local scale: UIScale = button:FindFirstChildOfClass("UIScale") or Build.new("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		Widgets.tween(scale, 0.08, { Scale = 0.9 })
	end)
	local function release()
		Widgets.tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

export type IconButtonProps = {
	icon: string,
	label: string?,
	size: UDim2,
	color: Color3?,
	round: boolean?,
	parent: Instance,
	layoutOrder: number?,
}

-- An emoji icon with an optional caption underneath.
function Widgets.iconButton(props: IconButtonProps): (TextButton, TextLabel, TextLabel?)
	local button: TextButton = Build.new("TextButton", {
		Size = props.size,
		BackgroundColor3 = props.color or Theme.Colors.Panel,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.layoutOrder or 0,
		Parent = props.parent,
	})
	Widgets.corner(button, if props.round then UDim.new(1, 0) else UDim.new(0, 18))
	Widgets.stroke(button)
	Widgets.pressEffect(button)

	local hasLabel = props.label ~= nil
	local icon = Widgets.label({
		Size = UDim2.fromScale(1, if hasLabel then 0.6 else 0.8),
		Position = UDim2.fromScale(0, if hasLabel then 0.08 else 0.1),
		Text = props.icon,
		TextScaled = true,
		Parent = button,
	})
	local caption: TextLabel? = nil
	if props.label then
		caption = Widgets.label({
			Size = UDim2.fromScale(1, 0.26),
			Position = UDim2.fromScale(0, 0.68),
			Text = props.label,
			TextScaled = true,
			Parent = button,
		})
	end
	return button, icon, caption
end

-- Gently pulses an element's stroke to draw attention. Returns a stop function.
function Widgets.pulse(target: GuiObject): () -> ()
	-- An overlay carries the glow, since an object only renders one UIStroke.
	local overlay: Frame = Build.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = target.ZIndex + 1,
		Parent = target,
	})
	local targetCorner = target:FindFirstChildOfClass("UICorner")
	Widgets.corner(overlay, if targetCorner then targetCorner.CornerRadius else nil)
	local stroke: UIStroke = Build.new("UIStroke", {
		Color = Theme.Colors.Highlight,
		Thickness = 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = overlay,
	})
	local tween = TweenService:Create(
		stroke,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Thickness = 9, Transparency = 0.4 }
	)
	tween:Play()
	return function()
		tween:Cancel()
		overlay:Destroy()
	end
end

return Widgets
