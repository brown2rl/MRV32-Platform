module testbench();

reg CLK;
reg tx;
reg rx, tx_trig;
System r1(CLK, tx, rx);

tbUART tbUART1(CLK, tx, rx, tx_trig);

initial
begin
	CLK <= 1'b0;
end
	
always
begin
	#1 CLK = ~CLK;
end	

initial
begin
	#3441600 tx_trig <= 1;
	#1404160
	$finish;
end

endmodule	

module tbUART(clk, rx, tx, tx_trig);

input clk, rst, rx, tx_trig;
reg[7:0] UART_MEM_IN;
output reg tx;
reg[7:0] UART_MEM_OUT;

reg[17:0] baudcnt, txbaudcnt, totalticks, halfticks;
reg[13:0] interbitcount;
reg[2:0] txstate;
reg[3:0] rxstate;
reg[3:0] rxbitcnt;
reg[4:0] txbitcnt;
reg[3:0] buftot;
reg txstart, txready, txdone, rxinterrupttrig, txbusy, rxbusy;
reg [7:0] buffer[0:20];
reg indicators;
reg[3:0] bufcnt;



initial
begin
	indicators = 0;
	UART_MEM_OUT = 8'b0;
	txstart = 1'b0;
	tx = 1'b1;
	txstate = 2'b00;
	rxstate = 2'b00;
	rxbitcnt = 0;
	rxbusy = 0;
	rxstate = 3'b000;
	txbaudcnt = 0;
	interbitcount = 0;
	txdone = 1'b0;
	txbusy = 1'b0;
	txready = 1'b1;
	buffer[0] = 8'h42;
	buffer[1] = 8'h61;
	buffer[2] = 8'h73;
	buffer[3] = 8'h69;
	buffer[4] = 8'h63;
	buffer[5] = 8'h0D;
	totalticks = 80000000/19200;
	halfticks = 40000000/19200;
	buftot = 6;
	bufcnt = 0;
end

//RECEPTION

