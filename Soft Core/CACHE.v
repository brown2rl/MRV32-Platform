// first iteration, 6 rightmost bits are 0, next iteration
// cache word = 32 bytes
// inputs: ram, pc, regs
// outputs: ir, ram, mar
// a few hard coded instructions
// states: IDLE, INDEX, RETRIEVE, WRITE_CACHE, FINISH
// cache control bit input
// perifrials and regs are cache_data
 
module cache(clk, scm, spc/*formerly spm*/, sci, lb, lbu, lh, lhu, lw, sb, sh, sw, srr8, srr16, srr32, in_byte, out_byte, out_byte_ready, byte_received, PC_CACHE, REGS_CACHE_DATA, REGS_CACHE_ADDRESS, RAM_CACHE, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT, CACHE_IR, CACHE_RAM, CACHE_MAR, CACHE_REGS, cache_done);

input clk, scm, spc, sci, out_byte_ready, byte_received, srr8, srr16, srr32, lb, lbu, lh, lhu, lw, sb, sh, sw; //indicators, rst, srr8, srr16, srr32, sramrs8, sramrs16, sramrs32, sramru8, sramru16, byte_ready, dev_start_signal, sdevram;
input[7:0] out_byte;
input[31:0] PC_CACHE, REGS_CACHE_ADDRESS, REGS_CACHE_DATA, RAM_CACHE, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT;

output[31:0] CACHE_IR, CACHE_RAM, CACHE_MAR, CACHE_REGS;
output[7:0] in_byte;
output cache_done;

reg[3:0] cache_state, retrieve_state;
reg[31:0] cache_word;
reg[278:0] cache_data[0:511];
reg[278:0] cache_line, new_cache_line;
reg accessed_data, write_data_cache, got_index, decide_data_cache, retrieve_start, ram_write_start, ram_write_done;
reg[4:0] current_index, offset;
reg[7:0] offset_bit;
reg[5:0] cnt;
reg[8:0] cache_index;
reg[1:0] write_state;

localparam
	b = 0,
	h = 1,
	w = 2,
	IDLE = 3,
	ACCESS = 4,
	MISS = 5,
	WRITE_BACK = 6,
	REFILL_LINE = 7,
	RETRIEVE = 8,
	RETRIEVE_WAIT = 9,
	INSTALL_LINE = 10,
	MERGE = 11,
	FINISH = 12;

// icarus and modelsim both require width to be a constant
//wire width = 8; //(8 << ((lb || lbu) ? b : lh || lhu) ? h : w) - 1);
integer i;

initial
	begin
		accessed_data = 1'b0;
		write_data_cache = 1'b0;
		got_index = 1'b0;
		decide_data_cache = 1'b0;
		ram_write_start = 1'b0;
		ram_write_done = 1'b0;
		retrieve_start = 1'b0;
		
		retrieve_start = 1'b0;
		
		write_state = 2'b00;

		retrieve_state = 3'b0;

		for (i = 0; i < 32; i = i + 1)
		begin
			cache_data[i] = 64000'b0;
		end

		cache_line = 64000'b0;
		new_cache_line = 64000'b0;

		cache_index = 9'b0;
		offset = 5'b0;

		cache_word = 32'b0;

		cnt = 8'b0;
		offset_bit = 8'b0;
	end

