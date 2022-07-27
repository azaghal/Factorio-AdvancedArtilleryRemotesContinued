-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2022 Branko Majic
-- Provided under MIT license. See LICENSE for details.


-- Main implementation
-- ===================

local remotes = {}


--- Retrieves the merge radius setting.
--
-- Acts as a thin wrapper around the mod setting.
--
-- @return int Merge (explosion) radius for locating overlapping targets.
--
function remotes.get_merge_radius()
  return settings.global["aar-merge-radius"].value
end


--- Checks if verbose reporting has been requested via mod settings.
--
-- Thin wrapper around the mod settings.
--
-- @return true, if verbose reporting was requested, false otherwise.
function remotes.verbose_reporting_enabled()
  return settings.global["aar-verbose"].value
end


--- Checks if worms should be targeted by the cluster remote.
--
-- Thin wrapper around the mod settings.
--
-- @return true, if worms should be targeted, false otherwise.
--
function remotes.target_worms_enabled()
  return settings.global["aar-cluster-mode"].value == "spawner-and-worms"
end


--- Retrieves radius in which the cluster remote operates.
--
-- Thin wrapper around the mod settings.
--
-- @return int Radius in which cluster remote operates.
--
function remotes.get_cluster_radius()
  return settings.global["aar-cluster-radius"].value
end


--- Retrieves configured discovery radius.
--
-- Thin wrapper around the mod settings.
--
-- @return int Radius in which to target positions for discovery purposes (in degrees).
function remotes.get_discovery_radius()
  return settings.global["aar-arc-radius"].value
end


--- Retrieves configured discovery arc angle width.
--
-- Thin wrapper around the mod settings.
--
-- @return int Desired distance between neighbouring target positions.
function remotes.get_discovery_angle_width()
  return settings.global["aar-angle-width"].value
end


--- Displays message to all players in specified force.
--
-- Notifications are sent only if verbose logging has been enabled.
--
-- @param force LuaForce Force to notify with a message.
-- @param message LocalisedString Message to display.
--
function remotes.notify_force(force, message)
  if remotes.verbose_reporting_enabled() then
    force.print(message)
  end
end


--- Optimises number of targets (based on explosion overlaps) in order to reduce ammunition usage.
--
-- @param targets {MapPosition} List of targets (positions). Modified during function execution.
--
function remotes.optimise_targeting(targets, explosion_radius)

  -- Calculates new target position that is positioned in-between the passed-in targets.
  local function merge_targets(target1, target2)
    local new_x = target1.x - math.floor((target1.x - target2.x) / 2)
    local new_y = target1.y - math.floor((target1.y - target2.y) / 2)

    return {x = new_x, y = new_y}
  end

  -- Checks if the explosions would overlap for passed-in targets based on explosion radius.
  local function explosions_overlap(target1, target2, explosion_radius)
    local x, y = target1.x - target2.x, target1.y - target2.y

    return (x^2 + y^2 < explosion_radius^2)
  end

  -- Iterate over all targets and see if it is possible to merge them in pairs.
  local targets_count = table_size(targets)
  for i1, target1 in pairs(targets) do

    -- Compare to existing targets, break once a merge happens.
    for i2 = i1+1, targets_count do
      local target2 = targets[i2]

      if target2 and explosions_overlap(target1, target2, explosion_radius) then
        targets[i1] = merge_targets(target1, target2)
        targets[i2] = nil
        break
      end
    end
  end
end


