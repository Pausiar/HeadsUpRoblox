-- TiendaCampamento: puesto grande de campaña al inicio de historia y de ronda rápida.
-- Todo se construye en el espacio local del puesto: X = tangente del sendero,
-- -Z = hacia el sendero (la cara frontal es la que lee el jugador).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Localization.Strings)
local Escenario = require(script.Parent.Escenario)

local TiendaCampamento = {}

local C = Escenario.Colores
local LONA = Color3.fromRGB(214, 198, 168)
local LONA_SOMBRA = Color3.fromRGB(186, 168, 138)
local VERDE_LONA = Color3.fromRGB(58, 96, 62)
local LUZ = Color3.fromRGB(255, 206, 128)
local METAL = Color3.fromRGB(70, 66, 62)

local function luzDeFuego(padre, pos, color, brillo, alcance, tamano)
	local farol = Escenario.pieza({
		nombre = "FarolTienda",
		tamano = tamano or Vector3.new(0.45, 0.7, 0.45),
		cf = pos,
		color = color,
		material = Enum.Material.Neon,
		padre = padre,
		colision = false,
		consulta = false,
	})
	local luz = Instance.new("PointLight")
	luz.Color = color
	luz.Brightness = brillo
	luz.Range = alcance
	luz.Shadows = false
	luz.Parent = farol
	return farol
end

