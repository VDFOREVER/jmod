--[[
	JMod Optimizer - автоматическая выдача владельца
	------------------------------------------------

	Задача: у всех JMod-сущностей и их производных (партиклы, снаряды,
	огонь, обломки, дочерние пропы) должен быть владелец-игрок, если
	сущность создана игроком или другой сущностью игрока.

	Владелец определяется по цепочке:
		EZowner -> DeadPlayer -> engine owner -> creator ->
		ent.Creator -> Owner/NW Owner -> родитель.

	JMod.GetEZowner/SetEZowner в sv_util.lua уже умеют использовать
	engine owner и creator как fallback, этот файл дополнительно
	проставляет поле EZowner и синхронизирует его с движком.
]]

if not SERVER then return end

local DEFAULT_CONFIG = {
	Enabled = true,
	RepairInterval = 15
}

local function ValidEntity(value)
	return type(value) == "Entity" and IsValid(value)
end

local function GetConfig()
	return (JMod.Optimizer and JMod.Optimizer.Ownership) or DEFAULT_CONFIG
end

local function DirectPlayer(ent)
	if not ValidEntity(ent) then return nil end
	if ent:IsPlayer() then return ent end

	if ValidEntity(ent.EZowner) and ent.EZowner:IsPlayer() then
		return ent.EZowner
	end

	if ValidEntity(ent.DeadPlayer) and ent.DeadPlayer:IsPlayer() then
		return ent.DeadPlayer
	end

	return nil
end

local function ResolveOwner(ent, depth)
	depth = depth or 0
	if depth > 6 or not ValidEntity(ent) or ent:IsPlayer() then return nil end

	local Owner

	Owner = DirectPlayer(ent)
	if Owner then return Owner end

	Owner = DirectPlayer(ent.EZowner)
	if Owner then return Owner end

	Owner = DirectPlayer(ent.DeadPlayer)
	if Owner then return Owner end

	Owner = DirectPlayer(ent.Creator)
	if Owner then return Owner end

	Owner = DirectPlayer(ent.Owner)
	if Owner then return Owner end

	if ent.EZownerID then
		local IDOwner = player.GetBySteamID64(ent.EZownerID)
		if IsValid(IDOwner) then return IDOwner end
	end

	local EngineOwner = ent.GetOwner and ent:GetOwner()
	if ValidEntity(EngineOwner) and EngineOwner ~= ent then
		Owner = DirectPlayer(EngineOwner)
		if Owner then return Owner end
	end

	local Creator = ent.GetCreator and ent:GetCreator()
	if ValidEntity(Creator) and Creator ~= ent then
		Owner = DirectPlayer(Creator)
		if Owner then return Owner end
	end

	if ent.GetNW2Entity then
		local NWOwner = ent:GetNW2Entity("Owner", NULL)
		if ValidEntity(NWOwner) and NWOwner ~= ent then
			Owner = ResolveOwner(NWOwner, depth + 1)
			if Owner then return Owner end
		end

		local InvOwner = ent:GetNW2Entity("EZInvOwner", NULL)
		if ValidEntity(InvOwner) and InvOwner ~= ent then
			Owner = DirectPlayer(InvOwner)
			if Owner then return Owner end
		end
	end

	if ent.GetNWEntity then
		local NWOwner = ent:GetNWEntity("Owner", NULL)
		if ValidEntity(NWOwner) and NWOwner ~= ent then
			Owner = ResolveOwner(NWOwner, depth + 1)
			if Owner then return Owner end
		end
	end

	local Parent = ent.GetParent and ent:GetParent()
	if ValidEntity(Parent) and Parent ~= ent then
		Owner = ResolveOwner(Parent, depth + 1)
		if Owner then return Owner end
	end

	return nil
end

local function TryOwn(ent)
	if not ValidEntity(ent) or ent:IsPlayer() then return end
	if not JMod or not isfunction(JMod.SetEZowner) then return end

	local Existing = ent.EZowner

	if ValidEntity(Existing) then
		if Existing:IsPlayer() then
			ent.JModBuilderOwned = (JMod.IsBuilder and JMod.IsBuilder(Existing)) or nil

			-- Если движок уже передал сущность другому игроку (например, оружие
			-- подобрали), обновляем JMod-владельца.
			local EngineOwner = ent.GetOwner and ent:GetOwner()
			if ValidEntity(EngineOwner) and EngineOwner:IsPlayer() and EngineOwner ~= Existing then
				JMod.SetEZowner(ent, EngineOwner)
				ent.JModOptimizerOwnerSynced = true
				return
			end

			-- Синхронизируем engine owner/creator один раз, даже если EZowner уже стоит.
			if not ent.JModOptimizerOwnerSynced then
				JMod.SetEZowner(ent, Existing)
				ent.JModOptimizerOwnerSynced = true
			end

			return
		end

		-- Явно выставленный мир (например, потерянный бомбовый владелец)
		-- не переприсваиваем.
		if Existing == game.GetWorld() then return end

		local ExistingPlayer = DirectPlayer(Existing)
		if ExistingPlayer then
			JMod.SetEZowner(ent, ExistingPlayer)
		end

		return
	end

	local Owner = ResolveOwner(ent)
	if ValidEntity(Owner) and Owner:IsPlayer() then
		JMod.SetEZowner(ent, Owner)
	end
end

