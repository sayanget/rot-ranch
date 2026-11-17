-- RanchClient: the player's side of Rot Ranch. Waits for the game, mounts the HUD over the 3D
-- ranch and binds the ranch keys; every rule and every coin lives on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Hud = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Hud"))
local Controls = require(ReplicatedStorage:WaitForChild("Controls"))

local view = Hud.mountRanchHud()
Controls.bindRanchKeys(view)
