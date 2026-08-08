// first iteration, 6 rightmost bits are 0, next iteration
// cache word = 32 bytes
// inputs: ram, pc, regs
// outputs: ir, ram, mar
// a few hard coded instructions
// states: IDLE, INDEX, RETRIEVE, WRITE_CACHE, FINISH
// cache control bit input
// perifrials and regs are cache_data
 
module cache(clk, scm, spm, PC_CACHE, REGS_CACHE, RAM_CACHE, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT, CACHE_IR, CACHE_RAM, CACHE_MAR, CACHE_REGS, out_byte, out_byte_ready, lb, lbu, lh, lhu, retrieve_start, retrieve_finished);

input clk, scm, spm, out_byte_ready, lb, lbu, lh, lhu;
input[7:0] out_byte;
input[31:0] PC_CACHE, REGS_CACHE, RAM_CACHE, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT;

output[31:0] CACHE_IR, CACHE_RAM, CACHE_MAR, CACHE_REGS;
output retrieve_start, retrieve_finished;

reg[31:0] mar_address, cache_word, cache_data_out;
reg[64000:0] cache_data[0:31]; // data reg -> 0-10: mar, 11-19: regs, 20-30: pc; instruction reg -> 0-16: pc, 17-31: ram
reg[64000:0] cache_data_line, new_cache_line; //32 bytes, tag (277:256), consider 64 bytes (256+278) wide
reg accessed_data, write_data_cache, got_index, decide_data_cache, retrieve_state, retrieve_start, retrieve_finished;
reg[4:0] current_index, cache_index, offset;
reg[7:0] offset_bit, cnt;
reg[3:0] data_cache_state;

localparam
	b = 0,
	h = 1,
	w = 2,
	IDLE = 3,
	INDEX = 4,
	RETRIEVE = 5,
	WRITE_CACHE = 6,
	FINISH = 7,
	ACCESS = 8,
	width = 8;

// icarus and modelsim both require width to be a constant
//wire width = 8; //(8 << ((lb || lbu) ? b : (lh || lhu) ? h : w) - 1);
integer i;

initial
	begin
		accessed_data = 1'b0;
		write_data_cache = 1'b0;
		got_index = 1'b0;
		decide_data_cache = 1'b0;
		retrieve_state = 1'b0;

		for (i = 0; i < 32; i = i + 1)
		begin
			cache_data[i] = 64000'b0;
		end

		cache_data_line = 64000'b0;
		new_cache_line = 64000'b0;

		cache_index = 5;
		offset = 5;

		mar_address = 32'b0;
		cache_word = 32'b0;
		cache_data_out = 32'b0;

		cnt = 8'b0;
		offset_bit = 8'b0;

		data_cache_state = 4'b0;

		retrieve_start = 1'b0;
		retrieve_finished = 1'b0;
	end

//data_cache access
always @(posedge clk)
begin
	if (data_cache_state == ACCESS)
	begin
		cache_data_line <= cache_data[cache_index];
		accessed_data <= 1;
	end
	else
	begin
		accessed_data <= 0;
	end
end

//writing to data cache
always @(posedge clk)
begin
	if (write_data_cache)
	begin
		cache_data[cache_index] <= { 1'b1 , PC_CACHE[31:10] , new_cache_line[255:0] };
	end
end


always @*
begin
	if (data_cache_state == RETRIEVE)
	begin
		retrieve_start = 1;
	end

	if (retrieve_state == 2 && cnt == 32)
	begin
		retrieve_finished = 1;
	end

	cache_index = PC_CACHE[9:5];

	//byte select logic
	offset = PC_CACHE[4:0];
	offset_bit[7:0] = offset[4:0] << 3;
	
	
	if (cache_data_line[277:256] == PC_CACHE[31:10])
	begin
		cache_word = cache_data_line[offset_bit +: 32];
	end

	cache_word = cache_data_line[{offset[4:2], 5'b0} +: 32];

	cache_data_out = cache_word[0 +: width];

end

//data cache decision fsm
always @(posedge clk)
begin
	if (data_cache_state == IDLE && decide_data_cache)
	begin
		data_cache_state <= ACCESS;
	end
	if (data_cache_state == ACCESS && accessed_data)
	begin
		if (cache_data_line[277:256] == PC_CACHE[31:10] && cache_data_line[278])
		begin
			data_cache_state <= FINISH;
		end
		else
		begin
			data_cache_state <= RETRIEVE;
		end
	end
	if (data_cache_state == RETRIEVE)
	begin
		data_cache_state <= WRITE_CACHE;
	end
	if (data_cache_state == WRITE_CACHE && retrieve_finished)
	begin
		data_cache_state <= FINISH;
		write_data_cache <= 1;
	end
	if (data_cache_state == FINISH)
	begin
		data_cache_state <= IDLE;
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

assign CACHE_MAR = mar_address;
assign CACHE_IR = cache_data_out;

endmodule