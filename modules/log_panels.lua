local Global = require 'utils.global'
local Color = require 'utils.color_presets'
local Event = require 'utils.event'


--- @alias PartialLogData.type
--- | "script"
--- | "built_entity"
--- | "marked_for_deconstruction"
--- | "cancelled_deconstruction"
--- | "player_fast_transferred"
--- | "robot_built_entity"

--- @class PartialLogData
--- @field public type PartialLogData.type
--- @field public actor integer?

--- @class ScriptLogData : PartialLogData
--- @field public type "script"
--- @field public extra_info table<string, any>

--- @class BuiltEntityLogData : PartialLogData
--- @field public type "built_entity"
--- @field public created_entity integer

--- @class MarkedForDeconstructionLogData : PartialLogData
--- @field public type "marked_for_deconstruction"
--- @field public entity integer

--- @class CancelledDeconstructionLogData : PartialLogData
--- @field public type "cancelled_deconstruction"
--- @field public entity integer

--- @class PlayerFastTransferredLogData : PartialLogData
--- @field public type "player_fast_transferred"
--- @field public give boolean
--- @field public split boolean
--- @field public entity integer

--- @class RobotBuiltEntityLogData : PartialLogData
--- @field public type "robot_built_entity"
--- @field public created_entity integer

--- @class LogData : PartialLogData
--- @field public order integer

local this = {
    --- @type table<integer, LogData>
    all_events = {},
    --- @type LogData[]
    all_events_squashed = {},
    --- @type table<integer, LogData[]>
    events_by_entity = {},
    next = 1,
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
    [defines.relative_gui_type.rocket_silo_gui] = {},
    [defines.relative_gui_type.furnace_gui] = {},
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
    ["rocket-silo"] = defines.relative_gui_type.rocket_silo_gui,
    ["stone-furnace"] = defines.relative_gui_type.furnace_gui,
    ["steel-furnace"] = defines.relative_gui_type.furnace_gui,
    ["electric-furnace"] = defines.relative_gui_type.furnace_gui,
}

--[[ Utilities ]]
--- @param entity LuaEntity
--- @return boolean
local function trackable(entity)
    if not entity.valid then return false end
    if not entity.unit_number then return false end
    this.events_by_entity[entity.unit_number] = this.events_by_entity[entity.unit_number] or {}
    return true
end

--- @param color Color
--- @return string
local function format_color_tag(color)
    return "[color=" .. color.r .. "," .. color.g .. "," .. color.b .. "]"
end

local info_colors = {
    deconstruct = format_color_tag { r = 1, g = 0.5, b = 0.5 },
    cancel_deconstruct = format_color_tag { r = 0.5, g = 1, b = 0.5 },
    insert = format_color_tag { r = 0.5, g = 0.75, b = 1 },
    extract = format_color_tag { r = 1, g = 0.75, b = 0.5 },
}

--- @return integer
local function next()
    local nnext = this.next
    this.next = this.next + 1
    return nnext
end

---Push an event into various lists.
---@param entity_no integer
---@param event PartialLogData
---@return LogData
local function push_event(entity_no, event)
    local id = next()
    log("event added to " .. entity_no .. ": " .. serpent.line(event))
    event.order = id
    ---@cast event LogData
    this.all_events[id] = event
    table.insert(this.all_events_squashed, event)
    table.insert(this.events_by_entity[entity_no], event)
    return event
end

--- Get player name and color.
--- @param player_index integer?
--- @param default_name string
--- @param default_color Color
--- @return string, Color
local function get_name_col(player_index, default_name, default_color)
    --- @cast player_index uint
    local player = player_index ~= nil and game.get_player(player_index) or nil
    if not player then return default_name, default_color end
    return player.name, player.color
end

--[[ UI ]]
local render = {}
--- @param event BuiltEntityLogData
--- @return string
function render.built_entity(event)
    local player_name, player_color = get_name_col(event.actor, "<unknown>", { r = 0.5, g = 0.5, b = 0.5 })
    return format_color_tag(player_color) .. player_name .. "[/color] built"
end

--- @param event MarkedForDeconstructionLogData
function render.marked_for_deconstruction(event)
    local player_name, player_color = get_name_col(event.actor, "<script>", { r = 0.5, g = 0.5, b = 0.5 })
    return format_color_tag(player_color) .. player_name .. "[/color] " .. info_colors.deconstruct .. "+deconstruct[/color]"
end

