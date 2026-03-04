# Receiver 设计指南：端口、数据流与 AXI 架构

这篇指南回答了关于 Receiver 模块设计、256-bit 数据处理以及 PS 端控制的常见问题。

## 1. 256-bit AXIS 信号合理吗？
**非常合理。** 
在 QICK 项目（尤其是基于 RFSoC 的 `qick_tprocv2_4x2_standard`）中，FPGA 内部的数据处理通常是并行的：
- **采样频率高**：ADC 采样率通常为几个 Gsps。
- **并行处理**：为了降低时钟频率（降低到 ~400MHz 左右），数据会被并行化。256-bits 通常代表 **8 个并行样本 (8 samples x 32 bits)**。
- **协议一致性**：QICK 的 `axis_signal_gen` 等模块输出的正是 256-bit 的 AXI-Stream。

## 2. 接收数据：直接给 PS 还是通过 DMA？
**必须通过 DMA。**
- **速度差异**：PS 端（ARM CPU）通过 AXI-Lite 寄存器读取数据的速度极慢（读取一个 32-bit 寄存器需要几十个时钟周期）。
- **位宽限制**：AXI-Lite 通常只有 32 位。你要读完一个 256 位的包需要读取 8 次寄存器，这会丢失大量高速到来的数据。
- **DMA 的作用**：DMA 就像一个“搬运工”，它直接把 PL 端的高速 256-bit 直流数据流搬运到 DDR 内存中。等搬运完成了，PS 端只需要去内存里读取即可。

## 3. PS 端如何表示“要收数据”？
在 DMA 架构中，控制不是通过简单的“握手信号”实现的，而是通过**状态机和寄存器配置**：
1. **配置阶段**：PS 通过 AXI-Lite 告诉 DMA：“我要收 1024 个数据包，请存到内存地址 `0x10000000`。”
2. **准备阶段**：DMA 在 `S_AXIS` 接口上拉高 `TREADY`，表示它准备好收数了。
3. **传输阶段**：你的 Receiver 模块拉高 `TVALID` 并开始发送数据。
4. **结束阶段**：当 DMA 收够了 1024 个包，它会向 PS 发送一个**中断 (Interrupt)**，或者 PS 通过读取 DMA 的状态寄存器知道传输已完成。

## 4. Receiver 模块的端口定义建议
即便不考虑 AXI，你的核心逻辑模块（Core Logic）应该具备以下基本端口：

| 端口名 | 方向 | 宽度 | 描述 |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | 处理时钟（通常与信号源一致） |
| `resetn` | Input | 1 | 低电平有效复位 |
| `din` | Input | 256 | 来自 Hashing Engine 的数据 |
| `din_valid` | Input | 1 | 表示输入数据有效 |
| `dout` | Output | 32-256 | 处理后的数据（送往 DMA） |
| `dout_valid` | Output | 1 | 表示输出数据有效 |
| `cfg_threshold` | Input | 32 | 配置参数（来自 AXI-Lite 寄存器） |

## 5. AXI Wrapper 有现成的 IP 吗？
没有一个可以直接例化的“万能包装 IP”，但有以下三种常用方法：
1. **Vivado 向导生成的代码（推荐）**：
   - Tools -> Create and Package New IP -> Create a new AXI4 Peripheral。
   - 它会生成一个 `.v` 文件，里面已经帮你写好了 AXI-Lite 的读写时序。你只需要把你的 `cfg_threshold` 连到它里面的 `slv_reg0` 即可。
2. **手写简易 AXI-Lite**：针对简单的配置，可以自己写一个小的 FSM 来解码 `AWADDR` 和 `WDATA`。
3. **AXI-Stream 包装**：只要你的输出满足 `dout`, `dout_valid`, `dout_ready` 的握手逻辑，它天然就是 AXI-Stream，直接起名叫 `m_axis_tdata` 等即可。

## 6. PS 如何知道收到了多少个 Packet？

这是一个关键的同步问题，通常有三种解决方案：

### A. 使用 `TLAST` 信号（数据流控制）
AXI-Stream 协议中有一个特别的信号叫 **`TLAST`**。
- **机制**：当你的 Receiver 发送完一组数据（比如 1024 个采样）时，在发送最后一个 `dout` 的同时，将 `TLAST` 拉高一个时钟周期。
- **PS 端感知**：DMA 看到 `TLAST` 后，会立刻结束当前的搬运任务，并给 PS 发送一个“传输完成”的中断。
- **优点**：由硬件决定包的边界，非常精准。

### B. PS 指定长度（预设模式）
- **机制**：PS 在启动 DMA 之前，通过软件告诉 DMA：“请接收 4096 字节的数据”。
- **PS 端感知**：DMA 内部有个计数器，当它从你的 Receiver 那里收够了 4096 字节，它就会停止收数并通知 PS。
- **优点**：软件控制简单，适合固定长度的实验。

### C. 硬件计数器 (Status Register)
- **机制**：在你的 Receiver 模块内部写一个简单的计数器逻辑：每成功发送一个包（`valid && ready`），计数器加 1。
- **PS 端感知**：将这个计数器的值连到 AXI-Lite 的一个只读寄存器（比如 `slv_reg1`）。PS 随时可以读取这个寄存器，看看“一共发了多少个包”。
- **优点**：方便调试，PS 可以实时监控 PL 的运行状态。

## 7. 连续运行状态下，如何判断电路发送完毕？

你注意到了“Controller 似乎一直在跑”，这在 FPGA 设计中很常见（时钟和总线确实一直在跳动）。但在 QICK 的架构中，数据的“开始”和“结束”是通过**触发脉冲 (Trigger)** 和 **计数器 (Counter)** 来精确控制的。

### 核心机制：触发式采样 (Trigger-Gated Logic)

1.  **触发信号 (`trigger`)**：
    你的模块会有一个输入端口叫 `trigger`。这个信号通常由 **tProcessor (中央控制器)** 在特定的实验时刻拉高。
    
2.  **计数器启动**：
    当你的模块检测到 `trigger` 的上升沿时，内部的状态机从 `IDLE` 转为 `BUSY`，并开始清零一个内部计数器。

3.  **有效数据抓取 (`TVALID`)**：
    -   即使 Hashing Engine 一直在送数据，你的模块也只在 `BUSY` 状态下才处理这些数据。
    -   你会根据 PS 设置的 **`NSAMP` (采样长度)** 寄存器来判断：
        -   如果 `count < NSAMP`：逻辑继续运行，向 DMA 发送 `m_axis_tvalid = 1`。
        -   如果 `count == NSAMP`：逻辑认为本轮发送完毕，将 `m_axis_tlast = 1` 维持一个周期，然后将 `m_axis_tvalid` 拉低。

4.  **回到等待状态**：
    发送完 `TLAST` 后，模块回到 `IDLE` 状态，停止一切输出，直到下一个 `trigger`信号到来。

### 总结
这就是为什么 PS 能够判断“发送完毕”：
-   虽然 Controller 总线在跑，但你的模块输出的 **`TVALID`** 信号只在触发后的 `NSAMP` 周期内才为高。
-   对于 DMA 来说，没看到 `TVALID` 就代表没数据；看到了 `TLAST` 就代表这一批次任务结束。

**这就像是**：自来水管（Hashing Engine）虽然一直在出水，但你手里有一个带倒计时的水桶（Receiver）。你只有在按下“开始”键（Trigger）时才打开盖子接水，接够了 10 升（NSAMP）就关上盖子（TVALID=0），并打个信号提示（TLAST）。
