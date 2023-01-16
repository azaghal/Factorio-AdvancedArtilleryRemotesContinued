-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2022 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local remotes = require("scripts.remotes")
local mod_commands = require("scripts.commands")


-- Event handler registration
-- ==========================
script.on_init(remotes.on_init)
script.on_configuration_changed(remotes.on_configuration_changed)
script.on_event(defines.events.on_player_used_capsule, remotes.on_player_used_capsule)
script.on_event(defines.events.on_runtime_mod_setting_changed, remotes.on_runtime_mod_setting_changed)


-- Command registration
-- ====================
for _, mod_command in pairs(mod_commands) do
    commands.add_command(mod_command.name, mod_command.help, mod_command.func)
end
