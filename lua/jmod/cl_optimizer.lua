--[[
	JMod Optimizer - клиентский рендер-куллинг
	-----------------------------------------

	Далёкие машины, ресурсы, партиклы и эффекты перестают рисоваться.
	Для машин вместо модели можно рисовать лёгкий спрайт-маркер.

	Настройки: lua/jmod/sh_optimizer.lua
]]

if not CLIENT then return end

if not (JMod and JMod.Optimizer) then
	include("jmod/sh_optimizer.lua")
end

local CATEGORIES = {"Machines", "Resources", "Particles", "Effects"}
local Tracked = {
	Machines = {},
	Resources = {},
	Particles = {},
	Effects = {}
}

local PlaceholderMats = {}
local CachedRender
local ParticleClasses = {}
local EffectClasses = {}
local NextScan = 0

local function RefreshConfig()
	local Config = JMod and JMod.Optimizer
	local R = Config and Config.Enabled and Config.Render

	if not R or not R.Enabled then return nil end

	if CachedRender ~= R then
		CachedRender = R
		ParticleClasses = (Config.Particles and Config.Particles.Classes) or {}
		EffectClasses = (Config.Effects and Config.Effects.Classes) or {}
	end

	return R
end

local function GetPlaceholderMaterial(Cfg)
	local Path = Cfg.PlaceholderMaterial or "sprites/glow04_noz"

	if not PlaceholderMats[Path] then
		PlaceholderMats[Path] = Material(Path)
	end

	return PlaceholderMats[Path]
end

local function GetCategory(ent)
	local Class = ent:GetClass()

	if ent.IsJackyEZmachine then return "Machines" end
	if ent.IsJackyEZresource then return "Resources" end
	if ParticleClasses[Class] then return "Particles" end
	if EffectClasses[Class] then return "Effects" end

	return nil
end

local function SetEntityHiddenState(ent, ShouldHide)
	-- Сущности в инвентаре JMod уже скрыты, их нельзя трогать.
	local InventoryOwner = ent:GetNW2Entity("EZInvOwner", NULL)
	if IsValid(InventoryOwner) then
		ent.JModOptimizerHidden = false
		ent.JModOptimizerManaged = nil
		return
	end

	-- Не трогаем сущности, которые уже скрыты самим JMod/движком.
	if not ent.JModOptimizerManaged then
		if ent:GetNoDraw() then
			ent.JModOptimizerHidden = false
			return
		end

		ent.JModOptimizerManaged = true
	end

	if ent:GetNoDraw() ~= ShouldHide then
		ent:SetNoDraw(ShouldHide)
	end

	ent.JModOptimizerHidden = ShouldHide
end

local function ScanEntities(R)
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	for _, Category in ipairs(CATEGORIES) do
		Tracked[Category] = {}
	end

	local EyePosition = EyePos()

	for _, ent in ipairs(ents.FindByClass("ent_jack_gmod_ez*")) do
		if IsValid(ent) then
			local Category = GetCategory(ent)

			if Category then
				local Cfg = R[Category]
				local CullDistance = Cfg and tonumber(Cfg.CullDistance) or 0

				if CullDistance and CullDistance > 0 then
					Tracked[Category][#Tracked[Category] + 1] = ent

					local ShouldHide = ent:GetPos():DistToSqr(EyePosition) > (CullDistance * CullDistance)
					SetEntityHiddenState(ent, ShouldHide)
				end
			end
		end
	end
end

local function DrawPlaceholders()
	local R = RefreshConfig()
	if not R then return end

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local Drawn = 0
	local EyePosition = EyePos()

	for _, Category in ipairs(CATEGORIES) do
		local Cfg = R[Category]

		if Cfg and Cfg.Placeholder then
			local MaxDistance = tonumber(Cfg.PlaceholderMaxDistance) or 0

			if MaxDistance > 0 then
				local Mat = GetPlaceholderMaterial(Cfg)
				local MinSize = tonumber(Cfg.PlaceholderMinSize) or 8
				local MaxSize = tonumber(Cfg.PlaceholderMaxSize) or 100
				local Scale = tonumber(Cfg.PlaceholderScale) or 0.005
				local SpriteColor = Cfg.PlaceholderColor or Color(255, 255, 255, 80)

				render.SetMaterial(Mat)

				for _, ent in ipairs(Tracked[Category]) do
					if IsValid(ent) and ent.JModOptimizerHidden then
						local Pos = ent:GetPos()
						local Distance = Pos:Distance(EyePosition)

						if Distance <= MaxDistance then
							local Size = math.Clamp(Distance * Scale, MinSize, MaxSize)
							render.DrawSprite(Pos, Size, Size, SpriteColor)

							Drawn = Drawn + 1
							if Drawn >= (tonumber(R.MaxPlaceholders) or 150) then return end
						end
					end
				end
			end
		end
	end
end

hook.Add("PostDrawTranslucentRenderables", "JMod_OptimizerDrawPlaceholders", function(bDrawingDepth, bSkybox)
	if bDrawingDepth or bSkybox then return end
	DrawPlaceholders()
end)

timer.Create("JMod_OptimizerClientCull", 0.1, 0, function()
	local R = RefreshConfig()
	if not R then return end

	local Now = CurTime()
	if Now < NextScan then return end

	NextScan = Now + math.max(tonumber(R.Interval) or 0.4, 0.1)
	ScanEntities(R)
end)

concommand.Add("jmod_optimizer_render_status", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local Total = 0
	local Hidden = 0

	for _, Category in ipairs(CATEGORIES) do
		local CategoryHidden = 0

		for _, ent in ipairs(Tracked[Category]) do
			if IsValid(ent) then
				Total = Total + 1
				if ent.JModOptimizerHidden then
					Hidden = Hidden + 1
					CategoryHidden = CategoryHidden + 1
				end
			end
		end

		ply:PrintMessage(HUD_PRINTCONSOLE, string.format("[JMod Optimizer] %s: %d (скрыто %d)", Category, #Tracked[Category], CategoryHidden))
	end

	ply:PrintMessage(HUD_PRINTCONSOLE, string.format("[JMod Optimizer] Всего: %d, скрыто: %d", Total, Hidden))
end, nil, "Показывает статистику клиентского рендер-оптимизатора.")
