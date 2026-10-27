-- Spike S3 (servidor): mensaje falso de chat, plan §2.2/§5.5. Código de prueba desechable.
-- Roblox no permite jugadores falsos: el servidor decide el texto y los clientes lo muestran.
-- Este script clona al primer jugador como "ElDoble", filtra el texto del banco curado
-- con TextService:FilterStringAsync POR RECEPTOR y lo envía por RemoteEvent.
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = Instance.new("RemoteEvent")
remote.Name = "SpikeFakeChat"
remote.Parent = ReplicatedStorage

local TEXTO = "aquí, ven" -- banco curado (plan §5.5); cero texto libre

task.delay(4, function()
	local victima = Players:GetPlayers()[1]
	if not victima or not victima.Character then
		warn("[S3] sin víctima o character")
		return
	end
	victima.Character.Archivable = true
	local doble = victima.Character:Clone()
	doble.Name = "ElDoble"
	for _, d in doble:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	doble.Parent = workspace
	local root = victima.Character:FindFirstChild("HumanoidRootPart")
	if root and doble:FindFirstChild("HumanoidRootPart") then
		doble:PivotTo(root.CFrame * CFrame.new(5, 0, 2))
	end
	print("[S3] clon creado en", doble:GetPivot().Position)

	for _, receptor in Players:GetPlayers() do
		local filtrado = TEXTO
		local ok, res = pcall(function()
			return TextService:FilterStringAsync(TEXTO, receptor.UserId, Enum.TextFilterContext.PublicChat)
		end)
		if ok then
			local ok2, res2 = pcall(function()
				return res:GetChatForUserAsync(receptor)
			end)
			if ok2 then
				filtrado = res2
			end
		else
			warn("[S3] FilterStringAsync falló:", res)
		end
		remote:FireClient(receptor, "ElDoble", filtrado)
	end
end)
