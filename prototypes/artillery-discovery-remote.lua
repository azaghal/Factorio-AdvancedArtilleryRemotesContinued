local discovery_remote = {
  type = "capsule",
  name = "artillery-discovery-remote",
  icon = "__AdvArtilleryRemotes__/graphics/icons/artillery-discovery-remote.png",
  icon_size = 32,
  capsule_action = {
    type = "artillery-remote",
    flare = "artillery-discovery-flare"
  },
  subgroup = "capsule",
  order = "zzza",
  stack_size = 1
}

local discovery_flare = {
  type = "artillery-flare",
  name = "artillery-discovery-flare",
  icon = "__AdvArtilleryRemotes__/graphics/icons/artillery-discovery-remote.png",
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