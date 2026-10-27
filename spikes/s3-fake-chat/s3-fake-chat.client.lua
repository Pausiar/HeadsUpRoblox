-- Spike S3 (cliente): muestra el mensaje del Doble en el chat (TextChatService)
-- y como burbuja sobre el clon. Código de prueba desechable.
-- Nota: DisplayBubble no acepta el modelo del clon tal cual ("not a legal character");
-- hay que pasarle un BasePart (HumanoidRootPart). Corregido tras el primer playtest.
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("SpikeFakeChat")

task.spawn(function()
	local channels = TextChatService:WaitForChild("TextChannels", 10)
	if not channels then
		warn("[S3] sin TextChannels (ChatVersion legacy?)")
		return
	end
	local channel = channels:WaitForChild("RBXGeneral", 10)
	if not channel then
		warn("[S3] sin RBXGeneral")
		return
	end

	remote.OnClientEvent:Connect(function(nick, texto)
		channel:DisplaySystemMessage(string.format('<font color="#E0453A"><b>[%s]:</b></font> %s', nick, texto))
		print("[S3] mensaje mostrado en chat:", texto)
		local doble = workspace:FindFirstChild(nick)
		local parte = doble and (doble:FindFirstChild("HumanoidRootPart") or doble:FindFirstChildWhichIsA("BasePart"))
		if parte and TextChatService.DisplayBubble then
			TextChatService:DisplayBubble(parte, texto)
			print("[S3] burbuja mostrada sobre", nick)
		end
	end)
end)
