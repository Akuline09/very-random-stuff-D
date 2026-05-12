local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Camera     = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

getgenv().HeadSize       = 6
getgenv().HeadHitboxOn   = false
getgenv().HeadTeamCheck  = false
getgenv().HeadFriendOnly = false

getgenv().ESP_Box       = false
getgenv().ESP_Tracer    = false
getgenv().ESP_Highlight = false
getgenv().ESP_Info      = false

getgenv().AuraOn         = false
getgenv().AuraRange      = 8
getgenv().AuraTeamCheck  = false
getgenv().AuraFriendOnly = false
getgenv().AuraMode       = "tool"

getgenv().TargetPlayers   = true
getgenv().TargetNPC       = false
getgenv().NPCHostileOnly  = false
getgenv().NPCFriendlyOnly = false

local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- NPC cache
local npcCache    = {}
local lastScan    = 0
local SCAN_RATE   = 2

local function refreshNPCs()
    npcCache = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LocalPlayer.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hum and hrp then
                local isPC = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character == obj then isPC = true; break end
                end
                if not isPC then table.insert(npcCache, obj) end
            end
        end
    end
end

-- Hostile = NPC has an ObjectValue "Target"/"AggroTarget" etc pointing at a player character
-- Friendly = does not attack players
local TARGET_NAMES = {"target","aggroTarget","attacktarget","currenttarget","targetplayer","victim"}

local function getNPCAlign(model)
    -- attribute check first
    for _, a in ipairs({"Hostile","IsHostile","Enemy","IsEnemy","Aggressive","hostile","enemy"}) do
        if model:GetAttribute(a) == true then return "hostile" end
    end
    for _, a in ipairs({"Friendly","IsFriendly","Ally","IsAlly","friendly","ally"}) do
        if model:GetAttribute(a) == true then return "friendly" end
    end
    -- ObjectValue pointing at a player character = hostile
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("ObjectValue") and desc.Value then
            local n = desc.Name:lower()
            for _, tn in ipairs(TARGET_NAMES) do
                if n == tn then
                    for _, p in ipairs(Players:GetPlayers()) do
                        local chr = p.Character
                        if chr and (desc.Value == chr or desc.Value:IsDescendantOf(chr)) then
                            return "hostile"
                        end
                    end
                end
            end
        end
        if desc:IsA("BoolValue") then
            local n = desc.Name:lower()
            if (n=="hostile" or n=="enemy" or n=="aggressive") and desc.Value then return "hostile" end
            if (n=="friendly" or n=="ally") and desc.Value then return "friendly" end
        end
    end
    return "unknown"
end

local function shouldTargetNPC(model)
    if not TargetNPC then return false end
    if not model or not model.Parent then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if NPCHostileOnly or NPCFriendlyOnly then
        local align = getNPCAlign(model)
        if NPCHostileOnly  and align ~= "hostile"  then return false end
        if NPCFriendlyOnly and align ~= "friendly" then return false end
    end
    return true
end

local function getNPCColor(model)
    local align = getNPCAlign(model)
    if align == "hostile"  then return Color3.fromRGB(255, 60, 60) end
    if align == "friendly" then return Color3.fromRGB(60, 220, 60) end
    return Color3.fromRGB(255, 160, 0)
end

local function shouldTarget(v)
    if v == LocalPlayer then return false end
    if not TargetPlayers then return false end
    if HeadTeamCheck  and LocalPlayer.Team == v.Team then return false end
    if HeadFriendOnly and LocalPlayer:IsFriendsWith(v.UserId) then return false end
    return true
end

local function auraTarget(v)
    if v == LocalPlayer then return false end
    if AuraTeamCheck  and LocalPlayer.Team == v.Team then return false end
    if AuraFriendOnly and LocalPlayer:IsFriendsWith(v.UserId) then return false end
    return true
end

local function getTeamColor(v)
    if v.Team then return v.Team.TeamColor.Color end
    return Color3.fromRGB(255, 50, 50)
end

