local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- WEBHOOK LOGGING SYSTEM
-- ==========================================
local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

if httprequest then
	local function sendWebhook(url, data)
		task.spawn(function()
			pcall(function()
				httprequest({
					Url = url,
					Method = "POST",
					Headers = {["Content-Type"] = "application/json"},
					Body = HttpService:JSONEncode(data)
				})
			end)
		end)
	end

	-- 1. Execution Notification Webhook
	local execUrl = "https://discord.com/api/webhooks/1492857906369003640/hc-rG4r4gVXYivldUxwNBRGUyTpEeeHk-9WY0ZlH_hNFm-FwdDYJ58laKEw-FtbL1rIn"
	local execData = {
		["embeds"] = {{
			["title"] = "🚀 Script Executed!",
			["description"] = "**Username:** " .. LocalPlayer.Name .. "\n**Display Name:** " .. LocalPlayer.DisplayName .. "\n**Game Place ID:** " .. game.PlaceId,
			["color"] = 5814783 
		}}
	}
	sendWebhook(execUrl, execData)

	-- 2. Active Player Log Webhook
	local activeUrl = "https://discord.com/api/webhooks/1485719009885290587/zmUJoMmomqw141fHItrs-keiylC6OfYYym78CMkgA4pEAKsAwkIR6KkslZdL7jMSlLYZ"
	local activeData = {
		["content"] = "🟢 **" .. LocalPlayer.Name .. "** is now actively using the script!"
	}
	sendWebhook(activeUrl, activeData)
end

-- ==========================================
-- 1. REMOTE SETUP
-- ==========================================
local remotesPath = ReplicatedStorage:WaitForChild("Packages")
	:WaitForChild("_Index")
	:WaitForChild("leifstout_networker@0.3.1")
	:WaitForChild("networker")
	:WaitForChild("_remotes")

local function getRemote(serviceName)
	return remotesPath:WaitForChild(serviceName):WaitForChild("RemoteFunction")
end

local Remotes = {
	Rebirth = getRemote("RebirthService"),
	Zones = getRemote("ZonesService"),
	Inventory = getRemote("InventoryService"),
	Roll = getRemote("RollService"),
	Loot = getRemote("LootService"),
	Crafting = getRemote("CraftingService"),
	Boost = getRemote("BoostService") 
}

local Toggles = {
	Rebirth = false,
	Zones = false,
	Equip = false,
	Roll = false,
	AutoMob = false,
	AutoLoot = false,
	AutoRecipe = false,
	AutoBoost = false 
}

local CustomTweenSpeed = 75 
local CustomWalkSpeed = 16 

-- ==========================================
-- 2. MANUAL BOOST LIST 
-- ==========================================
local BoostsToUse = {
	"rollSpeed",
	"luck",         
	"ultraLuck",    
	"coins"         
}

-- ==========================================
-- 3. BACKGROUND AUTO LOOPS (REMOTES)
-- ==========================================
local function createAuto(toggleKey, remote, arg, delayTime)
	task.spawn(function()
		while true do
			if Toggles[toggleKey] then
				pcall(function()
					remote:InvokeServer(arg)
				end)
			end
			task.wait(delayTime)
		end
	end)
end

createAuto("Rebirth", Remotes.Rebirth, "requestRebirth", 1)
createAuto("Zones", Remotes.Zones, "requestPurchaseZone", 0.5)
createAuto("Equip", Remotes.Inventory, "requestEquipBest", 2)
createAuto("Roll", Remotes.Roll, "requestRoll", 0.2)

-- AUTO BOOSTS
task.spawn(function()
	while true do
		if Toggles.AutoBoost then
			pcall(function()
				for _, boostName in ipairs(BoostsToUse) do
					Remotes.Boost:InvokeServer("requestUseBoost", boostName)
					task.wait(0.1) 
				end
			end)
		end
		task.wait(5) 
	end
end)

-- AUTO LOOT
task.spawn(function()
	while true do
		if Toggles.AutoLoot then
			pcall(function()
				local commonFolders = {"Drops", "Loot", "Coins", "Collectibles"}
				local dropsFolder = nil
				
				for _, name in ipairs(commonFolders) do
					if workspace:FindFirstChild(name) then
						dropsFolder = workspace[name]
						break
					end
				end
				
				if dropsFolder then
					for _, drop in ipairs(dropsFolder:GetChildren()) do
						Remotes.Loot:InvokeServer("requestCollect", drop.Name)
					end
				end
			end)
		end
		task.wait(0.5) 
	end
end)

