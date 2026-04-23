local workspace = cloneref(game:GetService("Workspace"))
local run = cloneref(game:GetService("RunService"))
local http_service = cloneref(game:GetService("HttpService"))
local players = cloneref(game:GetService("Players"))

local vec2 = Vector2.new
local vec3 = Vector3.new
local dim2 = UDim2.new
local dim = UDim.new 
local rect = Rect.new
local cfr = CFrame.new
local empty_cfr = cfr()
local point_object_space = empty_cfr.PointToObjectSpace
local angle = CFrame.Angles
local dim_offset = UDim2.fromOffset

local color = Color3.new
local rgb = Color3.fromRGB
local hex = Color3.fromHex
local hsv = Color3.fromHSV
local rgbseq = ColorSequence.new
local rgbkey = ColorSequenceKeypoint.new
local numseq = NumberSequence.new
local numkey = NumberSequenceKeypoint.new

local camera = workspace.CurrentCamera

local bones = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"UpperTorso", "RightUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LowerTorso", "RightUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
}

local flags = { -- basically a substitute for ur ui flags (flags["wahdiuawdhwa"])
    ["Enabled"] = false;
    ["Names"] = false; 
    ["Name_Type"] = "Both"; 
    ["Name_Color"] = { Color = rgb(255, 255, 255) };
    ["Boxes"] = true;
    ["Box_Type"] = "Corner";
    ["Box_Color"] = { Color = rgb(255, 255, 255) };
    ["Box_Fill"] = false;
    ["Box_Fill_Type"] = "Solid";
    ["Box_Fill_Color"] = { Color = rgb(255, 255, 255) };
    ["Box_Fill_Color2"] = { Color = rgb(0, 0, 0) };
    ["Box_Fill_Transparency"] = 0.5;
    ["Box_Fill_Gradient_Rotation"] = 90;
    ["Healthbar"] = true; 
    ["Health_Mode"] = "Two Tone";
    ["Health_High"] = { Color = rgb(0, 255, 0) };
    ["Health_Low"] = { Color = rgb(255, 0, 0) };
    ["Distance"] = true;
    ["Weapon"] = true;
    ["Skeletons"] = true;
    ["Skeletons_Color"] = { Color = rgb(255, 255, 255) };
    ["Distance_Color"] = { Color = rgb(255, 255, 255) };
    ["Weapon_Color"] = { Color = rgb(255, 255, 255) };
    
    ["NPC_Enabled"] = false;
    ["NPC_Names"] = false; 
    ["NPC_Name_Type"] = "Both"; 
    ["NPC_Name_Color"] = { Color = rgb(255, 255, 255) };
    ["NPC_Boxes"] = true;
    ["NPC_Box_Type"] = "Corner";
    ["NPC_Box_Color"] = { Color = rgb(255, 255, 255) };
    ["NPC_Box_Fill"] = false;
    ["NPC_Box_Fill_Type"] = "Solid";
    ["NPC_Box_Fill_Color"] = { Color = rgb(255, 255, 255) };
    ["NPC_Box_Fill_Color2"] = { Color = rgb(0, 0, 0) };
    ["NPC_Box_Fill_Transparency"] = 0.5;
    ["NPC_Box_Fill_Gradient_Rotation"] = 90;
    ["NPC_Healthbar"] = true; 
    ["NPC_Health_Mode"] = "Two Tone";
    ["NPC_Health_High"] = { Color = rgb(0, 255, 0) };
    ["NPC_Health_Low"] = { Color = rgb(255, 0, 0) };
    ["NPC_Distance"] = true;
    ["NPC_Weapon"] = true;
    ["NPC_Skeletons"] = true;
    ["NPC_Skeletons_Color"] = { Color = rgb(255, 255, 255) };
    ["NPC_Distance_Color"] = { Color = rgb(255, 255, 255) };
    ["NPC_Weapon_Color"] = { Color = rgb(255, 255, 255) }
}