function TiendaCampamento.Construir(carpeta, puntoInicio, tangenteInicio)
	local normal = tangenteInicio:Cross(Vector3.yAxis).Unit
	local base = puntoInicio.Y - 0.5
	local centro = Vector3.new(puntoInicio.X, base, puntoInicio.Z) + normal * 13.5
	local cf = CFrame.lookAt(centro, centro - normal)

	local tienda = Instance.new("Folder")
	tienda.Name = "TiendaCampamento"
	tienda.Parent = carpeta

	local function parte(props)
		props.padre = tienda
		return Escenario.pieza(props)
	end

	-- Mostrador de 9 studs con tablón y listones frontales.
	local mostrador = parte({
		nombre = "MostradorTienda",
		tamano = Vector3.new(9.2, 1.3, 2.6),
		cf = cf * CFrame.new(0, 0.65, -0.9),
		color = C.Madera,
		material = Enum.Material.WoodPlanks,
	})
	parte({
		nombre = "TablonTienda",
		tamano = Vector3.new(9.6, 0.18, 3.0),
		cf = cf * CFrame.new(0, 1.39, -0.9),
		color = Color3.fromRGB(126, 84, 48),
		material = Enum.Material.Wood,
	})
	for i = -2, 2 do
		parte({
			nombre = "ListonTienda",
			tamano = Vector3.new(0.42, 1.1, 0.12),
			cf = cf * CFrame.new(i * 1.75, 0.6, -2.26),
			color = Color3.fromRGB(126, 84, 48),
			material = Enum.Material.Wood,
			colision = false,
			consulta = false,
		})
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TiendaInicio"
	prompt.ActionText = "ABRIR TIENDA"
	prompt.ObjectText = "Tienda del campamento"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = mostrador

	-- Cuatro postes hasta la lona (7.2, no 8.8: a su altura el toldo baja a ~7.24).
	for _, x in ipairs({ -5.2, 5.2 }) do
		for _, z in ipairs({ -3.2, 3.2 }) do
			parte({
				nombre = "PosteTienda",
				tamano = Vector3.new(0.5, 7.2, 0.5),
				cf = cf * CFrame.new(x, 3.6, z),
				color = C.Madera,
				material = Enum.Material.Wood,
			})
		end
	end
	parte({
		nombre = "VigaFrenteTienda",
		tamano = Vector3.new(11.0, 0.45, 0.45),
		cf = cf * CFrame.new(0, 6.6, -3.2),
		color = C.Madera,
		material = Enum.Material.Wood,
		colision = false,
		consulta = false,
	})
	for _, lado in ipairs({ -1, 1 }) do
		parte({
			nombre = "VigaLateralTienda",
			tamano = Vector3.new(0.45, 0.45, 6.9),
			cf = cf * CFrame.new(lado * 5.2, 6.6, 0),
			color = C.Madera,
			material = Enum.Material.Wood,
			colision = false,
			consulta = false,
		})
	end
	parte({
		nombre = "CumbreraTienda",
		tamano = Vector3.new(11.6, 0.4, 0.4),
		cf = cf * CFrame.new(0, 8.8, 0),
		color = C.Madera,
		material = Enum.Material.Wood,
		colision = false,
		consulta = false,
	})

	-- Toldo a dos aguas con faldón verde en el borde delantero.
	local angulo = math.rad(26)
	local mediaLona = 2.45
	for _, lado in ipairs({ -1, 1 }) do
		parte({
			nombre = "ToldoTienda",
			tamano = Vector3.new(11.8, 0.16, mediaLona * 2),
			cf = cf
				* CFrame.new(0, 8.8 - mediaLona * math.sin(angulo), lado * mediaLona * math.cos(angulo))
				* CFrame.Angles(lado * angulo, 0, 0),
			color = lado < 0 and LONA or LONA_SOMBRA,
			material = Enum.Material.Fabric,
			colision = false,
			consulta = false,
		})
	end
	parte({
		nombre = "FaldonTienda",
		tamano = Vector3.new(11.8, 0.55, 0.1),
		cf = cf * CFrame.new(0, 6.62, -4.34),
		color = VERDE_LONA,
		material = Enum.Material.Fabric,
		colision = false,
		consulta = false,
	})

	-- Trastienda: pared de tablones con dos estantes y mercancía.
	parte({
		nombre = "ParedTienda",
		tamano = Vector3.new(10.9, 5.6, 0.4),
		cf = cf * CFrame.new(0, 2.8, 3.35),
		color = Color3.fromRGB(78, 50, 29),
		material = Enum.Material.WoodPlanks,
	})
	for _, y in ipairs({ 2.0, 3.35 }) do
		parte({
			nombre = "EstanteTienda",
			tamano = Vector3.new(8.6, 0.14, 1.0),
			cf = cf * CFrame.new(0, y, 2.72),
			color = C.Madera,
			material = Enum.Material.Wood,
			colision = false,
			consulta = false,
		})
	end
	local mercancia = {
		{ x = -3.4, y = 2.3, z = 2.72, tam = 0.62, color = C.Poste },
		{ x = -2.2, y = 2.25, z = 2.72, tam = 0.55, color = C.Rojo },
		{ x = 1.6, y = 2.28, z = 2.72, tam = 0.6, color = C.Verde },
		{ x = 2.9, y = 2.3, z = 2.72, tam = 0.65, color = C.Cartel },
	}
	for _, caja in ipairs(mercancia) do
		parte({
			nombre = "MercanciaTienda",
			tamano = Vector3.new(caja.tam, caja.tam, caja.tam),
			cf = cf * CFrame.new(caja.x, caja.y, caja.z) * CFrame.Angles(0, math.rad(caja.x * 9), 0),
			color = caja.color,
			material = Enum.Material.WoodPlanks,
			colision = false,
			consulta = false,
		})
	end
	for _, x in ipairs({ -0.6, 0.6, 3.9 }) do
		parte({
			nombre = "BotellaTienda",
			tamano = Vector3.new(0.34, 0.85, 0.34),
			cf = cf * CFrame.new(x, 3.82, 2.72),
			color = Color3.fromRGB(120, 190, 160),
			material = Enum.Material.Glass,
			colision = false,
			consulta = false,
		})
	end

	-- Cartel colgado de la viga delantera con dos cadenas.
	for _, x in ipairs({ -2.6, 2.6 }) do
		parte({
			nombre = "CadenaTienda",
			tamano = Vector3.new(0.08, 0.85, 0.08),
			cf = cf * CFrame.new(x, 6.5, -3.45),
			color = METAL,
			material = Enum.Material.Metal,
			colision = false,
			consulta = false,
		})
	end
	Escenario.cartelTexto({
		nombre = "CartelTienda",
		tamano = Vector3.new(7, 1.9, 0.22),
		cf = cf * CFrame.new(0, 5.55, -3.45),
		texto = string.upper(Localization.L("tienda")),
		fondo = VERDE_LONA,
		colorTablero = C.Madera,
		colorTexto = C.Cartel,
		padre = tienda,
	})

	-- Guirnalda de bombillas sobre el cartel y dos faroles en el alero.
	parte({
		nombre = "CableTienda",
		tamano = Vector3.new(9.8, 0.05, 0.05),
		cf = cf * CFrame.new(0, 6.62, -4.25),
		color = METAL,
		material = Enum.Material.Metal,
		colision = false,
		consulta = false,
	})
	for i = -3, 3 do
		parte({
			nombre = "BombillaTienda",
			tamano = Vector3.new(0.24, 0.24, 0.24),
			cf = cf * CFrame.new(i * 1.45, 6.48, -4.25),
			color = LUZ,
			material = Enum.Material.Neon,
			forma = Enum.PartType.Ball,
			colision = false,
			consulta = false,
		})
	end
	for _, lado in ipairs({ -1, 1 }) do
		parte({
			nombre = "GanchoFarol",
			tamano = Vector3.new(0.08, 0.35, 0.08),
			cf = cf * CFrame.new(lado * 5.2, 6.4, -4.2),
			color = METAL,
			material = Enum.Material.Metal,
			colision = false,
			consulta = false,
		})
		luzDeFuego(tienda, cf * CFrame.new(lado * 5.2, 5.95, -4.2), LUZ, 1.1, 12)
	end

	-- Cajas y barriles alrededor del puesto.
	local cajas = {
		{ x = -7.2, y = 0.7, z = 0.6, tam = 1.4, giro = 0 },
		{ x = -7.2, y = 2.1, z = 0.55, tam = 1.4, giro = 12 },
		{ x = -6.5, y = 0.6, z = 2.3, tam = 1.2, giro = -8 },
		{ x = 6.9, y = 0.65, z = 2.1, tam = 1.3, giro = 6 },
		{ x = 7.6, y = 0.6, z = 0.4, tam = 1.2, giro = -14 },
	}
	for _, caja in ipairs(cajas) do
		parte({
			nombre = "CajaTienda",
			tamano = Vector3.new(caja.tam, caja.tam, caja.tam),
			cf = cf * CFrame.new(caja.x, caja.y, caja.z) * CFrame.Angles(0, math.rad(caja.giro), 0),
			color = C.Madera,
			material = Enum.Material.WoodPlanks,
		})
	end
	for _, x in ipairs({ 5.6, 6.6 }) do
		parte({
			nombre = "BarrilTienda",
			tamano = Vector3.new(1.6, 1.0, 1.0),
			cf = cf * CFrame.new(x, 0.8, 3.3 + (x - 5.6) * 0.35) * CFrame.Angles(0, 0, math.pi / 2),
			color = Color3.fromRGB(104, 68, 40),
			material = Enum.Material.Wood,
			forma = Enum.PartType.Cylinder,
		})
	end

	-- Hoguera de campaña delante del puesto, con dos troncos para sentarse.
	parte({
		nombre = "BrasasTienda",
		tamano = Vector3.new(0.95, 0.22, 0.95),
		cf = cf * CFrame.new(-4.9, 0.14, -6.3),
		color = Color3.fromRGB(255, 130, 50),
		material = Enum.Material.Neon,
		colision = false,
		consulta = false,
	})
	for i = 0, 2 do
		parte({
			nombre = "TroncoTienda",
			tamano = Vector3.new(1.9, 0.3, 0.3),
			cf = cf * CFrame.new(-4.9, 0.24, -6.3) * CFrame.Angles(0, math.rad(i * 60), 0),
			color = C.Madera,
			material = Enum.Material.Wood,
		})
	end
	for i = 0, 3 do
		local ang = math.rad(45 + i * 90)
		parte({
			nombre = "PiedraFuego",
			tamano = Vector3.new(0.6, 0.6, 0.6),
			cf = cf * CFrame.new(-4.9 + math.cos(ang) * 1.25, 0.28, -6.3 + math.sin(ang) * 1.25),
			color = C.Roca,
			material = Enum.Material.Slate,
			forma = Enum.PartType.Ball,
		})
	end
	for _, x in ipairs({ -7.5, -2.3 }) do
		parte({
			nombre = "BancoTienda",
			tamano = Vector3.new(1.7, 0.42, 0.42),
			cf = cf * CFrame.new(x, 0.24, -5.9) * CFrame.Angles(0, math.rad(90), 0),
			color = C.Madera,
			material = Enum.Material.Wood,
		})
	end
	luzDeFuego(tienda, cf * CFrame.new(-4.9, 0.55, -6.3), Color3.fromRGB(255, 150, 70), 1.4, 14)

	-- Banderín en la cumbrera.
	parte({
		nombre = "AstaTienda",
		tamano = Vector3.new(0.12, 2.1, 0.12),
		cf = cf * CFrame.new(0, 9.95, 0),
		color = C.Madera,
		material = Enum.Material.Wood,
		colision = false,
		consulta = false,
	})
	parte({
		nombre = "BanderinTienda",
		tamano = Vector3.new(1.5, 0.85, 0.06),
		cf = cf * CFrame.new(0.82, 10.35, 0),
		color = C.Verde,
		material = Enum.Material.Fabric,
		colision = false,
		consulta = false,
	})

	return tienda
end

return TiendaCampamento