always @(posedge clk)
begin
    if (rxstate == 3'b000)
    begin
        if (!rx)
        begin
            rxbusy <= 1;
            rxstate <= 3'b001;
            interbitcount <= 0;
        end
    end
  	else if (rxstate == 3'b001) 
	begin
		if (interbitcount == halfticks)
		begin
		    if (!rx)
        	    begin
		      	rxstate <= 3'b010;
		       	interbitcount <= 0;
		      	rxbitcnt <= 0;
		      	UART_MEM_OUT <= 0;
		    end
		    else
		        rxstate <= 3'b000;
		end
		interbitcount <= interbitcount + 1;   
	end
	else if (rxstate == 3'b010)
	begin
	    if (interbitcount == totalticks)
		    begin
           	    UART_MEM_OUT[rxbitcnt] <= rx;
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
		if (UART_MEM_OUT[7:0] == 8'hA)
			$display(" ");
		if (UART_MEM_OUT[7:0] == 8'h20)
			$display(" ");	
		if (UART_MEM_OUT[7:0] == 8'h21)
			$display("!");
		if (UART_MEM_OUT[7:0] == 8'h22)
			$display("*");
		if (UART_MEM_OUT[7:0] == 8'h23)
			$display("#");
		if (UART_MEM_OUT[7:0] == 8'h24)
			$display("$");
		if (UART_MEM_OUT[7:0] == 8'h25)
			$display("%");
		if (UART_MEM_OUT[7:0] == 8'h26)
			$display("&");
		if (UART_MEM_OUT[7:0] == 8'h27)
			$display("'");
		if (UART_MEM_OUT[7:0] == 8'h28)
			$display("(");
		if (UART_MEM_OUT[7:0] == 8'h29)
			$display(")");
		if (UART_MEM_OUT[7:0] == 8'h2A)
			$display("*");
		if (UART_MEM_OUT[7:0] == 8'h2B)
			$display("+");
		if (UART_MEM_OUT[7:0] == 8'h2C)
			$display(",");
		if (UART_MEM_OUT[7:0] == 8'h2D)
			$display("-");
		if (UART_MEM_OUT[7:0] == 8'h2E)
			$display(".");
		if (UART_MEM_OUT[7:0] == 8'h2F)
			$display("/");
		if (UART_MEM_OUT[7:0] == 8'h30)
			$display("0");	
		if (UART_MEM_OUT[7:0] == 8'h31)
			$display("1");
		if (UART_MEM_OUT[7:0] == 8'h32)
			$display("2");
		if (UART_MEM_OUT[7:0] == 8'h33)
			$display("3");
		if (UART_MEM_OUT[7:0] == 8'h34)
			$display("4");
		if (UART_MEM_OUT[7:0] == 8'h35)
			$display("5");
		if (UART_MEM_OUT[7:0] == 8'h36)
			$display("6");
		if (UART_MEM_OUT[7:0] == 8'h37)
			$display("7");
		if (UART_MEM_OUT[7:0] == 8'h38)
			$display("8");
		if (UART_MEM_OUT[7:0] == 8'h39)
			$display("9");
		if (UART_MEM_OUT[7:0] == 8'h3A)
			$display(":");
		if (UART_MEM_OUT[7:0] == 8'h3B)
			$display(";");
		if (UART_MEM_OUT[7:0] == 8'h3C)
			$display("<");
		if (UART_MEM_OUT[7:0] == 8'h3D)
			$display("=");
		if (UART_MEM_OUT[7:0] == 8'h3E)
			$display(">");
		if (UART_MEM_OUT[7:0] == 8'h3F)
			$display("?");
		if (UART_MEM_OUT[7:0] == 8'h40)
			$display("@");	
		if (UART_MEM_OUT[7:0] == 8'h41)
			$display("A");
		if (UART_MEM_OUT[7:0] == 8'h42)
			$display("B");
		if (UART_MEM_OUT[7:0] == 8'h43)
			$display("C");
		if (UART_MEM_OUT[7:0] == 8'h44)
			$display("D");
		if (UART_MEM_OUT[7:0] == 8'h45)
			$display("E");
		if (UART_MEM_OUT[7:0] == 8'h46)
			$display("F");
		if (UART_MEM_OUT[7:0] == 8'h47)
			$display("G");
		if (UART_MEM_OUT[7:0] == 8'h48)
			$display("H");
		if (UART_MEM_OUT[7:0] == 8'h49)
			$display("I");
		if (UART_MEM_OUT[7:0] == 8'h4A)
			$display("J");
		if (UART_MEM_OUT[7:0] == 8'h4B)
			$display("K");
		if (UART_MEM_OUT[7:0] == 8'h4C)
			$display("L");
		if (UART_MEM_OUT[7:0] == 8'h4D)
			$display("M");
		if (UART_MEM_OUT[7:0] == 8'h4E)
			$display("N");
		if (UART_MEM_OUT[7:0] == 8'h4F)
			$display("O");
		if (UART_MEM_OUT[7:0] == 8'h50)
			$display("P");	
		if (UART_MEM_OUT[7:0] == 8'h51)
			$display("Q");
		if (UART_MEM_OUT[7:0] == 8'h52)
			$display("R");
		if (UART_MEM_OUT[7:0] == 8'h53)
			$display("S");
		if (UART_MEM_OUT[7:0] == 8'h54)
			$display("T");
		if (UART_MEM_OUT[7:0] == 8'h55)
			$display("U");
		if (UART_MEM_OUT[7:0] == 8'h56)
			$display("V");
		if (UART_MEM_OUT[7:0] == 8'h57)
			$display("W");
		if (UART_MEM_OUT[7:0] == 8'h58)
			$display("X");
		if (UART_MEM_OUT[7:0] == 8'h59)
			$display("Y");
		if (UART_MEM_OUT[7:0] == 8'h5A)
			$display("Z");
		if (UART_MEM_OUT[7:0] == 8'h5B)
			$display("[");
		if (UART_MEM_OUT[7:0] == 8'h5C)
			$display(" ");
		if (UART_MEM_OUT[7:0] == 8'h5D)
			$display("]");
		if (UART_MEM_OUT[7:0] == 8'h5E)
			$display("^");
		if (UART_MEM_OUT[7:0] == 8'h5F)
			$display("_");
		if (UART_MEM_OUT[7:0] == 8'h60)
			$display("`");	
		if (UART_MEM_OUT[7:0] == 8'h61)
			$display("a");
		if (UART_MEM_OUT[7:0] == 8'h62)
			$display("b");
		if (UART_MEM_OUT[7:0] == 8'h63)
			$display("c");
		if (UART_MEM_OUT[7:0] == 8'h64)
			$display("d");
		if (UART_MEM_OUT[7:0] == 8'h65)
			$display("e");
		if (UART_MEM_OUT[7:0] == 8'h66)
			$display("f");
		if (UART_MEM_OUT[7:0] == 8'h67)
			$display("g");
		if (UART_MEM_OUT[7:0] == 8'h68)
			$display("h");
		if (UART_MEM_OUT[7:0] == 8'h69)
			$display("i");
		if (UART_MEM_OUT[7:0] == 8'h6A)
			$display("j");
		if (UART_MEM_OUT[7:0] == 8'h6B)
			$display("k");
		if (UART_MEM_OUT[7:0] == 8'h6C)
			$display("l");
		if (UART_MEM_OUT[7:0] == 8'h6D)
			$display("m");
		if (UART_MEM_OUT[7:0] == 8'h6E)
			$display("n");
		if (UART_MEM_OUT[7:0] == 8'h6F)
			$display("o");
		if (UART_MEM_OUT[7:0] == 8'h70)
			$display("p");	
		if (UART_MEM_OUT[7:0] == 8'h71)
			$display("q");
		if (UART_MEM_OUT[7:0] == 8'h72)
			$display("r");
		if (UART_MEM_OUT[7:0] == 8'h73)
			$display("s");
		if (UART_MEM_OUT[7:0] == 8'h74)
			$display("t");
		if (UART_MEM_OUT[7:0] == 8'h75)
			$display("u");
		if (UART_MEM_OUT[7:0] == 8'h76)
			$display("v");
		if (UART_MEM_OUT[7:0] == 8'h77)
			$display("w");
		if (UART_MEM_OUT[7:0] == 8'h78)
			$display("x");
		if (UART_MEM_OUT[7:0] == 8'h79)
			$display("y");
		if (UART_MEM_OUT[7:0] == 8'h7A)
			$display("z");
		if (UART_MEM_OUT[7:0] == 8'h7B)
			$display("{");
		if (UART_MEM_OUT[7:0] == 8'h7C)
			$display("|");
		if (UART_MEM_OUT[7:0] == 8'h7D)
			$display("}");
		if (UART_MEM_OUT[7:0] == 8'h7E)
			$display("~");
		if (UART_MEM_OUT[7:0] == 8'h7F)
			$display(" ");
		rxstate <= 3'b000;
   		rxbusy <= 0;
   	end
end


always @*
if (txready && (bufcnt < buftot) && tx_trig)
	txstart = 1;
else
	txstart = 0;



always @(posedge clk)
begin
	if (txstart && txstate == 3'b000)
	begin
	    tx <= 1'b0;
	    txstate <= 3'b001;
	    txready <= 0;
	    txbitcnt <= 0;
	    txbaudcnt <= 0;
	end
	else if (txstate == 3'b001)
	begin
	    if (txbaudcnt >= totalticks)
	    begin
    		txbaudcnt <= 0;
    		tx <= buffer[bufcnt][txbitcnt];
	       	txbitcnt <= txbitcnt + 1;
		    if (indicators)
	    		$display("TB TX IS %b and bit = %d", tx, txbitcnt);
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
	    if (txbaudcnt >= totalticks)
	    begin
	    	if (indicators)
	    			$display("TB TX IS %b and bit = %d", tx, txbitcnt);
	        tx <= 1;
	        txbaudcnt <= 0;
	        txstate <= 3'b011;
	    end
	    else
	    txbaudcnt <= txbaudcnt + 1;
	end
	else if (txstate == 3'b011)
	begin
	    if (txbaudcnt >= totalticks)
	    begin
	    	if (indicators)
	    			$display("TB TX IS %b and bit = %d", tx, txbitcnt);
	        txbaudcnt <= 0;
	        txstate <= 3'b100;
	    end
	    else
	    txbaudcnt <= txbaudcnt + 1;
	end
	else if (txstate == 3'b100)
	begin
	    if (txbaudcnt == totalticks*10)
	    begin
	        txbaudcnt <= 0;
	        txstate <= 3'b000;
	        txready <= 1;
	        bufcnt <= bufcnt + 1;
	    end
	    else
	    txbaudcnt <= txbaudcnt + 1;
	end
end



	
endmodule

