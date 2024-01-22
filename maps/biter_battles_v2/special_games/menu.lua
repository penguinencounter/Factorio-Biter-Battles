local event = require "utils.event"
local mu = require "maps.biter_battles_v2.special_games.menu_utils"
-- Special game toolbox.

-- List of special games to load.
-- These names are passed to require(), but the contained modules can have a different ID without consequence.
local SOURCES = {
    "turtle",
    "infinity_chest",
    "disabled_research",
    "disabled_entities",
    "disable_sciences",
    "shared_science_throw",
    "limited_lives",
    "send_to_external_server",
    "captain",
    "arbitrary",
}

--- extend this class in your plugin files
---@class special.ModuleData
---@field enabled boolean

--- add fields to this class from plugin
---@class special.EditorConf

---@class special.PlayerData
---
---@field player_index integer
---@field open { [special.UI_ids]?: LuaGuiElement }
---@field editor_conf special.EditorConf

---@class special.this
---@field players table<integer, special.PlayerData>
local this

local function init()
    global.special_game_toolbox = {
        players = {},
    }
    this = global.special_game_toolbox
end

---@return special.PlayerData
local function get_default()
    return {
        player_index = 0,
        open = {},
        editor_conf = {
        },
    }
end

---Get per-player storage.
---@param player_idx integer
---@return special.PlayerData
local function get_player_storage(player_idx)
    if this.players[player_idx] then
        return this.players[player_idx]
    else
        this.players[player_idx] = get_default()
        this.players[player_idx].player_index = player_idx
        return this.players[player_idx]
    end
end

---Delete per-player storage.
---@param player_idx integer
local function erase_player_storage(player_idx)
    this.players[player_idx] = nil
end

---Check that the player is still valid.
---@param player_idx integer
---@return boolean
local function validate_player(player_idx)
    if not (game.players[player_idx] and game.players[player_idx].valid) then
        erase_player_storage(player_idx)
        return false
    end
    -- Since we're a UI, we disappear when the player disconnects.
    if not game.players[player_idx].connected then
        erase_player_storage(player_idx)
        return false
    end
    return true
end
local listbox_prefixer = mu.mk_prefix("special_game_list")

---@type table<string, special.UI_ids>
local click_to_ui_lut = {}

local Editor_ElementIDs
do
    local prefix = mu.mk_prefix("special_editor")

    Editor_ElementIDs = {
        global_name = prefix("root"),
        frame_header = prefix("header"),
        toplevel_quit_btn = prefix("top_quit"),
        toplevel_layout = prefix("top_layout"),
        main_content = prefix("main_content"),
        save_btn = prefix("save_btn"),
        save_queue_btn = prefix("save_queue_btn"),
        preset_name = prefix("preset_name"),
        preset_name_edit = prefix("preset_name_edit"),

        launch_export_ui = prefix("launch_export_ui"),
        launch_import_ui = prefix("launch_import_ui"),
        reset_to_preset = prefix("reset_to_preset"),
        clear_all = prefix("clear_all"),
    }
    for k, v in pairs(Editor_ElementIDs) do
        click_to_ui_lut[v] = mu.UI_ids.editor
    end
end

---Register a button so that event handlers can find it.
---@param element LuaGuiElement
---@param ui_id special.UI_ids
local function register_element(element, ui_id)
    click_to_ui_lut[element.name] = ui_id
end

---@generic T
---@alias special.EarlyHandler<T> { [string | number]: (fun(e: T): boolean | nil) }

---@generic T
---@alias special.Handler<T> { [string] : { [string | fun(e: T)]: fun(e: T) } }

---@class special.EventRegisterFuncs
---@field register_early fun(name: string, cbck: (fun(evt: table): boolean | nil))
---@field unregister_early fun(name: string)
---@field register fun(target: string, cbck: fun(evt: table), name?: string)
---@field unregister fun(target: string, name: string | fun(evt: table))
---@field fire fun(data: table, target_name: string)

