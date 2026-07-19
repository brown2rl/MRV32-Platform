module CM(clk, rst, tu, restu, ecall, sret, mret, rxinterrupt, tx_int_ack, sdrs, sdrd, sdws, sdwd, srs, pc, bacm, stucsrpc, pcpi, ipc, mpi, rpi, scmcsi, scmcst, scmpc, jalr, cur, smi, spm, srm, crm, sri, spcr, spcrt, srpc, spca, sraa, srab, sar, scmr, srcm, srram, srr8, srr16, srr32, sramrs8, sramrs16, sramrs32, sramru8, sramru16, scsr, srcs, spcs, scsp, scmcs, csbmr, csbmi, csor, csori, csan, csrl, csani, smrar, scma, scmau, stupc, ALU_OP, CM_PC, IR_CM, REGS_CM, CM_REGS, REG_A, REG_B, REG_D, CM_ALU, ALU_CM, CM_CSR, CM_CSRI, CM_CSRT, CM_MAR, CSR_DEV_SEL);

input clk, rst, bacm, stucsrpc, stupc, rxinterrupt, tx_int_ack, sdrd, sdwd;
input[31:0] IR_CM, REGS_CM, ALU_CM, CSR_DEV_SEL;
output reg[31:0] CM_REGS, CM_CSRI, CM_CSRT;
output reg[11:0] CM_CSR;
output reg[19:0] CM_PC;
output reg[31:0] CM_MAR;
output reg[31:0] CM_ALU;
output reg[4:0] REG_A, REG_B, REG_D, ALU_OP;
output reg tu, restu, ecall, sret, mret, sdrs, sdws, srs, pc, pcpi, mpi, rpi, ipc, scmcsi, scmcst, scmpc, jalr, cur, smi, spm, srm, crm, sri, spcr, spcrt, srpc, spca, sraa, srab, sar, scmr, srcm, srram, srr8, srr16, srr32, sramrs8, sramrs16, sramrs32, sramru8, sramru16, scsr, srcs, spcs, scsp, scmcs, csbmr, csbmi, csor, csori, csan, csrl, csani, smrar, scma, scmau;
wire[31:0] instruction;
reg[5:0] T;
reg[16:0] scounter;
reg wfi, resT, sup, pf, ri;
localparam [4:0]
    add  = 5'd1,
    mul  = 5'd2,
    XOR  = 5'd3,
    OR   = 5'd4,
    AND  = 5'd5,
    sll  = 5'd6,
    srl  = 5'd7,
    sra  = 5'd8,
    sub  = 5'd9,
    sllr = 5'd10,
    srlr = 5'd11,
    srar = 5'd12,
    lt   = 5'd13,
    ltu  = 5'd14,
    beq  = 5'd15,
    bneq = 5'd16,
    bge  = 5'd17,
    bgeu = 5'd18,
    blt  = 5'd19,
    bltu = 5'd20,
    mulh = 5'd21,
    mulhsu = 5'd22,
    mulhu = 5'd23,
    div = 5'd24,
    divu = 5'd25,
    rem  = 5'd26,
    remu = 5'd27;
    
assign instruction = IR_CM;

initial
begin
	T = 3'b0;
	//resT = 1'b1;
	wfi = 1'b0;
	REG_A	= 0;	
	REG_B	= 0;
	REG_D	= 0;
	CM_REGS = 0;
    	CM_CSR  = 0;
    	CM_CSRI = 0;
    	CM_CSRT = 0;
    	CM_PC   = 0;
   	CM_MAR  = 0;
    	CM_ALU  = 0;
    	ALU_OP  = 0;
	sret	= 0;
	mret	= 0;
	ri	= 0;
	pf	= 0;
	tu	= 0;	
	restu    = 0;
	pc 	= 0;
	pcpi	= 0;
	mpi	= 0;
	rpi	= 0;
	scmpc	= 0;
	jalr	= 0;
	cur	= 0;
	smi	= 0;
	spm	= 0;
	srm	= 0;	
	crm 	= 0;
	ipc	= 0;
	sri	= 0;
	spcr	= 0;
	srpc	= 0;
	spca	= 0;
	sraa	= 0;
	srab	= 0;
	sar	= 0;
	scmr	= 0;
	srcm	= 0;
	srram	= 0;
	srr8	= 0;
	srr16	= 0;
	srr32	= 0;
	sramrs8	= 0;
	sramrs16= 0;
	sramrs32= 0;
	sramru8	= 0;
	sramru16= 0;
	scsr	= 0;
	srcs	= 0;
	spcs	= 0;
	scsp	= 0;
	scmcs	= 0;
	csbmr	= 0;
	csbmi	= 0;
	csor	= 0;
	csan	= 0;
	csrl	= 0;
	smrar	= 0;
	scma	= 0;
	scmau	= 0;
	scmcst	= 0;
	resT	= 0;
end

always @(posedge clk)
if (stupc)
begin
    	T <= 0;
    	wfi <= 0;
end
else if (rxinterrupt)
begin
	T <= 0;
	wfi <= 0;
end
else if (tx_int_ack)
begin
    	T <= 0;
    	wfi <= 0;
end
else if (wfi && (sdrd || sdwd))
begin
    wfi <= 0;
