--[[
	JMod Spawn Control
	------------------
	1) Запрещает спавнить взрывчатку из меню спавна.
	   По умолчанию запрещены ВСЕ предметы категории
	   "JMod - EZ Explosives". Получать их можно только крафтом.

	2) Запрещает AdvDupe2 копировать JMod-ресурсы, контейнеры
	   с ресурсами и машины с загруженными ресурсами.

	Настройки ниже.
]]

if not SERVER then return end

JMod = JMod or {}

JMod.SpawnControl = {
	Enabled = true,
	Notify = true,
	NotifyCooldown = 2,

	Explosives = {
		Enabled = true,

		-- Категории, которые нельзя спавнить из меню.
		BlockCategories = {
			["JMod - EZ Explosives"] = true
		},

		-- Дополнительные классы, которые нельзя спавнить.
		BlockedClasses = {},

		-- Белый список: эти классы разрешены, даже если их
		-- категория указана в BlockCategories.
		AllowedClasses = {}
	},

	AdvDupe2 = {
		Enabled = true,

		-- Блокировать копирование JMod-ресурсов
		-- (топливо, руда, слитки, газ, вода и т.д.).
		BlockResources = true,

		-- Блокировать контейнеры с содержимым:
		-- ящики, универсальные ящики, compact box, аммо-боксы.
		BlockContainers = true,

		-- Блокировать все JMod-машины.
		-- По умолчанию false, чтобы можно было копировать пустые машины.
		BlockMachines = false,

		-- Блокировать машины, в которых уже есть ресурсы
		-- (электричество, топливо, руда, газ, вода, химикаты).
		BlockLoadedMachines = true,

		-- Блокировать копирование взрывчатки через AdvDupe2.
		-- По умолчанию false: спавн из меню уже запрещён,
		-- но крафт и последующее копирование остаются разрешены.
		BlockExplosives = false,

		-- Дополнительные классы, которые нельзя копировать.
		BlockedClasses = {},

		-- Белый список: эти классы можно копировать всегда.
		AllowedClasses = {}
	}
}

local C = JMod.SpawnControl

local ContainerClasses = {
	["ent_jack_gmod_ezcrate"] = true,
	["ent_jack_gmod_ezcrate_uni"] = true,
	["ent_jack_gmod_ezcompactbox"] = true,
	["ent_jack_gmod_ezanomaly_crate"] = true,
	["ent_jack_gmod_ezammobox"] = true
}

local function Notify(ply, message)
	if not C.Notify or not IsValid(ply) or not ply:IsPlayer() then return end

	local Now = CurTime()
	if (ply.JModSpawnControlNotifyTime or 0) > Now then return end

	ply.JModSpawnControlNotifyTime = Now + (C.NotifyCooldown or 2)
	ply:PrintMessage(HUD_PRINTCENTER, "JMod: " .. message)
end

local function GetCategory(class)
	if not class or not scripted_ents then return nil end

	if isfunction(scripted_ents.GetMember) then
		return scripted_ents.GetMember(class, "Category")
	end

	local Stored = scripted_ents.GetStored(class)
	local Table = Stored and Stored.t

	return Table and Table.Category
end

local function IsBasedOn(class, base)
	if not class then return false end
	if class == base then return true end

	return scripted_ents and isfunction(scripted_ents.IsBasedOn) and scripted_ents.IsBasedOn(class, base)
end

function JMod.IsExplosiveSpawnRestricted(class)
	if not C.Enabled or not C.Explosives.Enabled then return false end
	if not class then return false end
	if C.Explosives.AllowedClasses[class] then return false end
	if C.Explosives.BlockedClasses[class] then return true end

	local Category = GetCategory(class)

	return Category and C.Explosives.BlockCategories[Category] or false
end

function JMod.IsNoDupeClass(class)
	if not C.Enabled or not C.AdvDupe2.Enabled then return false end
	if not class then return false end
	if C.AdvDupe2.AllowedClasses[class] then return false end
	if C.AdvDupe2.BlockedClasses[class] then return true end

	if C.AdvDupe2.BlockResources and IsBasedOn(class, "ent_jack_gmod_ezresource") then
		return true
	end

	if C.AdvDupe2.BlockContainers then
		if ContainerClasses[class]
			or IsBasedOn(class, "ent_jack_gmod_ezcrate")
			or IsBasedOn(class, "ent_jack_gmod_ezcompactbox") then
			return true
		end
	end

	if C.AdvDupe2.BlockMachines and IsBasedOn(class, "ent_jack_gmod_ezmachine_base") then
		return true
	end

	if C.AdvDupe2.BlockExplosives then
		local Category = GetCategory(class)
		if Category == "JMod - EZ Explosives" then return true end
	end

	return false
end

local function HasLoadedResources(ent)
	if not IsValid(ent) then return false end

	for _, Method in pairs(JMod.EZ_RESOURCE_TYPE_METHODS or {}) do
		local Getter = ent["Get" .. Method]

		if isfunction(Getter) then
			local Value = Getter(ent)
			if type(Value) == "number" and Value > 0 then
				return true
			end
		end
	end

	if ent.GetOre then
		local Ore = ent:GetOre()
		if type(Ore) == "number" and Ore > 0 then return true end
	end

	if ent.GetResource then
		local Resource = ent:GetResource()
		if type(Resource) == "number" and Resource > 0 then return true end
	end

	return false
