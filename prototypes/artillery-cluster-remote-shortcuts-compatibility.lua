-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


-- @WORKAROUND: Compatibility cluster remote for use with Shortcuts mod. Once Shortcuts mod has been updated to deal
--              with new cluster remote name, this whole file can be dropped.
if mods["Shortcuts-ick"] == "1.1.27" then

  local ammo_category = "artillery-shell"
  local tint_colour = {255, 45, 8}
  local flare_name = "artillery-cluster-flare-" .. ammo_category
  local remote_name = "artillery-cluster-remote"

  -- Construct localised name for the remote by "appending" the ammo category to base name.
  local remote_localised_name = {
    "",
    {"item-name.artillery-cluster-remote"},
    " (",
    {"?", {"ammo-category-name." .. ammo_category}, ammo_category},
    ")"
  }
  -- Use two layers for the cluster remote icon in order to allow applying tint to the targeting circle. This way we can
  -- easily define additional cluster remotes for different types of artillery shells that are visually distinct. In order
  -- to simulate the red colour of vanilla artillery remote, set tint to {r=255, g=45, b=8, a=255}.
  local remote_icons = {
    {
      icon = "__ArtillerySmartClusteringRemote__/graphics/icons/artillery-remote-target.png",
      tint = tint_colour
    },
    {
      icon = "__ArtillerySmartClusteringRemote__/graphics/icons/artillery-cluster-remote-shells.png",
    },
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
    stack_size = 1,
    flags = {"hidden"}
  }

  data:extend({remote})
end
