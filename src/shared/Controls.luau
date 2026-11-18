-- Controls: the rancher's keys and body. WASD and the camera stay Roblox's own; this binds L (lock
-- gate), R (rebirth), B (RanchDex), M (music on/off) and Shift (sprint) through ContextActionService,
-- sets walk speed (slower while carrying a rustled critter), hides Rustle prompts on your own herd,
-- routes the server's cues to RanchAudio and the HUD's flourishes, and throws you when trampled by
-- the herd or swept up by the Dust Devil.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))
local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))
local RanchAudio = require(scripts:WaitForChild("RanchAudio"))
local RanchDex = require(scripts:WaitForChild("RanchDex"))

local Controls = {}

Controls.WALK = 18
Controls.SPRINT = 27
Controls.CARRY = 13

local player = Players.LocalPlayer
local action = ReplicatedStorage:WaitForChild("RanchAction") :: RemoteEvent
local sprinting = false

function Controls.requestGateLock()
	action:FireServer("lock")
end

function Controls.requestRebirth()
	action:FireServer("rebirth")
end

local function shakeCamera(humanoid: Humanoid, strength: number, frames: number)
	for i = 1, frames do
		humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * (frames - i) * strength
		task.wait(0.03)
	end
	humanoid.CameraOffset = Vector3.zero
end

-- A stampede bull hit us: launch the character sideways and up. The Dust Devil instead spins you
-- straight up into the sky.
local function throwRancher()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	if player:GetAttribute("TrampledBy") == "twister" then
		root.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), 110, math.random(-20, 20))
		root.AssemblyAngularVelocity = Vector3.new(0, 25, 0)
		shakeCamera(humanoid, 0.18, 16)
	else
		local side = if root.Position.Z >= 0 then 1 else -1
		root.AssemblyLinearVelocity = Vector3.new(-70, 60, side * 45)
		shakeCamera(humanoid, 0.25, 12)
	end
end

local function bindKey(name: string, key: Enum.KeyCode, onPress: () -> ())
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			onPress()
		end
		return Enum.ContextActionResult.Sink
	end, false, key)
end

-- The big centre-screen pops some cues deserve.
local function flourish(view: Hud.View, name: string, data: any)
	if name == "contract" then
		Hud.bigPop(view, "CONTRACT DONE! " .. tostring(data), Hud.GOLD)
	elseif name == "tag" then
		Hud.bigPop(view, "RUSTLER TAGGED! +" .. Cast.formatCash(data or 0), Color3.fromRGB(130, 255, 120))
	elseif name == "rebirth" then
		Hud.bigPop(view, "REBORN! x" .. string.format("%.1f", Cast.rebirthMultiplier(data or 1)), Color3.fromRGB(230, 170, 255))
	elseif name == "coin" then
		Hud.bigPop(view, "+" .. Cast.formatCash(data or 0), Hud.GOLD)
	elseif name == "golden" then
		Hud.bigPop(view, "GOLDEN HOUR! x2", Hud.GOLD)
	elseif name == "trampled" then
		Hud.bigPop(view, if player:GetAttribute("TrampledBy") == "twister" then "SWEPT UP!" else "TRAMPLED!", Hud.RED)
	elseif name == "lasso" and type(data) == "table" and data.mutation then
		Hud.bigPop(view, string.upper(data.mutation) .. "!", Cast.mutationTint(data.mutation) or Hud.GOLD)
	end
end

-- Binds the ranch keys and HUD buttons, and starts the per-frame body and HUD updates.
function Controls.bindRanchKeys(view: Hud.View)
	bindKey("RanchLockGate", Enum.KeyCode.L, Controls.requestGateLock)
	bindKey("RanchRebirth", Enum.KeyCode.R, Controls.requestRebirth)
	bindKey("RanchDex", Enum.KeyCode.B, RanchDex.toggle)
	bindKey("RanchMusic", Enum.KeyCode.M, function()
		local on = RanchAudio.toggleMusic()
		Hud.showToast(view, if on then "Music ON (M)" else "Music OFF (M) - sound effects stay on", Color3.fromRGB(255, 236, 190))
	end)
	ContextActionService:BindAction("RanchSprint", function(_, state)
		sprinting = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift)
	view.gateButton.Activated:Connect(Controls.requestGateLock)
	view.rebirthButton.Activated:Connect(Controls.requestRebirth)
	view.dexButton.Activated:Connect(RanchDex.toggle)

	-- Your own herd shows no Rustle prompt: you cannot rustle from yourself. Every other prompt
	-- gets the ranch's wooden tag while it is in reach.
	local tags: { [ProximityPrompt]: BillboardGui } = {}
	ProximityPromptService.PromptShown:Connect(function(prompt)
		local model = prompt:FindFirstAncestorOfClass("Model")
		if prompt:GetAttribute("Rustle") and model and model:GetAttribute("OwnerUserId") == player.UserId then
			prompt.Enabled = false
			return
		end
		if prompt.Style == Enum.ProximityPromptStyle.Custom and not tags[prompt] then
			tags[prompt] = Hud.showRanchPrompt(prompt)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local tag = tags[prompt]
		if tag then
			tag:Destroy()
			tags[prompt] = nil
		end
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if tags[prompt] then
			Hud.fillRanchPrompt(tags[prompt], prompt.HoldDuration)
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if tags[prompt] then
			Hud.fillRanchPrompt(tags[prompt], 0)
		end
	end)

	local toast = ReplicatedStorage:WaitForChild("RanchToast") :: RemoteEvent
	toast.OnClientEvent:Connect(function(message, color)
		Hud.showToast(view, message, color)
	end)
	local cue = ReplicatedStorage:WaitForChild("RanchCue") :: RemoteEvent
	cue.OnClientEvent:Connect(function(name, data)
		RanchAudio.play(name, data)
		flourish(view, name, data)
	end)
	player:GetAttributeChangedSignal("TrampledAt"):Connect(function()
		task.spawn(throwRancher)
	end)
	player:GetAttributeChangedSignal("Dex"):Connect(function()
		if RanchDex.isOpen() then
			RanchDex.refresh()
		end
	end)

	local popClock = 0
	RunService.RenderStepped:Connect(function(dt)
		Hud.refreshRanchHud(view, dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local carrying = (player:GetAttribute("Carrying") or "") ~= ""
			humanoid.WalkSpeed = if carrying then Controls.CARRY elseif sprinting then Controls.SPRINT else Controls.WALK
		end
		popClock += dt
		if popClock >= 1 then
			popClock = 0
			Hud.popIncome(view)
			if (player:GetAttribute("Income") or 0) > 0 then
				RanchAudio.play("cash")
			end
		end
	end)
end

return Controls
