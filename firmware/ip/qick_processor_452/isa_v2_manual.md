# QICK tProc v2 ISA Manual (Bit-Level Detail)

This document provides the definitive bit-level specification for the **tProc v2** (72-bit) architecture.

---

## 1. Instruction Overview (72-bit)
Every instruction consists of a **16-bit Header** and a **56-bit Payload**.

### 1.1 Header Format [bit 71:56] <a id="header_and_payload"></a>
| Bits  | Field        | Description                                                                     |
| :---: | :----------- | :------------------------------------------------------------------------------ |
| 71:69 | **OpCode**   | Main Category (see Section 3)                                                   |
|  68   | **AI**       | **Address Immediate**: 1 = Use `IMM_ADDR` as operand; 0 = Use Register.         |
| 67:66 | **DF**       | **Data Format**: 00=16b Addr, 01=16b Signed IMM, 10=24b Signed IMM, 11=32b IMM. |
| 65:63 | **COND**     | **Condition Code**: Evaluation of ALU flags/External flag (see Section 2.4).    |
|  62   | **SO**       | **Sub-Option**: Differentiates operations within a Category.                    |
|  61   | **TO**       | **Time Option**: 1 = Timed instruction (uses `s14`); 0 = Immediate.             |
|  60   | **UF**       | **Update Flag**: 1 = Update `Z/S` flags based on result.                        |
| 59:56 | **Misc/ALU** | Sub-Op or ALU Ops (Category dependent).                                         |

### 1.2 Payload Format [bit 55:0]
Interpretation depends on the **AI** and **DF** flags.

| Bits  | Default Field | Description                                          |
| :---: | :------------ | :--------------------------------------------------- |
| 55:45 | `IMM_ADDR`    | 11-bit Immediate Address (if **AI=1**).              |
| 50:45 | `rsA0`        | Source Register A0 (if **AI=0**).                    |
| 44:39 | `rsA1`        | Source Register A1 (often used as offset).           |
| 38:7  | `IMM_DATA`    | Up to 32-bit Immediate Data (Muxed based on **DF**). |
| 37:31 | `rsD0`        | Source Register D0.                                  |
| 29:23 | `rsD1`        | Source Register D1 (only if **DF=01**).              |
|  6:0  | **RD**        | **Destination Register** (7-bit address).            |

---

## 2. Register Architecture
The processor supports 128 registers, divided into four 32-register pages.

### 2.1 Register Map (7-bit Address)
| Address Range       | Type     | Implementation                                             |
| :------------------ | :------- | :--------------------------------------------------------- |
| `0000000 - 0011111` | **SReg** | Special Function Registers (16 implemented: `s0-s15`).     |
| `0100000 - 0111111` | **DReg** | General Purpose Data Registers (16 implemented: `r0-r15`). |
| `1000000 - 1011111` | **WReg** | Waveform Registers (6 implemented: `w0-w5`).               |
| `1100000 - 1111111` | **RFU**  | Reserved for Future Use.                                   |

### 2.2 Special Function Registers (SReg)
| Reg     | Mnemonic     | Description                                       |
| :------ | :----------- | :------------------------------------------------ |
| `s0`    | `zero`       | Constant 0.                                       |
| `s1`    | `s_rand`     | 32-bit LFSR Random Number.                        |
| `s2`    | `s_cfg`      | Config [7:0] and Control [23:16].                 |
| `s3`    | `s_arith`    | ALU 32-bit result (DSP block).                    |
| `s4-s5` | `s_div`      | Divider Quotient (`s4`) and Remainder (`s5`).     |
| `s10`   | `s_status`   | Processor status flags.                           |
| `s11`   | `s_time`     | **User Time**: Lower 32 bits of 48-bit reference. |
| `s14`   | `s_out_time` | **Excution Time**: Timestamp for next output.     |
| `s15`   | `s_addr`     | Return address for call/ret.                      |

### 2.3 Condition Codes (COND [65:63])
The processor evaluates conditions in the **ID (Decode)** stage using internal, non-addressable flag registers. **IF the condition is met, the instruction is executed. Otherwise, the instruction is discarded.**

#### Flag Registers (Internal, simple flip-flops, 1-bit each)
- **`alu_fZ_r` (Zero Flag)**: Set if the result of an ALU operation is zero.
- **`alu_fS_r` (Sign Flag)**: Set if the result of an ALU operation is negative (MSB=1).

> [!IMPORTANT]
> **Update Mechanism**: Flags are ONLY updated if the **Update Flag (UF)** bit of an instruction is set to **1**. If `UF=0`, the flags retain their previous values.

