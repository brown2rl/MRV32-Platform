`timescale 1ns/1ps

module CACHE_tb;

    // Inputs
    reg clk;
    reg spc;
    reg ddc;
    reg sci;
    reg busy_w;

    reg srr8;
    reg srr16;
    reg srr32;

    reg lb;
    reg lbu;
    reg lh;
    reg lhu;

    reg out_bytes_ready;
    reg bytes_received;
    reg dev_start_signal;
    reg sdevcache;

    reg [7:0] out_bytes;
    reg [7:0] cachecontout;

    reg [31:0] PC_CACHE;
    reg [31:0] REGS_CACHE_ADDRESS;
    reg [31:0] REGS_CACHE_DATA;
    reg [31:0] CSR_DEV_BUS_IN;
    reg [31:0] CSR_DEV_BUS_OUT;
    reg [31:0] CM_CACHE;

    // Outputs
    wire retrieve_start;
    wire ram_write_start;
    wire dev_stop_signal;
    wire sdevbit;
    wire address_progression;
    wire [7:0] cachecontin, in_bytes, CACHE_DEV;
    wire [24:0] qspi_address;
    wire [31:0] CACHE_IR;
    wire [31:0] CACHE_REGS;
    wire cache_done;
    wire rom_sel;

//-----------------------------
// RAM sync model
//-----------------------------
reg [7:0] wb_ram [0:31];

    //----------------------------------------------------
    // Clock
    //----------------------------------------------------

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //----------------------------------------------------
    // Monitor
    //----------------------------------------------------

    initial begin
        $monitor(
            "T=%0t retrieve=%b done=%b qspi=%h regs=%h",
            $time,
            retrieve_start,
            cache_done,
            qspi_address,
            CACHE_REGS
        );
    end

    //----------------------------------------------------
    // Stimulus
    //----------------------------------------------------

    integer i;
    integer wb_count;
    integer j;

    initial begin

        // Initialize inputs

        spc = 0;
        ddc = 0;
        sci = 0;
        busy_w = 0;

        srr8 = 0;
        srr16 = 0;
        srr32 = 0;

        lb = 0;
        lbu = 0;
        lh = 0;
        lhu = 0;

        out_bytes_ready = 0;
        bytes_received = 0;

        dev_start_signal = 0;
        sdevcache = 0;

	wb_count = 0;

        out_bytes = 8'h00;
        cachecontout = 8'h00;

        PC_CACHE = 32'h00001000;
        REGS_CACHE_ADDRESS = 32'h00002000;
        REGS_CACHE_DATA = 32'hDEADBEEF;

        CSR_DEV_BUS_IN = 0;
        CSR_DEV_BUS_OUT = 0;
        CM_CACHE = 0;

        //------------------------------------------------
        // Start memory read
        //------------------------------------------------

	@(posedge clk);
	ddc <= 1;

	@(posedge clk);
	ddc <= 0;

        //------------------------------------------------
        // Wait for refill request
        //------------------------------------------------

        wait(retrieve_start);

        $display("Refill started at %t", $time);


        //------------------------------------------------
        // Send 8 words (32 bytes)
        //------------------------------------------------

        for (i = 0; i < 32; i = i + 1)
        begin
            @(posedge clk);

            out_bytes       <= i;
            out_bytes_ready <= 1'b1;

            @(posedge clk);

            out_bytes_ready <= 1'b0;
        end



        //------------------------------------------------
        // Wait for completion
        //------------------------------------------------

        wait(cache_done);

        $display("Cache transaction complete");

        #50;

// testing write-back
	@(posedge clk); // finish to idle transition

	@(posedge clk);

        REGS_CACHE_DATA <= 32'hAABBCCDD;

	srr32 <= 1;

	@(posedge clk);
	ddc = 1;

	@(posedge clk);
	ddc = 0;

	wait(cache_done);

	@(posedge clk);
	REGS_CACHE_ADDRESS <= 32'h40002000;
	
	ddc = 1;

	@(posedge clk);
	ddc = 0;

        wait(retrieve_start);

        $display("Refill started at %t", $time);

        for (i = 0; i < 32; i = i + 1)
        begin
            @(posedge clk);

            out_bytes       <= i;
            out_bytes_ready <= 1'b1;

            @(posedge clk);

            out_bytes_ready <= 1'b0;
        end

	wait(cache_done);

	srr32 <= 0;
        //$finish;
    end

always @(ddc)
        $display("DDC pulse seen at %0t", $time);

    //----------------------------------------------------
    // VCD dump
    //----------------------------------------------------

    initial begin
        $dumpfile("cache.vcd");
        $dumpvars(0, CACHE_tb);
    end

always @(posedge clk)
begin
    $display(
      "state=%0d hit=%b valid=%b dirty=%b store_req=%b we=%b ddc=%d, done=%d",
      dut.cache_state,
      dut.hit,
      dut.valid_do,
      dut.dirty_do,
      dut.store_req,
      dut.we,
      ddc,
      cache_done
    );
end

always @(posedge clk)
begin
    if (dut.out_bytes_ready)
        $display(
            "fill_bits=%0d fill_word_ptr=%0d fill_we=%b",
            dut.fill_bits,
            dut.fill_word_ptr,
            dut.fill_we
        );
end

always @(posedge clk)
begin
    bytes_received <= 1;
    
    if (dut.cache_state == dut.ACCESS && dut.accessed_data)
	$display("ACCESS occured: hit=%b store_req=%b we=%b tag_do=%h tag_r=%h",
		dut.hit,
		dut.store_req,
		dut.we,
		dut.tag_do,
		dut.tag_r);
    if (dut.cache_state == dut.MERGE)
        $display("MERGE occurred");
    if (dut.cache_state == dut.MISS)
	$display("idx=%d dirty[idx]=%b dirty_do=%b tag_do=%h tag_r=%h", dut.idx_r, dut.dirty[dut.idx_r], dut.dirty_do, dut.tag_do, dut.tag_r); 
    if (dut.cache_state == dut.WRITE_BACK && dut.write_state == 3'd3 && !dut.ram_write_done && wb_count < 32)
    begin
	$display(
    		"RAM WRITING t=%0t wb_bits=%0d wb_shift=%h in_bytes=%h data_ram_0=%h data_ram_1=%h",
    			$time,
    				dut.wb_bits,
    				dut.wb_shift,
    				in_bytes,
				dut.data_ram[{dut.idx_r,3'd0}],
				dut.data_ram[{dut.idx_r,3'd1}]
		);
	
        	wb_ram[wb_count] <= in_bytes;
        	wb_count <= wb_count + 1;

 
	bytes_received <= 1;

        $display(
            "WB byte %0d : data=%02h word=%0d byte=%0d",
            wb_count,
            in_bytes,
            dut.wb_word,
            dut.wb_bits
        );
    end
    if (dut.ram_write_done)
    begin
        $display(
            "ram_write_done asserted after %0d bytes",
            wb_count
        );

        $display("\nWrite-back RAM contents:");

        for (j=0; j<32; j=j+1)
            $display("[%0d] = %02h", j, wb_ram[j]);
    end
end

always @(posedge clk)
begin

end

    //----------------------------------------------------
    // DUT
    //----------------------------------------------------

    CACHE dut (
        .clk(clk),
        .spc(spc),
        .ddc(ddc),
        .sci(sci),
        .busy_w(busy_w),

        .srr8(srr8),
        .srr16(srr16),
        .srr32(srr32),

        .lb(lb),
        .lbu(lbu),
        .lh(lh),
        .lhu(lhu),

        .ram_write_start(ram_write_start),

        .in_bytes(in_bytes),

        .retrieve_start(retrieve_start),
        .out_bytes(out_bytes),
        .out_bytes_ready(out_bytes_ready),

        .bytes_received(bytes_received),

        .sdevbit(sdevbit),
        .dev_stop_signal(dev_stop_signal),
        .dev_start_signal(dev_start_signal),

        .sdevcache(sdevcache),

        .qspi_address(qspi_address),

        .address_progression(address_progression),

        .cachecontin(cachecontin),
        .cachecontout(cachecontout),

        .CM_CACHE(CM_CACHE),
        .PC_CACHE(PC_CACHE),

        .REGS_CACHE_DATA(REGS_CACHE_DATA),
        .REGS_CACHE_ADDRESS(REGS_CACHE_ADDRESS),

        .CSR_DEV_BUS_IN(CSR_DEV_BUS_IN),
        .CSR_DEV_BUS_OUT(CSR_DEV_BUS_OUT),

        .CACHE_IR(CACHE_IR),
        .CACHE_REGS(CACHE_REGS),
	.CACHE_DEV(CACHE_DEV),

        .cache_done(cache_done),
	.rom_sel(rom_sel)
    );

endmodule