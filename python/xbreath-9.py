import sys
import os

# Append current script directory to sys.path to allow local module import
sys.path.append(os.path.dirname(sys.argv[0]))

from xbreath import process_pre_fx_volume

if __name__ == "__main__":
    process_pre_fx_volume(attenuation_db=9.0, offset_time=0.01, curve_shape=2)