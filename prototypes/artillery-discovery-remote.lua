-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2022 Branko Majic
-- Provided under MIT license. See LICENSE for details.


-- Custom discovery flare that sets the shot category. This allows us to restrict discovery shots to plain (vanilla)
-- artillery shells to avoid using expensive ammo from mods that implement atomic artillery and such. Take note that
-- such mods must use different ammo category for their ammo for this to work as expected.
local discovery_flare = util.table.deepcopy(data.raw["artillery-flare"]["artillery-flare"])
discovery_flare.name = "artillery-discovery-flare"
discovery_flare.icon = "__AdvancedArtilleryRemotesContinued__/graphics/icons/artillery-discovery-remote.png"
discovery_flare.icon_size = 32
discovery_flare.icon_mipmaps = 1
discovery_flare.shot_category = "artillery-shell"


local discovery_remote = {
  type = "capsule",
  name = "artillery-discovery-remote",
  icon = "__AdvancedArtilleryRemotesContinued__/graphics/icons/artillery-discovery-remote.png",
  icon_size = 32,
  capsule_action = {
    type = "artillery-remote",
    flare = "artillery-discovery-flare"
  },
  subgroup = "capsule",
  order = "zzza",
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
