-- Ranked hero turrets that were picked up end up as items in logistic storage. The button hands them back to the
-- wall: per logistic network, base turret and quality, the highest ranks in stock are paired with the lowest-ranked
-- placed turrets, and each pair where the stock outranks the placed turret is marked for upgrade. Construction
-- robots do the swap, so nothing is destroyed by script and the replaced turret returns to storage as an item.
-- Pairing best stock with worst placed means a replaced turret never outranks what is left in stock: the wall
-- ends up holding the best turrets and the stock ends up plain as far as the numbers allow.

local TURRET_TYPES = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret"}

local function parse(name)
  local rank, base = name:match("^hero%-turret%-(%d+)%-for%-(.+)$")
  if rank then return base, tonumber(rank) end
  return name, 0
end

local function ranked_name(base, rank)
  return "hero-turret-" .. rank .. "-for-" .. base
end

-- First stationary network whose construction area covers the turret (walls are rarely inside the logistic area).
local function home_network(entity, is_static)
  for _, network in pairs(entity.surface.find_logistic_networks_by_construction_area(entity.position, entity.force)) do
    local id = entity.surface.index .. ":" .. network.network_id
    if is_static[id] == nil then
      local cell = network.cells[1]
      is_static[id] = (cell ~= nil and not cell.mobile)
    end
    if is_static[id] then return network, id end
  end
end

local function restock(force, player)
  local nets, is_static = {}, {}

  for _, surface in pairs(game.surfaces) do
    for _, e in pairs(surface.find_entities_filtered{type = TURRET_TYPES, force = force}) do
      local base, rank = parse(e.name)
      if prototypes.entity[ranked_name(base, 1)] and not e.to_be_deconstructed() then
        local network, id = home_network(e, is_static)
        if network then
          local net = nets[id]
          if not net then net = {network = network, groups = {}}; nets[id] = net end
          local key = base .. "/" .. e.quality.name
          local g = net.groups[key]
          if not g then g = {base = base, quality = e.quality.name, placed = {}, reserved = {}}; net.groups[key] = g end
          if e.to_be_upgraded() then
            -- an earlier press already promised one item of that rank to this turret
            local target = e.get_upgrade_target()
            local tbase, trank = parse(target.name)
            if tbase == base and trank > 0 then g.reserved[trank] = (g.reserved[trank] or 0) + 1 end
          else
            g.placed[#g.placed + 1] = {entity = e, rank = rank, kills = e.kills, unit = e.unit_number}
          end
        end
      end
    end
  end

  local marked, leftover = {}, {}   -- [base][rank] = count
  local total = 0
  for _, net in pairs(nets) do
    local stock = {}   -- [group key][rank] = count
    for _, item in pairs(net.network.get_contents()) do
      local place = prototypes.item[item.name].place_result
      if place then
        local base, rank = parse(place.name)
        if rank > 0 then
          local key = base .. "/" .. item.quality
          stock[key] = stock[key] or {}
          stock[key][rank] = (stock[key][rank] or 0) + item.count
        end
      end
    end

    for key, g in pairs(net.groups) do
      local ranks = {}
      for rank, count in pairs(stock[key] or {}) do
        local free = count - (g.reserved[rank] or 0)
        if free > 0 then ranks[#ranks + 1] = {rank = rank, count = free} end
      end
      table.sort(ranks, function(a, b) return a.rank > b.rank end)
      -- lowest rank first; among equals the turret that fights the most gets the better replacement
      table.sort(g.placed, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.kills ~= b.kills then return a.kills > b.kills end
        return a.unit < b.unit
      end)

      local i = 1
      for _, s in ipairs(ranks) do
        while s.count > 0 do
          local p = g.placed[i]
          if not p or p.rank >= s.rank then break end
          i = i + 1
          if p.entity.order_upgrade{target = {name = ranked_name(g.base, s.rank), quality = g.quality}, force = force, player = player} then
            s.count = s.count - 1
            total = total + 1
            marked[g.base] = marked[g.base] or {}
            marked[g.base][s.rank] = (marked[g.base][s.rank] or 0) + 1
          end
        end
        if s.count > 0 then leftover[g.base] = (leftover[g.base] or 0) + s.count end
      end
    end
  end

  local function say(msg)
    if player then player.print(msg) end
  end
  for base, by_rank in pairs(marked) do
    local n, parts = 0, {}
    for rank = 12, 1, -1 do
      if by_rank[rank] then
        n = n + by_rank[rank]
        parts[#parts + 1] = by_rank[rank] .. " x rank " .. rank
      end
    end
    say({"htr.line", prototypes.entity[base].localised_name, n, table.concat(parts, ", ")})
    log("[HTR] " .. base .. ": " .. n .. " marked (" .. table.concat(parts, ", ") .. ")")
  end
  for base, n in pairs(leftover) do
    say({"htr.leftover", prototypes.entity[base].localised_name, n})
    log("[HTR] " .. base .. ": " .. n .. " ranked in stock left unused")
  end
  if total > 0 then say({"htr.total", total}) else say({"htr.none"}) end
  log("[HTR] total marked: " .. total)
  return total
end

script.on_event(defines.events.on_lua_shortcut, function(ev)
  if ev.prototype_name == "htr-restock" then
    local player = game.get_player(ev.player_index)
    restock(player.force, player)
  end
end)

remote.add_interface("hero-turret-restock", {
  restock = function(force_name) return restock(game.forces[force_name or "player"], nil) end,
})
