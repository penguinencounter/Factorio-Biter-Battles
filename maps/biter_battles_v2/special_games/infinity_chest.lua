local mu = require "maps.biter_battles_v2.special_games.menu_utils"

---@type special.SpecialGamePlugin
return function(plugs)
    return {
        id = "infinity_chest",
        name = "Infinity chest",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            local container, options = mu.mk_options(list_itm, self.id)
            options.add {
                type = "label",
                caption = "infinity chest options placeholder",
            }
        end,
        disable = function(self, player_idx, list_itm)
            mu.rm_options(list_itm, self.id)
        end
    }
end