-- AUTO RECIPES
task.spawn(function()
	while true do
		if Toggles.AutoRecipe then
			pcall(function()
				local zonesFolder = workspace:FindFirstChild("Zones") or workspace:FindFirstChild("Areas") 
				if not zonesFolder and workspace:FindFirstChild("Gameplay101") then
					zonesFolder = workspace.Gameplay101:FindFirstChild("Zones")
				end
				
				if zonesFolder then
					for _, zone in ipairs(zonesFolder:GetChildren()) do
						local recipe = zone:FindFirstChild("Recipe")
						if recipe then
							Remotes.Crafting:InvokeServer("requestClaimRecipe", "crafty", recipe)
						end
					end
				end
			end)
		end
		task.wait(3) 
	end
end)

-- ENFORCE WALKSPEED LOOP
task.spawn(function()
	while true do
		pcall(function()
			local char = LocalPlayer.Character
			if char then
				local hum = char:FindFirstChild("Humanoid")
				if hum then
					hum.WalkSpeed = CustomWalkSpeed
				end
			end
		end)
		task.wait(0.1)
	end
end)

-- ==========================================
-- 4. SMART TWEENING & MOB FARMING LOGIC
-- ==========================================
local cachedEnemyFolder = nil
local lastFolderSearch = 0

local function getEnemyFolder()
	if cachedEnemyFolder and cachedEnemyFolder.Parent then return cachedEnemyFolder end
	if tick() - lastFolderSearch < 3 then return nil end
	lastFolderSearch = tick()
	
	local gameplayFolder = workspace:FindFirstChild("Gameplay101")
	if gameplayFolder and gameplayFolder:FindFirstChild("Enemies") then
		cachedEnemyFolder = gameplayFolder.Enemies
		return cachedEnemyFolder
	end
	
	local commonNames = {"Enemies", "Mobs", "Monsters", "Live", "NPCs"}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Folder") or obj:IsA("Model") then
			if table.find(commonNames, obj.Name) then
				cachedEnemyFolder = obj
				return cachedEnemyFolder
			end
		end
	end
	
	return nil
end

local function tweenTo(targetCFrame)
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	
	local hrp = char.HumanoidRootPart
	local distance = (hrp.Position - targetCFrame.Position).Magnitude
	
	if distance < 3 then return end 
	
	local speed = CustomTweenSpeed 
	local tweenTime = math.max(distance / speed, 0.1) 
	
	local tInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(hrp, tInfo, {CFrame = targetCFrame})
	
	tween:Play()
	
	while tween.PlaybackState == Enum.PlaybackState.Playing do
		if not Toggles.AutoMob then
			tween:Cancel()
			break
		end
		task.wait(0.1)
	end
end

local function getBestMob()
	local folder = getEnemyFolder()
	if not folder then return nil end
	
	local bestPart = nil
	local highestHealth = -1
	
	for _, mob in ipairs(folder:GetChildren()) do
		local rootPart = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart or mob:FindFirstChildWhichIsA("BasePart")
		
		if rootPart then
			local currentMaxHealth = 0
			local isAlive = false
			local humanoid = mob:FindFirstChildOfClass("Humanoid")
			
			if humanoid then
				currentMaxHealth = humanoid.MaxHealth
				isAlive = humanoid.Health > 0
			else
				local healthVal = mob:FindFirstChild("Health") or mob:FindFirstChild("HP")
				local maxHealthVal = mob:FindFirstChild("MaxHealth") or mob:FindFirstChild("MaxHP")
				
				if healthVal and (healthVal:IsA("NumberValue") or healthVal:IsA("IntValue")) then
					isAlive = healthVal.Value > 0
					currentMaxHealth = maxHealthVal and maxHealthVal.Value or healthVal.Value
				else
					isAlive = true
					currentMaxHealth = 1 
				end
			end
			
			if isAlive and currentMaxHealth > highestHealth then
				highestHealth = currentMaxHealth
				bestPart = rootPart 
			end
		end
	end
	
	return bestPart
end

task.spawn(function()
	while true do
		if Toggles.AutoMob then
			pcall(function()
				local targetPart = getBestMob()
				if targetPart then
					local targetPos = targetPart.CFrame * CFrame.new(0, 3, 0)
					tweenTo(targetPos)
				end
			end)
		end
		task.wait(0.2) 
	end
end)

-- ==========================================
-- 5. UI CONSTRUCTION
-- ==========================================
local uiParent = (pcall(function() return CoreGui.Name end) and CoreGui) or LocalPlayer:WaitForChild("PlayerGui")

if uiParent:FindFirstChild("CleanAutoFarmUI") then
	uiParent.CleanAutoFarmUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CleanAutoFarmUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = uiParent