---@return special.EventRegisterFuncs
local function create_event_functions()
    local early = {}
    local normal = {}
    ---@type special.EventRegisterFuncs
    return {
        register_early = function(name, cbck)
            early[name] = cbck
        end,
        unregister_early = function(name)
            early[name] = nil
        end,
        register = function(target, cbck, name)
            normal[target] = normal[target] or {}
            normal[target][name or cbck] = cbck
        end,
        unregister = function(target, name)
            if not normal[target] then return end
            if not name then
                normal[target] = {}
                return
            end
            normal[target][name] = nil
        end,

        fire = function(data, target_name)
            local db_actioned = {}
            local hdlr = function(e)
                log('[ERROR] in a UI event handler: ' .. e)
                log('[ERROR] the following handlers were run:')
                for _, action_taken in ipairs(db_actioned) do
                    local logged_name = action_taken
                    if type(action_taken) == "function" then
                        local source_info = debug.getinfo(action_taken, "S")
                        logged_name = "anonymous " .. source_info.source .. ":" .. source_info.linedefined
                    end
                    log('[ERROR] + ' .. tostring(logged_name) )
                end
                log(debug.traceback())
            end
            for k, v in pairs(early) do
                table.insert(db_actioned, k)
                local ok, val = xpcall(v, hdlr, data)
                if not ok then error(val) end
                if val then return end
            end
            local cbcks = normal[target_name]
            if not cbcks then return end
            for k, v in pairs(cbcks) do
                table.insert(db_actioned, k)
                local ok, er = xpcall(v, hdlr, data)
                if not ok then error(er) end
            end
        end,
    }
end

---@class special.SpecialGamePluginData
local plugin_data = {
    get_player_storage = get_player_storage,
    erase_player_storage = erase_player_storage,
    validate_player = validate_player,
    register_element = register_element,

    click = create_event_functions(),
    change = create_event_functions(),
}

---@class special.SpecialGameSpec
---@field id string
---@field name string
---Called during the module registration phase.
---@field const_init fun()
---Called when the UI needs to be (re)created.
---@field construct fun(self: special.SpecialGameSpec, player_idx: integer, list_itm: LuaGuiElement)
---Called when the module is enabled.
---@field enable fun(self: special.SpecialGameSpec, player_idx: integer, list_itm: LuaGuiElement)
---Called when the module is disabled.
---@field disable fun(self: special.SpecialGameSpec, player_idx: integer, list_itm: LuaGuiElement)
---Called when the module is cleared.
---@field clear_data fun(self: special.SpecialGameSpec, player_idx: integer, list_itm: LuaGuiElement)
---Centralized "refresh info" function. Load data from storage and update the UI.
---@field refresh_ui fun(self: special.SpecialGameSpec, player_idx: integer, list_itm: LuaGuiElement)

---@alias special.SpecialGamePlugin fun(plug: special.SpecialGamePluginData): special.SpecialGameSpec

---@type { [string]: special.SpecialGameSpec }
local SpecialGames = {}

---@param name string
local function add_source(name)
    ---@type special.SpecialGamePlugin
    local func = require("maps.biter_battles_v2.special_games." .. name)
    local spec = func(plugin_data)
    SpecialGames[spec.id] = spec
end

---@param arr string[]
local function add_sources(arr)
    for _, name in ipairs(arr) do
        add_source(name)
    end
end

add_sources(SOURCES)

for k, v in pairs(SpecialGames) do
    v.const_init()
    log("Special game " .. k .. " registered.")
end

