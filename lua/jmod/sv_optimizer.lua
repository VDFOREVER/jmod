--[[
	JMod Optimizer - серверные лимиты партиклов и эффектов
	------------------------------------------------------

	Ограничивает количество газовых/дымовых партиклов и долгих
	эффектов (огонь, лужи огня), чтобы ядерные взрывы и газовые
	бомбы не убивали сервер.

	Настройки: lua/jmod/sh_optimizer.lua
]]

if not SERVER then return end

if not (JMod and JMod.Optimizer) then
	include("jmod/sh_optimizer.lua")
end

local Config = JMod.Optimizer
if not Config or not Config.Enabled then return end

local function IsPlayer(ply)
	return IsValid(ply) and ply:IsPlayer()
end

local function GetOwner(ent)
	if JMod and isfunction(JMod.GetEZowner) then
		return JMod.GetEZowner(ent)
	end

	return game.GetWorld()
end

local function NormalizeLimit(value, default)
	if value == nil then value = default end
	if value == false then return 0 end
	if type(value) ~= "number" then return tonumber(value) or 0 end
	return value
end

local ParticleGroup = {
	Cfg = Config.Particles,
	List = {}
}

local EffectGroup = {
	Cfg = Config.Effects,
	List = {}
}

local TrimPending = false

local function TrimGroup(group)
	local Cfg = group.Cfg
	local List = group.List

	if not Cfg or not Cfg.Enabled then
		group.List = {}
		return
	end

	local MaxGlobal = NormalizeLimit(Cfg.MaxGlobal, 0)
	local MaxPerPlayer = NormalizeLimit(Cfg.MaxPerPlayer, 0)
	local MaxPerClass = NormalizeLimit(Cfg.MaxPerClass, 0)

	if MaxGlobal <= 0 and MaxPerPlayer <= 0 and MaxPerClass <= 0 then
		group.List = {}
		return
	end

	local Valid = {}
	local OwnerCounts = {}
	local ClassCounts = {}
	local Total = 0
	local Now = CurTime()

	for i = 1, #List do
		local Ent = List[i]

		if IsValid(Ent) and not Ent:IsMarkedForDeletion() then
			Total = Total + 1
			Valid[Total] = Ent

			local Class = Ent:GetClass()
			ClassCounts[Class] = (ClassCounts[Class] or 0) + 1

			local Owner = GetOwner(Ent)
			if IsPlayer(Owner) then
				OwnerCounts[Owner] = (OwnerCounts[Owner] or 0) + 1
			end
		end
	end

	local Keep = {}

	for i = 1, Total do
		local Ent = Valid[i]
		local Class = Ent:GetClass()
		local Owner = GetOwner(Ent)

		-- Не удаляем сущность в том же тике, в котором её создали:
		-- вызывающий код ещё может обращаться к ней.
		local TooYoung = ((Ent.JModOptimizerBorn or 0) + 0.1) > Now
		local Remove = false

		if not TooYoung then
			if MaxGlobal > 0 and Total > MaxGlobal then
				Remove = true
			elseif MaxPerPlayer > 0 and IsPlayer(Owner) and (OwnerCounts[Owner] or 0) > MaxPerPlayer then
				Remove = true
			elseif MaxPerClass > 0 and (ClassCounts[Class] or 0) > MaxPerClass then
				Remove = true
			end
		end

		if Remove then
			Total = Total - 1
			ClassCounts[Class] = ClassCounts[Class] - 1

			if IsPlayer(Owner) then
				OwnerCounts[Owner] = OwnerCounts[Owner] - 1
			end

			SafeRemoveEntity(Ent)
		else
			Keep[#Keep + 1] = Ent
		end
	end

	group.List = Keep
end

local function TrimAll()
	TrimGroup(ParticleGroup)
	TrimGroup(EffectGroup)
end

local function RequestTrim()
	if TrimPending then return end

	TrimPending = true
	timer.Simple(0, function()
		TrimPending = false
		TrimAll()
	end)
end

local function TrackEntity(ent, group)
	local Cfg = group.Cfg
	if not Cfg or not Cfg.Enabled then return end
	if not Cfg.Classes or not Cfg.Classes[ent:GetClass()] then return end

	ent.JModOptimizerBorn = CurTime()
	group.List[#group.List + 1] = ent

	local SoftLimit = 100

	if Cfg.MaxGlobal and Cfg.MaxGlobal > 0 then
		SoftLimit = Cfg.MaxGlobal + 20
	elseif Cfg.MaxPerPlayer and Cfg.MaxPerPlayer > 0 then
		SoftLimit = Cfg.MaxPerPlayer * 2
	end

	if #group.List > SoftLimit then
		RequestTrim()
	end
end

hook.Add("OnEntityCreated", "JMod_OptimizerTrackParticles", function(ent)
	if not IsValid(ent) then return end

	TrackEntity(ent, ParticleGroup)
	TrackEntity(ent, EffectGroup)
end)

local ParticleInterval = math.max(NormalizeLimit(ParticleGroup.Cfg and ParticleGroup.Cfg.TrimInterval, 0.5), 0.1)
local EffectInterval = math.max(NormalizeLimit(EffectGroup.Cfg and EffectGroup.Cfg.TrimInterval, 0.5), 0.1)

timer.Create("JMod_OptimizerTrimParticles", ParticleInterval, 0, function()
	TrimGroup(ParticleGroup)
end)

timer.Create("JMod_OptimizerTrimEffects", EffectInterval, 0, function()
	TrimGroup(EffectGroup)
end)

local function IsAdmin(ply)
	if not IsValid(ply) then return true end
	if ply:IsAdmin() or ply:IsSuperAdmin() then return true end
	if JMod and isfunction(JMod.IsAdmin) then return JMod.IsAdmin(ply) end

	return false
end

local function Reply(ply, text)
	if IsPlayer(ply) then
		ply:PrintMessage(HUD_PRINTCONSOLE, text)
	else
		print(text)
	end
end

local function CountValidList(List)
	local Count = 0

	for i = 1, #List do
		local Ent = List[i]
		if IsValid(Ent) and not Ent:IsMarkedForDeletion() then
			Count = Count + 1
		end
	end

	return Count
end

concommand.Add("jmod_optimizer_status", function(ply)
	if not IsAdmin(ply) then return end

	Reply(ply, "=== JMod Optimizer ===")
	Reply(ply, string.format("Партиклы: %d / %d (на игрока: %d)", CountValidList(ParticleGroup.List), NormalizeLimit(ParticleGroup.Cfg and ParticleGroup.Cfg.MaxGlobal, 0), NormalizeLimit(ParticleGroup.Cfg and ParticleGroup.Cfg.MaxPerPlayer, 0)))
	Reply(ply, string.format("Эффекты: %d / %d (на игрока: %d)", CountValidList(EffectGroup.List), NormalizeLimit(EffectGroup.Cfg and EffectGroup.Cfg.MaxGlobal, 0), NormalizeLimit(EffectGroup.Cfg and EffectGroup.Cfg.MaxPerPlayer, 0)))
end, nil, "Показывает статистику JMod Optimizer.")

concommand.Add("jmod_optimizer_clear_particles", function(ply)
	if not IsAdmin(ply) then return end

	local Removed = 0
	local Groups = {ParticleGroup, EffectGroup}

	for _, group in ipairs(Groups) do
		local Cfg = group.Cfg

		if Cfg and Cfg.Enabled and Cfg.Classes then
			for Class in pairs(Cfg.Classes) do
				for _, Ent in ipairs(ents.FindByClass(Class)) do
					if IsValid(Ent) then
						SafeRemoveEntity(Ent)
						Removed = Removed + 1
					end
				end
			end
		end

		group.List = {}
	end

	Reply(ply, string.format("[JMod Optimizer] Удалено партиклов/эффектов: %d", Removed))
end, nil, "Удаляет все партиклы и эффекты, отслеживаемые оптимизатором.")
