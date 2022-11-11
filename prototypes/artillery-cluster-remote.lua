-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2022 Branko Majic
-- Provided under MIT license. See LICENSE for details.

-- Colours used for applying tint on targeting circles, allowing to distinguish between different remotes and target
-- entities.
local tint_colours = {
  red = {255, 45, 8},
  orange = {255, 169, 8},
  green = {8, 255, 45},
  teal = {8, 255, 169},
  blue = {45, 8, 255},
  purple = {169, 8, 255}
}

-- Use two layers for the cluster remote icon in order to allow applying tint to the targeting circle. This way we can
-- easily define additional cluster remotes for different types of artillery shells that are visually distinct. In order
-- to simulate the red colour of vanilla artillery remote, set tint to {r=255, g=45, b=8, a=255}.
local cluster_remote_icons = {
  {
    icon = "__AdvancedArtilleryRemotesContinued__/graphics/icons/artillery-remote-target.png",
    tint = tint_colours.red
  },
  {
    icon = "__AdvancedArtilleryRemotesContinued__/graphics/icons/artillery-cluster-remote-shells.png",
  },
}

-- Custom artillery flare that sets the shot category. This allows us to restrict cluster shots to plain (vanilla)
-- artillery shells to avoid using expensive ammo from mods that implement atomic artillery and such. Take note that
-- such mods must use different ammo category for their ammo for this to work as expected.
local cluster_flare = {
  type = "artillery-flare",
  name = "artillery-cluster-flare",
  shot_category = "artillery-shell",
  icons = cluster_remote_icons,
  icon_size = 64,
  icon_mipmaps = 4,
  flags = {"placeable-off-grid", "not-on-map"},
  map_color = tint_colours.red,
  life_time = 60 * 60,
  initial_height = 0,
  initial_vertical_speed = 0,
  initial_frame_speed = 1,
  shots_per_flare = 1,
  early_death_ticks = 3 * 60,
  pictures =
    {
      {
        filename = "__AdvancedArtilleryRemotesContinued__/graphics/artillery-target.png",
        tint = tint_colours.red,
        priority = "low",
        width = 258,
        height = 183,
        frame_count = 1,
        scale = 1,
        flags = {"icon"}
      }
    }
}

local cluster_remote = {
  type = "capsule",
  name = "artillery-cluster-remote",
  icons = cluster_remote_icons,
  icon_size = 64,
  icon_mipmaps = 4,
  capsule_action = {
    type = "artillery-remote",
    flare = "artillery-cluster-flare"
  },
  subgroup = "capsule",
  order = "zzza",
  stack_size = 1
}

local cluster_recipe = {
  type = "recipe",
  name = "artillery-cluster-remote",
  enabled = false,
  ingredients =
  {
    {"artillery-targeting-remote", 1},
    {"processing-unit", 1},
  },
  result = "artillery-cluster-remote"
}

table.insert(data.raw["technology"]["artillery"].effects, {type = "unlock-recipe", recipe = "artillery-cluster-remote"})
data:extend({cluster_remote, cluster_flare, cluster_recipe, test_flare})
