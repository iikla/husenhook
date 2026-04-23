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
        Enabled = false,
        MaxDistance = 1500,
        TextFont = 2,
        TextSize = 13,

        Enemy = {
            Box        = { Enabled = false, Type = "Regular", Color = Color3.fromRGB(255, 255, 255) },
            BoxFill    = { Enabled = false, Type = "Solid", Color = Color3.fromRGB(255, 255, 255), Color2 = Color3.fromRGB(0, 0, 0), Rotation = 90, Transparency = 0.5 },
            HealthBar  = { Enabled = false, Mode = "Two Tone", ColorLow = Color3.fromRGB(255, 0, 0), ColorHigh = Color3.fromRGB(0, 255, 0) },
            Name       = { Enabled = false, Color = Color3.fromRGB(255, 255, 255) },
            Distance   = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            Weapon     = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            OOF        = { Enabled = false, Radius = 300, Size = 15, Color = Color3.fromRGB(255, 0, 0) }
        },
        Team = {
            Box        = { Enabled = false, Type = "Regular", Color = Color3.fromRGB(0, 255, 0) },
            BoxFill    = { Enabled = false, Type = "Solid", Color = Color3.fromRGB(255, 255, 255), Color2 = Color3.fromRGB(0, 0, 0), Rotation = 90, Transparency = 0.5 },
            HealthBar  = { Enabled = false, Mode = "Two Tone", ColorLow = Color3.fromRGB(255, 0, 0), ColorHigh = Color3.fromRGB(0, 255, 0) },
            Name       = { Enabled = false, Color = Color3.fromRGB(0, 255, 0) },
            Distance   = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            Weapon     = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            OOF        = { Enabled = false, Radius = 300, Size = 15, Color = Color3.fromRGB(0, 255, 0) }
        },
        NPC = {
            Box        = { Enabled = false, Type = "Regular", Color = Color3.fromRGB(255, 150, 0) },
            BoxFill    = { Enabled = false, Type = "Solid", Color = Color3.fromRGB(255, 255, 255), Color2 = Color3.fromRGB(0, 0, 0), Rotation = 90, Transparency = 0.5 },
            HealthBar  = { Enabled = false, Mode = "Two Tone", ColorLow = Color3.fromRGB(255, 0, 0), ColorHigh = Color3.fromRGB(0, 255, 0) },
            Name       = { Enabled = false, Color = Color3.fromRGB(255, 150, 0) },
            Distance   = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            Weapon     = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            OOF        = { Enabled = false, Radius = 300, Size = 15, Color = Color3.fromRGB(255, 150, 0) }
        }
    },
    Cache = {},
    Connections = {},
    ScreenGui = Instance.new("ScreenGui")
}

local coreGui = game:GetService("CoreGui")
ESP.ScreenGui.Name = "ESP_Hybrid_Layer"
ESP.ScreenGui.Parent = coreGui:FindFirstChild("RobloxGui") or coreGui

-- Drawing helper
local function Draw(class, props)
    local obj = Drawing.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    return obj
end

-- Create cached drawing objects for a player
function ESP:Add(Entity, isNPC)
    if Entity == LocalPlayer then return end

    local cache = {
        IsNPC = isNPC,
        -- Box: outline (black border) → inline (colored)
        BoxOutline  = Draw("Square", { Thickness = 3, Filled = false, Color = Color3.new(0, 0, 0), ZIndex = 1 }),
        Box         = Draw("Square", { Thickness = 1, Filled = false, ZIndex = 2 }),

        -- Corner lines (8 lines)
        Corners = {},

        -- Health bar: outline (black border) → background (dark fill) → bar (colored fill)
        HealthOutline = Draw("Square", { Filled = true, Color = Color3.new(0, 0, 0), ZIndex = 1 }),
        HealthBG      = Draw("Square", { Filled = true, Color = Color3.fromRGB(40, 40, 40), ZIndex = 2 }),
        HealthBar     = Draw("Square", { Filled = true, ZIndex = 3 }),

        -- Text layers
        Name     = Draw("Text", { Center = true, Outline = true, ZIndex = 4 }),
        Distance = Draw("Text", { Center = true, Outline = true, ZIndex = 4 }),
        Weapon   = Draw("Text", { Center = true, Outline = true, ZIndex = 4 }),

        -- Off-screen arrow
        Arrow = Draw("Triangle", { Filled = true, ZIndex = 3 }),

        -- GUI Elements
        GUI = {}
    }

    for i = 1, 8 do
        cache.Corners[i] = Draw("Line", { Thickness = 1, ZIndex = 2 })
        cache.Corners[i .. "_outline"] = Draw("Line", { Thickness = 3, Color = Color3.new(0,0,0), ZIndex = 1 })
    end

    local fillFrame = Instance.new("Frame")
    fillFrame.BorderSizePixel = 0
    fillFrame.BackgroundColor3 = Color3.new(1, 1, 1)
    fillFrame.Visible = false
    fillFrame.Parent = self.ScreenGui
    cache.GUI.Fill = fillFrame

    local fillGrad = Instance.new("UIGradient")
    fillGrad.Parent = fillFrame
    cache.GUI.FillGrad = fillGrad

    local healthGradFrame = Instance.new("Frame")
    healthGradFrame.BorderSizePixel = 0
    healthGradFrame.BackgroundColor3 = Color3.new(1, 1, 1)
    healthGradFrame.Visible = false
    healthGradFrame.Parent = self.ScreenGui
    cache.GUI.HealthGradFrame = healthGradFrame

    local healthGrad = Instance.new("UIGradient")
    healthGrad.Rotation = -90
    healthGrad.Parent = healthGradFrame
    cache.GUI.HealthGrad = healthGrad

    self.Cache[Entity] = cache