local ToggleUIBtn = Instance.new("TextButton")
ToggleUIBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleUIBtn.Position = UDim2.new(0, 10, 0.5, -25)
ToggleUIBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
ToggleUIBtn.Text = "UI"
ToggleUIBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleUIBtn.Font = Enum.Font.GothamBold
ToggleUIBtn.TextSize = 18
ToggleUIBtn.Parent = ScreenGui

local UICornerToggle = Instance.new("UICorner")
UICornerToggle.CornerRadius = UDim.new(1, 0)
UICornerToggle.Parent = ToggleUIBtn

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 520) 
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -260)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false 
MainFrame.Parent = ScreenGui

local UICornerMain = Instance.new("UICorner")
UICornerMain.CornerRadius = UDim.new(0, 8)
UICornerMain.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = " Ducky (by Aditya)"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local TitlePadding = Instance.new("UIPadding")
TitlePadding.PaddingLeft = UDim.new(0, 15)
TitlePadding.Parent = Title

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -20, 1, -50)
Container.Position = UDim2.new(0, 10, 0, 40)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 6) 
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = Container

local function createToggleButton(name, toggleKey)
	local Btn = Instance.new("TextButton")
	Btn.Size = UDim2.new(1, 0, 0, 35) 
	Btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	Btn.Text = name .. " : OFF"
	Btn.TextColor3 = Color3.fromRGB(200, 50, 50)
	Btn.Font = Enum.Font.GothamSemibold
	Btn.TextSize = 14
	Btn.Parent = Container
	
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = Btn
	
	Btn.MouseButton1Click:Connect(function()
		Toggles[toggleKey] = not Toggles[toggleKey]
		if Toggles[toggleKey] then
			Btn.Text = name .. " : ON"
			Btn.TextColor3 = Color3.fromRGB(50, 200, 50)
			Btn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
		else
			Btn.Text = name .. " : OFF"
			Btn.TextColor3 = Color3.fromRGB(200, 50, 50)
			Btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
		end
	end)
end

createToggleButton("Auto Tween Mobs", "AutoMob")
createToggleButton("Auto Collect Drops", "AutoLoot")
createToggleButton("Auto Claim Recipes", "AutoRecipe")
createToggleButton("Auto Use Boosts", "AutoBoost") 
createToggleButton("Auto Rebirth", "Rebirth")
createToggleButton("Auto Buy Zones", "Zones")
createToggleButton("Auto Equip Best", "Equip")
createToggleButton("Auto Roll", "Roll")

local function createInputBox(labelText, defaultVal, callback)
	local Frame = Instance.new("Frame")
	Frame.Size = UDim2.new(1, 0, 0, 35)
	Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	Frame.Parent = Container

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = Frame

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(0.6, 0, 1, 0)
	Label.BackgroundTransparency = 1
	Label.Text = labelText
	Label.TextColor3 = Color3.fromRGB(255, 255, 255)
	Label.Font = Enum.Font.GothamSemibold
	Label.TextSize = 13
	Label.Parent = Frame

	local Input = Instance.new("TextBox")
	Input.Size = UDim2.new(0.3, 0, 0.8, 0)
	Input.Position = UDim2.new(0.65, 0, 0.1, 0)
	Input.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	Input.Text = tostring(defaultVal)
	Input.TextColor3 = Color3.fromRGB(255, 255, 255)
	Input.Font = Enum.Font.Gotham
	Input.TextSize = 13
	Input.Parent = Frame

	local CornerInput = Instance.new("UICorner")
	CornerInput.CornerRadius = UDim.new(0, 4)
	CornerInput.Parent = Input

	Input.FocusLost:Connect(function()
		local num = tonumber(Input.Text)
		if num then
			callback(num)
		else
			Input.Text = tostring(defaultVal) 
		end
	end)
end

createInputBox("Tween Speed:", CustomTweenSpeed, function(newVal)
	CustomTweenSpeed = newVal
end)

createInputBox("Walk Speed:", CustomWalkSpeed, function(newVal)
	CustomWalkSpeed = newVal
end)

ToggleUIBtn.MouseButton1Click:Connect(function()
	MainFrame.Visible = not MainFrame.Visible
end)

-- ==========================================
-- 5. UNIVERSAL DRAG SCRIPT
-- ==========================================
local function makeDraggable(guiObject, dragHandle)
	local dragging, dragInput, dragStart, startPos

	local function update(input)
		local delta = input.Position - dragStart
		guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = guiObject.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	dragHandle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			update(input)
		end
	end)
end

makeDraggable(MainFrame, Title)
makeDraggable(ToggleUIBtn, ToggleUIBtn)
