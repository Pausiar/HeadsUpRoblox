-- ChatMimicView (cliente): pinta el chat de El Doble que envía ChatMimicService (plan §2.2/§5.5).
-- El texto llega YA filtrado por receptor desde el servidor: se muestra tal cual, sin refiltrar.
-- Reutiliza el patrón probado del spike S3: mensaje de sistema en el canal RBXGeneral con
-- RichText + burbuja sobre un BasePart (lección S3: DisplayBubble rechaza el Model del personaje).
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local COLOR_ETIQUETA = "#E0453A" -- rojo de peligro para la etiqueta [ElDoble]:
local COLOR_CREMA = "#F5EBD8" -- ADN (docs/design/design-dna.md): texto neutro del aviso

-- Guardas del spike S3 (10 s): si el juego usa chat legacy, salir limpio.
local canales = TextChatService:WaitForChild("TextChannels", 10)
if not canales then
	warn("[ChatMimicView] sin TextChannels (ChatVersion legacy?): el Doble no hablará en el chat")
	return
end
local canal = canales:WaitForChild("RBXGeneral", 10)
if not canal then
	warn("[ChatMimicView] sin canal RBXGeneral")
	return
end

-- Aviso previo del plan §5.5: que imitar el chat sea un reto y no un engaño (una vez por sesión;
-- este LocalScript corre una sola vez por unión en StarterPlayerScripts).
canal:DisplaySystemMessage(('<font color="%s">Un imitador puede escribir en este chat. No confíes solo en los mensajes.</font>'):format(COLOR_CREMA))

Remotes.Esperar(Remotes.Nombres.ChatFalso).OnClientEvent:Connect(function(mensaje)
	-- Payload del servidor: { nick = "ElDoble", texto = <ya filtrado por receptor> }
	if typeof(mensaje) ~= "table" or mensaje.texto == nil or mensaje.texto == "" then
		return
	end
	local nick = mensaje.nick or "ElDoble"

	canal:DisplaySystemMessage(('<font color="%s"><b>[%s]:</b></font> %s'):format(COLOR_ETIQUETA, nick, mensaje.texto))

	-- Burbuja sobre el clon (lección S3: pasar HumanoidRootPart, no el Model).
	local doble = workspace:FindFirstChild(nick)
	local parte = doble and (doble:FindFirstChild("HumanoidRootPart") or doble:FindFirstChildWhichIsA("BasePart"))
	if parte and TextChatService.DisplayBubble then
		TextChatService:DisplayBubble(parte, mensaje.texto)
	end
end)

print("[ChatMimicView] activo")