local function IsAdmin(ply)
	if not IsValid(ply) then return true end
	if ply:IsAdmin() or ply:IsSuperAdmin() then return true end
	if JMod and isfunction(JMod.IsAdmin) then return JMod.IsAdmin(ply) end

	return false
end

local function IsJModEntity(ent)
	local Class = ent:GetClass()

	if string.sub(Class, 1, 9) == "ent_jack_" then return true end
	if string.sub(Class, 1, 8) == "npc_jack" then return true end
	if string.sub(Class, 1, 8) == "wep_jack" then return true end
	if string.sub(Class, 1, 9) == "sent_jack" then return true end
	if ent.IsJackyEZmachine or ent.IsJackyEZresource then return true end

	return false
end

hook.Add("OnEntityCreated", "JMod_OptimizerOwnership", function(ent)
	if not IsValid(ent) or ent:IsPlayer() then return end

	local Config = GetConfig()
	if not Config or not Config.Enabled then return end

	-- Если EZowner уже стоит (обычно у партиклов/снарядов), просто
	-- синхронизируем engine owner/creator и не создаём таймер.
	if ValidEntity(ent.EZowner) then
		TryOwn(ent)
		return
	end

	local HasOwnerHint = ValidEntity(ent.EZowner)
		or ValidEntity(ent.DeadPlayer)
		or ValidEntity(ent.Creator)
		or ValidEntity(ent.Owner)
		or (ent.GetOwner and ValidEntity(ent:GetOwner()))
		or (ent.GetCreator and ValidEntity(ent:GetCreator()))

	-- Не создаём таймеры для тысяч обычных map-сущностей.
	if not IsJModEntity(ent) and not HasOwnerHint then return end

	TryOwn(ent)

	-- Некоторые сущности получают creator/owner только после Spawn/Activate.
	timer.Simple(0.1, function()
		if IsValid(ent) then
			TryOwn(ent)
		end
	end)
end)

local function AssignFromSpawnHook(ply, ent)
	local Config = GetConfig()
	if not Config or not Config.Enabled then return end
	if not IsValid(ply) or not ply:IsPlayer() or not IsValid(ent) then return end

	-- Для обычных sandbox-пропов не вызываем SetOwner/CPPI:
	-- это может отключать физику и ломать коллизии. Достаточно
	-- JMod-полей владельца.
	ent.EZowner = ply
	ent.EZownerID = ply:SteamID64()
	ent.EZownerTeam = ply:Team()
	ent.JModBuilderOwned = (JMod.IsBuilder and JMod.IsBuilder(ply)) or nil
end

hook.Add("PlayerSpawnedProp", "JMod_OptimizerOwnershipProp", function(ply, model, ent)
	AssignFromSpawnHook(ply, ent)
end)

hook.Add("PlayerSpawnedRagdoll", "JMod_OptimizerOwnershipRagdoll", function(ply, model, ent)
	AssignFromSpawnHook(ply, ent)
end)

hook.Add("PlayerSpawnedEffect", "JMod_OptimizerOwnershipEffect", function(ply, model, ent)
	AssignFromSpawnHook(ply, ent)
end)

hook.Add("PlayerSpawnedVehicle", "JMod_OptimizerOwnershipVehicle", function(ply, ent)
	AssignFromSpawnHook(ply, ent)
end)

hook.Add("PlayerSpawnedNPC", "JMod_OptimizerOwnershipNPC", function(ply, ent)
	AssignFromSpawnHook(ply, ent)
end)

hook.Add("PlayerSpawnedSWEP", "JMod_OptimizerOwnershipSWEP", function(ply, ent)
	AssignFromSpawnHook(ply, ent)
end)

hook.Add("PlayerSpawnedSENT", "JMod_OptimizerOwnershipSENT", function(ply, ent)
	AssignFromSpawnHook(ply, ent)
end)

timer.Simple(0, function()
	local Config = GetConfig()
	if not Config or not Config.Enabled then return end

	local RepairInterval = tonumber(Config.RepairInterval) or 15
	if RepairInterval <= 0 then return end

	timer.Create("JMod_OptimizerOwnershipRepair", math.max(RepairInterval, 1), 0, function()
		local Patterns = {"ent_jack_*", "npc_jack*", "wep_jack*", "sent_jack*"}

		for _, Pattern in ipairs(Patterns) do
			for _, ent in ipairs(ents.FindByClass(Pattern)) do
				if IsValid(ent) and IsJModEntity(ent) then
					TryOwn(ent)
				end
			end
		end
	end)
end)

concommand.Add("jmod_optimizer_ownership_scan", function(ply)
	if not IsAdmin(ply) then return end

	local Fixed = 0
	local Patterns = {"ent_jack_*", "npc_jack*", "wep_jack*", "sent_jack*"}

	for _, Pattern in ipairs(Patterns) do
		for _, ent in ipairs(ents.FindByClass(Pattern)) do
			if IsValid(ent) and IsJModEntity(ent) and not ValidEntity(ent.EZowner) then
				local Before = ent.EZowner
				TryOwn(ent)
				if ent.EZowner ~= Before then
					Fixed = Fixed + 1
				end
			end
		end
	end

	local Msg = "[JMod Optimizer] Владелец выдан/обновлён: " .. Fixed

	if IsValid(ply) then
		ply:PrintMessage(HUD_PRINTCONSOLE, Msg)
	else
		print(Msg)
	end
end, nil, "Проставляет владельцев JMod-сущностям, у которых их нет.")
