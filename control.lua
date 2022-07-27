-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2022 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local remotes = require("scripts.remotes")


-- Event handler registration
-- ==========================
script.on_configuration_changed(remotes.on_configuration_changed)
script.on_event(defines.events.on_player_used_capsule, remotes.on_player_used_capsule)
