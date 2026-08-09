module spi(clk, rst_n);

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