end
else if (!wfi)
begin
    	T <= T + 1;
	if (T == 0 || ri)
	begin
		REG_A	<= 0;	
		REG_B	<= 0;
		REG_D	<= 0;
	    	CM_REGS <= 0;
        	CM_CSR  <= 0;
        	CM_CSRI <= 0;
        	CM_CSRT <= 0;
        	CM_PC   <= 0;
        	CM_MAR  <= 0;
        	CM_ALU  <= 0;
		ALU_OP  <= 0;
		sret	<= 0;
		mret	<= 0;
		ri	<= 0;
		tu	<= 0;	
		restu   <= 0;
		pc 	<= 0;
		pcpi	<= 0;
		mpi	<= 0;
		scmpc	<= 0;
		jalr	<= 0;
		cur 	<= 0;
		smi	<= 0;
		if (!ri)
			spm	<= 1;
		srm	<= 0;	
		crm 	<= 0;
		ipc	<= 0;
		sri	<= 0;
		spcr	<= 0;
		srpc	<= 0;
		spca	<= 0;
		sraa	<= 0;
		srab	<= 0;
		sar	<= 0;
		scmr	<= 0;
		srcm	<= 0;
		srram	<= 0;
		srr8	<= 0;
		srr16	<= 0;
		srr32	<= 0;
		sramrs8	<= 0;
		sramrs16<= 0;
		sramrs32<= 0;
		sramru8	<= 0;
		sramru16<= 0;
		scsr	<= 0;
		srcs	<= 0;
		spcs	<= 0;
		scsp	<= 0;
		scmcs	<= 0;
		csbmr	<= 0;
		csbmi	<= 0;
		csor	<= 0;
		csan	<= 0;
		csrl	<= 0;
		smrar	<= 0;
		scma	<= 0;
		scmau	<= 0;
		scmcst	<= 0;
		resT	<= 0;
	end
	else if (T == 1)
	begin
		spm	<= 0;
	end
	
	else if (T == 2)
	begin
		sri	<= 1;
	end
	else if (T >= 3)
	begin
		sri 	<= 0;
		if (!((instruction[6:0] == 7'b0010111) || (instruction[6:0] == 7'b1110011) || (instruction[6:0] == 7'b0000011) || (instruction[6:0] == 7'b0100011) || (instruction[6:0] == 7'b1101111) || (instruction[6:0] == 7'b1100111) || (instruction[6:0] == 7'b1100011)))
		begin
	
			if (T == 4)
			begin
				pc	<= 1;	
			end
			if (T == 5)
			begin
				spm	<= 1;
				pc	<= 0;
			end
			if (T == 6)
				spm	<= 0;		
		end

		//lui
		if (instruction[6:0] == 7'b0110111)
		begin
		
			REG_D <= instruction[11:7];
			CM_REGS <= { instruction[31:12], 12'b000000000000 };
			scmr <= 0;
			sri <= 0;
			
			if (T == 4)
			begin
				scmr 	<= 1;
			end
			
			if (T >= 7)
			begin
				sri	<= 1;
				T 	<= 3;
				ri	<= 1;
			end
		end
		
		//auipc
		if (instruction[6:0] == 7'b0010111)
		begin
		
			REG_D <= instruction[11:7];
			CM_ALU <= { instruction[31:12], 12'b000000000000 };
			scma 	<= 0;
			spca 	<= 0;
			sar 	<= 0;
			ALU_OP 	<= 0;
			//sri	<= 0;
			
			if  (T == 4)
			begin
				scma 	<= 1;
				spca 	<= 1;
				ALU_OP 	<= add;
			end
			
			if (T == 5)
			begin
				sar 	<= 1;
			end
			
			if (T >= 7)
			begin
				pc	<= 1;
				T 	<= 0;
				//ri	<= 1;
			end
		end
		
		if (instruction[6:0] == 7'b0010011)
		begin
			//addi
			if (instruction[14:12] == 3'b000)
			begin				
			
				REG_D 	<= instruction[11:7];
				REG_A 	<= instruction[19:15];
				CM_ALU 	<= { {20{instruction[31]}}, instruction[31:20] };
                		scma 	<= 0;
                		sraa 	<= 0;
                		ALU_OP 	<= 0;
                		sar  	<= 0;
                		sri   	<= 0;
				
				if (T == 4)
				begin
					scma 	<= 1;
					sraa 	<= 1;
					ALU_OP 	<= add;
				end
				
				else if (T == 5)
				begin
					sar 	<= 1;
			   	end
			    
				else if (T >= 7)
				begin
					sri	<= 1;
					T 	<= 3;
					ri	<= 1;
				end
			end
		
			//slti
			if (instruction[14:12] == 3'b010)
			begin
			
				REG_D 	<= instruction[11:7];
				REG_A 	<= instruction[19:15];
				CM_ALU 	<= { {20{instruction[31]}}, instruction[31:20] };
				scma 	<= 0;
				sraa 	<= 0;
				ALU_OP 	<= 0;
				sar 	<= 0;
				sri	<= 0;
				
				if (T == 4)
				begin
					scma 	<= 1;
					sraa 	<= 1;
					ALU_OP 	<= lt;
				end
				
				if (T == 5)
				begin
					sar	<= 1;
				end
				
				if (T >= 7)
				begin
					sri	<= 1;
					T 	<= 3;
					ri	<= 1;
				end
			end
			
			//sltiu
			if (instruction[14:12] == 3'b011)
			begin
			
				REG_A 	<= instruction[19:15];
				REG_D 	<= instruction[11:7];
				CM_ALU 	<= { {20{instruction[31]}}, instruction[31:20] };
				scmau 	<= 0;
				sraa 	<= 0;
				ALU_OP 	<= 0;
				sar 	<= 0;
				sri	<= 0;
				
				if (T == 4)
				begin
					scmau 	<= 1;
					sraa 	<= 1;
					ALU_OP 	<= ltu;
				end
				
				if (T == 5)
				begin
					sar 	<= 1;
				end
				
				if (T >= 7)
				begin
					sri	<= 1;
					T 	<= 3;
					ri	<= 1;
				end
			end
			
			//xori
			if (instruction[14:12] == 3'b100)
			begin
				
				REG_D 	<= instruction[11:7];
				REG_A 	<= instruction[19:15];
				CM_ALU 	<= { {20{instruction[31]}}, instruction[31:20] };
				scma 	<= 0;
				sraa 	<= 0;
				ALU_OP 	<= 0;
				sar	<= 0;
				sri	<= 0;
				
				if (T == 4)
				begin
					scma 	<= 1;
					sraa 	<= 1;
					ALU_OP 	<= XOR;
				end
				
				if (T == 5)
				begin
					sar 	<= 1;
				end
	
				if (T >= 7)
				begin
					sri	<= 1;
					T 	<= 3;
					ri	<= 1;
				end
			end
			
			//ori
			if (instruction[14:12] == 3'b110)
			begin
			
				REG_D 	<= instruction[11:7];
				REG_A 	<= instruction[19:15];
				CM_ALU 	<= { 20'b0, instruction[31:20] };
				scma 	<= 0;
				sraa 	<= 0;
				ALU_OP 	<= 0;
				sar 	<= 0;
				sri	<= 0;
				
				if (T == 4)
				begin
					scma 	<= 1;
					sraa 	<= 1;
					ALU_OP 	<= OR;
				end
				
				if (T == 5)
				begin
					sar 	<= 1;
				end
				
				if (T >= 7)
				begin
					sri	<= 1;
					T 	<= 3;
					ri	<= 1;
				end
			end
			
			//andi
			if (instruction[14:12] == 3'b111)
			begin
			
				REG_D 	<= instruction[11:7];
				REG_A 	<= instruction[19:15];
				CM_ALU 	<= { 20'b0, instruction[31:20] };
				scma 	<= 0;
				sraa 	<= 0;
				ALU_OP 	<= 0;
				sar 	<= 0;
				sri	<= 0;
				
				if (T == 4)
				begin
					scma 	<= 1;
					sraa 	<= 1;
					ALU_OP 	<= AND;
				end
				
				if (T == 5)
				begin
					sar	<= 1;
				end
				
				if (T >= 7)
				begin
					sri	<= 1;
					T 	<= 3;
					ri	<= 1;
				end	
			end
			
			//slli
			if (instruction[14:12] == 3'b001)
			begin
			
				REG_D 	<= instruction[11:7];
				REG_A 	<= instruction[19:15];
				CM_ALU 	<= { 27'b0, instruction[24:20] };
				scmau 	<= 0;
				sraa 	<= 0;
				ALU_OP 	<= 0;
				sar 	<= 0;
				sri	<= 0;
				
				if (T == 4)
				begin
					scmau 	<= 1;
					sraa 	<= 1;
					ALU_OP 	<= sll;
				end
				
				if (T == 5)
				begin
					sar 	<= 1;
				end
				
				if (T >= 7)
				begin
					sri	<= 1;
					T 	<= 3;
					ri	<= 1;
				end
			end
			
			//srli
			if (instruction[14:12] == 3'b101)
			begin
				if (instruction[31:25] == 7'b0000000)	
				begin
		
					REG_D 	<= instruction[11:7];
					REG_A 	<= instruction[19:15];
					CM_ALU 	<= { 27'b0, instruction[24:20] };
					scmau 	<= 0;
					sraa 	<= 0;
					ALU_OP 	<= 0;
					sar 	<= 0;
					sri	<= 0;
					
					if (T == 4)
					begin
						scmau 	<= 1;
						sraa 	<= 1;
						ALU_OP	<= srl;
					end
					
					if (T == 5)
					begin
						sar 	<= 1;
					end
					
					if (T >= 7)
					begin
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end
				end
				
				//srai
				if (instruction[31:25] == 7'b0100000)	
				begin
				
					REG_D 	<= instruction[11:7];
					REG_A 	<= instruction[19:15];
					CM_ALU 	<= { 27'b0, instruction[24:20] };
					scmau 	<= 0;
					sraa 	<= 0;
					sar 	<= 0;
					sri	<= 0;
				
					if (T == 4)
					begin
						scmau 	<= 1;
						sraa 	<= 1;
						ALU_OP 	<= sra;
					end
					
					if (T == 5)
					begin
						sar 	<= 1;
					end
	
					if (T >= 7)
					begin
						sri	<= 1;
						T 	<= 3;	
						ri	<= 1;				
					end
				end
			end
		end
		
		if (instruction[6:0] == 7'b0110011)
		begin
			if (instruction[14:12] == 3'b000)
			begin
				//add
				if (instruction[31:25] == 7'b0000000)
				begin
				
					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					srab 	<= 0;
					sraa 	<= 0;
					ALU_OP 	<= 0;
					sar 	<= 0;
					sri	<= 0;
					
					if (T == 4)
					begin
						srab 	<= 1;
						sraa 	<= 1;
						ALU_OP 	<= add;
					end
					
					if (T == 5)
					begin
						sar 	<= 1;
					end	
				
					if (T >= 7)
					begin
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end
				end
				
				//sub
				if (instruction[31:25] == 7'b0100000)
				begin
					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					srab 	<= 0;
					sraa 	<= 0;
					ALU_OP 	<= 0;
					sar 	<= 0;
					sri	<= 0;
										
					if (T == 4)
					begin
						srab 	<= 1;
						sraa 	<= 1;
						ALU_OP	<= sub;
					end
				    
				   	if (T == 5)
				   	begin
				        	sar <= 1;
				    	end
				    
					if (T >= 7)
					begin
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end
				end
			end
				
				
			if (instruction[31:25] == 7'b0000001)
			begin
				//mul
				if (instruction[14:12] == 3'b000)
				begin

					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					srab 	<= 0;
					sraa 	<= 0;
					ALU_OP 	<= 0;
					sar 	<= 0;
					sri	<= 0;
						
					if (T == 4)
					begin
						srab <= 1;
						sraa <= 1;
						ALU_OP <= mul;
					end
						
					if (T == 5)
					begin
						sar <= 1;
					end
	
					if (T >= 7)
					begin
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end	
				end
					
				//mulh
				if (instruction[14:12] == 3'b001)
				begin

					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					srab 	<= 0;
					sraa 	<= 0;
					ALU_OP 	<= 0;
					sar 	<= 0;
					sri	<= 0;
						
					if (T == 4)
					begin
						srab <= 1;
						sraa <= 1;
						ALU_OP <= mulh;
					end
					
					if (T == 5)
					begin
						sar <= 1;
					end
		
					if (T >= 7)
					begin
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end	
				end
					
					
				//mulhsu
				if (instruction[14:12] == 3'b010)
				begin

					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					srab 	<= 0;
					sraa 	<= 0;
					ALU_OP 	<= 0;
					sar 	<= 0;
					sri	<= 0;
						
					if (T == 4)
					begin
						srab <= 1;
						sraa <= 1;
						ALU_OP <= mulhsu;
					end
						
					if (T == 5)
					begin
						sar <= 1;
					end
		
					if (T >= 7)
					begin
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end	
				end
				
				//mulhu
				if (instruction[14:12] == 3'b011)
				begin

					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					srab 	<= 0;
					sraa 	<= 0;
					ALU_OP 	<= 0;
					sar 	<= 0;
					sri	<= 0;
					
					if (T == 4)
					begin
						srab <= 1;
						sraa <= 1;
						ALU_OP <= mulhu;
					end
					
					if (T == 5)
					begin
						sar <= 1;
					end
		
					if (T >= 7)
					begin
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end	
				end
					
				//div
				if (instruction[14:12] == 3'b100)
				begin
					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					sar 	<= 0;
					sri	<= 0;
					
					if (T == 4)
					begin
						ALU_OP <= div;
						srab <= 1;
						sraa <= 1;
					end
						
					if (T == 38)
					begin
						sar <= 1;
						ALU_OP <= 0;
					end
		
					if (T >= 39)
					begin
						srab 	<= 0;
						sraa 	<= 0;
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end	
				end
				
					
				//divu
				if (instruction[14:12] == 3'b101)
				begin
					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					sar 	<= 0;
					sri	<= 0;
					
					if (T == 4)
					begin
						ALU_OP <= divu;
						srab <= 1;
						sraa <= 1;
					end
						
					if (T == 38)
					begin
						sar <= 1;
						ALU_OP <= 0;
					end
		
					if (T >= 39)
					begin
						srab 	<= 0;
						sraa 	<= 0;
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end	
				end
									
				//rem
				if (instruction[14:12] == 3'b110)
				begin
					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					sar 	<= 0;
					sri	<= 0;
					
					if (T == 4)
					begin
						ALU_OP <= rem;
						srab <= 1;
						sraa <= 1;
					end
						
					if (T == 38)
					begin
						sar <= 1;
						ALU_OP <= 0;
					end
		
					if (T >= 39)
					begin
						srab 	<= 0;
						sraa 	<= 0;
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end	
				end
									
				//remu
				if (instruction[14:12] == 3'b111)
				begin
					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					sar 	<= 0;
					sri	<= 0;
					
					if (T == 4)
					begin
						ALU_OP <= remu;
						srab <= 1;
						sraa <= 1;
					end
						
					if (T == 38)
					begin
						sar <= 1;
						ALU_OP <= 0;
					end
		
					if (T >= 39)
					begin
						srab 	<= 0;
						sraa 	<= 0;
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end	
				end
			end	
		
			
			if (instruction[14:12] == 3'b001)
			begin
				//sll
				if (instruction[31:25] == 7'b0000000)
				begin
				
					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					srab 	<= 0;
					sraa 	<= 0;
					ALU_OP 	<= 0;
					sar 	<= 0;
					sri 	<= 0;
					
					if (T == 4)
					begin
						srab 	<= 1;
						sraa 	<= 1;
						ALU_OP 	<= sll;
					end
					
					if (T == 5)
					begin
						sar 	<= 1;
					end
					
					if (T >= 7)
					begin
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end
				end
			end
			
						

			//slt
			if (instruction[14:12] == 3'b010 && instruction[31:25] == 7'b0000000)
			begin

				REG_D 	<= instruction[11:7];	
				REG_A 	<= instruction[19:15];
				REG_B 	<= instruction[24:20];
				srab 	<= 0;
				sraa 	<= 0;
				ALU_OP 	<= 0;
				sar 	<= 0;
				sri	<= 0;
			
				if (T == 4)
				begin
					srab 	<= 1;
					sraa 	<= 1;
					ALU_OP 	<= lt;
				end
				
				if (T == 5)
				begin
					sar 	<= 1;	
				end
				
				if (T >= 7)
				begin
					sri	<= 1;
					T 	<= 3;
					ri	<= 1;
				end
				
			end
			
			//sltu
			if (instruction[14:12] == 3'b011 && instruction[31:25] == 7'b0000000)
			begin

				REG_D 	<= instruction[11:7];	
				REG_A 	<= instruction[19:15];
				REG_B 	<= instruction[24:20];
				srab 	<= 0;
				sraa 	<= 0;
				ALU_OP 	<= 0;
				sar 	<= 0;
				sri	<= 0;
			
				if (T == 4)
				begin
					srab 	<= 1;
					sraa 	<= 1;
					ALU_OP 	<= ltu;
				end
				
				if (T == 5)
				begin
					sar 	<= 1;	
				end
				
				if (T >= 7)
				begin
					sri	<= 1;
					T 	<= 3;
					ri	<= 1;
				end
				
			end
			
			//xor
			if (instruction[14:12] == 3'b100 && instruction[31:25] == 7'b0000000)
			begin

				REG_D 	<= instruction[11:7];	
				REG_A 	<= instruction[19:15];
				REG_B 	<= instruction[24:20];
				srab 	<= 0;
				sraa 	<= 0;
				ALU_OP 	<= 0;
				sar 	<= 0;
				sri	<= 0;
			
				if (T == 4)
				begin
					srab 	<= 1;
					sraa 	<= 1;
					ALU_OP 	<= XOR;
				end
				
				if (T == 5)
				begin
					sar 	<= 1;	
				end
				
				if (T >= 7)
				begin
					sri	<= 1;
					T 	<= 3;
					ri	<= 1;
				end
				
			end

			if (instruction[14:12] == 3'b101)
			begin	
				//srl
				if (instruction[31:25] == 7'b0000000)
				begin

				REG_D 	<= instruction[11:7];	
				REG_A 	<= instruction[19:15];
				REG_B 	<= instruction[24:20];
				srab 	<= 0;
				sraa 	<= 0;
				ALU_OP 	<= 0;
				sar 	<= 0;
				sri	<= 0;
			
				if (T == 4)
				begin
					srab 	<= 1;
					sraa 	<= 1;
					ALU_OP 	<= srl;
				end
				
				if (T == 5)
				begin
					sar 	<= 1;	
				end
				
				if (T >= 7)
				begin
					sri	<= 1;
					T 	<= 3;
					ri	<= 1;
				end
				
			end
				
				//sra
				if (instruction[31:25] == 7'b0100000)
				begin

					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					srab 	<= 0;
					sraa 	<= 0;
					ALU_OP 	<= 0;
					sar 	<= 0;
					sri	<= 0;
				
					if (T == 4)
					begin
						srab 	<= 1;
						sraa 	<= 1;
						ALU_OP 	<= sra;
					end
					
					if (T == 5)
					begin
						sar 	<= 1;	
					end
					
					if (T >= 7)
					begin
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end
				
				end
			end
			
	
			if (instruction[14:12] == 3'b110)
			begin	
				//or
				if (instruction[31:25] == 7'b0000000)
				begin

					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					srab 	<= 0;
					sraa 	<= 0;
					ALU_OP 	<= 0;
					sar 	<= 0;
					sri	<= 0;
			
					if (T == 4)
					begin
						srab 	<= 1;
						sraa 	<= 1;
						ALU_OP 	<= OR;
					end
				
					if (T == 5)
					begin
						sar 	<= 1;	
					end
				
					if (T >= 7)
					begin
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end
				end
			end
			
			
			if (instruction[14:12] == 3'b111)
			begin	
				//and
				if (instruction[31:25] == 7'b0000000)
				begin

					REG_D 	<= instruction[11:7];	
					REG_A 	<= instruction[19:15];
					REG_B 	<= instruction[24:20];
					srab 	<= 0;
					sraa 	<= 0;
					ALU_OP 	<= 0;
					sar 	<= 0;
					sri	<= 0;
			
					if (T == 4)
					begin
						srab 	<= 1;
						sraa 	<= 1;
						ALU_OP 	<= AND;
					end
				
					if (T == 5)
					begin
						sar 	<= 1;	
					end
				
					if (T >= 7)
					begin
						sri	<= 1;
						T 	<= 3;
						ri	<= 1;
					end
				end
			end
		end
		
		if (instruction[6:0] == 7'b1110011)
		begin
			//csrrw
			if (instruction[14:12] == 3'b001)
			begin
			
				REG_D 	<= instruction[11:7];		
				REG_A 	<= instruction[19:15];
				CM_CSR 	<= instruction[31:20];
				scmcs 	<= 0;
				scsr 	<= 0;
				srcs 	<= 0;
				csrl	<= 0;
				
				if (T == 4)
				begin
					scmcs <= 1;
				end
				
				if (T == 5)
				begin
					scsr <= 1;
				end
					
				if (T == 6)
				begin
					srcs <= 1;
				end
					
				if (T >= 7)
				begin
					csrl <= 1;
					T 	<=0;
					pc	<= 1;
				end
			end
				
			//csrrs
			if (instruction[14:12] == 3'b010)
			begin
			
				REG_D 	<= instruction[11:7];		
				REG_A 	<= instruction[19:15];
				CM_CSR 	<= instruction[31:20];
				scmcs 	<= 0;
				csbmr 	<= 0;
				scsr 	<= 0;
				csor 	<= 0;
				csrl	<= 0;			
			
				if (T == 4)
				begin
					scmcs <= 1;
				end				
			
				if (T == 5)
				begin
					csbmr <= 1;
					scsr <= 1;
				end
				
				if (T == 6)
				begin
					csor <= 1;
				end
				
				if (T >= 7)
				begin
					csrl <= 1;
					T 	<=0;
					pc	<= 1;
				end
			end	
			
			//csrrc
			if (instruction[14:12] == 3'b011)
			begin

				REG_D 	<= instruction[11:7];		
				REG_A 	<= instruction[19:15];
				CM_CSR 	<= instruction[31:20];
				scmcs 	<= 0;
				scsr 	<= 0;
				csbmr 	<= 0;
				csan 	<= 0;
				csrl	<= 0;
				sri 	<= 0;				
				
				if (T == 4)
				begin
					scmcs <= 1;
	            		end				
				
				if (T == 5)
				begin
					scsr <= 1;
					csbmr <= 1;
	            		end
	            
				if (T == 6)
				begin
					csan <= 1;
				end
				
				if (T >= 7)
				begin
					csrl <= 1;
					T 	<=0;
					pc	<= 1;
				end
			end	
			
			//csrwi
			if (instruction[14:12] == 3'b101)
			begin
			
				REG_D 	<= instruction[11:7];		
				CM_CSRI <= { 27'b0 , instruction[19:15] };
				CM_CSR 	<= instruction[31:20];
				scmcs 	<= 0;
				scsr 	<= 0;
				scmcsi 	<= 0;
				csrl	<= 0;
						
				if (T == 4)
				begin
					scmcs <= 1;
				end	
						
				if (T == 5)
				begin
					scsr <= 1;
				end
				
				if (T == 6)
				begin
					scmcsi <= 1;
				end
				
				if (T >= 7)
				begin
					csrl 	<= 1;
					T 	<=0;
					pc	<= 1;
				end
			
			end
			
			//csrrsi
			if (instruction[14:12] == 3'b110)
			begin
	
				REG_D 	<= instruction[11:7];		
				CM_CSRI <= { 27'b0 , instruction[19:15] };
				CM_CSR 	<= instruction[31:20];
				scmcs 	<= 0;
				csbmi 	<= 0;
				scsr 	<= 0;
				csori 	<= 0;
				csrl	<= 0;
				
				if (T == 4)
				begin
					scmcs <= 1;
				end

				if (T == 5)
				begin
					csbmi <= 1;
				end
				
				if (T == 6)
				begin
					csori <= 1;
				end
				
				if (T >= 7)
				begin
					csrl <= 1;
					T 	<=0;
					pc	<= 1;
				end
			end
			
			//csrrci
			if (instruction[14:12] == 3'b111)
			begin
			
				REG_D 	<= instruction[11:7];	
				CM_CSRI <= { 27'b0 , instruction[19:15] };
				CM_CSR 	<= instruction[31:20];
				scmcs 	<= 0;
				csbmi 	<= 0;
				scsr 	<= 0;
				scsr 	<= 0;
				csani 	<= 0;
				csrl	<= 0;
	
				if (T == 4)
				begin
					scmcs <= 1;
					csbmi <= 1;
					scsr <= 1;
	            		end
	            
				if (T == 5)
				begin
					scsr <= 0;
					csani <= 1;
				end
	
				if (T >= 7)
				begin
					csrl 	<= 1;
					T 	<=0;
					pc	<= 1;
				end
			end		
		
			//ecall
			if (instruction[31:15] == 17'b0)
			begin
				ecall <= 0;
				restu <= 0;
		
				if (T == 4)
				begin
					ecall <= 1;
                		end
                		
                		/*if (T == 5)
                		begin
                			restu <= 1;
                		end*/
					
				if (T >= 8)
				begin
					T <= 0;	
				end					
			end
		
			//sret
			if (instruction[31:20] == 12'b000100000010)
			begin
				sret <= 0;
				restu <= 0;
				
				if (T == 4)
				begin
					sret <= 1;
				end
				
				if (T == 5)
				begin
				    	restu <= 1;
				end
				
				if (T == 6)
				begin
					T <= 0;
				end
			end
		
			//mret
			if (instruction[31:20] == 12'b001100000010)
			begin
				mret <= 0;
				restu <= 0;
				
				if (T == 4)
				begin
					mret <= 1;
				end
				
				if (T == 5)
				begin
				    	restu <= 1;
				end
				
				if (T == 6)
				begin
					T <= 0;
				end
			end
		
			//wfi
			if (instruction[31:20] == 12'b000100000101)
				if (T == 6)
				begin
					wfi <= 1;
				end
		end		
		
		if (instruction[6:0] == 7'b0000011)
		begin
			//lb
			if (instruction[14:12] == 3'b000)
			begin
				
				
				REG_D <= instruction[11:7];
				REG_A <= instruction[19:15];
				CM_MAR <= { {20{instruction[31]}}, instruction[31:20]};
				sri <= 0;
				srm <= 0;
				mpi <= 0;
				sramrs8 <= 0;
				crm <= 0;
				pc <= 0;
				rpi <= 0;
				
				if (T == 4)
				begin
					srm <= 1;
					smi <= 1;
				end	
				
				if (T == 5)
				begin
					rpi <= 1;
				end
				
				if (T == 7)
				begin
					smi <= 0;
					sramrs8 <= 1;
				end
				
				if (T >= 8)
				begin
					crm <= 1;
					pc <= 1;
					T <= 0;
				end
			end
			
			//lh
			if (instruction[14:12] == 3'b001)
			begin
				
				
				REG_D <= instruction[11:7];
				REG_A <= instruction[19:15];
				CM_MAR <= { {20{instruction[31]}}, instruction[31:20]};
				sri <= 0;
				srm <= 0;
				mpi <= 0;
				sramrs16 <= 0;
				crm <= 0;
				pc <= 0;
				rpi <= 0;
				
				if (T == 4)
				begin
					srm <= 1;
					smi <= 1;
				end	
				
				if (T == 5)
				begin
					rpi <= 1;
				end
				
				if (T == 7)
				begin
					smi <= 0;
					sramrs16 <= 1;
				end
				
				if (T >= 8)
				begin
					crm <= 1;
					pc <= 1;
					T <= 0;
				end
			end
			
			//lw
			if (instruction[14:12] == 3'b010)
			begin
				
				
				REG_D <= instruction[11:7];
				REG_A <= instruction[19:15];
				CM_MAR <= { {20{instruction[31]}}, instruction[31:20]};
				sri <= 0;
				srm <= 0;
				mpi <= 0;
				sramrs32 <= 0;
				crm <= 0;
				pc <= 0;
				rpi <= 0;
				cur <= 0;
				
				if (T == 4)
				begin
					srm <= 1;
					smi <= 1;
				end	
				
				if (T == 5)
				begin
					rpi <= 1;
				end
				
				if (T == 7)
				begin
					smi <= 0;
					sramrs32 <= 1;
				end
				
				if (T >= 8)
				begin
					crm <= 1;
					pc <= 1;
					T <= 0;
				end
			end
			
			//lbu
			if (instruction[14:12] == 3'b100 && CSR_DEV_SEL == 0)
			begin
				
				
				REG_D <= instruction[11:7];
				REG_A <= instruction[19:15];
				CM_MAR <= { {20{instruction[31]}}, instruction[31:20]};
				sri <= 0;
				srm <= 0;
				mpi <= 0;
				sramru8 <= 0;
				crm <= 0;
				pc <= 0;
				rpi <= 0;
				cur <= 0;
								
				if (T == 4)
				begin
					srm <= 1;
					smi <= 1;
				end	
				
				if (T == 5)
				begin
					rpi <= 1;
				end
				
				if (T == 7)
				begin
					smi <= 0;
					sramru8 <= 1;
				end
				
				if (T >= 8)
				begin
					cur <= 1;
				end
				
				if (T >= 9)
				begin
					crm <= 1;
					pc <= 1;
					T <= 0;
				end
			end
			else if (instruction[14:12] == 3'b100 && CSR_DEV_SEL == 1)
			begin
				
				REG_A <= instruction[19:15];
				REG_B <= instruction[11:7];
				sri <= 0;
				srm <= 0;
				srs <= 0;
				crm <= 0;
				pc <= 0;
				rpi <= 0;
				cur <= 0;
				sdrs <= 0;
								
				if (T == 4)
				begin
					srm <= 1;
					srs <= 1;
				end	
				
				if (T == 6)
				begin
				    sdrs <= 1;
				end
				
				if (T == 7)
				begin
				    wfi <= 1;
				end
				
				if (T >= 8)
				begin
					pc <= 1;
					T <= 0;
				end
			end
			
			//lhu
			if (instruction[14:12] == 3'b101)
			begin
				
				
				REG_D <= instruction[11:7];
				REG_A <= instruction[19:15];
				CM_MAR <= { {20{instruction[31]}}, instruction[31:20]};
				sri <= 0;
				srm <= 0;
				mpi <= 0;
				sramrs32 <= 0;
				crm <= 0;
				pc <= 0;
				rpi <= 0;
				
				if (T == 4)
				begin
					srm <= 1;
					smi <= 1;
				end	
				
				if (T == 5)
				begin
					rpi <= 1;
				end
				
				if (T == 7)
				begin
					smi <= 0;
					sramru16 <= 1;
				end
				
				if (T >= 8)
				begin
					crm <= 1;
					pc <= 1;
					T <= 0;
				end
			end
		end
		
		if (instruction[6:0] == 7'b0100011)
		begin
			
			//sb
			if (instruction[14:12] == 3'b000 && CSR_DEV_SEL == 0)
			begin
				
				REG_B <= instruction[24:20];
				REG_A <= instruction[19:15];
				CM_MAR <= { {20{instruction[31]}}, instruction[31:25] , instruction[11:7] };
             	   		srm <= 0;
                		rpi <= 0;
                		srr8 <= 0;
                		pc <= 0;
				crm <= 0;
                		
                		if (T == 4)	
				begin
					crm <= 0;
				end
                
				if (T == 5)
				begin
					srm <= 1;
				end
				
				if (T == 7)
				begin
					smi <= 1;
				end
				
				if (T == 8)	
				begin
					rpi <= 1;
				end
				
				if (T == 9)
				begin
                			smi <= 0;
					srr8 <= 1;
				end
			
				if (T >= 10)
				begin
					T <= 0;
					crm <= 1;
					pc <= 1;
				end
			
			end
			else if (instruction[14:12] == 3'b000 && CSR_DEV_SEL == 1)
			begin
				
				REG_B <= instruction[24:20];
				REG_A <= instruction[19:15];
				CM_MAR <= { {20{instruction[31]}}, instruction[31:25] , instruction[11:7] };
                pc <= 0;
				srm <= 0;
				srs <= 0;
				sdws <= 0;
                		
                if (T == 4)	
				begin
				    srm <= 1;
				    srs <= 1;
				end
                		
                if (T == 6)	
				begin
				    sdws <= 1;
				end
				
				if (T == 7)
				begin
				    wfi <= 1;
				end
			
				if (T >= 8)
				begin
					T <= 0;
					pc <= 1;
				end
			
			end
			
			//sh
			if (instruction[14:12] == 3'b001)
			begin
				
				REG_B <= instruction[24:20];
				REG_A <= instruction[19:15];
				CM_MAR <= { {20{instruction[31]}}, instruction[31:25] , instruction[11:7] };
             	   		srm <= 0;
                		rpi <= 0;
                		srr16 <= 0;
                		pc <= 0;
				crm <= 0;
                		
                		if (T == 4)	
				begin
					crm <= 0;
				end
                
				if (T == 5)
				begin
					srm <= 1;
				end
				
				if (T == 7)
				begin
					smi <= 1;
				end
				
				if (T == 8)	
				begin
					rpi <= 1;
				end
				
				if (T == 9)
				begin
                			smi <= 0;
					srr16 <= 1;
				end
			
				if (T >= 10)
				begin
					T <= 0;
					crm <= 1;
					pc <= 1;
				end
			
			end
			
			//sw
			if (instruction[14:12] == 3'b010)
			begin
				
				REG_B <= instruction[24:20];
				REG_A <= instruction[19:15];
				CM_MAR <= { {20{instruction[31]}}, instruction[31:25] , instruction[11:7] };
             	   		srm <= 0;
                		rpi <= 0;
                		srr32 <= 0;
                		pc <= 0;
				crm <= 0;
                		
                		if (T == 4)	
				begin
					crm <= 0;
				end
                
				if (T == 5)
				begin
					srm <= 1;
				end
				
				if (T == 7)
				begin
					smi <= 1;
				end
				
				if (T == 8)	
				begin
					rpi <= 1;
				end
				
				if (T == 9)
				begin
                			smi <= 0;
					srr32 <= 1;
				end
			
				if (T >= 10)
				begin
					T <= 0;
					crm <= 1;
					pc <= 1;
				end
			
			end
		end
		
		//jal
		if (instruction[6:0] == 7'b1101111)
		begin
		
			REG_D <= instruction[11:7];
			CM_PC <= { instruction[31] , instruction[19:12] , instruction[20] , instruction[30:21] };
			pcpi <= 0;
			spcr <= 0;
			spcrt <= 0;
			scmpc <= 0;
			jalr <= 0;
			pcpi <= 0;
			
			if (T == 4)
			begin
				spcrt <= 1;
				scmpc <= 1;
			end
			
			if (T == 5)
			begin
				spcr <= 1;
			end	

			if (T == 6)
			begin
				pcpi <= 1;
			end
			
			if (T >= 7)
			begin
				T <= 0;
			end
			
		end
		
		//jalr
		if (instruction[6:0] == 7'b1100111)
		begin
			REG_D <= instruction[11:7];
			REG_A <= instruction[19:15];
			CM_PC <= { {20{instruction[31]}} , instruction[31:20] };
			srpc <= 0;
			scmpc <= 0;
			pcpi <= 0;
			spcr <= 0;
			spcrt <= 0;
			jalr <= 1;

			if (T == 4)
			begin
				spcrt <= 1;
			end

			if (T == 5)
			begin
				srpc <= 1;
				scmpc <= 1;
			end
			
			if (T == 6)
			begin
				pcpi <= 1;
			end
			
			if (T == 7)
			begin
				spcr <= 1;
			end
			
			if (T >= 8)
			begin
				T <= 0;
			end
		end
		
		if (instruction[6:0] == 7'b1100011)
		begin
			//beq
			if (instruction[14:12] == 3'b000)
			begin

				REG_A <= instruction[19:15];
				REG_B <= instruction[24:20];
				CM_PC <= { instruction[31] , instruction[7] , instruction[30:25] , instruction[11:8] };
				srab <= 0;
				sraa <= 0;
				pc <= 0;
				
				
				if (T == 4)
				begin
					srab <= 1;
					sraa <= 1;
					ALU_OP <= beq;
				end
				
				if (T == 5)
				begin
					ALU_OP <= 0;
					if (bacm)
					begin
						T <= 0;
					end
					else
					begin
					    pc <= 1;
					    T <= 0;
				    end
				end
				
				if (T >= 6)
					ALU_OP <= 0;
			end
			
			//bne
			if (instruction[14:12] == 3'b001)
			begin

				REG_A <= instruction[19:15];
				REG_B <= instruction[24:20];
				CM_PC <= { instruction[31] , instruction[7] , instruction[30:25] , instruction[11:8] };
				srab <= 0;
				sraa <= 0;
				ALU_OP <= 0;
				pc <= 0;
				
				
				if (T == 4)
				begin
					srab <= 1;
					sraa <= 1;
					ALU_OP <= bneq;
				end
				
				if (T >= 5)
				begin
					ALU_OP <= 0;
					if (bacm)
					begin
						T <= 0;
					end
					else
					begin
					    pc <= 1;
					    T <= 0;
				    end
				end
			end
			
			//blt
			if (instruction[14:12] == 3'b100)
			begin

				REG_A <= instruction[19:15];
				REG_B <= instruction[24:20];
				CM_PC <= { instruction[31] , instruction[7] , instruction[30:25] , instruction[11:8] };
				srab <= 0;
				sraa <= 0;
				ALU_OP <= 0;
				pc <= 0;
				
				
				if (T == 4)
				begin
					srab <= 1;
					sraa <= 1;
					ALU_OP <= blt;
				end
				
				if (T >= 5)
				begin
					ALU_OP <= 0;
					if (bacm)
					begin
						T <= 0;
					end
					else
					begin
					    pc <= 1;
					    T <= 0;
				    end
				end
			end
			
			//bge
			if (instruction[14:12] == 3'b101)
			begin

				REG_A <= instruction[19:15];
				REG_B <= instruction[24:20];
				CM_PC <= { instruction[31] , instruction[7] , instruction[30:25] , instruction[11:8] };
				srab <= 0;
				sraa <= 0;
				ALU_OP <= 0;
				pc <= 0;
				
				
				if (T == 4)
				begin
					srab <= 1;
					sraa <= 1;
					ALU_OP <= bge;
				end
				
				if (T >= 5)
				begin
					ALU_OP <= 0;
					if (bacm)
					begin
						T <= 0;
					end
					else
					begin
					    pc <= 1;
					    T <= 0;
				    end
				end
			end
			
			//bltu
			if (instruction[14:12] == 3'b110)
			begin

				REG_A <= instruction[19:15];
				REG_B <= instruction[24:20];
				CM_PC <= { instruction[31] , instruction[7] , instruction[30:25] , instruction[11:8] };
				srab <= 0;
				sraa <= 0;
				ALU_OP <= 0;
				pc <= 0;
				
				
				if (T == 4)
				begin
					srab <= 1;
					sraa <= 1;
					ALU_OP <= bltu;
				end
				
				if (T >= 5)
				begin
					ALU_OP <= 0;
					if (bacm)
					begin
						T <= 0;
					end
					else
					begin
					    pc <= 1;
					    T <= 0;
				    end
				end
			end
			
			//bgeu
			if (instruction[14:12] == 3'b111)
			begin

				REG_A <= instruction[19:15];
				REG_B <= instruction[24:20];
				CM_PC <= { instruction[31] , instruction[7] , instruction[30:25] , instruction[11:8] };
				srab <= 0;
				sraa <= 0;
				ALU_OP <= 0;
				pc <= 0;
				
				
				if (T == 4)
				begin
					srab <= 1;
					sraa <= 1;
					ALU_OP <= bgeu;
				end
				
				if (T >= 5)
				begin
					ALU_OP <= 0;
					if (bacm)
					begin
						T <= 0;
					end
					else
					begin
					    	pc <= 1;
					    	T <= 0;
				    	end
				end
			end
		end
	end		
end

endmodule
