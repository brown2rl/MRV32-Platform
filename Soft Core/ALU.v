module ALU(clk, spca, sraa, srab, scma, scmau, bacm, div_cnt, ALU_OP, REGS_ALU_A, REGS_ALU_B, ALU_REGS, CM_ALU, PC_ALU, ALU_CM);

input clk, spca, sraa, srab, scma, scmau;
input[31:0] REGS_ALU_A, REGS_ALU_B;
input[31:0] CM_ALU, PC_ALU;
input[4:0] ALU_OP;
input[5:0] div_cnt;
output[31:0] ALU_REGS;
output[31:0] ALU_CM;
output reg bacm;
reg[4:0] add, mul, lt, ltu, blt, bge, bgeu, beq, bneq, bltu, XOR, OR, AND, sll, srl, sra, sub, sllr, srlr, srar;
reg[5:0] div_state;
reg[31:0] ALU_A, ALU_B, ALU_D, ALU_D_registered;
reg[63:0] product, quo;
localparam [4:0]
    ALU_ADD  = 5'd1,
    ALU_MUL  = 5'd2,
    ALU_XOR  = 5'd3,
    ALU_OR   = 5'd4,
    ALU_AND  = 5'd5,
    ALU_SLL  = 5'd6,
    ALU_SRL  = 5'd7,
    ALU_SRA  = 5'd8,
    ALU_SUB  = 5'd9,
    ALU_SLLR = 5'd10,
    ALU_SRLR = 5'd11,
    ALU_SRAR = 5'd12,
    ALU_LT   = 5'd13,
    ALU_LTU  = 5'd14,
    ALU_BEQ  = 5'd15,
    ALU_BNE  = 5'd16,
    ALU_BGE  = 5'd17,
    ALU_BGEU = 5'd18,
    ALU_BLT  = 5'd19,
    ALU_BLTU = 5'd20,
    ALU_MULH = 5'd21,
    ALU_MULHSU = 5'd22,
    ALU_MULHU = 5'd23,
    ALU_DIV  = 5'd24,
    ALU_DIVU = 5'd25,
    ALU_REM  = 5'd26,
    ALU_REMU = 5'd27;


initial
begin
    	ALU_A = 0;
    	ALU_B = 0;
    	ALU_D = 0;
    	ALU_D_registered = 0;
    	bacm = 0;
end


always @*
begin
if (sraa)
begin
	ALU_A = REGS_ALU_A;
end
else if (spca)
begin
	ALU_A = PC_ALU;
end
end

always @*
begin
if (srab)
begin
	ALU_B = REGS_ALU_B;
end
else if (scma)
begin
	ALU_B = $signed(CM_ALU);
end
else if (scmau)
	ALU_B = $signed(CM_ALU);
end

