--// Created by depso
-- Run _G.StopMouseTracking() to stop the script!

local Players = game:GetService("Players")
local Connections = {}

local function TrackMouse(Player: Player)
    local MousePosition = Player:WaitForChild("MousePosition")
    local Character = Player.Character or Player.CharacterAdded:Wait()
    local RootPart = Character:WaitForChild("HumanoidRootPart")

    --// Create the marker
    local Part = Instance.new("Part", workspace)
    Part.Size = Vector3.new(1, 1, 1)
    Part.Anchored = true
    Part.CanCollide = false
    Part.Transparency = 0.5
    Part.Color = Color3.fromRGB(255, 0, 0)

    --// Create the beam
    local Beam = Instance.new("Beam", workspace)
    local Attachment0 = Instance.new("Attachment", RootPart)
    local Attachment1 = Instance.new("Attachment", Part)

    Beam.Attachment0 = Attachment0
    Beam.Attachment1 = Attachment1

    --// Mouse hit changed 
    local Connection = MousePosition.Changed:Connect(function()
        Part.Position = MousePosition.Value
    end)

    --// Cache the part
    Parts[Player] = {
      Part = Part,
      Connection = Connection
    }
end

local function PlayerRemoved(Player: Player)
    local Data = Connections[Player]
    if not Data then return end

    local Part = Data.Part
    local Connection = Data.Connection
  
    Part:Destroy()
    Connection:Disconnect()
end

_G.StopMouseTracking = function()
  for _, Player: Player in next, Players:GetPlayers() do
      PlayerRemoved(Player)
  end
end

for _, Player: Player in next, Players:GetPlayers() do
    TrackMouse(Player)
end

--// Connect player events
Players.PlayerRemoving:Connect(PlayerRemoved)
Players.PlayerAdded:Connect(TrackMouse)