wire cache_address = spc ? PC_CACHE : REGS_CACHE_ADDRESS;
//byte select logic for stores
wire [3:0] we =
	srr32 ? 4'b1111 :
        srr16 ? (cache_index[1] ? 4'b1100 : 4'b0011) :
        srr8 ? (4'b0001 << cache_index[1:0]) :
        4'b0000;
        
wire [31:0] sb_data = {4{REGS_CACHE_DATA[7:0]}};
wire [31:0] sh_data = {2{REGS_CACHE_DATA[15:0]}};
wire [31:0] sw_data = REGS_CACHE_DATA;
    
wire [31:0] store_data =
        srr8 ? sb_data :
        srr16 ? sh_data :
        srr32 ? sw_data :
        32'b0;
   
wire [7:0] wbase = {cache_index[4:2], 5'b00000};

wire retrieve_done = (retrieve_state == 2 && cnt == 32);

//data_cache access
always @(posedge clk)
begin
	if (cache_state == ACCESS || cache_state == REFILL_LINE)
	begin
		cache_line <= cache_data[cache_index];
		accessed_data <= 1;
	end
	else
	begin
		accessed_data <= 0;
	end


	//writing to data cache

	if (write_data_cache)
	begin
		cache_data[cache_index] <= { 2'b01 , cache_address[31:14] , new_cache_line[255:0] };
	end
	
	if ((srr8 || srr16 || srr32) && cache_state == MERGE)
	begin
		if (we[0]) cache_data[cache_index][wbase +  0 +: 8] <= store_data[7:0];
	        if (we[1]) cache_data[cache_index][wbase +  8 +: 8] <= store_data[15:8];
	        if (we[2]) cache_data[cache_index][wbase +  16 +: 8] <= store_data[23:16];
	        if (we[3]) cache_data[cache_index][wbase +  24 +: 8] <= store_data[31:24];
        end
end

//byte select logic
always @*
begin
	cache_index = cache_address[13:5];
	offset = cache_address[4:0];
	cache_word = cache_line[{offset[4:2], 5'b0} +: 32];

	if (cache_line[273:256] == cache_address[31:14])
	begin
		cache_word = cache_line[{offset[4:2], 5'b0} +: 32];
	end
end

//data cache main fsm
always @(posedge clk)
begin
	if (cache_state == IDLE && decide_data_cache)
	begin
		cache_state <= ACCESS;
	end
	if (cache_state == ACCESS && accessed_data)
	begin
		//Hit or miss?
		if (cache_line[273:256] == cache_address[31:14] && cache_line[274])
		begin
			cache_state <= MERGE;
		end
		else
		begin
			cache_state <= MISS;
		end
	end
	if (cache_state == MISS)
	begin
		//dirty check
		if (cache_line[275])
		begin
			cache_state <= WRITE_BACK;
			ram_write_start <= 1;
			cnt <= 0;
		end
		else
		begin
			cache_state <= REFILL_LINE;
		end
	end
	if (cache_state == WRITE_BACK && ram_write_start)
	begin
		ram_write_start <= 0;
	end
	if (cache_state == WRITE_BACK && ram_write_done)
	begin
		cache_state <= REFILL_LINE;
	end
	if (cache_state == REFILL_LINE)
	begin
		retrieve_start <= 1;
		cache_state <= RETRIEVE_WAIT;	
	end
	if (cache_state == RETRIEVE_WAIT)
	begin
		retrieve_start <= 0;
		cache_state <= INSTALL_LINE;
	end
	if (cache_state == INSTALL_LINE && retrieve_done)
	begin
		cache_line[275:274] <= 2'b01;
		write_data_cache <= 1;
		cache_state <= FINISH;
	end
	if (cache_state == MERGE)
	begin
		cache_state <= FINISH;
	end
	if (cache_state == FINISH)
	begin
		cache_state <= IDLE;
		write_data_cache <= 0;
	end	
end

//RAM retrieve fsm
always @(posedge clk)
begin
	if (retrieve_state == 0 && retrieve_start)
	begin
		retrieve_state <= 1;
		cnt <= 0;
	end
	if (retrieve_state == 1 && out_byte_ready)
	begin
		new_cache_line[(cnt << 3) +: 8] <= out_byte;
		cnt <= cnt + 1;
		retrieve_state <= 2;
	end
	if (retrieve_state == 2)
	begin
		if (cnt == 32)
		begin
			retrieve_state <= 0;
			cnt <= 0;
		end
		else
		begin
			retrieve_state <= 1;
		end
	end	
end

//RAM write fsm
always @(posedge clk)
begin
	if (write_state == 0)
	begin
		ram_write_done <= 0;
	end
	if (write_state == 0 && ram_write_start)
	begin
		in_byte <= cache_line[(cnt << 3) +: 8];
		cnt <= cnt + 1;
		write_state <= 1;
	end
	if (write_state == 1 && byte_received)
	begin
		in_byte <= cache_line[(cnt << 3) +: 8];
		cnt <= cnt + 1;
		write_state <= 2;
	end
	if (write_state == 2)
	begin
		if (cnt == 32)
		begin
			write_state <= 0;
			ram_write_done <= 1;
			cnt <= 0;
		end
		else
		begin
			write_state <= 1;
		end
	end	
end

assign CACHE_MAR = spc ? PC_CACHE : REGS_CACHE_ADDRESS;
assign CACHE_IR = sci ? cache_word : 0;

endmodule