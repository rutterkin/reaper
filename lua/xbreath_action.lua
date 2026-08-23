-- The main script attenuating the time selection by the decibel amount defined in the GUI. 
-- How it works: make a time selection and run the xbreath_action.lua script. It first checks
-- if the GUI from the xbreath_gui.lua script is displayed (if not, it launches it) and based on the
-- attenuation value selected there, modifies the Volume Pre-FX envelope to attenuate the breath.

local ext_section = "xBreath"
local offset_time = 0.05
local curve_shape = 2

-- Configuration
local ENABLE_DEBUG = false -- Set to true to enable console logs

-- Internal logging system
local function DEBUG_LOG(message)
    if ENABLE_DEBUG then
        reaper.ShowConsoleMsg("[xBreath] " .. message .. "\n")
    end
end

DEBUG_LOG("--- Execution Triggered ---")

-- 1. Dynamic GUI Loader & State Validation
local gui_state = reaper.GetExtState(ext_section, "GUI_State")
DEBUG_LOG("System ExtState for GUI: " .. (gui_state == "" and "EMPTY" or gui_state))

if gui_state ~= "running" then
    DEBUG_LOG("GUI not detected. Initiating dynamic boot sequence...")
    local _, script_file, _, _, _ = reaper.get_action_context()
    local path_dir = script_file:match("^(.*)[/\\]")
    
    if not path_dir then 
        DEBUG_LOG("CRITICAL: Cannot determine script execution path.")
        return 
    end
    
    local gui_script_path = path_dir .. "/xbreath_gui.lua"
    local cmd_id = reaper.AddRemoveReaScript(true, 0, gui_script_path, true)
    
    if cmd_id and cmd_id > 0 then
        reaper.Main_OnCommand(cmd_id, 0)
        DEBUG_LOG("GUI registered and started successfully (Command ID: " .. tostring(cmd_id) .. ").")
    else
        DEBUG_LOG("CRITICAL: GUI script missing or failed to register at: " .. gui_script_path)
        return
    end
else
    DEBUG_LOG("GUI is actively running in background.")
end

-- 2. Fetch Audio Processing Parameters
local attenuation_db = tonumber(reaper.GetExtState(ext_section, "attenuation_db")) or 6.0
DEBUG_LOG("Active attenuation parameter: -" .. tostring(attenuation_db) .. " dB")

local start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0.0, 0.0, false)

if start_time == end_time then 
    DEBUG_LOG("ABORT: No time selection detected.")
    return 
end

local track = reaper.GetSelectedTrack(0, 0)
if not track then 
    DEBUG_LOG("ABORT: No track selected.")
    return 
end

-- 3. Automatic Envelope Activation
local env = reaper.GetTrackEnvelopeByName(track, "Volume (Pre-FX)")
if not env then 
    DEBUG_LOG("Envelope 'Volume (Pre-FX)' not found. Forcing activation...")
    reaper.Main_OnCommand(41866, 0) -- Native Action: Track: Show volume (Pre-FX) envelope
    
    env = reaper.GetTrackEnvelopeByName(track, "Volume (Pre-FX)")
    if not env then
        DEBUG_LOG("CRITICAL: Envelope activation failed systemically.")
        return
    else
        DEBUG_LOG("Envelope initialized and hooked successfully.")
    end
else
    DEBUG_LOG("Envelope 'Volume (Pre-FX)' hooked successfully.")
end

-- 4. Execution Logic
local mode = reaper.GetEnvelopeScalingMode(env)

local _, val_start = reaper.Envelope_Evaluate(env, start_time, 0, 0)
local _, val_end = reaper.Envelope_Evaluate(env, end_time, 0, 0)

local amp_start = reaper.ScaleFromEnvelopeMode(mode, val_start)
local amp_end = reaper.ScaleFromEnvelopeMode(mode, val_end)

local db_start = (amp_start > 0) and (20.0 * (math.log(amp_start) / math.log(10))) or -150.0
local db_end = (amp_end > 0) and (20.0 * (math.log(amp_end) / math.log(10))) or -150.0

DEBUG_LOG(string.format("Time selection boundary values: Start = %.2f dB, End = %.2f dB", db_start, db_end))

local start_is_zero = math.abs(db_start) <= 0.01
local end_is_zero = math.abs(db_end) <= 0.01

if not start_is_zero and not end_is_zero then 
    DEBUG_LOG("ABORT: Boundary points do not meet the 0.01 dB tolerance for insertion.")
    return 
end

if (end_time - start_time) <= (offset_time * 2.0) then 
    DEBUG_LOG("ABORT: Time selection is too short for the configured envelope offset.")
    return 
end

local val_0db = reaper.ScaleToEnvelopeMode(mode, 1.0)
local val_attenuated = reaper.ScaleToEnvelopeMode(mode, 10.0 ^ (-attenuation_db / 20.0))

reaper.Undo_BeginBlock2(0)
reaper.DeleteEnvelopePointRange(env, start_time, end_time)
DEBUG_LOG("Existing points within selection purged.")

local action_name = ""

if start_is_zero and end_is_zero then
    reaper.InsertEnvelopePoint(env, start_time, val_0db, curve_shape, 0.0, false, true)
    reaper.InsertEnvelopePoint(env, start_time + offset_time, val_attenuated, curve_shape, 0.0, false, true)
    reaper.InsertEnvelopePoint(env, end_time - offset_time, val_attenuated, curve_shape, 0.0, false, true)
    reaper.InsertEnvelopePoint(env, end_time, val_0db, curve_shape, 0.0, false, true)
    action_name = "Duck Volume Pre-FX (-" .. tostring(attenuation_db) .. "dB)"
    
elseif not start_is_zero and end_is_zero then
    reaper.InsertEnvelopePoint(env, start_time, val_start, curve_shape, 0.0, false, true)
    reaper.InsertEnvelopePoint(env, end_time - offset_time, val_start, curve_shape, 0.0, false, true)
    reaper.InsertEnvelopePoint(env, end_time, val_0db, curve_shape, 0.0, false, true)
    action_name = "Flatten Volume Pre-FX (Start dB to 0dB)"
    
elseif start_is_zero and not end_is_zero then
    reaper.InsertEnvelopePoint(env, start_time, val_0db, curve_shape, 0.0, false, true)
    reaper.InsertEnvelopePoint(env, start_time + offset_time, val_end, curve_shape, 0.0, false, true)
    reaper.InsertEnvelopePoint(env, end_time, val_end, curve_shape, 0.0, false, true)
    action_name = "Flatten Volume Pre-FX (0dB to End dB)"
end

reaper.Envelope_SortPoints(env)
reaper.UpdateArrange()
reaper.Undo_EndBlock2(0, action_name, -1)
DEBUG_LOG("SUCCESS: Points injected (" .. action_name .. "). Engine update complete.")