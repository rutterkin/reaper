-- ==========================================
-- CONFIGURATION
-- ==========================================
local CROSSFADE_TIME = 0.03 -- Crossfade duration in seconds
local ENABLE_DEBUG = false  -- Set to true to enable console logs
-- ==========================================

local function DEBUG_LOG(message)
    if ENABLE_DEBUG then
        reaper.ShowConsoleMsg("[xRemove] " .. message .. "\n")
    end
end

local function execute()
    DEBUG_LOG("--- Execution Triggered ---")

    local start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0.0, 0.0, false)
    if start_time == end_time then 
        DEBUG_LOG("ABORT: No time selection detected.")
        return 
    end
    DEBUG_LOG(string.format("Time selection boundary values: Start = %.3f s, End = %.3f s", start_time, end_time))

    local num_sel_tracks = reaper.CountSelectedTracks(0)
    if num_sel_tracks == 0 then 
        DEBUG_LOG("ABORT: No track selected.")
        return 
    end
    DEBUG_LOG("Selected tracks count: " .. tostring(num_sel_tracks))

    local orig_ripple = 0
    if reaper.GetToggleCommandState(40311) == 1 then 
        orig_ripple = 40311
        DEBUG_LOG("Original state: Ripple Edit (All Tracks) enabled.")
    elseif reaper.GetToggleCommandState(40310) == 1 then 
        orig_ripple = 40310
        DEBUG_LOG("Original state: Ripple Edit (Per-track) enabled.")
    else
        DEBUG_LOG("Original state: Ripple Edit disabled.")
    end

    local orig_autox = reaper.GetToggleCommandState(40912)
    DEBUG_LOG("Original state: Auto-crossfade " .. (orig_autox == 1 and "enabled" or "disabled") .. ".")

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    -- Force states required for execution
    if orig_ripple ~= 0 then
        reaper.Main_OnCommand(orig_ripple, 0)
    end

    if orig_autox == 0 then
        reaper.Main_OnCommand(40912, 0)
    end

    DEBUG_LOG("Executing split and delete sequence...")
    reaper.Main_OnCommand(40289, 0)  -- Unselect all items
    reaper.Main_OnCommand(40718, 0)  -- Select items in time selection
    reaper.Main_OnCommand(40061, 0)  -- Split items

    -- Enable Ripple Edit (Per-track)
    reaper.Main_OnCommand(40310, 0)
    
    -- Delete isolated items
    reaper.Main_OnCommand(40006, 0)

    DEBUG_LOG("Selecting right edge items for nudging...")
    reaper.Main_OnCommand(40289, 0)
    for t_idx = 0, num_sel_tracks - 1 do
        local track = reaper.GetSelectedTrack(0, t_idx)
        local item_count = reaper.CountTrackMediaItems(track)
        
        for i = 0, item_count - 1 do
            local item = reaper.GetTrackMediaItem(track, i)
            local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            
            if pos >= start_time - 0.01 then
                reaper.SetMediaItemSelected(item, true)
                break
            end
        end
    end

    -- Parameters: project(0), nudgeflag(0=nudge), nudgewhat(0=position), nudgeunits(0=ms), value, reverse(true=left), copies(0)
    local ms_value = CROSSFADE_TIME * 1000.0
    DEBUG_LOG("Applying nudge: " .. tostring(ms_value) .. " ms left.")
    reaper.ApplyNudge(0, 0, 0, 0, ms_value, true, 0)

    -- Shift markers
    local total_shift = (end_time - start_time) + CROSSFADE_TIME
    DEBUG_LOG("Shifting markers by: " .. tostring(total_shift) .. " seconds.")
    local markers = {}
    local i = 0
    
    while true do
        local retval, isrgn, pos, rgnend, name, midx, color = reaper.EnumProjectMarkers3(0, i)
        if retval == 0 then break end
        
        table.insert(markers, {
            midx = midx, 
            isrgn = isrgn, 
            pos = pos, 
            rgnend = rgnend, 
            name = name, 
            color = color
        })
        i = i + 1
    end

    local shifted_count = 0
    for _, m in ipairs(markers) do
        if m.pos >= end_time then
            local n_pos = m.pos - total_shift
            local n_end = m.isrgn and (m.rgnend - total_shift) or 0
            reaper.SetProjectMarker3(0, m.midx, m.isrgn, n_pos, n_end, m.name, m.color)
            shifted_count = shifted_count + 1
        end
    end
    DEBUG_LOG("Shifted " ..