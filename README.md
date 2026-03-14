# README for qick_processor_452

This repository is based on the open-source **QICK** project.
Please see the original QICK README here:

- [QICK README](README_QICK.md)

For the ISA used by this processor, see:

- [ISA v2 Manual](firmware/ip/qick_processor_452/isa_v2_manual.md)

## 1. Environment

The development environment used for this work is:

- FPGA board: **RFSoC4x2**
- Vivado version: **2023.1**
- Python version: **3.9.13**

## 2. Main source code location

The main source code for this version of the processor is located at:

- `firmware/ip/qick_processor_452`

## 3. Rabi example generation code

The Python code used to generate the Rabi example ASM is located at:

- `firmware/ip/qick_processor_452/src/tb/generate_benchmarks/generate_rabi_asm.py`

Related helper files in the same folder include:

- `firmware/ip/qick_processor_452/src/tb/generate_benchmarks/export_rabi_mem.py`
- `firmware/ip/qick_processor_452/src/tb/generate_benchmarks/export_rabi_asm.py`

## 4. Source code overview

The RTL source code is under:

- `firmware/ip/qick_processor_452/src`

Some important files are:

- `axis_qick_processor.sv`: AXIS wrapper and system integration module for the processor
- `qick_processor_452.sv`: top-level module for this processor version
- `qcore_cpu.sv`: CPU pipeline, decode, branch, and flag logic
- `qcore_mem.v`: program/data/wave memory integration
- `qproc_time_ctrl.sv`: time and scheduling related control
- `_qproc_defines.svh`: compile-time switches and shared definitions
- `tb/`: simulation testbenches and benchmark-generation utilities

## 5. Simulation testbench and memory initialization

The simulation testbench used here is:

- `firmware/ip/qick_processor_452/src/tb/tb_qick_processor_issue35.sv`

Inside this testbench, the following files are used to fill the memories:

- PMEM:
  - `new_prog_rabi.mem` when ``QPROC_452`` is defined
  - `prog_rabi.mem` otherwise
- WMEM:
  - `new_wave_rabi.mem` when ``QPROC_452`` is defined
  - `wave_rabi.mem` otherwise
- DMEM:
  - `new_dmem_rabi.mem` when ``QPROC_452`` is defined
  - `dmem_rabi.mem` otherwise

Which memory files are used is controlled by the `QPROC_452` compile-time switch.

## 6. Switching between the new and old versions

To switch between the new and old processor versions, set the following define in:

- `firmware/ip/qick_processor_452/src/_qproc_defines.svh`

The switch is:

- ``QPROC_452``

`QPROC_452` is a compile-time switch defined in `_qproc_defines.svh`.
It simultaneously controls two things: the CPU version used in the RTL and the memory files loaded in simulation.

When defined, the new 452 CPU path is used and the testbench loads:

- `new_prog_rabi.mem`
- `new_wave_rabi.mem`
- `new_dmem_rabi.mem`

When not defined, the old CPU path is used together with:

- `prog_rabi.mem`
- `wave_rabi.mem`
- `dmem_rabi.mem`

## 7. Create the Vivado project

The Vivado project creation script is:

- `firmware/projects/tproc_452.tcl`

To create the project:

1. Open **Vivado 2023.1**
2. In the Tcl console, go to the projects directory:
   - `cd <your-path>/qick/firmware/projects`
3. Source the script:
   - `source tproc_452.tcl`
> [!NOTE]
    > The path should be the **directory**, not the `.tcl` file itself. 

## 8. Assembler location

If you want to modify the assembler, the main file is:

- `qick_lib/qick/asm_v2.py`



## 9. Additional notes

- This work is built on top of the open-source QICK framework.
- The repository-level QICK README is located at [README.md](README.md).
- The ISA reference for this processor version is [firmware/ip/qick_processor_452/isa_v2_manual.md](firmware/ip/qick_processor_452/isa_v2_manual.md).