---Initializes the Special Game UI.
---Last-resort fallback for updating the UI. Destroys the UI and recreates it.
---@param player_id integer
local function init_ui(player_id)
    local player = game.players[player_id]
    if player.gui.screen[Editor_ElementIDs.global_name] then
        player.gui.screen[Editor_ElementIDs.global_name].destroy()
    end
    local player_UI = player.gui.screen.add {
        type = "frame",
        name = Editor_ElementIDs.global_name,
        direction = "vertical",
    }
    ---@diagnostic disable-next-line: missing-fields
    mu.style(player_UI, {
        width = 600,
        minimal_height = 800,
        maximal_height = 1000,
        vertically_stretchable = true,
        horizontal_align = "center",
        padding = { 4, 8, 8, 8 }
    })
    player_UI.auto_center = true

    -- Header (title + drag handle + close button)
    do
        local header = player_UI.add {
            type = "flow",
            name = Editor_ElementIDs.frame_header,
            direction = "horizontal"
        }
        ---@diagnostic disable-next-line: missing-fields
        mu.style(header, {
            vertically_stretchable = false
        })
        header.add {
            type = "label",
            caption = "Setup special game",
            style = "frame_title"
        }
        local dragger = header.add {
            type = "empty-widget",
            style = "draggable_space_header"
        }
        ---@diagnostic disable-next-line: missing-fields
        mu.style(dragger, {
            right_margin = 4,
            horizontally_stretchable = true,
            vertically_stretchable = true,
            height = 24,
            natural_height = 24,
        })
        dragger.drag_target = player_UI
        header.add {
            type = "sprite-button",
            sprite = "utility/close_white",
            hovered_sprite = "utility/close_black",
            clicked_sprite = "utility/close_black",
            style = "frame_action_button",
            name = Editor_ElementIDs.toplevel_quit_btn
        }
    end

    local toplevel_layout = player_UI.add {
        type = "flow",
        name = Editor_ElementIDs.toplevel_layout,
        direction = "vertical"
    }
    ---@diagnostic disable-next-line: missing-fields
    mu.style(toplevel_layout, {
        horizontally_stretchable = true,
        vertically_stretchable = true,
        padding = 0,
        margin = 0,
    })

    -- Main content
    local body_scrollbox
    do
        local main = toplevel_layout.add {
            type = "frame",
            style = "inside_shallow_frame",
            name = Editor_ElementIDs.main_content,
            direction = "vertical"
        }
        ---@diagnostic disable-next-line: missing-fields
        mu.style(main, {
            horizontally_stretchable = true,
            vertically_stretchable = true,
            padding = 0,
            margin = 0,
            top_margin = 4,
            bottom_margin = 4,
            left_margin = 4,
            right_margin = 4,
        })

        local header = main.add {
            type = "frame",
            direction = "horizontal",
            style = "subheader_frame",
        }
        ---@diagnostic disable-next-line: missing-fields
        mu.style(header, {
            horizontally_stretchable = true,
        })

        local label_editor = header.add {
            type = "flow",
            direction = "horizontal",
        }
        ---@diagnostic disable-next-line: missing-fields
        mu.style(label_editor, {
            horizontally_stretchable = true,
            vertical_align = "center",
        })

        local preset_name = label_editor.add {
            type = "label",
            style = "subheader_caption_label",
            caption = "(new preset)",
            name = Editor_ElementIDs.preset_name,
        }
        local edit_preset_name = label_editor.add {
            type = "sprite-button",
            sprite = "utility/rename_icon_small_black",
            hovered_sprite = "utility/rename_icon_small_black",
            clicked_sprite = "utility/rename_icon_small_black",
            style = "mini_button_aligned_to_text_vertically_when_centered",
            name = Editor_ElementIDs.preset_name_edit,
        }

        -- Toolbar buttons: save / load / clear / delete
        header.add {
            type = "sprite-button",
            sprite = "utility/export_slot",
            style = "tool_button",
            tooltip = "Export string or save as preset",
            name = Editor_ElementIDs.launch_export_ui,
        }
        header.add {
            type = "sprite-button",
            sprite = "utility/import_slot",
            style = "tool_button",
            tooltip = "Import string or select a preset from the list",
            name = Editor_ElementIDs.launch_import_ui,
        }
        mu.style(header.add {
            type = "empty-widget",
        }, { ---@diagnostic disable-line: missing-fields
            natural_width = 8,
            horizontally_squashable = true
        })

        header.add {
            type = "sprite-button",
            sprite = "utility/reset",
            style = "tool_button",
            tooltip = "Undo changes to this preset\nNo changes made yet",
            enabled = false,
            name = Editor_ElementIDs.reset_to_preset,
        }
        header.add {
            type = "sprite-button",
            sprite = "utility/trash",
            style = "tool_button_red",
            tooltip = "Clear all settings",
            name = Editor_ElementIDs.clear_all,
        }

        local body = main.add {
            type = "frame",
            direction = "vertical",
            style = "inside_shallow_frame",
        }
        ---@diagnostic disable-next-line: missing-fields
        mu.style(body, {
            horizontally_stretchable = true,
            vertically_stretchable = true,
            padding = 0,
            margin = 0,
        })

        body_scrollbox = body.add {
            type = "scroll-pane",
            style = "scroll_pane_with_dark_background_under_subheader",
        }
        ---@diagnostic disable-next-line: missing-fields
        mu.style(body_scrollbox, {
            horizontally_stretchable = true,
            vertically_stretchable = true,
        })
    end

    -- Populate listbox
    for k, v in pairs(SpecialGames) do
        local ui_box = body_scrollbox.add {
            type = "flow",
            name = listbox_prefixer(k),
            direction = "vertical",
        }
        ---@diagnostic disable-next-line: missing-fields
        mu.style(ui_box, {
            vertical_spacing = 0
        })

        local toggle_module_enabled = ui_box.add {
            type = "button",
            name = mu.mk_prefix(listbox_prefixer(k))("toggle"),
            caption = v.name,
            auto_toggle = true,
        }
        register_element(toggle_module_enabled, mu.UI_ids.editor)

        ---@diagnostic disable-next-line: missing-fields
        mu.style(toggle_module_enabled, {
            horizontally_stretchable = true,
            vertical_align = "center",
            horizontal_align = "left",
            padding = { 0, 8 },
            margin = 0,
            height = 36,
        })

        -- Tell module to get set up
        if v.construct then -- TODO: make this mandatory!!!
            v:construct(player_id, ui_box)
        end
        if v.clear_data then
            v:clear_data(player_id, ui_box)
        end
    end

    -- Bottom action buttons
    do
        local dialog_buttons = toplevel_layout.add {
            type = "flow",
            direction = "horizontal",
            style = "dialog_buttons_horizontal_flow",
        }

        mu.spacer(dialog_buttons.add {
            type = "empty-widget"
        })

        ---@diagnostic disable-next-line: missing-fields
        mu.style(dialog_buttons, {
            horizontally_stretchable = true,
            top_padding = 8,
            horizontal_spacing = 4,
        })
        dialog_buttons.add {
            type = "button",
            caption = "Queue",
            style = "confirm_button",
            name = Editor_ElementIDs.save_queue_btn,
        }
        dialog_buttons.add {
            type = "button",
            caption = "Start",
            style = "confirm_button",
            name = Editor_ElementIDs.save_btn,
        }
    end
    player.opened = player_UI
    get_player_storage(player_id).open[mu.UI_ids.editor] = player_UI