local fonts = {}; do
    function Register_Font(Name, Weight, Style, Asset)
        if not isfile(Asset.Id) then
            writefile(Asset.Id, Asset.Font)
        end

        if isfile(Name .. ".font") then
            delfile(Name .. ".font")
        end

        local Data = {
            name = Name,
            faces = {
                {
                    name = "Normal",
                    weight = Weight,
                    style = Style,
                    assetId = getcustomasset(Asset.Id),
                },
            },
        }
        writefile(Name .. ".font", http_service:JSONEncode(Data))

        return getcustomasset(Name .. ".font");
    end
    
    local ProggyTiny = Register_Font("adwdawdwadadwadawdawdawdawd!", 100, "Normal", {
        Id = "ProggyTinyyyy.ttf",
        Font = game:HttpGet("https://github.com/i77lhm/storage/raw/refs/heads/main/fonts/ProggyTiny.ttf"),
    })

    fonts = {
        main = Font.new(ProggyTiny, Enum.FontWeight.Regular, Enum.FontStyle.Normal);
    }
end

local esp = { players = {}, screengui = Instance.new("ScreenGui", gethui()), cache = Instance.new("ScreenGui", gethui()), connections = {}}; do 
    esp.screengui.IgnoreGuiInset = true
    esp.screengui.Name = "\0"

    esp.cache.Enabled = false

    -- Functions 
        function esp:get_screen_pos(world_position)
            local viewport_size = camera.ViewportSize
            local local_position = camera.CFrame:pointToObjectSpace(world_position) 
            
            local aspect_ratio = viewport_size.x / viewport_size.y
            local half_height = -local_position.z * math.tan(math.rad(camera.FieldOfView / 2))
            local half_width = aspect_ratio * half_height
            
            local far_plane_corner = Vector3.new(-half_width, half_height, local_position.z)
            local relative_position = local_position - far_plane_corner
        
            local screen_x = relative_position.x / (half_width * 2)
            local screen_y = -relative_position.y / (half_height * 2)
        
            local is_on_screen = -local_position.z > 0 and screen_x >= 0 and screen_x <= 1 and screen_y >= 0 and screen_y <= 1
            
            -- returns in pixels as opposed to scale
            return Vector3.new(screen_x * viewport_size.x, screen_y * viewport_size.y, -local_position.z), is_on_screen
        end

        function esp:box_solve(torso)
            if not torso then
                return nil, nil, nil
            end
            
            local ViewportTop = torso.Position + (torso.CFrame.UpVector * 1.8) + camera.CFrame.UpVector
            local ViewportBottom = torso.Position - (torso.CFrame.UpVector * 2.5) - camera.CFrame.UpVector
            local Distance = (torso.Position - camera.CFrame.p).Magnitude

            local Top, TopIsRendered = esp:get_screen_pos(ViewportTop)
            local Bottom, BottomIsRendered = esp:get_screen_pos(ViewportBottom)

            local Width = math.max(math.floor(math.abs(Top.X - Bottom.X)), 3)
            local Height = math.max(math.floor(math.max(math.abs(Bottom.Y - Top.Y), Width / 2)), 3)
            local BoxSize = Vector2.new(math.floor(math.max(Height / 1.5, Width)), Height)
            local BoxPosition = Vector2.new(math.floor(Top.X * 0.5 + Bottom.X * 0.5 - BoxSize.X * 0.5), math.floor(math.min(Top.Y, Bottom.Y)))
            
            return BoxSize, BoxPosition, TopIsRendered, Distance
            
        end

        function esp:create(instance, options)
            local ins = Instance.new(instance) 
            
            for prop, value in options do 
                ins[prop] = value
            end
            
            return ins 
        end

        function esp:create_object( entity, is_npc )
            esp[ entity ] = { objects = { }, info = {character = is_npc and entity or nil; humanoid = nil; is_npc = is_npc}; drawings = { }} 
            local data = esp[ entity ] 

            local objects = data.objects; do
                objects[ "holder" ] = esp:create( "Frame" , {
                    Parent = esp.screengui;
                    Name = "\0";
                    BackgroundTransparency = 1;
                    Position = dim2(0, 0, 0, 0);
                    BorderColor3 = rgb(0, 0, 0);
                    Size = dim2(0, 0, 0, 0);
                    BorderSizePixel = 0;
                    BackgroundColor3 = rgb(255, 255, 255)
                });
                
                objects[ "box_outline" ] = esp:create( "UIStroke" , {
                    Parent = (flags["Boxes"] and flags["Box_Type"] ~= "Corner" and objects["holder"]) or esp.cache;
                    LineJoinMode = Enum.LineJoinMode.Miter
                });
                
                objects[ "name" ] = esp:create( "TextLabel" , {
                    FontFace = fonts.main;
                    Parent = objects[ "holder" ];
                    TextColor3 = flags["Name_Color"].Color;
                    BorderColor3 = rgb(0, 0, 0);
                    Text = is_npc and "NPC" or string.format("%s (@%s)", entity.DisplayName, entity.Name);
                    Name = "\0";
                    TextStrokeTransparency = 0;
                    AnchorPoint = vec2(0, 1);
                    Size = dim2(1, 0, 0, 0);
                    BackgroundTransparency = 1;
                    Position = dim2(0, 0, 0, -5);
                    BorderSizePixel = 0;
                    AutomaticSize = Enum.AutomaticSize.Y;
                    TextSize = 9;
                });
                
                objects[ "box_handler" ] = esp:create( "Frame" , {
                    Parent = (flags["Boxes"] and flags["Box_Type"] ~= "Corner" and objects["holder"]) or esp.cache;
                    Name = "\0";
                    BackgroundTransparency = 1;
                    Position = dim2(0, 1, 0, 1);
                    BorderColor3 = rgb(0, 0, 0);
                    Size = dim2(1, -2, 1, -2);
                    BorderSizePixel = 0;
                    BackgroundColor3 = rgb(255, 255, 255)
                });
                
                objects[ "box_color" ] = esp:create( "UIStroke" , {
                    Color = rgb(255, 255, 255);
                    LineJoinMode = Enum.LineJoinMode.Miter;
                    Name = "\0";
                    Parent = objects[ "box_handler" ]
                });
                
                objects[ "outline" ] = esp:create( "Frame" , {
                    Parent = objects[ "box_handler" ];
                    Name = "\0";
                    BackgroundTransparency = 1;
                    Position = dim2(0, 1, 0, 1);
                    BorderColor3 = rgb(0, 0, 0);
                    Size = dim2(1, -2, 1, -2);
                    BorderSizePixel = 0;
                    BackgroundColor3 = rgb(255, 255, 255)
                });
                
                esp:create( "UIStroke" , {
                    Parent = objects[ "outline" ];
                    LineJoinMode = Enum.LineJoinMode.Miter
                });  
                
                -- Box Fill
                objects[ "fill" ] = esp:create( "Frame" , {
                    Parent = esp.cache;
                    Name = "\0";
                    BackgroundTransparency = 0.5;
                    Position = dim2(0, 1, 0, 1);
                    BorderColor3 = rgb(0, 0, 0);
                    Size = dim2(1, -2, 1, -2);
                    BorderSizePixel = 0;
                    BackgroundColor3 = rgb(255, 255, 255)
                });
                objects[ "fill_gradient" ] = esp:create( "UIGradient" , {
                    Parent = esp.cache;
                    Color = ColorSequence.new(rgb(255, 255, 255), rgb(0, 0, 0));
                    Rotation = 90;
                });
                --
                
                -- Corner Boxes
                    objects[ "corners" ] = esp:create( "Frame" , {
                        Visible = true;
                        BorderColor3 = rgb(0, 0, 0);
                        Parent = flags["Boxes"] and flags["Box_Type"] == "Corner" and objects["holder"] or esp.cache;
                        BackgroundTransparency = 1;
                        Position = dim2(0, -1, 0, 2);
                        Name = "\0";
                        Size = dim2(1, 0, 1, 0);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(255, 255, 255)
                    });

                    objects[ "1" ] = esp:create( "Frame" , {
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(0, 0, 0, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0.2, 0, 0, 3);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "1" ];
                        Position = dim2(0, 1, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, -2);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "2" ] = esp:create( "Frame" , {
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(0, 0, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0, 3, 0.2, 0);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "2" ];
                        Position = dim2(0, 1, 0, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, 1);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "3" ] = esp:create( "Frame" , {
                        AnchorPoint = vec2(1, 0);
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(1, 0, 0, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0.2, 0, 0, 3);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "3" ];
                        Position = dim2(0, 1, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, -2);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "4" ] = esp:create( "Frame" , {
                        AnchorPoint = vec2(1, 0);
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(1, 0, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0, 3, 0.2, 0);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "4" ];
                        Position = dim2(0, 1, 0, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, 1);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "5" ] = esp:create( "Frame" , {
                        AnchorPoint = vec2(0, 1);
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(0, 0, 1, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0.2, 0, 0, 3);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "5" ];
                        Position = dim2(0, 1, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, -2);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "6" ] = esp:create( "Frame" , {
                        BorderColor3 = rgb(0, 0, 0);
                        Rotation = 180;
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(0, 0, 1, -5);
                        AnchorPoint = vec2(0, 1);
                        Size = dim2(0, 3, 0.2, 0);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "6" ];
                        Position = dim2(0, 1, 0, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, 1);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "7" ] = esp:create( "Frame" , {
                        AnchorPoint = vec2(1, 1);
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(1, 0, 1, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0.2, 0, 0, 3);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "7" ];
                        Position = dim2(0, 1, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, -2);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "7" ] = esp:create( "Frame" , {
                        BorderColor3 = rgb(0, 0, 0);
                        Rotation = 180;
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(1, 0, 1, -5);
                        AnchorPoint = vec2(1, 1);
                        Size = dim2(0, 3, 0.2, 0);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "7" ];
                        Position = dim2(0, 1, 0, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, 1);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                -- 
                
                -- Healthbar
                    objects[ "healthbar_holder" ] = esp:create( "Frame" , {
                        AnchorPoint = vec2(1, 0);
                        Parent = flags["Healthbar"] and objects[ "holder" ] or esp.cache;
                        Name = "\0";
                        Position = dim2(0, -5, 0, -1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0, 4, 1, 2);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    objects[ "healthbar" ] = esp:create( "Frame" , {
                        Parent = objects[ "healthbar_holder" ];
                        Name = "\0";
                        Position = dim2(0, 1, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, -2);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(255, 255, 255)
                    });
                    objects[ "healthbar_gradient" ] = esp:create( "UIGradient" , {
                        Parent = esp.cache;
                        Rotation = -90;
                    });
                -- 

                -- Distance esp
                    objects[ "distance" ] = esp:create( "TextLabel" , {
                        FontFace = fonts.main;
                        TextColor3 = flags["Distance_Color"].Color;
                        BorderColor3 = rgb(0, 0, 0);
                        Text = "127st";
                        Parent = flags[ "Distance" ] and objects[ "holder" ] or esp.cache;
                        TextStrokeTransparency = 0;
                        Name = "\0";
                        Size = dim2(1, 0, 0, 0);
                        BackgroundTransparency = 1;
                        Position = dim2(0, 0, 1, 5);
                        BorderSizePixel = 0;
                        AutomaticSize = Enum.AutomaticSize.Y;
                        TextSize = 9;
                    });                
                -- 

                -- Weapon esp
                    objects[ "weapon" ] = esp:create( "TextLabel" , {
                        FontFace = fonts.main;
                        TextColor3 = flags["Weapon_Color"].Color;
                        BorderColor3 = rgb(0, 0, 0);
                        Text = "[ak-47]";
                        Parent = esp.cache;
                        TextStrokeTransparency = 0;
                        Name = "\0";
                        Size = dim2(1, 0, 0, 0);
                        BackgroundTransparency = 1;
                        Position = dim2(0, 0, 1, 19);
                        BorderSizePixel = 0;
                        AutomaticSize = Enum.AutomaticSize.Y;
                        TextSize = 9;
                    });
                -- 
                
                -- Skeleton Lines
                    
                    for _, bone in bones do
                        local line = Drawing.new("Line")
                        line.Color = flags["Skeletons_Color"].Color;
                        line.Thickness = 1;
                        line.Visible = false;

                        data.drawings[#data.drawings + 1] = line;
                    end
                -- 
            end
            
            do --[[ data functions ]]
                data.health_changed = function( value )
                    local prefix = data.info.is_npc and "NPC_" or ""
                    if not flags[ prefix .. "Healthbar" ] then 
                        return 
                    end

                    local humanoid = data.info.humanoid
                    local multiplier = value / humanoid.MaxHealth
                    local mode = flags[ prefix .. "Health_Mode" ] or "Two Tone"
                    
                    objects[ "healthbar" ].Size = UDim2.new(1, -2, multiplier, -2)
                    objects[ "healthbar" ].Position = UDim2.new(0, 1, 1 - multiplier, 1)

                    if mode == "Solid" then
                        objects[ "healthbar" ].BackgroundColor3 = flags[ prefix .. "Health_High" ].Color
                    elseif mode == "Gradient" then
                        objects[ "healthbar" ].BackgroundColor3 = rgb(255, 255, 255)
                    else
                        local color = flags[ prefix .. "Health_Low" ].Color:Lerp( flags[ prefix .. "Health_High" ].Color, multiplier )
                        objects[ "healthbar" ].BackgroundColor3 = color
                    end
                end

                data.tool_added = function( item )
                    if not item:IsA("Tool") then 
                        return 
                    end 

                    local exists = data.info.character:FindFirstChild(item.Name) 
                    print(exists, item.Name)
                    objects[ "weapon" ].Text = item.Name
                    objects[ "weapon" ].Parent = exists and objects[ "holder" ] or esp.cache
                end

                data.refresh_offsets = function()
                    local offset = 5; 

                    if objects["distance"].Parent == objects[ "holder" ] then 
                        offset += 5
                        objects[ "weapon" ].Position = dim2(0, 0, 1, offset)
                    end 

                    if objects[ "weapon" ].Parent == objects[ "holder" ] then 
                        offset += 5
                        objects[ "weapon" ].Position = dim2(0, 0, 1, offset)
                    end 
                end 

                data.refresh_descendants = function() 
                    local character = player.Character or player.CharacterAdded:Wait()
                    local humanoid = character:WaitForChild( "Humanoid" )
                    
                    data.info.character = character
                    data.info.humanoid = humanoid
                    data.info.rootpart = rootpart

                    humanoid.HealthChanged:Connect( data.health_changed )

                    character.ChildAdded:Connect( data.tool_added )
                    character.ChildRemoved:Connect( data.tool_added )

                    data.health_changed( data.info.humanoid.Health )
                end
            end 
            
            do --[[ init / connections ]]  
                data.refresh_descendants()

                data.health_changed( data.info.humanoid.Health )

                player.CharacterAdded:Connect( data.refresh_descendants )

                local tool = player.Character:FindFirstChildOfClass("Tool")

                if tool then
                    data.tool_added( tool )
                end 
            end 
        end

        function esp:remove_object(entity)
            local holder = esp[entity]

            if not holder then return end 

            local objects = holder.objects
 
            for _, line in holder.drawings do 
                line:Remove()
            end
            
            objects[ "holder" ]:Destroy() 
            esp[entity] = nil
        end
        
        function esp.refresh_elements( )
            for entity, path in pairs(esp) do
                if type(entity) == "string" or type(path) ~= "table" or not path.objects then continue end

                local is_npc = path.info and path.info.is_npc
                local prefix = is_npc and "NPC_" or ""
                
                if not is_npc and entity == players.LocalPlayer then continue end
                
                if not path.info.character then continue end

                local objects = path.objects
                
                objects.holder.Parent = flags[prefix .. "Enabled"] and esp.screengui or esp.cache

                objects[ "name" ].Parent = flags[prefix .. "Names"] and objects["holder"] or esp.cache
                objects[ "name" ].TextColor3 = flags[prefix .. "Name_Color"].Color
                
                local name_type = flags[prefix .. "Name_Type"] or "Both"
                local name_text = ""
                if is_npc then
                    name_text = "NPC"
                elseif name_type == "Username" then
                    name_text = entity.Name
                elseif name_type == "Display Name" then
                    name_text = entity.DisplayName
                else
                    name_text = string.format("%s (@%s)", entity.DisplayName, entity.Name)
                end
                
                if objects["name"].Text ~= name_text then
                    objects["name"].Text = name_text
                end
                
                local is_corner = flags[ prefix .. "Box_Type" ] == "Corner"

                if flags[prefix .. "Boxes"] then 
                    objects[ "corners" ].Parent = (is_corner and objects["holder"]) or esp.cache
                    objects[ "box_handler" ].Parent = (is_corner and esp.cache or objects[ "holder" ])
                    objects[ "box_outline" ].Parent = (is_corner and esp.cache or objects[ "holder" ]) 
                else
                    objects[ "corners" ].Parent =  esp.cache
                    objects[ "box_handler" ].Parent = esp.cache
                    objects[ "box_outline" ].Parent = esp.cache
                end 
                
                objects[ "box_color" ].Color = flags[prefix .. "Box_Color"].Color 

                for _, corner in objects[ "corners" ]:GetChildren() do
                    corner.Frame.BackgroundColor3 = flags[prefix .. "Box_Color"].Color
                end

                if flags[prefix .. "Box_Fill"] and flags[prefix .. "Boxes"] then
                    objects["fill"].Parent = objects["holder"]
                    objects["fill"].BackgroundTransparency = flags[prefix .. "Box_Fill_Transparency"]
                    
                    if flags[prefix .. "Box_Fill_Type"] == "Gradient" then
                        objects["fill"].BackgroundColor3 = rgb(255, 255, 255)
                        objects["fill_gradient"].Parent = objects["fill"]
                        objects["fill_gradient"].Color = ColorSequence.new(flags[prefix .. "Box_Fill_Color"].Color, flags[prefix .. "Box_Fill_Color2"].Color)
                        objects["fill_gradient"].Rotation = flags[prefix .. "Box_Fill_Gradient_Rotation"]
                    else
                        objects["fill"].BackgroundColor3 = flags[prefix .. "Box_Fill_Color"].Color
                        objects["fill_gradient"].Parent = esp.cache
                    end
                else
                    objects["fill"].Parent = esp.cache
                end

                for _, line in path.drawings do
                    line.Color = flags[prefix .. "Skeletons_Color"].Color
                    line.Visible = flags[prefix .. "Skeletons"]
                end

                objects[ "healthbar_holder" ].Parent = flags[ prefix .. "Healthbar" ] and objects[ "holder" ] or esp.cache
                if flags[prefix .. "Healthbar"] and path.info and path.info.humanoid then
                    path.health_changed(path.info.humanoid.Health)
                    
                    if flags[ prefix .. "Health_Mode" ] == "Gradient" then
                        objects[ "healthbar_gradient" ].Parent = objects[ "healthbar" ]
                        objects[ "healthbar_gradient" ].Color = ColorSequence.new(flags[ prefix .. "Health_High" ].Color, flags[ prefix .. "Health_Low" ].Color)
                    else
                        objects[ "healthbar_gradient" ].Parent = esp.cache
                    end
                end
                
                objects[ "weapon" ].TextColor3 = flags[prefix .. "Weapon_Color"].Color
                local tool = path.info.character:FindFirstChildOfClass("Tool")
                objects[ "weapon" ].Parent = flags[prefix .. "Weapon"] and tool and objects[ "holder" ] or esp.cache

                objects[ "distance" ].TextColor3 = flags[prefix .. "Distance_Color"].Color
                objects[ "distance" ].Parent = flags[prefix .. "Distance"] and objects[ "holder" ] or esp.cache
            end
        end

        esp.connection = run.RenderStepped:Connect(function()
            for entity, data in pairs(esp) do 
                if type(entity) == "string" or type(data) ~= "table" or not data.objects then continue end

                local is_npc = data.info and data.info.is_npc
                local prefix = is_npc and "NPC_" or ""

                if not flags[prefix .. "Enabled"] then 
                    data.objects.holder.Visible = false
                    continue
                end

                local character = data.info.character
                local humanoid = data.info.humanoid 
                
                if not (character or humanoid) then 
                    continue 
                end 

                local objects = data.objects 

                local box_size, box_pos, on_screen, distance = esp:box_solve(humanoid.RootPart)
                local holder = objects[ "holder" ]

                if holder.Visible ~= on_screen then 
                    holder.Visible = on_screen
                end 

                -- Skeletons 
                local show_skeletons = flags[prefix .. "Skeletons"] and character:FindFirstChild("UpperTorso")
                
                for i = 1, #bones do
                    local path = data.drawings[i]
                    if not path then 
                        continue  
                    end 

                    if show_skeletons then
                        local origin, destination = bones[i][1], bones[i][2]

                        local origin_3d = character:FindFirstChild(origin) 
                        local destination_3d = character:FindFirstChild(destination) 

                        if origin_3d and destination_3d then 
                            local origin_2d, on_screen_start = esp:get_screen_pos(origin_3d.Position)
                            local destination_2d, on_screen_end = esp:get_screen_pos(destination_3d.Position)
                            
                            if on_screen_start and on_screen_end then 
                                if not path.Visible then
                                    path.Visible = true
                                end
                                
                                local from = vec2(origin_2d.X, origin_2d.Y)
                                local to = vec2(destination_2d.X, destination_2d.Y)
                                
                                if path.From ~= from then path.From = from end
                                if path.To ~= to then path.To = to end
                                
                                continue -- Successfully rendered this bone, move to next
                            end 
                        end
                    end 
                    
                    -- If any condition above failed, or drawing shouldn't be shown, conceal it safely
                    if path.Visible then
                        path.Visible = false
                    end
                end 
                -- 

                if not on_screen then
                    continue
                end 
                
                local pos = dim_offset(box_pos.X, box_pos.Y) -- silly sanity check
                if pos ~= holder.Position then 
                    holder.Position = dim_offset(box_pos.X, box_pos.Y)
                end 

                local size = dim_offset(box_size.X, box_size.Y) -- more silly sanity checks
                if size ~= holder.Size then 
                    holder.Size = size
                end 

                local distance_label = objects[ "distance" ]
                if distance_label.Text ~= tostring( math.round(distance) )  .. "st" then 
                    distance_label.Text = tostring( math.round(distance) ) .. "st"
                end 

            end
        end)

        function esp:unload() 
            for entity, data in pairs(esp) do 
                if type(entity) ~= "string" and type(data) == "table" and data.objects then
                    esp:remove_object(entity)
                end
            end 

            esp.connection:Disconnect() 
            esp.player_added:Disconnect() 
            esp.player_removed:Disconnect() 
            if esp.npc_added then esp.npc_added:Disconnect() end
            if esp.npc_removed then esp.npc_removed:Disconnect() end 

            esp.cache:Destroy() 
            esp.screengui:Destroy()

            esp = nil
        end 
    -- 
end

-- Load existing players
for _,v in players:GetPlayers() do 
    if v ~= players.LocalPlayer then 
        esp:create_object(v)
    end 
end 

esp.player_added = players.PlayerAdded:Connect(function(v)
    esp:create_object(v)
end)

esp.player_removed = players.PlayerRemoving:Connect(function(v)
    esp:remove_object(v)
end)

-- Load existing NPCs
local enemies_folder = workspace:FindFirstChild("Spawned") and workspace.Spawned:FindFirstChild("Enemies")
if enemies_folder then
    for _, v in enemies_folder:GetChildren() do
        if v:IsA("Model") then
            esp:create_object(v, true)
        end
    end

    esp.npc_added = enemies_folder.ChildAdded:Connect(function(v)
        if v:IsA("Model") then
            esp:create_object(v, true)
        end
    end)

    esp.npc_removed = enemies_folder.ChildRemoved:Connect(function(v)
        if v:IsA("Model") then
            esp:remove_object(v)
        end
    end)
end

task.wait()
esp.refresh_elements()

return {
    flags = flags,
    refresh_elements = function() esp.refresh_elements() end
}
