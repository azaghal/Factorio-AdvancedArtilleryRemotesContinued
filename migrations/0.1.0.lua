for index, force in pairs(game.forces) do
  if force.technologies["artillery"] ~= nil and force.technologies["artillery"].researched then
    force.recipes["artillery-cluster-remote"].enabled = true
    force.recipes["artillery-discovery-remote"].enabled = true
  end
end