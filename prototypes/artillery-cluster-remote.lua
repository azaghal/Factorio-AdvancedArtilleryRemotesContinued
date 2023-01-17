-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.

-- Colours used for applying tint on targeting circles, allowing to distinguish between different remotes and targets on
-- the map. Generated using six-tone algorithm.
local TINT_COLOURS = {
  red = {255, 45, 8},
  orange = {255, 169, 8},
  green = {8, 255, 45},
  teal = {8, 255, 169},
  blue = {45, 8, 255},
  purple = {169, 8, 255}
}

-- Reserve certain tint colours for specific artillery remotes and flares, identified by ammo category.
local RESERVED_TINT_COLOURS = {
  ["artillery-shell"] = "red",
  ["atomic-artillery"] = "green"
}

-- Extract available artillery ammo categories. Use table keys in order to obtain unique set.
local ammo_categories = {}

for _, prototype_type in pairs({"artillery-turret", "artillery-wagon"}) do
  for _, prototype in pairs(data.raw["artillery-turret"]) do

    local attack_parameters = data.raw["gun"][prototype.gun].attack_parameters

    if attack_parameters.ammo_type then
      ammo_categories[attack_parameters.ammo_type.category] = true
    end

    if attack_parameters.ammo_category then
      ammo_categories[attack_parameters.ammo_category] = true
    end

    for _, ammo_category in pairs(attack_parameters.ammo_categories or {}) do
      ammo_categories[ammo_category] = true
    end

  end
end

-- Assign reserved tint colours first.
for category, colour in pairs(RESERVED_TINT_COLOURS) do
  if ammo_categories[category] then
    ammo_categories[category] = TINT_COLOURS[colour]
    TINT_COLOURS[colour] = nil
  end
end

-- Assign remaining available tint colours in order they are defined in. Manually iterate over the tint colours in order
-- to effectively "pop" them off one by one from the list.
local tint_colours_iterator = pairs(TINT_COLOURS)
local tint_colours_iterator_current = nil
local colour

for category, unassigned in pairs(ammo_categories) do
  if unassigned == true then

    -- Grab the next tint colour in the list.
    tint_colours_iterator_current, colour = tint_colours_iterator(TINT_COLOURS, tint_colours_iterator_current)

    -- We limit number of remotes to only six, but this should be easy to expand by just adding more colours.
    if tint_colours_iterator_current then
      ammo_categories[category] = colour
    else
      print("[ERROR] More than six cluster remotes are already defined, ignoring artillery ammo category: " .. category)
      ammo_categories[category] = nil
    end
  end
end

-- Process each ammo category corresponding prototypes for it.
for ammo_category, tint_colour in pairs(ammo_categories) do

  local flare_name = "artillery-cluster-flare-" .. ammo_category
  local remote_name = "artillery-cluster-remote-" .. ammo_category

  -- Construct localised name for the remote by "appending" the ammo category to base name.
  local remote_localised_name = {
    "",
    {"item-name.artillery-cluster-remote"},
    " (",
    {"ammo-category-name." .. ammo_category},
    ")"
  }
  -- Use two layers for the cluster remote icon in order to allow applying tint to the targeting circle. This way we can
  -- easily define additional cluster remotes for different types of artillery shells that are visually distinct. In order
  -- to simulate the red colour of vanilla artillery remote, set tint to {r=255, g=45, b=8, a=255}.
  local remote_icons = {
    {
      icon = "__AdvancedArtilleryRemotesContinued__/graphics/icons/artillery-remote-target.png",
      tint = tint_colour
    },
    {
      icon = "__AdvancedArtilleryRemotesContinued__/graphics/icons/artillery-cluster-remote-shells.png",
    },
  }

  -- Custom cluster flares are created to ensure that the cluster remotes operate only on specific type of
  -- ammunition. This allows us to restrict cluster shots to specific types of artillery shells to avoid using expensive
  -- ammo from mods that implement atomic artillery and such. Take note that each such mod must use a distinct ammo
  -- category for their ammo for this to work as expected.
  local flare = {
    type = "artillery-flare",
    name = flare_name,
    shot_category = ammo_category,
    icons = remote_icons,
    icon_size = 64,
    icon_mipmaps = 4,
    flags = {"placeable-off-grid", "not-on-map"},
    map_color = tint_colour,
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
          tint = tint_colour,
          priority = "low",
          width = 258,
          height = 183,
          frame_count = 1,
          scale = 1,
          flags = {"icon"}
        }
      }
  }

  -- Cluster remote.
  local remote = {
    type = "capsule",
    name = remote_name,
    localised_name = remote_localised_name,
    icons = remote_icons,
    icon_size = 64,
    icon_mipmaps = 4,
    capsule_action = {
      type = "artillery-remote",
      flare = flare_name
    },
    subgroup = "defensive-structure",
    order = "b[turret]-d[artillery-turret]-ba[remote]",
    stack_size = 1
  }

  -- Cluster remote recipe.
  local remote_recipe = {
    type = "recipe",
    name = remote_name,
    enabled = false,
    ingredients =
      {
        {"artillery-targeting-remote", 1},
        {"processing-unit", 1},
      },
    result = remote_name
  }

  data:extend({flare})
  data:extend({remote})
  data:extend({remote_recipe})

  -- @TODO: Would be nice if we were to unlock the cluster remote recipe alongside actual ammunition type.
  table.insert(data.raw["technology"]["artillery"].effects, {type = "unlock-recipe", recipe = remote_name})
end
