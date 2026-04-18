local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {
    Settings = {
        Enabled = true,
        MaxDistance = 1500,
        TeamCheck = true,
        TextFont = 2,
        TextSize = 13,
        
        Enemy = {
            Box = { Enabled = true, Color = Color3.fromRGB(255, 255, 255) },
            HealthBar = { Enabled = true, ColorLow = Color3.fromRGB(255, 0, 0), ColorHigh = Color3.fromRGB(0, 255, 0) },
            Name = { Enabled = true, Color = Color3.fromRGB(255, 255, 255) },
            Distance = { Enabled = true, Color = Color3.fromRGB(200, 200, 200) },
            Weapon = { Enabled = true, Color = Color3.fromRGB(200, 200, 200) },
            OOF = { Enabled = false, Radius = 300, Size = 15, Color = Color3.fromRGB(255, 0, 0) }
        },
        Team = {
            Box = { Enabled = false, Color = Color3.fromRGB(0, 255, 0) },
            HealthBar = { Enabled = false, ColorLow = Color3.fromRGB(255, 0, 0), ColorHigh = Color3.fromRGB(0, 255, 0) },
            Name = { Enabled = false, Color = Color3.fromRGB(0, 255, 0) },
            Distance = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            Weapon = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            OOF = { Enabled = false, Radius = 300, Size = 15, Color = Color3.fromRGB(0, 255, 0) }
        }
    },
    Cache = {},
    Connections = {}
}

-- Utility Functions
local function Draw(type, properties)
    local obj = Drawing.new(type)
    for k, v in pairs(properties or {}) do
        obj[k] = v
    end
    return obj
end

local function Round(num)
    return math.floor(num + 0.5)
end

-- Initializes Drawings for a player
function ESP:Add(Player)
    if Player == LocalPlayer then return end
    
    local Objects = {
        BoxOutline = Draw("Square", {Thickness = 3, Filled = false, Color = Color3.new(0, 0, 0), ZIndex = 1}),
        Box = Draw("Square", {Thickness = 1, Filled = false, ZIndex = 2}),
        
        HealthOutline = Draw("Square", {Thickness = 3, Filled = false, Color = Color3.new(0, 0, 0), ZIndex = 1}),
        HealthBar = Draw("Square", {Thickness = 1, Filled = true, ZIndex = 2}),
        
        Name = Draw("Text", {Center = true, Outline = true, ZIndex = 3}),
        Distance = Draw("Text", {Center = true, Outline = true, ZIndex = 3}),
        Weapon = Draw("Text", {Center = true, Outline = true, ZIndex = 3}),
        
        Arrow = Draw("Triangle", {Filled = true, ZIndex = 3})
    }
    
    self.Cache[Player] = Objects
end

-- Cleans Drawings
function ESP:Remove(Player)
    if self.Cache[Player] then
        for _, obj in pairs(self.Cache[Player]) do
            obj:Remove()
        end
        self.Cache[Player] = nil
    end
end

-- Unloads everything cleanly if hot-reloading
function ESP:Unload()
    for _, conn in pairs(self.Connections) do
        conn:Disconnect()
    end
    for plr, _ in pairs(self.Cache) do
        self:Remove(plr)
    end
end

