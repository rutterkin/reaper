# reaper
Plugins/scripts for Cockos Reaper

# REAPER Audio Processing Scripts Repository

This repository contains advanced audio processing and automation scripts for REAPER, utilizing EEL2, Lua, and Python APIs. 

## Installation
1. Move the script files to the `Scripts` folder located in your REAPER user resource directory (`Options > Show REAPER resource path in explorer/finder...`).
2. Open the Action List in REAPER (`Actions > Show action list...` or `?`).
3. Click `New action... > Load ReaScript...` (or the `Load` button, depending on version) and select the desired scripts to register them in your environment.

## 1. Spectral Breath Ducker (EEL2)
**Description**: Automates breath attenuation using FFT-based spectral matching (4096 size window). It acquires a noise/breath template from a time selection, scans selected tracks via `CreateTrackAudioAccessor`, and calculates similarity via vector dot product of magnitudes. If the match exceeds the threshold, it dynamically ducks the `Volume (Pre-FX)` envelope.
**Use Case**: Automated breath reduction in voiceover or dialogue tracks without traditional noise gate artifacts.
**Core Parameters**: `sim_threshold`, `gate_min_db`, `duck_db`.

## 2. Automixer Pro (EEL2)
**Description**: Multi-track lookahead automixer. It performs RMS analysis to dynamically calculate speech vs. noise thresholds per track. Incorporates gap-fill logic and edge-detection for voice takeover, generating envelope nodes on either `Volume (Pre-FX)` or `Volume`.
**Use Case**: Podcast or panel discussion auto-mixing. Reduces mic bleed and background noise automatically based on the active speaker.

## 3. xBreath Toolset (Lua)
**Description**: A modular envelope manipulation system. `xBreath_GUI.lua` provides a native GFX interface to select attenuation levels and stores them in REAPER's `ExtState`. `xBreath_Action.lua` dynamically triggers the GUI if not active, reads the `ExtState`, and injects a precise 4-point ducking curve into the `Volume (Pre-FX)` envelope bounded by the time selection.
**Use Case**: Manual, high-precision breath or plosive attenuation using a dedicated hotkey and UI-driven parameters.

## 4. Automation Node Purger (Lua)
**Description**: Rapid utility script that iterates through selected tracks, targets the `Volume (Pre-FX)` envelope, and deletes all automation nodes within the active time selection using `DeleteEnvelopePointRange`.
**Use Case**: Resetting faulty automation or clearing manual edits instantly across multiple tracks.

## 5. xRemove / Smart Ripple Delete (Lua & Python)
**Description**: Executes a smart ripple delete within a time selection. It splits and deletes isolated items, forces per-track Ripple Edit, shifts remaining items left, and applies an automated Nudge (ms) for crossfading. It dynamically recalculates and shifts Project Markers to maintain synchronization.
**Use Case**: Seamless removal of mistakes or pauses in dialogue editing while automatically crossfading the cut to prevent zero-crossing clicks.

## 6. Python Implementations
**Description**: Python API equivalents of the xBreath and xRemove Lua scripts. The envelope logic is extracted into a modular `process_pre_fx_volume` function to allow direct parameter injection (attenuation, offset time, curve shape).
**Use Case**: Integrating envelope manipulation into larger Python-based automation pipelines or assigning static macros (e.g., fixed 6dB or 9dB reduction) to REAPER toolbars without external UI dependencies.