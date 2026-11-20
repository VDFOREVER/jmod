--[[
	JMod Spawn Limits
	-----------------
	ОТДЕЛЬНЫЙ ФАЙЛ С НАСТРОЙКАМИ И ЛОГИКОЙ ЛИМИТОВ НА СПАВН.

	Ограничивает, сколько сущностей игрок может заспавнить из меню
	сущностей (Spawnmenu). Считаются все сущности данного класса,
	владельцем которых является игрок.

	Примеры:
		печка  — максимум 3;
		канистра топлива — максимум 3;
		всего машин — 20;
		всего ресурсов — 40.

	0 = без ограничения.
]]

if not SERVER then return end

JMod = JMod or {}

JMod.SpawnLimits = {
	Enabled = true,
	Notify = true,

	-- Не применять лимиты к админам.
	ExemptAdmins = false,

	-- Общие лимиты на игрока.
	MaxMachinesPerPlayer = 20,
	MaxResourcesPerPlayer = 40,

	-- Лимиты по умолчанию для классов, которых нет в таблицах ниже.
	MachineDefault = 4,
	ResourceDefault = 8,

	-- Минимальная пауза между сообщениями игроку (секунды).
	NotifyCooldown = 2,

	-- Удалять предмет, если крафт превысил лимит.
	-- ВНИМАНИЕ: ресурсы за крафт не возвращаются.
	EnforceCraftedLimits = false,

	-- Проверять лимиты после вставки из Duplicator.
	EnforcePastedLimits = false,

	Machines = {
		["ent_jack_gmod_ezfurnace"] = 3,
		["ent_jack_gmod_ezrefinery"] = 3,
		["ent_jack_gmod_ezpumpjack"] = 3,
		["ent_jack_gmod_ezoil_rig"] = 2,
		["ent_jack_gmod_ezaugerdrill"] = 3,
		["ent_jack_gmod_ezcentrifuge"] = 2,
		["ent_jack_gmod_ezfabricator"] = 2,
		["ent_jack_gmod_ezworkbench"] = 2,
		["ent_jack_gmod_ezprimitivebench"] = 2,
		["ent_jack_gmod_ezsentry"] = 3,
		["ent_jack_gmod_ezsfg"] = 2,
		["ent_jack_gmod_ezshieldgen"] = 2,
		["ent_jack_gmod_ezrtg"] = 3,
		["ent_jack_gmod_ezrtgs"] = 3,
		["ent_jack_gmod_ezgeothermalgenerator"] = 3,
		["ent_jack_gmod_ezsolargenerator"] = 5,
		["ent_jack_gmod_ezpowerbank"] = 5,
		["ent_jack_gmod_ezfieldhospital"] = 2,
		["ent_jack_gmod_ezaidradio"] = 2,
		["ent_jack_gmod_ezgroundscanner"] = 3,
		["ent_jack_gmod_ezlfg"] = 2,
		["ent_jack_gmod_ezsprinkler"] = 3,
		["ent_jack_gmod_ezwinch"] = 4,
		["ent_jack_gmod_ezfluid_bottler"] = 2,
		["ent_jack_gmod_ezhardpoint"] = 6,
		["ent_jack_gmod_ezbombbay"] = 4,
		["ent_jack_gmod_ezrocketpod"] = 4
	},

	Resources = {
		["ent_jack_gmod_ezfuel"] = 3,
		["ent_jack_gmod_ezgas"] = 3,
		["ent_jack_gmod_ezwater"] = 6,
		["ent_jack_gmod_ezoil"] = 4,
		["ent_jack_gmod_ezcoolant"] = 4,
		["ent_jack_gmod_ezbattery"] = 10,
		["ent_jack_gmod_ezammo"] = 10,
		["ent_jack_gmod_ezexplosives"] = 6,
		["ent_jack_gmod_ezpropellant"] = 6,
		["ent_jack_gmod_ezfissilematerial"] = 4,
		["ent_jack_gmod_ezantimatter"] = 4
	}
}

local Limits = JMod.SpawnLimits

if not Limits.Enabled then return end

local CATEGORY_MACHINE = "Machines"
local CATEGORY_RESOURCE = "Resources"
local WrappedSpawnFunctions = {}

local function IsPlayer(ply)
	return IsValid(ply) and ply:IsPlayer()
end

local function IsAdmin(ply)
	if not IsValid(ply) then return true end
	if ply:IsAdmin() or ply:IsSuperAdmin() then return true end
	if JMod and isfunction(JMod.IsAdmin) then return JMod.IsAdmin(ply) end

	return false
end

local function GetStoredEntTable(stored)
	if not stored then return nil end
	if istable(stored.t) then return stored.t end
	if istable(stored) then return stored end

	return nil
end

