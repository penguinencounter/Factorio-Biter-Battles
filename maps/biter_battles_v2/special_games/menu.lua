local event = require "utils.event"
local mu = require "maps.biter_battles_v2.special_games.utilities"
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
---@field popups LuaGuiElement[]
---@field editor_conf special.EditorConf

---@class special.this
---@field players table<integer, special.PlayerData>
---@field ui_bindings table<string, special.UI_ids>
---@field event_handlers { [string]: { early: { [string]: integer }, standard: { [string]: integer[] } } }
local this = setmetatable({}, {
    __index = function(t, k)
        return global.special_game_toolbox[k]
    end,
    __newindex = function(t, k, v)
        global.special_game_toolbox[k] = v
    end
})

-- note: maybe use Token from the rest of the game instead?

-- Set to true at the end of the file, before any of the game events have run.
-- Setting to true exits the 'constant init phase'.
local desync_guard = false

---@type table<integer, fun(...): ...>
local callback_alias = {}

---@param key integer
---@return fun(...): ...
local function get_alias(key)
    local ref = callback_alias[key]
    if ref == nil then error("Broken reference to " .. key) end
    return ref
end

---@param func fun(...): ...
---@return integer
local function const_register_callable(func)
    if desync_guard then error("Can't register a new callable outside the const init phase.") end
    local idx = #callback_alias + 1
    callback_alias[idx] = func
    return idx
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

---Mapping between element names and their UI set.
---Set this table directly to register constant names.
---Set `this.ui_bindings` to register names during runtime.
---@type table<string, special.UI_ids>
local element_ui_map = setmetatable(
    {},
    {
        __index = function(_, k)
            return this.ui_bindings[k]
        end
    }
)

local Editor_ElementIDs
do
    local prefix = mu.mk_prefix("special_editor")

    Editor_ElementIDs = {
        global_name = prefix("root"),
        frame_header = prefix("header"),
        toplevel_quit_btn = prefix("top_quit"),
        toplevel_layout = prefix("top_layout"),
        main_content = prefix("main_content"),
        continue_to_text_editor = prefix("continue_to_text_editor"),
        preset_name = prefix("preset_name"),
        preset_name_edit = prefix("preset_name_edit"),

        launch_export_ui = prefix("launch_export_ui"),
        launch_import_ui = prefix("launch_import_ui"),
        reset_to_preset = prefix("reset_to_preset"),
        clear_all = prefix("clear_all"),
    }
    for _, v in pairs(Editor_ElementIDs) do
        element_ui_map[v] = mu.UI_ids.editor
    end
end

local EditorExport_ElementIDs
do
    local prefix = mu.mk_prefix("special_editor_export")
    EditorExport_ElementIDs = {
        global_name = prefix("root"),
        frame_header = prefix("header"),
        toplevel_quit_btn = prefix("top_quit"),
        panes = prefix("panes"),

        output = prefix("output"),
    }
    for _, v in pairs(EditorExport_ElementIDs) do
        element_ui_map[v] = mu.UI_ids.editor_export
    end
end

---Register a button so that event handlers can find it.
---@param element LuaGuiElement
---@param ui_id special.UI_ids
local function register_element(element, ui_id)
    element_ui_map[element.name] = ui_id
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

-- FIXME: This will not work in multiplayer.
--        People will be stepping on each others' toes (event handlers) all over the place.
--        Will also almost certainly desync, because plugin_data is not const.
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
                    log('[ERROR] + ' .. tostring(logged_name))
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

    button_clicked = create_event_functions(),
    picker_changed = create_event_functions(),
    text_changed = create_event_functions(),
    text_confirmed = create_event_functions(),
    slider_changed = create_event_functions(),
    checkbox_changed = create_event_functions(),
    switch_changed = create_event_functions(),
    listbox_changed = create_event_functions(),
}

---Declare that an element is associated with a UI.
---@param element LuaGuiElement
---@param ui_id special.UI_ids
local function register_element_v2(element, ui_id)
    this.ui_bindings = this.ui_bindings
    this.ui_bindings[element.name] = ui_id
end

---@param element_name string
---@param ui_id special.UI_ids
local function const_register_name(element_name, ui_id)
    if desync_guard then error("Cannot register names using const_register_name outside of const init phase.", 2) end
    element_ui_map[element_name] = ui_id
end

---@class special.EventRegisterFuncs2
---@field const_register_early fun(name: string, callback: integer | fun(evt: table): boolean | nil)
---@field register_early_global fun(name: string, callback_id: integer)
---@field const_register fun(target: string, callback: (integer | fun(evt: table)), name: string?)
---@field register_global fun(target: string, callback_id: integer, name: string?)
---@field emit fun(name: string, player: integer, event_data: table)

---Event handlers to initialize with init().
---@type string[]
local queued_event_handlers = {}

