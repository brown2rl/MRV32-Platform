module Trap_Unit(clk, restu, tuwfi, tucall, tuint, tupc, rxinterrupt, rxack, tx_irq_en, rxpending, rxack, txready, tx_int_ack, txbusy, ecall, sret, mret, tupccs, tucspc, stupc, stucsr, stucsrpc, scspcecall, scspcmret, scspctxint, scspcrxint, scsr0, TU_PC, TU_CSR);

input clk, tuwfi, restu, ecall, sret, mret, rxinterrupt, tx_irq_en, txready, txbusy;
output reg tucall, tuint, tupc, tupccs, tucspc, stupc, stucsr, stucsrpc, scspcecall, scspcmret, scspctxint, scspcrxint, scsr0, rxpending, rxack, tx_int_ack;
output reg[31:0] TU_PC, TU_CSR;
reg takeirq, resirq, tx_fsm_cont, supmode;
reg[1:0] rxintstate, irqstate, mretstate;
reg[2:0] txintstate, ecallstate;
reg[31:0] mtvec, rxinterruptvec, txinterruptvec;
reg[15:0] fsm_cont_count;

initial
begin
	rxintstate = 0;
	irqstate = 0;
	resirq = 0;
	tx_int_ack = 0;
	tx_fsm_cont = 0;
	txintstate = 0;
	ecallstate = 0;
	mretstate = 0;
end

always @(posedge clk)
begin
if (ecall && ecallstate == 3'b000)
begin
	ecallstate <= 3'b001;
	tupccs <= 1;
end
else if (ecallstate == 3'b001)
begin
	stucsr <= 0;
	tupccs <= 0;
	ecallstate <= 3'b010;
end
else if (ecallstate == 3'b010)	
begin
	tupccs <= 0;
	scspcecall <= 0;
	ecallstate <= 3'b011;
end
else if (ecallstate == 3'b011)
begin
	scspcecall <= 1;
	ecallstate <= 3'b100;
end
else if (ecallstate == 3'b100)
begin
	scspcecall <= 0;
	ecallstate <= 3'b000;
end
if (mret && mretstate == 2'b00)
	begin
		scspcmret <= 1;
		supmode <= 0;
		mretstate <= 2'b01;
	end
else if (mretstate == 2'b01)
	begin
		scspcmret <= 0;
		mretstate <= 2'b00;
	end
if (sret)
	begin
		stucsrpc <= 1;
		tupc <= 1;
	end	

/*if (txintstate == 3'b000 && tx_irq_en && !txbusy)
begin
	scspctxint <= 1;
    	txintstate <= 3'b001;
end
else if (txintstate == 3'b001)
begin
	scspctxint <= 0;
        tx_int_ack <= 1;
	txintstate <= 3'b010;
end
else if (txintstate == 3'b010)
begin
    	tx_int_ack <= 0;
	txintstate <= 3'b011;
	fsm_cont_count <= 0;
end
else if (txintstate == 3'b011)
begin
    if (txbusy || !tx_irq_en)
    begin
        tx_fsm_cont <= 0;
        txintstate <= 3'b000;
    end
end*/
if (restu)
begin
	stucsr 	<= 0;
	stupc 	<= 0;
	tupccs 	<= 0;
	scsr0 	<= 0;
	stucsrpc<= 0;
	tupc 	<= 0;
	resirq 	<= 0;
end
end

always @(posedge clk)
if (rxinterrupt && tuwfi)
begin
	scspcrxint <= 1;
	rxack <= 1;
end
else
begin
	scspcrxint <= 0;
	rxack <= 0;
end



endmodule