end

-- Clean up drawings
function ESP:Remove(Entity)
    local cache = self.Cache[Entity]
    if not cache then return end
    for k, obj in pairs(cache) do 
        if type(obj) == "table" and k == "Corners" then
            for _, line in pairs(obj) do line:Remove() end
        elseif type(obj) == "table" and k == "GUI" then
            for _, gui in pairs(obj) do gui:Destroy() end
        elseif type(obj) ~= "boolean" then 
            obj:Remove() 
        end
    end
    self.Cache[Entity] = nil
end

-- Hot-reload safe teardown
function ESP:Unload()
    for _, c in pairs(self.Connections) do c:Disconnect() end
    for entity in pairs(self.Cache) do self:Remove(entity) end
    if self.ScreenGui then self.ScreenGui:Destroy() end
end

-- Hide all drawings for a player
local function HideAll(objs)
    for k, obj in pairs(objs) do 
        if type(obj) == "table" and k == "Corners" then
            for _, line in pairs(obj) do line.Visible = false end
        elseif type(obj) == "table" and k == "GUI" then
            for _, gui in pairs(obj) do 
                if gui:IsA("Frame") then gui.Visible = false end
            end
        elseif type(obj) ~= "boolean" then
            obj.Visible = false 
        end
    end
end

-- Main render loop
function ESP:Update()
    Camera = workspace.CurrentCamera -- refresh in case of respawn

    for entity, objs in pairs(self.Cache) do
        local character
        if objs.IsNPC then
            character = entity
        else
            character = entity.Character
        end
        local humanoid  = character and character:FindFirstChild("Humanoid")
        local hrp       = character and character:FindFirstChild("HumanoidRootPart")
        local head      = character and character:FindFirstChild("Head")

        local config
        if objs.IsNPC then
            config = self.Settings.NPC
        else
            local isTeammate = entity.Team ~= nil and entity.Team == LocalPlayer.Team
            config = isTeammate and self.Settings.Team or self.Settings.Enemy
            if self.Settings.TeamCheck and isTeammate then 
                -- handled via validity checks
            end
        end

        -- Validity checks
        local alive = humanoid and humanoid.Health > 0
        local pass  = self.Settings.Enabled and character and alive and hrp and head
        if not objs.IsNPC and self.Settings.TeamCheck and entity.Team == LocalPlayer.Team then pass = false end

        local dist = 0
        if pass then
            local localChar = LocalPlayer.Character
            local localHRP = localChar and localChar:FindFirstChild("HumanoidRootPart")
            dist = localHRP and (hrp.Position - localHRP.Position).Magnitude or (hrp.Position - Camera.CFrame.Position).Magnitude
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
        -- Bounding Box Calculation (FOV-based scale)
        --------------------------------------------------
        local rootPos = Camera:WorldToViewportPoint(hrp.Position)
        local scale = 1 / (rootPos.Z * math.tan(rad(Camera.FieldOfView * 0.5)) * 2) * 1000
        local boxW = floor(4.5 * scale)
        local boxH = floor(6 * scale)
        local scrX = floor(rootPos.X)
        local scrY = floor(rootPos.Y)
        local boxX = floor(scrX - boxW * 0.5)
        local boxY = floor((scrY - boxH * 0.5) + (0.5 * scale))

        local boxPos  = V2(boxX, boxY)
        local boxSize = V2(boxW, boxH)

        local healthPct = clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)

        --------------------------------------------------
        -- Box (outline + inline, 1px each) + Corners + Fill
        --------------------------------------------------
        if config.Box.Enabled then
            if config.Box.Type == "Corner" then
                objs.Box.Visible = false
                objs.BoxOutline.Visible = false
                local cornerLen = floor(boxW * 0.2)
                local cornerH = floor(boxH * 0.2)
                
                local c = objs.Corners
                for i=1,8 do c[i].Visible = true; c[i.."_outline"].Visible = true end
                
                -- Top Left
                c[1].From = V2(boxX, boxY); c[1].To = V2(boxX + cornerLen, boxY)
                c[2].From = V2(boxX, boxY); c[2].To = V2(boxX, boxY + cornerH)
                
                -- Top Right
                c[3].From = V2(boxX + boxW, boxY); c[3].To = V2(boxX + boxW - cornerLen, boxY)
                c[4].From = V2(boxX + boxW, boxY); c[4].To = V2(boxX + boxW, boxY + cornerH)
                
                -- Bottom Left
                c[5].From = V2(boxX, boxY + boxH); c[5].To = V2(boxX + cornerLen, boxY + boxH)
                c[6].From = V2(boxX, boxY + boxH); c[6].To = V2(boxX, boxY + boxH - cornerH)
                
                -- Bottom Right
                c[7].From = V2(boxX + boxW, boxY + boxH); c[7].To = V2(boxX + boxW - cornerLen, boxY + boxH)
                c[8].From = V2(boxX + boxW, boxY + boxH); c[8].To = V2(boxX + boxW, boxY + boxH - cornerH)

                for i=1,8 do
                    c[i].Color = config.Box.Color
                    c[i.."_outline"].From = c[i].From
                    c[i.."_outline"].To = c[i].To
                end
            else
                for i=1,8 do objs.Corners[i].Visible = false; objs.Corners[i.."_outline"].Visible = false end
                objs.Box.Position  = boxPos
                objs.Box.Size      = boxSize
                objs.Box.Color     = config.Box.Color
                objs.Box.Visible   = true

                objs.BoxOutline.Position = boxPos
                objs.BoxOutline.Size     = boxSize
                objs.BoxOutline.Visible  = true
            end
        else
            objs.Box.Visible = false
            objs.BoxOutline.Visible = false
            for i=1,8 do objs.Corners[i].Visible = false; objs.Corners[i.."_outline"].Visible = false end
        end

        if config.BoxFill.Enabled and config.Box.Enabled then
            objs.GUI.Fill.Visible = true
            objs.GUI.Fill.Position = UDim2.new(0, boxX, 0, boxY)
            objs.GUI.Fill.Size = UDim2.new(0, boxW, 0, boxH)
            objs.GUI.Fill.BackgroundTransparency = config.BoxFill.Transparency
            
            if config.BoxFill.Type == "Gradient" then
                objs.GUI.Fill.BackgroundColor3 = Color3.new(1, 1, 1)
                objs.GUI.FillGrad.Enabled = true
                objs.GUI.FillGrad.Color = ColorSequence.new(config.BoxFill.Color, config.BoxFill.Color2)
                objs.GUI.FillGrad.Rotation = config.BoxFill.Rotation
            else
                objs.GUI.Fill.BackgroundColor3 = config.BoxFill.Color
                objs.GUI.FillGrad.Enabled = false
            end
        else
            objs.GUI.Fill.Visible = false
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

            if config.HealthBar.Mode == "Gradient" then
                objs.HealthBar.Visible = false
                objs.GUI.HealthGradFrame.Visible = true
                objs.GUI.HealthGradFrame.Position = UDim2.new(0, bgX, 0, fillY)
                objs.GUI.HealthGradFrame.Size = UDim2.new(0, barW, 0, fillH)
                objs.GUI.HealthGrad.Color = ColorSequence.new(config.HealthBar.ColorHigh, config.HealthBar.ColorLow)
            else
                objs.GUI.HealthGradFrame.Visible = false
                objs.HealthBar.Position = V2(bgX, fillY)
                objs.HealthBar.Size     = V2(barW, fillH)
                if config.HealthBar.Mode == "Solid" then
                    objs.HealthBar.Color = config.HealthBar.ColorHigh
                else
                    objs.HealthBar.Color = config.HealthBar.ColorLow:Lerp(config.HealthBar.ColorHigh, healthPct)
                end
                objs.HealthBar.Visible  = true
            end
        else
            objs.HealthOutline.Visible = false
            objs.HealthBG.Visible      = false
            objs.HealthBar.Visible     = false
            objs.GUI.HealthGradFrame.Visible = false
        end

        --------------------------------------------------
        -- Name (centered above box, 2px gap)
        --------------------------------------------------
        if config.Name.Enabled then
            objs.Name.Text  = objs.IsNPC and "NPC" or entity.Name
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
            objs.Distance.Text  = "[" .. floor(dist + 0.5) .. " studs]"
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
    ESP:Add(plr, false)
end))

table.insert(ESP.Connections, Players.PlayerRemoving:Connect(function(plr)
    ESP:Remove(plr)
end))

for _, plr in pairs(Players:GetPlayers()) do
    ESP:Add(plr, false)
end

local enemiesFolder = workspace:FindFirstChild("Spawned") and workspace.Spawned:FindFirstChild("Enemies")
if enemiesFolder then
    for _, npc in pairs(enemiesFolder:GetChildren()) do
        if npc:IsA("Model") then ESP:Add(npc, true) end
    end
    table.insert(ESP.Connections, enemiesFolder.ChildAdded:Connect(function(npc)
        if npc:IsA("Model") then ESP:Add(npc, true) end
    end))
    table.insert(ESP.Connections, enemiesFolder.ChildRemoved:Connect(function(npc)
        ESP:Remove(npc)
    end))
end

table.insert(ESP.Connections, RunService.RenderStepped:Connect(function()
    ESP:Update()
end))

return ESP
