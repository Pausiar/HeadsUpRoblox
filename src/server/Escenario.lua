-- Piezas y carteles compartidos por los escenarios (etapa, ronda rápida y tienda).
local Escenario = {}

Escenario.Colores = {
	Madera = Color3.fromRGB(92, 58, 33), -- #5C3A21
	Poste = Color3.fromRGB(255, 201, 60), -- #FFC93C
	Cartel = Color3.fromRGB(245, 235, 216), -- #F5EBD8
	Roca = Color3.fromRGB(110, 106, 100),
	Verde = Color3.fromRGB(76, 140, 74), -- #4C8C4A
	Rojo = Color3.fromRGB(224, 69, 58), -- #E0453A
}

function Escenario.pieza(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = props.colision ~= false
	p.CanQuery = props.consulta ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.nombre
	p.Size = props.tamano
	p.CFrame = props.cf
	p.Color = props.color
	p.Material = props.material
	p.Shape = props.forma or Enum.PartType.Block
	p.Parent = props.padre
	return p
end

-- Cartel de madera con texto fijo del mundo (el servidor no cambia de idioma).
function Escenario.cartelTexto(props)
	local tablero = Escenario.pieza({
		nombre = props.nombre,
		tamano = props.tamano,
		cf = props.cf,
		color = props.colorTablero or Escenario.Colores.Madera,
		material = props.material or Enum.Material.Wood,
		padre = props.padre,
		colision = false,
		consulta = false,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Texto"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Adornee = tablero
	gui.Parent = tablero

	local texto = Instance.new("TextLabel")
	texto.Name = "Texto"
	texto.Size = UDim2.fromScale(1, 1)
	texto.BackgroundColor3 = props.fondo
	texto.BorderSizePixel = 0
	texto.Font = Enum.Font.GothamBlack
	texto.Text = props.texto
	texto.TextColor3 = props.colorTexto
	texto.TextScaled = true
	texto.TextWrapped = true
	texto.Parent = gui

	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop = UDim.new(0.08, 0)
	relleno.PaddingBottom = UDim.new(0.08, 0)
	relleno.PaddingLeft = UDim.new(0.06, 0)
	relleno.PaddingRight = UDim.new(0.06, 0)
	relleno.Parent = texto
	return tablero
end

return Escenario
