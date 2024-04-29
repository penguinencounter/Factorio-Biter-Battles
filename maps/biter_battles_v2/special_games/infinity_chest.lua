local mu = require "maps.biter_battles_v2.special_games.utilities"

---@class special.infinity_chest.Data : special.ModuleData
---@field slots LuaItemStack[]

---@class special.EditorConf
---@field infinity_chest special.infinity_chest.Data

local pfx = mu.mk_prefix("special_editor_infinity_chest")

---Reset per-player UI state.
---@param data_store special.EditorConf
local function clear_data(data_store)
    data_store.infinity_chest = {
        enabled = false,
        slots = {}
    }
end

local SLOTS = 21

local NAMES = {
    reset = pfx("reset")
}
for i = 1, SLOTS do
    NAMES[i] = pfx("slot_" .. i)
end

---@param data_store special.EditorConf
local function ensure_data(data_store)
    if not data_store.infinity_chest then clear_data(data_store) end
end

---@type special.SpecialGamePlugin
---@param plugs special.PluginAPIV2
return function(plugs)
    ---@type special.SpecialGameSpec
    return {
        id = "infinity_chest",
        name = "Infinity chest",
        const_init = function(self)
            for _, name in pairs(NAMES) do
                plugs.const_register_name(name, mu.UI_ids.editor)
            end

            ---@param evt EventData.on_gui_click
            plugs.on_click.const_register(NAMES.reset, function(evt)
                local list_itm = plugs.find_list_item(evt.element, self.id)
                if not list_itm then error("couldn't figure out the list item!") end
                self:clear_data(evt.player_index, list_itm)
            end, NAMES.reset)
        end,
        construct = function(self, player_idx, list_itm)
            local container, options, actionbar = mu.recreate_options(list_itm, pfx)
            mu.spacer(actionbar.add { type = "empty-widget" })
            local clear = actionbar.add {
                type = "sprite-button",
                sprite = "utility/trash",
                tooltip = "Clear this section",
                style = "tool_button",
                name = NAMES.reset
            }

            local grid = options.add {
                type = "flow",
                direction = "vertical",
                name = NAMES.grid_rows
            }

            local function orentation_label(text)
                local label_container = grid.add {
                    type = "flow",
                    direction = "horizontal"
                }
                label_container.add {
                    type = "label",
                    caption = text
                }
                ---@diagnostic disable-next-line: missing-fields
                mu.style(label_container, {
                    horizontally_stretchable = true,
                    padding = 4,
                    horizontal_align = "center"
                })
            end

            orentation_label("Closest to river")

            ---@diagnostic disable-next-line: missing-fields
            mu.style(grid, {
            })
            local row
            for i = 1, SLOTS do
                if i % 7 == 1 then
                    row = grid.add {
                        type = "flow",
                        direction = "horizontal"
                    }
                    ---@diagnostic disable-next-line: missing-fields
                    mu.style(row, {
                        horizontally_stretchable = true,
                        padding = 0,
                        horizontal_align = "center"
                    })
                end
                row.add {
                    type = "choose-elem-button",
                    elem_type = "item",
                    item = "iron-plate",
                    name = NAMES[i]
                }
            end

            orentation_label("Farthest from river")

            container.visible = false
        end,
        enable = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            ec.infinity_chest.enabled = true
            local container = mu.get_options(list_itm, pfx)
            if not container then
                self:construct(player_idx, list_itm)
                container = mu.get_options(list_itm, pfx)
                if not container then
                    error("Failed to construct options for " .. self.id)
                end
            end
            container.visible = true
        end,
        disable = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            ec.infinity_chest.enabled = false

            local container = mu.get_options(list_itm, pfx)
            if not container then return end
            container.visible = false
        end,
        clear_data = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            local was_enabled = ec.infinity_chest.enabled
            clear_data(ec)
            ec.infinity_chest.enabled = was_enabled
            self:refresh_ui(player_idx, list_itm)
        end,
        refresh_ui = function(self, player_idx, list_itm)

        end
    }
end
