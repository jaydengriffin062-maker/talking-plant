--!strict
-- Tiny helpers for building instances from property tables.

local Build = {}

-- Creates `className`, assigns `props` (Parent last) and parents `children`.
function Build.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className) :: any
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- An anchored, non-colliding decorative part.
function Build.part(props: { [string]: any }): BasePart
	local defaults: { [string]: any } = {
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}
	for key, value in props do
		defaults[key] = value
	end
	local className = defaults.ClassName or "Part"
	defaults.ClassName = nil
	return Build.new(className, defaults)
end

-- A part rendered as an ellipsoid of the given size (SpecialMesh sphere).
function Build.ellipsoid(props: { [string]: any }): BasePart
	local part = Build.part(props)
	Build.new("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = part })
	return part
end

-- A vertical cylinder (Roblox cylinders run along X, so it is rotated upright).
function Build.cylinder(props: { [string]: any }, center: CFrame, height: number, diameter: number): BasePart
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = center * CFrame.Angles(0, 0, math.pi / 2)
	return Build.part(props)
end

return Build
