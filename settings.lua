-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


data:extend({

    -- Map settings
    -- ============

    {
        type = "string-setting",
        name = "asc-cluster-mode",
        setting_type = "runtime-global",
        order = "ab",
        default_value = "spawner-and-worms",
        allowed_values = {"spawner-only", "spawner-and-worms"}
    },

    {
        type = "int-setting",
        name = "asc-cluster-radius",
        setting_type = "runtime-global",
        order = "ac",
        default_value = 32,
        minimum_value = 1,
        maximum_value = 100,
    },

    {
        type = "int-setting",
        name = "asc-cluster-iterations",
        setting_type = "runtime-global",
        order = "ad",
        default_value = 3,
        minimum_value = 0,
        maximum_value = 10,
    },

    {
        type = "string-setting",
        name = "asc-damage-radius-overrides",
        setting_type = "runtime-global",
        order = "ae",
        default_value = "",
        allow_blank = true,
    },

    -- Per-player settings
    -- ===================

    {
        type = "string-setting",
        name = "asc-cluster-mode-player",
        setting_type = "runtime-per-user",
        order = "aa",
        default_value = "use-map-setting",
        allowed_values = {"use-map-setting", "spawner-only", "spawner-and-worms"},
    },

    {
        type = "bool-setting",
        name = "asc-verbose",
        order = "ab",
        setting_type = "runtime-per-user",
        default_value = false
    },

    {
        type = "bool-setting",
        name = "asc-cluster-single-target-fallback",
        order = "ab",
        setting_type = "runtime-per-user",
        default_value = false
    },

})