-- HEAD HITBOX — always iterate full cache so turning off properly resets all NPCs
local function applyHeads()
    for _, v in ipairs(Players:GetPlayers()) do
        if v == LocalPlayer or not v.Character then continue end
        local head = v.Character:FindFirstChild("Head")
        if not head then continue end
        if HeadHitboxOn and shouldTarget(v) then
            head.Size = Vector3.new(HeadSize, HeadSize, HeadSize)
            head.Transparency = 0.5; head.Massless = true; head.CanCollide = false
        else
            head.Size = Vector3.new(2, 1, 1)
            head.Transparency = 0; head.Massless = false; head.CanCollide = false
        end
    end
    for _, model in ipairs(npcCache) do
        if not model or not model.Parent then continue end
        local head = model:FindFirstChild("Head")
        if not head then continue end
        if HeadHitboxOn and shouldTargetNPC(model) then
            head.Size = Vector3.new(HeadSize, HeadSize, HeadSize)
            head.Transparency = 0.5; head.Massless = true; head.CanCollide = false
        else
            -- always reset, even when TargetNPC is turned off mid-session
            head.Size = Vector3.new(2, 1, 1)
            head.Transparency = 0; head.Massless = false; head.CanCollide = false
        end
    end
end

RunService.RenderStepped:Connect(applyHeads)

RunService.RenderStepped:Connect(function()
    if tick() - lastScan >= SCAN_RATE then
        refreshNPCs(); lastScan = tick()
    end
end)

-- SWORD AURA
RunService.RenderStepped:Connect(function()
    if not AuraOn then return end
    local chr = LocalPlayer.Character
    if not chr then return end
    local inRange = false

    for _, v in ipairs(Players:GetPlayers()) do
        if not auraTarget(v) then continue end
        local vc = v.Character; if not vc then continue end
        local hum = vc:FindFirstChild("Humanoid")
        local hrp = vc:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp or hum.Health <= 0 then continue end
        if LocalPlayer:DistanceFromCharacter(hrp.Position) <= AuraRange then
            inRange = true
            if AuraMode == "tool" then
                local tool = chr:FindFirstChildOfClass("Tool")
                if tool and tool:FindFirstChild("Handle") then
                    tool:Activate()
                    for _, part in next, vc:GetChildren() do
                        if part:IsA("BasePart") then
                            firetouchinterest(tool.Handle, part, 0)
                            firetouchinterest(tool.Handle, part, 1)
                        end
                    end
                end
            end
        end
    end

    if TargetNPC then
        for _, model in ipairs(npcCache) do
            if not shouldTargetNPC(model) then continue end
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hrp and LocalPlayer:DistanceFromCharacter(hrp.Position) <= AuraRange then
                inRange = true
                if AuraMode == "tool" then
                    local tool = chr:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Handle") then
                        tool:Activate()
                        for _, part in next, model:GetChildren() do
                            if part:IsA("BasePart") then
                                firetouchinterest(tool.Handle, part, 0)
                                firetouchinterest(tool.Handle, part, 1)
                            end
                        end
                    end
                end
            end
        end
    end

    if AuraMode == "m1" and inRange then
        local tool = chr:FindFirstChildOfClass("Tool")
        if isMobile then
            if tool then pcall(function() tool:Activate() end) end
        else
            pcall(function() mouse1click() end)
        end
    end
end)

-- ESP
local espData = {}

local function clearESP(key)
    local d = espData[key]; if not d then return end
    for _, obj in pairs(d) do
        pcall(function()
            if typeof(obj) == "Instance" then obj:Destroy() else obj:Remove() end
        end)
    end
    espData[key] = nil
end

local function clearAll()
    for k in pairs(espData) do clearESP(k) end
end

local function newLine(col)
    local l = Drawing.new("Line")
    l.Visible=true; l.Color=col; l.Thickness=1.2; l.Transparency=1
    return l
end

local function newText(col)
    local t = Drawing.new("Text")
    t.Visible=true; t.Color=col; t.Size=13; t.Font=Drawing.Fonts.UI
    t.Outline=true; t.OutlineColor=Color3.new(0,0,0); t.Center=true
    return t
end

local function getBounds(model)
    local hrp  = model:FindFirstChild("HumanoidRootPart")
    local head = model:FindFirstChild("Head")
    if not hrp or not head then return end
    local top, onT = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y*0.5, 0))
    local bot, onB = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
    if not onT or not onB or top.Z <= 0 then return end
    return top, bot
end

