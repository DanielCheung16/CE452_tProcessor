import os
import sys

# Ensure qick_lib is on track
qick_lib_path = os.path.abspath(r"e:\Homework_NU\winter_project\qick\qick_lib")
if qick_lib_path not in sys.path:
    sys.path.insert(0, qick_lib_path)

# Import the rabi program
from generate_rabi_asm import prog

# Utilize asm_v2.py compile engine
prog.compile()

# pmem_path = r"..\prog_rabi.mem"
# wmem_path = r"..\wave_rabi.mem"
# dmem_path = r"..\dmem_rabi.mem"

pmem_path = r"..\new_prog_rabi.mem"
wmem_path = r"..\new_wave_rabi.mem"
dmem_path = r"..\new_dmem_rabi.mem"

# 1. PMEM
with open(pmem_path, "w") as f:
    f.write("// PMEM content\n")
    for line in prog.binprog['pmem']:
        # line is a list of 8 ints, [n0, n1, n2, ...] where n2 is top 8 bits, n1 is mid 32 bits, n0 is bot 32 bits
        val = (line[2] << 64) | (line[1] << 32) | line[0]
        hex_str = f"{val:018x}"
        f.write(f"{hex_str}\n")

# 2. WMEM
with open(wmem_path, "w") as f:
    f.write("// WMEM content\n")
    waves = prog.binprog.get('wmem', [])
    if waves:
        for w in waves:
            # w is a list of integers. Standard tproc v2 wave length is packed into 8 32-bit words
            val = 0
            for i, word in enumerate(w):
                val |= (word & 0xFFFFFFFF) << (32 * i)
            # 168 bit (actual wave valid payload is usually 168 or 256 bits)
            # We pad it to 42 hex characters (168 bits) just like wave_issue35.mem
            hex_str = f"{val:042x}"
            f.write(f"{hex_str}\n")

# 3. DMEM
with open(dmem_path, "w") as f:
    f.write("// DMEM content\n")
    dmem = prog.binprog.get('dmem', [])
    if dmem:
        for d in dmem:
            f.write(f"{d:08x}\n")

print(f"Extraction successful: PMEM={len(prog.binprog['pmem'])} instructions")
