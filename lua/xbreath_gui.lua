-- xBreath_GUI.lua
-- Native GFX implementation (No dependencies)

local ext_section = "xBreath"
local options_db = {3.0, 6.0, 9.0, 12.0}

-- State Initialization
local current_val = tonumber(reaper.GetExtState(ext_section, "attenuation_db"))
if not current_val then 
    current_val = 6.0 
    reaper.SetExtState(ext_section, "attenuation_db", tostring(current_val), true)
end

reaper.SetExtState(ext_section, "GUI_State", "running", false)

local function OnExit()
    reaper.SetExtState(ext_section, "GUI_State", "stopped", false)
end
reaper.atexit(OnExit)

-- GFX Window Initialization
gfx.init("xBreath Settings", 200, 150, 0, 100, 100)
gfx.setfont(1, "Arial", 16)

-- Colors
local COLOR_BG = {0.15, 0.15, 0.15}
local COLOR_TEXT = {0.9, 0.9, 0.9}
local COLOR_ACTIVE = {0.8, 0.8, 0.2}
local COLOR_INACTIVE = {0.4, 0.4, 0.4}

local last_mouse_cap = 0

local function MainLoop()
    -- Handle window close
    if gfx.getchar() == -1 then return end
    
    -- Draw Background
    gfx.clear = 8947848
    
    -- Draw Header
    gfx.x, gfx.y = 15, 15
    gfx.set(COLOR_TEXT[1], COLOR_TEXT[2], COLOR_TEXT[3], 1)
    gfx.drawstr("Attenuation (dB):")
    
    gfx.x = 15
    gfx.y = 35
    gfx.line(15, 35, 185, 35)
    
    -- Mouse State
    local mouse_click = (gfx.mouse_cap & 1 == 1) and (last_mouse_cap & 1 == 0)
    last_mouse_cap = gfx.mouse_cap
    
    -- Render Radio Buttons & Hitboxes
    local y_offset = 50
    for _, val in ipairs(options_db) do
        local is_active = (current_val == val)
        local label = tostring(val) .. " dB"
        
        -- Hitbox detection
        local is_hovered = (gfx.mouse_x >= 15 and gfx.mouse_x <= 150 and gfx.mouse_y >= y_offset - 5 and gfx.mouse_y <= y_offset + 15)
        
        if is_hovered and mouse_click then
            current_val = val
            reaper.SetExtState(ext_section, "attenuation_db", tostring(val), true)
        end
        
        -- Draw Radio Circle
        if is_active then
            gfx.set(COLOR_ACTIVE[1], COLOR_ACTIVE[2], COLOR_ACTIVE[3], 1)
            gfx.circle(20, y_offset + 6, 6, 1, 1) -- Filled
        else
            gfx.set(COLOR_INACTIVE[1], COLOR_INACTIVE[2], COLOR_INACTIVE[3], 1)
            gfx.circle(20, y_offset + 6, 6, 0, 1) -- Outline
        end
        
        -- Draw Label
        gfx.set(COLOR_TEXT[1], COLOR_TEXT[2], COLOR_TEXT[3], 1)
        gfx.x, gfx.y = 40, y_offset
        gfx.drawstr(label)
        
        y_offset = y_offset + 25
    end
    
    gfx.update()
    reaper.defer(MainLoop)
end

reaper.defer(MainLoop)