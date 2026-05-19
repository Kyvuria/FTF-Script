local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Camera      = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local BeastESPEnabled    = true
local PlayerESPEnabled   = true
local ComputerESPEnabled = true

local BeastHighlights    = {}
local PlayerHighlights   = {}
local ComputerHighlights = {}
local NameLabels         = {}

-- ── helpers ──────────────────────────────────────
local function getIsBeast(player)
    local tmp = player:FindFirstChild("TempPlayerStatsModule")
    if not tmp then return false end
    local v = tmp:FindFirstChild("IsBeast")
    return v and v.Value == true
end

local function makeHighlight(adornee, color, parent)
    local hl = Instance.new("Highlight")
    hl.FillColor           = color
    hl.OutlineColor        = color
    hl.FillTransparency    = 0.4
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee             = adornee
    hl.Parent              = parent or adornee
    return hl
end

local function destroyHL(tbl, key)
    if tbl[key] then tbl[key]:Destroy() tbl[key] = nil end
end

-- ── player ESP ───────────────────────────────────
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
    if NameLabels[player] then NameLabels[player]:Remove() NameLabels[player] = nil end
end

for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)

-- ── computer ESP ─────────────────────────────────
local function setupComputers()
    -- find all ComputerTable models anywhere in workspace
    local function applyToComputer(model)
        if ComputerHighlights[model] then return end
        local hl = makeHighlight(model, Color3.fromRGB(170, 0, 255), workspace)
        ComputerHighlights[model] = hl

        -- clean up if computer gets removed
        model.AncestryChanged:Connect(function()
            if not model:IsDescendantOf(workspace) then
                destroyHL(ComputerHighlights, model)
            end
        end)
    end

    -- scan existing
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "ComputerTable" and obj:IsA("Model") then
            applyToComputer(obj)
        end
    end

    -- watch for new ones
    workspace.DescendantAdded:Connect(function(obj)
        if obj.Name == "ComputerTable" and obj:IsA("Model") then
            applyToComputer(obj)
        end
    end)
end

setupComputers()

-- ── render loop ──────────────────────────────────
RunService.RenderStepped:Connect(function()
    -- player/beast name labels
    for player, lbl in pairs(NameLabels) do
        local isBeast    = getIsBeast(player)
        local char       = player.Character
        local showBeast  = BeastESPEnabled  and isBeast     and char ~= nil
        local showPlayer = PlayerESPEnabled and not isBeast and char ~= nil

        if BeastHighlights[player]  then BeastHighlights[player].Enabled  = showBeast  end
        if PlayerHighlights[player] then PlayerHighlights[player].Enabled = showPlayer end

        local show = showBeast or showPlayer
        if show then
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            if root then
                local sp, depth = Camera:WorldToViewportPoint(root.Position)
                if depth > 0 then
                    lbl.Position = Vector2.new(sp.X, sp.Y - 55)
                    lbl.Text     = player.DisplayName
                    lbl.Visible  = true
                    continue
                end
            end
        end
        lbl.Visible = false
    end

    -- computer highlights toggle
    for _, hl in pairs(ComputerHighlights) do
        hl.Enabled = ComputerESPEnabled
    end
end)

-- ── UI ───────────────────────────────────────────
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
    Default  = true,
    Callback = function(v) PlayerESPEnabled = v end,
})

ESPBox:AddDivider()

ESPBox:AddToggle('ComputerESP', {
    Text     = 'Enable Computer ESP',
    Default  = true,
    Callback = function(v) ComputerESPEnabled = v end,
})

ESPBox:AddDivider()

ESPBox:AddToggle('BeastESP', {
    Text     = 'Enable Beast ESP',
    Default  = true,
    Callback = function(v) BeastESPEnabled = v end,
})

Library:Notify('FTF Loaded!', 3)