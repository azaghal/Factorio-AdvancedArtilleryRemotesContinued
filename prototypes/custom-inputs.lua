-- Copyright (c) 2025 kommade
-- Provided under MIT license. See LICENSE for details.

data:extend({
  {
    type = "custom-input",
    name = "give-artillery-discovery-remote",
    key_sequence = "ALT + H",
    consuming = "game-only",
    item_to_spawn = "artillery-discovery-remote",
    action = "spawn-item"
  },
  {
    type = "custom-input",
    name = "give-artillery-cluster-remote",
    key_sequence = "ALT + I",
    consuming = "game-only",
    item_to_spawn = "artillery-cluster-remote-artillery-shell",
    action = "spawn-item"
  }
})
