-- "Custom Lua" special game (?)

local mu = require "maps.biter_battles_v2.special_games.utilities"

local pfx = mu.mk_prefix("special_editor_arbitrary")

---@class special.arbitrary.Data : special.ModuleData
---@field code string

---@class special.EditorConf
---@field arbitrary special.arbitrary.Data

---Reset per-player UI state.
---@param data_store special.EditorConf
local function clear_data(data_store)
    data_store.arbitrary = {
        enabled = false,
        code = ""
    }
end

local function ensure_data(data_store)
    if not data_store.arbitrary then clear_data(data_store) end
end

local NAMES = {
    clear_button = pfx("reset"),
    textfield = pfx("code")
}

---@type special.SpecialGamePlugin
local plugin = function(plugs)
    ---@type special.SpecialGameSpec
    return {
        id = "arbitrary",
        name = "Custom Lua",
        const_init = function(self)
            for _, name in pairs(NAMES) do
                plugs.const_register_name(name, mu.UI_ids.editor)
            end

            ---@param event EventData.on_gui_click
            plugs.on_click.const_register(NAMES.clear_button, function(event)
                local list_itm = plugs.find_list_item(event.element, self.id)
                if not list_itm then
                    error("couldn't figure out the list item!")
                end
                self:clear_data(event.player_index, list_itm)
            end, pfx("reset"))
        end,
        construct = function(self, player_idx, list_itm)
            local old_container = mu.get_options(list_itm, pfx)
            if old_container then old_container.destroy() end

            local container, options, actionbar = mu.mk_options(list_itm, pfx)
            mu.spacer(actionbar.add { type = "empty-widget" })
            local clear_button = actionbar.add {
                type = "sprite-button",
                sprite = "utility/trash",
                tooltip = "Clear this section",
                style = "tool_button",
                name = NAMES.clear_button
            }
            local textfield = options.add {
                type = "text-box",
                text = "",
                name = NAMES.textfield
            }
            ---@diagnostic disable-next-line: missing-fields
            mu.style(textfield, {
                horizontally_stretchable = true,
                vertically_stretchable = true,
                natural_height = 0,
                minimal_height = 400,
                maximal_width = 9999999,
            })
            container.visible = false
        end,
        enable = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            ec.arbitrary.enabled = true

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
            ec.arbitrary.enabled = false

            local container = mu.get_options(list_itm, pfx)
            if not container then return end
            container.visible = false
        end,
        clear_data = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            local was_enabled = ec.arbitrary.enabled
            clear_data(ec)
            ec.arbitrary.enabled = was_enabled
            self:refresh_ui(player_idx, list_itm)
        end,
        refresh_ui = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            local data = ec.arbitrary

            if data.enabled then
                self:enable(player_idx, list_itm)
            else
                self:disable(player_idx, list_itm)
            end

            local container, options, actionbar = mu.get_options(list_itm, pfx)
            if not options then return end
            local textfield = options[NAMES.textfield]
            if not textfield then return end
            textfield.text = data.code
        end
    }
end

return plugin
