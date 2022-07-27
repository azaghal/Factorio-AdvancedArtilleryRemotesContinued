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

local remotes = require("scripts.remotes")

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
  remotes.optimise_targeting(pos_flares, remotes.get_merge_radius())
end

local function cluster_flare(event)
  local player = game.players[event.player_index]
  local surface = player and player.surface or nil
  local position = event.position
  local targeting_radius = remotes.get_cluster_radius()
  local explosion_radius = remotes.get_merge_radius()

  -- Bail-out if we could not determine the surface. @TODO: Can this even happen? Check API docs.
  if not surface then
    _warn("Unable to determine surface index.")
    return
  end

  remotes.cluster_targeting(player.force, surface, position, targeting_radius, explosion_radius)
end

--[[ ----------------------------------------------------------------------------------
      DISCOVERY MODE
--]]
local function discovery_flare(event)
  local player = game.players[event.player_index]
  local surface = player and player.surface or nil
  local position = event.position
  local discovery_radius = remotes.get_discovery_radius()
  local discovery_angle_width = remotes.get_discovery_angle_width()

  -- Bail-out if we could not determine the surface. @TODO: Can this even happen? Check API docs.
  if not surface then
    _warn("Unable to determine surface index.")
    return
  end

  remotes.discovery_targeting(player.force, surface, position, discovery_radius, discovery_angle_width)
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
