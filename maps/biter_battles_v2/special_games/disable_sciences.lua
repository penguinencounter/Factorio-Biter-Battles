local mu = require "maps.biter_battles_v2.special_games.menu_utils"

---@class special.disabled_throws.Data : special.ModuleData

---@class special.EditorConf
---@field disabled_throws special.disabled_throws.Data

---@type special.disabled_throws.Data
local data_default = {
    enabled = false
}

local function refresh_slots()

end

---@type special.SpecialGamePlugin
local function plugin(plugs)
    return {
        id = "disabled_throws",
        name = "Disable sciences",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ec.disabled_throws = ec.disabled_throws or data_default
            ec.disabled_throws.enabled = true
        end,
        disable = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ec.disabled_throws = ec.disabled_throws or data_default
            ec.disabled_throws.enabled = false
            mu.rm_options(list_itm, self.id)
        end
    }
end
return plugin