local function drawESP(key, model, col, nameStr, dist)
    if not espData[key] then espData[key] = {} end
    local d = espData[key]
    if ESP_Highlight then
        if not d.hl then
            local hl = Instance.new("SelectionBox")
            hl.LineThickness=0.04; hl.SurfaceTransparency=0.72; hl.Parent=workspace
            d.hl = hl
        end
        d.hl.Adornee=model; d.hl.Color3=col; d.hl.SurfaceColor3=col
    elseif d.hl then d.hl:Destroy(); d.hl=nil end

    local top, bot = getBounds(model)
    if not top then
        for _, k in pairs({"b1","b2","b3","b4","tr","nm","di"}) do
            if d[k] then pcall(function() d[k]:Remove() end); d[k]=nil end
        end
        return
    end

    local vp = Camera.ViewportSize
    local tb = Vector2.new(vp.X*0.5, vp.Y)
    local h=math.abs(bot.Y-top.Y); local w=h*0.55; local cx=top.X
    local x1,y1=cx-w*0.5,top.Y; local x2,y2=cx+w*0.5,bot.Y

    if ESP_Box then
        if not d.b1 then d.b1=newLine(col);d.b2=newLine(col);d.b3=newLine(col);d.b4=newLine(col) end
        d.b1.Color=col;d.b1.From=Vector2.new(x1,y1);d.b1.To=Vector2.new(x2,y1)
        d.b2.Color=col;d.b2.From=Vector2.new(x2,y1);d.b2.To=Vector2.new(x2,y2)
        d.b3.Color=col;d.b3.From=Vector2.new(x2,y2);d.b3.To=Vector2.new(x1,y2)
        d.b4.Color=col;d.b4.From=Vector2.new(x1,y2);d.b4.To=Vector2.new(x1,y1)
        d.b1.Visible=true;d.b2.Visible=true;d.b3.Visible=true;d.b4.Visible=true
    elseif d.b1 then d.b1.Visible=false;d.b2.Visible=false;d.b3.Visible=false;d.b4.Visible=false end

    if ESP_Tracer then
        if not d.tr then d.tr=newLine(col) end
        d.tr.Color=col;d.tr.From=tb;d.tr.To=Vector2.new(cx,y2);d.tr.Visible=true
    elseif d.tr then d.tr.Visible=false end

    if ESP_Info then
        if not d.nm then d.nm=newText(col) end
        if not d.di then d.di=newText(Color3.new(1,1,1)) end
        d.nm.Color=col;d.nm.Text=nameStr;d.nm.Position=Vector2.new(cx,y1-16);d.nm.Visible=true
        d.di.Text=dist.." m";d.di.Position=Vector2.new(cx,y1-3);d.di.Visible=true
    elseif d.nm then d.nm.Visible=false; if d.di then d.di.Visible=false end end
end

RunService.RenderStepped:Connect(function()
    local anyOn = ESP_Box or ESP_Tracer or ESP_Highlight or ESP_Info
    if not anyOn then clearAll(); return end

    local lhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    if TargetPlayers then
        for _, v in ipairs(Players:GetPlayers()) do
            if not shouldTarget(v) then clearESP(v); continue end
            local chr = v.Character; if not chr then clearESP(v); continue end
            local hrp = chr:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
            local dist = lhrp and math.floor((lhrp.Position-hrp.Position).Magnitude) or 0
            drawESP(v, chr, getTeamColor(v), v.DisplayName, dist)
        end
    end

    if TargetNPC then
        local active = {}
        for _, model in ipairs(npcCache) do
            if not shouldTargetNPC(model) then clearESP(model); continue end
            local hrp = model:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
            local dist = lhrp and math.floor((lhrp.Position-hrp.Position).Magnitude) or 0
            active[model] = true
            drawESP(model, model, getNPCColor(model), model.Name, dist)
        end
        for k in pairs(espData) do
            local isPlayer = false
            for _, p in ipairs(Players:GetPlayers()) do if p==k then isPlayer=true; break end end
            if not isPlayer and not active[k] then clearESP(k) end
        end
    end

    for k in pairs(espData) do
        if typeof(k)=="Instance" and k:IsA("Player") and not k.Parent then clearESP(k) end
    end
end)

Players.PlayerRemoving:Connect(clearESP)

-- ============================================================
-- RAYFIELD UI
-- ============================================================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name             = "Yeu em Giang",
    LoadingTitle     = "operation1",
    LoadingSubtitle  = "remake by : Aholo",
    Theme            = "Default",
    ConfigurationSaving = { Enabled = false },
    KeySystem        = false,
})

-- ── TAB: Target ─────────────────────────────────────────────
local TabTarget = Window:CreateTab("Target", 4483362458)

