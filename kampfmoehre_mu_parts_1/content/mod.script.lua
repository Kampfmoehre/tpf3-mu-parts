-- Buyable Multiple Unit Parts for Transport Fever 3.
--
-- The depot's vehicle list drops every vehicle whose transportVehicle.filterTags
-- is empty (vehicle_store_util.depotMatchesVehicleFilterTags: "filter out any
-- vehicles that have NO filterTags set"). Parts that exist only inside a
-- multiple-unit set (power cars, buffet/special coaches) ship with empty
-- filterTags, ordinary coaches with { "default" }. This mod gives the set parts
-- the tags of their set after all resources are loaded (postRunFn), using the
-- same model table API the official campaign mods use
-- (api.res.modelRep.getAsTable / setAsTable).
--
-- Mod parameters: one Off/On switch per base-game set (key "set_<id>", values
-- from allModParams are 1-based: 1 = Off, 2 = On) plus "set_other" for every
-- multiple unit not listed here (vehicle mods).

local KNOWN_SETS = {
	["::/vehicle/train/avelia_liberty/avelia_liberty.mu"] = "avelia_liberty",
	["::/vehicle/train/emd_f/emd_f.mu"] = "emd_f",
	["::/vehicle/train/es1_lastochka/es1_lastochka.mu"] = "es1_lastochka",
	["::/vehicle/train/fs_etr_450/etr_450.mu"] = "fs_etr_450",
	["::/vehicle/train/fuxing_hao/fuxing_hao.mu"] = "fuxing_hao",
	["::/vehicle/train/hst_125/hst_125.mu"] = "hst_125",
	["::/vehicle/train/ice1/ice1.mu"] = "ice1",
	["::/vehicle/train/metroliner/metroliner.mu"] = "metroliner",
	["::/vehicle/train/re_450/re_450.mu"] = "re_450",
	["::/vehicle/train/shaoshan_4g/shaoshan_4g.mu"] = "shaoshan_4g",
	["::/vehicle/train/shinkansen_0s/shinkansen_0s.mu"] = "shinkansen_0s",
	["::/vehicle/train/tgv_duplex/tgv_duplex.mu"] = "tgv_duplex",
	["::/vehicle/train/twindexx/twindexx.mu"] = "twindexx",
}

-- "::/vehicle/train/x/x.mu" + "x_front.mdl" -> "::/vehicle/train/x/x_front.mdl"
local function resolveModelName(muPath, name)
	if type(name) ~= "string" then return nil end
	if name:sub(1, 3) == "::/" or name:find("::/", 1, true) then
		return name
	end
	local dir = muPath:match("^(.*/)[^/]*$") or ""
	return dir .. name
end

-- "::/vehicle/train/hst_125/hst_125_middle2.mdl" with set "hst_125" -> "middle2"
local function partRole(modelName, muPath)
	local base = (modelName:match("([^/]+)%.mdl$") or modelName)
	local setBase = (muPath:match("([^/]+)%.mu$") or "")
	if setBase ~= "" and base:sub(1, #setBase + 1) == setBase .. "_" then
		return base:sub(#setBase + 2)
	end
	return base
end

-- Returns true if the model was changed.
local function unlock(modelName, tags, role)
	local id = api.res.modelRep.find(modelName)
	if id == nil or id < 0 then
		print("[mu_parts] model not found: " .. tostring(modelName))
		return false
	end
	local model = api.res.modelRep.getAsTable(id)
	local tv = model and model.metadata and model.metadata.transportVehicle
	if not tv then
		return false
	end
	if type(tv.filterTags) == "table" and #tv.filterTags > 0 then
		return false -- already buyable on its own
	end
	local newTags = {}
	for _, t in ipairs(tags or {}) do newTags[#newTags + 1] = t end
	if #newTags == 0 then newTags[1] = "default" end
	tv.filterTags = newTags

	-- set parts often share the display name with their set or with each
	-- other; add the part's role from the file name to tell them apart
	local desc = model.metadata.description
	if type(desc) == "table" and type(desc.name) == "string" and role and role ~= "" then
		desc.name = desc.name .. " (" .. role .. ")"
	end

	api.res.modelRep.setAsTable(id, model)
	return true
end

function data()
	local mod = {}

	mod.postRunFn = function(captureParams, configDict, allModParams, baseConfig)
		local params = (allModParams and allModParams[getCurrentModId()]) or {}
		local function enabled(muPath)
			local key = KNOWN_SETS[muPath]
			if key then
				return params["set_" .. key] == 2
			end
			return params.set_other == 2
		end

		local count, sets = 0, 0
		for muId, _ in pairs(api.res.multipleUnitRep.getAll()) do
			local muPath = api.res.multipleUnitRep.getName(muId)
			if enabled(muPath) then
				local ok, mu = pcall(api.res.multipleUnitRep.get, muId)
				if ok and mu and mu.vehicles then
					sets = sets + 1
					local seen = {}
					for _, v in ipairs(mu.vehicles) do
						local modelName = resolveModelName(muPath, v.name)
						if modelName and not seen[modelName] then
							seen[modelName] = true
							local okU, changed = pcall(unlock, modelName, mu.filterTags, partRole(modelName, muPath))
							if okU and changed then
								count = count + 1
								print("[mu_parts] made buyable: " .. modelName)
							elseif not okU then
								print("[mu_parts] failed for " .. tostring(modelName) .. ": " .. tostring(changed))
							end
						end
					end
				end
			end
		end
		print(string.format("[mu_parts] %d sets enabled, %d set-only vehicle models made buyable", sets, count))
	end

	return mod
end
