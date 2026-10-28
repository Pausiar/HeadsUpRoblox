-- RopaArte: dibujo 2D del diseño de camiseta plan B (RopaConfig, decisión D7).
-- Mismo módulo para el servidor (SurfaceGui sobre el torso) y el cliente (vista
-- previa del editor): un solo dibujo, dos lienzos. Todo va en escala relativa
-- para que el mismo diseño quepa en un lienzo de 96 px y en uno de 2 studs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RopaConfig = require(ReplicatedStorage.Shared.Config.RopaConfig)

local RopaArte = {}

local function color3De(id, respaldoRgb)
	local color = RopaConfig.ColorPorId(id)
	local rgb = color and color.rgb or respaldoRgb
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function marco(padre, posicion, tamano, color)
	local f = Instance.new("Frame")
	f.Position = posicion
	f.Size = tamano
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = padre
	return f
end

local function redondear(objeto, radio)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = radio
	esquina.Parent = objeto
end

local function dibujarPatron(lienzo, patron, color2)
	if patron == "franjas" then
		for i = 0, 3 do
			marco(lienzo, UDim2.fromScale(0, 0.08 + i * 0.24), UDim2.fromScale(1, 0.09), color2)
		end
	elseif patron == "cuadros" then
		for i = 0, 3 do
			marco(lienzo, UDim2.fromScale(0, 0.1 + i * 0.26), UDim2.fromScale(1, 0.05), color2)
			marco(lienzo, UDim2.fromScale(0.1 + i * 0.26, 0), UDim2.fromScale(0.05, 1), color2)
		end
	elseif patron == "estrella" then
		-- Dos cuadrados girados (45° y 0°) forman una estrella de 8 puntas.
		local grande = marco(lienzo, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5), color2)
		grande.AnchorPoint = Vector2.new(0.5, 0.5)
		grande.Rotation = 45
		local pequena = marco(lienzo, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.36, 0.36), color2)
		pequena.AnchorPoint = Vector2.new(0.5, 0.5)
	elseif patron == "montana" then
		-- Pirámide escalonada: 4 barras centradas cada vez más estrechas.
		for i = 0, 3 do
			local barra = marco(
				lienzo,
				UDim2.fromScale(0.5, 0.45 + i * 0.12),
				UDim2.fromScale(0.5 - i * 0.09, 0.13),
				color2
			)
			barra.AnchorPoint = Vector2.new(0.5, 0)
		end
	end
end

local function dibujarPegatina(lienzo, id)
	if id == nil or id == "ninguna" then
		return
	end
	local base = marco(lienzo, UDim2.fromScale(0.5, 0.26), UDim2.fromScale(0.28, 0.28), Color3.new())
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.ZIndex = 2
	redondear(base, UDim.new(1, 0)) -- círculo
	if id == "pina" then
		base.BackgroundColor3 = Color3.fromRGB(255, 201, 60)
		local hoja = marco(base, UDim2.fromScale(0.5, -0.42), UDim2.fromScale(0.55, 0.32), Color3.fromRGB(76, 140, 74))
		hoja.AnchorPoint = Vector2.new(0.5, 0)
		redondear(hoja, UDim.new(0, 3))
	elseif id == "roca" then
		base.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
		base.Rotation = 12
		local brillo = marco(base, UDim2.fromScale(0.18, 0.18), UDim2.fromScale(0.3, 0.24), Color3.fromRGB(165, 165, 165))
		redondear(brillo, UDim.new(0, 3))
	elseif id == "arbol" then
		-- Tronco fuera del cuadrado girado para que quede vertical.
		local tronco = marco(lienzo, UDim2.fromScale(0.5, 0.39), UDim2.fromScale(0.07, 0.1), Color3.fromRGB(92, 58, 33))
		tronco.AnchorPoint = Vector2.new(0.5, 0)
		tronco.ZIndex = 1
		base.BackgroundColor3 = Color3.fromRGB(76, 140, 74)
		base.Rotation = 45
	elseif id == "huella" then
		base.BackgroundColor3 = Color3.fromRGB(62, 42, 24)
		base.Size = UDim2.fromScale(0.2, 0.17)
		base.Position = UDim2.fromScale(0.5, 0.3)
		for i = 0, 2 do
			local dedo = marco(
				base,
				UDim2.fromScale(0.5 + (i - 1) * 0.42, -0.62 + math.abs(i - 1) * 0.16),
				UDim2.fromScale(0.26, 0.26),
				Color3.fromRGB(62, 42, 24)
			)
			dedo.AnchorPoint = Vector2.new(0.5, 0.5)
			redondear(dedo, UDim.new(1, 0))
		end
	end
end

-- Dibuja el diseño dentro de `contenedor` (un Frame o un SurfaceGui) y devuelve
-- el lienzo creado: el llamador lo destruye antes de redibujar.
function RopaArte.Dibujar(contenedor, diseno)
	if type(diseno) ~= "table" then
		diseno = RopaConfig.PorDefecto
	end
	local lienzo = Instance.new("Frame")
	lienzo.Name = "Lienzo"
	lienzo.Size = UDim2.fromScale(1, 1)
	lienzo.BackgroundColor3 = color3De(diseno.color1, RopaConfig.PorDefecto.color1)
	lienzo.BorderSizePixel = 0
	lienzo.ClipsDescendants = true
	lienzo.Parent = contenedor
	dibujarPatron(lienzo, diseno.patron, color3De(diseno.color2, RopaConfig.PorDefecto.color2))
	dibujarPegatina(lienzo, diseno.pegatina)
	return lienzo
end

return RopaArte
