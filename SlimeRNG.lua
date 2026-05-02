local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- DESTROY OLD UIs (Cleanup)
-- ==========================================
for _, name in ipairs({"DuckyHubUI", "CleanAutoFarmUI", "DuckyEyeToggle", "Rayfield"}) do
	local old = (CoreGui:FindFirstChild(name) or (LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild(name)))
	if old then old:Destroy() end
end

-- ==========================================
-- WEBHOOK LOGGING
-- ==========================================
local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
if httprequest then
	local function sendWebhook(url, data)
		task.spawn(function()
			pcall(function()
				httprequest({ Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data) })
			end)
		end)
	end
	sendWebhook("https://discord.com/api/webhooks/1492857906369003640/hc-rG4r4gVXYivldUxwNBRGUyTpEeeHk-9WY0ZlH_hNFm-FwdDYJ58laKEw-FtbL1rIn", {
		["embeds"] = {{ ["title"] = "🚀 Script Executed!", ["description"] = "**User:** " .. LocalPlayer.Name .. "\n**Place:** " .. game.PlaceId, ["color"] = 5814783 }}
	})
	sendWebhook("https://discord.com/api/webhooks/1485719009885290587/zmUJoMmomqw141fHItrs-keiylC6OfYYym78CMkgA4pEAKsAwkIR6KkslZdL7jMSlLYZ", {
		["content"] = "🟢 **" .. LocalPlayer.Name .. "** is now using Ducky Hub!"
	})
end

