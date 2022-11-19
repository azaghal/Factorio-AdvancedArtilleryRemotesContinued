-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2022 Branko Majic
-- Provided under MIT license. See LICENSE for details.


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
discovery_flare.icon_mipmaps = 4
discovery_flare.shot_category = "artillery-shell"


local discovery_remote = {
  type = "capsule",
  name = "artillery-discovery-remote",
  icons = discovery_remote_icons,
  icon_size = 64,
  icon_mipmaps = 4,
  capsule_action = {
    type = "artillery-remote",
    flare = "artillery-discovery-flare"
  },
  subgroup = "defensive-structure",
  order = "b[turret]-d[artillery-turret]-bb[remote]",
  stack_size = 1
}


local discovery_recipe = {
  type = "recipe",
  name = "artillery-discovery-remote",
  enabled = false,
  ingredients =
  {
    {"artillery-targeting-remote", 1},
    {"processing-unit", 1},
  },
  result = "artillery-discovery-remote"
}

table.insert(data.raw["technology"]["artillery"].effects, {type = "unlock-recipe", recipe = "artillery-discovery-remote"})
data:extend({discovery_remote, discovery_flare, discovery_recipe})
