-- RanchClient: the player's side of Rot Ranch. Waits for the game, mounts the HUD and the RanchDex
-- over the 3D ranch, starts the soundtrack and the critters' motion, and binds the ranch keys;
-- every rule and every coin lives on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))
local RanchAudio = require(scripts:WaitForChild("RanchAudio"))
local RanchDex = require(scripts:WaitForChild("RanchDex"))
local CritterMotion = require(scripts:WaitForChild("CritterMotion"))
local Controls = require(ReplicatedStorage:WaitForChild("Controls"))

local view = Hud.mountRanchHud()
RanchDex.mountRanchDex(view.area)
RanchAudio.startRanchAudio()
CritterMotion.startCritterMotion()
Controls.bindRanchKeys(view)
