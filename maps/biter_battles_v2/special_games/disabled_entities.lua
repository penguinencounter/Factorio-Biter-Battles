local mu = require "maps.biter_battles_v2.special_games.menu_utils"

local slot_prefix = mu.mk_prefix("disabled_entities_slot")

---@param evt EventData.on_gui_elem_changed
local function on_changed(evt)

end

---@type special.SpecialGamePlugin
local plugin = function(plugs)
    return {
        id = "disabled_entities",
        name = "Disable entities",
        const_init = function()
            plugs.change.register_early("disabled_entities", on_changed)
        end,
        enable = function(self, player_idx, list_itm)
            local options = mu.mk_options(list_itm, self.id)
            local grid_rows = options.add {
                type = "flow",
                direction = "vertical"
            }
            -- Up to 12 per row.
            ---@diagnostic disable-next-line: missing-fields
            mu.style(grid_rows, {
                vertical_spacing = 4,
                padding = 4,
            })
            local initial_row = grid_rows.add {
                type = "flow",
                direction = "horizontal"
            }
            ---@diagnostic disable-next-line: missing-fields
            mu.style(initial_row, {
                horizontal_spacing = 4
            })
            local button = initial_row.add {
                type = "choose-elem-button",
                elem_type = "item"
            }

            plugs.register_element(button, mu.UI_ids.editor)
        end,
        disable = function(self, player_idx, list_itm)
            mu.rm_options(list_itm, self.id)
        end
    }
end

return plugin
