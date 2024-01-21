local export = {}

---@enum special.UI_ids
export.UI_ids = {
    editor = "special_editor",
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

---Add an options panel.
---@param parent LuaGuiElement
---@param id string
---@return LuaGuiElement
function export.mk_options(parent, id)
    local options = parent.add {
        type = "frame",
        style = "deep_frame_in_shallow_frame",
        direction = "vertical",
        name = export.mk_prefix(id)("options"),
    }
    ---@diagnostic disable-next-line: missing-fields
    export.style(options, {
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
function export.rm_options(parent, id)
    local options = export.find(parent, export.mk_prefix(id)("options"))
    if options then
        options.destroy()
    end
end

return export