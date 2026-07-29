module SAR(clk, srs, srsp, REGS_SAR, SAR_SDC);

input clk, srs, srsp;
input[31:0] REGS_SAR;
output[31:0] SAR_SDC;
reg[31:0] SAR;

initial
begin
    SAR = 0;
end

always @(posedge clk)
begin
if (srs || srsp)
    SAR <= REGS_SAR;
end    

assign SAR_SDC = SAR;

endmodule