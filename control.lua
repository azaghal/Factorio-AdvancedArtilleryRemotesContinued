--[[

--]]

MOD_NAME    = "AdvancedArtilleryRemotesContinued"
MOD_STRING  = "Advanced Artillery Remotes Continued"
MOD_TOKEN   = "AARU"
MOD_VERSION = "1.0.0"
MOD_RELEASE = true

require "util"
require "utils.logger"

CLUSTER_MODE_SPAWNER = 0
CLUSTER_MODE_SPAWNERWORM = 1
CLUSTER_MODE_CARPET = 2

--[[ ----------------------------------------------------------------------------------
      MOD SETTINGS
--]]
-- settings
global.settings = global.settings or {
  verbose        = true,
  cluster_mode   = CLUSTER_MODE_SPAWNER,
  cluster_radius = 32,
  cluster_merge  = 49,

  discovery_arc_radius = 30,
  discovery_angle_length = 40,
}

-- update settings called every time and on mod_runtime_setting_changed()
local function update_settings()
  global.settings.verbose = settings.global["aar-verbose"].value

  if settings.global["aar-cluster-mode"].value == "spawner-only" then
    global.settings.cluster_mode = CLUSTER_MODE_SPAWNER
  elseif settings.global["aar-cluster-mode"].value == "spawner-and-worms" then
    global.settings.cluster_mode = CLUSTER_MODE_SPAWNERWORM
  end

  global.settings.cluster_radius = settings.global["aar-cluster-radius"].value

  local merge_dist = settings.global["aar-merge-radius"].value
  global.settings.cluster_merge = merge_dist * merge_dist

  global.settings.discovery_arc_radius = settings.global["aar-arc-radius"].value
  global.settings.discovery_angle_length = settings.global["aar-angle-width"].value
end
script.on_event({defines.events.on_runtime_mod_setting_changed}, update_settings)

-- always run
do
  update_settings()
end

--[[ ----------------------------------------------------------------------------------
      CLUSTER MODE
--]]
local function reduce_flares(pos_flares)
  local function merge_flares(flare1, flare2)
    local new_x = flare1.x - math.floor((flare1.x - flare2.x) / 2)
    local new_y = flare1.y - math.floor((flare1.y - flare2.y) / 2)
    --_debug("merging: flare1 (" .. flare1.x .. "/" .. flare1.y .. ") flare2: (" .. flare2.x .. "/" .. flare2.y .. ") mergedto: (" .. new_x .. "/" .. new_y .. ")" )
    return {x = new_x, y = new_y}
  end

  local function is_in_distance(flare1, flare2)
    local x, y = flare1.x-flare2.x, flare1.y-flare2.y
    local dist = x*x + y*y
    --_debug("checking distance: " .. dist)
    return (dist < global.settings.cluster_merge) -- 4*4, explosion radius
  end

  local tsize = table_size(pos_flares)
  for i, flare1 in pairs(pos_flares) do

    for j = i+1, tsize do
      if pos_flares[j] ~= nil then
        local flare2 = pos_flares[j]
        if is_in_distance(flare1, flare2) then
          -- merge flares
          flare1 = merge_flares(flare1, flare2)
          pos_flares[i] = flare1
          pos_flares[j] = nil
          goto break_merging
        end
      end
    end
    ::break_merging::
  end
end

