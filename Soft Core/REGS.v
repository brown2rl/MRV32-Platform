module REGS( clk, indicators, out, spcr, spcrt, sraa, srab, sar, scmr, sramr, scsr, sramrs8, sramrs16, sramrs32, sramru8, sramru16, REGS_SAR, PC_REGS, REGS_PC, CM_REGS, REGS_CM, RAM_REGS, REGS_RAM, CSR_REGS, REGS_CSR, REGS_MAR, REGS_ALU_A, REG_A, REG_B, REG_D, REGS_ALU_B, ALU_REGS);
    
input clk, indicators;
input spcr, spcrt, sraa, srab, sar, scmr, sramr, scsr;
input sramrs8, sramrs16, sramrs32, sramru8, sramru16;

input [31:0] PC_REGS, CM_REGS, RAM_REGS, CSR_REGS, ALU_REGS, CACHE_REGS;
input [4:0]  REG_A, REG_B, REG_D;

output reg out;
output [31:0] REGS_PC, REGS_CM, REGS_RAM, REGS_CSR;
output [31:0] REGS_MAR, REGS_SAR, REGS_ALU_A, REGS_ALU_B;

(* ram_style = "registers" *)
reg [31:0] regs [0:31];

wire        wb_en;
reg [31:0] wb_data, PC_REGStemp;

integer i;

initial
begin
    for (i = 0; i < 32; i = i + 1)
        regs[i] = 32'h00;
end
        
assign wb_en =
        scmr     |
        spcr     |
        sar      |
        scsr     |
        sramrs8  |
        sramrs16 |
        sramrs32 |
        sramru8  |
        sramru16;

always @* begin
    wb_data = 32'd0;

    if (scmr)
        wb_data = CM_REGS;
    else if (spcr)
        wb_data = PC_REGStemp + 4;
    else if (sar)
        wb_data = ALU_REGS;
    else if (scsr)
    begin
        if (REG_D != 0)
        	wb_data = CSR_REGS;
        else
        	wb_data = 0;
    end
    else if (sramrs8)
        wb_data = $signed(RAM_REGS[7:0]);
    else if (sramrs16)
        wb_data = $signed(RAM_REGS[15:0]);
    else if (sramrs32)
        wb_data = RAM_REGS;
    else if (sramru8)
    	wb_data = RAM_REGS[7:0];
    else if (sramru16)
        wb_data = RAM_REGS[15:0];
end

always @(posedge clk)
if (spcrt)
	 PC_REGStemp <= PC_REGS;

//REGISTER FILE WRITE
always @(posedge clk)
begin
    if (wb_en && REG_D != 0) begin
        regs[REG_D] <= wb_data;
        if (indicators)
		$display("WRITEBACK: rd=%d data=%d or data=%b", REG_D, wb_data, wb_data);
    end
end

//READ PORTS
assign REGS_UART  = regs[REG_B][7:0];
assign REGS_ALU_A = regs[REG_A];
assign REGS_ALU_B = regs[REG_B];
assign REGS_PC    = regs[REG_A];
assign REGS_CM    = regs[REG_A];
assign REGS_RAM   = regs[REG_B];
assign REGS_CSR   = regs[REG_A];
assign REGS_MAR   = regs[REG_A];
assign REGS_SAR   = regs[REG_B];

endmodule
