-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local remotes = require("scripts.remotes")


local commands = {}


commands.show_damage_radius_defaults = {}
commands.show_damage_radius_defaults.name = "asc-show-damage-radius-defaults"
commands.show_damage_radius_defaults.help = [[
Lists default damage radius values for each artillery ammo category recognised by the Advanced Artillery Remotes mod. Useful for changing the "Damage radius overrides for cluster targeting" mod setting.
Usage:
    /asc-show-damage-radius-defaults
]]


--- Shows current defaults for ammo category damage radius.
--
-- @param command_data CustomCommandData Command data structure passed-in by the game engine.
--
commands.show_damage_radius_defaults.func = function(command_data)
  local player = game.players[command_data.player_index]

  remotes.show_damage_radius_defaults(player)
end


return commands
