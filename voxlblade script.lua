--// Created by depso

--// Libraries
local ImGui = loadstring(game:HttpGet('https://github.com/depthso/Roblox-ImGUI/raw/main/ImGui.lua'))()
local SimplePath = loadstring(game:HttpGet('https://raw.githubusercontent.com/grayzcale/simplepath/refs/heads/main/src/SimplePath.lua'))()

--// Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

--// Player
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local CurrentTween = nil
local InventoryItems = {}
local Path = nil

--// Game folders
local Npcs = workspace.NPCS
local Infusers = workspace.Infusers
local Shrines = workspace.Shrines
local Dummies = workspace.Dummies
local Map = workspace.Map

--// Core folders
local Core = LocalPlayer.PlayerScripts:WaitForChild("Core")
local Events = ReplicatedStorage:WaitForChild("Events")
local Data = ReplicatedStorage:WaitForChild("Data")

--// Events
local SendInfo = Events.SendInfo
local SwingSword = Events.SwingSword
local EquipWeapon = Events.EquipWeapon
local DestroyItem = Events.DestroyItem
local WeaponArt = Events.WeaponArt
local Rune = Events.Rune

local ItemData = require(Data.ItemData)

--// Frontier Village
local FrontierVillage = Map.FrontierVillage
local Farmlands = {}

--// Enemies
local Ememies = {
    Buni = false,
    Mageling = false,
    PlainsWoof = false
}

--// Item types to sell
local ToSell = {
    Shirt = true,
    Pants = true,
    Helmet = true,
    Ring = false,
}

--// UI Elements
local Window = ImGui:CreateWindow({
	Title = "Voxlblade GUI | By: Depso 🐈",
	Size = UDim2.fromOffset(350, 300)
})
Window:Center()

----// Auto farm tab
local AutoFarmTab = Window:CreateTab({
	Name = "Auto-farm",
	Visible = true 
})
local AutoFarm = AutoFarmTab:Checkbox({
	Label = "Auto-farm enabled",
	Value = false,
    Callback = function(self, Value)
		if not Value and CurrentTween then
            CurrentTween:Cancel()
        end
	end,
})
local FarmlandOnly = AutoFarmTab:Checkbox({
	Label = "Farmland only",
	Value = true,
})
local RightClick = AutoFarmTab:Checkbox({
	Label = "Right-click swing",
	Value = false,
})
local AutoRune = AutoFarmTab:Checkbox({
	Label = "Auto use rune",
	Value = true,
})
local AutoWeaponart = AutoFarmTab:Checkbox({
	Label = "Auto weapon art",
	Value = true,
})
local Offset = AutoFarmTab:Slider({
	Label = "Offset",
	Value = 5,
	MinValue = 1,
	MaxValue = 10
})
local MovementMethod = AutoFarmTab:Combo({
	Label = "Movement method",
    Selected = "Tween",
	Items = {
		"Tween",
		"Path find",
	}
})
local EmemiesHeader = AutoFarmTab:CollapsingHeader({
	Title = "Ememies",
	Open = true
})

----// Auto sell tab
local AutoSellTab = Window:CreateTab({
	Name = "Auto-sell" 
})
local AutoSell = AutoSellTab:Checkbox({
	Label = "Auto-sell enabled",
	Value = false,
})
local IgnoreEnchanted = AutoSellTab:Checkbox({
	Label = "Ignore Enchanted",
	Value = true,
})
local IgnoreItems = AutoSellTab:Checkbox({
	Label = "Ignore Items",
	Value = true,
})
local AutoSellThreshold = AutoSellTab:Slider({
    Label = "Threshold",
    Value = 10,
    MinValue = 1,
    MaxValue = 100
})
local SellTypesHeader = AutoSellTab:CollapsingHeader({
	Title = "Item types to sell",
	Open = true
})

local SellDebugText = AutoSellTab:Label()

----// Settings tab
local SettingsTab = Window:CreateTab({
	Name = "Settings"
})
local TweenStep = SettingsTab:Slider({
	Label = "Tween step (1s for every ? studs)",
	Value = 30,
	MinValue = 20,
	MaxValue = 120
})
local Enabled = SettingsTab:Checkbox({
	Label = "Enabled",
	Value = true,
})
SettingsTab:Checkbox({
	Label = "No rendering",
	Value = false,
    Callback = function(self, Value)
        RunService:Set3dRenderingEnabled(not Value)
    end
})

local function BindCheckboxes(Table, Parent)
    for Name: string, Value: boolean in next, Table do
        Parent:Checkbox({
            Label = Name,
            Value = Value,
            Callback = function(self, Value)
                Ememies[Name] = Value
            end
        })
    end
end

local function AddCheckboxes()
    BindCheckboxes(Ememies, EmemiesHeader)
    BindCheckboxes(ToSell, SellTypesHeader)
end

