module CACHE(clk, spc/*formerly spm*/, ddc, sci, busy_w, srr8, srr16, srr32, lb, lbu, lh, lhu, ram_write_start, in_bytes, retrieve_start,
 out_bytes, out_bytes_ready, bytes_received, sdevbit, dev_stop_signal, dev_start_signal, sdevcache, qspi_address, 
address_progression, cachecontin, cachecontout, CM_CACHE, PC_CACHE, REGS_CACHE_DATA, REGS_CACHE_ADDRESS, CSR_DEV_BUS_IN,
 CSR_DEV_BUS_OUT, CACHE_IR, CACHE_REGS, cache_done);

input clk, spc, sci, ddc, out_bytes_ready, bytes_received, dev_start_signal, 
sdevcache, busy_w, srr8, srr16, srr32, lb, lbu, lh, lhu;
input[7:0] out_bytes, cachecontout;
input[31:0] PC_CACHE, REGS_CACHE_ADDRESS, REGS_CACHE_DATA, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT, CM_CACHE;

output[31:0] CACHE_IR, CACHE_REGS;
output cache_done;
output reg retrieve_start;
output reg ram_write_start, dev_stop_signal, sdevbit, address_progression;
output reg[7:0] cachecontin;
output[7:0] in_bytes;
output [24:0] qspi_address;

// ---------------------------------------------------------
// Cache FSM
// ---------------------------------------------------------

reg [3:0] cache_state;

// ---------------------------------------------------------
// Cache control
// ---------------------------------------------------------

reg accessed_data;
reg ram_write_done;

// ---------------------------------------------------------
// Refill path
// ---------------------------------------------------------

reg [31:0] fill_word;
reg [2:0]  fill_word_ptr;
reg [1:0]  fill_bits;
reg         fill_we;
reg         filling;

// ---------------------------------------------------------
// Write-back path
// ---------------------------------------------------------

reg [2:0]  wb_word;
reg [1:0]  wb_bits;
reg [2:0]  write_state;
reg [31:0] wb_shift;

// ---------------------------------------------------------
// Tag/address latches w/ RAM output reg
// ---------------------------------------------------------

reg [17:0] tag_r;
reg [8:0]  idx_r;
reg [2:0]  word_r;
reg [1:0]  bits_r;
reg [17:0] victim_tag;
reg [511:0] valid;
reg [511:0] dirty;
reg [17:0] tag_do;
reg valid_do, dirty_do, refill_done;
reg [31:0] dram_do;
(* ram_style = "block" *) reg [17:0] tag_ram [0:511];
(* ram_style = "block" *) reg [31:0] data_ram [0:4095];

localparam
	IDLE = 3,
	ACCESS = 4,
	MISS = 5,
	WRITE_BACK = 6,
	REFILL_LINE = 7,
	RETRIEVE_WAIT = 9,
	INSTALL_LINE = 10,
	ACCESS2 = 12,
	MERGE = 11,
	FINISH = 14;

integer k;

initial
begin
	cache_state      = IDLE;
    	retrieve_start   = 1'b0;
    	ram_write_start  = 1'b0;
	accessed_data = 1'b0;
    	ram_write_done   = 1'b0;
    	write_state      = 3'd0;
    	fill_word     = 32'd0;
    	fill_word_ptr = 3'd0;
    	fill_bits     = 2'd0;
    	fill_we       = 1'b0;
    	filling       = 1'b0;
    	for (k = 0; k < 512; k = k + 1)
    		tag_ram[k] = 18'd0;
	for (k = 0; k < 4096; k = k + 1)
		data_ram[k] = 32'd0;
    	valid    = 512'd0;
    	dirty    = 512'd0;
    	tag_do   = 18'd0;
    	valid_do = 1'b0;
    	dirty_do = 1'b0;
    	wb_word  = 3'd0;
    	wb_bits  = 2'd0;
    	wb_shift = 32'd0;
	tag_r = 18'd0;
	idx_r = 9'd0;
	word_r = 3'd0;
	refill_done = 1'b0;
	dram_do = 32'd0;
	bits_r = 2'd0;
	victim_tag = 18'd0;
end

