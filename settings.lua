-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2023-2025 Branko Majic
-- Provided under MIT license. See LICENSE for details.


data:extend({

    -- Map settings
    -- ============

    {
        type = "string-setting",
        name = "aar-cluster-mode",
        setting_type = "runtime-global",
        order = "ab",
        default_value = "spawner-only",
        allowed_values = {"spawner-only", "spawner-and-worms"}
    },

    {
        type = "int-setting",
        name = "aar-cluster-radius",
        setting_type = "runtime-global",
        order = "ac",
        default_value = 32,
        minimum_value = 1,
        maximum_value = 100,
    },

    {
        type = "string-setting",
        name = "aar-damage-radius-overrides",
        setting_type = "runtime-global",
        order = "ad",
        default_value = "",
        allow_blank = true,
    },

    {
        type = "int-setting",
        name = "aar-arc-radius",
        setting_type = "runtime-global",
        order = "ae",
        default_value = 30,
        minimum_value = 1,
        maximum_value = 360,
    },

    {
        type = "int-setting",
        name = "aar-angle-width",
        setting_type = "runtime-global",
        order = "af",
        default_value = 40,
        minimum_value = 1,
        maximum_value = 100,
    },

    -- Per-player settings
    -- ===================

    {
        type = "string-setting",
        name = "aar-cluster-mode-player",
        setting_type = "runtime-per-user",
        order = "aa",
        default_value = "use-map-setting",
        allowed_values = {"use-map-setting", "spawner-only", "spawner-and-worms"},
    },

    {
        type = "bool-setting",
        name = "aar-verbose",
        order = "ab",
        setting_type = "runtime-per-user",
        default_value = false
    },

    {
        type = "bool-setting",
        name = "aar-cluster-single-target-fallback",
        order = "ab",
        setting_type = "runtime-per-user",
        default_value = false
    },

})
