module UART(clk, indicatorsin, cur, tx, rx, rxack, srm, mpi, srr8, srr32, rxinterrupt, txready, txbusy, UART_DEV, DEV_UART, REGS_MAR, UART_MAR, MAR_UART, uartcontin, uartcontout, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT);

input clk, indicatorsin, cur, rx, srm, mpi, srr8, srr32, rxack;
input[31:0] DEV_UART, REGS_MAR, MAR_UART, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT;
input[7:0] uartcontout;
output[31:0] UART_MAR;
output reg[7:0] UART_DEV, uartcontin;
output reg tx, rxinterrupt, txready, txbusy;

reg[13:0] baudcnt, txbaudcnt, totalticks, halftotalticks;
reg[13:0] interbitcount;
reg[7:0] MEM_IN;
reg[7:0] UART_IN;
reg[7:0] inbuffer[0:31];
reg[2:0] txstate;
reg[3:0] rxstate;
reg[3:0] rxbitcnt;
reg[4:0] txbitcnt;
reg rx_pending;
reg tx_start, tx_req, txdone, rxbusy, rxready, tx_finished, sdevram;
integer i;

/* ------------------------------------------------------------------
 * RX FIFO: circular buffer, 32 deep.
 * wptr/rptr carry one extra bit so full and empty are distinguishable.
 * ------------------------------------------------------------------ */
reg[5:0] wptr, rptr;
reg      sdevram_d;
reg      rx_overrun;

