local mu = require "maps.biter_battles_v2.special_games.utilities"

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

local NAMES = {
    reset = pfx("reset"),
    flow = pfx("flow")
}
for _, v in ipairs(pack_order) do
    NAMES[v] = pfx(v .. "_toggle")
end

---@type special.SpecialGamePlugin
local function plugin(plugs)
    ---@type special.SpecialGameSpec
    return {
        id = "disabled_throws",
        name = "Disable sciences",
        const_init = function(self)
            for _, name in pairs(NAMES) do
                plugs.const_register_name(name, mu.UI_ids.editor)
            end

            ---@param event EventData.on_gui_click
            plugs.on_click.const_register(NAMES.reset, function(event)
                local list_itm = plugs.find_list_item(event.element, self.id)
                if not list_itm then
                    error("couldn't figure out the list item!")
                end
                self:clear_data(event.player_index, list_itm)
            end, NAMES.reset)
            
            ---@param event EventData.on_gui_click
            local function handler(event)
                if not (event.element and event.element.valid) then return end
                local ec = plugs.get_player_storage(event.player_index).editor_conf
                local this_data = ec.disabled_throws
                local pack_info = event.element.tags.pack_name --[[@as string]]
                if not pack_info then return end
                this_data.packs[pack_info] = event.element.toggled
            end

            for _, v in ipairs(pack_order) do
                plugs.on_click.const_register(NAMES[v], handler, NAMES[v])
            end
        end,
        construct = function(self, player_idx, list_itm)
            local container, options, actionbar = mu.recreate_options(list_itm, pfx)
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
                name = NAMES.reset
            }

            local flow = options.add {
                type = "flow",
                direction = "horizontal",
                name = NAMES.flow
            }

            for _, v in ipairs(pack_order) do
                local toggle = flow.add {
                    type = "sprite-button",
                    sprite = "item/" .. v .. "-science-pack",
                    tooltip = { "item-name." .. v .. "-science-pack" },
                    state = false,
                    auto_toggle = true,
                    name = NAMES[v],
                    tags = {pack_name = v}
                }
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
            local button_set = options[NAMES.flow]
            if not button_set then return end

            for _, name in ipairs(pack_order) do
                local actual_state = data.packs[name]
                local toggle = button_set[NAMES[name]]
                toggle.toggled = actual_state
            end
        end
    }
end
return plugin
