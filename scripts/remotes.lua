-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


-- Main implementation
-- ===================

local remotes = {}


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
    if not prototypes.ammo_category[ammo_category] then
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
    storage.ammo_category_damage_radius_overrides[ammo_category] or
    storage.ammo_category_damage_radius_defaults[ammo_category]
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


--- Optimises number of targets (based on damage radius) in order to reduce ammunition usage.
--
-- The algorithm:
--
--   - Looks-up pairs of targets that are close enough to each-other to be replaced with a single target that is
--     positioned midway between them, and still be caught within the damage radius.
--   - Removes targets that are already within damage radius of another already optimised target.
--   - Targets that cannot be paired-up or are not already covered by damage radius of another optimised target are
--     preserved as-is (and considered as optimised).
--
-- @param targets {MapPosition} List of targets (positions) on a single surface.
-- @param damage_radius float Damage radius around designated targets.
--
-- @return {MapPosition} Optimised list of targets (positions).
--
function remotes.optimise_targeting(targets, damage_radius)

  local optimised_targets = {}

  -- Calculates new target position that is positioned in-between the passed-in targets.
  local function merge_targets(target1, target2)
    local new_x = target1.x - math.floor((target1.x - target2.x) / 2)
    local new_y = target1.y - math.floor((target1.y - target2.y) / 2)

    return {x = new_x, y = new_y}
  end

  -- Checks if two targets could be merged into single one positioned midway between the two.
  local function can_merge_targets(target1, target2, damage_radius)
    local x, y = target1.x - target2.x, target1.y - target2.y

    return (x^2 + y^2 < (damage_radius * 2)^2)
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

        if i1 ~= i2 and not processed[i1] and not processed[i2] and can_merge_targets(target1, target2, damage_radius) then
          optimised_target = merge_targets(target1, target2)
          processed[i2] = true
          break
        end

      end

      -- Mark the starting target as processed (at this point it is going to be kept, or replaced with a merged target).
      processed[i1] = true

      -- Check if any other (unprocessed) targets fall within the damage radius of optimised target.
      for i, target in pairs(targets) do

        -- Reuse the test, pass-in half the damage radius since we don't want to check the mid-point.
        if not processed[i] and can_merge_targets(optimised_target, target, damage_radius/2) then
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

    -- No longer needed
    --   if remote_prototype.name == "artillery-cluster-remote" then
    --     remote_prototype = prototypes.item["artillery-cluster-remote-artillery-shell"]
    --   end

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
  if table_size(storage.supported_artillery_entity_prototypes["artillery-shell"] or {}) == 0 then
    player.print({"error.aar-no-supported-artillery-in-game"})
    return
  end

  -- Locate all artillery pieces on targetted surface.
  local artilleries = surface.find_entities_filtered {
    name = storage.supported_artillery_entity_prototypes["artillery-shell"],
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
  local artillery_prototypes = prototypes.get_entity_filtered(
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

  local artillery_prototypes = prototypes.get_entity_filtered(
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
  local prototype = prototypes.entity[name]

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
  local ammo_prototypes = prototypes.get_item_filtered( { { filter = "type", type = "ammo" } } )

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
  storage.artillery_ammo_categories = remotes.get_artillery_ammo_categories()

  -- Set-up list of supported artillery entity prototypes by ammo category.
  storage.supported_artillery_entity_prototypes = {}
  for _, ammo_category in pairs(storage.artillery_ammo_categories) do
    storage.supported_artillery_entity_prototypes[ammo_category] = remotes.get_artillery_entity_prototypes_by_ammo_category(ammo_category)
  end

  -- Calculate default damage radius for each ammo category.
  storage.ammo_category_damage_radius_defaults = {}
  for _, ammo_category in pairs(storage.artillery_ammo_categories) do
    storage.ammo_category_damage_radius_defaults[ammo_category] = remotes.get_damage_radius_default(ammo_category)
  end

  storage.ammo_category_damage_radius_overrides = remotes.parse_damage_radius_overrides(settings.global["aar-damage-radius-overrides"].value)
end


--- Shows currently detected default damage radius for each supported ammo category.
--
-- @param player LuaPlayer Player to which the listing should be shown.
--
function remotes.show_damage_radius_defaults(player)
  local listing = {}
  local sorted_ammo_categories = {}

  for ammo_category, damage_radius in pairs(storage.ammo_category_damage_radius_defaults) do
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
    storage.settings = nil

    -- Wipe the messages stored in global variable (from older mod versions). Unused data structure.
    storage.messages = nil
  end

  -- Reinitialise all global data to pick up any changes in ammo categories etc.
  remotes.initialise_global_data()
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
    storage.ammo_category_damage_radius_overrides = remotes.parse_damage_radius_overrides(settings.global["aar-damage-radius-overrides"].value)
  end
end


return remotes