wire[5:0] fifocnt   = wptr - rptr;
wire      fifoempty = (wptr == rptr);
wire      fifofull  = (fifocnt == 6'd32);

/* A whole character has just been assembled (rxstate 100 lasts 1 clk). */
wire rx_push = (rxstate == 3'b100) && !fifofull;

/* The CPU has just latched UART_DEV into RAM: sb, UART -> RAM.
 * sdevram is a 1-clk strobe from the CM; the edge detect is insurance. */
wire rx_read = sdevram && !sdevram_d &&
               (CSR_DEV_BUS_IN == 2) && (CSR_DEV_BUS_OUT == 1);
wire rx_pop  = rx_read && !fifoempty;

initial
begin
	wptr         = 0;
	rptr         = 0;
	sdevram_d    = 0;
	rx_overrun   = 0;
	rx_pending   = 0;
	MEM_IN       = 0;
	txbaudcnt    = 0;
	interbitcount = 0;
	UART_IN = 8'b0;
	tx = 1'b1;
	txstate = 3'b000;
	rxstate = 3'b000;
	rxbitcnt = 0;
	rxinterrupt = 1'b0;
	rxbusy = 0;
	baudcnt = 14'b0;
	txready = 1;
	txdone = 1'b0;
	txbusy = 1'b0;
	tx_req = 1'b0;
	totalticks = 80000000/19200;
	halftotalticks = 40000000/19200;
	for (i = 0; i < 32; i = i + 1)
	begin
	    inbuffer[i] = 0;
	end
end

/*

OUTGOING-
0 - dev_start_signal for tx_start

INCOMING-
0 - tx_finished

*/

always @*
begin
	tx_start = 1'b0;                       // default: no inferred latch
	if (CSR_DEV_BUS_IN == 1 && CSR_DEV_BUS_OUT == 2)
		tx_start = uartcontout[0];
end

always @*
begin
	uartcontin = 8'b0;                     // default: no inferred latch
	if (CSR_DEV_BUS_IN == 1 && CSR_DEV_BUS_OUT == 2)
		uartcontin[0] = tx_finished;
end

always @*
begin
	sdevram = 0;                     // default: no inferred latch
	if (CSR_DEV_BUS_IN == 2 && CSR_DEV_BUS_OUT == 1)
		sdevram = uartcontout[0];
end

/* dev_start_signal is only a 1-clk pulse, and the CM freezes decode the
 * moment wfi goes high, so the request must be latched here -- otherwise a
 * start that lands while the RX line is busy is lost and the CPU stalls
 * forever waiting for dev_stop_signal. */
always @(posedge clk)
begin
	if (tx_start)
		tx_req <= 1'b1;
	else if (txstate == 3'b001)
		tx_req <= 1'b0;
end

wire indicators = indicatorsin;

always @*
begin
    txbusy = (txstate == 2'b01 || txstate == 2'b10 || txstate == 2'b11);
end

always @*
begin
	tx_finished = (txstate == 3'b100);
end

//TRANSMISSION
always @(posedge clk)
begin
	if (tx_req && txstate == 3'b000)   // full duplex: do not gate on rxbusy
	begin
	    tx <= 1'b0;
	    txstate <= 3'b001;
	    txready <= 0;
	    txbitcnt <= 0;
	    txbaudcnt <= 0;
	end
	else if (txstate == 3'b001)
	begin
	    if (txbaudcnt == totalticks)
	    begin
    		txbaudcnt <= 0;
    		tx <= DEV_UART[txbitcnt];
	       	txbitcnt <= txbitcnt + 1;
		    if (indicators)
	    		$display("TX IS %b and bit = %d", tx, txbitcnt);
		    if (txbitcnt == 4'd7)
		    begin
			    txstate <= 3'b010;
			    txbitcnt <= 0;
		    end
	    end
	    else
	    begin
	        txbaudcnt <= txbaudcnt + 1;
		end
	end
	else if (txstate == 3'b010)
	begin
	    if (txbaudcnt == totalticks)
	    begin
	        tx <= 1;
	        txbaudcnt <= 0;
	        txstate <= 3'b011;
	    end
	    else
	    txbaudcnt <= txbaudcnt + 1;
	end
	else if (txstate == 3'b011)
	begin
	    if (txbaudcnt == totalticks)
	    begin
	        txbaudcnt <= 0;
	        txstate <= 3'b100;
	        txready <= 1;
	    end
	    else
	    txbaudcnt <= txbaudcnt + 1;
	end
	else if (txstate == 3'b100)
	begin
		txstate <= 3'b000;
	end
end

//RECEPTION

always @*
    rxinterrupt = rx_pending;

/* The head of the FIFO is what the CPU sees at the data register. */
always @*
    UART_DEV = inbuffer[rptr[4:0]];

/* ------------------------------------------------------------------
 * rx_pending
 *   - set   when a new character lands in the FIFO
 *   - held  across a pop if characters remain
 *   - clear on rxack (interrupt taken) or when the last char is read
 * ------------------------------------------------------------------ */
always @(posedge clk)
begin
    if (rx_pop)
        rx_pending <= (fifocnt > 6'd1) || rx_push;
    else if (rx_push)
        rx_pending <= 1'b1;
    else if (rxack)
        rx_pending <= 1'b0;
end

always @(posedge clk)
begin
    sdevram_d <= sdevram;

    if (rx_push)
    begin
        inbuffer[wptr[4:0]] <= MEM_IN;
        wptr <= wptr + 1'b1;
    end
    else if (rxstate == 3'b100)
        rx_overrun <= 1'b1;

    if (rx_pop)
        rptr <= rptr + 1'b1;

    /*
     * Receive state machine.
     */
    if (rxstate == 3'b000)
    begin
        if (!rx && !rxbusy)
        begin
            rxbusy <= 1;
            rxstate <= 3'b001;
            interbitcount <= 0;
        end
    end
    else if (rxstate == 3'b001)
    begin
        if (interbitcount == halftotalticks)
        begin
            if (!rx)
            begin
                rxstate <= 3'b010;
                interbitcount <= 0;
                rxbitcnt <= 0;
            end
            else begin
                rxbusy <= 0;
                rxstate <= 3'b000;
            end
        end
        else begin
            interbitcount <= interbitcount + 1'b1;
        end
    end
    else if (rxstate == 3'b010)
    begin
        if (interbitcount == totalticks)
        begin
            MEM_IN[rxbitcnt] <= rx;
            interbitcount <= 0;
            rxbitcnt <= rxbitcnt + 1'b1;

            if (rxbitcnt == 3'd7)
                rxstate <= 3'b011;
        end
        else begin
            interbitcount <= interbitcount + 1'b1;
        end
    end
    else if (rxstate == 3'b011)
    begin
        if (interbitcount == totalticks)
        begin
            rxstate <= 3'b100;
            interbitcount <= 0;
        end
        else begin
            interbitcount <= interbitcount + 1'b1;
        end
    end
    else if (rxstate == 3'b100)
    begin
        rxstate <= 3'b000;
        rxbusy <= 1'b0;
    end
end

endmodule