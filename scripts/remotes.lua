-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2023 Branko Majic
-- Copyright (c) 2024 Bryan O'Malley
-- Provided under MIT license. See LICENSE for details.


-- Main implementation
-- ===================

local remotes = {}
local overlap_tolerance = 0.9

--- Calculates square distance between 2 positions
--
-- @param a first position
-- @param b second position--
--
-- @return squared distance between the positions
--
function dist_sq(a, b)
  distance = (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2
  return distance
end

--- Calculates the center of the passed in circle or rectangle
--
-- @param shape the shape
--
-- @return the center of the shape
--
function shape_center(shape)
  if shape.center then
    return shape.center
  else
    return {x = 0.5 * (shape.left_top.x + shape.right_bottom.x), y = 0.5 * (shape.left_top.y + shape.right_bottom.y)}
  end
end

--- Calculates the approximate center point between an array of circles
--
-- Calculation is a weighted average of the circle centers based on inverse radii weights (closer to smaller circles)
--
-- @param targets the array of circles
--
-- @return the approximate center point between the circles
--
function circle_centroid(targets)
  local average = { x = 0.0, y = 0.0 }
  local length = #targets
  if length == 0 then
    return average
  end
  -- approximate finding center point between circle edges
  local weight = 0
  for _, target in pairs(targets) do
    if target.radius == nil then
      return average -- quit early if we've not been passed all circles
    end
    -- limit modifier to radius 1 or greater to avoid issues with 0-radius inputs
    local modifier = target.radius < 1.0 and (1/target.radius) or 2.0
    weight = weight + modifier
    average.x = average.x + modifier * target.center.x
    average.y = average.y + modifier * target.center.y
  end
  average.x = average.x / weight
  average.y = average.y / weight
  return average
end

--- Calculates the approximate center point between an array of rectangles
--
-- Calculation is created by creating an average of each corner, then caulcating the center of the 'average' rectangle
--
-- @param targets the array of rectangles
--
-- @return the approximate center point between the rectangles
--
function rect_centroid(targets)
  local avg_rect = {left_top={x=0.0,y=0.0},right_bottom={x=0.0,y=0.0}}
  local length = #targets
  if length == 0 then
    return avg_rect
  end
  for _, rect in pairs(targets) do
    if rect.left_top == nil then
      return avg_rect -- quit early if we've not been passed all rectangles
    end
    avg_rect.left_top.x = avg_rect.left_top.x + rect.left_top.x
    avg_rect.left_top.y = avg_rect.left_top.y + rect.left_top.y
    avg_rect.right_bottom.x = avg_rect.right_bottom.x + rect.right_bottom.x
    avg_rect.right_bottom.y = avg_rect.right_bottom.y + rect.right_bottom.y
  end
  avg_rect.left_top.x = avg_rect.left_top.x / #targets
  avg_rect.left_top.y = avg_rect.left_top.y / #targets
  avg_rect.right_bottom.x = avg_rect.right_bottom.x / #targets
  avg_rect.right_bottom.y = avg_rect.right_bottom.y / #targets
  return shape_center(avg_rect)
end

--- Calculates the approximate center between an array of shapes
--
-- passed in shape array must be either all circles or all rectangles
-- 
-- @param targets the array of shapes
--
-- @return the approximate center point between the shapes
--
function center_point(targets)
  if #targets == 0 then
    return {x = 0.0, y = 0.0}
  end
  if targets[1].center then
    return circle_centroid(targets)
  else
    return rect_centroid(targets)
  end
end

--- Determines if 2 objects overlap
--
-- @param a cluster {center: {x,y}, radius}
-- @param b circular {center: {x,y}, radius} or rectangular {left_top: {x,y}, right_bottom: {x,y}} object
--
-- @return boolean
--
function does_overlap(a, b)
  local distance_sq = 0.0
  if b.center then
    distance_sq = dist_sq(a.center, b.center)
    return distance_sq <= (overlap_tolerance * a.radius + b.radius)^2
  elseif b.left_top then
    local closest_point = {}
    closest_point.x = math.max(b.left_top.x, math.min(b.right_bottom.x, a.center.x))
    closest_point.y = math.max(b.left_top.y, math.min(b.right_bottom.y, a.center.y))
    distance_sq = dist_sq(a.center, closest_point)
    return distance_sq <= (overlap_tolerance * a.radius)^2
  end
  error("need to pass circle or rect to does_overlap", 2)
end

--- Determines if a mew target can be added to an existing target cluster
--
-- The new target can be added if the adjustment of the cluster center would not remove any existing targets from the cluster's radius
--
-- @param cluster {center: {x,y}, radius, targets: {...}}
-- @param target {center: {x,y}, radius} or rectangular {left_top: {x,y}, right_bottom: {x,y}}
--
-- @return true, if the new target can be added to the cluster without disrupting existing targets
--
function try_add_to_cluster(cluster, target)
  local destination = {}
  local padding = nil
  local distance = nil
  local separation = nil
  local move_ratio = nil
  local new_center = nil

  -- minimum movement to bring cluster into range
  if target.center then
    destination = target.center
    padding = overlap_tolerance * cluster.radius + target.radius
  elseif target.left_top then
    destination.x = math.max(target.left_top.x, math.min(target.right_bottom.x, cluster.center.x))
    destination.y = math.max(target.left_top.y, math.min(target.right_bottom.y, cluster.center.y))
    padding = overlap_tolerance * cluster.radius
  else
    error("target should be circle or rectangle", 2)
  end
  
  distance = math.sqrt(dist_sq(cluster.center, destination))
  separation = math.max(0, distance - padding)
  if separation == 0 then
    -- if no separation, no movement needed, success
    return {success = true, distance = distance, new_center = cluster.center}
  elseif separation > cluster.radius * 2 then
    -- if (separation > cluster.radius * 2), movement would almost surely remove the original target from the cluster, fail early
    return {success = false, distance = distance}
  end

  move_ratio = separation / distance
  new_center = {}
  new_center.x = move_ratio * (destination.x - cluster.center.x) + cluster.center.x
  new_center.y = move_ratio * (destination.y - cluster.center.y) + cluster.center.y

  -- check to ensure the possible cluster move still hits all original targets
  local new_impact = {center = new_center, radius = cluster.radius}
  for _, cluster_target in pairs(cluster.targets) do
    if not does_overlap(new_impact, cluster_target) then
      -- if we missed an original target, we fail
      return {success = false, distance = distance}
    end
  end
  -- we missed no original targets, success
  return {success = true, distance = distance, new_center = new_center}
end

--- Adds a mew target can be added to an existing target cluster
--
-- The new target is added and the cluster center is adjusted the minimum amount necessary to cover the new target
--
-- @param cluster {center: {x,y}, radius, targets: {...}}
-- @param target {center: {x,y}, radius} or rectangular {left_top: {x,y}, right_bottom: {x,y}}
-- @param try_add_result the result returned by the try_add_to_cluster function, which must be called successfully before calling this function
--
-- @return none
--
function add_to_cluster(cluster, target, try_add_result)
  if not try_add_result.success or not try_add_result.new_center then
    error("passed a failed try_add to add", 2)
    return
  end
  table.insert(cluster.targets, target)
  cluster.center = try_add_result.new_center
end

--- Parses damage radius overrides for ammo categories.
--
-- @param value string Value to parse.
--
-- @return {string=number} Mapping between ammo category names and damage radius overrides.
--
function remotes.parse_damage_radius_overrides(value)

  -- Table for storing the parsed results.
  local overrides = {}

  -- Store list of unknown ammo categories for showing a warning message.
  local unknown_ammo_categories = {}

  for override in string.gmatch(value, "[^,]+") do

    local ammo_category = string.gsub(override, "=.*", "")
    local damage_radius = string.gsub(override, "^[^=]*=", "")

    damage_radius = tonumber(damage_radius)

    -- Store unrecognised ammo categories.
    if not game.ammo_category_prototypes[ammo_category] then
      table.insert(unknown_ammo_categories, ammo_category)
    end

    -- Validate damage radius is valid.
    if not damage_radius or damage_radius < 0 then
      game.print({"error.aar-error-parsing-damage-radius-overrides"})
      return {}
    else
      overrides[ammo_category] = damage_radius
    end

  end

  if table_size(unknown_ammo_categories) > 0 then
    game.print({"warning.aar-unknown-ammo-category", table.concat(unknown_ammo_categories, ", ")})
  end

  return overrides
end


--
-- Uses calculated damage radius unless the player provides override via mod settings.
--
-- @return int Damage radius for optimising cluster targeting.
--
function remotes.get_damage_radius(ammo_category)

  return
    global.ammo_category_damage_radius_overrides[ammo_category] or
    global.ammo_category_damage_radius_defaults[ammo_category]
end


--- Checks if verbose reporting has been enabled for player.
--
-- Thin wrapper around the mod settings.
--
-- @param player LuaPlayer Player for which to make the check.
--
-- @return true, if verbose reporting was requested, false otherwise.
function remotes.verbose_reporting_enabled(player)
  return player.mod_settings["aar-verbose"].value
end


--- Checks if worms should be targeted by the cluster remote.
--
-- Thin wrapper around the mod settings. Takes into account both per-player and map settings.
--
-- @param player LuaPlayer Player for which to perform the check.
--
-- @return true, if worms should be targeted, false otherwise.
--
function remotes.target_worms_enabled(player)
  local player_setting = player.mod_settings["aar-cluster-mode-player"].value
  local setting = player_setting ~= "use-map-setting" and player_setting or settings.global["aar-cluster-mode"].value

  return setting == "spawner-and-worms"
end


--- Checks if cluster remote can be used for firing individual shots if no target entities are found.
--
-- Thin wrapper around the mod setting.
--
-- @param player LuaPlayer Player for which to perform the check.
--
-- @return true, if cluster remote single target fallback is enabled, false otherwise.
--
function remotes.cluster_remote_single_target_fallback_enabled(player)
  return player.mod_settings["aar-cluster-single-target-fallback"].value
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


--- Notifies player with a flying text message at cursor.
--
-- Notifications are sent only if verbose logging has been enabled, or if they are errors. In case of errors, an error
-- sound notification is played as well.
--
-- @param force LuaForce Force to notify with a message.
-- @param message LocalisedString Message to display.
-- @param is_error bool If message should be treated as an error or not.
--
function remotes.notify_player(player, message, is_error)
  if remotes.verbose_reporting_enabled(player) or is_error then
    player.create_local_flying_text {
      text = message,
      create_at_cursor = true,
      speed = 5
    }
  end

  if is_error then
    player.play_sound{ path = "utility/cannot_build" }
  end

end

--- Assigns new targets to a existing cluster array
--
-- @param targets {{center: {x,y}, radius} or rectangular {left_top: {x,y}, right_bottom: {x,y}}, ...}
-- @param damage_radius the radius used for clusters (impact locations) to cover targets
-- @param clusters {{center: {x,y}, radius, targets: {...}}, ...}
--
-- @return updated array of clusters
function assign_clusters(targets, radius, clusters)
  if center_shift == nil then
    center_shift = false
  end
  -- assign targets to clusters
  for _, target in pairs(targets) do
    if #clusters == 0 then
      table.insert(clusters, { center = shape_center(target), radius = radius, targets = { target } })
    else
      local best_cluster = nil
      local best_result = nil
      for _, cluster in pairs(clusters) do
        -- try add
        local try_add_result = try_add_to_cluster(cluster, target)
        if try_add_result.success and (not best_result or try_add_result.distance < best_result.distance) then
          best_cluster = cluster
          best_result = try_add_result
        end
      end
      if best_cluster then
        add_to_cluster(best_cluster, target, best_result)
      else
        table.insert(clusters, { center = shape_center(target), radius = radius, targets = { target } })
      end
    end
  end
end

--- Optimises number of targets (based on entity & damage radii) in order to reduce ammunition usage.
--
-- The algorithm:
--
--   - Simple k-means-like algorithm
--   - Begin empty table of clusters { center: {x,y}, targets: {{x,y}, ...} }
--
--   1. For each target, add it to the closest cluster within damage_radius, if none found, create new cluster
--     - When added to cluster, update cluster position to include new target (minimum necessary)
--   2. Remove any clusters that have no targets
--   - Iterate X times by:
--     3. Merge clusters by rerunning Step 1 with clusters as the targets
--     4. Center each 'new' cluster between it's targets
--   - Output cluster centers as new target list
--
-- @param targets {{center: {x,y}, radius} or rectangular {left_top: {x,y}, right_bottom: {x,y}}, ...}
-- @param damage_radius the radius used for clusters (impact locations) to cover targets
-- @param iteration_passes how many passes to use to 'refine' the clusters, 1-2 passes will be very rough,
--   3+ will return 'good' results with almost no result needing more than 10 passes to 'stabilise'
--
-- @return {MapPosition, ...} Optimised list of target impact locations.
--
function remotes.optimise_targeting(targets, damage_radius, iteration_passes)
  local best_clusters = nil
  local current_clusters = {}

  -- iteration passes
  for pass = 1, iteration_passes, 1 do
    
    -- 3. merge clusters
    local merged_clusters = {}
    assign_clusters(current_clusters, damage_radius, merged_clusters)
    
    -- 4. center on targets then discard them
    for _, cluster in pairs(merged_clusters) do
      cluster.center = center_point(cluster.targets)
      cluster.targets = {}
    end
    
    -- 1. assign targets to clusters
    assign_clusters(targets, damage_radius, merged_clusters)

    -- 2. remove empty clusters
    current_clusters = {}
    for _, cluster in pairs(merged_clusters) do
      if #cluster.targets > 0 then
        table.insert(current_clusters, cluster)
      end
    end

    if not best_clusters or #current_clusters < #best_clusters then
      best_clusters = current_clusters
    end
  end

  -- build final targeting list
  local optimised_targets = {}
  for _, cluster in pairs(best_clusters) do
    table.insert(optimised_targets, cluster.center)
  end
  return optimised_targets
end

--- Retrieves list of entities to target with cluster fire.
--
-- Spawners are always targeted. Worms are targeted if explicitly requested via parameter.
--
-- @param force LuaForce Requesting force. Only opposing forces will be targeted.
-- @param surface LuaSurface Surface to target.
-- @param position MapPosition Central position around which to search for target entities.
-- @param radius uint Radius around the requested position within which to search for target entities.
-- @param include_worms bool Specify if worms should be included for targeting (in addition to spawners).
--
-- @return {LuaEntity} List of targeted enemy entities.
--
function remotes.get_cluster_target_entities(requesting_force, surface, position, radius, include_worms)
  local target_entities = {}
  local enemy_forces = {}

  -- Populate list of enemy forces.
  for _, force in pairs(game.forces) do
    if requesting_force.is_enemy(force) then
      table.insert(enemy_forces, force)
    end
  end

  -- Bail-out if there are no enemy forces.
  if table_size(enemy_forces) == 0 then
    return {}
  end

  -- Add enemy spawners to list of target entities.
  local spawners = surface.find_entities_filtered {
    type = "unit-spawner",
    position = position,
    radius = radius,
    force = enemy_forces,
  }

  for _, spawner in pairs(spawners) do
    table.insert(target_entities, spawner)
  end

  -- Optionally add enemy worms to the list of target entities.
  if include_worms then
    local worms = surface.find_entities_filtered {
      type = "turret",
      position = position,
      radius = radius,
      force = enemy_forces,
    }

    for _, worm in pairs(worms) do
      if string.find(worm.name, "worm") then
        table.insert(target_entities, worm)
      end
    end
  end

  return target_entities
end


--- Finds and removes artillery flares from specified position (if any).
--
-- @param force LuaForce Force which owns the flares.
-- @param surface LuaSufrface Surface to search.
-- @param position MapPosition Surface position to search.
--
function remotes.remove_artillery_flare(force, surface, position)
  local flares = surface.find_entities_filtered {
    type = "artillery-flare",
    position = position,
    force = force,
  }
  for _, flare in pairs(flares) do
    flare.destroy()
  end
end


--- Targets enemy spawners within the configured radius of specified position.
--
-- @param player LuaPlayer Player that requested the targeting.
-- @param surface LuaSurface Surface to target.
-- @param requested_position MapPosition Position around which to carry-out cluster targeting.
-- @param remote_prototype LuaItemPrototype Prototype of cluster remote used to request targeting.
-- @param targeting_radius int Radius around the requested position to target.
--
function remotes.cluster_targeting(player, surface, requested_position, remote_prototype, targeting_radius)
  local target_entities = {}
  local targets = {}

  -- @WORKAROUND: Handling of compatibility cluster remote for use with Shortcuts mod. Once Shortcuts mod has been
  --              updated to deal with new cluster remote name (artillery-cluster-remote-artillery-shell), this block
  --              can be dropped.
  if remote_prototype.name == "artillery-cluster-remote" then
    remote_prototype = game.item_prototypes["artillery-cluster-remote-artillery-shell"]
  end

  local artillery_flare_name = string.gsub(remote_prototype.name,
                                           "artillery[-]cluster[-]remote[-]",
                                           "artillery-cluster-flare-")

  local ammo_category = string.gsub(remote_prototype.name,
                                    "artillery[-]cluster[-]remote[-]",
                                    "")

  local target_entities = remotes.get_cluster_target_entities(player.force, surface, requested_position,
                                                              targeting_radius, remotes.target_worms_enabled(player))

  local damage_radius = remotes.get_damage_radius(ammo_category)

  -- Bail-out if no matching entities could be found.
  if table_size(target_entities) == 0 then

    -- Drop the artillery flare created by player if single target fallback was not enabled - thus preserving some ammo,
    -- and getting clear indication that nothing could be targeted.
    if not remotes.cluster_remote_single_target_fallback_enabled(player) then
      remotes.remove_artillery_flare(player.force, surface, requested_position)
      remotes.notify_player(player, {"error.aar-no-valid-targets"}, true)
    end
    return
  end

  -- Drop the artillery flare created by player - it is only used for marking the center of location to target.
  remotes.remove_artillery_flare(player.force, surface, requested_position)

  -- Create list of target positions.
  for _, entity in pairs(target_entities) do
    table.insert(targets, entity.position)
  end

  -- Optimise number of target positions for flares (reducing required ammo quantity).
  targets = remotes.optimise_targeting(targets, damage_radius)

  remotes.notify_player(player, {"info.aar-artillery-cluster-requested", table_size(target_entities), table_size(targets)})

  for _, position in pairs(targets) do
    surface.create_entity {
      name = artillery_flare_name,
      position = position,
      force = player.force,
      frame_speed = 0,
      vertical_speed = 0,
      height = 0,
      movement = {0, 0}
    }
  end

end


--- Targets positions on map with artillery for discovery/exploration purposes.
--
-- @param player LuaPlayer Player that has requested area discovery.
-- @param surface LuaSurface Surface to target.
-- @param requested_position MapPosition Central position around which to spread-out discovery targets.
-- @param discovery_radius Radius in which to carry-out discovery.
-- @param target_distance Desired distance between consecutive discovery targets alongside circle (for spacing them out).
--
function remotes.discovery_targeting(player, surface, requested_position, discovery_radius, target_distance)
  local target_positions = {}

  -- Drop the flare at requested position to avoid hitting friendlies, and to save on ammunition.
  local flares = surface.find_entities_filtered {
    name = "artillery-discovery-flare",
    position = requested_position,
    force = requested_force,
  }
  for _, flare in pairs(flares) do
    flare.destroy()
  end

  -- No supported artillery is present in the game. This most likely indicates bug in the mod.
  if table_size(global.supported_artillery_entity_prototypes["artillery-shell"] or {}) == 0 then
    player.print({"error.aar-no-supported-artillery-in-game"})
    return
  end

  -- Locate all artillery pieces on targetted surface.
  local artilleries = surface.find_entities_filtered {
    name = global.supported_artillery_entity_prototypes["artillery-shell"],
    force = player.force,
  }

  -- Bail-out if no artillery pieces could be found.
  if table_size(artilleries) == 0 then
    remotes.notify_player(player, {"error.aar-no-supported-artillery"}, true)
    return
  end

  -- Find closest artillery piece to requested position.
  local closest_artillery = surface.get_closest(requested_position, artilleries)
  if not closest_artillery or not closest_artillery.valid then
    remotes.notify_player(player, {"error.aar-no-supported-artillery"}, true)
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
    remotes.notify_player(player, {"error.aar-no-valid-targets"}, true)
    return
  end

  remotes.notify_player(player, {"info.aar-artillery-discovery-requested", discovery_radius, string.format("%.2f", math.deg(angle_width)), table_size(target_positions)})

  -- Create target artillery flares.
  for _, position in pairs(target_positions) do
    surface.create_entity {
      name="artillery-discovery-flare",
      position = position,
      force = player.force,
      frame_speed = 0,
      vertical_speed = 0,
      height = 0,
      movement = {0,0}
    }
  end

end


--- Retrieves list of artillery ammo categories.
--
-- @return {string} List of artillery ammo category names.
--
function remotes.get_artillery_ammo_categories()
  local artillery_prototypes = game.get_filtered_entity_prototypes(
    {
      { filter = "type", type = "artillery-turret" },
      { filter = "type", type = "artillery-wagon" }
    }
  )

  local ammo_categories_set = {}
  for _, prototype in pairs(artillery_prototypes) do
    for _, gun in pairs(prototype.guns) do
      for _, category in pairs(gun.attack_parameters.ammo_categories) do
        ammo_categories_set[category] = true
      end
    end
  end

  local ammo_categories = {}
  for ammo_category, _ in pairs(ammo_categories_set) do
    table.insert(ammo_categories, ammo_category)
  end

  return  ammo_categories
end


--- Retrieves list of artillery entity prototypes that are capable of firing specific ammo category.
--
-- @param ammo_category string Ammo category to match.
--
-- @return {string} List of entity artillery entity prototype names.
--
function remotes.get_artillery_entity_prototypes_by_ammo_category(ammo_category)
  -- "Set" for storing the matched entity prototype names.
  local matched_artillery_prototypes = {}

  local artillery_prototypes = game.get_filtered_entity_prototypes(
    {
      { filter = "type", type = "artillery-turret" },
      { filter = "type", type = "artillery-wagon" }
    }
  )

  for _, prototype in pairs(artillery_prototypes) do
    for _, gun in pairs(prototype.guns) do
      for _, category in pairs(gun.attack_parameters.ammo_categories) do
        if category == ammo_category then
          matched_artillery_prototypes[prototype.name] = true
        end
      end
    end
  end

  -- Convert the set into list of names.
  local matched_artillery_prototype_names = {}
  for name, _ in pairs(matched_artillery_prototypes) do
    table.insert(matched_artillery_prototype_names, name)
  end

  return matched_artillery_prototype_names
end


--- Retrieve (maximum) damage radius for projectile's attack result.
--
-- Implementation is based on traversing the attack result table recursively and finding the largest radius for an
-- "area" type of action/effect.
--
-- This _seems_ to be the algorithm that Factorio uses when calculating the damage radius for a particular projectile
-- (which is then subsequently used for calculating the artillery remote damage indicator).
--
-- However, take note that some of the traversed attack results do _not_ actually cause any damage - they merely produce
-- visual effect (like spreading smoke etc). For simplicity, and to match vanilla game remote's damage indicator, we
-- ignore that detail. Otherwise we would need to do some more recursion and processing to figure out exactly what
-- projectile will cause damage etc.
--
-- @param attack_result table Table describing the attack result (LuaEntityPrototype.attack_result).
--
-- @return int Damage radius for projectile's attack result.
--
function remotes.get_attack_result_damage_radius(attack_result)
  local damage_radius = 0

  -- Start off with current table's radius if any.
  if attack_result.type and attack_result.type == "area" and attack_result.radius then
    damage_radius = attack_result.radius
  end

  -- Recursively iterate over any nested tables. Easier done this way than to sort-out exact nesting structure that
  -- Factorio implements.
  for _, element in pairs(attack_result) do

    if type(element) == "table" then
      local element_damage_radius = remotes.get_attack_result_damage_radius(element)
      damage_radius =
        element_damage_radius > damage_radius and element_damage_radius or
        damage_radius
    end

  end

  return damage_radius
end


--- Retrieve damage radius for projectile.
--
-- @param name string Name of projectile prototype.
--
-- @return int Damage radius for projectile.
--
function remotes.get_projectile_damage_radius(name)
  local prototype = game.entity_prototypes[name]

  -- Starting point.
  local projectile_damage_radius = 0

  -- Projectile can maybe have multiple attack results. Find the biggest value.
  for _, attack_result in pairs(prototype.attack_result or {}) do

    local attack_result_damage_radius = remotes.get_attack_result_damage_radius(attack_result)

    projectile_damage_radius =
      attack_result_damage_radius > projectile_damage_radius and attack_result_damage_radius or
      projectile_damage_radius

  end

  return projectile_damage_radius
end


--- Calculates the default damage radius for an (artillery) ammo category.
--
-- The default damage radius is calculated to match the damage indicator that an artillery remote displays when player
-- is holding it in hand.
--
-- Take note that this is normally the largest possible damage radius for all the different projctiles that are tied-in
-- to the ammo category.
--
-- @param ammo_category string Ammo category (prototype) name.
--
-- @return int Damage radius for passed-in ammo category.
--
function remotes.get_damage_radius_default(ammo_category)
  local ammo_prototypes = game.get_filtered_item_prototypes( { { filter = "type", type = "ammo" } } )

  local projectile_damage_radius_maximum = 0

  -- Iterate over all ammo items, and operate only on those that have a matching ammo category.
  for _, ammo_prototype in pairs(ammo_prototypes) do
    local ammo_type = ammo_prototype.get_ammo_type()

    if ammo_type.category == ammo_category then

      for _, action in pairs(ammo_type.action) do

        if action.type == "direct" then

          for _, action_delivery in pairs(action.action_delivery) do

            if action_delivery.projectile then
              local projectile_damage_radius = remotes.get_projectile_damage_radius(action_delivery.projectile)
              projectile_damage_radius_maximum =
                projectile_damage_radius > projectile_damage_radius_maximum and projectile_damage_radius or
                projectile_damage_radius_maximum
            end

          end

        end

      end

    end

  end

  return projectile_damage_radius_maximum
end


--- Updates recipe availability for all forces based on researched technologies.
--
-- This function should be used when additional artillery ammo categories are introduced into the game by mods added to
-- an existing save.
--
function remotes.update_recipe_availability()
  for _, force in pairs(game.forces) do
    for _, recipe in pairs(force.recipes) do
      if force.technologies["artillery"].researched and
         string.find(recipe.name, "artillery[-]cluster[-]remote[-]") == 1 or
         recipe.name == "artillery-discovery-remote" then
        recipe.enabled = true
      end
    end
  end
end


--- Initialises all global data from scratch.
--
-- Recalculates lists of artillery ammo categories, supported artillery entity prototypes by ammo category, and default
-- damage radius for each ammo category. Meant to be called via on_init and on_configuration_changed event handlers.
--
function remotes.initialise_global_data()
  -- Set-up list of available ammo categories.
  global.artillery_ammo_categories = remotes.get_artillery_ammo_categories()

  -- Set-up list of supported artillery entity prototypes by ammo category.
  global.supported_artillery_entity_prototypes = {}
  for _, ammo_category in pairs(global.artillery_ammo_categories) do
    global.supported_artillery_entity_prototypes[ammo_category] = remotes.get_artillery_entity_prototypes_by_ammo_category(ammo_category)
  end

  -- Calculate default damage radius for each ammo category.
  global.ammo_category_damage_radius_defaults = {}
  for _, ammo_category in pairs(global.artillery_ammo_categories) do
    global.ammo_category_damage_radius_defaults[ammo_category] = remotes.get_damage_radius_default(ammo_category)
  end

  global.ammo_category_damage_radius_overrides = remotes.parse_damage_radius_overrides(settings.global["aar-damage-radius-overrides"].value)
end


--- Shows currently detected default damage radius for each supported ammo category.
--
-- @param player LuaPlayer Player to which the listing should be shown.
--
function remotes.show_damage_radius_defaults(player)
  local listing = {}
  local sorted_ammo_categories = {}

  for ammo_category, damage_radius in pairs(global.ammo_category_damage_radius_defaults) do
    table.insert(listing, ammo_category .. "=" .. damage_radius)
  end

  player.print({"info.aar-ammo-category-damage-radius-defaults", table.concat(listing, "\n") })
end


-- Event handlers
-- ==============


--- Handler invoked when the mod is added for the first time.
--
function remotes.on_init()
  remotes.initialise_global_data()
end


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

  -- Reinitialise all global data to pick up any changes in ammo categories etc.
  remotes.initialise_global_data()

  -- Update availability of advanced artillery remotes for all forces.
  remotes.update_recipe_availability()
end


--- Handler invoked when player uses a capsule or artillery remotes.
--
-- @param event EventData Event data as passed-in by the game engine.
--
function remotes.on_player_used_capsule(event)

  -- @WORKAROUND: Name comparison for artillery-cluster-remote is meant for compatbility mode with Shortcuts. Drop the
  --              condition once the Shortcuts mod has been properly fixed to handle new prototype name.
  if string.find(event.item.name, "artillery[-]cluster[-]remote[-]") == 1 or event.item.name == "artillery-cluster-remote" then
    local player = game.players[event.player_index]
    remotes.cluster_targeting(player, player.surface, event.position, event.item, remotes.get_cluster_radius())
  end

  if event.item.name == "artillery-discovery-remote" then
    local player = game.players[event.player_index]
    remotes.discovery_targeting(player, player.surface, event.position, remotes.get_discovery_radius(), remotes.get_discovery_angle_width())
  end
end


--- Handler invoked when player changes the mod configuration.
--
-- @param event EventData Event data as passed-in by the game engine.
--
function remotes.on_runtime_mod_setting_changed(event)

  -- Parse the player-provided settings.
  if event.setting == "aar-damage-radius-overrides" then
    global.ammo_category_damage_radius_overrides = remotes.parse_damage_radius_overrides(settings.global["aar-damage-radius-overrides"].value)
  end
end


return remotes
