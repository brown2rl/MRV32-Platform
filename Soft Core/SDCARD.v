module SD_Controller(clk, reset, ss, start, tx_byte, sdc_wirq_en, sdc_rirq_en, srr8, srr32, next_read_address, next_write_address, cs_en, clk_on, clk_cnt, rx_byte, busy, done, card_busy, sd_read_interrupt, sd_write_interrupt, SDC_DEV, DEV_SDC, RAM_SDC, MAR_DEV, SAR_SDC, sdccontin, sdccontout, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT);

    input clk, busy, done, reset, sdc_wirq_en, sdc_rirq_en, sd_read_interrupt, sd_write_interrupt, srr8, srr32;
    input [7:0] rx_byte, DEV_SDC, MAR_DEV, RAM_SDC, sdccontout;
    input [31:0] SAR_SDC, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT;
    output reg start, cs_en, ss, clk_on, card_busy, next_read_address, next_write_address;
    output reg [7:0] tx_byte, sdccontin, SDC_DEV;
    output reg [15:0] clk_cnt;

    reg rst_reg, ready_state, start_level, address_progression, sdws, sdwd, sdrs, sdrd;
    reg [4:0] init_state, card_on_state, write_state, read_state;
    reg [5:0] intra_state;
    reg [18:0] cnt;
    reg [47:0] CMD_0   = 48'h400000000095;
    reg [47:0] CMD_8   = 48'h48000001AA87;
    reg [47:0] CMD_55  = 48'h7700000000FF;
    reg [47:0] ACMD_41 = 48'h694000000077;
    reg [47:0] CMD_58  = 48'h7A00000000FD;
    reg [47:0] CMD;
    reg [2:0] cmd_byte_cnt;
    reg [7:0] rx_byte_reg;
    wire [31:0] write_address;
    wire [31:0] read_address;

    localparam RESPONSE_TIMEOUT = 10000;

    initial
    begin
        start       = 0;
        sdrs        = 0;
        sdws        = 0;
        sdrd        = 0;
        sdwd        = 0;
        cs_en       = 1;
        clk_on      = 1;
        tx_byte     = 0;
        clk_cnt     = 199;
        init_state  = 0;
        intra_state = 0;
        write_state = 0;
        read_state  = 0;
        ready_state = 0;
        card_on_state = 0;
        cnt         = 0;
        rx_byte_reg = 0;
        CMD_0       = 48'h400000000095;
        CMD_8       = 48'h48000001AA87;
        CMD_55      = 48'h770000000065;
        ACMD_41     = 48'h694000000077;
        CMD_58      = 48'h7A00000000FD;
        rst_reg     = 0;
        start_level = 0;
        ss          = 0;
    end

    always @*
        rx_byte_reg = rx_byte;

    always @(posedge clk)
    begin
        if (reset)
        begin
            start_level <= 1;
        end
    end

    always @(posedge clk)
    begin
        if (write_state == 3 && intra_state == 4)
        begin
            ss <= 1;
        end
        // else
        // begin
        //     ss <= 0;
        // end
    end
    
    assign write_address = SAR_SDC;
    assign read_address = SAR_SDC;

always @*
if (CSR_DEV_BUS_IN == 1 && CSR_DEV_BUS_OUT == 3)
begin
	sdws = sdccontout[0];
end

always @*
if (CSR_DEV_BUS_IN == 3 && CSR_DEV_BUS_OUT == 1)
begin
	sdrs = sdccontout[0];
end

always @*
begin
    if (CSR_DEV_BUS_IN == 1 && CSR_DEV_BUS_OUT == 3)
    begin
	   sdccontin[0] = address_progression;
	   sdccontin[1] = sdwd;
    end
    else if (CSR_DEV_BUS_IN == 3 && CSR_DEV_BUS_OUT == 1)
    begin
	   sdccontin[0] = address_progression;
	   sdccontin[1] = sdrd;
    end
