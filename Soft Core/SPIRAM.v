// ============================================================================
//  aps6404l.v -- Behavioral bus-functional model of the AP Memory
//                APS6404L-3SQR 64Mbit (8MB) SPI / QPI PSRAM.
//
//  This is a *slave* model: it sits on the QSPI bus and responds to real
//  traffic, so you can hang your QSPI engine / PSRAM controller off it and
//  drive it exactly the way you would drive silicon.
//
//  Supported commands
//  ------------------
//    03h  Read              1-1-1, 24b addr, 0 dummy   (SPI only, <=33MHz)
//    0Bh  Fast Read         1-1-1, 24b addr, 8 dummy   (SPI only)
//    EBh  Fast Read Quad    1-4-4 (SPI) or 4-4-4 (QPI), 6 dummy
//    02h  Write             1-1-1, 24b addr, 0 dummy   (SPI only)
//    38h  Quad Write        1-4-4 (SPI) or 4-4-4 (QPI), 0 dummy
//    9Fh  Read ID           24b addr then 8 ID bytes
//    35h  Enter Quad Mode (QPI)
//    F5h  Exit Quad Mode
//    66h  Reset Enable / 99h Reset  (must be issued back to back)
//    C0h  Set Burst Length -- toggles wrap boundary 1024 <-> 32 bytes
//
//  Protocol conventions (SPI mode 0 / mode 3)
//  ------------------------------------------
//    * The model SAMPLES sio[] on the rising edge of sclk.
//    * The model DRIVES  sio[] on the falling edge of sclk, +T_CO.
//    * Your controller should therefore launch data on the falling edge and
//      capture read data on the rising edge.
//
//  Bursts wrap inside the current wrap boundary (1024B by default), exactly
//  like the real part -- they do NOT run linearly across the boundary. Set
//  WARN_ON_WRAP=1 to get a message when it happens; this catches a very
//  common controller bug.
// ============================================================================