-- Main Render Loop
function ESP:Update()
    for player, objs in pairs(self.Cache) do
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        
        -- Determine Team Configuration (if neutral, treats as enemy usually)
        local isTeammate = player.Team == LocalPlayer.Team and player.Team ~= nil
        local config = isTeammate and self.Settings.Team or self.Settings.Enemy
        local pass = self.Settings.Enabled and character and humanoid and humanoid.Health > 0 and hrp and true or false
        
        if self.Settings.TeamCheck and isTeammate then pass = false end

        local dist = hrp and (hrp.Position - Camera.CFrame.Position).Magnitude or 0
        if dist > self.Settings.MaxDistance then pass = false end

        -- Projection Math
        local onScreen = false
        local minX, maxX, minY, maxY = 0, 0, 0, 0
        
        if pass then
            local rootPos, vis = Camera:WorldToViewportPoint(hrp.Position)
            onScreen = vis
            
            if onScreen then
                -- Get bounds proportional to scale/distance
                local headPos = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.5, 0))
                local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                local height = math.abs(headPos.Y - legPos.Y)
                local width = height * 0.6
                
                minX, maxX = headPos.X - (width/2), headPos.X + (width/2)
                minY, maxY = headPos.Y, legPos.Y
            end
        end

        local function setVisibility(visible)
            for k, obj in pairs(objs) do
                if k == "Arrow" and config.OOF.Enabled and pass and not onScreen then
                    -- Handled specifically
                else
                    obj.Visible = visible
                end
            end
        end

        -- Off-screen Indicators (OOF)
        if pass and not onScreen and config.OOF.Enabled then
            local proj = Camera.CFrame:PointToObjectSpace(hrp.Position)
            local ang = math.atan2(proj.Z, proj.X)
            local dir = Vector2.new(math.cos(ang), math.sin(ang))
            
            local center = Camera.ViewportSize / 2
            local a = (dir * config.OOF.Radius) + center
            local arrowSize = config.OOF.Size
            
            -- Rotate corners
            local function rotateVec(vec, r)
                return Vector2.new(math.cos(r)*vec.X - math.sin(r)*vec.Y, math.sin(r)*vec.X + math.cos(r)*vec.Y)
            end
            
            local b = a - rotateVec(dir, math.rad(30)) * arrowSize
            local c = a - rotateVec(dir, -math.rad(30)) * arrowSize
            
            objs.Arrow.PointA = a
            objs.Arrow.PointB = b
            objs.Arrow.PointC = c
            objs.Arrow.Color = config.OOF.Color
            objs.Arrow.Visible = true
            
            setVisibility(false) -- Hide everything else
            continue
        else
            objs.Arrow.Visible = false
        end

        if not (pass and onScreen) then
            setVisibility(false)
            continue
        end

        -- Map Layout
        local size = Vector2.new(maxX - minX, maxY - minY)
        local pos = Vector2.new(minX, minY)
        local healthPct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)

        -- Box
        if config.Box.Enabled then
            objs.Box.Size = size
            objs.Box.Position = pos
            objs.Box.Color = config.Box.Color
            objs.Box.Visible = true

            objs.BoxOutline.Size = size
            objs.BoxOutline.Position = pos
            objs.BoxOutline.Visible = true
        else
            objs.Box.Visible = false
            objs.BoxOutline.Visible = false
        end

        -- Health
        if config.HealthBar.Enabled then
            local barHeight = size.Y * healthPct
            local barOffset = Vector2.new(pos.X - 5, maxY - barHeight)
            local healthColor = config.HealthBar.ColorLow:Lerp(config.HealthBar.ColorHigh, healthPct)

            objs.HealthBar.Size = Vector2.new(2, barHeight)
            objs.HealthBar.Position = barOffset
            objs.HealthBar.Color = healthColor
            objs.HealthBar.Visible = true

            objs.HealthOutline.Size = Vector2.new(4, size.Y + 2)
            objs.HealthOutline.Position = Vector2.new(pos.X - 6, pos.Y - 1)
            objs.HealthOutline.Visible = true
        else
            objs.HealthBar.Visible = false
            objs.HealthOutline.Visible = false
        end

        -- Name
        if config.Name.Enabled then
            objs.Name.Text = player.Name
            objs.Name.Font = self.Settings.TextFont
            objs.Name.Size = self.Settings.TextSize
            objs.Name.Color = config.Name.Color
            objs.Name.Position = Vector2.new(pos.X + (size.X / 2), pos.Y - objs.Name.TextBounds.Y - 2)
            objs.Name.Visible = true
        else
            objs.Name.Visible = false
        end
        
        -- Tracker for bottom elements
        local bottomOffset = pos.Y + size.Y + 2

        -- Weapon
        if config.Weapon.Enabled then
            local tool = character:FindFirstChildOfClass("Tool")
            if tool then
                objs.Weapon.Text = tostring(tool.Name)
                objs.Weapon.Font = self.Settings.TextFont
                objs.Weapon.Size = self.Settings.TextSize
                objs.Weapon.Color = config.Weapon.Color
                objs.Weapon.Position = Vector2.new(pos.X + (size.X / 2), bottomOffset)
                objs.Weapon.Visible = true
                bottomOffset = bottomOffset + objs.Weapon.TextBounds.Y + 2
            else
                objs.Weapon.Visible = false
            end
        else
            objs.Weapon.Visible = false
        end

        -- Distance
        if config.Distance.Enabled then
            objs.Distance.Text = "[" .. Round(dist/3) .. "m]"
            objs.Distance.Font = self.Settings.TextFont
            objs.Distance.Size = self.Settings.TextSize
            objs.Distance.Color = config.Distance.Color
            objs.Distance.Position = Vector2.new(pos.X + (size.X / 2), bottomOffset)
            objs.Distance.Visible = true
        else
            objs.Distance.Visible = false
        end
    end
end

-- Events Setup
table.insert(ESP.Connections, Players.PlayerAdded:Connect(function(plr)
    ESP:Add(plr)
end))

table.insert(ESP.Connections, Players.PlayerRemoving:Connect(function(plr)
    ESP:Remove(plr)
end))

for _, plr in pairs(Players:GetPlayers()) do
    ESP:Add(plr)
end

table.insert(ESP.Connections, RunService.RenderStepped:Connect(function()
    ESP:Update()
end))

return ESP
