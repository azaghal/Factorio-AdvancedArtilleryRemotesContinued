local cluster_remote = {
  type = "capsule",
  name = "artillery-cluster-remote",
  icon = "__AdvArtilleryRemotes__/graphics/icons/artillery-cluster-remote.png",
  icon_size = 32,
  capsule_action = {
    type = "artillery-remote",
    flare = "artillery-cluster-flare"
  },
  subgroup = "capsule",
  order = "zzza",
  stack_size = 1
}

local cluster_flare = {
  type = "artillery-flare",
  name = "artillery-cluster-flare",
  icon = "__AdvArtilleryRemotes__/graphics/icons/artillery-cluster-remote.png",
  icon_size = 32,
  flags = {"placeable-off-grid", "not-on-map"},
  map_color = {r=1, g=0.5, b=0},
  life_time = 60 * 60,
  initial_height = 0,
  initial_vertical_speed = 0,
  initial_frame_speed = 1,
  shots_per_flare = 1,
  early_death_ticks = 3 * 60,
  pictures =
  {
    {
      filename = "__core__/graphics/shoot-cursor-red.png",
      priority = "low",
      width = 258,
      height = 183,
      frame_count = 1,
      scale = 1,
      flags = {"icon"}
    },
  }
}

local test_flare = {
  type = "artillery-flare",
  name = "artillery-test-flare",
  icon = "__AdvArtilleryRemotes__/graphics/icons/artillery-cluster-remote.png",
  icon_size = 32,
  flags = {"placeable-off-grid", "not-on-map"},
  map_color = {r=0, g=0, b=1},
  life_time = 60 * 60,
  initial_height = 0,
  initial_vertical_speed = 0,
  initial_frame_speed = 1,
  shots_per_flare = 1,
  early_death_ticks = 3 * 60,
  pictures =
  {
    {
      filename = "__core__/graphics/shoot-cursor-green.png",
      priority = "low",
      width = 258,
      height = 183,
      frame_count = 1,
      scale = 1,
      flags = {"icon"}
    },
  }
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