local function GetCategory(entityTable, class)
	if entityTable then
		if entityTable.IsJackyEZmachine or entityTable.Base == "ent_jack_gmod_ezmachine_base" then
			return CATEGORY_MACHINE
		end

		if entityTable.IsJackyEZresource or entityTable.Base == "ent_jack_gmod_ezresource" then
			return CATEGORY_RESOURCE
		end
	end

	if scripted_ents and isfunction(scripted_ents.IsBasedOn) then
		if scripted_ents.IsBasedOn(class, "ent_jack_gmod_ezmachine_base") then return CATEGORY_MACHINE end
		if scripted_ents.IsBasedOn(class, "ent_jack_gmod_ezresource") then return CATEGORY_RESOURCE end
	end

	if Limits.Machines[class] ~= nil then return CATEGORY_MACHINE end
	if Limits.Resources[class] ~= nil then return CATEGORY_RESOURCE end

	return nil
end

local function GetEntityName(class, ent)
	if IsValid(ent) and ent.PrintName then return ent.PrintName end

	if scripted_ents and isfunction(scripted_ents.GetStored) then
		local Table = GetStoredEntTable(scripted_ents.GetStored(class))
		if Table and Table.PrintName then return Table.PrintName end
	end

	return class
end

local function NormalizeLimit(value, default)
	if value == nil then value = default end
	if value == false then return 0 end
	if type(value) ~= "number" then return tonumber(value) or 0 end

	return value
end

local function GetClassLimit(class, category)
	if category == CATEGORY_MACHINE then
		return NormalizeLimit(Limits.Machines[class], Limits.MachineDefault)
	elseif category == CATEGORY_RESOURCE then
		return NormalizeLimit(Limits.Resources[class], Limits.ResourceDefault)
	end

	return 0
end

local function GetTotalLimit(category)
	if category == CATEGORY_MACHINE then
		return NormalizeLimit(Limits.MaxMachinesPerPlayer, 0)
	elseif category == CATEGORY_RESOURCE then
		return NormalizeLimit(Limits.MaxResourcesPerPlayer, 0)
	end

	return 0
end

local function NotifyPlayer(ply, text)
	if not Limits.Notify or not IsPlayer(ply) then return end

	local Now = CurTime()
	if (ply.JModSpawnLimitNextNotify or 0) > Now then return end

	ply.JModSpawnLimitNextNotify = Now + (Limits.NotifyCooldown or 2)
	ply:PrintMessage(HUD_PRINTTALK, "[JMod] " .. text)
end

local function CountOwnedClass(ply, class)
	local Count = 0

	for _, ent in ipairs(ents.FindByClass(class)) do
		if IsValid(ent) and JMod.GetEZowner(ent) == ply then
			Count = Count + 1
		end
	end

	return Count
end

local function CountOwnedCategory(ply, category)
	local Count = 0

	for _, ent in ipairs(ents.FindByClass("ent_jack_gmod_ez*")) do
		if IsValid(ent) and JMod.GetEZowner(ent) == ply then
			if GetCategory(ent, ent:GetClass()) == category then
				Count = Count + 1
			end
		end
	end

	return Count
end

local function CheckLimit(ply, class, category, isPostSpawn)
	if not IsPlayer(ply) or not category then return true end
	if not JMod or not isfunction(JMod.GetEZowner) then return true end
	if Limits.ExemptAdmins and IsAdmin(ply) then return true end

	local ClassLimit = GetClassLimit(class, category)
	local TotalLimit = GetTotalLimit(category)
	if ClassLimit <= 0 and TotalLimit <= 0 then return true end

	local ClassCount = CountOwnedClass(ply, class)
	local TotalCount = ClassCount

	if TotalLimit > 0 then
		TotalCount = CountOwnedCategory(ply, category)
	end

	local OverClass = false
	if ClassLimit > 0 then
		if isPostSpawn then
			OverClass = ClassCount > ClassLimit
		else
			OverClass = ClassCount >= ClassLimit
		end
	end

	local OverTotal = false
	if TotalLimit > 0 then
		if isPostSpawn then
			OverTotal = TotalCount > TotalLimit
		else
			OverTotal = TotalCount >= TotalLimit
		end
	end

	if not OverClass and not OverTotal then return true end

	if OverClass then
		NotifyPlayer(ply, string.format("Лимит: %s — максимум %d шт. (сейчас %d).", GetEntityName(class), ClassLimit, ClassCount))
	else
		local CategoryName = (category == CATEGORY_MACHINE) and "машин" or "ресурсов"
		NotifyPlayer(ply, string.format("Общий лимит %s — максимум %d шт. (сейчас %d).", CategoryName, TotalLimit, TotalCount))
	end

	return false
end

