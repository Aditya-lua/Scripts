-- Ducky Hub | Pure Headless Kaitun
-- discord.gg/s6qfm7uycS

getgenv().DuckyConfig = {
    ["Kaitun"] = {
        ["Ultra Fast Roll"] = true,
        ["Auto Rebirth"] = true,
        ["Auto Buy Zones"] = true,
        ["Auto Teleport Max Zone"] = true,
        ["Auto Equip Best"] = true,
        ["Smart Auto Craft"] = true,
        ["Auto Claim Recipes"] = true,
        ["Auto Claim Index"] = true,
        ["Auto Collect Drops"] = true,
        ["Auto Use Boosts"] = true
    },
    ["Performance"] = {
        ["Black Screen (Anti-Lag)"] = false, -- Set to true if AFKing overnight
        ["Optimization"] = true
    }
}

-- ==========================================
-- CORE SETUP & MODULES
-- ==========================================
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Source = ReplicatedStorage:WaitForChild("Source")
local Features = Source:WaitForChild("Features")
local GameItems = Source:WaitForChild("Game"):WaitForChild("Items")

local Modules = {
    DataServiceClient = require(Packages:WaitForChild("DataService")).client,
    Zones = require(GameItems:WaitForChild("Zones")),
    RebirthUtils = require(Features:WaitForChild("Rebirth"):WaitForChild("RebirthServiceUtils")),
    CraftingUtils = require(Features:WaitForChild("Crafting"):WaitForChild("CraftingServiceUtils")),
}

local rPath = Packages:WaitForChild("_Index"):WaitForChild("leifstout_networker@0.3.1"):WaitForChild("networker"):WaitForChild("_remotes")
local function getRemote(s) return rPath:WaitForChild(s):WaitForChild("RemoteFunction") end
local Remotes = {
    Roll = getRemote("RollService"),
    Rebirth = getRemote("RebirthService"),
    Zones = getRemote("ZonesService"),
    Inventory = getRemote("InventoryService"),
    Loot = getRemote("LootService"),
    Crafting = getRemote("CraftingService"),
    Index = getRemote("IndexService"),
    Boost = getRemote("BoostService")
}

-- ==========================================
-- ANTI AFK & PERFORMANCE
-- ==========================================
-- 10-minute jump and constant idle bypass
LocalPlayer.Idled:Connect(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
task.spawn(function() while true do task.wait(600); pcall(function() LocalPlayer.Character.Humanoid.Jump = true end) end end)

if getgenv().DuckyConfig.Performance["Optimization"] then
    pcall(function() Lighting.GlobalShadows = false; for _, v in pairs(workspace:GetDescendants()) do if v:IsA("BasePart") then v.CastShadow = false; v.Material = Enum.Material.SmoothPlastic end end end)
end

if getgenv().DuckyConfig.Performance["Black Screen (Anti-Lag)"] then
    for _, v in ipairs(CoreGui:GetChildren()) do if v.Name == "DuckyBlackScreen" then v:Destroy() end end
    local bs = Instance.new("ScreenGui", CoreGui); bs.Name = "DuckyBlackScreen"; bs.IgnoreGuiInset = true; bs.DisplayOrder = 9999
    local bf = Instance.new("Frame", bs); bf.Size = UDim2.new(1,0,1,0); bf.BackgroundColor3 = Color3.new(0,0,0)
    local tx = Instance.new("TextLabel", bf); tx.Size = UDim2.new(1,0,1,0); tx.BackgroundTransparency = 1; tx.Text = "DUCKY GHOST MODE\nAFK RUNNING\n(Pure Headless)" ; tx.TextColor3 = Color3.fromRGB(100,100,100); tx.Font = Enum.Font.GothamBold; tx.TextSize = 24
    pcall(function() RunService:Set3dRenderingEnabled(false) end)
end

-- ==========================================
-- KAITUN AUTOMATION LOOPS
-- ==========================================
local K = getgenv().DuckyConfig.Kaitun

-- Fast Roll
task.spawn(function()
    while true do
        if K["Ultra Fast Roll"] then
            pcall(function() Remotes.Roll:InvokeServer("requestRoll") end)
        end
        task.wait(0.05)
    end
end)

-- Rebirth
task.spawn(function()
    while true do
        if K["Auto Rebirth"] then
            local r = tonumber(Modules.DataServiceClient:get("rebirths")) or 0
            if Modules.RebirthUtils.canAffordRebirth(r, tonumber(Modules.DataServiceClient:get("goop")) or 0) then Remotes.Rebirth:InvokeServer("requestRebirth") end
        end
        task.wait(1)
    end
end)

-- Buy Zones
task.spawn(function()
    while true do
        if K["Auto Buy Zones"] then
            local nz = (tonumber(Modules.DataServiceClient:get("maxZone")) or 1) + 1
            if Modules.Zones.hasZone(nz) and (tonumber(Modules.DataServiceClient:get("coins")) or 0) >= (tonumber(Modules.Zones.getZone(nz).price) or 0) then
                pcall(function() Remotes.Zones:InvokeServer("requestPurchaseZone") end)
            end
        end
        task.wait(0.75)
    end
end)

-- Auto Teleport Max Zone
local function getHighestUnlockedZone()
    local zones = workspace:FindFirstChild("Zones") or workspace:FindFirstChild("Areas")
    if not zones then return nil end
    local highest = 0
    for _, z in ipairs(zones:GetChildren()) do
        local num = tonumber(z.Name)
        if num and z:FindFirstChild("Gate") and z.Gate:FindFirstChild("Back") and not z.Gate.Back.CanCollide then
            if num > highest then highest = num end
        end
    end
    local target = highest + 1
    if zones:FindFirstChild(tostring(target)) then return target end
    return highest > 0 and highest or nil
end

local function getZoneCFrame(zoneNum)
    local zones = workspace:FindFirstChild("Zones") or workspace:FindFirstChild("Areas")
    if not zones then return nil end
    local zone = zones:FindFirstChild(tostring(zoneNum))
    if not zone then return nil end
    local poi = zone:FindFirstChild("POI")
    if poi and poi:FindFirstChildWhichIsA("BasePart", true) then return poi:FindFirstChildWhichIsA("BasePart", true).CFrame + Vector3.new(0, 6, 0) end
    return nil
end

task.spawn(function()
    while true do
        if K["Auto Teleport Max Zone"] then
            local num = getHighestUnlockedZone()
            if num then
                local cf = getZoneCFrame(num)
                if cf and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    pcall(function()
                        local hrp = LocalPlayer.Character.HumanoidRootPart
                        local dist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(cf.Position.X, 0, cf.Position.Z)).Magnitude
                        if dist > 100 then hrp.CFrame = cf end
                    end)
                end
            end
        end
        task.wait(3)
    end
end)