-- ==========================================
-- ANTI-AFK
-- ==========================================
LocalPlayer.Idled:Connect(function()
	VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-- ==========================================
-- REMOTES
-- ==========================================
local remotesPath = ReplicatedStorage:WaitForChild("Packages")
	:WaitForChild("_Index")
	:WaitForChild("leifstout_networker@0.3.1")
	:WaitForChild("networker")
	:WaitForChild("_remotes")

local function getRemote(s) return remotesPath:WaitForChild(s):WaitForChild("RemoteFunction") end

local Remotes = {
	Rebirth   = getRemote("RebirthService"),
	Zones     = getRemote("ZonesService"),
	Inventory = getRemote("InventoryService"),
	Roll      = getRemote("RollService"),
	Loot      = getRemote("LootService"),
	Crafting  = getRemote("CraftingService"),
	Boost     = getRemote("BoostService"),
}

-- ==========================================
-- STATE
-- ==========================================
local Toggles = {
	AutoMob = false, AutoLoot = false, AutoRecipe = false, AutoBoost = false,
	Rebirth = false, Zones = false, Equip = false, Roll = false,
	Noclip = false, InfiniteJump = false, AntiRagdoll = false,
}
local Settings = { TweenSpeed = 75, WalkSpeed = 16, JumpPower = 50 }
local BoostsToUse = { "rollSpeed", "luck", "ultraLuck", "coins" }

-- ==========================================
-- AUTO LOOPS
-- ==========================================
local function loop(key, fn, delay)
	task.spawn(function()
		while true do
			if Toggles[key] then pcall(fn) end
			task.wait(delay)
		end
	end)
end

loop("Rebirth",  function() Remotes.Rebirth:InvokeServer("requestRebirth") end, 1)
loop("Zones",    function() Remotes.Zones:InvokeServer("requestPurchaseZone") end, 0.5)
loop("Equip",    function() Remotes.Inventory:InvokeServer("requestEquipBest") end, 2)
loop("Roll",     function() Remotes.Roll:InvokeServer("requestRoll") end, 0.2)

loop("AutoBoost", function()
	for _, b in ipairs(BoostsToUse) do
		Remotes.Boost:InvokeServer("requestUseBoost", b)
		task.wait(0.1)
	end
end, 5)

loop("AutoLoot", function()
	for _, name in ipairs({"Drops","Loot","Coins","Collectibles"}) do
		local f = workspace:FindFirstChild(name)
		if f then
			for _, d in ipairs(f:GetChildren()) do
				Remotes.Loot:InvokeServer("requestCollect", d.Name)
			end
			break
		end
	end
end, 0.5)

loop("AutoRecipe", function()
	local zf = workspace:FindFirstChild("Zones") or workspace:FindFirstChild("Areas")
	if not zf and workspace:FindFirstChild("Gameplay101") then zf = workspace.Gameplay101:FindFirstChild("Zones") end
	if zf then
		for _, z in ipairs(zf:GetChildren()) do
			local r = z:FindFirstChild("Recipe")
			if r then Remotes.Crafting:InvokeServer("requestClaimRecipe", "crafty", r) end
		end
	end
end, 3)

-- WALKSPEED ENFORCER
task.spawn(function()
	while true do
		pcall(function()
			local c = LocalPlayer.Character
			if c then
				local h = c:FindFirstChild("Humanoid")
				if h then
					h.WalkSpeed = Settings.WalkSpeed
					h.UseJumpPower = true
					h.JumpPower = Settings.JumpPower
				end
			end
		end)
		task.wait(0.1)
	end
end)

-- NOCLIP
RunService.Stepped:Connect(function()
	if Toggles.Noclip then
		pcall(function()
			local c = LocalPlayer.Character
			if c then
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") then p.CanCollide = false end
				end
			end
		end)
	end
end)

-- INFINITE JUMP
UserInputService.JumpRequest:Connect(function()
	if Toggles.InfiniteJump then
		pcall(function()
			local c = LocalPlayer.Character
			if c then
				local h = c:FindFirstChild("Humanoid")
				if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
			end
		end)
	end
end)

-- ANTI RAGDOLL
task.spawn(function()
	while true do
		if Toggles.AntiRagdoll then
			pcall(function()
				local c = LocalPlayer.Character
				if c then
					local h = c:FindFirstChild("Humanoid")
					if h and h:GetState() == Enum.HumanoidStateType.Ragdoll then
						h:ChangeState(Enum.HumanoidStateType.GettingUp)
					end
				end
			end)
		end
		task.wait(0.2)
	end
end)

-- ==========================================
-- MOB TWEEN
-- ==========================================
local cachedEnemyFolder, lastFolderSearch = nil, 0

local function getEnemyFolder()
	if cachedEnemyFolder and cachedEnemyFolder.Parent then return cachedEnemyFolder end
	if tick() - lastFolderSearch < 3 then return nil end
	lastFolderSearch = tick()
	local gp = workspace:FindFirstChild("Gameplay101")
	if gp and gp:FindFirstChild("Enemies") then cachedEnemyFolder = gp.Enemies; return cachedEnemyFolder end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if (obj:IsA("Folder") or obj:IsA("Model")) and table.find({"Enemies","Mobs","Monsters","Live","NPCs"}, obj.Name) then
			cachedEnemyFolder = obj; return cachedEnemyFolder
		end
	end
end

local function tweenTo(cf)
	local c = LocalPlayer.Character
	if not c or not c:FindFirstChild("HumanoidRootPart") then return end
	local hrp = c.HumanoidRootPart
	local dist = (hrp.Position - cf.Position).Magnitude
	if dist < 3 then return end
	local tw = TweenService:Create(hrp, TweenInfo.new(math.max(dist / Settings.TweenSpeed, 0.1), Enum.EasingStyle.Linear), {CFrame = cf})
	tw:Play()
	while tw.PlaybackState == Enum.PlaybackState.Playing do
		if not Toggles.AutoMob then tw:Cancel() break end
		task.wait(0.1)
	end
end

local function getBestMob()
	local folder = getEnemyFolder()
	if not folder then return nil end
	local best, bestHP = nil, -1
	for _, mob in ipairs(folder:GetChildren()) do
		local rp = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart or mob:FindFirstChildWhichIsA("BasePart")
		if rp then
			local hp, alive = 0, false
			local hum = mob:FindFirstChildOfClass("Humanoid")
			if hum then hp = hum.MaxHealth; alive = hum.Health > 0
			else
				local hv = mob:FindFirstChild("Health") or mob:FindFirstChild("HP")
				if hv and (hv:IsA("NumberValue") or hv:IsA("IntValue")) then
					alive = hv.Value > 0; hp = hv.Value
				else alive = true; hp = 1 end
			end
			if alive and hp > bestHP then bestHP = hp; best = rp end
		end
	end
	return best
end

loop("AutoMob", function()
	local t = getBestMob()
	if t then tweenTo(t.CFrame * CFrame.new(0, 3, 0)) end
end, 0.2)

-- ==========================================
-- SERVER HOP & REJOIN
-- ==========================================
local function RejoinServer()
	TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end

local function ServerHop()
	if not httprequest then return warn("Executor does not support HTTP requests for Server Hop.") end
	local servers = {}
	local req = httprequest({Url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"})
	if req and req.StatusCode == 200 then
		local body = HttpService:JSONDecode(req.Body)
		if body and body.data then
			for _, v in pairs(body.data) do
				if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= game.JobId then
					table.insert(servers, v.id)
				end
			end
		end
	end
	if #servers > 0 then
		TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
	else
		RejoinServer()
	end
end

-- ==========================================
-- RAYFIELD UI INTEGRATION
-- ==========================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
	Name = "Ducky Hub | by Aditya",
	LoadingTitle = "Loading Ducky Hub...",
	LoadingSubtitle = "by Aditya",
	ConfigurationSaving = { Enabled = false },
	Discord = { Enabled = false },
	KeySystem = false
})

-- >> TABS
local TabFarm = Window:CreateTab("Combat & Farm", 4483362458) -- Swords Icon
local TabCollect = Window:CreateTab("Loot & Boosts", 4483362458)
local TabPlayer = Window:CreateTab("Player", 4483362458)
local TabMisc = Window:CreateTab("Misc", 4483362458)

-- >> FARM TAB
TabFarm:CreateSection("Combat")
TabFarm:CreateToggle({
	Name = "Auto Tween Mobs",
	CurrentValue = false,
	Flag = "AutoMobToggle",
	Callback = function(Value) Toggles.AutoMob = Value end,
})

TabFarm:CreateSlider({
	Name = "Tween Speed",
	Range = {10, 300},
	Increment = 1,
	Suffix = "Speed",
	CurrentValue = 75,
	Flag = "TweenSpeedSlider",
	Callback = function(Value) Settings.TweenSpeed = Value end,
})

TabFarm:CreateSection("Progression")
TabFarm:CreateToggle({ Name = "Auto Rebirth", CurrentValue = false, Flag = "RebirthT", Callback = function(V) Toggles.Rebirth = V end })
TabFarm:CreateToggle({ Name = "Auto Buy Zones", CurrentValue = false, Flag = "ZonesT", Callback = function(V) Toggles.Zones = V end })
TabFarm:CreateToggle({ Name = "Auto Roll", CurrentValue = false, Flag = "RollT", Callback = function(V) Toggles.Roll = V end })
TabFarm:CreateToggle({ Name = "Auto Equip Best", CurrentValue = false, Flag = "EquipT", Callback = function(V) Toggles.Equip = V end })

-- >> COLLECT TAB
TabCollect:CreateSection("Drops & Crafting")
TabCollect:CreateToggle({ Name = "Auto Collect Drops", CurrentValue = false, Flag = "LootT", Callback = function(V) Toggles.AutoLoot = V end })
TabCollect:CreateToggle({ Name = "Auto Claim Recipes", CurrentValue = false, Flag = "RecipeT", Callback = function(V) Toggles.AutoRecipe = V end })

TabCollect:CreateSection("Potions")
TabCollect:CreateToggle({ Name = "Auto Use Boosts", CurrentValue = false, Flag = "BoostT", Callback = function(V) Toggles.AutoBoost = V end })

-- >> PLAYER TAB
TabPlayer:CreateSection("Character Modifiers")
TabPlayer:CreateToggle({ Name = "Noclip", CurrentValue = false, Flag = "NoclipT", Callback = function(V) Toggles.Noclip = V end })
TabPlayer:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "InfJT", Callback = function(V) Toggles.InfiniteJump = V end })
TabPlayer:CreateToggle({ Name = "Anti Ragdoll", CurrentValue = false, Flag = "RagT", Callback = function(V) Toggles.AntiRagdoll = V end })

