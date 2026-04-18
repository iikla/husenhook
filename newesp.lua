local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local floor = math.floor
local abs = math.abs
local clamp = math.clamp
local cos = math.cos
local sin = math.sin
local atan2 = math.atan2
local rad = math.rad
local V2 = Vector2.new
local V3 = Vector3.new

local ESP = {
    Settings = {
        Enabled = true,
        MaxDistance = 1500,
        TeamCheck = true,
        TextFont = 2,
        TextSize = 13,

        Enemy = {
            Box        = { Enabled = true,  Color = Color3.fromRGB(255, 255, 255) },
            HealthBar  = { Enabled = true,  ColorLow = Color3.fromRGB(255, 0, 0), ColorHigh = Color3.fromRGB(0, 255, 0) },
            Name       = { Enabled = true,  Color = Color3.fromRGB(255, 255, 255) },
            Distance   = { Enabled = true,  Color = Color3.fromRGB(200, 200, 200) },
            Weapon     = { Enabled = true,  Color = Color3.fromRGB(200, 200, 200) },
            OOF        = { Enabled = false, Radius = 300, Size = 15, Color = Color3.fromRGB(255, 0, 0) }
        },
        Team = {
            Box        = { Enabled = false, Color = Color3.fromRGB(0, 255, 0) },
            HealthBar  = { Enabled = false, ColorLow = Color3.fromRGB(255, 0, 0), ColorHigh = Color3.fromRGB(0, 255, 0) },
            Name       = { Enabled = false, Color = Color3.fromRGB(0, 255, 0) },
            Distance   = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            Weapon     = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            OOF        = { Enabled = false, Radius = 300, Size = 15, Color = Color3.fromRGB(0, 255, 0) }
        }
    },
    Cache = {},
    Connections = {}
}

-- Drawing helper
local function Draw(class, props)
    local obj = Drawing.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    return obj
end

-- Create cached drawing objects for a player
function ESP:Add(Player)
    if Player == LocalPlayer then return end

    self.Cache[Player] = {
        -- Box: outline (black border) → inline (colored)
        BoxOutline  = Draw("Square", { Thickness = 3, Filled = false, Color = Color3.new(0, 0, 0), ZIndex = 1 }),
        Box         = Draw("Square", { Thickness = 1, Filled = false, ZIndex = 2 }),

        -- Health bar: outline (black border) → background (dark fill) → bar (colored fill)
        HealthOutline = Draw("Square", { Filled = true, Color = Color3.new(0, 0, 0), ZIndex = 1 }),
        HealthBG      = Draw("Square", { Filled = true, Color = Color3.fromRGB(40, 40, 40), ZIndex = 2 }),
        HealthBar     = Draw("Square", { Filled = true, ZIndex = 3 }),

        -- Text layers
        Name     = Draw("Text", { Center = true, Outline = true, ZIndex = 4 }),
        Distance = Draw("Text", { Center = true, Outline = true, ZIndex = 4 }),
        Weapon   = Draw("Text", { Center = true, Outline = true, ZIndex = 4 }),

        -- Off-screen arrow
        Arrow = Draw("Triangle", { Filled = true, ZIndex = 3 })
    }
end

-- Clean up drawings
function ESP:Remove(Player)
    local cache = self.Cache[Player]
    if not cache then return end
    for _, obj in pairs(cache) do obj:Remove() end
    self.Cache[Player] = nil
end

-- Hot-reload safe teardown
function ESP:Unload()
    for _, c in pairs(self.Connections) do c:Disconnect() end
    for plr in pairs(self.Cache) do self:Remove(plr) end
end

-- Hide all drawings for a player
local function HideAll(objs)
    for _, obj in pairs(objs) do obj.Visible = false end
end