end


    always @(posedge clk)
    begin

        if (init_state == 0)     // WAIT PERIOD
        begin
            cnt <= cnt + 1;
            if (cnt == 400000)
            begin
                init_state  <= 1;
                intra_state <= 0;
                cnt         <= 0;
            end
        end

        if (init_state == 1)                    // FFs
        begin
            if (intra_state == 0)
            begin
                tx_byte     <= 8'hFF;
                intra_state <= 1;
            end
            if (intra_state == 1)
            begin
                start       <= 1;
                intra_state <= 2;
            end
            if (intra_state == 2)
            begin
                start       <= 0;
                intra_state <= 3;
            end
            if (intra_state == 3 && done)
            begin
                if (cnt < 80)
                begin
                    cnt         <= cnt + 1;
                    intra_state <= 1;
                end
                else
                begin
                    init_state <= 2;
                end
            end
        end

        if (init_state == 2)
        begin
            init_state   <= 3;
            cs_en        <= 0;
            cnt          <= 0;
            cmd_byte_cnt <= 0;
            CMD          <= CMD_0;
            intra_state  <= 0;
        end

        if (init_state == 3)                    // CMD 0
        begin
            if (intra_state == 0)
            begin
                cmd_byte_cnt <= 0;
                CMD          <= CMD_0;
                intra_state  <= 16'd1;
            end
            else if (intra_state == 1)
            begin
                tx_byte     <= CMD[((5 - cmd_byte_cnt) * 8) +: 8];
                intra_state <= 2;
                clk_on      <= 1;
            end
            else if (intra_state == 2)
            begin
                start       <= 1;
                intra_state <= 3;
            end
            else if (intra_state == 3)
            begin
                start       <= 0;
                intra_state <= 4;
            end
            else if (intra_state == 4 && done)
            begin
                if (cmd_byte_cnt == 5)
                begin
                    intra_state <= 5;
                end
                else
                begin
                    intra_state  <= 1;
                    cmd_byte_cnt <= cmd_byte_cnt + 1;
                end
            end
            else if (intra_state == 5)          // RESPONSE
            begin
                tx_byte     <= 8'hFF;
                intra_state <= 6;
            end
            else if (intra_state == 6)
            begin
                start       <= 1;
                intra_state <= 7;
            end
            else if (intra_state == 7)
            begin
                start       <= 0;
                intra_state <= 8;
            end
            else if (intra_state == 8 && done && rx_byte == 8'h01)
            begin
                init_state  <= 4;
                intra_state <= 0;
                cnt         <= 0;
            end
            else if (intra_state == 8 && done && rx_byte == 8'hFF)
            begin
                intra_state <= 6;
            end
            else if (intra_state == 8 && done)
            begin
                intra_state <= 6;
            end
        end

        if (init_state == 4)                    // FFs
        begin
            if (intra_state == 0)
            begin
                tx_byte     <= 8'hFF;
                intra_state <= 1;
            end
            if (intra_state == 1)
            begin
                start       <= 1;
                intra_state <= 2;
            end
            if (intra_state == 2)
            begin
                start       <= 0;
                intra_state <= 3;
            end
            if (intra_state == 3 && done)
            begin
                if (cnt < 6)
                begin
                    cnt         <= cnt + 1;
                    intra_state <= 1;
                end
                else
                begin
                    init_state  <= 5;
                    intra_state <= 0;
                end
            end
        end

        if (init_state == 5)                    // CMD 8
        begin
            if (intra_state == 0)
            begin
                cmd_byte_cnt <= 0;
                CMD          <= CMD_8;
                intra_state  <= 16'd1;
            end
            else if (intra_state == 1)
            begin
                tx_byte     <= CMD[((5 - cmd_byte_cnt) * 8) +: 8];
                intra_state <= 2;
            end
            else if (intra_state == 2)
            begin
                start       <= 1;
                intra_state <= 3;
            end
            else if (intra_state == 3)
            begin
                start       <= 0;
                intra_state <= 4;
            end
            else if (intra_state == 4 && done)
            begin
                if (cmd_byte_cnt == 5)
                begin
                    intra_state <= 5;
                    cnt         <= 0;
                end
                else
                begin
                    intra_state  <= 1;
                    cmd_byte_cnt <= cmd_byte_cnt + 1;
                end
            end
            else if (intra_state == 5)          // RESPONSE
            begin
                tx_byte     <= 8'hFF;
                intra_state <= 6;
            end
            else if (intra_state == 6)
            begin
                start       <= 1;
                intra_state <= 7;
            end
            else if (intra_state == 7)
            begin
                start       <= 0;
                intra_state <= 8;
            end
            else if (intra_state == 8 && done && (cnt == 0 || cnt == 3) && rx_byte == 8'h01)
            begin
                intra_state <= 6;
                cnt         <= cnt + 1;
            end
            else if (intra_state == 8 && done && (cnt == 1 || cnt == 2) && rx_byte == 8'h00)
            begin
                intra_state <= 6;
                cnt         <= cnt + 1;
            end
            else if (intra_state == 8 && done && cnt == 4 && rx_byte == 8'hAA)
            begin
                intra_state <= 0;
                cnt         <= 0;
                init_state  <= 6;
                clk_on      <= 1;
            end
            else if (intra_state == 8 && done && rx_byte == 8'hFF)
            begin
                intra_state <= 6;
                cnt         <= 0;
            end
            else if (intra_state == 8 && done)
            begin
                intra_state <= 6;
                cnt         <= 0;   // restart the R7 byte-index count on any unexpected value
            end
        end

        if (init_state == 6)                    // FFs
        begin
            if (intra_state == 0)
            begin
                tx_byte     <= 8'hFF;
                intra_state <= 1;
            end
            if (intra_state == 1)
            begin
                start       <= 1;
                intra_state <= 2;
            end
            if (intra_state == 2)
            begin
                start       <= 0;
                intra_state <= 3;
            end
            if (intra_state == 3 && done)
            begin
                if (cnt < 2)
                begin
                    cnt         <= cnt + 1;
                    intra_state <= 1;
                end
                else
                begin
                    init_state  <= 7;
                    intra_state <= 0;
                end
            end
        end

        if (init_state == 7)                    // CMD 55
        begin
            if (intra_state == 0)
            begin
                cmd_byte_cnt <= 0;
                CMD          <= CMD_55;
                intra_state  <= 16'd1;
            end
            else if (intra_state == 1)
            begin
                tx_byte     <= CMD[((5 - cmd_byte_cnt) * 8) +: 8];
                intra_state <= 2;
            end
            else if (intra_state == 2)
            begin
                start       <= 1;
                intra_state <= 3;
            end
            else if (intra_state == 3)
            begin
                start       <= 0;
                intra_state <= 4;
            end
            else if (intra_state == 4 && done)
            begin
                if (cmd_byte_cnt == 5)
                begin
                    intra_state <= 5;
                end
                else
                begin
                    intra_state  <= 1;
                    cmd_byte_cnt <= cmd_byte_cnt + 1;
                end
            end
            else if (intra_state == 5)          // RESPONSE
            begin
                tx_byte     <= 8'hFF;
                intra_state <= 6;
            end
            else if (intra_state == 6)
            begin
                start       <= 1;
                intra_state <= 7;
            end
            else if (intra_state == 7)
            begin
                start       <= 0;
                intra_state <= 8;
            end
            else if (intra_state == 8 && done && rx_byte == 8'h01)
            begin
                init_state  <= 8;
                intra_state <= 0;
            end
            else if (intra_state == 8 && done && rx_byte == 8'hFF)
            begin
                intra_state <= 6;
            end
            else if (intra_state == 8 && done)
            begin
                intra_state <= 6;
            end
        end

        if (init_state == 8)                    // FFs
        begin
            if (intra_state == 0)
            begin
                tx_byte     <= 8'hFF;
                intra_state <= 1;
            end
            if (intra_state == 1)
            begin
                start       <= 1;
                intra_state <= 2;
            end
            if (intra_state == 2)
            begin
                start       <= 0;
                intra_state <= 3;
            end
            if (intra_state == 3 && done)
            begin
                if (cnt < 2)
                begin
                    cnt         <= cnt + 1;
                    intra_state <= 1;
                end
                else
                begin
                    init_state  <= 9;
                    intra_state <= 0;
                end
            end
        end

        if (init_state == 9)                    // ACMD 41
        begin
            if (intra_state == 0)
            begin
                cmd_byte_cnt <= 0;
                CMD          <= ACMD_41;
                cnt          <= 0;
                intra_state  <= 16'd1;
            end
            else if (intra_state == 1)
            begin
                tx_byte     <= CMD[((5 - cmd_byte_cnt) * 8) +: 8];
                intra_state <= 2;
                clk_on      <= 1;
            end
            else if (intra_state == 2)
            begin
                start       <= 1;
                intra_state <= 3;
            end
            else if (intra_state == 3)
            begin
                start       <= 0;
                intra_state <= 4;
            end
            else if (intra_state == 4 && done)
            begin
                if (cmd_byte_cnt == 5)
                begin
                    intra_state <= 5;
                end
                else
                begin
                    intra_state  <= 1;
                    cmd_byte_cnt <= cmd_byte_cnt + 1;
                end
            end
            else if (intra_state == 5)          // RESPONSE
            begin
                tx_byte     <= 8'hFF;
                intra_state <= 6;
            end
            else if (intra_state == 6)
            begin
                start       <= 1;
                intra_state <= 7;
            end
            else if (intra_state == 7)
            begin
                start       <= 0;
                intra_state <= 8;
            end
            else if (intra_state == 8 && done && rx_byte == 8'h00)
            begin
                init_state  <= 10;
                intra_state <= 0;
                ready_state <= 1;
                clk_cnt     <= 15;
                cnt         <= 0;
                cs_en       <= 1;
            end
            else if (intra_state == 8 && done && rx_byte == 8'hFF && cnt < 5)
            begin
                cnt         <= cnt + 1;
                intra_state <= 6;
            end
            else if (intra_state == 8 && done)
            begin
                cnt         <= 0;
                init_state  <= 6;
                intra_state <= 0;
            end
        end


        if (ready_state)
        begin
        
            if (write_state == 0)
            begin
                if (sdws)
                begin
                    cs_en       <= 0;
                    write_state <= 1;
                end
            end
            else if (write_state == 1)          // FFs
            begin
                if (intra_state == 0)
                begin
                    tx_byte     <= 8'hFF;
                    intra_state <= 1;
                end
                if (intra_state == 1)
                begin
                    start       <= 1;
                    intra_state <= 2;
                end
                if (intra_state == 2)
                begin
                    start       <= 0;
                    intra_state <= 3;
                end
                if (intra_state == 3 && done)
                begin
                    if (cnt < 2)
                    begin
                        cnt         <= cnt + 1;
                        intra_state <= 1;
                    end
                    else
                    begin
                        write_state <= 2;
                        intra_state <= 0;
                    end
                end
            end

            if (write_state == 2)               // CMD 24
            begin
                if (intra_state == 0)
                begin
                    cmd_byte_cnt <= 0;
                    CMD          <= { 8'h58, write_address[31:0], 8'hFF };
                    intra_state  <= 16'd1;
                end
                else if (intra_state == 1)
                begin
                    tx_byte     <= CMD[((5 - cmd_byte_cnt) * 8) +: 8];
                    intra_state <= 2;
                end
                else if (intra_state == 2)
                begin
                    start       <= 1;
                    intra_state <= 3;
                end
                else if (intra_state == 3)
                begin
                    start       <= 0;
                    intra_state <= 4;
                end
                else if (intra_state == 4 && done)
                begin
                    if (cmd_byte_cnt == 5)
                    begin
                        intra_state <= 5;
                    end
                    else
                    begin
                        intra_state  <= 1;
                        cmd_byte_cnt <= cmd_byte_cnt + 1;
                    end
                end
                else if (intra_state == 5)      // RESPONSE
                begin
                    tx_byte     <= 8'hFF;
                    intra_state <= 6;
                end
                else if (intra_state == 6)
                begin
                    start       <= 1;
                    intra_state <= 7;
                end
                else if (intra_state == 7)
                begin
                    start       <= 0;
                    intra_state <= 8;
                end
                else if (intra_state == 8 && done && rx_byte == 8'h00)
                begin
                    write_state <= 3;
                    intra_state <= 0;
                end
                else if (intra_state == 8 && done && rx_byte == 8'hFF)
                begin
                    intra_state <= 6;
                end
                else if (intra_state == 8 && done)
                begin
                    intra_state <= 6;
                end
            end

            if (write_state == 3)
            begin
                if (intra_state == 0)
                begin
                    tx_byte     <= 8'hFF;
                    intra_state <= 1;
                end
                else if (intra_state == 1)
                begin
                    start       <= 1;
                    intra_state <= 2;
                end
                else if (intra_state == 2)
                begin
                    start       <= 0;
                    intra_state <= 3;
                end
                else if (intra_state == 3 && done)
                begin
                    tx_byte     <= 8'hFE;
                    intra_state <= 4;
                end
                else if (intra_state == 4)
                begin
                    start       <= 1;
                    intra_state <= 5;
                end
                else if (intra_state == 5)
                begin
                    start       <= 0;
                    intra_state <= 6;
                    cnt <= 0;
                end
                else if (intra_state == 6 && (done || cnt > 0))
                begin
                    intra_state <= 7;
                    tx_byte     <= DEV_SDC;
                end
                else if (intra_state == 7)
                begin
                    address_progression   <= 1;
                    start       <= 1;
                    intra_state <= 8;
                end
                else if (intra_state == 8)
                begin
                    address_progression   <= 0;
                    start       <= 0;
                    intra_state <= 9;
                end
                else if (intra_state == 9 && done)
                begin
                    if (cnt < 511)
                    begin
                        cnt         <= cnt + 1;
                        intra_state <= 6;
                    end
                    else
                    begin
                        intra_state <= 10;
                    end
                end
                else if (intra_state == 10)
                begin
                    tx_byte     <= 8'hFF;
                    intra_state <= 11;
                end
                else if (intra_state == 11)
                begin
                    start       <= 1;
                    intra_state <= 12;
                end
                else if (intra_state == 12)
                begin
                    start       <= 0;
                    intra_state <= 13;
                end
                else if (intra_state == 13 && done)
                begin
                    start       <= 1;
                    intra_state <= 14;
                end
                else if (intra_state == 14)
                begin
                    start       <= 0;
                    intra_state <= 15;
                end
                else if (intra_state == 15 && done)
                begin
                    start       <= 1;
                    intra_state <= 16;
                end
                else if (intra_state == 16)
                begin
                    start       <= 0;
                    intra_state <= 17;
                end
                else if (intra_state == 17 && done)
                begin
                    if (rx_byte[2:0] == 3'b101)
                    begin
                        intra_state <= 18;
                        cnt         <= 0;
                    end
                end
                else if (intra_state == 18)
                begin
                    tx_byte     <= 8'hFF;
                    intra_state <= 19;
                end
                else if (intra_state == 19)
                begin
                    start       <= 1;
                    intra_state <= 20;
                end
                else if (intra_state == 20)
                begin
                    start       <= 0;
                    intra_state <= 21;
                end
                else if (intra_state == 21 && done)
                begin
                    if (rx_byte[0] == 1'b1)
                    begin
                        intra_state <= 22;
                    end
                    else
                    begin
                        intra_state <= 19;
                    end
                end
                else if (intra_state == 22)
                begin
                    cs_en       <= 1;
                    tx_byte     <= 8'hFF;
                    intra_state <= 23;
                end
                else if (intra_state == 23)
                begin
                    start       <= 1;
                    intra_state <= 24;
                end
                else if (intra_state == 24)
                begin
                    start       <= 0;
                    intra_state <= 25;
                end
                else if (intra_state == 25 && done)
                begin
                    intra_state <= 26;
                    sdwd        <= 1;
                end
                else if (intra_state == 26)
                begin
                    write_state <= 0;
                    intra_state <= 0;
                    cnt         <= 0;
                    sdwd        <= 0;
                end
            end


            if (read_state == 0)
            begin
                sdrd <= 0;
                next_read_address <= 0;
                if (sdrs)
                begin
                    cs_en       <= 0;
                    read_state  <= 1;
                end
            end
            else if (read_state == 1)
            begin
                if (intra_state == 0)
                begin
                    tx_byte     <= 8'hFF;
                    intra_state <= 1;
                end
                else if (intra_state == 1)
                begin
                    start       <= 1;
                    intra_state <= 2;
                end
                if (intra_state == 2)
                begin
                    start       <= 0;
                    intra_state <= 3;
                end
                if (intra_state == 3 && done)
                begin
                    if (cnt < 4)
                    begin
                        cnt         <= cnt + 1;
                        intra_state <= 1;
                    end
                    else
                    begin
                        read_state  <= 2;
                        intra_state <= 0;
                    end
                end
            end

            else if (read_state == 2)           // CMD 24
            begin
                if (intra_state == 0)
                begin
                    cmd_byte_cnt <= 0;
                    CMD          <= { 8'h51, read_address[31:0], 8'hFF };
                    intra_state  <= 16'd1;
                end
                else if (intra_state == 1)
                begin
                    tx_byte     <= CMD[((5 - cmd_byte_cnt) * 8) +: 8];
                    intra_state <= 2;
                end
                else if (intra_state == 2)
                begin
                    start       <= 1;
                    intra_state <= 3;
                end
                else if (intra_state == 3)
                begin
                    start       <= 0;
                    intra_state <= 4;
                end
                else if (intra_state == 4 && done)
                begin
                    if (cmd_byte_cnt == 5)
                    begin
                        intra_state <= 5;
                    end
                    else
                    begin
                        intra_state  <= 1;
                        cmd_byte_cnt <= cmd_byte_cnt + 1;
                    end
                end
                else if (intra_state == 5)      // RESPONSE
                begin
                    tx_byte     <= 8'hFF;
                    intra_state <= 6;
                end
                else if (intra_state == 6)
                begin
                    start       <= 1;
                    intra_state <= 7;
                end
                else if (intra_state == 7)
                begin
                    start       <= 0;
                    intra_state <= 8;
                end
                else if (intra_state == 8 && done && rx_byte == 8'h00)
                begin
                    read_state  <= 3;
                    intra_state <= 0;
                end
                else if (intra_state == 8 && done && rx_byte == 8'hFF)
                begin
                    intra_state <= 6;
                end
                else if (intra_state == 8 && done)
                begin
                    intra_state <= 6;
                end
            end

            else if (read_state == 3)
            begin
                if (intra_state == 0)           // RESPONSE
                begin
                    tx_byte     <= 8'hFF;
                    intra_state <= 1;
                end
                else if (intra_state == 1)
                begin
                    start       <= 1;
                    intra_state <= 2;
                end
                else if (intra_state == 2)
                begin
                    start       <= 0;
                    intra_state <= 3;
                end
                else if (intra_state == 3 && done && rx_byte == 8'hFE)
                begin
                    read_state  <= 4;
                    intra_state <= 0;
                end
                else if (intra_state == 3 && done && rx_byte == 8'hFF)
                begin
                    intra_state <= 1;
                end
                else if (intra_state == 3 && done)
                begin
                    intra_state <= 1;
                end
            end

            else if (read_state == 4)
            begin
                if (intra_state == 0)
                begin
                    tx_byte     <= 8'hFF;
                    cnt         <= 0;
                    intra_state <= 1;
                end
                else if (intra_state == 1)
                begin
                    start       <= 1;
                    intra_state <= 2;
                    address_progression <= 0;
                end
                else if (intra_state == 2)
                begin
                    start       <= 0;
                    intra_state <= 3;
                end
                else if (intra_state == 3 && done)
                begin
                    SDC_DEV <= rx_byte;
                    intra_state <= 4;
                end
                else if (intra_state == 4)
                begin
                    if (cnt < 511)
                    begin
                        address_progression <= 1;
                        cnt         <= cnt + 1;
                        intra_state <= 1;
                    end
                    else
                    begin
                        address_progression <= 1;
                        intra_state <= 5;
                        cnt         <= 0;
                    end
                end
                else if (intra_state == 5)
                begin
                    address_progression <= 0;
                    tx_byte     <= 8'hFF;
                    cnt         <= 0;
                    intra_state <= 6;
                end
                else if (intra_state == 6)
                begin
                    start       <= 1;
                    intra_state <= 7;
                end
                else if (intra_state == 7)
                begin
                    start       <= 0;
                    intra_state <= 8;
                end
                else if (intra_state == 8 && done)
                begin
                    start       <= 1;
                    intra_state <= 9;
                end
                else if (intra_state == 9)
                begin
                    start       <= 0;
                    intra_state <= 10;
                end
                else if (intra_state == 10 && done)
                begin
                    start       <= 1;
                    intra_state <= 11;
                end
                else if (intra_state == 11)
                begin
                    start       <= 0;
                    intra_state <= 12;
                end
                else if (intra_state == 12 && done)
                begin
                    read_state <= 0;
                    intra_state <= 0;
                    cs_en <= 1;
                    sdrd <= 1;
                end
            end
        end
    end

endmodule


module SPI_Engine(clk, start, tx_byte, cs_en, clk_on, clk_cnt, miso, rx_byte, busy, done, cs, sclk, mosi);

    input clk, start, miso, cs_en, clk_on;
    input [7:0] tx_byte;
    input [15:0] clk_cnt;
    output reg [7:0] rx_byte;
    output reg sclk, mosi;
    output cs, done, busy;

    reg [7:0] tx_byte_reg;
    reg [15:0] clk_div;
    reg sclk_rise, sclk_fall;
    reg [2:0] bit_cnt;
    reg [1:0] txfer_state;

    initial
    begin
        bit_cnt     = 0;
        clk_div     = 0;
        txfer_state = 0;
        sclk        = 0;
        sclk_rise   = 0;
        sclk_fall   = 0;
        rx_byte     = 0;
        tx_byte_reg = 0;
        mosi        = 1;
    end

    assign cs = cs_en;


    // CLOCK DIVIDER

    always @(posedge clk)
    begin
        if (txfer_state == 1 || txfer_state == 2)
        begin
            if (clk_div == clk_cnt)
            begin
                clk_div   <= 0;
                sclk      <= ~sclk;
                sclk_rise <= !sclk;
                sclk_fall <= sclk;
            end
            else
            begin
                sclk_rise <= 0;
                sclk_fall <= 0;
                clk_div   <= clk_div + 1;
            end
        end
        else
        begin
             clk_div   <= 0;
             sclk_rise <= 0;
             sclk_fall <= 0;
        end
    end

    assign busy = (txfer_state != 0);
    assign done = (txfer_state == 3);


    // TRANSFER BYTES

    always @(posedge clk)
    begin
        if (txfer_state == 0)
        begin
            if (start)
            begin
                txfer_state      <= 1;
                tx_byte_reg[7:0] <= tx_byte[7:0];
            end
        end
        if (txfer_state == 1)
        begin
            if (sclk_fall)
            begin
                txfer_state <= 2;
                bit_cnt     <= 7;
                mosi        <= tx_byte_reg[7];
            end
        end
        if (txfer_state == 2)
        begin
            if (sclk_fall)
            begin
                mosi <= tx_byte_reg[bit_cnt];
            end
            if (sclk_rise)
            begin
                rx_byte[bit_cnt] <= miso;
                bit_cnt          <= bit_cnt - 1;
                if (bit_cnt == 0)
                begin
                    txfer_state <= 3;
                end
            end
        end
        if (txfer_state == 3)
        begin
            txfer_state <= 0;
        end
    end

endmodule
