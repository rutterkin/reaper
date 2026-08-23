import reaper_python as RPR

# ==========================================
# CONFIGURATION
# ==========================================
CROSSFADE_TIME = 0.05  # Crossfade duration in seconds
# ==========================================

def execute():
    is_set, proj, is_loop, sel_start, sel_end, autoseek = RPR_GetSet_LoopTimeRange2(0, False, False, 0.0, 0.0, False)
    if sel_start == sel_end: 
        return

    num_sel_tracks = RPR_CountSelectedTracks(0)
    if num_sel_tracks == 0: 
        return

    orig_ripple = 0
    if RPR_GetToggleCommandState(40311) == 1: 
        orig_ripple = 40311
    elif RPR_GetToggleCommandState(40310) == 1: 
        orig_ripple = 40310

    orig_autox = RPR_GetToggleCommandState(40912)

    RPR_Undo_BeginBlock()
    RPR_PreventUIRefresh(1)

    if orig_ripple != 0:
        RPR_Main_OnCommand(orig_ripple, 0)

    if orig_autox == 0:
        RPR_Main_OnCommand(40912, 0)

    RPR_Main_OnCommand(40289, 0)  # Unselect all items
    RPR_Main_OnCommand(40718, 0)  # Select items in time selection
    RPR_Main_OnCommand(40061, 0)  # Split items

    # Enable Ripple Edit (Per-track)
    RPR_Main_OnCommand(40310, 0)
    
    # Delete isolated items
    RPR_Main_OnCommand(40006, 0)

    # Select right edge items
    RPR_Main_OnCommand(40289, 0)
    for t_idx in range(num_sel_tracks):
        track = RPR_GetSelectedTrack(0, t_idx)
        item_count = RPR_CountTrackMediaItems(track)
        for i in range(item_count):
            item = RPR_GetTrackMediaItem(track, i)
            pos = RPR_GetMediaItemInfo_Value(item, "D_POSITION")
            
            if pos >= sel_start - 0.01:
                RPR_SetMediaItemSelected(item, 1)
                break

    # FIX: Convert seconds to milliseconds to avoid SWIG float casting issues
    # Parameters: project, flag(0=nudge), what(0=position), units(0=ms), value, reverse(1=left), copies(0)
    ms_value = CROSSFADE_TIME * 1000.0
    RPR_ApplyNudge(0, 0, 0, 0, ms_value, 1, 0)

    # Shift markers
    total_shift = (sel_end - sel_start) + CROSSFADE_TIME
    markers = []
    i = 0
    while True:
        ret, p, num, isrgn, m_pos, rgnend, name, midx, color = RPR_EnumProjectMarkers3(0, i, 0, 0.0, 0.0, "", 0, 0)
        if ret == 0: 
            break
        markers.append((midx, isrgn, m_pos, rgnend, name, color))
        i += 1

    for m in markers:
        midx, isrgn, m_pos, rgnend, name, color = m
        if m_pos >= sel_end:
            n_pos = m_pos - total_shift
            n_end = rgnend - total_shift if isrgn else 0
            RPR_SetProjectMarker3(0, midx, isrgn, n_pos, n_end, name, color)

    # Clean up and restore UI states
    RPR_Main_OnCommand(40020, 0)
    
    RPR_Main_OnCommand(40310, 0)
    if orig_ripple != 0:
        RPR_Main_OnCommand(orig_ripple, 0)

    if orig_autox == 0:
        RPR_Main_OnCommand(40912, 0)

    RPR_UpdateArrange()
    RPR_PreventUIRefresh(-1)
    RPR_Undo_EndBlock("Native Action Crossfade", -1)

execute()