-- Equip Best & Index
task.spawn(function()
    while true do
        if K["Auto Equip Best"] then pcall(function() Remotes.Inventory:InvokeServer("requestEquipBest") end) end
        if K["Auto Claim Index"] then 
            for _, rt in ipairs({"basic", "shiny", "big", "huge", "inverted"}) do 
                pcall(function() Remotes.Index:InvokeServer("requestClaimReward", rt) end) 
            end 
        end
        task.wait(3)
    end
end)

-- Auto Use Boosts
task.spawn(function()
    while true do
        if K["Auto Use Boosts"] then
            for _, b in ipairs({"rollSpeed", "luck", "ultraLuck", "coins"}) do
                pcall(function() Remotes.Boost:InvokeServer("requestUseBoost", b) end)
            end
        end
        task.wait(5)
    end
end)

-- Collect Drops
task.spawn(function()
    while true do
        if K["Auto Collect Drops"] then
            for _, n in ipairs({"Drops","Loot","Coins","Collectibles"}) do
                local f = workspace:FindFirstChild(n)
                if f then 
                    for _, d in ipairs(f:GetChildren()) do 
                        pcall(function() Remotes.Loot:InvokeServer("requestCollect", d.Name) end) 
                    end 
                end
            end
        end
        task.wait(0.5)
    end
end)

-- Auto Claim Recipes
task.spawn(function()
    while true do
        if K["Auto Claim Recipes"] then
            local zf = workspace:FindFirstChild("Zones") or workspace:FindFirstChild("Areas") or (workspace:FindFirstChild("Gameplay101") and workspace.Gameplay101:FindFirstChild("Zones"))
            if zf then
                for _, z in ipairs(zf:GetChildren()) do
                    if z:FindFirstChild("Recipe") then 
                        pcall(function() Remotes.Crafting:InvokeServer("requestClaimRecipe", "crafty", z.Recipe) end) 
                    end
                end
            end
        end
        task.wait(3)
    end
end)

-- Smart Auto Craft
task.spawn(function()
    while true do
        if K["Smart Auto Craft"] then
            local inventory = Modules.DataServiceClient:get("inventory") or {}
            local craftingRecipes = Modules.DataServiceClient:get("craftingRecipes") or {}
            local unlocks = Modules.DataServiceClient:get("unlocks") or {}

            if Modules.CraftingUtils.isMachineUnlocked(unlocks) then
                for _, recipe in ipairs(Modules.CraftingUtils.getRecipes()) do
                    if Modules.CraftingUtils.isRecipeOwned(craftingRecipes, recipe.id) then
                        local selectedSlimes, usedAmounts = {}, {}
                        local valid = true
                        for _, ingredient in ipairs(recipe.inputs) do
                            local entries = Modules.CraftingUtils.getIngredientInventoryEntries(ingredient, inventory)
                            local selectedUniqueId = nil
                            for _, entry in ipairs(entries or {}) do
                                if entry.uniqueId and (tonumber(entry.ownedAmount) or 0) - (usedAmounts[entry.uniqueId] or 0) > 0 then
                                    selectedUniqueId = entry.uniqueId
                                    break
                                end
                            end
                            if not selectedUniqueId then valid = false break end
                            usedAmounts[selectedUniqueId] = (usedAmounts[selectedUniqueId] or 0) + 1
                            table.insert(selectedSlimes, selectedUniqueId)
                        end
                        if valid then
                            pcall(function() Remotes.Crafting:InvokeServer("requestCraftRecipe", recipe.id, selectedSlimes, 1) end)
                            task.wait(0.15)
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
end)

print("🦆 Ducky Kaitun Loaded Successfully!")
