-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2022 Branko Majic
-- Provided under MIT license. See LICENSE for details.


-- Use two layers for the cluster remote icon in order to allow applying tint to the targeting circle. This way we can
-- easily define additional cluster remotes for different types of artillery shells that are visually distinct. In order
-- to simulate the red colour of vanilla artillery remote, set tint to {r=255, g=45, b=8, a=255}.
local cluster_remote_icons = {
  {
    icon = "__AdvancedArtilleryRemotesContinued__/graphics/icons/artillery-remote-target.png",
    tint = {r=255, g=45, b=8, a=255}
  },
  {
    icon = "__AdvancedArtilleryRemotesContinued__/graphics/icons/artillery-cluster-remote-shells.png",
  },
}

-- Custom artillery flare that sets the shot category. This allows us to restrict cluster shots to plain (vanilla)
-- artillery shells to avoid using expensive ammo from mods that implement atomic artillery and such. Take note that
-- such mods must use different ammo category for their ammo for this to work as expected.
local cluster_flare = util.table.deepcopy(data.raw["artillery-flare"]["artillery-flare"])
cluster_flare.name = "artillery-cluster-flare"
cluster_flare.icons = cluster_remote_icons
cluster_flare.icon_size = 64
cluster_flare.icon_mipmaps = 4
cluster_flare.shot_category = "artillery-shell"

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
