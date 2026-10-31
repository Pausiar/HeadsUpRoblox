-- Config de audio (plan §8 fase 6). Los SFX usan sonidos incluidos en Roblox
-- (rbxasset://sounds/...), así que no hace falta subir assets para probar.
-- La música está a 0: el creador debe subir un audio y poner su ID en Musica.id.
local AudioConfig = {}

AudioConfig.Musica = {
	id = 0, -- rbxassetid://...; 0 = sin música (silencio, no error)
	volumen = 0.35,
}

AudioConfig.Efectos = {
	Aviso = { id = "rbxasset://sounds/electronicpingshort.wav", volumen = 0.55, subtitulo = "¡Peligro!" },
	Impacto = { id = "rbxasset://sounds/impact_water.mp3", volumen = 0.7, subtitulo = "¡Impacto!" },
	Reanimar = { id = "rbxasset://sounds/action_get_up.mp3", volumen = 0.6, subtitulo = "Te han reanimado" },
	Checkpoint = { id = "rbxasset://sounds/switch3.wav", volumen = 0.5, subtitulo = "Checkpoint alcanzado" },
	Monstruo = { id = "rbxasset://sounds/bass.wav", volumen = 0.8, subtitulo = "Algo se mueve entre los árboles…", velocidad = 0.55 },
	-- L6b: aullido del Sabueso. id 0 = aún sin asset (AudioService lo descarta
	-- en su pcall); el subtítulo lo muestra Subtitulos.client sin mirar el id.
	Aullido = { id = 0, subtitulo = "Un aullido resuena entre los árboles…" },
	Compra = { id = "rbxasset://sounds/electronicpingshort.wav", volumen = 0.45, subtitulo = "Compra realizada", velocidad = 1.3 },
	Fin = { id = "rbxasset://sounds/action_falling.mp3", volumen = 0.7, subtitulo = "Fin de la partida" },
	UI = { id = "rbxasset://sounds/switch3.wav", volumen = 0.35 },
	-- Sustos ambientales (fase 9): nativos de Roblox a tono bajo, sin subtítulo
	-- (el texto delataría el susto). Los elige al azar HazardService.
	Susurro = { id = "rbxasset://sounds/bass.wav", volumen = 0.55, velocidad = 0.32 },
	Crujido = { id = "rbxasset://sounds/switch3.wav", volumen = 0.32, velocidad = 0.35 },
	Lamento = { id = "rbxasset://sounds/action_falling.mp3", volumen = 0.3, velocidad = 0.4 },
	Rama = { id = "rbxasset://sounds/impact_water.mp3", volumen = 0.34, velocidad = 0.45 },
}

AudioConfig.Sustos = { "Susurro", "Crujido", "Lamento", "Rama" }

function AudioConfig.PorId(id)
	return AudioConfig.Efectos[id]
end

return AudioConfig
