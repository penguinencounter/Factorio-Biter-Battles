local mu = require "maps.biter_battles_v2.special_games.utilities"

---@type special.SpecialGamePlugin
return function(plugs)
    return {
        id = "turtle",
        name = "Turtle moat",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            local container, options = mu.mk_options(list_itm, self.id)
            options.add {
                type = "label",
                caption = "Turtle options placeholder",
            }
        end,
        disable = function(self, player_idx, list_itm)
            mu.rm_options(list_itm, self.id)
        end
    }
end
