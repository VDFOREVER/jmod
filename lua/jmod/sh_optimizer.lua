--[[
	JMod Optimizer - общие настройки
	--------------------------------

	Этот файл загружается и на сервере, и на клиенте.

	Лимиты на спавн находятся в отдельном файле:
		lua/jmod/sv_spawn_limits.lua
]]

JMod = JMod or {}

JMod.Optimizer = {
	-- Главный выключатель оптимизаций (кроме лимитов на спавн).
	Enabled = true,

	-- ============================================================
	-- Ограничение газовых/дымовых партиклов
	-- ============================================================
	Particles = {
		Enabled = true,

		-- 0 = без ограничения.
		MaxGlobal = 250,
		MaxPerPlayer = 60,
		MaxPerClass = 120,

		-- Как часто проверять и удалять лишние партиклы (секунды).
		TrimInterval = 0.5,

		Classes = {
			["ent_jack_gmod_ezgasparticle"] = true,
			["ent_jack_gmod_ezcoparticle"] = true,
			["ent_jack_gmod_ezcsparticle"] = true,
			["ent_jack_gmod_ezexplosivegasparticle"] = true,
			["ent_jack_gmod_ezfalloutparticle"] = true,
			["ent_jack_gmod_ezvirusparticle"] = true
		}
	},

	-- ============================================================
	-- Ограничение долгих эффектов (огонь, лужи огня)
	-- ============================================================
	Effects = {
		Enabled = true,

		MaxGlobal = 120,
		MaxPerPlayer = 30,
		MaxPerClass = 80,

		TrimInterval = 0.5,

		-- Не добавляйте сюда ent_jack_gmod_eznapalm:
		-- это летящие снаряды, их удаление ломает урон.
		Classes = {
			["ent_jack_gmod_ezfirehazard"] = true,
			["ent_jack_gmod_ezoilfire"] = true
		}
	},

	-- ============================================================
	-- Автоматическая выдача владельца сущностям
	-- ============================================================
	Ownership = {
		Enabled = true,

		-- Периодическая проверка сущностей, у которых владелец
		-- не определился сразу после создания (секунды).
		RepairInterval = 15
	},

	-- ============================================================
	-- Клиентский рендер-куллинг
	-- ============================================================
	Render = {
		Enabled = true,

		-- Как часто пересчитывать дистанции (секунды).
		Interval = 0.4,

		-- Максимум спрайтов-заглушек за кадр.
		MaxPlaceholders = 150,

		-- Машины: дальше CullDistance модель не рисуется.
		Machines = {
			CullDistance = 4000,
			Placeholder = true,
			PlaceholderMaxDistance = 14000,
			PlaceholderMinSize = 10,
			PlaceholderMaxSize = 90,
			PlaceholderScale = 0.006,
			PlaceholderColor = Color(255, 255, 255, 90),
			PlaceholderMaterial = "sprites/glow04_noz"
		},

		-- Ресурсы/канистры.
		Resources = {
			CullDistance = 1800,
			Placeholder = false,
			PlaceholderMaxDistance = 5000,
			PlaceholderMinSize = 6,
			PlaceholderMaxSize = 30,
			PlaceholderScale = 0.004,
			PlaceholderColor = Color(255, 210, 80, 60),
			PlaceholderMaterial = "sprites/glow04_noz"
		},

		-- Газовые/дымовые партиклы.
		Particles = {
			CullDistance = 3000,
			Placeholder = false,
			PlaceholderMaxDistance = 6000,
			PlaceholderMinSize = 6,
			PlaceholderMaxSize = 30,
			PlaceholderScale = 0.004,
			PlaceholderColor = Color(120, 255, 120, 40),
			PlaceholderMaterial = "sprites/glow04_noz"
		},

		-- Огонь/опасные зоны.
		Effects = {
			CullDistance = 2500,
			Placeholder = false,
			PlaceholderMaxDistance = 5000,
			PlaceholderMinSize = 6,
			PlaceholderMaxSize = 30,
			PlaceholderScale = 0.004,
			PlaceholderColor = Color(255, 120, 40, 40),
			PlaceholderMaterial = "sprites/glow04_noz"
		}
	}
}
