local export = {}

---@enum special.UI_ids
export.UI_ids = {
    editor = "special_editor",
    editor_export = "special_editor_export",
}

---@param prefix string
---@return fun(name: string): string
function export.mk_prefix(prefix)
    return function(name)
        return prefix .. "_" .. name
    end
end

---Apply styling and layout changes to the element.
---@param element LuaGuiElement
---@param properties LuaStyle
function export.style(element, properties)
    for k, v in pairs(properties) do
        element.style[k] = v
    end
end

function export.spacer(element)
    ---@diagnostic disable-next-line: missing-fields
    export.style(element, {
        horizontally_stretchable = true,
        vertically_stretchable = true,
    })
end

---Find items in the UI.
---@param parent LuaGuiElement
---@param name string
---@return LuaGuiElement | nil
function export.find(parent, name)
    for _, v in pairs(parent.children) do
        if v.name == name then
            return v
        end
    end
    for _, v in pairs(parent.children) do
        local found = export.find(v, name)
        if found then return found end
    end
    return nil
end

---Add an options panel and bar.
---@param parent LuaGuiElement
---@param prefixer (fun(name: string): string) | string
---@return LuaGuiElement container, LuaGuiElement options, LuaGuiElement panel
function export.mk_options(parent, prefixer)
    if type(prefixer) == "string" then
        prefixer = export.mk_prefix(prefixer)
    end
    local options = parent.add {
        type = "frame",
        style = "deep_frame_in_shallow_frame",
        direction = "vertical",
        name = prefixer("options"),
    }
    ---@diagnostic disable-next-line: missing-fields
    export.style(options, {
        horizontally_stretchable = true,
        natural_height = 0,
        margin = 0
    })
    local stack = options.add {
        type = "flow",
        direction = "vertical",
        name = prefixer("stack")
    }
    ---@diagnostic disable-next-line: missing-fields
    export.style(stack, {
        vertical_spacing = 0,
    })
    local actionbar = stack.add {
        type = "frame",
        direction = "horizontal",
        style = "subheader_frame",
        name = prefixer("actionbar")
    }
    ---@diagnostic disable-next-line: missing-fields
    export.style(actionbar, {
        horizontally_stretchable = true,
    })

    local option_frame = stack.add {
        type = "flow",
        direction = "vertical",
        name = prefixer("options_frame")
    }
    ---@diagnostic disable-next-line: missing-fields
    export.style(option_frame, {
        horizontally_stretchable = true,
        padding = 4,
    })
    return options, option_frame, actionbar
end

---Destroy an options panel.
---@param parent LuaGuiElement
---@param prefixer (fun(name: string): string) | string
function export.rm_options(parent, prefixer)
    if type(prefixer) == "string" then
        prefixer = export.mk_prefix(prefixer)
    end
    local options = export.find(parent, prefixer("options"))
    if options then
        options.destroy()
    end
end

---Get the options panel, bar, and container.
---@param parent LuaGuiElement
---@param prefixer fun(name: string): string
---@return LuaGuiElement? container, LuaGuiElement? options, LuaGuiElement? panel
function export.get_options(parent, prefixer)
    local container = parent[prefixer("options")]
    if not container then return nil, nil, nil end

    local stack = container[prefixer("stack")]
    if not stack then return nil, nil, nil end

    local actionbar = stack[prefixer("actionbar")]
    local options_frame = stack[prefixer("options_frame")]

    return container, options_frame, actionbar
end

--- Destroy the options panel and create a new one.
---@param parent LuaGuiElement
---@param prefixer fun(name: string): string
---@return LuaGuiElement container, LuaGuiElement options, LuaGuiElement panel
function export.recreate_options(parent, prefixer)
    local container = export.get_options(parent, prefixer)
    if container then container.destroy() end
    return export.mk_options(parent, prefixer)
end


return export