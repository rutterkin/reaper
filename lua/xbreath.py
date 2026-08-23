import math
from reaper_python import *

def process_pre_fx_volume(attenuation_db=6.0, offset_time=0.05, curve_shape=2):
    time_sel = RPR_GetSet_LoopTimeRange2(0, False, False, 0.0, 0.0, False)
    start_time = time_sel[3]
    end_time = time_sel[4]

    if start_time == end_time:
        return

    track = RPR_GetSelectedTrack(0, 0)
    if not track:
        return

    env = RPR_GetTrackEnvelopeByName(track, "Volume (Pre-FX)")
    if not env:
        return

    mode = RPR_GetEnvelopeScalingMode(env)
    
    start_eval = RPR_Envelope_Evaluate(env, start_time, 0, 0, 0.0, 0.0, 0.0, 0.0)
    end_eval = RPR_Envelope_Evaluate(env, end_time, 0, 0, 0.0, 0.0, 0.0, 0.0)

    val_start = start_eval[5]
    val_end = end_eval[5]

    amp_start = RPR_ScaleFromEnvelopeMode(mode, val_start)
    amp_end = RPR_ScaleFromEnvelopeMode(mode, val_end)

    db_start = 20.0 * math.log10(amp_start) if amp_start > 0 else -150.0
    db_end = 20.0 * math.log10(amp_end) if amp_end > 0 else -150.0

    start_is_zero = abs(db_start) <= 0.01
    end_is_zero = abs(db_end) <= 0.01

    if not start_is_zero and not end_is_zero:
        return

    if (end_time - start_time) <= (offset_time * 2.0):
        return

    val_0db = RPR_ScaleToEnvelopeMode(mode, 1.0)
    val_attenuated = RPR_ScaleToEnvelopeMode(mode, 10.0 ** (-attenuation_db / 20.0))

    RPR_Undo_BeginBlock2(0)

    RPR_DeleteEnvelopePointRange(env, start_time, end_time)

    if start_is_zero and end_is_zero:
        RPR_InsertEnvelopePoint(env, start_time, val_0db, curve_shape, 0.0, False, True)
        RPR_InsertEnvelopePoint(env, start_time + offset_time, val_attenuated, curve_shape, 0.0, False, True)
        RPR_InsertEnvelopePoint(env, end_time - offset_time, val_attenuated, curve_shape, 0.0, False, True)
        RPR_InsertEnvelopePoint(env, end_time, val_0db, curve_shape, 0.0, False, True)
        action_name = f"Duck Volume Pre-FX (-{attenuation_db}dB)"
        
    elif not start_is_zero and end_is_zero:
        RPR_InsertEnvelopePoint(env, start_time, val_start, curve_shape, 0.0, False, True)
        RPR_InsertEnvelopePoint(env, end_time - offset_time, val_start, curve_shape, 0.0, False, True)
        RPR_InsertEnvelopePoint(env, end_time, val_0db, curve_shape, 0.0, False, True)
        action_name = "Flatten Volume Pre-FX (Start dB to 0dB)"
        
    elif start_is_zero and not end_is_zero:
        RPR_InsertEnvelopePoint(env, start_time, val_0db, curve_shape, 0.0, False, True)
        RPR_InsertEnvelopePoint(env, start_time + offset_time, val_end, curve_shape, 0.0, False, True)
        RPR_InsertEnvelopePoint(env, end_time, val_end, curve_shape, 0.0, False, True)
        action_name = "Flatten Volume Pre-FX (0dB to End dB)"

    RPR_Envelope_SortPoints(env)
    RPR_UpdateArrange()
    
    RPR_Undo_EndBlock2(0, action_name, -1)