local mu = require "maps.biter_battles_v2.special_games.menu_utils"

---@class special.disabled_throws.Data : special.ModuleData
---@field packs {automation: boolean, logistic: boolean, military: boolean, chemical: boolean, production: boolean, utility: boolean, space: boolean}

---@class special.EditorConf
---@field disabled_throws special.disabled_throws.Data

local pfx = mu.mk_prefix("special_editor_disabled_throws")
local pack_order = {
    "automation",
    "logistic",
    "military",
    "chemical",
    "production",
    "utility",
    "space",
}

---Reset per-player UI state.
---@param data_store special.EditorConf
local function clear_data(data_store)
    data_store.disabled_throws = {
        enabled = false,
        packs = {
            automation = false,
            logistic = false,
            military = false,
            chemical = false,
            production = false,
            utility = false,
            space = false,
        }
    }
end

local function ensure_data(data_store)
    if not data_store.disabled_throws then clear_data(data_store) end
end

---@type special.SpecialGamePlugin
local function plugin(plugs)
    ---@type special.SpecialGameSpec
    return {
        id = "disabled_throws",
        name = "Disable sciences",
        const_init = function()

        end,
        construct = function(self, player_idx, list_itm)
            local old_container = mu.get_options(list_itm, pfx)
            if old_container then old_container.destroy() end

            local container, options, actionbar = mu.mk_options(list_itm, pfx)
            mu.style(actionbar.add {
                type = "label",
                caption = "Select the sciences you want to disable."
            }, { ---@diagnostic disable-line: missing-fields
                left_margin = 4
            })
            mu.spacer(actionbar.add { type = "empty-widget" })
            local clear_button = actionbar.add {
                type = "sprite-button",
                sprite = "utility/trash",
                tooltip = "Clear this section",
                style = "tool_button",
                name = pfx("reset")
            }
            
            plugs.register_element(clear_button, mu.UI_ids.editor)
            plugs.button_clicked.register(clear_button.name, function (evt)
                self:clear_data(player_idx, list_itm)
            end, pfx("reset"))

            local flow = options.add {
                type = "flow",
                direction = "horizontal",
                name = pfx("flow")
            }

            for _, v in ipairs(pack_order) do
                local toggle = flow.add {
                    type = "sprite-button",
                    sprite = "item/" .. v .. "-science-pack",
                    tooltip = { "item-name." .. v .. "-science-pack" },
                    state = false,
                    auto_toggle = true,
                    name = pfx(v)
                }
                plugs.register_element(toggle, mu.UI_ids.editor)
            end
            container.visible = false
        end,
        enable = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            ec.disabled_throws.enabled = true

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
            ec.disabled_throws.enabled = false

            local container = mu.get_options(list_itm, pfx)
            if not container then return end
            container.visible = false
        end,
        clear_data = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            local was_enabled = ec.disabled_throws.enabled
            clear_data(ec)
            ec.disabled_throws.enabled = was_enabled
            self:refresh_ui(player_idx, list_itm)
        end,
        refresh_ui = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            local data = ec.disabled_throws

            if data.enabled then
                self:enable(player_idx, list_itm)
            else
                self:disable(player_idx, list_itm)
            end

            local container, options, actionbar = mu.get_options(list_itm, pfx)
            if not options then return end
            local button_set = options[pfx("flow")]
            if not button_set then return end

            for _, name in ipairs(pack_order) do
                local actual_state = data.packs[name]
                local toggle = button_set[pfx(name)]
                toggle.toggled = actual_state
            end
        end
    }
end
return plugin