always @(*) 
begin
	case (ALU_OP)
	0:
	begin
		ALU_D = ALU_D;
	end
        ALU_ADD:
        begin
		ALU_D = ALU_A + ALU_B;
	end
        ALU_MUL:
        begin
		product = $signed(ALU_A) * $signed(ALU_B);
		ALU_D = product[31:0];
	end
	ALU_MULH:
	begin
		product = $signed(ALU_A) * $signed(ALU_B);
		ALU_D = product[63:32];
	end
	ALU_MULHSU:
	begin
		product = $signed(ALU_A) * $signed({1'b0, ALU_B});;
		ALU_D = product[63:32];
	end
	ALU_MULHU:
	begin
		product = ALU_A * ALU_B;
		ALU_D = product[63:32];
	end
	ALU_DIVU:
	begin
		ALU_D = quo[31:0];
	end
	ALU_DIV:
	begin
		ALU_D = signed_quotient[31:0];
	end
	ALU_REMU:
	begin
		ALU_D = quo[63:32];
	end
	ALU_REM:
	begin
		ALU_D = signed_remainder[31:0];
	end
	ALU_XOR:
	begin
		ALU_D = ALU_A ^ ALU_B;
	end
	ALU_OR:
	begin
		ALU_D = ALU_A | ALU_B;
	end
	ALU_AND:
	begin
		ALU_D = ALU_A & ALU_B;
	end
	ALU_SLL:
	begin
		ALU_D = ALU_A << ALU_B;
	end
	ALU_SRL:
	begin
		ALU_D = ALU_A >> ALU_B;
	end
	ALU_SRA:
	begin
		ALU_D = $signed(ALU_A) >>> ALU_B;
	end
	ALU_SUB:
	begin
		ALU_D = ALU_A - ALU_B;
	end
	ALU_SRLR:
	begin
		ALU_D = ALU_A >> ALU_B[4:0];
	end
	ALU_SRAR:
	begin
		ALU_D = ALU_A >>> ALU_B[4:0];
	end
	ALU_LT:
	begin
		ALU_D = $signed(ALU_A) < $signed(ALU_B);
	end
	ALU_LTU:
	begin
		ALU_D = ALU_A < ALU_B;
	end
        default: ALU_D = 0; 
endcase
end

always @(*)
begin
bacm = 0;
case(ALU_OP)
	0:
	begin
		bacm = 0;
	end
	ALU_BEQ:
	if (ALU_A == ALU_B)
	begin
		bacm = 1;
	end
	ALU_BNE:
    	if (ALU_A != ALU_B)
	begin
		bacm = 1;
	end
	ALU_BGE:
    	if ($signed(ALU_A) >= $signed(ALU_B))
	begin
		bacm = 1;
	end
	ALU_BGEU:
    	if (ALU_A >= ALU_B)
	begin
		bacm = 1;
	end
    	ALU_BLT:
	if ($signed(ALU_A) < $signed(ALU_B))
	begin
		bacm = 1;
	end
	ALU_BLTU:
    	if (ALU_A < ALU_B)
	begin
    		bacm = 1;
	end
        default: bacm = 0;
endcase
end

reg [63:0] next_quo;
reg [31:0] divisor;
reg sign_q;
reg sign_r;
reg [31:0] abs_a;
reg [31:0] abs_b;
wire a_neg = ALU_A[31];
wire b_neg = ALU_B[31];
reg [31:0] q_unsigned;
reg [31:0] r_unsigned;
reg [31:0] signed_quotient;
reg [31:0] signed_remainder;
reg [31:0] rem;

always @*
begin
	sign_q = a_neg ^ b_neg;
	sign_r = a_neg;    
	abs_a = a_neg ? (~ALU_A + 1) : ALU_A;
	abs_b = b_neg ? (~ALU_B + 1) : ALU_B;
	q_unsigned = quo[31:0];
	r_unsigned = quo[63:32];
	signed_quotient  = sign_q ? (~q_unsigned + 1) : q_unsigned;
	signed_remainder = sign_r ? (~r_unsigned + 1) : r_unsigned;
end


always @(posedge clk) 
begin
	if ((ALU_OP == ALU_DIV || ALU_OP == ALU_DIVU || ALU_OP == ALU_REM || ALU_OP == ALU_REMU) && !ALU_B)
	begin
		quo[31:0] <= 32'hFFFFFFFF;
		quo[63:32] <= ALU_A;
	end
	else if ((ALU_OP == ALU_DIV || ALU_OP == ALU_REM) && ALU_A == 32'h80000000 && ALU_B == 32'hFFFFFFFF)
	begin
		quo[31:0] <= 32'h80000000;
		quo[63:32] <= 0;
	end
	else if ((ALU_OP == ALU_DIV || ALU_OP == ALU_DIVU || ALU_OP == ALU_REM || ALU_OP == ALU_REMU) && ALU_B) 
	begin
	       	if (div_state == 0) 
	       	begin
	       		if ((ALU_OP == ALU_DIV) || (ALU_OP == ALU_REM))
	        	begin
	        		quo <= {32'b0, abs_a};
	        		divisor <= abs_b;
	        	end
	        	else if ((ALU_OP == ALU_DIVU) || (ALU_OP == ALU_REMU))
	        	begin
	        		quo <= ALU_A;
	        		divisor <= ALU_B;
	        	end
	            	div_state <= 1;
	      	end


		else if (div_state <= 32) 
		begin
	    		next_quo = quo << 1;             
	    		if (next_quo[63:32] >= divisor) 
   	 		begin
       	 			next_quo[63:32] = next_quo[63:32] - divisor;  
       		 		next_quo[0] = 1;
    			end 	
    			else 
    			begin
   		     		next_quo[0] = 0;
    			end
   	 		quo <= next_quo;  
    			div_state <= div_state + 1;
		end
       		else if (div_state == 33)
        	begin
        	    	div_state <= 0;
       		end
       	end
       	else
       	begin
       		div_state <= 0;
       	end
end


always @(posedge clk)
begin
    ALU_D_registered <= ALU_D;
end

assign ALU_REGS = ALU_D_registered;
assign ALU_CM = ALU_D_registered;

endmodule
