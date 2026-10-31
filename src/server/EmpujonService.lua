-- Empujón amigo (B10, fase 11 · L5, plan §4.4): impulso suave validado en el
-- servidor. Solo empuja: sin derribo ni daño (PlayerStateService no se toca).
-- El cliente (Acciones, en integración) envía { accion = "empujar", objetivo =
-- userId } — o el payload corto { objetivo = userId } del contrato del remoto —
-- y aquí se valida todo: enfriamiento por empujador, estado de ambos, porte y
-- distancia. El mismo remoto transporta el ajuste «modo amistoso» del cliente
-- ({ accion = "amistoso", valor = bool }) porque Settings vive por VM y el
-- servidor no ve los Cambiar del cliente; §3.1 lo migrará a ajustes persistentes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local Ajustes = Config.Etapa0.Empujon

local EmpujonService = {}

-- Copia en el servidor del ajuste «modo amistoso» de cada cliente. Persistencia
-- de sesión: tabla en memoria, limpiada al salir; el valor del toggle del menú
-- llega por el remoto Empujar (no hay DataStore en este slice).
local modoAmistoso = {} -- [player] = bool

local permitirEmpujon -- RateLimiter por empujador (Config.Etapa0.Empujon.Enfriamiento)
local permitirAjuste -- anti-flood del canal «amistoso»; el toggle es idempotente
local playerState

-- EnJuego, vivo y no caído (patrón de EstaminaService).
local function vivoEnJuego(player)
	if not player or player:GetAttribute("EnJuego") ~= true then
		return false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	return not playerState.EstaCaido(player)
end

local function raizDe(player)
	local char = player and player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

-- B9 se escribe en paralelo: CargarService puede no existir todavía. Si falta (o
-- aún no expone EstaPortando), se omite la comprobación de porte y queda cubierta
-- cuando la integración lo conecte; el resto de validaciones no cambia.
local cargarService
local function estaPortando(player)
	if cargarService == nil then
		local modulo = script.Parent:FindFirstChild("CargarService")
		local ok, servicio = pcall(require, modulo)
		cargarService = (ok and servicio) or false
	end
	if type(cargarService) == "table" and type(cargarService.EstaPortando) == "function" then
		local ok, portando = pcall(cargarService.EstaPortando, player)
		if ok then
			return portando == true
		end
	end
	return false
end

local function validarYEmpujar(player, datos)
	if type(datos.objetivo) ~= "number" then
		return
	end
	-- El enfriamiento se gasta aunque el intento no sea válido: el spam de
	-- payloads inventados también queda frenado a 1 intento cada 3 s.
	if not permitirEmpujon(player) then
		return
	end
	if modoAmistoso[player] then
		return -- ajuste «modo amistoso» del propio empujador: no empuja a nadie
	end
	if not vivoEnJuego(player) then
		return -- fuera de partida, muerto o caído no empuja
	end
	local objetivo = Players:GetPlayerByUserId(datos.objetivo)
	if not objetivo or objetivo == player then
		return
	end
	if not vivoEnJuego(objetivo) then
		return -- criterio B10: no se mueve a nadie fuera de partida ni caído
	end
	if estaPortando(player) or estaPortando(objetivo) then
		return -- ni portadores ni cargados empujan o reciben empujones (§4.4)
	end

	local raizEmpujador = raizDe(player)
	local raizObjetivo = raizDe(objetivo)
	if not raizEmpujador or not raizObjetivo then
		return
	end

	-- Dirección horizontal del empujador hacia el objetivo (Y=0).
	local delta = raizObjetivo.Position - raizEmpujador.Position
	local plano = Vector3.new(delta.X, 0, delta.Z)
	if plano.Magnitude > Ajustes.Alcance then
		return
	end
	if plano.Magnitude < 0.05 then
		return -- solapados: sin dirección fiable, nada que empujar
	end

	-- Impulso escalado por la masa del objetivo: misma velocidad final para
	-- cualquier avatar. Sin daño ni derribo: solo física, Humanoid intacto.
	local masa = raizObjetivo.AssemblyMass
	raizObjetivo:ApplyImpulse(plano.Unit * Ajustes.Fuerza * masa)
	print("[Empujon] " .. player.Name .. " empujó a " .. objetivo.Name)
end

function EmpujonService.Iniciar()
	playerState = require(script.Parent.PlayerStateService)
	permitirEmpujon = RateLimiter.nuevo(Ajustes.Enfriamiento)
	permitirAjuste = RateLimiter.nuevo(0.1)

	local remoto = Remotes.Crear(Remotes.Nombres.Empujar)
	remoto.OnServerEvent:Connect(function(player, datos)
		if type(datos) ~= "table" then
			return
		end
		if datos.accion == "amistoso" then
			if permitirAjuste(player) then
				modoAmistoso[player] = datos.valor == true
			end
			return
		end
		if datos.accion == nil or datos.accion == "empujar" then
			validarYEmpujar(player, datos)
		end
		-- Cualquier otra «accion»: ignorada.
	end)

	Players.PlayerRemoving:Connect(function(player)
		modoAmistoso[player] = nil
	end)

	print("[Empujon] activo (enfriamiento " .. tostring(Ajustes.Enfriamiento) .. " s)")
end

return EmpujonService