local function WrapSpawnFunction(class, entityTable)
	local Original = entityTable.SpawnFunction
	if not isfunction(Original) then return false end
	if WrappedSpawnFunctions[Original] then return false end

	local Wrapper = function(selfTable, ply, tr, classname)
		local ActualClass = classname or (selfTable and selfTable.ClassName) or class
		local Category = GetCategory(selfTable, ActualClass)

		if Category and not CheckLimit(ply, ActualClass, Category, false) then
			return nil
		end

		return Original(selfTable, ply, tr, classname)
	end

	WrappedSpawnFunctions[Original] = true
	entityTable.SpawnFunction = Wrapper

	return true
end

local function WrapAllSpawnFunctions()
	local Wrapped = 0

	if scripted_ents and isfunction(scripted_ents.GetList) then
		local EntityList = scripted_ents.GetList()

		if istable(EntityList) then
			for class, stored in pairs(EntityList) do
				local Table = GetStoredEntTable(stored)

				if Table and isfunction(Table.SpawnFunction) and GetCategory(Table, class) then
					if WrapSpawnFunction(class, Table) then Wrapped = Wrapped + 1 end
				end
			end
		end
	end

	if Wrapped == 0 and list and isfunction(list.Get) and scripted_ents and isfunction(scripted_ents.GetStored) then
		local Spawnables = list.Get("SpawnableEntities")

		if istable(Spawnables) then
			for class in pairs(Spawnables) do
				local Table = GetStoredEntTable(scripted_ents.GetStored(class))

				if Table and isfunction(Table.SpawnFunction) and GetCategory(Table, class) then
					if WrapSpawnFunction(class, Table) then Wrapped = Wrapped + 1 end
				end
			end
		end
	end
end

-- Основная проверка для Sandbox-меню: хук вызывается до создания сущности.
hook.Add("PlayerSpawnSENT", "JMod_SpawnLimitsPreSpawn", function(ply, class)
	local Category = GetCategory(nil, class)

	if Category and not CheckLimit(ply, class, Category, false) then
		return false
	end
end)

-- Страховка, если SpawnFunction не обернулась.
hook.Add("PlayerSpawnedSENT", "JMod_SpawnLimitsPostSpawn", function(ply, ent)
	if not IsValid(ent) or not IsPlayer(ply) then return end

	local Class = ent:GetClass()
	local Category = GetCategory(ent, Class)

	if Category and not CheckLimit(ply, Class, Category, true) then
		SafeRemoveEntity(ent)
	end
end)

hook.Add("InitPostEntity", "JMod_SpawnLimitsWrap", function()
	timer.Simple(1, WrapAllSpawnFunctions)
end)

hook.Add("OnReloaded", "JMod_SpawnLimitsWrapReload", function()
	timer.Simple(1, WrapAllSpawnFunctions)
end)

hook.Add("PlayerInitialSpawn", "JMod_SpawnLimitsWrapJoin", function()
	WrapAllSpawnFunctions()
end)

timer.Simple(5, WrapAllSpawnFunctions)

if Limits.EnforceCraftedLimits then
	hook.Add("JMod_OnRecipeCrafted", "JMod_SpawnLimitsCrafted", function(ply, craftEnt, ent)
		if not IsValid(ent) or not IsPlayer(ply) then return end

		local Class = ent:GetClass()
		local Category = GetCategory(ent, Class)

		if Category and not CheckLimit(ply, Class, Category, true) then
			SafeRemoveEntity(ent)
		end
	end)
end

if Limits.EnforcePastedLimits then
	hook.Add("OnPostEntityPaste", "JMod_SpawnLimitsPasted", function(ply, ent, createdEntities)
		if not IsPlayer(ply) or not istable(createdEntities) then return end

		for _, Created in ipairs(createdEntities) do
			if IsValid(Created) then
				local Class = Created:GetClass()
				local Category = GetCategory(Created, Class)

				if Category and not CheckLimit(ply, Class, Category, true) then
					SafeRemoveEntity(Created)
				end
			end
		end
	end)
end

concommand.Add("jmod_spawnlimits_status", function(ply)
	if not IsAdmin(ply) then return end

	local function Reply(text)
		if IsPlayer(ply) then
			ply:PrintMessage(HUD_PRINTCONSOLE, text)
		else
			print(text)
		end
	end

	Reply("=== JMod Spawn Limits ===")

	for _, target in ipairs(player.GetAll()) do
		local Machines = CountOwnedCategory(target, CATEGORY_MACHINE)
		local Resources = CountOwnedCategory(target, CATEGORY_RESOURCE)

		Reply(string.format("%s: машин %d / %d, ресурсов %d / %d", target:Nick(), Machines, NormalizeLimit(Limits.MaxMachinesPerPlayer, 0), Resources, NormalizeLimit(Limits.MaxResourcesPerPlayer, 0)))
	end
end, nil, "Показывает лимиты и текущее количество сущностей у игроков.")
