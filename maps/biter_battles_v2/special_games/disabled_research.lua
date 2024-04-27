local mu = require "maps.biter_battles_v2.special_games.utilities"

local slot_prefix = mu.mk_prefix("disabled_research_slot")

---@class special.disabled_research.Data : special.ModuleData
---@field north_enabled boolean
---@field south_enabled boolean
---@field entity_list string[]

---@class special.EditorConf
---@field disabled_research special.disabled_research.Data

---Reset per-player UI state.
---@param data_store special.EditorConf
local function clear_data(data_store)
    data_store.disabled_research = {
        enabled = false,
        entity_list = {},
        north_enabled = true,
        south_enabled = true,
    }
end

local function ensure_data(data_store)
    if not data_store.disabled_research then clear_data(data_store) end
end

---Delete nils from a list.
---@param tabl table
---@param size integer
---@return table
local function flatten(tabl, size)
    local result = {}
    for i = 1, size do
        if tabl[i] then
            result[#result + 1] = tabl[i]
        end
    end
    return result
end

---@param data_store special.EditorConf
---@param slot_container LuaGuiElement
---@param register_func fun(elem: LuaGuiElement, target: special.UI_ids)
local function rebuild_slots(data_store, slot_container, register_func)
    local entity_list = data_store.disabled_research.entity_list
    -- Not the most efficient
    slot_container.clear()

    -- add 1 more slot than needed, so that there's a space to add a new one
    for i = 1, #entity_list + 1 do
        local row_no = math.floor((i - 1) / 12)
        local row = slot_container[slot_prefix("row_" .. row_no)]
        if not row then
            row = slot_container.add {
                type = "flow",
                direction = "horizontal",
                name = slot_prefix("row_" .. row_no)
            }
            ---@diagnostic disable-next-line: missing-fields
            mu.style(row, {
                horizontal_spacing = 4
            })
        end
        local slot = row.add {
            type = "choose-elem-button",
            elem_type = "technology",
            name = slot_prefix(tostring(i))
        }
        register_func(slot, mu.UI_ids.editor)
        slot.elem_value = entity_list[i]
    end
end

local prefixer = mu.mk_prefix("disabled_research")

local NAMES = {
    actionbar_flow = prefixer("actionbar_flow"),
    north = prefixer("north"),
    south = prefixer("south"),
    reset = prefixer("reset"),
    grid_rows = prefixer("grid_rows"),
}

---@type special.SpecialGamePlugin
local plugin = function(plugs)
    ---@param evt EventData.on_gui_elem_changed
    local function on_changed(evt)
        if not (evt.element and evt.element.valid) then return end
        local nmatch = evt.element.name:match("^" .. slot_prefix("(%d+)$"))
        if nmatch then
            local cfg = plugs.get_player_storage(evt.player_index).editor_conf
            local size = #cfg.disabled_research.entity_list + 1
            cfg.disabled_research.entity_list[tonumber(nmatch)] = evt.element.elem_value --[[@as string]]
            cfg.disabled_research.entity_list = flatten(cfg.disabled_research.entity_list, size)
            rebuild_slots(cfg, evt.element.parent.parent, plugs.register_element)
            return true
        end
    end

    ---@type special.SpecialGameSpec
    return {
        id = "disabled_research",
        name = "Disable research",
        const_init = function(self)
            for _, name in pairs(NAMES) do
                plugs.const_register_name(name, mu.UI_ids.editor)
            end
            plugs.picker_changed.const_register_early("disabled_research", on_changed)
            plugs.on_click.const_register(NAMES.reset, function(evt)
                local list_itm = plugs.find_list_item(evt.element, self.id)
                if not list_itm then
                    error("couldn't figure out the list item!")
                end
                self:clear_data(evt.player_index, list_itm)
            end, NAMES.reset)
        end,
        construct = function(self, player_idx, list_itm)
            local old_container = mu.get_options(list_itm, prefixer)
            if old_container then old_container.destroy() end

            local container, options, actionbar = mu.mk_options(list_itm, prefixer)
            local actionbar_flow = actionbar.add {
                type = "flow",
                direction = "horizontal",
                name = NAMES.actionbar_flow
            }
            ---@diagnostic disable-next-line: missing-fields
            mu.style(actionbar_flow, {
                horizontally_stretchable = true,
                natural_width = 0,
                horizontal_spacing = 8,
                padding = { 0, 4 },
                vertical_align = "center",
            })
            local north_checkbox = actionbar_flow.add {
                type = "checkbox",
                caption = "North",
                state = false,
                name = NAMES.north
            }
            local south_checkbox = actionbar_flow.add {
                type = "checkbox",
                caption = "South",
                state = false,
                name = NAMES.south
            }
            mu.spacer(actionbar.add { type = "empty-widget" })
            local erase_button = actionbar.add {
                type = "sprite-button",
                sprite = "utility/trash",
                tooltip = "Clear this section",
                style = "tool_button",
                name = NAMES.reset
            }

            local grid_rows = options.add {
                type = "flow",
                direction = "vertical",
                name = NAMES.grid_rows
            }
            -- Up to 12 per row.
            ---@diagnostic disable-next-line: missing-fields
            mu.style(grid_rows, {
                vertical_spacing = 4,
                padding = 4,
            })
            container.visible = false
        end,
        enable = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            ec.disabled_research.enabled = true

            local container = mu.get_options(list_itm, prefixer)
            if not container then
                self:construct(player_idx, list_itm)
                container = mu.get_options(list_itm, prefixer)
                if not container then
                    error("Failed to construct options for " .. self.id)
                end
            end
            container.visible = true
        end,
        disable = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            ec.disabled_research.enabled = false

            local container = mu.get_options(list_itm, prefixer)
            if not container then return end
            container.visible = false
        end,
        clear_data = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            local was_enabled = ec.disabled_research.enabled
            clear_data(ec)
            ec.disabled_research.enabled = was_enabled
            self:refresh_ui(player_idx, list_itm)
        end,
        refresh_ui = function(self, player_idx, list_itm)
            local ec = plugs.get_player_storage(player_idx).editor_conf
            ensure_data(ec)
            local data = ec.disabled_research

            if data.enabled then
                self:enable(player_idx, list_itm)
            else
                self:disable(player_idx, list_itm)
            end

            local container, options, actionbar = mu.get_options(list_itm, prefixer)
            if not (options and options.valid) then
                print("invalid options")
                return
            end
            if not (actionbar and actionbar.valid) then
                print("invalid actionbar")
                return
            end

            local north_checkbox = actionbar[NAMES.actionbar_flow][NAMES.north]
            if not (north_checkbox and north_checkbox.valid) then
                print("Invalid north checkbox")
                return
            end

            local south_checkbox = actionbar[NAMES.actionbar_flow][NAMES.south]
            if not (south_checkbox and south_checkbox.valid) then
                print("Invalid south checkbox")
                return
            end

            north_checkbox.state = data.north_enabled
            south_checkbox.state = data.south_enabled

            rebuild_slots(ec, options[NAMES.grid_rows], plugs.register_element)
        end
    }
end

return plugin
