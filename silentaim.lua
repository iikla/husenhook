local Config = getgenv().SilentAimConfig or {
	Enabled = false,
	InstantBullet = false,
	FOVCircleEnabled = false,
	FOVSize = 90,
	FOVColor = Color3.fromRGB(255, 255, 255),
	VisibleCheck = false,
	HitPart = "Head",
}

local BodyParts = {
	Head = "Head",
	Torso = "Torso",
	LeftArm = "Left Arm",
	RightArm = "Right Arm",
	LeftLeg = "Left Leg",
	RightLeg = "Right Leg",
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = Config.FOVCircleEnabled
FOVCircle.Color = Config.FOVColor
FOVCircle.Radius = Config.FOVSize
FOVCircle.Transparency = 1
FOVCircle.Filled = false
FOVCircle.NumSides = 64
FOVCircle.Position = UserInputService:GetMouseLocation()

RunService.PostSimulation:Connect(function()
	FOVCircle.Position = UserInputService:GetMouseLocation()
end)

local function GetClosestTarget()
	local PartName = BodyParts[Config.HitPart] or "Head"
	local MousePos = UserInputService:GetMouseLocation()
	local BestDistance = Config.FOVSize
	local ClosestEntity
	local TargetPart

	local Entities = {}

	for _, Entity in workspace.Spawned.Enemies:GetChildren() do
		if Entity:IsA("Model") then
			Entities[#Entities + 1] = Entity
		end
	end

	for _, Player in Players:GetPlayers() do
		if Player ~= LocalPlayer then
			local Character = Player.Character
			if Character then
				Entities[#Entities + 1] = Character
			end
		end
	end

	for _, Entity in Entities do
		local Part = Entity:FindFirstChild(PartName)
		if not Part then continue end

		local ScreenPos, OnScreen = Camera:WorldToScreenPoint(Part.Position)
		if not OnScreen or ScreenPos.Z <= 0 then continue end

		if Config.VisibleCheck then
			local RayParams = RaycastParams.new()
			RayParams.FilterDescendantsInstances = { workspace.Spawned, LocalPlayer.Character }
			RayParams.FilterType = Enum.RaycastFilterType.Exclude
			local RayResult = workspace:Raycast(Camera.CFrame.Position, Part.Position - Camera.CFrame.Position, RayParams)
			if RayResult and RayResult.Instance ~= Part then continue end
		end

		local ScreenDistance = (Vector2.new(ScreenPos.X, ScreenPos.Y) - MousePos).Magnitude

		if ScreenDistance < BestDistance then
			BestDistance = ScreenDistance
			ClosestEntity = Entity
			TargetPart = Part
		end
	end

	return ClosestEntity, TargetPart
end

if not LocalPlayer:GetAttribute("Loaded") then
	LocalPlayer:GetAttributeChangedSignal("Loaded"):Wait()
end

local RayMouse = require(game:GetService("ReplicatedStorage").Modules.Shared.RayUtils.RayMouse)
local Projectile = require(game:GetService("ReplicatedStorage").Modules.Client.Behaviours.BehaviourGunClient.ProjectileEnvConstructors.Projectile)
local RemoteCommunicateGun = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("EventsReplication"):WaitForChild("CommunicateGun")

local OldGetMousePos
OldGetMousePos = hookfunction(RayMouse.GetMousePosition, newcclosure(function(...)
	if not Config.Enabled then
		return OldGetMousePos(...)
	end
	local Source = debug.traceback()
	if Source and Source:find("BehaviourGunClient") then
		local _, Part = GetClosestTarget()
		if Part then
			return Part.Position
		end
	end
	return OldGetMousePos(...)
end))

local HookedFireTables = {}

local function HookFireTable(Table)
	if typeof(Table) ~= "table" or typeof(Table.Fire) ~= "function" then
		return
	end
	if HookedFireTables[Table] then
		return
	end
	HookedFireTables[Table] = true

	local OldFire
	OldFire = hookfunction(Table.Fire, newcclosure(function(Rotation, Spread, FiremodeEnv)
		if not Config.Enabled then
			return OldFire(Rotation, Spread, FiremodeEnv)
		end

		local _, Part = GetClosestTarget()

		if Part and Config.InstantBullet then
			RemoteCommunicateGun:FireServer("Hit", Rotation, Part, Part.Position)
			return
		end

		return OldFire(Rotation, Spread, FiremodeEnv)
	end))
end

local OldProjectile
OldProjectile = hookfunction(Projectile, newcclosure(function(...)
	local Table = OldProjectile(...)
	HookFireTable(Table)
	return Table
end))

for _, Table in filtergc("table", { Keys = { "Fire", "Cleanup" } }) do
	HookFireTable(Table)
end

return Config
