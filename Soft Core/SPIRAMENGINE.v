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