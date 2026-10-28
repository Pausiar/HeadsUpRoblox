-- Accesibilidad (plan §8): escala de texto global sobre toda la PlayerGui.
-- La escala se aplica sobre el TextSize base guardado UNA vez por etiqueta, así cambiar
-- el ajuste varias veces nunca acumula. Las etiquetas con TextScaled=true se ignoran.
-- shortcut: escala TextSize sin reflujo de alturas fijas; a 140 % algunos rótulos de
-- 18–22 px pueden recortarse (revisión de reflujo en la fase 7).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ATRIBUTO_BASE = "TextoBaseEscala"
local escala = Settings.Obtener("escalaTexto") or 100

local function aplicar(objeto)
	if not (objeto:IsA("TextLabel") or objeto:IsA("TextButton")) then
		return
	end
	if objeto.TextScaled then
		return
	end
	local base = objeto:GetAttribute(ATRIBUTO_BASE)
	if base == nil then
		if objeto.TextSize <= 0 then
			return -- aún sin tamaño: se guardará en el siguiente pase
		end
		base = objeto.TextSize
		objeto:SetAttribute(ATRIBUTO_BASE, base)
	end
	objeto.TextSize = math.max(1, math.floor(base * escala / 100 + 0.5))
end

local function aplicarTodo()
	for _, objeto in ipairs(playerGui:GetDescendants()) do
		aplicar(objeto)
	end
end

-- GUIs creadas después (HUD, menús, popups) se escalan al añadirse; no hay reentrada
-- porque escribir TextSize no dispara DescendantAdded.
playerGui.DescendantAdded:Connect(aplicar)

Settings.AlCambiar.Event:Connect(function(clave, valor)
	if clave == "escalaTexto" then
		escala = valor
		aplicarTodo()
	end
end)

aplicarTodo()
print("[Accesibilidad] activa")
