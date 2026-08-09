module top(clk, rst_n);

aps6404l ram1(sclk, cs, qspi_dq);

QSPI_CONTROLLER QCONT1( clk, rst_n, start_fsm, command, address, cache_word_length, in_byte, byte_received, out_byte, out_byte_ready, busy, CONT_ENG, ENG_CONT, start,done,op_en, sq_mode, cs_en, clk_en);

QSPI_ENGINE QSPI1(clk, rst_n, sclk, cs, dq_in, dq_out, ENG_CONT, CONT_ENG, start, done, sq_mode, op_en, cs_en, clk_en);

input clk, rst_n;
wire start_fsm, bytereceived, out_byte_ready, busy, start, done, op_en, sq_mode, cs_en, clk_en, sclk, cs;
wire[3:0] qspi_dq, dq_in, dq_out; 
wire[5:0] cache_word_length;
wire[7:0] command, CONT_ENG, ENG_CONT, in_byte, out_byte;
wire[23:0] address;


assign qspi_dq[0] = op_en ? dq_out[0] : 1'bz;
assign qspi_dq[1] = op_en ? dq_out[1] : 1'bz;
assign qspi_dq[2] = op_en ? dq_out[2] : 1'bz;
assign qspi_dq[3] = op_en ? dq_out[3] : 1'bz;

assign dq_in = qspi_dq;

endmodule


