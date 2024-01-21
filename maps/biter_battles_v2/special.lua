local event = require "utils.event"
-- Special game toolbox.

---@enum special.UI_ids
local UI_ids = {
    editor = "special_editor",
}

---@class special.PlayerData
---
---@field player_index integer
---@field open { [special.UI_ids]?: LuaGuiElement }

---@class special.this
---@field players table<integer, special.PlayerData>
local this

local function init()
    global.special_game_toolbox = {
        players = {},
    }
    this = global.special_game_toolbox
end

---@type special.PlayerData
local default = {
    player_index = 0,
    open = {},
}

---Get per-player storage.
---@param player_idx integer
---@return special.PlayerData
local function get_player_storage(player_idx)
    if this.players[player_idx] then
        return this.players[player_idx]
    else
        this.players[player_idx] = default
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

---@param prefix string
---@return fun(name: string): string
local function mk_prefix(prefix)
    return function(name)
        return prefix .. "_" .. name
    end
end
local listbox_prefixer = mk_prefix("special_game_list")

---@type table<string, special.UI_ids>
local click_to_ui_lut = {}

local Editor_ElementIDs
do
    local prefix = mk_prefix("special_editor")

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
        click_to_ui_lut[v] = UI_ids.editor
    end
end

---Register a button so that event handlers can find it.
---@param element LuaGuiElement
---@param ui_id special.UI_ids
local function register_button(element, ui_id)
    click_to_ui_lut[element.name] = ui_id
end

--- Always run on every click event that we recognize.
--- Use for dynamic UI elements.
---@type (fun(e: EventData.on_gui_click): boolean | nil)[]
local early_handlers = {}

---@type { [string]: { [string | fun(e: EventData.on_gui_click) ]: fun(e: EventData.on_gui_click) }}
local handlers = {}

---Register a button handler.
---@param name string
---@param cbck fun(e: EventData.on_gui_click)
---@param cbck_name? string
local function register_button_handler(name, cbck, cbck_name)
    handlers[name] = handlers[name] or {}
    handlers[name][cbck_name or cbck] = cbck
end

---Unregister a button handler. Pass nil to remove all handlers for the button.
---@param name string
---@param cbck_name? fun(e: EventData.on_gui_click) | string
local function unregister_button_handler(name, cbck_name)
    if not handlers[name] then return end
    if not cbck_name then
        handlers[name] = {}
        return
    end
    handlers[name][cbck_name] = nil
end

---Apply styling and layout changes to the element.
---@param element LuaGuiElement
---@param properties LuaStyle
local function style(element, properties)
    for k, v in pairs(properties) do
        element.style[k] = v
    end
end

local function spacer(element)
    ---@diagnostic disable-next-line: missing-fields
    style(element, {
        horizontally_stretchable = true,
        vertically_stretchable = true,
    })
end

---Find items in the UI.
---@param parent LuaGuiElement
---@param name string
---@return LuaGuiElement | nil
local function find(parent, name)
    for _, v in pairs(parent.children) do
        if v.name == name then
            return v
        end
    end
    for _, v in pairs(parent.children) do
        local found = find(v, name)
        if found then return found end
    end
    return nil
end

---@class special.SpecialGameSpec
---@field id string
---@field name string
---@field const_init fun()
---@field enable fun(self: special.SpecialGameSpec, player_idx: integer, list_itm: LuaGuiElement)
---@field disable fun(self: special.SpecialGameSpec, player_idx: integer, list_itm: LuaGuiElement)

---Add an options panel.
---@param parent LuaGuiElement
---@param id string
---@return LuaGuiElement
local function mk_options(parent, id)
    local options = parent.add {
        type = "frame",
        style = "deep_frame_in_shallow_frame",
        direction = "vertical",
        name = mk_prefix(id)("options"),
    }
    ---@diagnostic disable-next-line: missing-fields
    style(options, {
        horizontally_stretchable = true,
        natural_height = 0,
        padding = 4,
        margin = 0
    })
    return options