TabTarget:CreateSection("Target Mode")

TabTarget:CreateToggle({
    Name = "Players", CurrentValue = true, Flag = "TP",
    Callback = function(v) getgenv().TargetPlayers = v end,
})

TabTarget:CreateToggle({
    Name = "NPC", CurrentValue = false, Flag = "TNPC",
    Callback = function(v)
        getgenv().TargetNPC = v
        if v then refreshNPCs() end
        if not v then
            -- reset all cached NPC heads immediately
            for _, model in ipairs(npcCache) do
                pcall(function()
                    local head = model:FindFirstChild("Head")
                    if head then
                        head.Size=Vector3.new(2,1,1)
                        head.Transparency=0; head.Massless=false; head.CanCollide=false
                    end
                end)
            end
        end
    end,
})

TabTarget:CreateSection("NPC Filter")
TabTarget:CreateParagraph({
    Title = "Color legend",
    Content = "Red = Hostile  |  Green = Friendly  |  Orange = Unknown\nDetection: Target ObjectValue pointing to player = Hostile",
})

TabTarget:CreateToggle({
    Name = "Hostile Only", CurrentValue = false, Flag = "NPCHos",
    Callback = function(v)
        getgenv().NPCHostileOnly = v
        if v then getgenv().NPCFriendlyOnly = false
            Rayfield:Notify({ Title="NPC Filter", Content="Hostile Only ON — Friendly OFF", Duration=3 })
        end
    end,
})

TabTarget:CreateToggle({
    Name = "Friendly Only", CurrentValue = false, Flag = "NPCFri",
    Callback = function(v)
        getgenv().NPCFriendlyOnly = v
        if v then getgenv().NPCHostileOnly = false
            Rayfield:Notify({ Title="NPC Filter", Content="Friendly Only ON — Hostile OFF", Duration=3 })
        end
    end,
})

-- ── TAB: Hitbox ──────────────────────────────────────────────
local TabHitbox = Window:CreateTab("Hitbox", 4483362458)

TabHitbox:CreateSection("Head Hitbox")

TabHitbox:CreateInput({
    Name = "Head Size", CurrentValue = "6", PlaceholderText = "1 – 100",
    RemoveTextAfterFocusLost = false, Flag = "HSize",
    Callback = function(v)
        local n = tonumber(v)
        if n then getgenv().HeadSize = math.clamp(n, 1, 100) end
    end,
})

TabHitbox:CreateToggle({
    Name = "Head Hitbox  [F]", CurrentValue = false, Flag = "HHit",
    Callback = function(s)
        getgenv().HeadHitboxOn = s
        if QuickBtn then
            QuickBtn.Text = s and "HEAD\nON" or "HEAD\nOFF"
            QuickBtn.BackgroundColor3 = s
                and Color3.fromRGB(0,185,85) or Color3.fromRGB(0,100,170)
        end
    end,
})

TabHitbox:CreateSection("Filters")

TabHitbox:CreateToggle({
    Name = "Team Check", CurrentValue = false, Flag = "HTC",
    Callback = function(v) getgenv().HeadTeamCheck = v end,
})

TabHitbox:CreateToggle({
    Name = "Skip Friends", CurrentValue = false, Flag = "HFC",
    Callback = function(v) getgenv().HeadFriendOnly = v end,
})

-- ── TAB: ESP ─────────────────────────────────────────────────
local TabESP = Window:CreateTab("ESP", 4483362458)

TabESP:CreateSection("Draw")

TabESP:CreateToggle({
    Name = "2D Box", CurrentValue = false, Flag = "EBox",
    Callback = function(v) getgenv().ESP_Box = v end,
})

TabESP:CreateToggle({
    Name = "Tracers", CurrentValue = false, Flag = "ETrace",
    Callback = function(v) getgenv().ESP_Tracer = v end,
})

TabESP:CreateToggle({
    Name = "Highlight", CurrentValue = false, Flag = "EHL",
    Callback = function(v) getgenv().ESP_Highlight = v end,
})

TabESP:CreateToggle({
    Name = "Name + Distance", CurrentValue = false, Flag = "EInfo",
    Callback = function(v) getgenv().ESP_Info = v end,
})

-- ── TAB: Aura ────────────────────────────────────────────────
local TabAura = Window:CreateTab("Aura", 4483362458)

TabAura:CreateSection("Mode")

