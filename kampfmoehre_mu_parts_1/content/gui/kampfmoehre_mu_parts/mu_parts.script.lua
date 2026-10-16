-- Buyable Multiple Unit Parts: show unlocked parts as variants of their set.
--
-- The vehicle store groups vehicles by vehicleData.variantGroup (the model's
-- transportVehicle.groupFileName): a vehicle whose variantGroup is the path of
-- another store entry leaves the flat list and appears under that entry, which
-- gets an expand arrow (vehicle_store_window.tl, VehicleStoreEntryPoint builds
-- variantGroup2muAndVariants once from vehicle_store_util.makeVehicleData).
--
-- The engine only accepts a model path in a model's groupFileName, so
-- mod.script.lua marks every unlocked part with the path of the first unlocked
-- part of its set. Here we recognise that marker (groupFileName names a model of
-- the same set) and replace the variant group with the set's own .mu path, so
-- the set heads the group. Hooks, all on the shared vehicle_store_util table:
--  * makeVehicleData(repId, false): variantGroup -> path of the set.
--  * getPrimaryBucket(elemStatic): parts sort after their set, in set order.
--  * getVehicleNameAndIcons(repId, false, ...): parts share the name of their
--    set ("ICE 1"), so a role is appended: "power car" (engine, no capacity),
--    "end car" (first/last in the set) or "middle car", numbered when a set has
--    several parts with the same role. (Changing description.name in
--    mod.script.lua has no effect, the store shows the translated name key.)
--  * vehicleFilter(elemStatic, filterParams, filter): in the "Multiple Unit"
--    tab (withEngine and withCapacity both true) parts are checked without the
--    engine/capacity conditions, so unpowered coaches show up under their set.

