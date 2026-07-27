module UART(clk, indicatorsin, cur, tx, rx, rxack, srm, mpi, srr8, srr32, rxinterrupt, txready, txbusy, UART_DEV, DEV_UART, REGS_MAR, UART_MAR, MAR_UART, uartcontin, uartcontout, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT);

input clk, indicatorsin, cur, rx, srm, mpi, srr8, srr32, rxack;
input[31:0] DEV_UART, REGS_MAR, MAR_UART, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT;
input[7:0] uartcontout;
output[31:0] UART_MAR;
output reg[7:0] UART_DEV, uartcontin;
output reg tx, rxinterrupt, txready, txbusy;

reg[13:0] baudcnt, txbaudcnt, totalticks, halftotalticks;
reg[13:0] interbitcount;
reg[7:0] UART_MEM_OUT;
reg[7:0] UART_MEM_IN;
reg[2:0] txstate; 
reg[3:0] rxstate;
reg[3:0] rxbitcnt;
reg[4:0] txbitcnt;
reg rx_pending; 
reg tx_start, txdone, rxinterrupttrig, rxbusy, rxready, tx_finished;

initial
begin
	UART_MEM_OUT = 8'b0;
	tx = 1'b1;
	txstate = 3'b000;
	rxstate = 2'b00;
	rxbitcnt = 0;
	rxinterrupt = 1'b0;
	rxbusy = 0;
	baudcnt = 14'b0;
	txready = 1;
	txdone = 1'b0;
	txbusy = 1'b0;
	totalticks = 80000000/19200;
	halftotalticks = 40000000/19200;
end

/*

OUTGOING-
0 - dev_start_signal for tx_start

INCOMING-
0 - tx_finished

*/

always @*
if (CSR_DEV_BUS_IN == 1 && CSR_DEV_BUS_OUT == 2)
begin
	tx_start = uartcontout[0];
end

always @*
if (CSR_DEV_BUS_IN == 1 && CSR_DEV_BUS_OUT == 2)
begin
	uartcontin[0] = tx_finished;
end


//always @*
//$display("tx_f = %b", tx_finished);


//always @(posedge clk)
//if (tx_start)
//	$display("TX STARTED");

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
	if (tx_start && !rxbusy && txstate == 3'b000)
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
	    	if (indicators)
	    			$display("TX IS %b and bit = %d", tx, txbitcnt);
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
	    	if (indicators)
	    			$display("TX IS %b and bit = %d", tx, txbitcnt);
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
             

always @(posedge clk)
begin
    if (rxstate == 3'b100)    
        rx_pending <= 1'b1;
    else if (rxack)           
        rx_pending <= 1'b0;
end

always @*
    rxinterrupt = rx_pending;

//RECEPTION
	
always @(posedge clk)
begin
    if (rxstate == 3'b000 && !rxinterrupt)
    begin
        if (!rx && !txbusy && !rxbusy)
        begin
    	    //$display("rx starting");
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
		    else
		        rxstate <= 3'b000;
		end
		else
		interbitcount <= interbitcount + 1;   
	end
	else if (rxstate == 3'b010)
	begin
	    if (interbitcount == totalticks)
		    begin
           	    UART_DEV[rxbitcnt] <= rx;
		        if (indicators)
	    			$display("rx = %b", rx);
			    interbitcount <= 0;
			    rxbitcnt <= rxbitcnt + 1;
		        if (rxbitcnt == 3'd7)
		        begin
			    rxstate <= 3'b011;
			end
		    end
		else
    	    interbitcount <= interbitcount + 1; 
       
	end
	else if (rxstate == 3'b011)
	begin
		if (interbitcount == totalticks)
		begin
			rxstate <= 3'b100;
   			interbitcount <= 0;
   		end
   		interbitcount <= interbitcount + 1;
   	end
   	else if (rxstate == 3'b100)
	begin
		//$display("UART_DEV in UART = %b", UART_DEV);
		rxstate <= 3'b000;
   		rxbusy <= 0;
   	end
end

	
endmodule