--- Targets enemy spawners within the configured radius of specified position.
--
-- @param requesting_force LuaForce Force requesting to perform the targeting.
-- @param surface LuaSurface Surface to target.
-- @param requested_position MapPosition Position around which to carry-out cluster targeting.
-- @param targeting_radius int Radius around the requested position to target.
-- @param explosion_radius int Explosion radius to use when optimising the targeting.
--
function remotes.cluster_targeting(requesting_force, surface, requested_position, targeting_radius, explosion_radius)
  local target_entities = {}
  local targets = {}
  local enemy_forces = {}

  -- Drop the flare at requested position to avoid hitting friendlies, and to save on ammunition.
  local flares = surface.find_entities_filtered {
    type = "artillery-flare",
    position = requested_position,
    force = requesting_force,
  }
  for _, flare in pairs(flares) do
    flare.destroy()
  end

  -- Populate list of enemy forces.
  for _, force in pairs(game.forces) do
    if requesting_force.is_enemy(force) then
      table.insert(enemy_forces, force)
    end
  end

  -- Bail-out if there are no enemy forces.
  if table_size(enemy_forces) == 0 then
    remotes.notify_force(requesting_force, {"error.aar-no-enemy-forces"})
    return
  end

  -- Add enemy spawners to list of target entities.
  local spawners = surface.find_entities_filtered {
    type = "unit-spawner",
    position = requested_position,
    radius = targeting_radius,
    force = enemy_forces,
  }

  for _, spawner in pairs(spawners) do
    table.insert(target_entities, spawner)
  end

  -- Optionally add enemy worms to the list of target entities.
  if remotes.target_worms_enabled() then
    local worms = surface.find_entities_filtered {
      type = "turret",
      position = requested_position,
      radius = targeting_radius,
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
    remotes.notify_force(requesting_force, {"error.aar-no-valid-targets"})
    return
  end

  -- Create list of target positions.
  for _, entity in pairs(target_entities) do
    table.insert(targets, entity.position)
  end

  -- Optimise number of target positions for flares (reducing required ammo quantity).
  remotes.optimise_targeting(targets, explosion_radius)

  remotes.notify_force(requesting_force, {"info.aar-artillery-cluster-requested", table_size(target_entities), table_size(targets)})

  for _, position in pairs(targets) do
    surface.create_entity {
      name = "artillery-flare",
      position = position,
      force = requesting_force,
      frame_speed = 0,
      vertical_speed = 0,
      height = 0,
      movement = {0, 0}
    }
  end

end


--- Targets positions on map with artillery for discovery/exploration purposes.
--
-- @param requesting_force LuaForce Force that has requested area discovery.
-- @param surface LuaSurface Surface to target.
-- @param requested_position MapPosition Central position around which to spread-out discovery targets.
-- @param discovery_radius Radius in which to carry-out discovery.
-- @param target_distance Desired distance between consecutive discovery targets alongside circle (for spacing them out).
--
function remotes.discovery_targeting(requesting_force, surface, requested_position, discovery_radius, target_distance)
  local target_positions = {}

  -- Drop the flare at requested position to avoid hitting friendlies, and to save on ammunition.
  local flares = surface.find_entities_filtered {
    type = "artillery-flare",
    position = requested_position,
    force = requested_force,
  }
  for _, flare in pairs(flares) do
    flare.destroy()
  end

  -- Locate all artillery pieces on targetted surface.
  local artilleries = surface.find_entities_filtered {
    name = {"artillery-turret", "artillery-wagon"},
    force = requesting_force,
  }

  -- Bail-out if no artillery pieces could be found.
  if table_size(artilleries) == 0 then
    return
  end

  -- Find closest artillery piece to requested position.
  local closest_artillery = surface.get_closest(requested_position, artilleries)
  if not closest_artillery or not closest_artillery.valid then
    return
  end

  -- Calculate total number of positions to target along the arc.
  local shift_x, shift_y = requested_position.x - closest_artillery.position.x, requested_position.y - closest_artillery.position.y
  local dist = math.sqrt(shift_x * shift_x + shift_y * shift_y)
  local angle_width = math.atan(target_distance / dist)
  local points = math.floor((discovery_radius / math.deg(angle_width)) / 2)

  -- Calculate target position points.
  for i = -points, points do
    local angle = i * angle_width
    local position = {
      x = (shift_x * math.cos(angle) - shift_y * math.sin(angle)) + closest_artillery.position.x,
      y = (shift_x * math.sin(angle) + shift_y * math.cos(angle)) + closest_artillery.position.y,
    }
    table.insert(target_positions, position)
  end

  -- Bail-out if no valid target positions could be calculated.
  if table_size(target_positions) == 0 then
    return
  end

  remotes.notify_force(requesting_force, {"info.aar-artillery-discovery-requested", discovery_radius, string.format("%.2f", math.deg(angle_width)), table_size(target_positions) + 1})
  remotes.notify_force(requesting_force, {"info.aar-artillery-discovery-requested", discovery_radius, string.format("%.2f", math.deg(angle_width)), table_size(target_positions)})

  -- Create target artillery flares.
  for _, position in pairs(target_positions) do
    surface.create_entity {
      name="artillery-flare",
      position = position,
      force = requesting_force,
      frame_speed = 0,
      vertical_speed = 0,
      height = 0,
      movement = {0,0}
    }
  end

end


-- Event handlers
-- ==============


--- Handler invoked for game version updates, mod version changes, and mod startup configuration changes.
--
-- @param data ConfigurationChangedData Information about mod changes passed on by the game engine.
--
function remotes.on_configuration_changed(data)
  local mod_changes = data.mod_changes["AdvancedArtilleryRemotesContinued"]

  if mod_changes then
    -- Wipe the settings stored in global variable (from older mod versions). They are already easily accessible through
    -- mod API, and this helps avoid having to keep them in sync inside of global variable.
    global.settings = nil

    -- Wipe the messages stored in global variable (from older mod versions). Unused data structure.
    global.messages = nil
  end
end


--- Handler invoked when player uses a capsule or artillery remotes.
--
-- @param event EventData Event data as passed-in by the game engine.
--
function remotes.on_player_used_capsule(event)

  if event.item.name == "artillery-cluster-remote" then
    local player = game.players[event.player_index]
    remotes.cluster_targeting(player.force, player.surface, event.position, remotes.get_cluster_radius(), remotes.get_merge_radius())
  end

  if event.item.name == "artillery-discovery-remote" then
    local player = game.players[event.player_index]
    remotes.discovery_targeting(player.force, player.surface, event.position, remotes.get_discovery_radius(), remotes.get_discovery_angle_width())
  end
end

return remotes