local function CollectFarmLand()
    for _, Farm in next, FrontierVillage:GetChildren() do
        if not Farm:IsA("Model") then continue end
        if not Farm.Name:find("Farmland") then continue end
        table.insert(Farmlands, Farm)
    end
end

local function PivotTo(CFrame: CFrame)
    local Character = LocalPlayer.Character
    if not Character then return end
    Character:PivotTo(CFrame)
end

local function TweenToCFrame(TargetCFrame: CFrame)
    --// Character data
    local Character = LocalPlayer.Character
    local Origin = Character:GetPivot()

    local Step = TweenStep.Value
    local Distance = (Origin.Position - TargetCFrame.Position).Magnitude
    local TweenTime = (Distance / Step) * 1

    --// Create position holder for pivoting
    local Holder = Instance.new("CFrameValue")
    Holder.Value = Origin
    Holder:GetPropertyChangedSignal("Value"):Connect(function()
        if not Character then return end

        local CFrame = Holder.Value
        PivotTo(CFrame)
    end)

    --// Create tween
    local Info = TweenInfo.new(TweenTime)
    CurrentTween = TweenService:Create(Holder, Info, {
        Value = TargetCFrame
    })
    CurrentTween:Play()

    --// Wait for tween to complete
    CurrentTween.Completed:Wait()

    --// Tween completed cleanup
    Holder:Destroy()
end

local function PathfindPoint(TargetCFrame: CFrame)
    local Character = LocalPlayer.Character
    local Settings = {
        TIME_VARIANCE = 0.5,
        JUMP_WHEN_STUCK = true,
        COMPARISON_CHECKS = 1
    }

    --// Create part for pathfinding
    local Part = Instance.new("Part", workspace)
    Part.Anchored = true
    Part.CanCollide = false
    Part:PivotTo(TargetCFrame)

    --// Create path interface
    local Path = SimplePath.new(Character, nil, Settings)
    Path.Visualize = true
    Path.WaypointReached:Connect(function()
        Path:Run(Part)
    end)

    local function Error(ErrorType)
        warn(`Path finding error! Defaulting to tweening. #{ErrorType}`)

        Part:Destroy()
        TweenToCFrame(TargetCFrame)

        Path._events.Reached:Fire()
        Path:Destroy()
    end
    
    --// Error handling
    Path.Blocked:Connect(Error)
    Path.Error:Connect(Error)
    
    --// Run path
    Path:Run(Part)

    Path.Reached:Wait()
    Part:Destroy()
end

local function MoveToPoint(TargetCFrame: CFrame)
    local Method = MovementMethod.Value

    print("Method:", Method)

    if Method == "Tween" then
        TweenToCFrame(TargetCFrame)
    else
        PathfindPoint(TargetCFrame)
    end
end

function IsPointInArea(Point: (CFrame|Vector3), Area: (Part|Model)): boolean
	local Size, Center
	
	--// Get the center and size of the area
	if Area:IsA("Model") then
		Center, Size = Area:GetBoundingBox()
	else
		Center = Area.Position
		Size = Area.Size
	end
	
	--// Get the half size of the area
	local HalfSize = Size / 2
	local MinBound = Center - HalfSize
	local MaxBound = Center + HalfSize
	
	--// Check if the point is within the bounds of the area
	local X = Point.X >= MinBound.X and Point.X <= MaxBound.X
	local Y = Point.Y >= MinBound.Y and Point.Y <= MaxBound.Y
	local Z = Point.Z >= MinBound.Z and Point.Z <= MaxBound.Z

	return X and Y and Z
end

local function IsNpcInFarmland(NPC: BasePart): boolean
    local Position = NPC:GetPivot()

    for _, Farmland: Model in next, Farmlands do
        if IsPointInArea(Position, Farmland) then
            return true
        end
    end

    return false
end

local function FindEmermy(Name: string, InFarmland: boolean?): BasePart?
    for _, NPC: BasePart in next, Npcs:GetChildren() do
        local IsMatch = NPC.Name:find(Name)
        
        if not IsMatch then continue end
        if InFarmland and not IsNpcInFarmland(NPC) then continue end

        return NPC
    end
end

local function UpdateSwing(HitPivot: CFrame?, IsDown: boolean)
    local Hit = HitPivot or Mouse.Hit
    local MouseButton = RightClick.Value and "R" or "L"

    SwingSword:FireServer(MouseButton, IsDown, Hit)
end

local function UseWeaponArt()
    WeaponArt:FireServer()
end

local function UseRune()
    Rune:FireServer()
end

local function ToggleWeaponEquip()
    return EquipWeapon:InvokeServer()
end

local function IsSwordEquipped(): boolean
    local Character = LocalPlayer.Character
    if not Character then return false end
    
    return Character:FindFirstChild("Sword") and true
end