end

function JMod.IsNoDupeEntity(ent)
	if not C.Enabled or not C.AdvDupe2.Enabled then return false end
	if not IsValid(ent) then return false end

	local class = ent:GetClass()
	if C.AdvDupe2.AllowedClasses[class] then return false end
	if C.AdvDupe2.BlockedClasses[class] then return true end

	if C.AdvDupe2.BlockResources and ent.IsJackyEZresource then return true end
	if C.AdvDupe2.BlockContainers and (ent.IsJackyEZcrate or ContainerClasses[class]) then return true end

	if ent.IsJackyEZmachine then
		if C.AdvDupe2.BlockMachines then return true end
		if C.AdvDupe2.BlockLoadedMachines and HasLoadedResources(ent) then return true end
	end

	if C.AdvDupe2.BlockExplosives and GetCategory(class) == "JMod - EZ Explosives" then
		return true
	end

	return false
end

-- ============================================================
-- Запрет спавна взрывчатки из меню
-- ============================================================

hook.Add("PlayerSpawnSENT", "JMod_ExplosiveSpawnPreCheck", function(ply, class)
	if JMod.IsExplosiveSpawnRestricted(class) then
		Notify(ply, "Этот предмет нельзя спавнить. Получите его крафтом.")
		return false
	end
end)

local WrappedSpawnFunctions = {}
local WrappedValues = {}

local function GetRestrictedWrapper(class, Original)
	local Existing = WrappedSpawnFunctions[Original]
	if Existing then return Existing end
	if WrappedValues[Original] then return Original end

	local Wrapper = function(selfTable, ply, tr, classname)
		local ActualClass = classname or (selfTable and selfTable.ClassName) or class

		if JMod.IsExplosiveSpawnRestricted(ActualClass) then
			Notify(ply, "Этот предмет нельзя спавнить. Получите его крафтом.")
			return nil
		end

		return Original(selfTable, ply, tr, classname)
	end

	WrappedSpawnFunctions[Original] = Wrapper
	WrappedValues[Wrapper] = true

	return Wrapper
end

-- ============================================================
-- Запрет копирования ресурсов через AdvDupe2
-- ============================================================

local WrappedIsCopyable

local function InstallAdvDupe2Guard()
	if not (AdvDupe2 and AdvDupe2.duplicator and isfunction(AdvDupe2.duplicator.IsCopyable)) then return end
	if AdvDupe2.duplicator.IsCopyable == WrappedIsCopyable then return end

	local Original = AdvDupe2.duplicator.IsCopyable

	local Wrapper = function(ent)
		if not IsValid(ent) then return false end
		if JMod.IsNoDupeEntity(ent) then return false end

		return Original(ent)
	end

	WrappedIsCopyable = Wrapper
	AdvDupe2.duplicator.IsCopyable = Wrapper
end

hook.Add("AdvDupe2_CanCreateEntity", "JMod_AdvDupe2CanCreateEntity", function(ply, class)
	if JMod.IsNoDupeClass(class) then
		Notify(ply, "JMod-ресурсы нельзя копировать через AdvDupe2")
		return false, "JMod resources cannot be duplicated"
	end
end)

-- ============================================================
-- Установка обёрток (AdvDupe2 и SENT-классы могут загружаться позже)
-- ============================================================

local function Install()
	if not C.Enabled then return end

	-- Спавн-функции взрывчатки
	if scripted_ents and isfunction(scripted_ents.GetList) then
		local EntityList = scripted_ents.GetList()

		-- Сначала оборачиваем собственные SpawnFunction классов.
		for class, stored in pairs(EntityList) do
			local Table = stored and (stored.t or stored)

			if istable(Table) and JMod.IsExplosiveSpawnRestricted(class) and isfunction(Table.SpawnFunction) then
				Table.SpawnFunction = GetRestrictedWrapper(class, Table.SpawnFunction)
			end
		end

		-- Затем даём явную обёртку классам, которые наследуют SpawnFunction.
		for class, stored in pairs(EntityList) do
			local Table = stored and (stored.t or stored)

			if istable(Table) and JMod.IsExplosiveSpawnRestricted(class) and not isfunction(Table.SpawnFunction) then
				local Full = isfunction(scripted_ents.Get) and scripted_ents.Get(class)

				if Full and isfunction(Full.SpawnFunction) then
					Table.SpawnFunction = GetRestrictedWrapper(class, Full.SpawnFunction)
				end
			end
		end
	end

	InstallAdvDupe2Guard()
end

hook.Add("InitPostEntity", "JMod_SpawnControlInit", function()
	timer.Simple(1, Install)
	timer.Simple(5, Install)
end)

hook.Add("OnReloaded", "JMod_SpawnControlReload", function()
	timer.Simple(1, Install)
	timer.Simple(5, Install)
end)

timer.Simple(5, Install)

concommand.Add("jmod_spawncontrol_reload", function(ply)
	if IsValid(ply) and not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end

	Install()

	if IsValid(ply) then
		ply:PrintMessage(HUD_PRINTCONSOLE, "[JMod] Spawn control reloaded.")
	else
		print("[JMod] Spawn control reloaded.")
	end
end, nil, "Переустанавливает обёртки запрета спавна и AdvDupe2.")