end

---/debug-special command handler.
---@param cmd_data CustomCommandData
local function cmd_launch_ui(cmd_data)
    init_ui(cmd_data.player_index)
end

plugin_data.click.register_early("toggle buttons", function(evt)
    if not (evt.element and evt.element.valid) then return end
    if evt.element.name:match("^" .. listbox_prefixer("")) then
        local module_name = evt.element.name:match("^" .. listbox_prefixer("(.-)_toggle$"))
        if not module_name then return end

        -- take the module and enable / disable it
        local module = SpecialGames[module_name]
        if not module then
            log("Error enabling module " .. module_name .. ": module not found.")
        end

        if evt.element.toggled then
            module:enable(evt.player_index, evt.element.parent)
        else
            module:disable(evt.player_index, evt.element.parent)
        end
        return true
    end
end)

---@param player LuaPlayer
local function quit_editor(player)
    local player_data = get_player_storage(player.index)
    if player.opened == player_data.open[mu.UI_ids.editor] then
        player.opened = nil
    end
    if player_data.open[mu.UI_ids.editor] then
        if player_data.open[mu.UI_ids.editor].valid then
            player_data.open[mu.UI_ids.editor].destroy()
        end
        player_data.open[mu.UI_ids.editor] = nil
    end
    erase_player_storage(player.index) -- forget the contents of the screen
end

plugin_data.click.register(Editor_ElementIDs.toplevel_quit_btn, function(evt)
    quit_editor(game.players[evt.player_index])
end)

plugin_data.click.register(Editor_ElementIDs.clear_all, function(evt)
    local player_data = get_player_storage(evt.player_index)
    for _, v in pairs(SpecialGames) do
        -- Try to find the toggle button for this module.
        local container = mu.find(
            player_data.open[mu.UI_ids.editor]
            [Editor_ElementIDs.toplevel_layout]
            [Editor_ElementIDs.main_content],
            listbox_prefixer(v.id)
        )
        if not container then
            log("Error disabling module " .. v.id .. ": container " .. listbox_prefixer(v.id) .. " not found.")
            return
        end
        local togglebtn = mu.find(container, mu.mk_prefix(listbox_prefixer(v.id))("toggle"))
        if togglebtn then
            togglebtn.toggled = false
        end
        v:disable(evt.player_index, container)
        if v.clear_data then
            v:clear_data(evt.player_index, container)
        end
    end
end)

---@param evt EventData.on_gui_closed
event.add(defines.events.on_gui_closed, function(evt)
    if not validate_player(evt.player_index) then return end
    local player_data = get_player_storage(evt.player_index)
    if not player_data.open[mu.UI_ids.editor] then return end

    if evt.element == player_data.open[mu.UI_ids.editor] then
        quit_editor(game.players[evt.player_index])
    end
end)

local function check_gui_interaction(name, player_idx)
    local screen_name = click_to_ui_lut[name]
    if not screen_name then return end -- Not an element we care about.

    if not validate_player(player_idx) then
        -- how did this happen?
        log("Player " .. player_idx .. " is not valid, but they clicked a button?")
        return false
    end

    local player_data = get_player_storage(player_idx)

    if not player_data.open[screen_name] then
        log("Player " ..
            player_idx .. " clicked a button, apparently on " .. screen_name .. ", but the UI is not open.")
        return false
    end
    return true
end

---@param e EventData.on_gui_click
event.add(defines.events.on_gui_click, function(e)
    if not (e.element and e.element.valid) then return end
    if not check_gui_interaction(e.element.name, e.player_index) then return end
    plugin_data.click.fire(e, e.element.name)
end)

---@param e EventData.on_gui_elem_changed
event.add(defines.events.on_gui_elem_changed, function(e)
    if not (e.element and e.element.valid) then return end
    if not check_gui_interaction(e.element.name, e.player_index) then return end
    plugin_data.change.fire(e, e.element.name)
end)

event.on_init(init)

commands.add_command("debug-special", "launch Special Game Editor", cmd_launch_ui)