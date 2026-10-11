-- Works with the original HeroTurretRedux or its 2.1 fork HeroTurretsReduxFork (same entity names and icons).
local hero_mod = mods["HeroTurretsReduxFork"] and "HeroTurretsReduxFork" or mods["HeroTurretRedux"] and "HeroTurretRedux"
local icon = hero_mod and ("__" .. hero_mod .. "__/graphics/icons/hero-4-icon.png") or "__base__/graphics/icons/gun-turret.png"

data:extend({
  {
    type = "shortcut",
    name = "htr-restock",
    action = "lua",
    order = "z[htr]",
    icon = icon,
    icon_size = 64,
    small_icon = icon,
    small_icon_size = 64,
    toggleable = false,
  },
})