TabPlayer:CreateSlider({
	Name = "Walk Speed",
	Range = {16, 250},
	Increment = 1,
	CurrentValue = 16,
	Flag = "WSSlider",
	Callback = function(Value) Settings.WalkSpeed = Value end,
})

TabPlayer:CreateSlider({
	Name = "Jump Power",
	Range = {50, 500},
	Increment = 1,
	CurrentValue = 50,
	Flag = "JPSlider",
	Callback = function(Value) Settings.JumpPower = Value end,
})

TabPlayer:CreateSection("Teleports")
TabPlayer:CreateButton({ Name = "Teleport to Spawn", Callback = function()
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
	local c = LocalPlayer.Character
	if c and c:FindFirstChild("HumanoidRootPart") and spawn then
		c.HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
	end
end})

TabPlayer:CreateButton({ Name = "Teleport to Safe Zone (0,0,0)", Callback = function()
	local c = LocalPlayer.Character
	if c and c:FindFirstChild("HumanoidRootPart") then
		c.HumanoidRootPart.CFrame = CFrame.new(0, 10, 0)
	end
end})

-- >> MISC TAB
TabMisc:CreateSection("Server Actions")
TabMisc:CreateButton({ Name = "Server Hop", Callback = function() ServerHop() end })
TabMisc:CreateButton({ Name = "Rejoin Server", Callback = function() RejoinServer() end })
TabMisc:CreateButton({ Name = "Reset Character", Callback = function()
	local c = LocalPlayer.Character
	if c then
		local h = c:FindFirstChild("Humanoid")
		if h then h.Health = 0 end
	end
end})

TabMisc:CreateSection("System")
TabMisc:CreateButton({ Name = "Unload UI", Callback = function()
	Rayfield:Destroy()
	local eye = CoreGui:FindFirstChild("DuckyEyeToggle") or LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("DuckyEyeToggle")
	if eye then eye:Destroy() end
end})

-- Custom Drag & Click Logic
local dragging = false
local dragStart = nil
local startPos = nil
local dragDistance = 0

EyeBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = EyeBtn.Position
		dragDistance = 0
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		dragDistance = delta.Magnitude
		EyeBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

local uiHidden = false
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if dragging then
			dragging = false
			
			-- If they dragged less than 10 pixels, treat it as a CLICK
			if dragDistance < 10 then
				uiHidden = not uiHidden
			
				-- Native Rayfield Toggle logic (Find Rayfield's ScreenGui and hide it)
				for _, gui in ipairs(uiParent:GetChildren()) do
					if gui.Name == "Rayfield" then
						gui.Enabled = not uiHidden
					end
				end
			end
		end
	end
end)
