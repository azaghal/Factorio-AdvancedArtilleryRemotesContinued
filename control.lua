--[[

--]]

MOD_NAME    = "AdvancedArtilleryRemotesContinued"
MOD_STRING  = "Advanced Artillery Remotes Continued"
MOD_TOKEN   = "AARU"
MOD_VERSION = "0.2.0"
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
local function make_pos_list(entity_list)
  local pos_list = {}
  for _, entity in pairs(entity_list) do
    table.insert(pos_list, entity.position)
  end
  return pos_list
end

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
  local surface = nil
  if game.players[event.player_index] and game.players[event.player_index].character then
    surface = game.players[event.player_index].character.surface
  end
  if not surface then
    _warn("Unable to determine surface index.")
    return
  end

  local pos_flare = event.position
  local pos_cluster = nil

  -- cluster mode: spawner only
  if global.settings.cluster_mode == CLUSTER_MODE_SPAWNER then
    local spawner_list = surface.find_entities_filtered {
      type = "unit-spawner",
      position = pos_flare,
      radius = global.settings.cluster_radius,
      force="enemy",
    }

    pos_cluster = make_pos_list(spawner_list)
    --_debug("spawner only: found: " .. table_size(spawner_list))
  end

  -- cluster mode: spawner and worms
  if global.settings.cluster_mode == CLUSTER_MODE_SPAWNERWORM then
    local spawner_list = surface.find_entities_filtered {
      name = {"behemoth-worm-turret", "big-worm-turret", "medium-worm-turret", "small-worm-turret", "biter-spawner", "spitter-spawner"},
      position = pos_flare,
      radius = global.settings.cluster_radius,
      force="enemy",
    }

    pos_cluster = make_pos_list(spawner_list)
    --_debug("spawner+worms: found: " .. table_size(spawner_list))
  end

  -- do the clustering
  if not pos_cluster or table_size(pos_cluster) == 0 then return end

  --local tcopy = util.table.deepcopy(pos_cluster)

  local targets_found = table_size(pos_cluster)
  reduce_flares(pos_cluster)

  if global.settings.verbose then
    _info("Artillery Cluster requested. " .. targets_found .." targets found. Creating a total of " .. table_size(pos_cluster) .. " additional artillery flares")
  end


  local flare_force = game.players[event.player_index].force

  for _, pos in pairs(pos_cluster) do
    surface.create_entity {
      name="artillery-flare",
      position=pos,
      force=flare_force,
      frame_speed=0,
      vertical_speed=0,
      height=0,
      movement={0,0}
    }
  end
--    for _, pos in pairs(tcopy) do
--    surface.create_entity {
--      name="artillery-test-flare",
--      position=pos,
--      force=flare_force,
--      frame_speed=0,
--      vertical_speed=0,
--      height=0,
--      movement={0,0}
--    }
--  end
end

--[[ ----------------------------------------------------------------------------------
      DISCOVERY MODE
--]]
local function discovery_flare(event)
  local surface = nil
  if game.players[event.player_index] and game.players[event.player_index].character then
    surface = game.players[event.player_index].character.surface
  end
  if not surface then
    _warn("Unable to determine surface index.")
    return
  end

  --
  local flare_force = game.players[event.player_index].force
  local pos_flare = event.position
  local pos_cluster = {}

  local artilleries = surface.find_entities_filtered {
    name = {"artillery-turret", "artillery-wagon"},
    force = flare_force,
  }
  if not artilleries or table_size(artilleries) == 0 then return end

  local closest = surface.get_closest(pos_flare, artilleries)
  if not closest or not closest.valid then return end

  local pos_arty = closest.position
  local shift_x, shift_y = pos_flare.x-pos_arty.x, pos_flare.y-pos_arty.y
  local dist = math.sqrt(shift_x*shift_x + shift_y*shift_y )
  local angle_width = math.atan(global.settings.discovery_angle_length / dist)
  local points = math.floor((global.settings.discovery_arc_radius / math.deg(angle_width)) / 2)

  --
  for i = -points, points do
    if i ~= 0 then
      local angle = i * angle_width
      local new_flare = {
        x = (shift_x * math.cos(angle) - shift_y * math.sin(angle)) + pos_arty.x,
        y = (shift_x * math.sin(angle) + shift_y * math.cos(angle)) + pos_arty.y,
      }

      table.insert(pos_cluster, new_flare)
    end
  end

  -- do the clustering
  if not pos_cluster or table_size(pos_cluster) == 0 then return end

  if global.settings.verbose then
    _info("Artillery Discovery requested. Arcradius: " .. global.settings.discovery_arc_radius .."°, Angle: ".. math.deg(angle_width) .. "°. Creating a total of " .. table_size(pos_cluster) .. " additional artillery flares")
  end

  for _, pos in pairs(pos_cluster) do
    surface.create_entity {
      name="artillery-flare",
      position=pos,
      force=flare_force,
      frame_speed=0,
      vertical_speed=0,
      height=0,
      movement={0,0}
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
