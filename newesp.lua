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
        TeamCheck = true,
        TextFont = 2,
        TextSize = 13,

        Enemy = {
            Box        = { Enabled = false,  Color = Color3.fromRGB(255, 255, 255) },
            HealthBar  = { Enabled = false,  ColorLow = Color3.fromRGB(255, 0, 0), ColorHigh = Color3.fromRGB(0, 255, 0) },
            Name       = { Enabled = false,  Color = Color3.fromRGB(255, 255, 255) },
            Distance   = { Enabled = false,  Color = Color3.fromRGB(200, 200, 200) },
            Weapon     = { Enabled = false,  Color = Color3.fromRGB(200, 200, 200) },
            OOF        = { Enabled = false, Radius = 300, Size = 15, Color = Color3.fromRGB(255, 0, 0) }
        },
        Team = {
            Box        = { Enabled = false, Color = Color3.fromRGB(0, 255, 0) },
            HealthBar  = { Enabled = false, ColorLow = Color3.fromRGB(255, 0, 0), ColorHigh = Color3.fromRGB(0, 255, 0) },
            Name       = { Enabled = false, Color = Color3.fromRGB(0, 255, 0) },
            Distance   = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            Weapon     = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            OOF        = { Enabled = false, Radius = 300, Size = 15, Color = Color3.fromRGB(0, 255, 0) }
        },
        NPC = {
            Enabled = false,
            MaxDistance = 1500,
            Box        = { Enabled = false, Color = Color3.fromRGB(255, 255, 255) },
            HealthBar  = { Enabled = false, ColorLow = Color3.fromRGB(255, 0, 0), ColorHigh = Color3.fromRGB(0, 255, 0) },
            Name       = { Enabled = false, Color = Color3.fromRGB(255, 255, 255) },
            Distance   = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            Weapon     = { Enabled = false, Color = Color3.fromRGB(200, 200, 200) },
            OOF        = { Enabled = false, Radius = 300, Size = 15, Color = Color3.fromRGB(255, 0, 0) }
        }
    },
    Cache = {},
    NPCCache = {},
    Connections = {}
}

local function Draw(class, props)
    local obj = Drawing.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    return obj
end

local function CreateDrawings()
    return {
        BoxOutline  = Draw("Square", { Thickness = 3, Filled = false, Color = Color3.new(0, 0, 0), ZIndex = 1 }),
        Box         = Draw("Square", { Thickness = 1, Filled = false, ZIndex = 2 }),
        HealthOutline = Draw("Square", { Filled = true, Color = Color3.new(0, 0, 0), ZIndex = 1 }),
        HealthBG      = Draw("Square", { Filled = true, Color = Color3.fromRGB(40, 40, 40), ZIndex = 2 }),
        HealthBar     = Draw("Square", { Filled = true, ZIndex = 3 }),
        Name     = Draw("Text", { Center = true, Outline = true, ZIndex = 4 }),
        Distance = Draw("Text", { Center = true, Outline = true, ZIndex = 4 }),
        Weapon   = Draw("Text", { Center = true, Outline = true, ZIndex = 4 }),
        Arrow = Draw("Triangle", { Filled = true, ZIndex = 3 })
    }
end

function ESP:Add(Player)
    if Player == LocalPlayer then return end
    if self.Cache[Player] then return end
    self.Cache[Player] = CreateDrawings()
end

function ESP:Remove(Player)
    local cache = self.Cache[Player]
    if not cache then return end
    for _, obj in pairs(cache) do obj:Remove() end
    self.Cache[Player] = nil
end

function ESP:AddNPC(Model)
    if self.NPCCache[Model] then return end
    self.NPCCache[Model] = CreateDrawings()
end

function ESP:RemoveNPC(Model)
    local cache = self.NPCCache[Model]
    if not cache then return end
    for _, obj in pairs(cache) do obj:Remove() end
    self.NPCCache[Model] = nil
end

function ESP:Unload()
    for _, c in pairs(self.Connections) do c:Disconnect() end
    for plr in pairs(self.Cache) do self:Remove(plr) end
    for mdl in pairs(self.NPCCache) do self:RemoveNPC(mdl) end
end

local function HideAll(objs)
    for _, obj in pairs(objs) do obj.Visible = false end
end