function data()
	local VERSION = "0.3.3"

	local react = ug_require "::/gui/main/react.lua"
	local builtin = ug_require "::/gui/main/builtin.lua"
	local vehicle_store_util = ug_require "::/gui/line_vehicle_mgmt/vehicle_store_util.tl"

	-- The hooks are installed once per session and outlive this data() call, so
	-- their state lives on the shared builtin table.
	-- state.partToSet: model id -> path of the set (.mu) for every marked part
	-- state.partLabel: model id -> role label, filled per set on first use
	-- state.partRank: model id -> position of the part in its set (1 = first)
	if not builtin._kampfmoehreMuParts then
		builtin._kampfmoehreMuParts = { partToSet = nil, partLabel = {}, partRank = {} }
	end
	local state = builtin._kampfmoehreMuParts

	local function groupFileNameOf(modelId)
		local model = api.res.modelRep.get(modelId)
		local tv = model and model.metadata and model.metadata["transportVehicle"]
		local group = tv and tv.groupFileName
		if type(group) == "string" and group ~= "" then
			return group
		end
		return nil
	end

	local function buildPartToSet()
		local map = {}
		for muId, __ in pairs(api.res.multipleUnitRep.getAll()) do
			local muPath = api.res.multipleUnitRep.getName(muId)
			local mu = api.res.multipleUnitRep.get(muId)
			local ids = {}
			for __, v in ipairs(mu.vehicles) do
				local id = api.res.modelRep.find(v.name)
				if id ~= nil and id >= 0 then ids[id] = true end
			end
			for id, __ in pairs(ids) do
				local group = groupFileNameOf(id)
				if group then
					local groupId = api.res.modelRep.find(group)
					if groupId ~= nil and ids[groupId] and map[id] == nil then
						map[id] = muPath
					end
				end
			end
		end
		return map
	end

	-- Path of the set a marked part belongs to, nil for every other model. The
	-- marker is checked on the model itself, so a map built for a savegame with
	-- other mod params cannot group a part that is no longer marked; a marked
	-- part missing from the map triggers a rebuild.
	local function setOfPart(modelId)
		if not groupFileNameOf(modelId) then
			return nil
		end
		if state.partToSet == nil or state.partToSet[modelId] == nil then
			local ok, map = pcall(buildPartToSet)
			if not ok then
				log.warning("[kampfmoehre_mu_parts] building the part list failed: " .. tostring(map))
				map = {}
			end
			-- remember misses, so other models with a groupFileName (variants
			-- from vehicle mods) do not rebuild the map on every call
			for id, v in pairs(state.partToSet or {}) do
				if v == false and map[id] == nil then map[id] = false end
			end
			if map[modelId] == nil then map[modelId] = false end
			state.partToSet = map
			state.partLabel = {}
				state.partRank = {}
			local count = 0
			for __, v in pairs(map) do if v then count = count + 1 end end
			log.message("[kampfmoehre_mu_parts] " .. count .. " parts grouped under their set")
		end
		return state.partToSet[modelId] or nil
	end

	local function hasEngine(model)
		local lv = model.metadata["landVehicle"]
		if not lv then return false end
		for __ in ipairs(lv.engines) do return true end
		return false
	end

	local function hasCapacity(model)
		local tv = model.metadata["transportVehicle"]
		for __, compartment in ipairs(tv.compartments) do
			for __, loadConfig in ipairs(compartment.loadConfigs) do
				if loadConfig.cargoEntry.capacity > 0 then return true end
			end
		end
		return false
	end

	-- Fills state.partLabel and state.partRank for all marked parts of the set
	-- at setPath.
	local function labelSet(setPath)
		local mu = api.res.multipleUnitRep.get(api.res.multipleUnitRep.find(setPath))
		local order, info = {}, {}
		local last = #mu.vehicles
		for i, v in ipairs(mu.vehicles) do
			local id = api.res.modelRep.find(v.name)
			if id ~= nil and id >= 0 and setOfPart(id) == setPath then
				if not info[id] then
					info[id] = { isEnd = false }
					order[#order + 1] = id
				end
				if i == 1 or i == last then info[id].isEnd = true end
			end
		end
		local roleCount = {}
		for __, id in ipairs(order) do
			local model = api.res.modelRep.get(id)
			local role
			if hasEngine(model) and not hasCapacity(model) then
				role = "mu_parts_role_power_car"
			elseif info[id].isEnd then
				role = "mu_parts_role_end_car"
			else
				role = "mu_parts_role_middle_car"
			end
			info[id].role = role
			roleCount[role] = (roleCount[role] or 0) + 1
		end
		local roleIndex = {}
		for rank, id in ipairs(order) do
			state.partRank[id] = rank
			local role = info[id].role
			local label = _(role)
			if roleCount[role] > 1 then
				roleIndex[role] = (roleIndex[role] or 0) + 1
				label = label .. " " .. roleIndex[role]
			end
			state.partLabel[id] = label
		end
	end

	local function labelOfPart(modelId)
		local setPath = setOfPart(modelId)
		if not setPath then return nil end
		if state.partLabel[modelId] == nil then
			labelSet(setPath)
		end
		return state.partLabel[modelId]
	end

	if not builtin._kampfmoehreMuPartsHooked then
		builtin._kampfmoehreMuPartsHooked = true

		local origMakeVehicleData = vehicle_store_util.makeVehicleData
		vehicle_store_util.makeVehicleData = function(repId, multipleUnit, ...)
			local result = origMakeVehicleData(repId, multipleUnit, ...)
			if not multipleUnit and type(result) == "table" then
				local ok, setPath = pcall(setOfPart, repId)
				if ok and setPath then
					result.variantGroup = setPath
				end
			end
			return result
		end

		local origVehicleFilter = vehicle_store_util.vehicleFilter
		vehicle_store_util.vehicleFilter = function(elemStatic, filterParams, filter, ...)
			if filter and filter.withEngine == true and filter.withCapacity == true
				and elemStatic and not elemStatic.multipleUnit and elemStatic.isVariant then
				local ok, setPath = pcall(setOfPart, elemStatic.repId)
				if ok and setPath then
					local relaxed = {}
					for k, v in pairs(filter) do relaxed[k] = v end
					relaxed.withEngine = nil
					relaxed.withCapacity = nil
					relaxed.engines = {}
					return origVehicleFilter(elemStatic, filterParams, relaxed, ...)
				end
			end
			return origVehicleFilter(elemStatic, filterParams, filter, ...)
		end

		-- The store sorts by getPrimaryBucket first (no capacity < passengers <
		-- passengers+cargo < cargo), also inside an expanded group, so a power car
		-- would come before its set. Parts only show up inside their group (and in
		-- the table layout), so a bucket after all others keeps the set first.
		-- Parts of one set share year, name etc.; ties leave table.sort's order
		-- random, so each part gets its own bucket by its position in the set.
		local bucketCache = setmetatable({}, { __mode = "k" }) -- elemStatic -> number|false
		local origPrimaryBucket = vehicle_store_util.getPrimaryBucket
		vehicle_store_util.getPrimaryBucket = function(elem, ...)
			if type(elem) == "table" and not elem.multipleUnit then
				local bucket = bucketCache[elem]
				if bucket == nil then
					local ok, label = pcall(labelOfPart, elem.repId)
					bucket = (ok and label) and (5 + (state.partRank[elem.repId] or 999) / 1000) or false
					bucketCache[elem] = bucket
				end
				if bucket then
					return bucket
				end
			end
			return origPrimaryBucket(elem, ...)
		end

		local origNameAndIcons = vehicle_store_util.getVehicleNameAndIcons
		vehicle_store_util.getVehicleNameAndIcons = function(repId, multipleUnit, ...)
			local result = origNameAndIcons(repId, multipleUnit, ...)
			if not multipleUnit and type(result) == "table" and type(result.name) == "string" then
				local ok, label = pcall(labelOfPart, repId)
				if ok and label then
					result.name = result.name .. " (" .. label .. ")"
					if type(result.names) == "table" and #result.names == 1 then
						result.names[1] = result.name
					end
				elseif not ok then
					log.warning("[kampfmoehre_mu_parts] label failed: " .. tostring(label))
				end
			end
			return result
		end

		log.message("[kampfmoehre_mu_parts] v" .. VERSION .. " hooks installed")
	end

	local M = {}
	M.EntryPlugin = react.RegisterPluginRecipe(
		{ id = "::ModEntryPointExtension" }, "KampfmoehreMuPartsEntry",
		function()
			react.onMount(function()
				-- mod params may differ from the previous savegame
				state.partToSet = nil
				state.partLabel = {}
				state.partRank = {}
			end)
			return builtin.BoxLayout{ children = {} }
		end)
	return M
end
