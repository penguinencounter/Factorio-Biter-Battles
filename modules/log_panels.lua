local Global = require 'utils.global'
local Color = require 'utils.color_presets'
local Event = require 'utils.event'

local this = {
    all_events = {},
    events_by_position = {},
    next_id = 1
}
local Public = {}

Global.register(
    this,
    function(tbl)
        this = tbl
    end
)

--[[ Datasets ]]
local TARGETS = {
    [defines.relative_gui_type.rocket_silo_gui] = { --[[no properties]] }
}

local inverse_relative_gui_type = {}
for k, v in pairs(defines.relative_gui_type) do
    inverse_relative_gui_type[v] = k
end

--- @param gui_type defines.relative_gui_type
--- @return string
local function rel_gui_to_str(gui_type)
    return inverse_relative_gui_type[gui_type]
end

local entity_to_type = {
    ["rocket-silo"] = defines.relative_gui_type.rocket_silo_gui
}

--[[ Utilities ]]
--- @param entity LuaEntity
local function assign_id(entity)
    local tags = entity.tags or {}
    if tags.event_log_id then return end
    tags.event_log_id = this.next_id
    this.next_id = this.next_id + 1
    entity.tags = tags
    game.print("ID assigned: " .. tags.event_log_id .. " to " .. entity.name, Color.success)
end

--[[ UI ]]
---@param player LuaPlayer
---@param entity LuaEntity
---@param gui_type defines.relative_gui_type
local function track(player, entity, gui_type)
    local ui = player.gui.relative["bb_event_log_" .. rel_gui_to_str(gui_type)]
    if not ui then
        game.print("## Could not locate event log for " .. entity.name .. " ##", Color.fail)
        return
    end
    local main = ui.main.children[1] -- frame -> flow
    local status = main.status
    if not status then return end
    local status_icon = status.icon
    local status_label = status.label
    status_icon.sprite = "utility/status_yellow"
    status_label.caption = "Counting events..."
end

--- @param event EventData.on_gui_opened
local function on_gui_opened(event)
    if event.gui_type == defines.gui_type.entity then
        assign_id(event.entity)
        local entity_name = event.entity.name
        if not entity_to_type[entity_name] then return end
        local gui_type = entity_to_type[entity_name]
        local player = game.get_player(event.player_index)
        if not player then return end
        track(player, event.entity, gui_type)
    end
end


--- @param gui_type defines.relative_gui_type
--- @param player LuaPlayer
local function attach_logger_panel(player, gui_type)
    --- @type GuiAnchor
    local anchor = {
        gui = gui_type,
        position = defines.relative_gui_position.right
    }
    --- @type LuaGuiElement
    local window = player.gui.relative.add { type = "frame", anchor = anchor, name = "bb_event_log_" .. rel_gui_to_str(gui_type), direction =
    "vertical" }
    window.style.vertically_stretchable = true
    window.style.padding = { 4, 8, 8, 8 } -- t, r, b, l

    --[[ HEADER ]]
    do
        local window_title = "Event log"
        --- @type LuaGuiElement
        local title_flow = window.add { type = "flow", name = "title_flow" }
        title_flow.add { type = "label", caption = window_title, style = "frame_title" }
        --- @type LuaGuiElement
        local pusher = title_flow.add { type = "empty-widget" }
        pusher.style.horizontally_stretchable = true

        title_flow.add { type = "sprite-button", style = "frame_action_button", sprite = "utility/expand", name =
        "attached_log_expand" }
    end

    --[[ CONTENT ]]
    --- @type LuaGuiElement
    local content_container = window.add { type = "frame", style = "inside_shallow_frame_with_padding", direction =
    "vertical", name = "main" }
    content_container.style.vertically_stretchable = true
    --- @type LuaGuiElement
    local main_content = content_container.add { type = "flow", direction = "vertical" }
    main_content.style.vertical_spacing = 8

    --[[ Status bar and text ]]
    do
        --- @type LuaGuiElement
        local status = main_content.add { type = "flow", style = "status_flow", name = "status" }
        status.style.vertical_align = "center"
        --- @type LuaGuiElement
        local status_icon = status.add { type = "sprite", style = "status_image", name = "icon", sprite =
        "utility/status_not_working" }
        --- @type LuaGuiElement
        status.add { type = "label", caption = "Script loading error", name = "label" }
    end

    --[[ Event list ]]
    do
        --- @type LuaGuiElement
        local scroll_panel = main_content.add { type = "list-box", name = "event_list" }
        scroll_panel.style.minimal_width = 250
        scroll_panel.style.vertically_stretchable = true
    end

    --[[ Actions ]]
    do
        --- @type LuaGuiElement
        local action_set = main_content.add { type = "flow" }
        action_set.style.horizontal_spacing = 4 -- this is the default, but might want to tweak later
        action_set.style.horizontal_align = "left"
        action_set.style.horizontally_stretchable = true
        --- @type LuaGuiElement
        local clear_filters = action_set.add { type = "sprite-button", style = "tool_button", sprite = "utility/reset", tooltip =
        "Clear filters", name = "attached_log_clear_filters" }
        clear_filters.enabled = false
        local filter_type = action_set.add { type = "sprite-button", style = "tool_button_green", sprite =
        "utility/search_white", tooltip =
        "Show only this type of event", name = "attached_log_filter_type" }
        filter_type.enabled = false
        local exclude_type = action_set.add { type = "sprite-button", style = "tool_button_red", sprite =
        "utility/search_black", tooltip =
        "Exclude this type of event", name = "attached_log_exclude_type" }
        exclude_type.enabled = false

        --- @type LuaGuiElement
        local pusher = action_set.add { type = "empty-widget" }
        pusher.style.horizontally_stretchable = true

        --- @type LuaGuiElement
        local details_button = action_set.add { type = "button", style = "button", caption = "Details" }
        details_button.style.minimal_width = 0
        details_button.enabled = false
        details_button.style.minimal_width = 0
    end
end

--- @param event EventData.on_player_created
local function attach_panels(event)
    local player = game.get_player(event.player_index)

    if not player then return end
    for gui_type, tracked_items in pairs(TARGETS) do
        attach_logger_panel(player, gui_type)
    end
end

Event.add(defines.events.on_player_created, attach_panels)
Event.add(defines.events.on_gui_opened, on_gui_opened)
Event.add(defines.events.on_built_entity, assign_id)
