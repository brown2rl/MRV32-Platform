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

    reg out_byte_ready;
    reg byte_received;
    reg dev_start_signal;
    reg sdevcache;

    reg [7:0] out_byte;
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
    wire sdevbyte;
    wire address_progression;
    wire [7:0] cachecontin;
    wire [7:0] in_byte;
    wire [24:0] qspi_address;
    wire [31:0] CACHE_IR;
    wire [31:0] CACHE_REGS;
    wire cache_done;

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

        out_byte_ready = 0;
        byte_received = 0;

        dev_start_signal = 0;
        sdevcache = 0;

        out_byte = 8'h00;
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

        #20;

        ddc = 1;

        #10;
        ddc = 0;

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

            out_byte       <= i;
            out_byte_ready <= 1'b1;

            @(posedge clk);

            out_byte_ready <= 1'b0;
        end

        //------------------------------------------------
        // Wait for completion
        //------------------------------------------------

        wait(cache_done);

        $display("Cache transaction complete");

        #50;

        $finish;
    end

    //----------------------------------------------------
    // VCD dump
    //----------------------------------------------------

    initial begin
        $dumpfile("cache.vcd");
        $dumpvars(0, CACHE_tb);
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

        .in_byte(in_byte),

        .retrieve_start(retrieve_start),
        .out_byte(out_byte),
        .out_byte_ready(out_byte_ready),

        .byte_received(byte_received),

        .sdevbyte(sdevbyte),
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

        .cache_done(cache_done)
    );

endmodule