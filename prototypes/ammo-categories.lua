local new_ammo_categories = {}
local new_ammo = {}
local new_ammo_category_names = {}

-- iterate over existing ammo prototypes and create modified copies as an array
for name, prototype in pairs(data.raw["ammo"]) do
    if prototype and prototype.ammo_category == "artillery-shell" then
        if name ~= "artillery-shell" then
            local copy = table.deepcopy(prototype)
            copy.ammo_category = name .. "-category"
            table.insert(new_ammo, copy)

            table.insert(new_ammo_categories, {
                type = "ammo-category",
                name = name .. "-category",
                icon = prototype.icon or "__base__/graphics/icons/ammo-category/artillery-shell.png",
                icon_size = prototype.icon_size or 64,
                subgroup = "ammo-category",
            })

            table.insert(new_ammo_category_names, name .. "-category")
        end
    end
end

-- testing output
log(serpent.block(new_ammo_categories))
log(serpent.block(new_ammo))

-- add new ammo categories and modified ammo prototypes
data:extend(new_ammo_categories)
data:extend(new_ammo)

-- make sure vanilla artillery turrets can use the new ammo categories
local artillery_turret = data.raw["gun"] and table.deepcopy(data.raw["gun"]["artillery-wagon-cannon"]) or nil
if artillery_turret and artillery_turret.attack_parameters then
    artillery_turret.attack_parameters.ammo_category = nil
    local allowed = {"artillery-shell"}
    for _, n in ipairs(new_ammo_category_names) do table.insert(allowed, n) end
    artillery_turret.attack_parameters.ammo_categories = allowed
    data:extend({artillery_turret})
end