local function FindClosestShopkeeper(): BasePart?
    local ClosestShopkeeper = nil
    local ClosestDistance = math.huge

    local Character = LocalPlayer.Character
    local PlayerPos = Character:GetPivot().Position

    local Shopkeepers = CollectionService:GetTagged("Shopkeeper")
    for _, NPC: BasePart in ipairs(Shopkeepers) do
        local Distance = (NPC.Position - PlayerPos).Magnitude

        if Distance < ClosestDistance then
            ClosestShopkeeper = NPC
            ClosestDistance = Distance
        end
    end

    return ClosestShopkeeper
end

local function GetItemData(Name: string)
    local Data = ItemData[Name]
    return Data
end

type DestroyItems = {
    [string]: number
}
local function DestroyItems(Items: DestroyItems)
    return DestroyItem:InvokeServer(Items)
end

local function SellItems(Items: DestroyItems)
    local Shopkeeper = FindClosestShopkeeper()
    local Pivot = Shopkeeper:GetPivot()
    local Offset = CFrame.new(0, 0, -5)

    MoveToPoint(Pivot * Offset)

    return DestroyItems(Items)
end

type Item = {
    Favorited: boolean,
    ItemName: string,
    Enchantments: {}?,
    Amount: number?
}
local function GetInventoryItems(Config)
    local NameMatch = Config.NameMatch
    local TypeMatch = Config.TypeMatch
    local IsSell = Config.SellDataType
    local IgnoreEnchants = Config.IgnoreEnchants

    local Items = {}
    local Count = 0

    --// Find matching items in the player's inventory
    for Reference: string, Info: Item in next, InventoryItems do
        local ItemName = Info.ItemName
        local Enchantments = Info.Enchantments
        local Amount = Info.Amount -- Item speicific

        local Data = GetItemData(ItemName)
        local Type = Data.Type
        local Price = Data.Value

        if IgnoreItems and Amount then continue end
        if IgnoreEnchants and #Enchantments > 0 then continue end
        if NameMatch and not TypeMatch[ItemName] then continue end
        if TypeMatch and not TypeMatch[Type] then continue end

        Count += 1

        --// Compile the correct table type
        if IsSell then
            Items[Reference] = Amount or 1
        else
            Items[Reference] = Info 
        end
    end

    return Items, Count
end

local function CheckAutoSell()
    if not AutoSell.Value then return end
    if not InventoryItems then return end

    local IgnoreEnchants = IgnoreEnchanted.Value
    local Threshold = AutoSellThreshold.Value

    local Items, Count = GetInventoryItems({
        IgnoreEnchants = IgnoreEnchants,
        TypeMatch = ToSell,
        SellDataType = true,
    })

    SellDebugText.Text = `Items to sell count: {Count} Threshold: {Threshold}`

    --// Move to the closest shopkeeper and sell items
    if Count > Threshold then
        SellItems(Items)
    end
end

local function CheckSwordEquip()
    while true do
        if not AutoFarm.Value then return end
        if IsSwordEquipped() then return end

        --// Equip the sword
        ToggleWeaponEquip()

        wait(1)
    end
end

local function KillEnemy(NPC: BasePart)
    local Offset = Offset.Value
    local SwingDelay = 0.5
    
    local LastTick = tick() - 5
    local Pivot = NPC:GetPivot()
    local OffsetCFrame = CFrame.new(0, 0, Offset)

    local function UseWeapon()
        --// Time check
        local SecondsSinceSwing = tick() - LastTick
        if SecondsSinceSwing < SwingDelay then return end
        LastTick = tick()

        --// Check if the sword is equipped
        CheckSwordEquip()

        --// Swing sword
        UpdateSwing(Pivot, true)

        --// Use weapon art and rune
        if AutoWeaponart.Value then
            UseWeaponArt()
        end
        if AutoRune.Value then
            UseRune()
        end
    end

    MoveToPoint(Pivot * OffsetCFrame)
    
    --// Combat loop
    while true do
        if not NPC or not NPC.Parent then break end
        if not AutoFarm.Value then break end

        Pivot = NPC:GetPivot()

        --// Move to pivot
        local BehindCFrame = Pivot * OffsetCFrame
        PivotTo(BehindCFrame)

        --// Use weapon
        UseWeapon()

        task.wait()
    end

    --// Release the mouse button
    UpdateSwing(nil, false)
end

local function AutoFarmTick()
    local OnlyFarmland = FarmlandOnly.Value

    for Name: string, Enabled: boolean in next, Ememies do
        if not Enabled then continue end
        if not AutoFarm.Value then return end

        --// Find and kill the NPC
        local Enemy = FindEmermy(Name, OnlyFarmland)
        if Enemy then
            KillEnemy(Enemy)
        end
    end
end

local function Tick()
    AutoFarmTick()
    CheckAutoSell()
end

local function TickLoop()
    while wait(1) do
        if Enabled.Value then 
            Tick()
        end
    end
end

local function StartTick()
    coroutine.wrap(TickLoop)()
end

--// For decryption
SendInfo.OnClientEvent:Connect(function(Items)
    InventoryItems = Items
end)

--// Init
CollectFarmLand()
AddCheckboxes()
StartTick()
