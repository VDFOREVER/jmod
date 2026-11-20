--[[
	JMod Builder Restrictions
	-------------------------
	Ограничения для игроков с ply:IsBuild().

	Что запрещено билдерам:
	* крафт в JMod-верстаках и через JMod-инструменты;
	* добыча ресурсов (кирка/лопата/скребок, scrounge);
	* разбор/снятие JMod-объектов и упаковка;
	* использование JMod-машин для крафта/добычи ресурсов.

	Дополнительно:
	* пропы, принадлежащие билдеру, нельзя разбирать/упаковывать
	  другим игрокам;
	* билдер не может разбирать чужие пропы (он вообще не может
	  разбирать JMod-объекты по правилу выше).

	Настройки ниже. Если на сервере нет ply:IsBuild(), ограничения
	просто не активируются.
]]

JMod = JMod or {}

JMod.BuilderRestrictions = {
	Enabled = true,
	Notify = true,
	NotifyCooldown = 2,

	-- Крафт в верстаках, фабрикаторе, на примитивном столе,
	-- через тулбокс и команду handcraft.
	BlockCrafting = true,

	-- Добыча ресурсов: кирка, лопата, скребок, scrounge,
	-- переработка/добыча на JMod-машинах.
	BlockResourceGathering = true,

	-- Разбор/снятие JMod-объектов, salvage, loosen, упаковка.
	BlockDismantling = true,

	-- Защита пропов, владельцем которых является билдер.
	ProtectBuilderProps = true,

	-- Команды JMod, которые нельзя использовать билдерам.
	BlockedCommands = {
		handcraft = true,
		scrounge = true
	},

	-- Машины, которые билдер не может использовать и которые
	-- не должны производить ресурсы, если принадлежат билдеру.
	BlockedMachines = {
		["ent_jack_gmod_ezworkbench"] = true,
		["ent_jack_gmod_ezfabricator"] = true,
		["ent_jack_gmod_ezprimitivebench"] = true,
		["ent_jack_gmod_ezaugerdrill"] = true,
		["ent_jack_gmod_ezoil_rig"] = true,
		["ent_jack_gmod_ezpumpjack"] = true,
		["ent_jack_gmod_ezfurnace"] = true,
		["ent_jack_gmod_ezrefinery"] = true,
		["ent_jack_gmod_ezcentrifuge"] = true,
		["ent_jack_gmod_ezfluid_bottler"] = true
	}
}

local C = JMod.BuilderRestrictions

local function ToBool(value)
	if type(value) == "number" then return value ~= 0 end
	return value and true or false
end

function JMod.IsBuilder(ply)
	if not SERVER then return false end
	if not IsValid(ply) or not ply:IsPlayer() then return false end

	if isfunction(ply.IsBuild) then
		return ToBool(ply:IsBuild())
	end

	if ply.IsBuild ~= nil then
		return ToBool(ply.IsBuild)
	end

	if isfunction(ply.IsBuilder) then
		return ToBool(ply:IsBuilder())
	end

	if ply.IsBuilder ~= nil then
		return ToBool(ply.IsBuilder)
	end

	return false
end

function JMod.IsBuilderProp(ent, depth)
	depth = depth or 0
	if depth > 4 or not SERVER or not IsValid(ent) then return false end

	-- Если владелец/создатель сейчас онлайн, всегда смотрим его ТЕКУЩУЮ роль.
	-- Это важно при смене профессии: старые пропы не должны оставаться
	-- "пропами билдера" после перехода в обычную профессию.
	if JMod.GetEZowner then
		local Owner = JMod.GetEZowner(ent)
		if IsValid(Owner) and Owner:IsPlayer() then
			local OwnerIsBuilder = JMod.IsBuilder(Owner)
			ent.JModBuilderOwned = OwnerIsBuilder or nil
			return OwnerIsBuilder
		end
	end

	if ent.GetCreator then
		local Creator = ent:GetCreator()
		if IsValid(Creator) and Creator:IsPlayer() then
			local CreatorIsBuilder = JMod.IsBuilder(Creator)
			ent.JModBuilderOwned = CreatorIsBuilder or nil
			return CreatorIsBuilder
		end
	end

	if ent.EZownerID and player and player.GetBySteamID64 then
		local IDOwner = player.GetBySteamID64(ent.EZownerID)
		if IsValid(IDOwner) and IDOwner:IsPlayer() then
			local IDOwnerIsBuilder = JMod.IsBuilder(IDOwner)
			ent.JModBuilderOwned = IDOwnerIsBuilder or nil
			return IDOwnerIsBuilder
		end
	end

	-- Владелец оффлайн: используем последнюю известную роль.
	if ent.JModBuilderOwned then return true end

	if ent.GetContents then
		local Contents = ent:GetContents()
		if IsValid(Contents) and Contents ~= ent and JMod.IsBuilderProp(Contents, depth + 1) then return true end
	end

	return false
