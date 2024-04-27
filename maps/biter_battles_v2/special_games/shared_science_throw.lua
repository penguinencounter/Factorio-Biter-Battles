local mu = require "maps.biter_battles_v2.special_games.utilities"

---@type special.SpecialGamePlugin
return function(plugs)
    return {
        id = "shared_science_throw",
        name = "Share sent science",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            -- there are no options, this is just a toggle
        end,
        disable = function(self, player_idx, list_itm)
        end
    }
end
