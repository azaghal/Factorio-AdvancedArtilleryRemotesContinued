-- Copyright (c) 2020 Dockmeister
-- Copyright (c) 2022 Branko Majic
-- Provided under MIT license. See LICENSE for details.


for index, force in pairs(game.forces) do
  if force.technologies["artillery"] ~= nil and force.technologies["artillery"].researched then
    force.recipes["artillery-cluster-remote"].enabled = true
    force.recipes["artillery-discovery-remote"].enabled = true
  end
end
