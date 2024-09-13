-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


-- Main implementation
-- ===================

local remotes = {}

function target_radius(entity)
  -- None of the returned tile-sizes or collision-box dimensions from the API seem to directly match & work with in-game results, oddly.
  -- These numbers were derived by counting tiles in the map view while paused, and generate optimal results.
  -- WEIRD.
  if entity.type == "unit-spawner" then
    return 3
  elseif string.find(entity.name, "small") then
    return 1.5
  else
    return 2
  end
end

function distSq(a, b)
  distance = (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2
  return distance
end

function center_point(targets)
  local average = { x = 0.0, y = 0.0 }
  local length = #targets
  if length == 0 then
    return average
  end
  -- approximate finding center point between circle edges
  local weight = 0
  for _, target in pairs(targets) do
    local modifier = (1/target.radius)
    weight = weight + modifier
    average.x = average.x + modifier * target.position.x
    average.y = average.y + modifier * target.position.y
  end
  average.x = average.x / weight
  average.y = average.y / weight
  return average
end

--- Determines how close 2 objects are
--
-- @param a circular object {center: {x,y}, radius}
-- @param b circular or rectangle object, rectangle is {left_top: {x,y}, right_bottom: {x,y}}
-- @param tolerance how a must overlap b for overlap == true
--
-- @return {does_overlap, distance}
--
function proximity(a, b, tolerance)
  if tolerance == nil then
    tolerance = 0.10
  end
  local does_overlap = false
  local distanceSq = 0.0
  if b.center then
    distanceSq = distSq(a.center, b.center)
    does_overlap = distanceSq <= ((1-tolerance) * a.radius + b.radius)^2
  elseif b.left_top then
    local closest_point = {}
    closest_point.x = math.max(b.left_top.x, math.min(b.right_bottom.x, a.center.x))
    closest_point.y = math.max(b.right_bottom.y, math.min(b.left_top.y, a.center.y))
    distanceSq = distanceSq(a.center, closest_point)
    does_overlap = distanceSq <= ((1-tolerance) * a.radius)^2
  end
  return {does_overlap, distanceSq}
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
      game.print({ "error.asc-error-parsing-damage-radius-overrides" })
      return {}
    else
      overrides[ammo_category] = damage_radius
    end
  end

  if table_size(unknown_ammo_categories) > 0 then
    game.print({ "warning.asc-unknown-ammo-category", table.concat(unknown_ammo_categories, ", ") })
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
  return player.mod_settings["asc-verbose"].value
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
  local player_setting = player.mod_settings["asc-cluster-mode-player"].value
  local setting = player_setting ~= "use-map-setting" and player_setting or settings.global["asc-cluster-mode"].value

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
  return player.mod_settings["asc-cluster-single-target-fallback"].value
end

--- Retrieves radius in which the cluster remote operates.
--
-- Thin wrapper around the mod settings.
--
-- @return int Radius in which cluster remote operates.
--
function remotes.get_cluster_radius()
  return settings.global["asc-cluster-radius"].value
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
    player.play_sound { path = "utility/cannot_build" }
  end
end

function assign_clusters(targets, radius, clusters)
  -- assign targets to clusters
  for _, target in pairs(targets) do
    if #clusters == 0 then
      table.insert(clusters, { center = target.position, targets = { target } })
    else
      local near = nil
      local near_dist = -1
      for _, cluster in pairs(clusters) do
        local new_dist = distSq(target.position, cluster.center)
        if (new_dist - (radius + target.radius) <= 0) and ((not near) or (new_dist < near_dist)) then
          near = cluster
          near_dist = new_dist
        end
      end
      if near then
        table.insert(near.targets, target)
      else
        table.insert(clusters, { center = target.position, targets = { target } })
      end
    end
  end
  for _, cluster in pairs(clusters) do
    cluster.center = center_point(cluster.targets)
  end
end

--- Optimises number of targets (based on entity & damage radii) in order to reduce ammunition usage.
--
-- The algorithm:
--
--   - Simple k-means-like algorithm
--   - Begin empty table of clusters { center: {x,y}, targets: {{x,y}, ...} }
--   - For each target, add it to the closest cluster within damage_radius, if none found, create new cluster
--     - When added to cluster, update cluster position to average of all subtargets
--   - Iterate X times by moving targets to new cluster if:
--     - Target is now outside damage_radius of cluster center
--     - Target is closer to a different cluster
--   - Output cluster centers as new target list
--
--   - Optimization: Use on_nth_tick or on_tick to do each clustering iteration pass over time?
--
-- @param targets {position: MapPosition, radius: float} List of targets (positions) on a single surface with their radii.
-- @param damage_radius float Damage radius around designated targets.
--
-- @return {MapPosition} Optimised list of targets (positions).
--
function remotes.optimise_targeting(targets, damage_radius, iteration_passes)
  local target_clusters = {}
  local num_targets = nil

  -- iteration passes
  for pass = 1, iteration_passes, 1 do
    -- populate new potential cluster centers
    local potential_cluster_centers = {}
    for _, cluster in pairs(target_clusters) do
      -- use damage_radius as cluster radius to avoid overlapping impacts
      -- table.insert(potential_cluster_centers, {position = center_point(cluster.targets), radius = damage_radius})
      table.insert(potential_cluster_centers, { position = cluster.center, radius = damage_radius })
    end

    -- merge
    local merged_clusters = {}
    assign_clusters(potential_cluster_centers, damage_radius, merged_clusters)
    -- clean and adjust merged clusters
    for _, cluster in pairs(merged_clusters) do
      cluster.targets = {}
    end

    -- assign targets to merged clusters
    assign_clusters(targets, damage_radius, merged_clusters)

    -- update targeting or bail
    local new_num_targets = #merged_clusters
    if num_targets == nil or (new_num_targets < num_targets) then
      target_clusters = merged_clusters
      num_targets = new_num_targets
    else
      break
    end
  end

  -- build final targeting list
  local optimised_targets = {}
  for _, cluster in pairs(target_clusters) do
    --table.insert(optimised_targets, center_point(cluster.targets))
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
  -- local target_entities = {}
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
      remotes.notify_player(player, { "error.asc-no-valid-targets" }, true)
    end
    return
  end

  -- Drop the artillery flare created by player - it is only used for marking the center of location to target.
  remotes.remove_artillery_flare(player.force, surface, requested_position)

  -- Create list of target positions.
  for _, entity in pairs(target_entities) do
    table.insert(targets, { position = entity.position, radius = target_radius(entity) })
  end

  -- Optimise number of target positions for flares (reducing required ammo quantity).
  local optimised_targets = remotes.optimise_targeting(targets, damage_radius,
    settings.global["asc-cluster-iterations"].value)

  remotes.notify_player(player,
    { "info.asc-artillery-cluster-requested", table_size(target_entities), table_size(targets) })

  for _, target in pairs(optimised_targets) do
    surface.create_entity {
      name = artillery_flare_name,
      position = target,
      force = player.force,
      frame_speed = 0,
      vertical_speed = 0,
      height = 0,
      movement = { 0, 0 }
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

  return ammo_categories
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
  local ammo_prototypes = game.get_filtered_item_prototypes({ { filter = "type", type = "ammo" } })

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
    global.supported_artillery_entity_prototypes[ammo_category] = remotes
    .get_artillery_entity_prototypes_by_ammo_category(ammo_category)
  end

  -- Calculate default damage radius for each ammo category.
  global.ammo_category_damage_radius_defaults = {}
  for _, ammo_category in pairs(global.artillery_ammo_categories) do
    global.ammo_category_damage_radius_defaults[ammo_category] = remotes.get_damage_radius_default(ammo_category)
  end

  global.ammo_category_damage_radius_overrides = remotes.parse_damage_radius_overrides(settings.global
  ["asc-damage-radius-overrides"].value)
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

  player.print({ "info.asc-ammo-category-damage-radius-defaults", table.concat(listing, "\n") })
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
  -- remotes.update_recipe_availability()
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
end

--- Handler invoked when player changes the mod configuration.
--
-- @param event EventData Event data as passed-in by the game engine.
--
function remotes.on_runtime_mod_setting_changed(event)
  -- Parse the player-provided settings.
  if event.setting == "asc-damage-radius-overrides" then
    global.ammo_category_damage_radius_overrides = remotes.parse_damage_radius_overrides(settings.global
    ["asc-damage-radius-overrides"].value)
  end
end

return remotes