wire wb_owns  = (cache_state == WRITE_BACK);
wire [31:0] wb_address   = { victim_tag, idx_r, 5'b00000 };
wire [31:0] fill_address = { tag_r,      idx_r, 5'b00000 };
wire hit = valid_do && (tag_do == tag_r);
wire [31:0] cache_address = spc ? PC_CACHE : REGS_CACHE_ADDRESS + CM_CACHE;
wire [17:0] req_tag  = cache_address[31:14];
wire [8:0]  req_idx  = cache_address[13:5];
wire [2:0]  req_word = cache_address[4:2];
wire [1:0]  req_bits = cache_address[1:0];
wire [3:0] we = srr32 ? 4'b1111 :
                    srr16 ? (bits_r[1] ? 4'b1100 : 4'b0011) :
                    srr8  ? (4'b0001 << bits_r[1:0]) :
                            4'b0000;
wire [31:0] store_data = srr8  ? {4{REGS_CACHE_DATA[7:0]}}  :
                    srr16 ? {2{REGS_CACHE_DATA[15:0]}} :
                    srr32 ?    REGS_CACHE_DATA         :
                                        32'b0;
wire tag_we = (cache_state == INSTALL_LINE) && refill_done;
wire cpu_owns = (cache_state == ACCESS) || (cache_state == MERGE);
wire [2:0] ram_word = cpu_owns ? word_r  : wb_owns  ? wb_word : fill_word_ptr;
wire [8:0]  ram_idx = idx_r;
wire [11:0] dram_a  = { ram_idx, ram_word };
wire cpu_wr  = (cache_state == MERGE);
wire [3:0]  dram_we = cpu_wr ? we : (fill_we ? 4'b1111 : 4'b0000);
wire [31:0] dram_di = cpu_wr ? store_data : fill_word;
wire dram_re = cpu_owns || wb_owns || (cache_state == RETRIEVE_WAIT);
wire [31:0] load_word = dram_do >> {bits_r,3'b000};
wire store_req = |we;

always @*
begin
        sdevbit            = 1'b0;
        dev_stop_signal     = 1'b0;
        address_progression = 1'b0;
        cachecontin           = 8'b0;

        if (CSR_DEV_BUS_IN == 32'd1 && CSR_DEV_BUS_OUT == 32'd2)
        begin
            cachecontin[0] = dev_start_signal;
        end
        if (CSR_DEV_BUS_IN == 32'd1 && CSR_DEV_BUS_OUT == 32'd2)
        begin
            dev_stop_signal = cachecontout[0];
        end
        if (CSR_DEV_BUS_IN == 32'd2 && CSR_DEV_BUS_OUT == 32'd1)
        begin
            sdevbit = sdevcache;
        end
        if (CSR_DEV_BUS_IN == 32'd2 && CSR_DEV_BUS_OUT == 32'd1)
        begin
            cachecontin[0] = sdevcache;
        end
        if ((CSR_DEV_BUS_IN == 32'd1 && CSR_DEV_BUS_OUT == 32'd3) || (CSR_DEV_BUS_IN == 32'd3 && CSR_DEV_BUS_OUT == 32'd1))
        begin
            cachecontin[0] = dev_start_signal;
        end
        if ((CSR_DEV_BUS_IN == 32'd1 && CSR_DEV_BUS_OUT == 32'd3) || (CSR_DEV_BUS_IN == 32'd3 && CSR_DEV_BUS_OUT == 32'd1))
        begin
            address_progression = cachecontout[0];
            dev_stop_signal     = cachecontout[1];
        end
        if (CSR_DEV_BUS_IN == 32'd3 && CSR_DEV_BUS_OUT == 32'd1)
        begin
            sdevbit = cachecontout[0];
        end
end
    
    // Latched once per transaction. The index and tag must survive the whole
    // miss sequence, so nothing downstream depends on the CPU holding the
    // address stable across a refill.

always @(posedge clk)
        if (cache_state == IDLE && ddc)
        begin
            tag_r  <= req_tag;
            idx_r  <= req_idx;
            word_r <= req_word;
            bits_r <= req_bits;
        end

    // ------------------------------------------------- port arbitration
    // The FSM is strictly sequential: the CPU, the refill engine and the
    // write-back engine never touch the arrays in the same cycle. So one
    // port is enough and the only thing that needs muxing is the word
    // select within the line -- the index is constant for the whole
    // transaction. (Go true dual-port if you later want hit-under-miss.)
    // ------------------------------------------------------- tag array
    // The new tag is committed at the end of the refill.

always @(posedge clk)
    begin
        if (tag_we)
            tag_ram[ram_idx] <= tag_r;

        tag_do   <= tag_ram[ram_idx];      // 1-cycle latency, same as data
        valid_do <= valid[ram_idx];
        dirty_do <= dirty[ram_idx];
    end

    always @(posedge clk)
    begin
        if (tag_we)
        begin
            valid[ram_idx] <= 1'b1;
            dirty[ram_idx] <= 1'b0;        // freshly filled line is clean
        end
        else if (cache_state == MERGE && |we)
            dirty[ram_idx] <= 1'b1;        // a store just landed
    end

    always @(posedge clk)
        if (cache_state == MISS)
            victim_tag <= tag_do;    

//writing to data cache
// refill engine has a complete word

always @(posedge clk)
begin
        if (dram_we[0]) data_ram[dram_a][ 7: 0] <= dram_di[ 7: 0];
        if (dram_we[1]) data_ram[dram_a][15: 8] <= dram_di[15: 8];
        if (dram_we[2]) data_ram[dram_a][23:16] <= dram_di[23:16];
        if (dram_we[3]) data_ram[dram_a][31:24] <= dram_di[31:24];
	if (dram_re) dram_do <= data_ram[dram_a];       
end

always @(posedge clk)
    accessed_data <= (cache_state == ACCESS);

//data cache main fsm
always @(posedge clk)
begin
	if (cache_state == IDLE && ddc && !busy_w)
	begin
		cache_state <= ACCESS;
	end
	if (cache_state == ACCESS && accessed_data)
	begin
		cache_state <= hit ? (store_req ? MERGE : FINISH) : MISS;
	end
	if (cache_state == MISS)
	begin
		//dirty check
    		if (dirty_do)
    		begin
        		cache_state     <= WRITE_BACK;
        		ram_write_start <= 1;
    		end
   	 	else
        		cache_state <= REFILL_LINE;
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
		refill_done <= 1'b0;
	end
	else if (fill_we && (fill_word_ptr == 3'd7))
	begin
		refill_done <= 1'b1;
	end	
	if (cache_state == RETRIEVE_WAIT)
	begin
		retrieve_start <= 0;
		cache_state <= INSTALL_LINE;
	end
	if (cache_state == INSTALL_LINE && refill_done)
	begin
		cache_state <= ACCESS2;
	end
	if (cache_state == MERGE)
	begin
		cache_state <= FINISH;
	end
	if (cache_state == ACCESS2)
	begin
		cache_state <= ACCESS;
	end		
	if (cache_state == FINISH)
	begin
		cache_state <= IDLE;
	end	
end

always @(posedge clk)
	begin
        	fill_we <= 1'b0;

        if (cache_state == REFILL_LINE)
        begin
            fill_word_ptr <= 3'd0;
            fill_bits    <= 2'd0;
            filling       <= 1'b1;
        end

        if (filling && out_bytes_ready)
        begin
            case (fill_bits)
                2'd0 : fill_word[ 7: 0] <= out_bytes;
                2'd1 : fill_word[15: 8] <= out_bytes;
                2'd2 : fill_word[23:16] <= out_bytes;
                2'd3 : fill_word[31:24] <= out_bytes;
            endcase

            fill_bits <= fill_bits + 2'd1;

            if (fill_bits == 2'd3)
                fill_we <= 1'b1;           // word complete, write it next cycle
        end

        // fill_we is high for exactly the cycle in which the write happens,
        // so the pointer advances at the end of that cycle.
        if (fill_we)
        begin
            if (fill_word_ptr == 3'd7)
                filling <= 1'b0;
            fill_word_ptr <= fill_word_ptr + 3'd1;
        end
end

//RAM write fsm

    // change the port: output [7:0] in_bytes;  (no longer a reg)
    

always @(posedge clk)
    begin
        ram_write_done <= 1'b0;

        case (write_state)

        3'd0 : if (ram_write_start)
               begin
                   wb_word     <= 3'd0;
                   wb_bits     <= 2'd0;
                   write_state <= 3'd1;
               end

        3'd1 : begin
                   wb_word     <= 3'd1;        // word 0 read this cycle, prefetch 1
                   write_state <= 3'd2;
               end

        3'd2 : begin
                   wb_shift    <= dram_do;     // word 0 latched
                   write_state <= 3'd3;
               end

        3'd3 : if (bytes_received)
               begin
                   if (wb_bits == 2'd3)
                   begin
                       wb_bits <= 2'd0;
                       if (wb_word == 3'd0)        // wrapped past word 7
                       begin
                           ram_write_done <= 1'b1;
                           write_state    <= 3'd0;
                       end
                       else
                       begin
                           wb_shift <= dram_do;    // already prefetched
                           wb_word  <= wb_word + 3'd1;
                       end
                   end
                   else
                   begin
                       wb_shift <= { 8'h00, wb_shift[31:8] };
                       wb_bits  <= wb_bits + 2'd1;
                   end
               end

        default : write_state <= 3'd0;
        endcase
end

assign qspi_address = wb_owns ? wb_address : fill_address;
assign cache_done = (cache_state == FINISH);
assign in_bytes = wb_shift[7:0];
assign CACHE_REGS =
    lb  ? {{24{load_word[7]}},  load_word[7:0]}  :
    lbu ? {24'b0,              load_word[7:0]}  :
    lh  ? {{16{load_word[15]}}, load_word[15:0]} :
    lhu ? {16'b0,              load_word[15:0]} :
           load_word;
assign CACHE_IR   = sci ? dram_do : 32'b0;   // fetches are word-aligned
    
endmodule
