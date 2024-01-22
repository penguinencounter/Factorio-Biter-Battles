-- "Custom Lua" special game (?)

local mu = require "maps.biter_battles_v2.special_games.menu_utils"

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

---@type special.SpecialGamePlugin
local plugin = function(plugs)
    ---@type special.SpecialGameSpec
    return {
        id = "arbitrary",
        name = "Custom Lua",
        const_init = function()

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
                name = pfx("reset")
            }
            local textfield = options.add {
                type = "text-box",
                text = "",
                name = pfx("code")
            }
            ---@diagnostic disable-next-line: missing-fields
            mu.style(textfield, {
                horizontally_stretchable = true,
                vertically_stretchable = true,
                natural_height = 0,
                minimal_height = 400,
                maximal_width = 9999999,
            })

            plugs.register_element(clear_button, mu.UI_ids.editor)
            -- this will overwrite the previous handler, if there is one
            plugs.click.register(clear_button.name, function()
                self:clear_data(player_idx, list_itm)
            end, pfx("reset"))
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
            local textfield = options[pfx("code")]
            if not textfield then return end
            textfield.text = data.code
        end
    }
end

return plugin
