# QICK tProc v2: Hazard Detection & Resolution Logic (English Version)

This document details the "when, where, and why" of the QICK processor's hazard management.

## 1. Data Forwarding (Bypassing)
**Forwarding** allows an instruction to get its data from a previous instruction that hasn't finished its write-back yet.

### Forwarding Destinations
While the forwarding logic detects and intercepts data in the **RD stage**, the final data is injected into the **X1 Stage inputs**.
*   **ALU Inputs** (`x1_alu_in_A`, `x1_alu_in_B`): Used for back-to-back arithmetic.
*   **Memory Address Calc** (`x1_mem_addr`): Used when a calculation result is the address for a load/store.
*   **Memory Write Data** (`x1_mem_w_dt`): Used when a result is being stored to memory.
*   **External/User Outputs** (`usr_dt_a_o`, etc.): Real-time data sent out of the core.

### Sources and Timing
| Source Stage | Provided Data (SV Signal)                              | Hardware Role                      |
| :----------- | :----------------------------------------------------- | :--------------------------------- |
| **X1**       | `x1_alu_dt_i` (ALU Result) / `x1_imm_dt_i` (Immediate) | Resolves ALU -> ALU dependencies.  |
| **X2**       | `x2_alu_dt_i` / `x2_dmem_dt_i` (Memory Read Data)      | Resolves Load -> ALU dependencies. |

---

## 2. Stalling (Bubbles)
A **Stall** freezes a specific pipeline stage. The **"Current Instruction"** refers to the instruction being frozen in that stage.

### 2.1 ID Stage Stalls (`bubble_id_o`)
**Current Instruction = ID Stage**. It cannot proceed until the hazard is cleared.

| Cause | SV Signal | Triggering Instr. Stage | Penalty | Reason |
| :--- | :--- | :--- | :--- | :--- |
| **Jump** | `stall_id_j` | **RD** Stage writing `s_addr` | **3 Cycles** | Needs 3 cycles to reach WR and update `s15`. |
| | | **X1** Stage writing `s_addr` | **2 Cycles** | Needs 2 cycles to reach WR. |
| | | **X2** Stage writing `s_addr` | **1 Cycle** | Needs 1 cycle to reach WR. |
| **Flag** | `stall_id_f` | **RD** Stage updating Flags | **2 Cycles** | Flags need to reach X2 to be latched. |
| | | **X1** Stage updating Flags | **1 Cycle** | Flags need 1 cycle to reach X2. |
| **Wave** | `stall_id_w` | **RD** Stage writing `WREG` | **3 Cycles** | WREG has no forwarding; must wait for WR. |
| | | **X1** Stage writing `WREG` | **2 Cycles** | |
| | | **X2** Stage writing `WREG` | **1 Cycle** | |
| **Port** | `stall_id_wp` | **RD** Stage Port Write | **2 Cycles** | Synchronizing port access timing. |
| | | **X1** Stage Port Write | **1 Cycle** | |

### 2.2 RD Stage Stalls (`bubble_rd_o`)
**Current Instruction = RD Stage**. Frozen during register read and cannot move to X1.

| Cause | SV Signal | Triggering Instr. Stage | Penalty | Reason |
| :--- | :--- | :--- | :--- | :--- |
| **Load-Use**| `d_stall_D_rd`| **X1** Stage is `DMEM` load | **1 Cycle** | Mem data only ready at the end of X2. |
| **Wave Read**| `w_stall_D_rd`| **X1** Stage writing to `WREG` | **2 Cycles** | Must wait for WREG write commitment. |
| | | **X2** Stage writing to `WREG` | **1 Cycle** | |

---

## 3. Pipeline Flush
**Flush** discards instructions fetched from the wrong program path.

*   **Decision Basis**: **ID Stage**. The Branch/Jump condition is evaluated here.
*   **Target**: **IF Stage**. The instruction currently being fetched is discarded.
*   **Penalty**: **1 cycle**.
*   **Logic**: Even though flag generation ends at X1, the CPU checks the **latest latched flags** in the ID stage to decide on branches immediately.

---

## 4. Understanding the "Flag Distance"
If Instruction 1 updates flags and Instruction 4 uses them in an `-if()`:
1.  **Instr 1**: X1 (Flag Calculated) -> X2 (Flag Latched in `alu_fZ_r`).
2.  **Instr 4**: ID (Checks `alu_fZ_r`).
3.  **Distance**: Between X2 and ID there are **two stages** (RD and X1).
4.  **Result**: If Instr 4 is in ID while Instr 1 is in X2 or further, **ZERO penalty**.
5.  **Hazard**: If Instr 1 is in RD or X1, Instr 4 will **Stall** until Instr 1 reaches X2.