`timescale 1ns/1ps

module aps6404l #(
    // Modelled memory size. The real device is 23 bits (8MB); a smaller value
    // keeps simulation fast and simply aliases the upper address bits.
    parameter integer MEM_ADDR_BITS = 16,

    // 0 = power up as X (catches reads of never-written data)
    // 1 = power up as 8'h00
    // 2 = power up random
    parameter integer INIT_MODE     = 0,
    parameter integer INIT_SEED     = 32'hDEADBEEF,

    parameter real    T_CO          = 2.0,   // ns, sclk fall -> sio valid
    parameter real    T_DIS         = 2.0,   // ns, cs_n rise -> sio Hi-Z

    parameter integer DEBUG         = 1,     // 1 = log every transaction
    parameter integer WARN_ON_WRAP  = 1,     // 1 = log burst wrap events
    parameter integer ALLOW_144     = 0,     // allow EBh/38h in SPI mode
    parameter integer CHECK_TIMING  = 1,

    parameter real    T_CEM_MAX     = 8000.0,// ns, max cs_n low  (refresh)
    parameter real    T_CPH_MIN     = 18.0,  // ns, min cs_n high between xacts
    parameter real    T_CK_MIN      = 7.5,   // ns, 133 MHz
    parameter real    T_CK_MIN_SLOW = 30.3,  // ns, 33 MHz limit for 03h

    parameter integer WRAP_LONG     = 1024,
    parameter integer WRAP_SHORT    = 32
)(
    input  wire       sclk,
    input  wire       cs_n,
    inout  wire [3:0] sio     // sio0=SI, sio1=SO, sio2=/WP, sio3=/HOLD in SPI
);

    // ------------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------------
    localparam integer MEM_SIZE = (1 << MEM_ADDR_BITS);
    reg [7:0] mem [0:MEM_SIZE-1];

    // Device ID returned by 9Fh: MFID=0Dh (AP Memory), KGD=5Dh, then EID.
    reg [7:0] id_rom [0:7];

    integer i;
    integer seed;
    initial begin
        seed = INIT_SEED;
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            case (INIT_MODE)
                1:       mem[i] = 8'h00;
                2:       mem[i] = $random(seed);
                default: mem[i] = 8'hxx;
            endcase
        end
        id_rom[0] = 8'h0D;  // manufacturer ID
        id_rom[1] = 8'h5D;  // known good die
        id_rom[2] = 8'h52;  // EID[47:40] (arbitrary)
        id_rom[3] = 8'h9A;
        id_rom[4] = 8'h12;
        id_rom[5] = 8'h34;
        id_rom[6] = 8'h56;
        id_rom[7] = 8'h78;
    end

    // ------------------------------------------------------------------
    // Commands
    // ------------------------------------------------------------------
    localparam [7:0] CMD_READ       = 8'h03,
                     CMD_FAST_READ  = 8'h0B,
                     CMD_READ_QUAD  = 8'hEB,
                     CMD_WRITE      = 8'h02,
                     CMD_WRITE_QUAD = 8'h38,
                     CMD_ENTER_QPI  = 8'h35,
                     CMD_EXIT_QPI   = 8'hF5,
                     CMD_RST_EN     = 8'h66,
                     CMD_RESET      = 8'h99,
                     CMD_BURST_LEN  = 8'hC0,
                     CMD_READ_ID    = 8'h9F;

    localparam [2:0] S_IDLE  = 3'd0,
                     S_CMD   = 3'd1,
                     S_ADDR  = 3'd2,
                     S_DUMMY = 3'd3,
                     S_WRITE = 3'd4,
                     S_READ  = 3'd5,
                     S_DONE  = 3'd6;

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------
    reg  [2:0]  state;
    reg  [7:0]  cmd;
    reg  [31:0] shift;
    reg  [7:0]  clk_cnt;
    reg  [23:0] addr;
    reg  [23:0] start_addr;

    reg         qpi;            // 1 = QPI (4-4-4) mode
    reg         addr_quad;
    reg         data_quad;
    reg  [7:0]  dummy_clks;
    reg         is_read, is_write, is_id;
    reg         rst_en;
    reg  [11:0] wrap_len;

    reg  [7:0]  in_byte;
    reg  [3:0]  in_pos;
    reg  [7:0]  out_byte;
    reg  [3:0]  out_pos;
    reg  [2:0]  id_idx;
    reg  [3:0]  nib;
    reg  [31:0] nbytes;

    reg         dout_oe, dout_quad;
    reg  [3:0]  dout_nib;

    reg [8*16:1] cname;
    reg          warned_clk;   // throttle: one clock-rate warning per transaction

    real t_cs_fall, t_cs_rise, t_clk_prev;

    // ------------------------------------------------------------------
    // Bus drive
    // ------------------------------------------------------------------
    assign sio = dout_oe ? (dout_quad ? dout_nib
                                      : {2'bzz, dout_nib[1], 1'bz})
                         : 4'bzzzz;

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    function [7:0] mem_get(input [23:0] a);
        mem_get = mem[a[MEM_ADDR_BITS-1:0]];
    endfunction

    task mem_put(input [23:0] a, input [7:0] d);
        mem[a[MEM_ADDR_BITS-1:0]] = d;
    endtask

    function [23:0] next_addr(input [23:0] a);
        reg [23:0] mask;
        begin
            mask      = wrap_len - 1;
            next_addr = (a & ~mask) | ((a + 24'd1) & mask);
            if (WARN_ON_WRAP && (((a + 24'd1) & mask) == 24'd0))
                $display("[%0.1f ns] %m: NOTE burst wrapped at %0d-byte boundary (addr %06h -> %06h)",
                         $realtime, wrap_len, a, (a & ~mask));
        end
    endfunction

    // ------------------------------------------------------------------
    // Power-up / reset defaults
    // ------------------------------------------------------------------
    initial begin
        state      = S_IDLE;
        qpi        = 1'b0;
        rst_en     = 1'b0;
        wrap_len   = WRAP_LONG[11:0];
        dout_oe    = 1'b0;
        dout_quad  = 1'b0;
        dout_nib   = 4'h0;
        {is_read,is_write,is_id} = 3'b000;
        t_cs_fall  = 0.0;
        t_cs_rise  = -1.0e9;
        t_clk_prev = -1.0e9;
        warned_clk = 1'b0;
        nbytes     = 0;
    end

    // ------------------------------------------------------------------
    // Chip select
    // ------------------------------------------------------------------
    always @(negedge cs_n) begin
        if (CHECK_TIMING && (($realtime - t_cs_rise) < T_CPH_MIN))
            $display("[%0.1f ns] %m: WARNING tCPH violation, cs_n high only %0.2f ns (min %0.2f)",
                     $realtime, $realtime - t_cs_rise, T_CPH_MIN);
        t_cs_fall = $realtime;
        state     = S_CMD;
        clk_cnt   = 0;
        shift     = 0;
        nbytes    = 0;
        warned_clk = 1'b0;
        is_read   = 1'b0;
        is_write  = 1'b0;
        is_id     = 1'b0;
    end

    always @(posedge cs_n) begin
        if (CHECK_TIMING && (($realtime - t_cs_fall) > T_CEM_MAX))
            $display("[%0.1f ns] %m: WARNING tCEM violation, cs_n low for %0.2f ns (max %0.2f) - real device would lose refresh",
                     $realtime, $realtime - t_cs_fall, T_CEM_MAX);
        if (DEBUG && (state != S_IDLE) && (state != S_CMD))
            $display("[%0.1f ns] %m: end   %0s bytes=%0d final_addr=%06h",
                     $realtime, cname, nbytes, addr);
        t_cs_rise = $realtime;
        state     = S_IDLE;
        dout_oe  <= #(T_DIS) 1'b0;
    end

    // ------------------------------------------------------------------
    // Sample on rising edge
    // ------------------------------------------------------------------
    always @(posedge sclk) if (!cs_n) begin
        if (CHECK_TIMING && !warned_clk) begin
            if (($realtime - t_clk_prev) < T_CK_MIN) begin
                $display("[%0.1f ns] %m: WARNING sclk period %0.2f ns is faster than %0.2f ns (133 MHz)",
                         $realtime, $realtime - t_clk_prev, T_CK_MIN);
                warned_clk = 1'b1;
            end else if ((state != S_CMD) && (cmd == CMD_READ) &&
                         (($realtime - t_clk_prev) < T_CK_MIN_SLOW)) begin
                $display("[%0.1f ns] %m: WARNING 03h Read is limited to 33 MHz, period is %0.2f ns",
                         $realtime, $realtime - t_clk_prev);
                warned_clk = 1'b1;
            end
        end
        if (CHECK_TIMING) t_clk_prev = $realtime;

        case (state)
        // ---------------- command ----------------
        S_CMD: begin
            if (qpi) shift = {shift[27:0], sio};
            else     shift = {shift[30:0], sio[0]};
            clk_cnt = clk_cnt + 1;
            if (clk_cnt == (qpi ? 8'd2 : 8'd8)) begin
                cmd     = shift[7:0];
                clk_cnt = 0;
                decode;
            end
        end

        // ---------------- address ----------------
        S_ADDR: begin
            if (addr_quad) shift = {shift[27:0], sio};
            else           shift = {shift[30:0], sio[0]};
            clk_cnt = clk_cnt + 1;
            if (clk_cnt == (addr_quad ? 8'd6 : 8'd24)) begin
                addr       = shift[23:0];
                start_addr = shift[23:0];
                clk_cnt    = 0;
                if (DEBUG)
                    $display("[%0.1f ns] %m: start %0s addr=%06h", $realtime, cname, addr);
                if (is_write) begin
                    state  = S_WRITE;
                    in_pos = 0;
                end else if (dummy_clks != 0) begin
                    state = S_DUMMY;
                end else begin
                    state   = S_READ;
                    out_pos = 0;
                    id_idx  = 0;
                end
            end
        end

        // ---------------- dummy ----------------
        S_DUMMY: begin
            clk_cnt = clk_cnt + 1;
            if (clk_cnt == dummy_clks) begin
                state   = S_READ;
                out_pos = 0;
                id_idx  = 0;
            end
        end

        // ---------------- write data ----------------
        S_WRITE: begin
            if (data_quad) begin
                in_byte = {in_byte[3:0], sio};
                in_pos  = in_pos + 4;
            end else begin
                in_byte = {in_byte[6:0], sio[0]};
                in_pos  = in_pos + 1;
            end
            if (in_pos == 8) begin
                in_pos = 0;
                mem_put(addr, in_byte);
                if (DEBUG > 1)
                    $display("[%0.1f ns] %m:   wr %06h <= %02h", $realtime, addr, in_byte);
                addr   = next_addr(addr);
                nbytes = nbytes + 1;
            end
        end

        default: ; // S_READ / S_DONE / S_IDLE: nothing to sample
        endcase
    end

    // ------------------------------------------------------------------
    // Drive on falling edge
    // ------------------------------------------------------------------
    always @(negedge sclk) if (!cs_n && (state == S_READ)) begin
        if (out_pos == 0)
            out_byte = is_id ? id_rom[id_idx] : mem_get(addr);

        if (data_quad) begin
            nib     = (out_pos == 0) ? out_byte[7:4] : out_byte[3:0];
            out_pos = out_pos + 4;
        end else begin
            nib     = {2'b00, out_byte[7 - out_pos[2:0]], 1'b0};
            out_pos = out_pos + 1;
        end

        if (out_pos == 8) begin
            out_pos = 0;
            nbytes  = nbytes + 1;
            if (DEBUG > 1)
                $display("[%0.1f ns] %m:   rd %06h => %02h", $realtime, addr, out_byte);
            if (is_id) id_idx = id_idx + 1;
            else       addr   = next_addr(addr);
        end

        dout_nib  <= #(T_CO) nib;
        dout_quad <= #(T_CO) data_quad;
        dout_oe   <= #(T_CO) 1'b1;
    end

    // ------------------------------------------------------------------
    // Command decode
    // ------------------------------------------------------------------
    task decode;
        begin
            addr_quad  = 1'b0;
            data_quad  = 1'b0;
            dummy_clks = 8'd0;
            is_read    = 1'b0;
            is_write   = 1'b0;
            is_id      = 1'b0;
            cname      = "?";

            case (cmd)
            CMD_READ: begin
                cname = "READ(03h)";
                if (qpi) bad_cmd;
                else begin is_read = 1'b1; state = S_ADDR; end
            end
            CMD_FAST_READ: begin
                cname = "FASTREAD(0Bh)";
                if (qpi) bad_cmd;
                else begin is_read = 1'b1; dummy_clks = 8'd8; state = S_ADDR; end
            end
            CMD_READ_QUAD: begin
                cname = "READQUAD(EBh)";
                if (!qpi && !ALLOW_144) bad_cmd;
                else begin
                    is_read    = 1'b1;
                    addr_quad  = 1'b1;
                    data_quad  = 1'b1;
                    dummy_clks = 8'd6;
                    state      = S_ADDR;
                end
            end
            CMD_WRITE: begin
                cname = "WRITE(02h)";
                if (qpi) bad_cmd;
                else begin is_write = 1'b1; state = S_ADDR; end
            end
            CMD_WRITE_QUAD: begin
                cname = "WRITEQUAD(38h)";
                if (!qpi && !ALLOW_144) bad_cmd;
                else begin
                    is_write  = 1'b1;
                    addr_quad = 1'b1;
                    data_quad = 1'b1;
                    state     = S_ADDR;
                end
            end
            CMD_READ_ID: begin
                cname     = "READID(9Fh)";
                is_read   = 1'b1;
                is_id     = 1'b1;
                addr_quad = qpi;
                data_quad = qpi;
                state     = S_ADDR;
            end
            CMD_ENTER_QPI: begin
                cname = "ENTER_QPI(35h)";
                qpi   = 1'b1;
                state = S_DONE;
                if (DEBUG) $display("[%0.1f ns] %m: entered QPI mode", $realtime);
            end
            CMD_EXIT_QPI: begin
                cname = "EXIT_QPI(F5h)";
                qpi   = 1'b0;
                state = S_DONE;
                if (DEBUG) $display("[%0.1f ns] %m: exited QPI mode", $realtime);
            end
            CMD_RST_EN: begin
                cname  = "RST_EN(66h)";
                rst_en = 1'b1;
                state  = S_DONE;
            end
            CMD_RESET: begin
                cname = "RESET(99h)";
                state = S_DONE;
                if (rst_en) begin
                    qpi      = 1'b0;
                    wrap_len = WRAP_LONG[11:0];
                    if (DEBUG) $display("[%0.1f ns] %m: reset -> SPI mode, wrap %0d",
                                        $realtime, wrap_len);
                end else
                    $display("[%0.1f ns] %m: WARNING 99h Reset ignored, not preceded by 66h",
                             $realtime);
                rst_en = 1'b0;
            end
            CMD_BURST_LEN: begin
                cname    = "BURSTLEN(C0h)";
                wrap_len = (wrap_len == WRAP_LONG[11:0]) ? WRAP_SHORT[11:0]
                                                         : WRAP_LONG[11:0];
                state    = S_DONE;
                if (DEBUG) $display("[%0.1f ns] %m: wrap boundary now %0d bytes",
                                    $realtime, wrap_len);
            end
            default: begin
                $display("[%0.1f ns] %m: WARNING unsupported command %02h in %0s mode",
                         $realtime, cmd, qpi ? "QPI" : "SPI");
                state = S_DONE;
            end
            endcase

            if (cmd != CMD_RST_EN) rst_en = 1'b0;
        end
    endtask

    task bad_cmd;
        begin
            $display("[%0.1f ns] %m: WARNING command %02h is not valid in %0s mode",
                     $realtime, cmd, qpi ? "QPI" : "SPI");
            state = S_DONE;
        end
    endtask

    // ------------------------------------------------------------------
    // Backdoor access for your testbench
    // ------------------------------------------------------------------
    task poke(input [23:0] a, input [7:0] d);
        mem[a[MEM_ADDR_BITS-1:0]] = d;
    endtask

    function [7:0] peek(input [23:0] a);
        peek = mem[a[MEM_ADDR_BITS-1:0]];
    endfunction

    task fill_incrementing;
        integer k;
        for (k = 0; k < MEM_SIZE; k = k + 1) mem[k] = k[7:0];
    endtask

    // Current mode, handy for assertions in your TB
    // function in_qpi_mode; in_qpi_mode = qpi; endfunction

endmodule