-- Main render loop
function ESP:Update()
    Camera = workspace.CurrentCamera -- refresh in case of respawn

    for player, objs in pairs(self.Cache) do
        local character = player.Character
        local humanoid  = character and character:FindFirstChild("Humanoid")
        local hrp       = character and character:FindFirstChild("HumanoidRootPart")
        local head      = character and character:FindFirstChild("Head")

        -- Determine team flag
        local isTeammate = player.Team ~= nil and player.Team == LocalPlayer.Team
        local config = isTeammate and self.Settings.Team or self.Settings.Enemy

        -- Validity checks
        local alive = humanoid and humanoid.Health > 0
        local pass  = self.Settings.Enabled and character and alive and hrp and head
        if pass and self.Settings.TeamCheck and isTeammate then pass = false end

        local dist = 0
        if pass then
            dist = (hrp.Position - Camera.CFrame.Position).Magnitude
            if dist > self.Settings.MaxDistance then pass = false end
        end

        if not pass then
            HideAll(objs)
            -- Still try OOF arrow even if off-screen
            if self.Settings.Enabled and alive and hrp and config.OOF.Enabled then
                local _, vis = Camera:WorldToViewportPoint(hrp.Position)
                if not vis then
                    -- render OOF arrow below
                    local proj = Camera.CFrame:PointToObjectSpace(hrp.Position)
                    local ang  = atan2(proj.Z, proj.X)
                    local dir  = V2(cos(ang), sin(ang))
                    local center = Camera.ViewportSize / 2
                    local tip = center + dir * config.OOF.Radius
                    local sz  = config.OOF.Size
                    local function rot(v, r) return V2(cos(r)*v.X - sin(r)*v.Y, sin(r)*v.X + cos(r)*v.Y) end
                    objs.Arrow.PointA = tip
                    objs.Arrow.PointB = tip - rot(dir, rad(25)) * sz
                    objs.Arrow.PointC = tip - rot(dir, -rad(25)) * sz
                    objs.Arrow.Color  = config.OOF.Color
                    objs.Arrow.Visible = true
                end
            end
            continue
        end

        -- World-to-screen projection for bounding box
        local _, onScreen = Camera:WorldToViewportPoint(hrp.Position)

        -- OOF arrow when off-screen
        if not onScreen then
            HideAll(objs)
            if config.OOF.Enabled then
                local proj = Camera.CFrame:PointToObjectSpace(hrp.Position)
                local ang  = atan2(proj.Z, proj.X)
                local dir  = V2(cos(ang), sin(ang))
                local center = Camera.ViewportSize / 2
                local tip = center + dir * config.OOF.Radius
                local sz  = config.OOF.Size
                local function rot(v, r) return V2(cos(r)*v.X - sin(r)*v.Y, sin(r)*v.X + cos(r)*v.Y) end
                objs.Arrow.PointA = tip
                objs.Arrow.PointB = tip - rot(dir, rad(25)) * sz
                objs.Arrow.PointC = tip - rot(dir, -rad(25)) * sz
                objs.Arrow.Color  = config.OOF.Color
                objs.Arrow.Visible = true
            end
            continue
        end

        objs.Arrow.Visible = false

        --------------------------------------------------
        -- Bounding Box Calculation (CSGO-style fixed ratio)
        --------------------------------------------------
        -- Project head top and feet bottom to get a pixel-accurate height,
        -- then derive width as a fixed ratio of height (standard CSGO 0.55-0.6)
        local headTop  = Camera:WorldToViewportPoint(head.Position + V3(0, 0.5, 0))
        local feetBot  = Camera:WorldToViewportPoint(hrp.Position - V3(0, 3, 0))

        local boxH = abs(feetBot.Y - headTop.Y)
        local boxW = boxH * 0.55

        -- Center X on head, Y spans from headTop to feetBot
        local centerX = headTop.X
        local boxX = floor(centerX - boxW / 2)
        local boxY = floor(headTop.Y)
        boxW = floor(boxW)
        boxH = floor(boxH)

        local boxPos  = V2(boxX, boxY)
        local boxSize = V2(boxW, boxH)

        local healthPct = clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)

        --------------------------------------------------
        -- Box (outline + inline, 1px each)
        --------------------------------------------------
        if config.Box.Enabled then
            objs.Box.Position  = boxPos
            objs.Box.Size      = boxSize
            objs.Box.Color     = config.Box.Color
            objs.Box.Visible   = true

            objs.BoxOutline.Position = boxPos
            objs.BoxOutline.Size     = boxSize
            objs.BoxOutline.Visible  = true
        else
            objs.Box.Visible = false
            objs.BoxOutline.Visible = false
        end

        --------------------------------------------------
        -- Health Bar (left side, 2px wide, 1px gap from box)
        -- Layout:  [outline 4px] > [bg 2px] > [bar 2px]
        -- The bar grows upward from the bottom.
        --------------------------------------------------
        if config.HealthBar.Enabled then
            local barW       = 2     -- bar fill width
            local outlinePad = 1     -- padding around the bar
            local gap        = 3     -- gap between box left edge and outline right edge

            -- Outline (background border)
            local olX = boxX - gap - barW - outlinePad
            local olY = boxY - outlinePad
            local olW = barW + outlinePad * 2
            local olH = boxH + outlinePad * 2

            objs.HealthOutline.Position = V2(olX, olY)
            objs.HealthOutline.Size     = V2(olW, olH)
            objs.HealthOutline.Visible  = true

            -- Background (dark grey fill inside outline)
            local bgX = olX + outlinePad
            local bgY = olY + outlinePad
            objs.HealthBG.Position = V2(bgX, bgY)
            objs.HealthBG.Size     = V2(barW, boxH)
            objs.HealthBG.Visible  = true

            -- Actual health fill (grows from bottom up)
            local fillH = floor(boxH * healthPct)
            local fillY = bgY + (boxH - fillH)
            local hCol  = config.HealthBar.ColorLow:Lerp(config.HealthBar.ColorHigh, healthPct)

            objs.HealthBar.Position = V2(bgX, fillY)
            objs.HealthBar.Size     = V2(barW, fillH)
            objs.HealthBar.Color    = hCol
            objs.HealthBar.Visible  = true
        else
            objs.HealthOutline.Visible = false
            objs.HealthBG.Visible      = false
            objs.HealthBar.Visible     = false
        end

        --------------------------------------------------
        -- Name (centered above box, 2px gap)
        --------------------------------------------------
        if config.Name.Enabled then
            objs.Name.Text  = player.Name
            objs.Name.Font  = self.Settings.TextFont
            objs.Name.Size  = self.Settings.TextSize
            objs.Name.Color = config.Name.Color
            objs.Name.Position = V2(boxX + boxW / 2, boxY - objs.Name.TextBounds.Y - 2)
            objs.Name.Visible  = true
        else
            objs.Name.Visible = false
        end

        --------------------------------------------------
        -- Bottom elements (weapon → distance), stacked below box with 2px gap each
        --------------------------------------------------
        local bottomY = boxY + boxH + 1

        if config.Weapon.Enabled then
            local tool = character:FindFirstChildOfClass("Tool")
            if tool then
                objs.Weapon.Text  = tool.Name
                objs.Weapon.Font  = self.Settings.TextFont
                objs.Weapon.Size  = self.Settings.TextSize
                objs.Weapon.Color = config.Weapon.Color
                objs.Weapon.Position = V2(boxX + boxW / 2, bottomY)
                objs.Weapon.Visible = true
                bottomY = bottomY + objs.Weapon.TextBounds.Y + 1
            else
                objs.Weapon.Visible = false
            end
        else
            objs.Weapon.Visible = false
        end

        if config.Distance.Enabled then
            objs.Distance.Text  = "[" .. floor(dist / 3 + 0.5) .. "m]"
            objs.Distance.Font  = self.Settings.TextFont
            objs.Distance.Size  = self.Settings.TextSize
            objs.Distance.Color = config.Distance.Color
            objs.Distance.Position = V2(boxX + boxW / 2, bottomY)
            objs.Distance.Visible  = true
        else
            objs.Distance.Visible = false
        end
    end
end

-- Wire up events
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
