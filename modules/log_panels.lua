local Global = require 'utils.global'
local Color = require 'utils.color_presets'
local Event = require 'utils.event'

local this = {
    events = {},
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
local GUI_TYPE_TO_STRING = {
    [defines.relative_gui_type.accumulator_gui] = "accumulator",
    [defines.relative_gui_type.achievement_gui] = "achievement",
    [defines.relative_gui_type.additional_entity_info_gui] = "additional_entity_info",
    [defines.relative_gui_type.admin_gui] = "admin",
    [defines.relative_gui_type.arithmetic_combinator_gui] = "artihmetic_combinator",
}

--- @param gui_type defines.relative_gui_type
--- @param player LuaPlayer
local function attach_logger_panel(player, gui_type, tracks)
    --- @type GuiAnchor
    local anchor = {
        gui = gui_type,
        position = defines.relative_gui_position.right
    }
    --- @type LuaGuiElement
    local window = player.gui.relative.add { type = "frame", anchor = anchor, name = "bb_event_log_"..gui_type, direction =
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
        status.add { type = "label", caption = "Loading events...", name = "label" }
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
        local filter_type = action_set.add { type = "sprite-button", style = "tool_button_green", sprite = "utility/search_white", tooltip =
        "Show only this type of event", name = "attached_log_filter_type" }
        filter_type.enabled = false
        local exclude_type = action_set.add { type = "sprite-button", style = "tool_button_red", sprite = "utility/search_black", tooltip =
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
        attach_logger_panel(player, gui_type, tracked_items)
    end
end

Event.add(defines.events.on_player_created, attach_panels)
Event.add(defines.events.on_gui_opened, attach_panels)
