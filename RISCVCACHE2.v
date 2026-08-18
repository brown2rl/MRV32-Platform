//start cache fsm after adding immediate
`timescale 1ns/1ps
module CACHE(clk, spc/*formerly spm*/, ddc, sci, busy_w, srr8, srr16, srr32, sramrs8, sramrs16, sramrs32, sramru8, sramru16, ram_write_start, in_byte, retrieve_start, out_byte, out_byte_ready, byte_received, sdevbyte, dev_stop_signal, dev_start_signal, scachedev, sdevcache, qspi_address, address_progression, cachecontin, cachecontout, sdrd, CM_CACHE, PC_CACHE, REGS_CACHE_DATA, REGS_CACHE_ADDRESS, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT, CACHE_IR, CACHE_MAR, CACHE_REGS, CACHE_DEV, DEV_CACHE, cache_done, ready_state, rst, rom_sel, cao);

input clk, spc, sci, ddc, out_byte_ready, byte_received, dev_start_signal, sdevcache, scachedev, busy_w, srr8, srr16, srr32, sramrs8, sramrs16, sramrs32, sramru8, sramru16, ready_state, rst;
input[7:0] out_byte, cachecontout;
input[31:0] PC_CACHE, REGS_CACHE_ADDRESS, REGS_CACHE_DATA, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT, CM_CACHE, DEV_CACHE;

output[31:0] CACHE_MAR, CACHE_REGS;
output cache_done;
output reg retrieve_start;
output reg ram_write_start, dev_stop_signal, sdevbyte, sdrd, address_progression;
output reg[7:0] cachecontin;
output[7:0] in_byte;
output [24:0] qspi_address;
output reg[7:0] CACHE_DEV;
output reg[31:0] CACHE_IR;

reg[31:0] mar_address, cache_word, word, data_out;
reg[3:0] ram_full_state, pc_state, pc_full_state, regs_state, regs_full_state, ir_state, ir_full_state, mar_state, mar_full_state, bus_state, bus_full_state, current_state, next_state, cache_state, ram_write_done, write_state;
reg cd, ci, accessed_data, got_index, ssddev, sd_read_txfer_busy;
reg[4:0] current_index, offset;
reg[7:0] offset_bit;
reg[8:0] cache_index, address_addon;
wire [29:0] rom_idx = cache_address[31:2] - 30'd17000000;

integer i;
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
	ACCESS2 = 12,
	ACCESS2_DONE = 13,
	FINISH = 14;	

initial
	begin
		cd = 0;
		ci = 0;
		ram_full_state = 4'b0011;
		pc_state = 4'b0100;
		pc_full_state = 4'b0101;
		regs_state = 4'b0110;
		regs_full_state = 4'b0111;
		ir_state = 4'b1000;
		ir_full_state = 4'b1001;
		mar_state = 4'b1010;
		mar_full_state = 4'b1011;
		bus_state = 4'b1100;
		bus_full_state = 4'b1101;
		cache_index = 4'b0;
		offset = 4'b0;
		current_index = 5'b0;
		cache_state = IDLE;      
		write_state = 0;    
		retrieve_start = 0;    
		ram_write_start = 0;     
		ram_write_done = 0;      
		accessed_data = 0;   
		address_addon = 0;  
		address_progression = 0;
		sd_read_txfer_busy = 0;
		tag_r = 0; 
		idx_r = 0; 
		word_r = 0;
		byte_r = 0;
		rom_sel = 0;
		sdrd = 0;
	end


	
	
    always @*
    begin
    	ssddev		    = 1'b0;
    	sdrd		    = 1'b0;
        sdevbyte            = 1'b0;
        dev_stop_signal     = 1'b0;
        address_progression = 1'b0;
        cachecontin           = 8'b0;
        if (CSR_DEV_BUS_IN == 1 && CSR_DEV_BUS_OUT == 2)
        begin
            cachecontin[0] = dev_start_signal;
        end
        if (CSR_DEV_BUS_IN == 1 && CSR_DEV_BUS_OUT == 2)
        begin
            dev_stop_signal = cachecontout[0];
        end
        if (CSR_DEV_BUS_IN == 2 && CSR_DEV_BUS_OUT == 1)
        begin
            sdevbyte = sdevcache;
        end
        if (CSR_DEV_BUS_IN == 2 && CSR_DEV_BUS_OUT == 1)
        begin
            cachecontin[0] = sdevcache;
        end    
        
        if (CSR_DEV_BUS_IN == 1 && CSR_DEV_BUS_OUT == 3)
        begin
            cachecontin[0] = dev_start_signal;
        end
        if (CSR_DEV_BUS_IN == 1 && CSR_DEV_BUS_OUT == 3)
        begin
            address_progression = cachecontout[0];
            dev_stop_signal     = cachecontout[1];
        end
        
        
        if (CSR_DEV_BUS_IN == 3 && CSR_DEV_BUS_OUT == 1)
        begin
        	cachecontin[0] = dev_start_signal;
        	cachecontin[1] = byte_stored;
        end
        if (CSR_DEV_BUS_IN == 3 && CSR_DEV_BUS_OUT == 1)
        begin
            	sdevbyte = cachecontout[0];
            	address_progression = cachecontout[1];
            	sdrd = cachecontout[2];
            	sd_read_txfer_busy = cachecontout[3];
        end
    end
    
    wire  byte_stored = (cache_state == FINISH);
    
    always @(posedge clk)
    begin
    	if (CSR_DEV_BUS_IN == 1 && CSR_DEV_BUS_OUT == 2)
    	begin
    		CACHE_DEV <= CACHE_REGS[7:0];
    	end
    end    
    
    
    always @(posedge clk)
    begin
    	if (sdrd)
    		address_addon <= 0;
    	else if (address_progression)
    		address_addon <= address_addon + 1;
    end  
    
	assign qspi_address = wb_owns ? wb_address : fill_address;

    wire [31:0] cache_address = spc ? PC_CACHE : (REGS_CACHE_ADDRESS + CM_CACHE + address_addon);
    output[31:0] cao;
    assign cao = cache_address;
    assign PC = cache_address[31:0];

    wire [17:0] req_tag  = cache_address[31:14];
    wire [8:0]  req_idx  = cache_address[13:5];
    wire [2:0]  req_word = cache_address[4:2];
    wire [1:0]  req_byte = cache_address[1:0];

    // Latched once per transaction. The index and tag must survive the whole
    // miss sequence, so nothing downstream depends on the CPU holding the
    // address stable across a refill.
    reg [17:0] tag_r;
    reg [8:0]  idx_r;
    reg [2:0]  word_r;
    reg [1:0]  byte_r;

    always @(posedge clk)
        if (cache_state == IDLE && (ddc || ssddev || sdevbyte))
        begin
            tag_r  <= req_tag;
            idx_r  <= req_idx;
            word_r <= req_word;
            byte_r <= req_byte;
        end


    // ------------------------------------------------- port arbitration
    // The FSM is strictly sequential: the CPU, the refill engine and the
    // write-back engine never touch the arrays in the same cycle. So one
    // port is enough and the only thing that needs muxing is the word
    // select within the line -- the index is constant for the whole
    // transaction. (Go true dual-port if you later want hit-under-miss.)
    reg [2:0] fill_word_ptr;   // refill  : which word of the line
    reg [2:0] wb_word;         // evict   : which word of the line

    wire cpu_owns = (cache_state == ACCESS) || (cache_state == MERGE);
    wire wb_owns  = (cache_state == WRITE_BACK);

    wire [2:0] ram_word = cpu_owns ? word_r  :
                          wb_owns  ? wb_word :
                                     fill_word_ptr;

    wire [8:0]  ram_idx = idx_r;
    wire [11:0] dram_a  = { ram_idx, ram_word };

    // ------------------------------------------------------- tag array
    (* ram_style = "block" *) reg [17:0] tag_ram [0:511];
    reg [511:0] valid;
    reg [511:0] dirty;

    reg [17:0] tag_do;
    reg        valid_do;
    reg        dirty_do;

    // The new tag is committed at the end of the refill.
    wire tag_we = (cache_state == INSTALL_LINE) && retrieve_done;

    integer k;
    initial
    begin
        for (k = 0; k < 512; k = k + 1)
        begin
            tag_ram[k] = 18'd0;        
	end 
        valid    = 512'd0;
        dirty    = 512'd0;
        tag_do   = 18'd0;
        valid_do = 1'b0;
        dirty_do = 1'b0;
    end

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
        if (rst)
        begin
            valid <= 512'd0;
            dirty <= 512'd0;
        end
        else if (tag_we)
        begin
            valid[ram_idx] <= 1'b1;
            dirty[ram_idx] <= 1'b0;        // freshly filled line is clean
        end
        else if (cache_state == MERGE && |we)
            dirty[ram_idx] <= 1'b1;        // a store just landed
    end

    wire hit = valid_do && (tag_do == tag_r);

    reg [17:0] victim_tag;
    always @(posedge clk)
        if (cache_state == MISS)
            victim_tag <= tag_do;

    wire [31:0] wb_address   = { victim_tag, idx_r, 5'b00000 };
    wire [31:0] fill_address = { tag_r,      idx_r, 5'b00000 };

//writing to data cache

    (* ram_style = "block" *) reg [31:0] data_ram [0:4095];
    integer j;
    
    initial
    begin
    for (j = 0; j < 4096; j = j + 1)
    begin
    	data_ram[j] = 0;
    end
    end
    reg [31:0] dram_do;

    reg        fill_we;        // refill engine has a complete word
    reg [31:0] fill_word;

    wire        cpu_wr  = (cache_state == MERGE);
    wire [3:0]  dram_we = cpu_wr ? we : (fill_we ? 4'b1111 : 4'b0000);
    wire [31:0] dram_di = cpu_wr ? store_data : fill_word;
    wire dram_re = cpu_owns || wb_owns || (cache_state == RETRIEVE_WAIT);

    always @(posedge clk)
    begin
        if (dram_we[0]) data_ram[dram_a][ 7: 0] <= dram_di[ 7: 0];
        if (dram_we[1]) data_ram[dram_a][15: 8] <= dram_di[15: 8];
        if (dram_we[2]) data_ram[dram_a][23:16] <= dram_di[23:16];
        if (dram_we[3]) data_ram[dram_a][31:24] <= dram_di[31:24];
        if (dram_re) dram_do <= data_ram[dram_a];
        
    end


//byte select logic for stores
    wire [3:0] we = srr32 ? 4'b1111 :
                    srr16 ? (byte_r[1] ? 4'b1100 : 4'b0011) :
                    srr8  ? (4'b0001 << byte_r[1:0]) :
                    sdevbyte  ? (4'b0001 << byte_r[1:0]) :
                            4'b0000;

    wire [31:0] store_data = sdevbyte ? {4{DEV_CACHE[7:0]}}  :
    			     srr8  ? {4{REGS_CACHE_DATA[7:0]}}  :
                             srr16 ? {2{REGS_CACHE_DATA[15:0]}} :
                             srr32 ?    REGS_CACHE_DATA         :
                                        32'b0;


// FIX: (cnt_r<<3) and (cnt_w<<3) are self-determined expressions whose width
// is that of the 6-bit counter, so the byte index wrapped every 8 bytes.
// Widen the shift to 9 bits before using it as a part-select base.

wire retrieve_done = fill_we && (fill_word_ptr == 3'd7);

assign cache_done = sd_read_txfer_busy ? 0 : (cache_state == FINISH);

always @(posedge clk)
    accessed_data <= !rst && (cache_state == ACCESS);

//data cache main fsm
always @(posedge clk)
begin
	if (rst)
	begin
		cache_state     <= IDLE;
		write_state     <= 0;
		retrieve_start  <= 0;
		ram_write_start <= 0;
		ram_write_done  <= 0;
	end
	else
	begin
    if (cache_state == IDLE && (ddc || ssddev || sdevbyte) && !busy_w && ready_state)
    begin
       if (spc && cache_address >= 68000000)
            cache_state <= FINISH;
        else
            cache_state <= ACCESS;
    end
	if (cache_state == ACCESS && accessed_data)
	begin
		//Hit or miss?
		cache_state <= hit ? MERGE : MISS;
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
	end
	if (cache_state == RETRIEVE_WAIT)
	begin
		retrieve_start <= 0;
		cache_state <= INSTALL_LINE;
	end
	if (cache_state == INSTALL_LINE && retrieve_done)
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
end

//RAM retrieve fsm
    reg [1:0] fill_byte;
    reg       filling;

    initial
    begin
        fill_word     = 32'd0;
        fill_word_ptr = 3'd0;
        fill_byte     = 2'd0;
        fill_we       = 1'b0;
        filling       = 1'b0;
    end

    always @(posedge clk)
    begin
        fill_we <= 1'b0;

        if (cache_state == REFILL_LINE)
        begin
            fill_word_ptr <= 3'd0;
            fill_byte     <= 2'd0;
            filling       <= 1'b1;
        end

        if (filling && out_byte_ready)
        begin
            case (fill_byte)
                2'd0 : fill_word[ 7: 0] <= out_byte;
                2'd1 : fill_word[15: 8] <= out_byte;
                2'd2 : fill_word[23:16] <= out_byte;
                2'd3 : fill_word[31:24] <= out_byte;
            endcase

            fill_byte <= fill_byte + 2'd1;

            if (fill_byte == 2'd3)
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
    reg [1:0] wb_byte;

    wire [7:0] wb_byte_mux = (wb_byte == 2'd0) ? dram_do[ 7: 0] :
                             (wb_byte == 2'd1) ? dram_do[15: 8] :
                             (wb_byte == 2'd2) ? dram_do[23:16] :
                                                 dram_do[31:24];

    reg [31:0] wb_shift;

    initial
    begin
        wb_word        = 3'd0;
        wb_byte        = 2'd0;
        wb_shift	= 0;
    end

    // change the port: output [7:0] in_byte;  (no longer a reg)
    assign in_byte = wb_shift[7:0];

    always @(posedge clk)
    begin
        ram_write_done <= 1'b0;

        case (write_state)

        3'd0 : if (ram_write_start)
               begin
                   wb_word     <= 3'd0;
                   wb_byte     <= 2'd0;
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

        3'd3 : if (byte_received)
               begin
                   if (wb_byte == 2'd3)
                   begin
                       wb_byte <= 2'd0;
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
                       wb_byte  <= wb_byte + 2'd1;
                   end
               end

        default : write_state <= 3'd0;
        endcase
    end

    wire [31:0] load_word = dram_do >> { byte_r, 3'b000 };
    
    reg [31:0] load_reg;
    always @(posedge clk)
        if (cache_state == MERGE)
            load_reg <= dram_do >> {byte_r, 3'b000};

    // ---- boot ROM: 51 words at byte address 68000000 (0x040D9900) ----
    // Base low byte is 0x00 and the ROM spans 0x00..0xC8, so cache_address[7:2]
    // indexes all 51 entries directly. Plain case logic, no memory inference.

    

    reg [31:0] ROM_OUT;
    output reg        rom_sel;

    wire rom_hit = (cache_address >= 32'd68000000) && (cache_address <= 32'd68000200);

    always @(posedge clk)
    begin
        if (spc)
        begin
            rom_sel <= rom_hit;
            case (cache_address[7:2])
            6'd0  : ROM_OUT <= 32'h00000117;
            6'd1  : ROM_OUT <= 32'h09410113;
            6'd2  : ROM_OUT <= 32'h00C000EF;
            6'd3  : ROM_OUT <= 32'h7C651073;
            6'd4  : ROM_OUT <= 32'h00008067;
            6'd5  : ROM_OUT <= 32'hFF010113;
            6'd6  : ROM_OUT <= 32'h00812423;
            6'd7  : ROM_OUT <= 32'h00912223;
            6'd8  : ROM_OUT <= 32'h00112623;
            6'd9  : ROM_OUT <= 32'h00000413;
            6'd10 : ROM_OUT <= 32'h00600493;
            6'd11 : ROM_OUT <= 32'h7D040593;
            6'd12 : ROM_OUT <= 32'h00941513;
            6'd13 : ROM_OUT <= 32'h00140413;
            6'd14 : ROM_OUT <= 32'h024000EF;
            6'd15 : ROM_OUT <= 32'hFE9418E3;
            6'd16 : ROM_OUT <= 32'h00100793;
            6'd17 : ROM_OUT <= 32'h00000067;
            6'd18 : ROM_OUT <= 32'h00C12083;
            6'd19 : ROM_OUT <= 32'h00812403;
            6'd20 : ROM_OUT <= 32'h00412483;
            6'd21 : ROM_OUT <= 32'h01010113;
            6'd22 : ROM_OUT <= 32'h00008067;
            6'd23 : ROM_OUT <= 32'h00100293;
            6'd24 : ROM_OUT <= 32'h00300313;
            6'd25 : ROM_OUT <= 32'h7C431073;
            6'd26 : ROM_OUT <= 32'h7C529073;
            6'd27 : ROM_OUT <= 32'h00B50023;
            6'd28 : ROM_OUT <= 32'h7C401073;
            6'd29 : ROM_OUT <= 32'h7C501073;
            6'd30 : ROM_OUT <= 32'h00100513;
            6'd31 : ROM_OUT <= 32'h00008067;
            6'd32 : ROM_OUT <= 32'h00000000;
            6'd33 : ROM_OUT <= 32'h00000000;
            6'd34 : ROM_OUT <= 32'h00000000;
            6'd35 : ROM_OUT <= 32'h00000000;
            6'd36 : ROM_OUT <= 32'h00000000;
            6'd37 : ROM_OUT <= 32'h00000000;
            6'd38 : ROM_OUT <= 32'h00000000;
            6'd39 : ROM_OUT <= 32'h00000000;
            6'd40 : ROM_OUT <= 32'h00000000;
            6'd41 : ROM_OUT <= 32'h00000000;
            6'd42 : ROM_OUT <= 32'h00000000;
            6'd43 : ROM_OUT <= 32'h00000000;
            6'd44 : ROM_OUT <= 32'h00000000;
            6'd45 : ROM_OUT <= 32'h00000000;
            6'd46 : ROM_OUT <= 32'h00000000;
            6'd47 : ROM_OUT <= 32'h00000000;
            6'd48 : ROM_OUT <= 32'h00000000;
            6'd49 : ROM_OUT <= 32'h00000000;
            6'd50 : ROM_OUT <= 32'h00000000;
            default: ROM_OUT <= 32'h00000000;
            endcase
        end
    end

    always @*
        CACHE_IR = rom_sel ? ROM_OUT : dram_do;

    assign CACHE_REGS = load_reg;
    assign CACHE_MAR  = cache_address;
    
endmodule
