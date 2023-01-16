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
function remotes.get_merge_radius(ammo_category)

  return global.ammo_category_default_merge_radius[ammo_category]
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


--- Optimises number of targets (based on explosion overlaps) in order to reduce ammunition usage.
--
-- The algorithm:
--
--   - Looks-up pairs of targets that are closer to each-other than the specified explosion range, and replaces them
--     with a new target positioned midway between the two.
--   - Removes targets that are already within explosion radius (half the explosion range) of already optimised target.
--   - Targets that cannot be paired-up or are not already covered by explosion radius of another optimised target are
--     preserved as-is (and considered as optimised).
--
-- @param targets {MapPosition} List of targets (positions) on a single surface.
-- @param explosion_range float Explosion range (diameter) around designated targets.
--
-- @return {MapPosition} Optimised list of targets (positions).
--
function remotes.optimise_targeting(targets, explosion_range)

  local optimised_targets = {}

  -- Calculates new target position that is positioned in-between the passed-in targets.
  local function merge_targets(target1, target2)
    local new_x = target1.x - math.floor((target1.x - target2.x) / 2)
    local new_y = target1.y - math.floor((target1.y - target2.y) / 2)

    return {x = new_x, y = new_y}
  end

  -- Checks if two targets could be merged into single one positioned midway between the two.
  local function can_merge_targets(target1, target2, explosion_range)
    local x, y = target1.x - target2.x, target1.y - target2.y

    return (x^2 + y^2 < explosion_range^2)
  end

  -- Keep track of processed targets - those have already been optimised and cannot be dropped without risking the full
  -- explosion coverage. Should map keys to boolean values.
  local processed = {}

  -- Iterate over all targets and see if it is possible to merge them in pairs.
  for i1, target1 in pairs(targets) do
    if not processed[i1] then

      -- Assume target is already optimised (this value is used in one of the later steps).
      local optimised_target = target1

      -- Merge the target with another one if possible.
      for i2, target2 in pairs(targets) do

        if i1 ~= i2 and not processed[i1] and not processed[i2] and can_merge_targets(target1, target2, explosion_range) then
          optimised_target = merge_targets(target1, target2)
          processed[i2] = true
          break
        end

      end

      -- Mark the starting target as processed (at this point it is going to be kept, or replaced with a merged target).
      processed[i1] = true

      -- Check if any other (unprocessed) targets fall within the explosion radius of optimised target.
      for i, target in pairs(targets) do

        -- Reuse the test, but pass-in radius instead of diameter (we won't place anything in-between).
        if not processed[i] and can_merge_targets(optimised_target, target, explosion_range/2) then
          processed[i] = true
        end

      end

      -- Finally add the optimised target to the list.
      table.insert(optimised_targets, optimised_target)

    end
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

  local artillery_flare_name = string.gsub(remote_prototype.name,
                                           "artillery[-]cluster[-]remote[-]",
                                           "artillery-cluster-flare-")

  local ammo_category = string.gsub(remote_prototype.name,
                                    "artillery[-]cluster[-]remote[-]",
                                    "")

  local target_entities = remotes.get_cluster_target_entities(player.force, surface, requested_position,
                                                              targeting_radius, remotes.target_worms_enabled(player))

  local explosion_radius = remotes.get_merge_radius(ammo_category)

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
  targets = remotes.optimise_targeting(targets, explosion_radius)

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

  -- Projectile can maybe have multiple attack results. Simply find the one that has the biggest damage radius.
  for _, attack_result in pairs(prototype.attack_result) do

    local attack_result_damage_radius = remotes.get_attack_result_damage_radius(attack_result)

    projectile_damage_radius =
      attack_result_damage_radius > projectile_damage_radius and attack_result_damage_radius or
      projectile_damage_radius

  end

  return projectile_damage_radius
end


--- Calculates the default merge radius for a particular (artillery) ammo category based on the area damage it causes.
--
-- The default merge radius is calculated in order to match-up with the damage indicator when holding a particular
-- artillery remote.
--
-- Technically, the returned value will be a _diameter_, but for legacy reasons (pre-fork) it is called radius within
-- the code. It might be a good idea to actually fix this naming in some way down the line to reduce confusion.
--
-- @param ammo_category string Ammo category (prototype) name.
--
-- @return int Merge radius for particular ammo category.
--
function remotes.get_default_merge_radius(ammo_category)
  local ammo_prototypes = game.get_filtered_item_prototypes( { { filter = "type", type = "ammo" } } )

  local projectile_damage_radius_maximum = 0

  -- Iterate over all ammo items, and operate only on those that have a matching ammo category.
  for _, ammo_prototype in pairs(ammo_prototypes) do
    local ammo_type = ammo_prototype.get_ammo_type()

    if ammo_type.category == ammo_category then

      for _, action in pairs(ammo_type.action) do

        if action.type == "direct" then

          for _, action_delivery in pairs(action.action_delivery) do
            local projectile_damage_radius = remotes.get_projectile_damage_radius(action_delivery.projectile)
            projectile_damage_radius_maximum =
              projectile_damage_radius > projectile_damage_radius_maximum and projectile_damage_radius or
              projectile_damage_radius_maximum
          end

        end

      end

    end

  end

  -- This is technically a diameter, but for legacy reasons we still call it radius. The optimisation code actually
  -- depends on diameter value.
  return projectile_damage_radius_maximum * 2
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
-- merge radius for each ammo category. Meant to be called via on_init and on_configuration_changed event handlers.
--
function remotes.initialise_global_data()
  -- Set-up list of available ammo categories.
  global.artillery_ammo_categories = remotes.get_artillery_ammo_categories()

  -- Set-up list of supported artillery entity prototypes by ammo category.
  global.supported_artillery_entity_prototypes = {}
  for _, ammo_category in pairs(global.artillery_ammo_categories) do
    global.supported_artillery_entity_prototypes[ammo_category] = remotes.get_artillery_entity_prototypes_by_ammo_category(ammo_category)
  end

  -- Calculate default merge radius for each ammo category.
  global.ammo_category_default_merge_radius = {}
  for _, ammo_category in pairs(global.artillery_ammo_categories) do
    global.ammo_category_default_merge_radius[ammo_category] = remotes.get_default_merge_radius(ammo_category)
  end
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

  if string.find(event.item.name, "artillery[-]cluster[-]remote[-]") == 1 then
    local player = game.players[event.player_index]
    remotes.cluster_targeting(player, player.surface, event.position, event.item, remotes.get_cluster_radius())
  end

  if event.item.name == "artillery-discovery-remote" then
    local player = game.players[event.player_index]
    remotes.discovery_targeting(player, player.surface, event.position, remotes.get_discovery_radius(), remotes.get_discovery_angle_width())
  end
end


return remotes
