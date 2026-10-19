-- Tests for hero-turret-restock, run with FactorioTest (see AutoTest/README.md in the author's workspace).
-- Loaded only when the factorio-test mod is active; never runs in a normal game.
--
-- Everything happens on an own lab surface and an own force, so a press never touches turrets of the save the
-- tests run on (restock() scans every surface, but only for the force it is given).

local FORCE = "htr-test"
local surface, force

local function ranked(rank)
	return rank == 0 and "gun-turret" or ("hero-turret-" .. rank .. "-for-gun-turret")
end

local function press()
	return remote.call("hero-turret-restock", "restock", FORCE)
end

local created = {}
local function create(name, position, extra)
	local spec = { name = name, position = position, force = force }
	for k, v in pairs(extra or {}) do
		spec[k] = v
	end
	local e = surface.create_entity(spec)
	assert(e, "could not create " .. name .. " at " .. serpent.line(position))
	created[#created + 1] = e
	return e
end

-- Roboport at the origin with a storage chest holding `stock` ({[item] = count}), no power and no robots.
local function network(stock)
	create("roboport", { 0, 0 })
	local chest = create("storage-chest", { 3.5, 3.5 })
	for item, count in pairs(stock) do
		chest.insert({ name = item, count = count })
	end
	return chest
end

before_all(function()
	assert(script.active_mods["HeroTurretRedux"] or script.active_mods["HeroTurretsReduxFork"], "needs a hero turret mod")
	assert(prototypes.entity[ranked(3)], "hero turret ranks missing")
	surface = game.create_surface("htr-test")
	surface.generate_with_lab_tiles = true
	surface.request_to_generate_chunks({ 0, 0 }, 3)
	surface.force_generate_chunk_requests()
	force = game.create_force(FORCE)
end)

after_all(function()
	game.delete_surface(surface)
	game.merge_forces(FORCE, "neutral")
end)

after_each(function()
	for _, e in pairs(created) do
		if e.valid then
			e.destroy()
		end
	end
	created = {}
	for _, e in pairs(surface.find_entities_filtered({ force = force })) do
		e.destroy()
	end
end)

describe("pairing", function()
	test("lowest placed turret gets the highest stock rank", function()
		network({ [ranked(3)] = 1 })
		local plain = create("gun-turret", { 10, 0 })
		local rank1 = create(ranked(1), { 12, 0 })
		assert(press() == 1, "expected 1 turret marked")
		assert(plain.to_be_upgraded(), "rank 0 turret not marked")
		assert(plain.get_upgrade_target().name == ranked(3), "wrong upgrade target " .. plain.get_upgrade_target().name)
		assert(not rank1.to_be_upgraded(), "rank 1 turret marked although the plain one is lower")
	end)

	test("best stock goes to worst placed, one item per turret", function()
		network({ [ranked(3)] = 1, [ranked(2)] = 1 })
		local plain = create("gun-turret", { 10, 0 })
		local rank1 = create(ranked(1), { 12, 0 })
		local rank2 = create(ranked(2), { 14, 0 })
		assert(press() == 2, "expected 2 turrets marked")
		assert(plain.get_upgrade_target().name == ranked(3), "plain turret should get rank 3")
		assert(rank1.get_upgrade_target().name == ranked(2), "rank 1 turret should get rank 2")
		assert(not rank2.to_be_upgraded(), "rank 2 turret marked")
	end)

	test("among equal ranks the turret with more kills goes first", function()
		network({ [ranked(2)] = 1 })
		local idle = create("gun-turret", { 10, 0 })
		local fighter = create("gun-turret", { 12, 0 })
		fighter.kills = 1
		assert(press() == 1, "expected 1 turret marked")
		assert(fighter.to_be_upgraded() and not idle.to_be_upgraded(), "the turret with kills should be upgraded")
	end)

	test("stock that does not outrank anything is left alone", function()
		network({ [ranked(1)] = 3 })
		create(ranked(2), { 10, 0 })
		create(ranked(1), { 12, 0 })
		assert(press() == 0, "nothing should be marked")
	end)

	test("pressing twice does not mark more than the stock", function()
		network({ [ranked(2)] = 1 })
		create("gun-turret", { 10, 0 })
		create("gun-turret", { 12, 0 })
		assert(press() == 1, "first press should mark 1")
		assert(press() == 0, "second press should mark 0: the item is reserved by the first order")
	end)

	test("turrets outside every construction area are ignored", function()
		network({ [ranked(2)] = 1 })
		local far = create("gun-turret", { 200, 0 })
		assert(press() == 0, "nothing should be marked")
		assert(not far.to_be_upgraded(), "far turret marked")
	end)

	local quality_test = prototypes.quality["uncommon"] and test or test.skip
	quality_test("stock of another quality is not used", function()
		local chest = network({})
		chest.insert({ name = ranked(2), count = 1, quality = "uncommon" })
		local plain = create("gun-turret", { 10, 0 })
		assert(press() == 0, "uncommon stock must not upgrade a normal turret")
		assert(not plain.to_be_upgraded(), "normal turret marked")
	end)
end)

describe("robots", function()
	test("construction robots carry out the upgrade and bring the plain turret back", function()
		create("electric-energy-interface", { -4, 0 })
		create("medium-electric-pole", { -2, 0 })
		local roboport = create("roboport", { 0, 0 })
		roboport.get_inventory(defines.inventory.roboport_robot).insert({ name = "construction-robot", count = 10 })
		local chest = create("storage-chest", { 3.5, 3.5 })
		chest.insert({ name = ranked(3), count = 1 })
		create("gun-turret", { 10, 0 })
		assert(press() == 1, "expected 1 turret marked")

		async(60 * 60)
		local ticks = 0
		on_tick(function()
			-- type filter: other mods put helper entities on turrets (ammo-loader adds a hidden inserter)
			local turret = surface.find_entities_filtered({ position = { 10, 0 }, radius = 1.5, force = force, type = "ammo-turret" })[1]
			ticks = ticks + 1
			if ticks % 600 == 0 then -- shown only if the test fails
				local net = roboport.logistic_network
				print(string.format(
					"t+%d turret=%s marked=%s robots=%s/%s roboport energy=%.0f stock=%s",
					ticks, turret and turret.name or "none", tostring(turret and turret.to_be_upgraded()),
					net and net.available_construction_robots or "-", net and net.all_construction_robots or "-",
					roboport.energy, serpent.line(chest.get_inventory(defines.inventory.chest).get_contents())))
			end
			if turret and turret.name == ranked(3) and chest.get_item_count("gun-turret") == 1 then
				assert(chest.get_item_count(ranked(3)) == 0, "rank 3 item still in stock")
				done()
				return false
			end
		end)
	end)
end)