end

function JMod.BuilderNotify(ply, message)
	if not (C.Enabled and C.Notify) then return end
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local Now = CurTime()
	if (ply.JModBuilderNotifyTime or 0) > Now then return end

	ply.JModBuilderNotifyTime = Now + (C.NotifyCooldown or 2)
	ply:PrintMessage(HUD_PRINTCENTER, "JMod: " .. (message or "Билдерам запрещено это действие"))
end

function JMod.RefreshBuilderOwnership(ply)
	if not SERVER or not IsValid(ply) or not ply:IsPlayer() then return end

	local NowBuilder = JMod.IsBuilder(ply)
	local ID = ply:SteamID64()
	local OwnerGetter = JMod.GetEZowner

	ply.JModLastBuilderState = NowBuilder

	for _, ent in ipairs(ents.GetAll()) do
		if IsValid(ent) then
			local Owner = OwnerGetter and OwnerGetter(ent)
			local CreatedBy = ent.GetCreator and ent:GetCreator()

			if Owner == ply or ent.EZownerID == ID or CreatedBy == ply then
				ent.JModBuilderOwned = NowBuilder or nil
			end
		end
	end
end

function JMod.CanCraft(ply)
	if not C.Enabled or not C.BlockCrafting then return true end
	if not JMod.IsBuilder(ply) then return true end

	return false, "Билдерам запрещено крафтить JMod-предметы"
end

function JMod.CanGatherResources(ply)
	if not C.Enabled or not C.BlockResourceGathering then return true end
	if not JMod.IsBuilder(ply) then return true end

	return false, "Билдерам запрещено добывать ресурсы"
end

function JMod.CanDismantle(ply, ent)
	if not C.Enabled then return true end

	if C.ProtectBuilderProps and JMod.IsBuilderProp(ent) then
		return false, "Нельзя разбирать собственность билдера"
	end

	if C.BlockDismantling and JMod.IsBuilder(ply) then
		return false, "Билдерам запрещено разбирать JMod-объекты"
	end

	return true
end

function JMod.CanUseMachine(ply, ent)
	if not C.Enabled then return true end
	if not C.BlockResourceGathering and not C.BlockCrafting then return true end
	if not IsValid(ent) then return true end
	if not C.BlockedMachines[ent:GetClass()] then return true end
	if not JMod.IsBuilder(ply) then return true end

	return false, "Билдерам запрещено использовать эту JMod-машину"
end

function JMod.CanUseCommand(ply, name)
	if not C.Enabled then return true end
	if name == "handcraft" and not C.BlockCrafting then return true end
	if name == "scrounge" and not C.BlockResourceGathering then return true end
	if not C.BlockedCommands[name] then return true end
	if not JMod.IsBuilder(ply) then return true end

	return false, "Билдерам запрещена эта JMod-команда"
end

function JMod.MachineBlockedForOwner(machine)
	if not C.Enabled or not C.BlockResourceGathering then return false end
	if not IsValid(machine) then return false end
	if not C.BlockedMachines[machine:GetClass()] then return false end

	return JMod.IsBuilder(JMod.GetEZowner and JMod.GetEZowner(machine))
end

if SERVER then
	hook.Add("PlayerUse", "JMod_BuilderMachineUse", function(ply, ent)
		if not IsValid(ent) then return end

		local Allowed, Message = JMod.CanUseMachine(ply, ent)
		if not Allowed then
			JMod.BuilderNotify(ply, Message)
			return false
		end
	end)

	local function RefreshAfterRoleChange(ply)
		timer.Simple(0.1, function()
			if IsValid(ply) then
				JMod.RefreshBuilderOwnership(ply)
			end
		end)
	end

	-- Покрываем популярные системы профессий/команд.
	local RoleChangeHooks = {
		"OnPlayerChangedTeam",
		"PlayerChangedTeam",
		"OnPlayerChangedJob",
		"PlayerChangedJob",
		"OnJobChanged",
		"PlayerJobChanged"
	}

	for _, HookName in ipairs(RoleChangeHooks) do
		hook.Add(HookName, "JMod_BuilderRoleRefresh_" .. HookName, RefreshAfterRoleChange)
	end

	hook.Add("PlayerSpawn", "JMod_BuilderRoleRefreshSpawn", function(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end

		local NowBuilder = JMod.IsBuilder(ply)
		if ply.JModLastBuilderState ~= NowBuilder then
			ply.JModLastBuilderState = NowBuilder
			JMod.RefreshBuilderOwnership(ply)
		end
	end)
end
