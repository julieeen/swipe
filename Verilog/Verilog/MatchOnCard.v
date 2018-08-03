`timescale 1ms / 1ps 

module MatchOnCard(

  // SPI slave interface (card to board)
  input wire CSN_cpu,
  output wire MISO_cpu,
  input wire SPICLK_cpu,
  input wire MOSI_cpu,

// the senor messages can be passed through the CPLD into the CPU
// or we dismiss them and inject our own data :)
  input wire MISO_sensor,
// the other signals going to the sensor are bypassing the CPLD,
// becaue there is no need to redirect them (we simply copy them)
//  output wire CSN_sensor,  
//  output wire SPICLK_sensor,
//  output wire MOSI_sensor,
  
  // SPI master interface (board to board)
  output wire mem_spi_en,
  input wire mem_spi_miso,
  output wire mem_spi_clk,
  output wire mem_spi_mosi,
  
  input SYSCLK,
  output reg SYSCLKout = 0,
  
  input key0, // low active
  input key1,
  
  output reg testout = 0, 
  output wire time_trigger,
  output reg LED0 = 0,       // low active, LED = 0 will light up
  output reg LED1 = 0 
);

reg CSN_cpu_sync = 0;
reg SPICLK_cpu_sync = 0;
reg MOSI_cpu_sync = 0;

wire [7:0] cpu_cmd_wire;

wire slave_valid;
reg slave_valid_syc = 0;

reg [7:0] sensor_out = 8'h00;
reg CSN_manual = 1'b0;

// SPI slave "sensor"
wire MISO_cpu_spoofed;
spi_slave slave(
   .CPOL(1'b0), 
   .CPHA(1'b0),
	
   .datai( sensor_out ),   // answer from "sensor"
   .datao( cpu_cmd_wire ), // cmds from cpu
	
   .csb( CSN_cpu ),// | CSN_manual ),  // slave needs a manual "reset" after each iteration
	//.csb(CSN_manual),
   .din( MOSI_cpu ),
   .sclk( SPICLK_cpu ),
   .dout( MISO_cpu_spoofed ),
   .valid( slave_valid )
);

// SPI interface to "memory" (cyclone IV)
wire [3:0] clk_divider = 6;
wire [7:0] mem_spi_data_get; 
reg [7:0] mem_spi_data_get_sync = 8'h00;
reg [7:0] mem_spi_data_send = 8'hAA;
reg mem_spi_go = 0;
wire mem_spi_busy;
reg mem_spi_busy_sync;
reg mem_spi_reset = 1'b1;

spi_master spi_i(
   .clk(SYSCLK),
   .resetb(mem_spi_reset), // low active

   .CPOL(1'b0), 
   .CPHA(1'b0),
   .clk_divider(clk_divider),
  
   .go(mem_spi_go),
   .datai(mem_spi_data_send), // data we will send to mem
   //.datai(8'hAA),
	.datao(mem_spi_data_get),  // data we will receive from mem
   .busy(mem_spi_busy),
   .done(),
   
   .csb(mem_spi_en),  
   .din(mem_spi_mosi),  // data we send (master -> slave)
   .sclk(mem_spi_clk),
   .dout(mem_spi_miso)  // data we get (slave -> master)
);

// mode 0: spoof // Mode 1: pass through
reg mode = 1'b0;
assign MISO_cpu = (mode == 1'b1) ? MISO_sensor : MISO_cpu_spoofed;

reg [15:0] wakeup_timeout = 16'h0;
reg [15:0] state = 16'h0000;
reg [31:0] auto_reset_cnt = 32'h0;	
reg [31:0] timeattack_cnt = 32'h0;
reg timeattack_trigger = 1'b0;	
reg [7:0] cnt_c4 = 8'h0;

assign time_trigger = (timeattack_trigger &  MOSI_cpu) ? 1'b1 : 1'b0;

always @ (posedge SYSCLK) begin
	SYSCLKout <= !SYSCLKout;
	mem_spi_data_send <= cpu_cmd_wire;	
	mem_spi_go <= mem_spi_go;
	state <= state;
	slave_valid_syc <= slave_valid;
	wakeup_timeout <= wakeup_timeout;
	mem_spi_reset <= mem_spi_reset;
	CSN_manual <= CSN_manual;
	mem_spi_busy_sync <= mem_spi_busy;
	mode <= mode;
	timeattack_trigger <= timeattack_trigger;
	timeattack_cnt <= timeattack_cnt;
	
	// sample the inputs
	CSN_cpu_sync <= CSN_cpu;
	SPICLK_cpu_sync <= SPICLK_cpu;
	MOSI_cpu_sync <= MOSI_cpu;
		
	mem_spi_data_get_sync <= mem_spi_data_get;

	// spoof mode
	if(key0 == 0) begin // key pushed?
		state <= 16'h0000;
		wakeup_timeout <= 0;
		LED0 <= 1'b0;
		LED1 <= 1'b0;
		mode <= 1'b0;
	end
	
	// pass through mode 
	if(key1 == 0) begin // key pushed?
		state <= 16'h00;
		LED0 <= 1'b1;
		LED1 <= 1'b1;
		mode <= 1'b1;
	end
	
	//testout <= slave_valid;
	//testout <= state[0];
	//testout <= timeattack_trigger;
	//testout <= timeattack_cnt[0];
	testout <= cnt_c4[0];
	//testout <= mem_spi_reset;
	//testout <= auto_reset_cnt[3];
	// testout <= wakeup_timeout[3];
	//testout <= CSN_manual;
	
	// reset state machine after 0.5 seconds, when SPI gets inactive :)
	// x = 0,5s / 0,00000004s = 25.000.000 = 0xBEBC20
	if( state > 16'h0000) begin
		if((CSN_cpu_sync == 1'b0) & (SPICLK_cpu_sync == 1'b0) & (MOSI_cpu_sync == 1'b0) ) begin
			auto_reset_cnt <= auto_reset_cnt + 1;
			if(auto_reset_cnt > 32'hBEBC20) begin
				auto_reset_cnt <= 32'h0;
				state <= 16'h0;
			end
		end
		else begin
			auto_reset_cnt <= 32'h0;
		end
	end
	
	case(state)
	
		// wait for spi wakeup ...
		// wait until enabel & mosi == 1 and clk == 0 are solid for 1,9 ms ...
		16'h0000: begin 
			if((CSN_cpu_sync == 1'b1) & (SPICLK_cpu_sync == 1'b0) & (MOSI_cpu_sync == 1'b1) ) begin
				wakeup_timeout <= wakeup_timeout + 1;
			end
			else begin
				wakeup_timeout <= 16'h0;
			end
			// 0,00004 ms (25 MHz)  * x = 1,9 ms --> 47.500, 0xB98C
			if(wakeup_timeout > 16'h005CC6) begin
				state <= state + 1;
			end

			// SKIP THIS IN SIMU :)
			//#1 state <= state + 1;
			// *****************
			sensor_out <= 8'h00;
			mem_spi_reset <= 1'b0;
		end
		
		// wait for first message, which is always 0xFC
		// wait until value is hold some cylces ...
		16'h0001: begin
			//CSN_manual <= 1'b0;
			sensor_out <= 8'h00;
			timeattack_cnt <= 32'h0;
			timeattack_trigger <= 1'b0;
			cnt_c4 <= 8'h0;
			if(mem_spi_data_send == 8'hFC) begin
				state <= state + 1;
				mem_spi_reset <= 1'b1;
			end
		end
		
		// now fetch the next respone from mem (START OF THE STATE MACHINE)
		16'h0002: begin
			state <= state + 1;
			mem_spi_go <= 1;
			
			// use c4 signal to count bytes for a meanigful trigger signal
			if(mem_spi_data_send == 8'hC4) begin
				cnt_c4 <= cnt_c4 + 1;
			end
			
		end
		// wait for mem getting busy
		16'h0003: begin 
			if(mem_spi_busy_sync == 1) begin
				state <= state + 1;
				mem_spi_go <= 0;
			end
		end
		// wait til memory read finished
		16'h0004: begin 
			//CSN_manual <= 1'b0;  // stop flush
			if(mem_spi_busy_sync == 0) begin
				state <= state + 1;
			end
		end
		// store mem value as next spi answer
		16'h0005: begin
			sensor_out <= mem_spi_data_get_sync;
			//sensor_out <= 8'h02;
			//sensor_out <= mem_spi_data_get;
			state <= state + 1;
		end
		// wait til cpu consumed value...
		16'h0006: begin 
			if(slave_valid_syc == 0) begin
				state <= state + 1;
				
				// after x times 0xc4 + 0x9000 bytes, the trigger shall occur
				if(cnt_c4 == 8'd2)begin
					timeattack_cnt <= timeattack_cnt + 1;
				end
				if(timeattack_cnt == 16'h9000) begin    // trigger for enrol, finger 2
					timeattack_trigger <= 1'b1;
				end
				else begin
					timeattack_trigger <= 1'b0;
				end
			end
		end
		// and get the next value from mem ...
		16'h0007: begin 
			if(slave_valid_syc == 1) begin
				state <= 16'h0002;		
		
	
			end			
		end
		
	endcase
end


endmodule
