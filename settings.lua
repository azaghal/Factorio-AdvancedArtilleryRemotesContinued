data:extend({
    {
        type = "bool-setting",
        name = "aar-verbose",
        order = "aa",
        setting_type = "runtime-global",
        default_value = true
    },
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
        type = "int-setting",
        name = "aar-merge-radius",
        setting_type = "runtime-global",
        order = "ad",
        default_value = 7,
        minimum_value = 1,
        maximum_value = 100,
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
})