end

---Destroy an options panel.
---@param parent LuaGuiElement
---@param id string
local function rm_options(parent, id)
    local options = find(parent, mk_prefix(id)("options"))
    if options then
        options.destroy()
    end
end

---@type { [string]: special.SpecialGameSpec }
local SpecialGames = {
    turtle = {
        id = "turtle",
        name = "Turtle moat",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            local options = mk_options(list_itm, self.id)
            options.add {
                type = "label",
                caption = "Turtle options placeholder",
            }
        end,
        disable = function(self, player_idx, list_itm)
            rm_options(list_itm, self.id)
        end
    },
    infinity_chest = {
        id = "infinity_chest",
        name = "Infinity chest",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            local options = mk_options(list_itm, self.id)
            options.add {
                type = "label",
                caption = "infinity chest options placeholder",
            }
        end,
        disable = function(self, player_idx, list_itm)
            rm_options(list_itm, self.id)
        end
    },
    disabled_research = {
        id = "disabled_research",
        name = "Disable research",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            local options = mk_options(list_itm, self.id)
            options.add {
                type = "label",
                caption = "disabled research options placeholder",
            }
        end,
        disable = function(self, player_idx, list_itm)
            rm_options(list_itm, self.id)
        end
    },
    disabled_entities = {
        id = "disabled_entities",
        name = "Disable entities",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            local options = mk_options(list_itm, self.id)
            options.add {
                type = "label",
                caption = "disabled entities options placeholder",
            }
        end,
        disable = function(self, player_idx, list_itm)
            rm_options(list_itm, self.id)
        end
    },
    shared_science_throw = {
        id = "shared_science_throw",
        name = "Share sent science",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            -- there are no options, this is just a toggle
        end,
        disable = function(self, player_idx, list_itm)
        end
    },
    limited_lives = {
        id = "limited_lives",
        name = "Limit number of lives",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            local options = mk_options(list_itm, self.id)
            options.add {
                type = "label",
                caption = "limited lives options placeholder",
            }
        end,
        disable = function(self, player_idx, list_itm)
            rm_options(list_itm, self.id)
        end
    },
    disable_sciences = {
        id = "disable_sciences",
        name = "Disable sciences",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            local options = mk_options(list_itm, self.id)
            options.add {
                type = "label",
                caption = "disabled science options placeholder",
            }
        end,
        disable = function(self, player_idx, list_itm)
            rm_options(list_itm, self.id)
        end
    },
    send_to_external_server = {
        id = "send_to_external_server",
        name = "Send players to another server",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            local options = mk_options(list_itm, self.id)
            options.add {
                type = "label",
                caption = "switch server options placeholder",
            }
        end,
        disable = function(self, player_idx, list_itm)
            rm_options(list_itm, self.id)
        end
    },
    captain_event = {
        id = "captain_event",
        name = "Captain event",
        const_init = function()

        end,
        enable = function(self, player_idx, list_itm)
            local options = mk_options(list_itm, self.id)
            options.add {
                type = "label",
                caption = "Captain event options placeholder",
            }
        end,
        disable = function(self, player_idx, list_itm)
            rm_options(list_itm, self.id)
        end
    },
}