--- @param event CancelledDeconstructionLogData
function render.cancelled_deconstruction(event)
    local player_name, player_color = get_name_col(event.actor, "<script>", { r = 0.5, g = 0.5, b = 0.5 })
    return format_color_tag(player_color) .. player_name .. "[/color] " .. info_colors.cancel_deconstruct .. "-deconstruct[/color]"
end

--- @param event PlayerFastTransferredLogData
function render.player_fast_transferred(event)
    local player_name, player_color = get_name_col(event.actor, "<unknown>", { r = 0.5, g = 0.5, b = 0.5 })
    local text_color = event.give and info_colors.insert or info_colors.extract
    local term = event.give and "inserted" or "extracted"
    return format_color_tag(player_color) .. player_name .. "[/color] " .. text_color .. term .. " items[/color]"
end

--- @param event RobotBuiltEntityLogData
function render.robot_built_entity(event)
    local player_name, player_color = get_name_col(event.actor, "<unknown>", { r = 0.5, g = 0.5, b = 0.5 })
    return format_color_tag(player_color) .. player_name .. "[/color] built (robot)"
end

---@param player LuaPlayer
---@param entity LuaEntity
---@param gui_type defines.relative_gui_type
local function track(player, entity, gui_type)
    local ui = player.gui.relative["bb_event_log_" .. rel_gui_to_str(gui_type)]
    if not ui then
        game.print("## Could not locate event log for " .. entity.name .. " ##", Color.fail)
        return
    end
    local main = ui.subwindows.selection.children[1] -- frame -> flow
    local status = main.status
    if not status then return end
    local status_icon = status.icon
    local status_label = status.label
    status_icon.sprite = "utility/status_yellow"
    status_label.caption = "? events"

    local event_list = main.event_list_container.children[1].children[1] -- frame -> scroll-pane -> flow
    event_list.clear()

    log("got " .. #this.events_by_entity[entity.unit_number] .. " events for " .. entity.unit_number .. ": " .. serpent.line(this.events_by_entity[entity.unit_number]))
    --- @type LogData[]
    local ordered_list = {}
    for _, event in ipairs(this.events_by_entity[entity.unit_number]) do
        -- reverse order
        table.insert(ordered_list, 1, event)
    end

    for _, event in ipairs(ordered_list) do
        local event_button = event_list.add { type = "button", caption = "#" .. event.order .. " " .. render[event.type](event), style = "frame_button" }
        event_button.style.font_color = { r = 1, g = 1, b = 1 }
        event_button.style.horizontally_stretchable = true
        event_button.style.horizontal_align = "left"
        event_button.style.padding = { 0, 8 }
        event_button.style.minimal_width = 0
    end
    status_icon.sprite = "utility/status_working"
    status_label.caption = "[font=default-bold]" .. #ordered_list .. "[/font] events"
end

--- @param event EventData.on_gui_opened
local function on_gui_opened(event)
    if event.gui_type == defines.gui_type.entity then
        if not trackable(event.entity) then return end
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
    local window = player.gui.relative.add { type = "frame", anchor = anchor, name = "bb_event_log_" ..
        rel_gui_to_str(gui_type), direction =
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
    local subwindows = window.add { type = "flow", direciton = "horizontal", name = "subwindows" }
    subwindows.style.vertically_stretchable = true
    subwindows.style.horizontal_spacing = 8

    --[[ Selection container ]]
    do
        --- @type LuaGuiElement
        local selection_container = subwindows.add { type = "frame", style = "inside_shallow_frame_with_padding", direction =
        "vertical", name = "selection" }
        selection_container.style.vertically_stretchable = true
        --- @type LuaGuiElement
        local main_selection = selection_container.add { type = "flow", direction = "vertical" }
        main_selection.style.vertical_spacing = 8

        --[[ Status bar and text ]]
        do
            --- @type LuaGuiElement
            local status = main_selection.add { type = "flow", style = "status_flow", name = "status" }
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
            local scroll_panel_container = main_selection.add { type = "frame", name = "event_list_container", direction =
            "vertical", style = "deep_frame_in_shallow_frame" }
            scroll_panel_container.style.vertically_stretchable = true
            --- @type LuaGuiElement
            local scroll_panel = scroll_panel_container.add { type = "scroll-pane", name = "event_list_scroll", direction =
            "vertical", horizontal_scroll_policy = "never", vertical_scroll_policy = "always" }
            scroll_panel.style.vertically_stretchable = true
            scroll_panel.style.horizontally_stretchable = true
            scroll_panel.style.extra_padding_when_activated = 0
            scroll_panel.style.extra_margin_when_activated = 0
            -- scroll_panel.style.vertical_spacing = 0 -- causes error
            scroll_panel.style.padding = 0 --?
            --- @type LuaGuiElement
            local event_list = scroll_panel.add { type = "flow", name = "event_list", direction = "vertical" }
            event_list.style.vertically_stretchable = true
            event_list.style.horizontally_stretchable = true
            event_list.style.minimal_width = 250
            event_list.style.natural_width = 250
            event_list.style.vertical_spacing = 0

            -- for i = 1,50 do
            --     --- @type LuaGuiElement
            --     local x = event_list.add { type = "button", caption = "#" .. i .. " " .. format_color_tag(player.color) .. player.name .. "[/color] touched", style = "frame_button" }
            --     x.style.font_color = { r = 1, g = 1, b = 1 }
            --     x.style.horizontally_stretchable = true
            --     x.style.horizontal_align = "left"
            --     x.style.padding = { 0, 8 }
            --     x.style.minimal_width = 0
            -- end
        end

        --[[ Actions ]]
        do
            --- @type LuaGuiElement
            local action_set = main_selection.add { type = "flow" }
            action_set.style.horizontal_spacing = 4 -- this is the default, but might want to tweak later
            action_set.style.horizontal_align = "left"
            action_set.style.vertical_align = "center"
            action_set.style.horizontally_stretchable = true
            --- @type LuaGuiElement
            local refresh = action_set.add { type = "sprite-button", style = "tool_button", sprite = "utility/reset", tooltip =
            "Refresh list", name = "attached_log_refresh" }
            refresh.enabled = true
            --- @type LuaGuiElement
            local clear_filter = action_set.add { type = "sprite-button", style = "tool_button", sprite = "utility/trash", tooltip =
            "Clear filters", name = "attached_log_clear_filter" }
            clear_filter.enabled = true

            --- @type LuaGuiElement
            local pusher = action_set.add { type = "empty-widget" }
            pusher.style.horizontally_stretchable = true

            --- @type LuaGuiElement
            local previous_page = action_set.add { type = "button", style = "tool_button", caption = "<", tooltip =
            "Previous page", name = "attached_log_prev_page" }
            previous_page.enabled = false
            --- @type LuaGuiElement
            local page_no = action_set.add { type = "label", caption = "1/1", name = "attached_log_page_no" }
            --- @type LuaGuiElement
            local next_page = action_set.add { type = "button", style = "tool_button", caption = ">", tooltip =
            "Next page", name = "attached_log_next_page" }
            next_page.enabled = false
        end
    end

    --[[ Details container ]]
    do
        --- @type LuaGuiElement
        local details_container = subwindows.add { type = "frame", style = "inside_shallow_frame_with_padding", direction =
        "vertical", name = "details" }
        -- details_container.visible = false
        details_container.style.vertically_stretchable = true
        --- @type LuaGuiElement
        local main_details = details_container.add { type = "flow", direction = "vertical" }
        main_details.style.vertical_spacing = 8
        main_details.style.minimal_width = 250
        --- @type LuaGuiElement
        local event_title = main_details.add { type = "label", caption = "Logged event #???", name = "event_title", style =
        "heading_2_label" }
        event_title.style.top_margin = -4

        --- @type LuaGuiElement
        local detail_table = main_details.add { type = "table", column_count = 5, name =
        "details" }
        detail_table.style.vertical_spacing = 4
        -- detail_table.style.natural_height = 0
        -- detail_table.style.minimal_height = 0
        detail_table.style.vertically_stretchable = true
        detail_table.style.horizontally_stretchable = true

        --[[ Actor ]]
        do
            detail_table.add { type = "label", caption = "Actor: " }
            detail_table.add { type = "label", caption = "unknown", style = "bold_label", name =
            "attached_log_event_actor" }

            local pusher = detail_table.add { type = "empty-widget" }
            pusher.style.horizontally_stretchable = true

            detail_table.add { type = "sprite-button", style = "tool_button_green", sprite =
            "utility/search_white", tooltip =
            "Show only this actor's events", name = "attached_log_filter_actor" }

            detail_table.add { type = "sprite-button", style = "tool_button_red", sprite =
            "utility/search_black", tooltip =
            "Exclude this actor's events", name = "attached_log_exclude_actor" }
        end

        --[[ Type ]]
        do
            detail_table.add { type = "label", caption = "Type: " }
            detail_table.add { type = "label", caption = "unknown", style = "bold_label", name =
            "attached_log_event_type" }

            local pusher = detail_table.add { type = "empty-widget" }
            pusher.style.horizontally_stretchable = true

            detail_table.add { type = "sprite-button", style = "tool_button_green", sprite =
            "utility/search_white", tooltip =
            "Show only this type of event", name = "attached_log_filter_type" }

            detail_table.add { type = "sprite-button", style = "tool_button_red", sprite =
            "utility/search_black", tooltip =
            "Exclude this type of event", name = "attached_log_exclude_type" }
        end

        --- @type LuaGuiElement
        local pusher = main_details.add { type = "empty-widget" }
        pusher.style.vertically_stretchable = true
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

--[[ Event providers ]]
local prepare = {}
local translate = {}

--- @param player_index number
--- @param entity LuaEntity
--- @return BuiltEntityLogData
function translate.built_entity(player_index, entity)
    --- @type BuiltEntityLogData
    local r = {
        type = "built_entity",
        actor = player_index,
        created_entity = entity.unit_number
    }
    return r
end

--- @param player_index number?
--- @param entity LuaEntity
--- @return MarkedForDeconstructionLogData
function translate.marked_for_deconstruction(player_index, entity)
    --- @type MarkedForDeconstructionLogData
    local r = {
        type = "marked_for_deconstruction",
        actor = player_index,
        entity = entity.unit_number
    }
    return r
end

--- @param player_index number
--- @param entity LuaEntity
--- @return CancelledDeconstructionLogData
function translate.cancelled_deconstruction(player_index, entity)
    --- @type CancelledDeconstructionLogData
    local r = {
        type = "cancelled_deconstruction",
        actor = player_index,
        entity = entity.unit_number
    }
    return r
end

--- @param player_index number
--- @param entity LuaEntity
--- @param give boolean
--- @param split boolean
--- @return PlayerFastTransferredLogData
function translate.player_fast_transferred(player_index, entity, give, split)
    --- @type PlayerFastTransferredLogData
    local r = {
        type = "player_fast_transferred",
        actor = player_index,
        entity = entity.unit_number,
        give = give,
        split = split,
    }
    return r
end

--- @param entity LuaEntity
--- @return RobotBuiltEntityLogData
function translate.robot_built_entity(entity)
    --- @type RobotBuiltEntityLogData
    local r = {
        type = "robot_built_entity",
        entity = entity.unit_number,
        robot = entity.last_user.index,
    }
    return r
end

--- @param event EventData.on_built_entity
function prepare.on_built_entity(event)
    if not trackable(event.created_entity) then return end
    local entity = event.created_entity
    push_event(
        entity.unit_number,
        translate.built_entity(event.player_index, entity)
    )
end

--- @param event EventData.on_marked_for_deconstruction
function prepare.on_marked_for_deconstruction(event)
    if not trackable(event.entity) then return end
    local entity = event.entity
    push_event(
        entity.unit_number,
        translate.marked_for_deconstruction(event.player_index, entity)
    )
end

--- @param event EventData.on_cancelled_deconstruction
function prepare.on_cancelled_deconstruction(event)
    if not trackable(event.entity) then return end
    local entity = event.entity
    push_event(
        entity.unit_number,
        translate.cancelled_deconstruction(event.player_index, entity)
    )
end

--- @param event EventData.on_player_fast_transferred
function prepare.on_player_fast_transferred(event)
    if not trackable(event.entity) then return end
    local entity = event.entity
    push_event(
        entity.unit_number,
        translate.player_fast_transferred(event.player_index, entity, event.from_player, event.is_split)
    )
end

--- @param event EventData.on_robot_built_entity
function prepare.on_robot_built_entity(event)
    if not trackable(event.created_entity) then return end
    local entity = event.created_entity
    push_event(
        entity.unit_number,
        translate.robot_built_entity(entity)
    )
end

Event.add(defines.events.on_player_created, attach_panels)
Event.add(defines.events.on_gui_opened, on_gui_opened)
Event.add(defines.events.on_built_entity, prepare.on_built_entity)
Event.add(defines.events.on_marked_for_deconstruction, prepare.on_marked_for_deconstruction)
Event.add(defines.events.on_cancelled_deconstruction, prepare.on_cancelled_deconstruction)
-- Event.add(defines.events.on_player_fast_transferred, prepare.on_player_fast_transferred) -- extraneous
Event.add(defines.events.on_robot_built_entity, prepare.on_robot_built_entity)
