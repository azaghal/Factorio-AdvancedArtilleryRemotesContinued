local new_ammo_categories = {}
local new_ammo = table.deepcopy(data.raw["ammo"])

for name, prototype in pairs(new_ammo) do
    if prototype.ammo_category == "artillery-shell" then
        if name ~= "artillery-shell" then
            new_ammo[name].ammo_category = name .. "-category"
            new_ammo_categories[name] = {
                type = "ammo-category",
                name = name .. "-category",
                icon = prototype.icon or "__base__/graphics/icons/ammo-category/artillery-shell.png",
                subgroup = "ammo-category",
            }
        end
    end
end

-- testing output
log(serpent.block(new_ammo_categories))

-- add new ammo categories
data:extend(new_ammo_categories)
data:extend(new_ammo)

-- make sure vanilla artillery turrets can use the new ammo categories
local artillery_turret = table.deepcopy(data.raw["item"]["artillery-turret"])
if artillery_turret and artillery_turret.attack_parameters and artillery_turret.attack_parameters.ammo_categories then
    artillery_turret.attack_parameters.ammo_category = nil
    table.insert(new_ammo_categories, "artillery-shell")
    artillery_turret.attack_parameters.ammo_categories = new_ammo_categories
end