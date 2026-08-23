-- The script removes Volume (Pre-FX) envelope points located on active tracks within the time selection boundaries

local function main()
    -- Get time selection
    local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

    -- Abort if no time selection
    if start_time == end_time then
        return
    end

    -- Abort if no tracks selected
    local num_tracks = reaper.CountSelectedTracks(0)
    if num_tracks == 0 then
        return
    end

    reaper.Undo_BeginBlock()

    -- Process selected tracks
    for i = 0, num_tracks - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        local env = reaper.GetTrackEnvelopeByName(track, "Volume (Pre-FX)")
        
        if env then
            reaper.DeleteEnvelopePointRange(env, start_time, end_time)
            reaper.Envelope_SortPoints(env)
        end
    end

    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Delete Volume (Pre-FX) envelope points", -1)
end

reaper.PreventUIRefresh(1)
main()
reaper.PreventUIRefresh(-1)