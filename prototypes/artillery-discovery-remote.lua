-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2023 Branko Majic
-- Copyright (c) 2025 kommade
-- Provided under MIT license. See LICENSE for details.

-- It is convenient to copy some of the properties from the vanilla artillery targeting remote.
local artillery_targeting_remote = data.raw["capsule"]["artillery-targeting-remote"]

-- Use two layers for the discovery remote icon in order to allow applying tint to the targeting circle. This way we can
-- easily define additional discovery remotes for different types of artillery shells that are visually distinct (if
-- ever needed). In order to simulate the red colour of vanilla artillery remote, set tint to {r=255, g=45, b=8, a=255}.
local discovery_remote_icons = {
  {
    icon = "__AdvancedArtilleryRemotesContinued__/graphics/icons/artillery-remote-target.png",
    tint = {r=255, g=45, b=8, a=255}
  },
  {
    icon = "__AdvancedArtilleryRemotesContinued__/graphics/icons/artillery-discovery-remote-radar.png",
  },
}

-- Custom discovery flare that sets the shot category. This allows us to restrict discovery shots to plain (vanilla)
-- artillery shells to avoid using expensive ammo from mods that implement atomic artillery and such. Take note that
-- such mods must use different ammo category for their ammo for this to work as expected.
local discovery_flare = util.table.deepcopy(data.raw["artillery-flare"]["artillery-flare"])
discovery_flare.name = "artillery-discovery-flare"
discovery_flare.icons = discovery_remote_icons
discovery_flare.icon_size = 64
discovery_flare.shot_category = "artillery-shell"

local discovery_remote = {
  type = "capsule",
  auto_recycle = false,
  name = "artillery-discovery-remote",
  icons = discovery_remote_icons,
  icon_size = 64,
  icon_mipmaps = 4,
  capsule_action = {
    type = "artillery-remote",
    flare = "artillery-discovery-flare"
  },
  order = "b[turret]-d[artillery-turret]-ba[remote]",
  flags = { "only-in-cursor", "not-stackable", "spawnable" },
  stack_size = 1,
  inventory_move_sound = artillery_targeting_remote.inventory_move_sound,
  pick_sound = artillery_targeting_remote.pick_sound,
  drop_sound = artillery_targeting_remote.drop_sound,
}

local discovery_shortcut = {
  type = "shortcut",
  name = "make-artillery-discovery-remote",
  order = "e[spidertron-remote]",
  action = "spawn-item",
  technology_to_unlock = "artillery",
  unavailable_until_unlocked = true,
  item_to_spawn = "artillery-discovery-remote",
  icons = discovery_remote_icons,
  icon_size = 64,
  icon_mipmaps = 4,
  small_icons = discovery_remote_icons,
  small_icon_size = 32,
  associated_control_input = "give-artillery-discovery-remote"
}

data:extend({discovery_remote, discovery_flare, discovery_shortcut})
