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

commands.recalculate_damage_radius_defaults = {}
commands.recalculate_damage_radius_defaults.name = "aar-recalculate-damage-radius-defaults"
commands.recalculate_damage_radius_defaults.help = [[
Forces recalculation of damage radius defaults for all ammo categories recognised by the Advanced Artillery Remotes mod. Useful for mod development.
Usage:
    /aar-recalculate-damage-radius-defaults
]]


--- Shows current defaults for ammo category damage radius.
--
-- @param command_data CustomCommandData Command data structure passed-in by the game engine.
--
commands.show_damage_radius_defaults.func = function(command_data)
  local player = game.players[command_data.player_index]

  remotes.show_damage_radius_defaults(player)
end


--- Recalculates damage radius defaults for all ammo categories.
--
-- @param command_data CustomCommandData Command data structure passed-in by the game engine.
--
commands.recalculate_damage_radius_defaults.func = function(command_data)
  local player = game.players[command_data.player_index]

  remotes.recalculate_damage_radius_defaults(player)
end


return commands
