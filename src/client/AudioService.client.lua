-- AudioService (fase 6, plan §8): reproduce el remoto Sonido y la música opcional.
-- El servidor decide qué suena; aquí solo pool, volumen de Settings y pcall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)

local POOL = 4

-- Accesibilidad §8: con reducirEfectos los avisos críticos bajan y el resto se omite.
local CRITICOS = {
	Aviso = true,
	Impacto = true,
	Reanimar = true,
	Checkpoint = true,
	Monstruo = true,
	Fin = true,
}

local sonidos = {}
local infoSonido = {} -- [Sound] = { base, critico }
local siguiente = 1
local avisado = false
local musica = nil

local function avisarUnaVez(mensaje)
	if avisado then
		return
	end
	avisado = true
	warn(mensaje)
end

local function volumenDe(base, critico)
	local volumen = base * math.clamp((tonumber(Settings.Obtener("volumenEfectos")) or 0) / 100, 0, 1)
	if Settings.Obtener("reducirEfectos") == true then
		if not critico then
			return nil
		end
		volumen *= 0.6
	end
	return math.clamp(volumen, 0, 1)
end

for i = 1, POOL do
	local sonido = Instance.new("Sound")
	sonido.Name = "Sfx" .. i
	sonido.Parent = SoundService
	sonidos[i] = sonido
end

local function tomarSonido()
	for _, sonido in sonidos do
		if not sonido.IsPlaying then
			return sonido
		end
	end
	siguiente = siguiente % POOL + 1
	return sonidos[siguiente]
end

local function reproducir(efecto, id)
	local critico = CRITICOS[id] == true
	local base = tonumber(efecto.volumen) or 0.5
	local volumen = volumenDe(base, critico)
	if volumen == nil or volumen <= 0 then
		return
	end
	local sonido = tomarSonido()
	sonido:Stop()
	sonido.SoundId = efecto.id
	sonido.Volume = volumen
	sonido.PlaybackSpeed = tonumber(efecto.velocidad) or 1
	infoSonido[sonido] = { base = base, critico = critico }
	sonido:Play()
end

local function alRecibir(payload)
	if type(payload) ~= "table" or type(payload.id) ~= "string" then
		return
	end
	local efecto = AudioConfig.PorId(payload.id)
	if efecto then
		pcall(reproducir, efecto, payload.id)
	end
end

local function refrescarEfectos()
	for sonido, info in infoSonido do
		if sonido.IsPlaying then
			local volumen = volumenDe(info.base, info.critico)
			if volumen and volumen > 0 then
				sonido.Volume = volumen
			else
				sonido:Stop()
			end
		end
	end
end

local function volumenMusica()
	local factor = (tonumber(Settings.Obtener("volumenMusica")) or 0) / 100
	return math.clamp((AudioConfig.Musica.volumen or 0) * factor, 0, 1)
end

local function crearMusica()
	local id = AudioConfig.Musica.id
	if id == nil or id == 0 or id == "0" or id == "" then
		return -- id 0 = silencio intencional: ni objeto ni aviso
	end
	local sonido = Instance.new("Sound")
	sonido.Name = "MusicaFondo"
	sonido.Loop = true
	sonido.SoundId = typeof(id) == "number" and ("rbxassetid://" .. id) or id
	sonido.Volume = volumenMusica()
	sonido.Parent = SoundService
	sonido:Play()
	musica = sonido
end

if not pcall(crearMusica) then
	avisarUnaVez("[Audio] no se pudo iniciar la música")
end

Settings.AlCambiar.Event:Connect(function(clave)
	if clave == "volumenMusica" then
		if musica then
			pcall(function()
				musica.Volume = volumenMusica()
			end)
		end
	elseif clave == "volumenEfectos" or clave == "reducirEfectos" then
		pcall(refrescarEfectos)
	end
end)

local remoteSonido = nil

task.spawn(function()
	local ok, remote = pcall(Remotes.Esperar, Remotes.Nombres.Sonido)
	if not ok or not remote then
		return
	end
	remoteSonido = remote
	remote.OnClientEvent:Connect(function(payload)
		pcall(alRecibir, payload)
	end)
end)

task.delay(10, function()
	if not remoteSonido then
		avisarUnaVez("[Audio] remote Sonido ausente: sin efectos de sonido")
	end
end)

print("[AudioService] activo")
