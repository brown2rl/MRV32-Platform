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