TabAura:CreateDropdown({
    Name = "Aura Mode", Options = {"Aura Tool", "Auto M1"},
    CurrentOption = {"Aura Tool"}, Flag = "AMode", MultipleOptions = false,
    Callback = function(v)
        getgenv().AuraMode = (v[1] == "Aura Tool") and "tool" or "m1"
    end,
})

TabAura:CreateSection("Settings")

TabAura:CreateInput({
    Name = "Range", CurrentValue = "8", PlaceholderText = "1 – 50",
    RemoveTextAfterFocusLost = false, Flag = "ARange",
    Callback = function(v)
        local n = tonumber(v)
        if n then getgenv().AuraRange = math.clamp(n, 1, 50) end
    end,
})

TabAura:CreateToggle({
    Name = "Enable Aura  [G]", CurrentValue = false, Flag = "AOn",
    Callback = function(v) getgenv().AuraOn = v end,
})

TabAura:CreateSection("Filters")

TabAura:CreateToggle({
    Name = "Team Check", CurrentValue = false, Flag = "ATC",
    Callback = function(v) getgenv().AuraTeamCheck = v end,
})

TabAura:CreateToggle({
    Name = "Skip Friends", CurrentValue = false, Flag = "AFC",
    Callback = function(v) getgenv().AuraFriendOnly = v end,
})

-- ── TAB: Settings ────────────────────────────────────────────
local TabSettings = Window:CreateTab("Settings", 4483362458)

TabSettings:CreateSection("Quick Button")

TabSettings:CreateToggle({
    Name = "Show Quick Toggle Button", CurrentValue = true, Flag = "ShowQuick",
    Callback = function(v)
        if QuickGui then QuickGui.Enabled = v end
    end,
})

TabSettings:CreateParagraph({
    Title  = "Keybinds",
    Content = "F  =  toggle Head Hitbox\nG  =  toggle Aura",
})

-- ============================================================
-- QUICK TOGGLE BUTTON  (separate ScreenGui, always on top)
-- ============================================================
QuickGui = Instance.new("ScreenGui")
QuickGui.Name = "QuickToggle_op1"
QuickGui.ResetOnSpawn = false
QuickGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
QuickGui.Parent = game.CoreGui

QuickBtn = Instance.new("TextButton")
QuickBtn.Parent = QuickGui
QuickBtn.Size   = UDim2.new(0, 68, 0, 68)
QuickBtn.Position = UDim2.new(1, -78, 1, -86)
QuickBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 170)
QuickBtn.BackgroundTransparency = 0.1
QuickBtn.Text = "HEAD\nOFF"
QuickBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
QuickBtn.Font = Enum.Font.GothamBold
QuickBtn.TextSize = 12
QuickBtn.TextWrapped = true
QuickBtn.Active = true
QuickBtn.Draggable = true
Instance.new("UICorner", QuickBtn).CornerRadius = UDim.new(0.2, 0)
local qs = Instance.new("UIStroke", QuickBtn)
qs.Color = Color3.fromRGB(0, 200, 255); qs.Thickness = 2

QuickBtn.MouseButton1Click:Connect(function()
    local newState = not HeadHitboxOn
    getgenv().HeadHitboxOn = newState
    QuickBtn.Text = newState and "HEAD\nON" or "HEAD\nOFF"
    QuickBtn.BackgroundColor3 = newState
        and Color3.fromRGB(0, 185, 85) or Color3.fromRGB(0, 100, 170)
    -- sync Rayfield toggle visual
    Rayfield:Notify({
        Title   = "Head Hitbox",
        Content = newState and "ON" or "OFF",
        Duration = 1.5,
    })
end)

-- ============================================================
-- KEYBINDS
-- ============================================================
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.F then
        local s = not HeadHitboxOn
        getgenv().HeadHitboxOn = s
        QuickBtn.Text = s and "HEAD\nON" or "HEAD\nOFF"
        QuickBtn.BackgroundColor3 = s
            and Color3.fromRGB(0, 185, 85) or Color3.fromRGB(0, 100, 170)
    end
    if inp.KeyCode == Enum.KeyCode.G then
        getgenv().AuraOn = not AuraOn
    end
end)

-- ============================================================
-- CREDIT
-- ============================================================
task.delay(2, function()
    Rayfield:Notify({
        Title   = "operation1",
        Content = "remake by : Aholo  |  F = hitbox  G = aura",
        Duration = 6,
    })
end)