for k, v in pairs(SpecialGames) do
    if k ~= v.id then
        error("Special game " ..
            k .. " has a mismatched ID. Fix registration info in special.lua and reload.")
    end
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
    style(player_UI, {
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
        style(header, {
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
        style(dragger, {
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
    style(toplevel_layout, {
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
        style(main, {
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
        style(header, {
            horizontally_stretchable = true,
        })

        local label_editor = header.add {
            type = "flow",
            direction = "horizontal",
        }
        ---@diagnostic disable-next-line: missing-fields
        style(label_editor, {
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
        style(header.add {
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
            style = "tool_button",
            tooltip = "Clear all settings",
            name = Editor_ElementIDs.clear_all,
        }

        local body = main.add {
            type = "frame",
            direction = "vertical",
            style = "inside_shallow_frame",
        }
        ---@diagnostic disable-next-line: missing-fields
        style(body, {
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
        style(body_scrollbox, {
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
        style(ui_box, {
            vertical_spacing = 0
        })

        local toggle_module_enabled = ui_box.add {
            type = "button",
            name = mk_prefix(listbox_prefixer(k))("toggle"),
            caption = v.name,
            auto_toggle = true,
        }
        register_button(toggle_module_enabled, UI_ids.editor)

        ---@diagnostic disable-next-line: missing-fields
        style(toggle_module_enabled, {
            horizontally_stretchable = true,
            vertical_align = "center",
            horizontal_align = "left",
            padding = { 0, 8 },
            margin = 0,
            height = 36,
        })
    end

    -- Bottom action buttons
    do
        local dialog_buttons = toplevel_layout.add {
            type = "flow",
            direction = "horizontal",
            style = "dialog_buttons_horizontal_flow",
        }

        spacer(dialog_buttons.add {
            type = "empty-widget"
        })

        ---@diagnostic disable-next-line: missing-fields
        style(dialog_buttons, {
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
    get_player_storage(player_id).open[UI_ids.editor] = player_UI
end

---/debug-special command handler.
---@param cmd_data CustomCommandData
local function cmd_launch_ui(cmd_data)
    init_ui(cmd_data.player_index)
end

early_handlers[#early_handlers + 1] = function(evt)
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
end

---@param player LuaPlayer
local function quit_editor(player)
    local player_data = get_player_storage(player.index)
    if player.opened == player_data.open[UI_ids.editor] then
        player.opened = nil
    end
    player_data.open[UI_ids.editor].destroy()
    player_data.open[UI_ids.editor] = nil
end

register_button_handler(Editor_ElementIDs.toplevel_quit_btn, function(evt)
    quit_editor(game.players[evt.player_index])
end)

register_button_handler(Editor_ElementIDs.clear_all, function(evt)
    local player_data = get_player_storage(evt.player_index)
    for _, v in pairs(SpecialGames) do
        -- Try to find the toggle button for this module.
        local container = find(
            player_data.open[UI_ids.editor]
            [Editor_ElementIDs.toplevel_layout]
            [Editor_ElementIDs.main_content],
            listbox_prefixer(v.id)
        )
        if not container then
            log("Error disabling module " .. v.id .. ": container " .. listbox_prefixer(v.id) .. " not found.")
            return
        end
        local togglebtn = find(container, mk_prefix(listbox_prefixer(v.id))("toggle"))
        if togglebtn then
            togglebtn.toggled = false
        end
        v:disable(evt.player_index, container)
    end
end)

---@param evt EventData.on_gui_closed
event.add(defines.events.on_gui_closed, function(evt)
    if not validate_player(evt.player_index) then return end
    local player_data = get_player_storage(evt.player_index)
    if not player_data.open[UI_ids.editor] then return end

    if evt.element == player_data.open[UI_ids.editor] then
        quit_editor(game.players[evt.player_index])
    end
end)

---@param e EventData.on_gui_click
event.add(defines.events.on_gui_click, function(e)
    local screen_name = click_to_ui_lut[e.element.name]
    if not screen_name then return end -- Not an element we care about.

    if not validate_player(e.player_index) then
        -- how did this happen?
        log("Player " .. e.player_index .. " is not valid, but they clicked a button?")
        return
    end

    local player_data = get_player_storage(e.player_index)

    if not player_data.open[screen_name] then
        log("Player " ..
            e.player_index .. " clicked a button, apparently on " .. screen_name .. ", but the UI is not open.")
        return
    end

    for _, cbck in ipairs(early_handlers) do
        if cbck(e) then return end
    end
    local cbcks = handlers[e.element.name]
    if not cbcks then return end
    for _, cbck in pairs(cbcks) do
        cbck(e)
    end
end)
event.on_init(init)

commands.add_command("debug-special", "launch Special Game Editor", cmd_launch_ui)