local function RenderESP(objs, character, name, config, maxDist)
    local humanoid  = character:FindFirstChild("Humanoid")
    local hrp       = character:FindFirstChild("HumanoidRootPart")
    local head      = character:FindFirstChild("Head")

    local alive = humanoid and humanoid.Health > 0
    local pass = character and alive and hrp and head

    local dist = 0
    if pass then
        local localChar = LocalPlayer.Character
        local localHRP = localChar and localChar:FindFirstChild("HumanoidRootPart")
        dist = localHRP and (hrp.Position - localHRP.Position).Magnitude or (hrp.Position - Camera.CFrame.Position).Magnitude
        if dist > maxDist then pass = false end
    end

    if not pass then
        HideAll(objs)
        if config.OOF and config.OOF.Enabled and alive and hrp then
            local _, vis = Camera:WorldToViewportPoint(hrp.Position)
            if not vis then
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
        return
    end

    local _, onScreen = Camera:WorldToViewportPoint(hrp.Position)

    if not onScreen then
        HideAll(objs)
        if config.OOF and config.OOF.Enabled then
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
        return
    end

    objs.Arrow.Visible = false

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

    if config.HealthBar.Enabled then
        local barW       = 2
        local outlinePad = 1
        local gap        = 3

        local olX = boxX - gap - barW - outlinePad
        local olY = boxY - outlinePad
        local olW = barW + outlinePad * 2
        local olH = boxH + outlinePad * 2

        objs.HealthOutline.Position = V2(olX, olY)
        objs.HealthOutline.Size     = V2(olW, olH)
        objs.HealthOutline.Visible  = true

        local bgX = olX + outlinePad
        local bgY = olY + outlinePad
        objs.HealthBG.Position = V2(bgX, bgY)
        objs.HealthBG.Size     = V2(barW, boxH)
        objs.HealthBG.Visible  = true

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

    if config.Name.Enabled then
        objs.Name.Text  = name
        objs.Name.Font  = ESP.Settings.TextFont
        objs.Name.Size  = ESP.Settings.TextSize
        objs.Name.Color = config.Name.Color
        objs.Name.Position = V2(boxX + boxW / 2, boxY - objs.Name.TextBounds.Y - 2)
        objs.Name.Visible  = true
    else
        objs.Name.Visible = false
    end

    local bottomY = boxY + boxH + 1

    if config.Weapon and config.Weapon.Enabled then
        local tool = character:FindFirstChildOfClass("Tool")
        if tool then
            objs.Weapon.Text  = tool.Name
            objs.Weapon.Font  = ESP.Settings.TextFont
            objs.Weapon.Size  = ESP.Settings.TextSize
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
        objs.Distance.Font  = ESP.Settings.TextFont
        objs.Distance.Size  = ESP.Settings.TextSize
        objs.Distance.Color = config.Distance.Color
        objs.Distance.Position = V2(boxX + boxW / 2, bottomY)
        objs.Distance.Visible  = true
    else
        objs.Distance.Visible = false
    end
end

function ESP:Update()
    Camera = workspace.CurrentCamera

    for player, objs in pairs(self.Cache) do
        local character = player.Character
        local isTeammate = player.Team ~= nil and player.Team == LocalPlayer.Team
        local config = isTeammate and self.Settings.Team or self.Settings.Enemy
        
        if not self.Settings.Enabled or (self.Settings.TeamCheck and isTeammate) or not character then
            HideAll(objs)
            continue
        end

        RenderESP(objs, character, player.Name, config, self.Settings.MaxDistance)
    end

    for model, objs in pairs(self.NPCCache) do
        if not model or not model.Parent then
            HideAll(objs)
            self:RemoveNPC(model)
            continue
        end

        if not self.Settings.NPC.Enabled then
            HideAll(objs)
            continue
        end

        local npcName = model:GetAttribute("Gender") ~= nil and "NPC" or "Bear"
        RenderESP(objs, model, npcName, self.Settings.NPC, self.Settings.NPC.MaxDistance)
    end
end

table.insert(ESP.Connections, Players.PlayerAdded:Connect(function(plr)
    ESP:Add(plr)
end))

table.insert(ESP.Connections, Players.PlayerRemoving:Connect(function(plr)
    ESP:Remove(plr)
end))

for _, plr in pairs(Players:GetPlayers()) do
    ESP:Add(plr)
end

local function CheckNPC(inst)
    if inst:IsA("Model") and inst ~= LocalPlayer.Character and not Players:GetPlayerFromCharacter(inst) then
        if inst:FindFirstChild("Humanoid") and inst:FindFirstChild("HumanoidRootPart") then
            ESP:AddNPC(inst)
        end
    end
end

for _, desc in pairs(workspace:GetDescendants()) do
    CheckNPC(desc)
end

table.insert(ESP.Connections, workspace.DescendantAdded:Connect(function(desc)
    task.defer(function()
        if desc:IsA("Model") then
            CheckNPC(desc)
        elseif desc:IsA("Humanoid") and desc.Parent and desc.Parent:IsA("Model") then
            CheckNPC(desc.Parent)
        end
    end)
end))

table.insert(ESP.Connections, workspace.DescendantRemoving:Connect(function(desc)
    if desc:IsA("Model") and ESP.NPCCache[desc] then
        ESP:RemoveNPC(desc)
    end
end))

table.insert(ESP.Connections, RunService.RenderStepped:Connect(function()
    ESP:Update()
end))

return ESP
