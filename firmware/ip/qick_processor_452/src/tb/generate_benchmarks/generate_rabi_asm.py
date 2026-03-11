import sys
import os

# ---------------------------------------------------------
# QICK Rabi ASM Generator for RFSoC4x2
# ---------------------------------------------------------

# Try multiple possible library paths
possible_paths = [
    r"e:\Homework_NU\winter_project\qick\qick_lib",
    r"C:\Users\DC\Downloads\qick\qick_lib",  # fallback example
    os.path.join(os.getcwd(), "qick_lib")
]
for p in possible_paths:
    if os.path.exists(p):
        sys.path.insert(0, p)
        break

from qick import QickConfig
from qick.asm_v2 import QickProgramV2

# RFSoC4x2 standard configuration parameters
# (Based on standard firmware defaults)
dummy_cfg = {
    'board': 'RFSoC4x2',
    'refclk_freq': 245.76,
    'gens': [
        {
            'type': 'axis_signal_gen_v6', 
            'dac': '20', 
            'tproc_ch': 0, 
            'fs': 9830.4, 
            'fs_mult': 40,
            'ref_div': 1,
            'f_fabric': 491.52, 
            'samps_per_clk': 16, 
            'has_dds': True,
            'has_mixer': False,
            'maxv': 32766,
            'maxv_scale': 1.0,
            'b_dds': 32,
            'b_phase': 32,
            'maxlen': 65536,
            'complex_env': True,
            'interpolation': 1,
            'f_dds': 9830.4,
            'fdds_div': 1
        }
    ],
    'readouts': [
        {
            'ro_type': 'axis_dyn_readout_v1',
            'adc': '20',
            'tproc_ctrl': 4, 
            'fs': 4915.2, 
            'fs_mult': 20,
            'ref_div': 1,
            'f_fabric': 491.52, 
            'b_dds': 32,
            'b_phase': 32,
            'f_dds': 4096.0,
            'fdds_div': 4,
            'f_output': 491.52,
            'avgbuf_type': 'axis_avg_buffer',
            'has_outsel': True,
            'has_weights': False,
            'has_edge_counter': True,
            'trigger_type': 'tport',
            'trigger_port': 0,
            'trigger_bit': 0,
            'ro_revision': 3
        }
    ],
    'tprocs': [
        {
            'type': 'qick_processor', 
            'f_core': 200.0, 
            'f_time': 491.52, 
            'pmem_size': 4096, 
            'dmem_size': 16384,
            'wmem_size': 1024,
            'dreg_qty': 16,
            'in_port_qty': 1,
            'out_trig_qty': 20,
            'out_dport_qty': 1,
            'out_wport_qty': 16,
            'revision': 27,
            'version': '2.0'
        }
    ]
}

config = QickConfig(dummy_cfg)

from qick.asm_v2 import AveragerProgramV2

class RabiProgram(AveragerProgramV2):
    def _initialize(self, cfg):
        # ch=0 corresponds to the tproc_ch=0 defined above
        self.declare_gen(ch=0, nqz=1)
        self.declare_readout(ch=0, length=100)
        self.add_pulse(ch=0, name="rabi_pulse", ro_ch=0, style="const", length=0.1, freq=1000, phase=0, gain=30000)

    def _body(self, cfg):
        # In V2, we often use macros
        self.send_readoutconfig(ch=0, name="rabi_pulse", t=0)
        self.pulse(ch=0, name="rabi_pulse", t=0)
        self.delay_auto(0.1, gens=False, ros=True)

soccfg = QickConfig(dummy_cfg)
prog = RabiProgram(soccfg, reps=10, final_delay=1.0, cfg=dummy_cfg)
print("================ GENERATED RABI ASM ================")
print(prog.asm())
print("===============================================================")
