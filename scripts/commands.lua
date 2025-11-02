-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local remotes = require("scripts.remotes")


local commands = {}


commands.show_damage_radius_defaults = {}
commands.show_damage_radius_defaults.name = "aar-show-damage-radius-defaults"
commands.show_damage_radius_defaults.help = [[

Lists default damage radius values for each artillery ammo category recognised by the Advanced Artillery Remotes mod. Useful for changing the "Damage radius overrides for cluster targeting" mod setting.

Usage:
    /aar-show-damage-radius-defaults
]]


--- Shows current defaults for ammo category damage radius.
--
-- @param command_data CustomCommandData Command data structure passed-in by the game engine.
--
commands.show_damage_radius_defaults.func = function(command_data)
  local player = game.players[command_data.player_index]

  remotes.show_damage_radius_defaults(player)
end


commands.reset_global_data = {}
commands.reset_global_data.name = "aar-reset-global-data"
commands.reset_global_data.help = [[

Resets and reinitialises mod's global data (primarily useful during development).

Usage of this command is discouraged for regular savegames.

Reinitialisation (amongst other things) forces rescan of available artillery ammo/categories and recalculation of damage radius for all artillery shell ammo categories. This is helpful when adding new artillery ammo or artillery ammo categories to the game or when tweaking the cluster targeting algorithm during development.

Usage:
    /aar-reset-global-data
]]


--- Resets and reinitialises all global data.
--
-- Useful during development when adding new ammo categories, artillery shells, or when tweaking the calculation
-- algorithm itself.
--
-- @param command_data CustomCommandData Command data structure passed-in by the game engine.
--
commands.reset_global_data.func = function(command_data)
  local player = game.players[command_data.player_index]

  -- Administrator privileges are required to run the command.
  if not player.admin then
    player.print({"error.aar-administrator-privileges-required"})
    return
  end

  remotes.initialise_global_data()
  player.print({ "info.aar-global-data-reset" })
  remotes.show_damage_radius_defaults(player)
end


return commands
