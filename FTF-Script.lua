local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Camera             = workspace.CurrentCamera
local LocalPlayer        = Players.LocalPlayer

local BeastESPEnabled       = false
local PlayerESPEnabled      = false
local ComputerESPEnabled    = false
local BeastPowerESPEnabled  = false

local BeastHighlights    = {}
local PlayerHighlights   = {}
local ComputerHighlights = {}
local NameLabels         = {}
local PowerLabels        = {}

local currentPower = "Waiting..."

local function getIsBeast(player)
    local tmp = player:FindFirstChild("TempPlayerStatsModule")
    if not tmp then return false end
    local v = tmp:FindFirstChild("IsBeast")
    return v and v.Value == true
end

local function updatePower()
    local cp = ReplicatedStorage:FindFirstChild("CurrentPower")
    if cp and cp.Value ~= "" then
        currentPower = cp.Value
    end
end

local cp = ReplicatedStorage:FindFirstChild("CurrentPower")
if cp then
    if cp.Value ~= "" then currentPower = cp.Value end
    cp.Changed:Connect(function(val)
        currentPower = (val ~= "" and val) or "Waiting..."
    end)
end

task.spawn(function()
    while true do
        task.wait(1)
        updatePower()
    end
end)

local function makeHighlight(adornee, color, parent)
    local hl = Instance.new("Highlight")
    hl.FillColor           = color
    hl.OutlineColor        = color
    hl.FillTransparency    = 0.3
    hl.OutlineTransparency = 0
    hl.Adornee = adornee
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee             = adornee
    hl.Enabled             = false
    hl.Parent              = parent or adornee
    return hl
end

local function destroyHL(tbl, key)
    if tbl[key] then tbl[key]:Destroy() tbl[key] = nil end
end

local function watchPlayer(player)
    if player == LocalPlayer then return end

    local lbl = Drawing.new("Text")
    lbl.Visible = false
    lbl.Center  = true
    lbl.Outline = true
    lbl.Color   = Color3.fromRGB(255, 255, 255)
    lbl.Size    = 14
    lbl.ZIndex  = 5
    NameLabels[player] = lbl

    local plbl = Drawing.new("Text")
    plbl.Visible = false
    plbl.Center  = true
    plbl.Outline = true
    plbl.Color   = Color3.fromRGB(255, 165, 0)
    plbl.Size    = 13
    plbl.ZIndex  = 5
    PowerLabels[player] = plbl

    local function hookIsBeast(tmp)
        local function bindVal(v)
            v.Changed:Connect(function(val)
                task.wait(0.2)
                if val then
                    destroyHL(PlayerHighlights, player)
                    if player.Character then
                        BeastHighlights[player] = makeHighlight(player.Character, Color3.fromRGB(255, 0, 0))
                    end
                else
                    destroyHL(BeastHighlights, player)
                    if player.Character then
                        PlayerHighlights[player] = makeHighlight(player.Character, Color3.fromRGB(0, 100, 255))
                    end
                end
            end)
        end
        local v = tmp:FindFirstChild("IsBeast")
        if v then bindVal(v)
        else tmp.ChildAdded:Connect(function(c) if c.Name == "IsBeast" then bindVal(c) end end) end
    end

    local tmp = player:FindFirstChild("TempPlayerStatsModule")
    if tmp then hookIsBeast(tmp)
    else player.ChildAdded:Connect(function(c) if c.Name == "TempPlayerStatsModule" then hookIsBeast(c) end end) end

    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        destroyHL(BeastHighlights, player)
        destroyHL(PlayerHighlights, player)
        if getIsBeast(player) then
            BeastHighlights[player] = makeHighlight(char, Color3.fromRGB(255, 0, 0))
        else
            PlayerHighlights[player] = makeHighlight(char, Color3.fromRGB(0, 100, 255))
        end
    end)

    task.wait(0.1)
    if player.Character then
        if getIsBeast(player) then
            BeastHighlights[player] = makeHighlight(player.Character, Color3.fromRGB(255, 0, 0))
        else
            PlayerHighlights[player] = makeHighlight(player.Character, Color3.fromRGB(0, 100, 255))
        end
    end
end

local function cleanupPlayer(player)
    destroyHL(BeastHighlights, player)
    destroyHL(PlayerHighlights, player)
    if NameLabels[player]  then NameLabels[player]:Remove()  NameLabels[player]  = nil end
    if PowerLabels[player] then PowerLabels[player]:Remove() PowerLabels[player] = nil end