local function cluster_flare(event)
  local player = game.players[event.player_index]
  local surface = player and player.surface or nil
  local requested_position = event.position

  local target_entities = {}
  local target_positions = {}
  local enemy_forces = {}

  -- Bail-out if we could not determine the surface. @TODO: Can this ever even happen?
  if not surface then
    _warn("Unable to determine surface index.")
    return
  end

  -- Drop the flare at requested position to avoid hitting friendlies, and to save on ammunition.
  local flares = surface.find_entities_filtered {
    type = "artillery-flare",
    position = requested_position,
    force = player.force,
  }
  for _, flare in pairs(flares) do
    flare.destroy()
  end

  -- Populate list of enemy forces.
  for _, force in pairs(game.forces) do
    if player.force.is_enemy(force) then
      table.insert(enemy_forces, force)
    end
  end

  -- Bail-out if there are no enemy forces.
  if table_size(enemy_forces) == 0 then
    if global.settings.verbose then
      _info("There are no enemy forces in the game to target with artillery cluster.")
    end
    return
  end

  -- Add enemy spawners to list of target entities.
  local spawners = surface.find_entities_filtered {
    type = "unit-spawner",
    position = requested_position,
    radius = global.settings.cluster_radius,
    force = enemy_forces,
  }

  for _, spawner in pairs(spawners) do
    table.insert(target_entities, spawner)
  end

  -- Optionally add enemy worms to the list of target entities.
  if global.settings.cluster_mode == CLUSTER_MODE_SPAWNERWORM then
    local worms = surface.find_entities_filtered {
      type = "turret",
      position = requested_position,
      radius = global.settings.cluster_radius,
      force = enemy_forces,
    }

    for _, worm in pairs(worms) do
      if string.find(worm.name, "worm") then
        table.insert(target_entities, worm)
      end
    end
  end

  -- Bail-out if no target entities could be found.
  if table_size(target_entities) == 0 then
    if global.settings.verbose then
      _info("No valid targets found for the artillery cluster.")
    end
    return
  end

  -- Create list of target positions.
  for _, entity in pairs(target_entities) do
    table.insert(target_positions, entity.position)
  end

  -- Optimise number of target positions for flares (reducing required ammo quantity).
  reduce_flares(target_positions)

  if global.settings.verbose then
    _info("Artillery Cluster requested. " .. table_size(target_entities) .." target(s) found. Creating a total of " .. table_size(target_positions) .. " artillery flares")
  end

  for _, position in pairs(target_positions) do
    surface.create_entity {
      name = "artillery-flare",
      position = position,
      force = player.force,
      frame_speed = 0,
      vertical_speed = 0,
      height = 0,
      movement = {0, 0}
    }
  end

end

--[[ ----------------------------------------------------------------------------------
      DISCOVERY MODE
--]]
local function discovery_flare(event)
  local player = game.players[event.player_index]
  local surface = player and player.surface or nil
  local requested_position = event.position

  local target_positions = {}

  -- Bail-out if we could not determine the surface. @TODO: Can this ever even happen?
  if not surface then
    _warn("Unable to determine surface index.")
    return
  end

  -- Locate all artillery on targetted surface.
  local artilleries = surface.find_entities_filtered {
    name = {"artillery-turret", "artillery-wagon"},
    force = player.force,
  }

  -- Bail-out if no nearby artillery could be found.
  if table_size(artilleries) == 0 then
    return
  end

  -- Find closest artillery (piece) to requested position.
  local closest_artillery = surface.get_closest(requested_position, artilleries)
  if not closest_artillery or not closest_artillery.valid then
    return
  end

  -- Calculate total number of positions (points) to target along the arc.
  local shift_x, shift_y = requested_position.x - closest_artillery.position.x, requested_position.y - closest_artillery.position.y
  local dist = math.sqrt(shift_x * shift_x + shift_y * shift_y)
  local angle_width = math.atan(global.settings.discovery_angle_length / dist)
  local points = math.floor((global.settings.discovery_arc_radius / math.deg(angle_width)) / 2)

  -- Calculate target position points.
  for i = -points, points do
    if i ~= 0 then
      local angle = i * angle_width
      local position = {
        x = (shift_x * math.cos(angle) - shift_y * math.sin(angle)) + closest_artillery.position.x,
        y = (shift_x * math.sin(angle) + shift_y * math.cos(angle)) + closest_artillery.position.y,
      }

      table.insert(target_positions, position)
    end
  end

  -- Bail-out if no valid target positions could be calculated.
  if table_size(target_positions) == 0 then
    return
  end

  if global.settings.verbose then
    _info("Artillery Discovery requested. Arcradius: " .. global.settings.discovery_arc_radius .."°, Angle: ".. math.deg(angle_width) .. "°. Creating a total of " .. table_size(target_positions) + 1 .. " artillery flares")
  end

  -- Create target artillery flares.
  for _, position in pairs(target_positions) do
    surface.create_entity {
      name="artillery-flare",
      position = position,
      force = player.force,
      frame_speed = 0,
      vertical_speed = 0,
      height = 0,
      movement = {0,0}
    }
  end
end

--[[ ----------------------------------------------------------------------------------
      ADVANCED ARTILLERY REMOTES
--]]
local function on_capsule_used(event)
  if not event.item then return end

  -- cluster flare
  if event.item.name == "artillery-cluster-remote" then
    cluster_flare(event)
    return
  end

  -- discovery flare
  if event.item.name == "artillery-discovery-remote" then
    discovery_flare(event)
    return
  end
end
script.on_event({defines.events.on_player_used_capsule}, on_capsule_used)
