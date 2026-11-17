-- Controls: the rancher's keys and body. WASD and the camera stay Roblox's own; this binds L (lock
-- gate), R (rebirth) and Shift (sprint) through ContextActionService, sets walk speed (slower while
-- carrying a rustled critter), hides Rustle prompts on your own herd, and throws you when trampled.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Hud = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Hud"))

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

-- A stampede bull hit us: launch the character sideways and up, and shake the camera.
local function throwTrampledRancher()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	local side = if root.Position.Z >= 0 then 1 else -1
	root.AssemblyLinearVelocity = Vector3.new(-70, 60, side * 45)
	for i = 1, 12 do
		humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * (12 - i) * 0.25
		task.wait(0.03)
	end
	humanoid.CameraOffset = Vector3.zero
end

-- Binds the ranch keys and HUD buttons, and starts the per-frame body and HUD updates.
function Controls.bindRanchKeys(view: Hud.View)
	ContextActionService:BindAction("RanchLockGate", function(_, state)
		if state == Enum.UserInputState.Begin then
			Controls.requestGateLock()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.L)
	ContextActionService:BindAction("RanchRebirth", function(_, state)
		if state == Enum.UserInputState.Begin then
			Controls.requestRebirth()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.R)
	ContextActionService:BindAction("RanchSprint", function(_, state)
		sprinting = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift)
	view.gateButton.Activated:Connect(Controls.requestGateLock)
	view.rebirthButton.Activated:Connect(Controls.requestRebirth)

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
	player:GetAttributeChangedSignal("TrampledAt"):Connect(function()
		task.spawn(throwTrampledRancher)
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
		end
	end)
end

return Controls