module QSPI_CONTROLLER (
    input             clk,
    input             rst_n,

    // ---- cache / CPU side ----
    input             start_fsm,          // 1-cycle pulse
    input      [7:0]  command,            // 8'hEB or 8'h38
    input      [23:0] address,
    input      [5:0]  cache_word_length,  // bytes in the burst
    input      [7:0]  in_byte,            // write data
    output reg        byte_received,      // strobe: advance in_byte
    output reg [7:0]  out_byte,           // read data
    output reg        out_byte_ready,     // strobe
    output reg        busy,

    // ---- engine side ----
    output reg [7:0]  CONT_ENG,           // byte to shift out
    input      [7:0]  ENG_CONT,           // byte shifted in
    output reg        start,
    input             done,
    output reg        op_en,              // 1 = drive, 0 = receive
    output reg        sq_mode,            // 0 = S (serial), 1 = Q (quad)
    output reg        cs_en,              // 1 = CS# HIGH (deselected)
    output reg        clk_en
);

    // ------------------------------------------------------------------
    localparam [3:0]
        STARTUP     = 4'd0,
        IDLE        = 4'd1,
        ASSERT_CS   = 4'd2,
        SEND_COMMAND= 4'd3,
        SEND_ADDRESS= 4'd4,
        DUMMY_CYCLES= 4'd5,
        WRITE_DATA  = 4'd6,
        READ_DATA   = 4'd7,
        DEASSERT_CS = 4'd8;

    localparam S = 1'b0, Q = 1'b1;

    // 150 us at 80 MHz = 12000 cycles; 13000 gives margin
    localparam [13:0] PWRUP_CYCLES = 14'd13000;

    localparam [2:0] ADDR_BYTES  = 3'd3;   // 24-bit address
    localparam [2:0] DUMMY_BYTES = 3'd3;   // 6 dummy SCLK / 2 per byte
    localparam [3:0] CS_GAP      = 4'd7;   // tCPH: 8 clk @80MHz = 100ns

    // ------------------------------------------------------------------
    reg [3:0]  state;
    reg [3:0]  intra_state;
    reg [13:0] cnt;          // power-up delay
    reg [3:0]  wait_cnt;     // CS# high gap
    reg [5:0]  byte_cnt;     // bytes remaining in current phase
    reg [23:0] sh;           // outgoing address shifter
    reg [1:0]  init_idx;

    wire [7:0] init_cmd = (init_idx == 2'd0) ? 8'h66 :
                          (init_idx == 2'd1) ? 8'h99 : 8'h35;

    // Latched request, so the caller may change command/address after the pulse
    reg [7:0]  cmd_reg;
    reg [23:0] addr_reg;
    reg [5:0]  len_reg;

    wire is_read  = (cmd_reg == 8'hEB);
    wire is_write = (cmd_reg == 8'h38);

    // ==================================================================
    always @(posedge clk) begin
    if (!rst_n) begin
        state          <= STARTUP;
        intra_state    <= 4'd0;
        cnt            <= 14'd0;
        wait_cnt       <= 4'd0;
        byte_cnt       <= 6'd0;
        init_idx       <= 2'd0;
        start          <= 1'b0;
        op_en          <= 1'b0;
        cs_en          <= 1'b1;      // deselected
        clk_en         <= 1'b0;
        sq_mode        <= S;
        busy           <= 1'b1;      // busy until init completes
        CONT_ENG       <= 8'h00;
        out_byte       <= 8'h00;
        out_byte_ready <= 1'b0;
        byte_received  <= 1'b0;
    end else begin
        // single-cycle strobes default low
        out_byte_ready <= 1'b0;
        byte_received  <= 1'b0;

        case (state)

        // ---------------------------------------------------------- STARTUP
        // 150us wait, then 66h / 99h / 35h, each a single-byte S-mode command
        STARTUP: begin
            case (intra_state)
            4'd0: begin                        // power-up delay
                busy <= 1'b1;
                if (cnt == PWRUP_CYCLES) begin
                    sq_mode <= S;
                    clk_en  <= 1'b1;
                    cnt     <= 14'd0;
                    intra_state <= 4'd1;
                end else
                    cnt <= cnt + 14'd1;
            end
            4'd1: begin                        // assert CS#, present opcode
                cs_en    <= 1'b0;
                op_en    <= 1'b1;
                CONT_ENG <= init_cmd;
                intra_state <= 4'd2;
            end
            4'd2: begin                        // launch, hold start
                start <= 1'b1;
                intra_state <= 4'd3;
            end
            4'd3: begin                        // opcode only: no addr/data
                if (done) begin
                    start    <= 1'b0;
                    cs_en    <= 1'b1;
                    op_en    <= 1'b0;
                    wait_cnt <= 4'd0;
                    intra_state <= 4'd4;
                end
            end
            4'd4: begin                        // tCPH gap
                if (wait_cnt == CS_GAP) begin
                    if (init_idx == 2'd2) begin
                        sq_mode <= Q;          // 35h has landed: QPI from here
                        busy    <= 1'b0;
                        state   <= IDLE;
                        intra_state <= 4'd0;
                    end else begin
                        init_idx <= init_idx + 2'd1;
                        intra_state <= 4'd1;
                    end
                end else
                    wait_cnt <= wait_cnt + 4'd1;
            end
            default: intra_state <= 4'd0;
            endcase
        end

        // ---------------------------------------------------------- IDLE
        IDLE: begin
            busy <= 1'b0;
            if (start_fsm) begin
                cmd_reg  <= command;
                addr_reg <= address;
                len_reg  <= cache_word_length;
                busy     <= 1'b1;
                state    <= ASSERT_CS;
            end
        end

        ASSERT_CS: begin
            cs_en       <= 1'b0;
            op_en       <= 1'b1;
            state       <= SEND_COMMAND;
            intra_state <= 4'd0;
        end

        // ---------------------------------------------------- SEND_COMMAND
        // one byte: EBh or 38h, quad (2 nibbles, 2 SCLK)
        SEND_COMMAND: begin
            case (intra_state)
            4'd0: begin
                CONT_ENG    <= cmd_reg;
                start       <= 1'b1;
                intra_state <= 4'd1;
            end
            4'd1: if (done) begin
                start       <= 1'b0;
                sh          <= addr_reg;
                byte_cnt    <= {3'b0, ADDR_BYTES};
                state       <= SEND_ADDRESS;
                intra_state <= 4'd0;
            end
            default: intra_state <= 4'd0;
            endcase
        end

        // ---------------------------------------------------- SEND_ADDRESS
        // three bytes, MSB first, out of the shift register
        SEND_ADDRESS: begin
            case (intra_state)
            4'd0: begin
                CONT_ENG    <= sh[23:16];
                start       <= 1'b1;
                intra_state <= 4'd1;
            end
            4'd1: if (done) begin
                start <= 1'b0;
                sh    <= {sh[15:0], 8'h00};
                if (byte_cnt == 6'd1) begin
                    intra_state <= 4'd0;
                    if (is_read) begin
                        op_en    <= 1'b0;          // release before the
                        byte_cnt <= {3'b0, DUMMY_BYTES};
                        state    <= DUMMY_CYCLES;  // device starts driving
                    end else begin
                        byte_cnt <= len_reg;
                        state    <= WRITE_DATA;    // 38h has no dummy phase
                    end
                end else begin
                    byte_cnt    <= byte_cnt - 6'd1;
                    intra_state <= 4'd0;
                end
            end
            default: intra_state <= 4'd0;
            endcase
        end

        // ---------------------------------------------------- DUMMY_CYCLES
        // three receive transfers, results discarded == 6 dummy SCLK
        DUMMY_CYCLES: begin
            case (intra_state)
            4'd0: begin
                start       <= 1'b1;               // op_en already 0
                intra_state <= 4'd1;
            end
            4'd1: if (done) begin
                start <= 1'b0;
                if (byte_cnt == 6'd1) begin
                    byte_cnt    <= len_reg;
                    state       <= READ_DATA;
                    intra_state <= 4'd0;
                end else begin
                    byte_cnt    <= byte_cnt - 6'd1;
                    intra_state <= 4'd0;
                end
            end
            default: intra_state <= 4'd0;
            endcase
        end

        // ------------------------------------------------------ WRITE_DATA
        WRITE_DATA: begin
            case (intra_state)
            4'd0: begin
                CONT_ENG    <= in_byte;
                start       <= 1'b1;
                intra_state <= 4'd1;
            end
            4'd1: if (done) begin
                start         <= 1'b0;
                byte_received <= 1'b1;             // cache: advance in_byte
                if (byte_cnt == 6'd1) begin
                    wait_cnt    <= 4'd0;
                    state       <= DEASSERT_CS;
                    intra_state <= 4'd0;
                end else begin
                    byte_cnt    <= byte_cnt - 6'd1;
                    intra_state <= 4'd2;           // let in_byte settle
                end
            end
            4'd2: intra_state <= 4'd0;
            default: intra_state <= 4'd0;
            endcase
        end

        // ------------------------------------------------------- READ_DATA
        READ_DATA: begin
            case (intra_state)
            4'd0: begin
                start       <= 1'b1;               // op_en still 0
                intra_state <= 4'd1;
            end
            4'd1: if (done) begin
                start       <= 1'b0;
                intra_state <= 4'd2;               // ENG_CONT valid next cycle
            end
            4'd2: begin
                out_byte       <= ENG_CONT;
                out_byte_ready <= 1'b1;
                if (byte_cnt == 6'd1) begin
                    wait_cnt    <= 4'd0;
                    state       <= DEASSERT_CS;
                    intra_state <= 4'd0;
                end else begin
                    byte_cnt    <= byte_cnt - 6'd1;
                    intra_state <= 4'd0;
                end
            end
            default: intra_state <= 4'd0;
            endcase
        end

        // ----------------------------------------------------- DEASSERT_CS
        DEASSERT_CS: begin
            op_en <= 1'b0;
            cs_en <= 1'b1;
            if (wait_cnt == CS_GAP) begin
                busy  <= 1'b0;
                state <= IDLE;
            end else
                wait_cnt <= wait_cnt + 4'd1;
        end

        default: state <= IDLE;
        endcase
    end
    end

endmodule



module QSPI_ENGINE(clk, rst_n, sclk, cs, SI, SO, ENG_CONT, CONT_ENG,
                  start, done, sq_mode, op_en, cs_en, clk_en);

input        clk, rst_n, start, sq_mode, op_en, cs_en, clk_en;
input  [7:0] CONT_ENG;
input  [3:0] SI;
output reg [3:0] SO;
output reg [7:0] ENG_CONT;
output       done, cs, sclk;

reg sclk_r, done_r, start_d;
reg [1:0] txfer_state;
reg [3:0] cnt;
reg [7:0] shreg;

localparam IDLE = 0, NIB_TXFER = 1, BIT_TXFER = 2;
localparam S = 1'b0, Q = 1'b1;

assign cs   = cs_en;
assign sclk = sclk_r;
assign done = done_r;

always @(posedge clk) begin
  if (!rst_n) begin
    txfer_state <= IDLE;
    sclk_r      <= 1'b0;
    cnt         <= 4'd0;
    done_r      <= 1'b0;
    start_d     <= 1'b0;
    SO          <= 4'b1100;
    ENG_CONT    <= 8'h00;
  end else begin
    done_r  <= 1'b0;                      // default: one-cycle pulse
    start_d <= start;                     // for rising-edge launch

    case (txfer_state)

    IDLE: begin
      sclk_r <= 1'b0;                     // park low (mode 0)
      if (start && !start_d && clk_en) begin
        shreg <= CONT_ENG;
        if (sq_mode == Q) begin
          cnt         <= 4'd1;            // two nibbles
          txfer_state <= NIB_TXFER;
          if (op_en) SO <= CONT_ENG[7:4]; // preload before first rise
        end else begin
          cnt         <= 4'd7;            // eight bits
          txfer_state <= BIT_TXFER;
          // DQ3=/HOLD, DQ2=/WP held HIGH in serial mode
          if (op_en) SO <= {2'b11, 1'b0, CONT_ENG[7]};
        end
      end
    end

    BIT_TXFER: begin                      // serial, transmit only
      sclk_r <= ~sclk_r;
      if (sclk_r) begin                   // this edge drops sclk: launch
        if (cnt == 4'd0) begin
          txfer_state <= IDLE;
          done_r      <= 1'b1;
        end else begin
          cnt <= cnt - 4'd1;
          SO  <= {2'b11, 1'b0, shreg[cnt-4'd1]};
        end
      end
    end

    NIB_TXFER: begin
      sclk_r <= ~sclk_r;
      if (op_en) begin
        if (sclk_r) begin                 // launch on the falling edge
          if (cnt == 4'd0) begin
            txfer_state <= IDLE;
            done_r      <= 1'b1;
          end else begin
            cnt <= cnt - 4'd1;
            SO  <= shreg[3:0];
          end
        end
      end else begin
        if (!sclk_r) begin                // sample on the rising edge
          if (cnt == 4'd0) begin
            ENG_CONT[3:0] <= SI;
            txfer_state   <= IDLE;
            done_r        <= 1'b1;
          end else begin
            ENG_CONT[7:4] <= SI;
            cnt <= cnt - 4'd1;
          end
        end
      end
    end

    default: txfer_state <= IDLE;
    endcase
  end
end

endmodule