---@param event_id string Event id. Used to manage storage.
---@return special.EventRegisterFuncs2
local function create_event(event_id)
    ---@type { [string]: fun(evt: table): boolean | nil}
    local const_early = {}
    ---@type { [string]: { [string | fun(evt: table)]: fun(evt: table) } }
    local const_standard = {}

    queued_event_handlers[#queued_event_handlers + 1] = event_id

    local runtime_early = setmetatable({}, {
        __index = function(t, k)
            return this.event_handlers[event_id].early[k]
        end,
        __newindex = function(t, k, v)
            this.event_handlers[event_id].early[k] = v
        end
    })

    local runtime_standard = setmetatable({}, {
        __index = function(t, k)
            return this.event_handlers[event_id].standard[k]
        end,
        __newindex = function(t, k, v)
            this.event_handlers[event_id].standard[k] = v
        end
    })

    ---@type special.EventRegisterFuncs2
    return {
        const_register_early = function(name, callback)
            if desync_guard then error("Cannot create const event registrations outside of const init phase.", 2) end
            -- this function accepts function pointers, not callback IDs.
            ---@type fun(evt: table): boolean | nil
            local resolved_callback
            if type(callback) == "number" then
                resolved_callback = get_alias(callback)
            else
                ---@cast callback -integer
                resolved_callback = callback
            end
            const_early[name] = resolved_callback
        end,
        register_early_global = function(name, callback_id)
            runtime_early[name] = callback_id
        end,
        const_register = function(target, callback, name)
            if desync_guard then error("Cannot create const event registrations outside of const init phase.", 2) end
            ---@type fun(evt: table)
            local resolved_callback
            if type(callback) == "number" then
                resolved_callback = get_alias(callback)
            else
                ---@cast callback -integer
                resolved_callback = callback
            end
            const_standard[target] = const_standard[target] or {}
            const_standard[target][name or resolved_callback] = resolved_callback
        end,
        register_global = function(target, callback_id, name)
            runtime_standard[target] = runtime_standard[target] or {}
            runtime_standard[target][name or callback_id] = callback_id
        end,

        emit = function(target_name, player, event_data)
            local actioned = {}
            local function error_handler(e)
                log('[ERROR] In UI event handler: ' .. e)
                log('[ERROR] These handlers were run:')
                for _, action in ipairs(actioned) do
                    local log_name = action
                    if type(action) == "function" then
                        local info = debug.getinfo(action, "S")
                        log_name = "anonymous " .. info.source .. ":" .. info.linedefined
                    end
                    log('[ERROR] - ' .. tostring(log_name))
                end
                log(debug.traceback())
            end

            for name, callable in pairs(const_early) do
                actioned[#actioned + 1] = name
                local ok, val = xpcall(callable, error_handler, event_data)
                if not ok then error(val) end
                if val then return end
            end
            -- can't use runtime_early because it's a half-baked proxy, so a pairs() doesn't work
            for name, callable_ref in pairs(this.event_handlers[event_id].early) do
                actioned[#actioned + 1] = name
                local callable = get_alias(callable_ref)
                local ok, val = xpcall(callable, error_handler, event_data)
                if not ok then error(val) end
            end

            local const_callbacks = const_standard[target_name]
            if const_callbacks then
                for name, callable in pairs(const_callbacks) do
                    actioned[#actioned + 1] = name
                    local ok, err = xpcall(callable, error_handler, event_data)
                    if not ok then error(err) end
                end
            end
            local runtime_callbacks = runtime_standard[target_name]
            if runtime_callbacks then
                for name, callable_ref in pairs(runtime_callbacks) do
                    actioned[#actioned + 1] = name
                    local callable = get_alias(callable_ref)
                    local ok, err = xpcall(callable, error_handler, event_data)
                    if not ok then error(err) end
                end
            end
        end
    }
end

---@type fun(child: LuaGuiElement, plugin_id: string): LuaGuiElement | nil
local find_list_item
do
    local find_list_item_memo = setmetatable({}, { __mode = 'kv' })
    ---@param child LuaGuiElement
    ---@param plugin_id string
    ---@return LuaGuiElement | nil
    function find_list_item(child, plugin_id)
        if find_list_item_memo[child] then
            return find_list_item_memo[child]
        end
        local target_name = listbox_prefixer(plugin_id)
        local parent = child
        while parent do
            if parent.name == target_name then
                find_list_item_memo[child] = parent
                return parent
            end
            parent = parent.parent
        end
        return nil
    end
end

---@class special.PluginAPIV2
local plugin_api_v2 = {
    get_player_storage = get_player_storage,
    erase_player_storage = erase_player_storage,
    validate_player = validate_player,
    const_register_name = const_register_name,
    register_element = register_element_v2,
    const_register_callable = const_register_callable,
    find_list_item = find_list_item,

    on_click = create_event("on_click"),
    picker_changed = create_event("picker_changed"),
}

---@class special.SpecialGameSpec
---@field id string
---@field name string
---Called during the module registration phase.
---@field const_init fun(self: special.SpecialGameSpec)
---Called when the UI needs to be (re)created.
---@field construct fun(self: special.SpecialGameSpec, player_idx: integer, list_itm: LuaGuiElement)
---Called when the module is enabled.
---@field enable fun(self: special.SpecialGameSpec, player_idx: integer, list_itm: LuaGuiElement)
---Called when the module is disabled.
---@field disable fun(self: special.SpecialGameSpec, player_idx: integer, list_itm: LuaGuiElement)
---Called when the module is cleared. Usually by the red Trash button at the top, but could also be called by the module itself.
---@field clear_data fun(self: special.SpecialGameSpec, player_idx: integer, list_itm: LuaGuiElement)
---Centralized "refresh info" function. Load data from storage and update the UI.
---@field refresh_ui fun(self: special.SpecialGameSpec, player_idx: integer, list_itm: LuaGuiElement)

---@alias special.SpecialGamePlugin fun(plug: special.PluginAPIV2): special.SpecialGameSpec

---@type { [string]: special.SpecialGameSpec }
local SpecialGames = {}

---@param name string
local function add_source(name)
    ---@type special.SpecialGamePlugin
    local func = require("maps.biter_battles_v2.special_games." .. name)
    local spec = func(plugin_api_v2)
    SpecialGames[spec.id] = spec
end

---@param arr string[]
local function add_sources(arr)
    for _, name in ipairs(arr) do
        add_source(name)
    end
end

---Initializes the Export UI for exporting a Special Game
local function export_ui(player_id)
    local player = game.players[player_id]
    if player.gui.screen[EditorExport_ElementIDs.global_name] then
        player.gui.screen[EditorExport_ElementIDs.global_name].destroy()
    end
    local export_UI = player.gui.screen.add {
        type = "frame",
        name = EditorExport_ElementIDs.global_name,
        direction = "vertical"
    }
    ---@diagnostic disable-next-line: missing-fields
    mu.style(export_UI, {
        width = 400,
        maximal_height = 700,
        vertically_stretchable = true,
        natural_height = 0,
        padding = { 4, 8, 8, 8 },
    })
    export_UI.auto_center = true

    -- Header (title + drag handle + close button)
    do
        local header = export_UI.add {
            type = "flow",
            name = EditorExport_ElementIDs.frame_header,
            direction = "horizontal"
        }
        ---@diagnostic disable-next-line: missing-fields
        mu.style(header, {
            vertically_stretchable = false
        })
        header.add {
            type = "label",
            caption = "Save / Export",
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
        dragger.drag_target = export_UI
        header.add {
            type = "sprite-button",
            sprite = "utility/close_white",
            hovered_sprite = "utility/close_black",
            clicked_sprite = "utility/close_black",
            style = "frame_action_button",
            name = EditorExport_ElementIDs.toplevel_quit_btn
        }
    end

    local panes = export_UI.add {
        type = "flow",
        name = EditorExport_ElementIDs.panes,
        direction = "vertical"
    }
    ---@diagnostic disable-next-line: missing-fields
    mu.style(panes, {
        vertically_stretchable = true,
        natural_width = 0,
        vertical_spacing = 21,
    })

    local output_box = panes.add {
        type = "text-box",
        text = "",
        name = EditorExport_ElementIDs.output
    }
    ---@diagnostic disable-next-line: missing-fields
    mu.style(output_box, {
        horizontally_stretchable = true,
        maximal_width = 99999,
        minimal_height = 150,
    })

    local save_pane = panes.add {
        type = "frame",
        style = "inside_shallow_frame"
    }
    ---@diagnostic disable-next-line: missing-fields
    mu.style(save_pane, {
        horizontally_stretchable = true,
        minimal_height = 150,
    })

    player.opened = export_UI
    get_player_storage(player_id).open[mu.UI_ids.editor_export] = export_UI
end

--- Prepares UI elements.
local function const_generate_init_ui_names()
    for k, _ in pairs(SpecialGames) do
        local name = mu.mk_prefix(listbox_prefixer(k))("toggle")
        plugin_api_v2.const_register_name(name, mu.UI_ids.editor)
    end
end

---Initializes the Special Game UI.
---Last-resort fallback for updating the UI. Destroys the UI and recreates it.
---@param player_id integer
local function init_ui(player_id)
    local player = game.players[player_id]
    if player.gui.screen[Editor_ElementIDs.global_name] then
        player.gui.screen[Editor_ElementIDs.global_name].destroy()
    end
    local editor_UI = player.gui.screen.add {
        type = "frame",
        name = Editor_ElementIDs.global_name,
        direction = "vertical",
    }
    ---@diagnostic disable-next-line: missing-fields
    mu.style(editor_UI, {
        width = 600,
        minimal_height = 800,
        maximal_height = 1000,
        vertically_stretchable = true,
        horizontal_align = "center",
        padding = { 4, 8, 8, 8 }
    })
    editor_UI.auto_center = true

    -- Header (title + drag handle + close button)
    do
        local header = editor_UI.add {
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
        dragger.drag_target = editor_UI
        header.add {
            type = "sprite-button",
            sprite = "utility/close_white",
            hovered_sprite = "utility/close_black",
            clicked_sprite = "utility/close_black",
            style = "frame_action_button",
            name = Editor_ElementIDs.toplevel_quit_btn
        }
    end

    local toplevel_layout = editor_UI.add {
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
            caption = "Next",
            style = "confirm_button",
            name = Editor_ElementIDs.continue_to_text_editor,
        }
    end
    player.opened = editor_UI
    get_player_storage(player_id).open[mu.UI_ids.editor] = editor_UI
end

---/debug-special command handler.
---@param cmd_data CustomCommandData
local function cmd_launch_ui(cmd_data)
    init_ui(cmd_data.player_index)
end


--- Set to true to prevent closing the window.
--- FIXME: desyncs!!!!
local popup_switchover = false

---@param player LuaPlayer
local function quit_export(player)
    local player_data = get_player_storage(player.index)
    local ui_box = player_data.open[mu.UI_ids.editor_export]
    ---@type LuaGuiElement | nil
    local focus_after = nil
    if player_data.open[mu.UI_ids.editor] and player_data.open[mu.UI_ids.editor].valid then
        log("[Info] Switching focus to " ..
            tostring(player_data.open[mu.UI_ids.editor] and player_data.open[mu.UI_ids.editor].name))
        focus_after = player_data.open[mu.UI_ids.editor]
        player_data.open[mu.UI_ids.editor].focus()
    end
    if ui_box then
        if ui_box.valid then
            ui_box.destroy()
        end
        player_data.open[mu.UI_ids.editor_export] = nil
    end
    -- I have no idea why LLS is clowning on this, because assigning `nil` directly works.
    ---@diagnostic disable-next-line: assign-type-mismatch
    player.opened = focus_after
end

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
    -- close any popups
    quit_export(player)
    erase_player_storage(player.index) -- forget the contents of the screen
end


add_sources(SOURCES)

for k, v in pairs(SpecialGames) do
    v:const_init()
    log("Special game " .. k .. " registered.")
end

-- generate UI item names
const_generate_init_ui_names()

plugin_api_v2.on_click.const_register_early("toggle buttons", function(evt)
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

plugin_api_v2.on_click.const_register(Editor_ElementIDs.launch_export_ui, function(evt)
    popup_switchover = true
    export_ui(evt.player_index)
    popup_switchover = false
end)

plugin_api_v2.on_click.const_register(Editor_ElementIDs.toplevel_quit_btn, function(evt)
    quit_editor(game.players[evt.player_index])
end)

plugin_api_v2.on_click.const_register(EditorExport_ElementIDs.toplevel_quit_btn, function(evt)
    quit_export(game.players[evt.player_index])
end)

plugin_api_v2.on_click.const_register(Editor_ElementIDs.clear_all, function(evt)
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
    local player = game.players[evt.player_index]
    if not evt.element then return end
    log("Screen closed " .. evt.element.name .. " -> " .. tostring(player.opened and player.opened.name))

    if evt.element == player_data.open[mu.UI_ids.editor] then
        if not popup_switchover then
            quit_editor(player)
        end
    elseif evt.element == player_data.open[mu.UI_ids.editor_export] then
        quit_export(player)
    end
end)

local function check_gui_interaction(name, player_idx)
    local screen_name = element_ui_map[name]
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
    plugin_api_v2.on_click.emit(e.element.name, e.player_index, e)
end)

---@param e EventData.on_gui_elem_changed
event.add(defines.events.on_gui_elem_changed, function(e)
    if not (e.element and e.element.valid) then return end
    if not check_gui_interaction(e.element.name, e.player_index) then return end
    plugin_api_v2.picker_changed.emit(e.element.name, e.player_index, e)
end)


local function init()
    global.special_game_toolbox = {
        players = {},
        ui_bindings = {},
        event_handlers = {}
    }
    for _, event_id in ipairs(queued_event_handlers) do
        this.event_handlers[event_id] = {
            early = {},
            standard = {}
        }
    end
end

event.on_init(init)

commands.add_command("debug-special", "launch Special Game Editor", cmd_launch_ui)

desync_guard = true
