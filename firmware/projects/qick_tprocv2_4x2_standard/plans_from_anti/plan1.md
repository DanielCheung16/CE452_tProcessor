# Implement Receiver to PS Interface

This plan outlines how to connect a custom receiver (readout) module to the Processing System (PS) on the RFSoC, following the teacher's suggestion to use Xilinx Register Slices for timing closure.

## User Review Required

> [!IMPORTANT]
> This plan assumes you are developing an IP core with AXI-Lite (for control) and AXI-Stream (for data) interfaces, similar to existing QICK readout modules.

## Proposed Changes

### 1. Receiver IP Design (HDL)
The receiver should follow the `axis_readout_v2` pattern:
- **`s_axi` interface**: For the PS to read/write registers.
- **`s_axis` interface**: To receive data from the ADC or Signal Generator.
- **`m_axis` interface**: To output processed data to the PS.

### 2. Block Design (Vivado)
The "implementation of the PS side" involves the following connections in the Block Design:

#### Control Path (AXI-Lite)
1. **Connect** the PS `M_AXI_HPM0_FPD` (or similar) master to an **AXI SmartConnect**.
2. **Add** an **AXI Register Slice** IP.
3. **Configure** the Register Slice as **AXI4-Lite**.
4. **Connect** the SmartConnect output to the Register Slice input.
5. **Connect** the Register Slice output to the receiver's `s_axi` port.

#### Data Path (AXI-Stream)
1. **Add** an **AXI DMA** IP (configured for S2MM - Stream to Memory Mapped).
2. **Add** an **AXI Register Slice** IP.
3. **Configure** the Register Slice as **AXI4-Stream**.
4. **Connect** the receiver's `m_axis` output to the Register Slice input.
5. **Connect** the Register Slice output to the AXI DMA `S_AXIS_S2MM` port.
6. **Connect** the AXI DMA `M_AXI_S2MM` master to the PS `S_AXI_HPC0_FPD` (or similar) slave port via an AXI SmartConnect.

## Verification Plan

### Manual Verification
1. **Address Mapping**: Ensure the receiver's `s_axi` is assigned an address in the Vivado Address Editor.
2. **Bitstream Generation**: Run Synthesis and Implementation to verify that the **Register Slice** helps meet timing requirements (check the Timing Summary).
3. **Python (PYNQ) Test**:
    - Use the `qick` Python library or raw `mmap` to write to the receiver's registers.
    - Use PYNQ's DMA object to trigger a data transfer from the receiver to a buffer in PS memory.