#### Condition Evaluation Table
| Code  | Mnemonic   | Logical Condition | Description                                 |
| :---: | :--------- | :---------------: | :------------------------------------------ |
| `000` | **ALWAYS** |        `1`        | Unconditional execution.                    |
| `001` | **EQ**     |     `Z == 1`      | Execute if Zero.                            |
| `010` | **LT**     |     `S == 1`      | Execute if Negative (Less Than 0).          |
| `011` | **NZ**     |     `Z == 0`      | Execute if Not Zero.                        |
| `100` | **NS**     |     `S == 0`      | Execute if Not Negative (Positive or Zero). |
| `101` | **FLAG**   |   `flag_i == 1`   | Execute if **External Flag** is High.       |
| `110` | **NFLAG**  |   `flag_i == 0`   | Execute if **External Flag** is Low.        |

*Note: `flag_i` is an external signal muxed from sources like AXI control or external FPGA pins.*

---

## 3. ALL Instructions (General)

The following table supplements the [previous format](#header_and_payload).

### 3.1 Bit Field Definitions

| Bit Range   | Field          | Description                                                                        |
| :---------- | :------------- | :--------------------------------------------------------------------------------- |
| **[71:69]** | **Op**         | **OpCode Category**: Defines the primary instruction group (000-111).              |
| **[68]**    | **AI**         | **Address / ALU Immediate**: 1 = Use Payload Immediate, 0 = Use Register.          |
| **[67:66]** | **DF**         | **Data Format**: Defines immediate data length (16b, 16b Signed, 24b Signed, 32b). |
| **[65:63]** | **COND / SRC** | **Condition / Source**: 3-bit condition code or hardware source selector.          |
| **[62]**    | **SO**         | **Special Option**: Often distinguishes Data (0) vs Waveform (1) operations.       |
| **[61]**    | **TO**         | **Time Option**: 1 = Executed at absolute time in `s14` (Scheduled).               |
| **[60]**    | **UF**         | **Update Flags**: 1 = Update Arithmetic flags (`Z`, `S`) based on result.          |
| **[59:56]** | **Sub_Op**     | **Sub-Operation**: 4-bit field for ALU operations or peripheral sub-types.         |
| **[55:45]** | **IMM_ADDR**   | **Address Immediate**: 11-bit address for Memory, Jump, or Ports.                  |
| **[50:45]** | **rsA0**       | **Source Address 0**: 6-bit register index (s0-s63).                               |
| **[44:39]** | **rsA1**       | **Source Address 1**: 6-bit register index (s0-s63).                               |
| **[38:7]**  | **IMM_DATA**   | **Immediate Data**: Up to 32 bits of immediate value (overlaps with rsD).          |
| **[37:31]** | **rsD0**       | **Source Data 0**: 7-bit register index (r0-r127).                                 |
| **[30:23]** | **rsD1**       | **Source Data 1**: 7-bit register index (r0-r127).                                 |
| **[6:0]**   | **RD**         | **Destination Register**: 7-bit index for the result.                              |

### 3.2 Master Instruction Table

| Category    | Mnemonic       |  Op   |  AI   |  DF   | SRC(header[8])/COND |  SO   |  TO   |  UF   |  Sub   | Payload Layout           |
| :---------- | :------------- | :---: | :---: | :---: | :-----------------: | :---: | :---: | :---: | :----: | :----------------------- |
| **Control** | `jump`         |  001  |  AI   |  00   |        COND         |   0   |   0   |   0   |  0000  | `[IMM/rsA0, rsA1]`       |
|             | `call`         |  001  |  AI   |  00   |        COND         |   1   |   0   |   0   |  0000  | `[IMM/rsA0, rsA1]`       |
|             | `ret`          |  001  |   0   |  00   |         000         |   1   |   1   |   0   |  0000  | *Pops s15*               |
| **Compute** | `reg_wr` (ALU) |  100  |  AI   |  DF   |        COND         |   0   |  TO   |  UF   | ALU_Op | `[rsD0, rsD1/IMM, RD]`   |
|             | `wreg` (Bulk)  |  100  |  AI   |  00   |         000         |   1   |   0   |   0   |  0000  | `[IMM/rsA0, RD=WReg]`    |
| **Memory**  | `dmem_wr`      |  101  |  AI   |  DF   |        COND         |   0   |  TO   |   0   |  0000  | `[IMM/rsA0, rsA1, rsD0]` |
|             | `wmem_wr`      |  101  |  AI   |  00   |         000         |   1   |   0   |   0   |  0000  | `[IMM/rsA0, rsA1, WReg]` |
| **Ports**   | `dport_wr`     |  110  |  AI   |  DF   |         001         |   0   |   0   |   0   |  0000  | `[rsA1=Port, rsD0]`      |
|             | `dport_rd`     |  110  |  AI   |  DF   |         000         |   0   |   0   |   0   |  0000  | `[rsA1=Port, RD]`        |
|             | `wport_wr`     |  110  |  AI   |  00   |         SRC         |   1   |  TO   |   0   |  0000  | `[rsA1=Port, rsA0/IMM]`  |
| **System**  | `time`         |  010  |  AI   |  00   |        COND         |   0   |   0   |   0   | TimeOp | `[rsA0/IMM]`             |
|             | `cfg`          |  000  |  AI   |  DF   |        COND         |  SO   |  TO   |  UF   | ALU_Op | `[rsD0, rsD1/IMM, RD]`   |

---

## 4. Timing Architecture
The tProc v2 separates **Absolute Time** from **Processor Time**.

1.  **Absolute Time (48-bit)**: Maintained in hardware.
2.  **Reference Time (T_ref)**: Set by the host.
3.  **User Time (s11)**: `(Absolute_Time - T_ref)[31:0]`.
4.  **Scheduled Time (s14)**: Instructions with `TO=1` use `s14` to schedule execution relative to `T_ref`.

---
## 5.Categories and OpCodes (details and according to functions)
### 5.1 Computational Core (reg_wr)
<font color="#008cffff">This category is for writing data to all addressable registers: Data (DReg), Special Function (SReg), and Waveform segments (WReg).</font>  

#### 5.1.1 alu operations <a id="alu-ops"></a>
* Header: `[Op=100, AI, DF, COND, SO=0, TO=0, UF, alu_sub_op]`  
* Payload: `[rsD0, rsD1, RD]` or `[rsD0, IMM_DATA, RD]` (depends on <font color="green">DF</font>)
> ALL the bits not mentioned above are ingnored

| alu_sub_op [3:0] | Mode  | Mnemonic | Logic Operation                    |
| :--------------: | :---: | :------- | :--------------------------------- |
|      `0000`      | Arith | **add**  | `A + B`                            |
|      `0010`      | Arith | **sub**  | `A - B`                            |
|      `0100`      | Arith | **and**  | `A & B`                            |
|      `0110`      | Arith | **asr**  | `A >>> B` (Arithmetic Shift Right) |
|      `1000`      | Arith | **abs**  | `abs(B)`                           |
|      `1010`      | Arith | **msh**  | `{16'b0, A[31:16]}`                |
|      `1100`      | Arith | **lsh**  | `{16'b0, A[15:0]}`                 |
|      `1110`      | Arith | **swp**  | `{A[15:0], A[31:16]}`              |
|      `0001`      | Logic | **not**  | `~A`                               |
|      `0011`      | Logic | **or**   | `A \| B`                           |
|      `0101`      | Logic | **xor**  | `A ^ B`                            |
|      `0111`      | Logic | **cat**  | `{A[15:0], B[15:0]}`               |
|      `1001`      | Logic | **clr**  | `0`                                |
|      `1011`      | Logic | **par**  | `{31'b0, ^A}` (Parity)             |
|      `1101`      | Logic | **sl**   | `A << B` (Logical Shift Left)      |
|      `1111`      | Logic | **lsr**  | `A >> B` (Logical Shift Right)     |

#### 5.1.2 load operations
Those are instructions that load data from Data Memory (DMem) to registers.
* Header: `[Op=100, AI, COND, SO=0, TO=1, UF]`  
* Payload: `[rsA0/IMM, rsA1, RD]` (depends on <font color="green">AI</font>)
> ALL the bits not mentioned above are ingnored (e.g. Ignore rsD0, rsD1, and ALU_sub_op)

**Address Calculation Logic**: `Memory_Address = (AI ? IMM_ADDR : rsA0) + rsA1`<a id="normal_addr_cal"></a>

#### 5.1.3 Configuration and Flag Testing (cfg)
This catagory is for updating internal flags (does not change data registers) or doing nothing. Only sub_set of ALU operations are used.

*   **Header**: `[Op=000, AI, DF, COND, UF, alu_sub_op]`
*   **Payload**: `[rsD0, rsD1/IMM, RD=s0]`
> ALL the bits not mentioned above are ingnored

| alu_sub_op (Header[1:0]) | Mode  | Mnemonic | Logic Operation                    |
| :----------------------: | :---: | :------- | :--------------------------------- |
|           `00`           | Arith | **add**  | `A + B`                            |
|           `01`           | Arith | **sub**  | `A - B`                            |
|           `10`           | Logic | **and**  | `A & B`                            |
|           `11`           | Arith | **asr**  | `A >>> B` (Arithmetic Shift Right) |

**Typical Instructions:**

1.  **`nop` (No Operation)**
    *   **Header**: `0x0000` (all control bits are 0)
    *   **Effect**: No operation, no flag update, no register change.

2.  **`test <op>` (Flag Update Only)**
    *   **Header**: `UF=1`
    *   **Effect**: Perform calculation and update `Z/S` flags based on result, discard result (not written to register).

3.  **`reg_wr_cfg` (Fused Config Write)**
    *   **Header**: `dual_we=1`(Header[3], special write enable)
    *   **Effect**: Allow writing to target register `RD` in `cfg` category. Data source determined by `src_sel` (Header[2]) (0: alu, 1: imm).
  
### 5.2 The Timing and Pulse Core
This core manages high-precision pulse generation and time synchronization, covering Waveform Register operations, Waveform Memory storage, and real-time Port triggers.

#### 5.2.1 Waveform Register Segments (`w0-w5`)
The processor contains a single 168-bit active **Waveform Register (WReg)**. To allow flexible control, **WReg** consists of six 32-bit segments.

*   **Segment Writing (`reg_wr`)**: Updates a single segment (32-bit). Data sources: ALU, DReg, SReg, or IMM ([as mentioned in 5.1.1](#alu-ops)).
*   **Bulk Loading (`wreg`)**: Updates the entire 168-bit register in one cycle. Data source: <font color = "green">Waveform Memory (WMem)</font>.
    *   **Header**: `[Op=100, AI, SRC(Header[8])=0, SO=1, TO=0]`
    *   **Unconditional**: Note that `wreg` does **not** evaluate `COND`.
    > [!NOTE]
    > Unlike DMem, Waveform Memory operations **do not** use the `rsA1` offset.  
    > **Address Calculation**: `WMem_Addr = (AI ? IMM_ADDR : rsA0)`. ([comparison](#normal_addr_cal))
    *   **Payload**: `[rsA0/IMM_ADDR, RD=WReg]`

#### 5.2.2 Waveform Port Write (`wport_wr`)
**Physical meaning**: Triggers a pulse. It sends all parameters from the WReg (frequency, phase, address, etc.) to the underlying Signal Generator.

*   **Header**: `[Op=110, AI, SRC(Header[8]), SO=1, TO]`
    *   **Unconditional**: Note that `wport_wr` does **not** evaluate `COND`.
    *   **SRC** (Bit 64 / Header[8]): **Source Selection**.
        - `SRC = 1`: Trigger from **WReg** (Registers).
        - `SRC = 0`: Trigger from **WMEM** (Memory, address via `rsA0/IMM_ADDR`).
*   **Timed Execution**: Depends on `TO`:

    | **TO** | Logic Operation                                                                  |
    | :----: | :------------------------------------------------------------------------------- |
    |  `0`   | triggers immediately                                                             |
    |  `1`   | the instruction triggers at the precise time scheduled in `s14` (Scheduled Time) |


*   **Payload**: Determines which port is triggered and where the data comes from.
    *   **Port Address (`rsA1`)**: Specifies the target Signal Generator/Port index (6-bit).
    *   **Source Address (`rsA0` or `IMM_ADDR`)**: Used if triggering directly from Waveform Memory (WMEM).
    *   **Data Content**: The 168-bit pulse parameters are sent to the target port.

#### 5.2.3 Waveform Memory Write (`wmem_wr`)
Backs up current WReg data to Waveform Memory, commonly used for storing complex pulse sequences.

*   **Header**: `[Op=101, AI, SO=1]`
*   **Unconditional**: Note that `wmem_wr` does **not** evaluate `COND`.
*   **Payload**: `[rsA0/IMM_ADDR, rsA1, RD=WReg]`

#### 5.2.4 Time Control (`time`)
Part of Internal Peripheral Control (`int_ctrl`), used to maintain the processor's scheduling clock.

*   **Header**: `[Op=010, AI, COND, SO=TO=UF=0(Header[6:4] = 0x0), Sub_Op(Header[3:0])]`

    | Bit (Header[x]) | Mnemonic       | Description                                                                                                                                                                             |
    | :-------------: | :------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
    |      **3**      | `time_step`    | **Increment timeline**: Adds operand to the current $T_{ref}$.                                                                                                                          |
    |      **2**      | `time_ref_set` | **Set $T_{ref}$**: Sets the reference time. Often called `time_init` (if set to 0) or `time_updt` (if set from register).  <font color = "green">Depending on `AI` and `Payload`</font> |
    |      **1**      | -              | Reserved / Other time control.                                                                                                                                                          |
    |      **0**      | -              | Reserved / Other time control.                                                                                                                                                          |


### 5.3 Control Flow (branch)
These instructions modify the Program Counter (PC) to change the execution sequence.

*   **OpCode**: `001`
*   **Conditionality**: Like all instructions, branching can be conditional (using the `COND` field).

#### 5.3.1 jump
Unconditional or conditional jump to a specific address.

*   **Header**: `[Op=001, AI, COND, SO=0]`
*   **Condition Selection (`COND`)**: Header[9:7] determines if the jump executes.
    > [!IMPORTANT]
    > To perform an **Unconditional Jump**, set `COND = 000` (ALWAYS).

| COND (Header[9:7]) | Mnemonic   | Description           | Logic Condition |
| :----------------: | :--------- | :-------------------- | :-------------- |
|      **000**       | `always`   | **Unconditional**     | Always executes |
|      **001**       | `eq` / `z` | **Equal / Zero**      | `ALU_Z == 1`    |
|      **010**       | `s`        | **Sign / Negative**   | `ALU_S == 1`    |
|      **011**       | `nz`       | **Not Zero**          | `ALU_Z == 0`    |
|      **100**       | `ns`       | **Not Negative**      | `ALU_S == 0`    |
|      **101**       | `f`        | **External Flag**     | `flag_i == 1`   |
|      **110**       | `nf`       | **Not External Flag** | `flag_i == 0`   |
|      **111**       | -          | Reserved              | Never executes  |

*   **Payload**: `[rsA0/IMM_ADDR, rsA1]`
*   **Target PC**: `PC_nxt = (AI ? IMM_ADDR : rsA0) + rsA1`

#### 5.3.2 call
Branch to a subroutine and save the return address.

*   **Header**: `[Op=001, AI, COND, SO=1, TO=0]`
*   **Conditionality**: Uses the same **`COND`** table as `jump`. It only executes if the condition is met.
*   **Payload**: Same as `jump`.
*   **Effect**:
    1.  Push `PC + 1` onto the internal hardware LIFO stack.
    2.  Jump to `Target Address`.

#### 5.3.3 ret
Return from a subroutine.

*   **Header**: `[Op=001, SO=1, TO=1]`
*   **Unconditional**: `ret` **always** executes regardless of the `COND` field in the Header.
*   **Effect**: Pops the top value from the LIFO stack into the `PC`.

> [!NOTE]
> **Hardware Stack Depth**: The internal LIFO stack has a depth of **8**, meaning subroutines can be nested up to 8 levels deep.

### 5.4 Peripheral Data I/O (dport)
This category facilitates high-speed data transfer between the processor and external peripheral modules (e.g., AXI streamers, custom logic).

#### 5.4.1 dport_wr
Write 32-bit data to a specific peripheral port.
*   **Header**: `[Op=110, AI, DF, COND=001, SO=0, TO=0]`
*   **Unconditional**: Note that `dport_wr` does **not** evaluate `COND`.
*   **Payload**: `[rsA1=Port, rsD0]`
*   **Description**: Sends the value of `rsD0` to the peripheral port mapped to the address in `rsA1`.

#### 5.4.2 dport_rd
Read 32-bit data from a specific peripheral port into a register.
*   **Header**: `[Op=110, AI, DF, COND=000, SO=0, TO=0]`
*   **Unconditional**: Note that `dport_rd` does **not** evaluate `COND`.
*   **Payload**: `[rsA1=Port, RD]`
*   **Description**: Captures data from the peripheral port at `rsA1` and stores it into destination register `RD`.  
   
---
## 6. Recommended Learning Path (RTL Files)

If you want to master the structure, read these RTL files in order:

1. **[_qproc_defines.svh](../qick_processor/src/_qproc_defines.svh)**: The "Dictionary". Understand the structs and OpCode naming.
2. **[qcore_cpu.sv](../qick_processor/src/qcore_cpu.sv)**: The "Brain". Focus on the `DECODER` logic (approx. Line 190) and the `PIPELINE` stages.
3. **[qcore_reg_bank.sv](../qick_processor/src/qcore_reg_bank.sv)**: The "Memory". See how registers are muxed and how SFRs are mapped.
4. **[_qproc_ips.sv](../qick_processor/src/_qproc_ips.sv)**: The "Tools". Deep dive into the `AB_alu` logic to see supported math ops.
5. **[tprocv2_assembler.py](../../../qick_lib/qick/tprocv2_assembler.py)**: The "Translator". See how high-level ASM maps to the 72-bit bitstream.
