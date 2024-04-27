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

local SLOTS = 7

---@param data_store special.EditorConf
local function ensure_data(data_store)
    if not data_store.infinity_chest then clear_data(data_store) end
end

---@type special.SpecialGamePlugin
---@param plugs special.SpecialGamePluginData
return function(plugs)
    ---@type special.SpecialGameSpec
    return {
        id = "infinity_chest",
        name = "Infinity chest",
        const_init = function()

        end,
        construct = function(self, player_idx, list_itm)
            -- local container, options, actionbar = mu.recreate_options(list_itm, pfx)
            -- mu.spacer(actionbar.add { type = "empty-widget" })
            -- local clear = actionbar.add {
            --     type = "sprite-button",
            --     sprite = "utility/trash",
            --     tooltip = "Clear this section",
            --     style = "tool_button",
            --     name = pfx("reset")
            -- }
            -- plugs.register_element(clear, mu.UI_ids.editor)
            -- plugs.button_clicked.register(clear.name, function (evt)
            --     self:clear_data(player_idx, list_itm)
            -- end)
        end,
        enable = function(self, player_idx, list_itm)
        end,
        disable = function(self, player_idx, list_itm)
            -- mu.rm_options(list_itm, self.id)
        end,
        clear_data = function(self, player_idx, list_itm)

        end,
        refresh_ui = function(self, player_idx, list_itm)

        end
    }
end