end

for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)

local function setupComputers()
    local function applyToComputer(model)
        if ComputerHighlights[model] then return end
        local hl = makeHighlight(model, Color3.fromRGB(170, 0, 255), workspace)
        ComputerHighlights[model] = hl
        model.AncestryChanged:Connect(function()
            if not model:IsDescendantOf(workspace) then
                destroyHL(ComputerHighlights, model)
            end
        end)
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "ComputerTable" and obj:IsA("Model") then applyToComputer(obj) end
    end
    workspace.DescendantAdded:Connect(function(obj)
        if obj.Name == "ComputerTable" and obj:IsA("Model") then applyToComputer(obj) end
    end)
end

setupComputers()

RunService.RenderStepped:Connect(function()
    for player, lbl in pairs(NameLabels) do
        local isBeast    = getIsBeast(player)
        local char       = player.Character
        local showBeast  = BeastESPEnabled  and isBeast     and char ~= nil
        local showPlayer = PlayerESPEnabled and not isBeast and char ~= nil

        if BeastHighlights[player]  then BeastHighlights[player].Enabled  = showBeast  end
        if PlayerHighlights[player] then PlayerHighlights[player].Enabled = showPlayer end

        local plbl      = PowerLabels[player]
        local show      = showBeast or showPlayer
        local didRender = false

        if show then
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            if root then
                local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
local depth = screenPos.Z
if depth > 0 then
                    local root2 = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                    local feet = root2 and (root2.Position - Vector3.new(0, 3, 0)) or root2.Position
                    local feetPos = Camera:WorldToViewportPoint(feet)
                    lbl.Position = Vector2.new(feetPos.X, feetPos.Y + 10)
                    lbl.Text     = player.DisplayName
                    lbl.Size     = 24
                    lbl.Visible  = true

                    if plbl then
                        if showBeast and BeastPowerESPEnabled then
                            plbl.Position = Vector2.new(feetPos.X, feetPos.Y + 28)
                            plbl.Text     = "Power: " .. tostring(currentPower)
                            plbl.Size     = 22
                            plbl.Color    = Color3.fromRGB(255, 165, 0)
                            plbl.Visible  = true
                        else
                            plbl.Visible = false
                        end
                    end

                    didRender = true
                end
            end
        end

        if not didRender then
            lbl.Visible = false
            if plbl then plbl.Visible = false end
        end
    end

    for _, hl in pairs(ComputerHighlights) do
        hl.Enabled = ComputerESPEnabled
    end
end)

local Window = Library:CreateWindow({
    Title    = 'FTF Script',
    Center   = true,
    AutoShow = true,
    Size     = UDim2.fromOffset(400, 300),
})

local Tabs = {
    Main = Window:AddTab('Main'),
    ESP  = Window:AddTab('ESP'),
}

Tabs.Main:AddLeftGroupbox('Info'):AddLabel('Flee the Facility Script')

local ESPBox = Tabs.ESP:AddLeftGroupbox('ESP')

ESPBox:AddToggle('PlayerESP', {
    Text     = 'Enable Player ESP',
    Default  = false,
    Callback = function(v)
        PlayerESPEnabled = v
        for _, hl in pairs(PlayerHighlights) do hl.Enabled = v end
    end,
})

ESPBox:AddDivider()

ESPBox:AddToggle('ComputerESP', {
    Text     = 'Enable Computer ESP',
    Default  = false,
    Callback = function(v)
        ComputerESPEnabled = v
        for _, hl in pairs(ComputerHighlights) do hl.Enabled = v end
    end,
})

ESPBox:AddDivider()

ESPBox:AddToggle('BeastESP', {
    Text     = 'Enable Beast ESP',
    Default  = false,
    Callback = function(v)
        BeastESPEnabled = v
        for _, hl in pairs(BeastHighlights) do hl.Enabled = v end
        if not v then
            for _, plbl in pairs(PowerLabels) do plbl.Visible = false end
        end
    end,
})

ESPBox:AddDivider()

ESPBox:AddToggle('BeastPowerESP', {
    Text     = 'Show Beast Power',
    Default  = false,
    Callback = function(v)
        BeastPowerESPEnabled = v
        if not v then
            for _, plbl in pairs(PowerLabels) do plbl.Visible = false end
        end
    end,
})

Library:Notify('FTF Loaded!', 3)
