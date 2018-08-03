
module toplevel (
    input sys_clk_pad_i,

	 output reg [7:0]   leds = 0,  // LEDs
	 input key0,
	 input key1,
	
	 // COMM interfaces
//	 input pc_comm_rx, 			// uart reciver pin
//	 output pc_comm_tx, 			// uart reciver pin
	 input pc_spi_en,
	 output pc_spi_miso,
	 input pc_spi_clk,
	 input pc_spi_mosi,
	 
	 input spi_en,
	 inout spi_in,				   // take this as "inout", because there is some mixup with inputs and outputs ...
	 input spi_clk,
	 inout spi_out,
	 
	 output reg ext_clk = 1'b0,
	
	 // SDRAM I/Os, do not touch
    output [1:0]  sdram_ba_pad_o,
    output [12:0] sdram_a_pad_o,
    output        sdram_cs_n_pad_o,
    output        sdram_ras_pad_o,
    output        sdram_cas_pad_o,
    output        sdram_we_pad_o,
	 inout  [15:0] sdram_dq_pad_io,
    output [1:0]  sdram_dqm_pad_o,
    output        sdram_cke_pad_o,
    output        sdram_clk_pad_o
);

wire clk100m;
assign sdram_clk_pad_o = clk100m;
// PLLs, to generate a 100MHz clock
pll_100m pll_100mi (
    .inclk0      (sys_clk_pad_i),
    .c0          (clk100m)
);

// sdram_out_data hold data we get from the mem
wire [15:0] sdram_out_data_bus;
reg [15:0] sdram_out_data = 16'h0000;
// sdram_in_data hold data we want to write to mem
reg [15:0] sdram_in_data = 16'h0000; 

reg [23:0] sdram_write_add = 24'h000000;
reg [23:0] sdram_read_add = 24'h000000;

// sdram core controls
wire ctrl_busy;			// signal sdram core operational state
reg ctrl_busy_sync;
wire ctrl_rd_ready;     // ready
reg reset = 0; 			// init with 0 and keep 1 during operation
reg write_enable = 0;	// pull high to write
reg read_enable = 0;    // pull high to read


/* SDRAM */
sdram_controller sdram_controlleri (
    /* HOST INTERFACE */
    .wr_addr       (sdram_write_add),
    .wr_data       (sdram_in_data),
    .wr_enable     (write_enable), 

    .rd_addr       (sdram_read_add), 
    .rd_data       (sdram_out_data_bus),
    .rd_ready      (ctrl_rd_ready),
    .rd_enable     (read_enable),
    
    .busy          (ctrl_busy),
    .rst_n         (reset),
    .clk           (clk100m),

    /* SDRAM SIDE, Do Not Change! */
    .addr          (sdram_a_pad_o),
    .bank_addr     (sdram_ba_pad_o),
    .data          (sdram_dq_pad_io),
    .clock_enable  (sdram_cke_pad_o),
    .cs_n          (sdram_cs_n_pad_o),
    .ras_n         (sdram_ras_pad_o),
    .cas_n         (sdram_cas_pad_o),
    .we_n          (sdram_we_pad_o),
    .data_mask_low (sdram_dqm_pad_o[0]),
    .data_mask_high(sdram_dqm_pad_o[1])
);

// COMM inetrface to communicate with PC
reg [7:0] pc_slave_write = 8'h00;
wire [7:0] pc_slave_read;
wire pc_slave_valid;
reg pc_slave_valid_sync;
spi_slave pc_slave(
   .CPOL(1'b0), 
   .CPHA(1'b0),
	
   .datai( pc_slave_write ),    // msg going to PC
   //.datai( sdram_write_add[7:0] ),   // answer from cyclone to pc
	.datao( pc_slave_read ),    // msg comming from PC
	
   .csb( pc_spi_en ),
   .din( pc_spi_mosi ),
   .sclk( pc_spi_clk ),
   .dout( pc_spi_miso ),
   .valid( pc_slave_valid )
);


reg [15:0] last_read_data = 16'hFF00;

// COMM inetrface to communicate with MAX V
reg spi_valid_sync;
wire spi_valid;
wire [7:0] cpu_cmd;
reg [7:0] cpu_cmd_sync;
spi_slave mem_slave(
   .CPOL(1'b0), 
   .CPHA(1'b0),
   
   .datai(last_read_data[7:0]),  // what we send
   .datao(cpu_cmd), 			 		// data that is recieved from board ...
   
   .csb(spi_en),
   .din(spi_in),
   .sclk(spi_clk),
   .dout(spi_out),
   
   .valid(spi_valid)
);



reg [15:0] state = 16'h0000;
reg [15:0] setup_cnt = 16'h00FF;
reg [31:0] timeout = 32'h0;

reg spi_en_sync;
reg [2:0] ext_clk_gen = 3'b000;
reg [31:0] inactive_read_mode_cnt = 32'h0;

//clk_div3 clkdivmodul(
//	.clk(clk100m),
//	.reset(1'b0),
//	.clk_out(ext_clk)
//);

always @ (posedge clk100m) begin

	ext_clk_gen <= ext_clk_gen + 1;
	if(ext_clk_gen == 1) begin
		ext_clk <= !ext_clk;
		ext_clk_gen <= 3'b000;
	end
		
	state <= state;
	write_enable <= write_enable;
	read_enable <= read_enable;
	sdram_in_data <= sdram_in_data;
	sdram_out_data <= sdram_out_data_bus;
	sdram_write_add <= sdram_write_add;
	sdram_read_add <= sdram_read_add;
	reset <= 1'b1;
	last_read_data <= last_read_data;
	
	pc_slave_valid_sync <= pc_slave_valid;
	pc_slave_write <= pc_slave_write;
	
	spi_valid_sync <= spi_valid;
	spi_en_sync <= spi_en;
	ctrl_busy_sync <= ctrl_busy;
	cpu_cmd_sync <= cpu_cmd;

	//leds <= state[7:0];
	//leds <= last_read_data[7:0];
	//leds <= {last_read_data[7:4], state[3:0]};
	leds <= {sdram_read_add[7:4], state[3:0]};

	// write mode
	if(~key0) begin
		state <= 16'h0001;
		pc_slave_write <= 8'h00;
		sdram_write_add <= 24'h000000;
	end
	
	// read mode
	if(~key1) begin
		// disable key for some sec here ...
		state <= 16'h0006;
		sdram_read_add <= 24'h000000;
	end
	
	
	// autom. realign of blob during read mode (after 5s of inactivity)
	if(state >= 16'h0006) begin
		inactive_read_mode_cnt <= inactive_read_mode_cnt + 1;
		if(inactive_read_mode_cnt >= 32'hBEBC200) begin
				state <= 16'h0006;
				sdram_read_add <= 24'h000000;
				inactive_read_mode_cnt <= 32'h0;
		end
	end
	
	case(state)
		// wait some clkcycles to init the mem controller
		// reset all the elements ...
		16'h0000: begin 	
			if(setup_cnt > 0) begin
				setup_cnt <= setup_cnt - 1;
				reset <= 1'b0;
			end
			if(setup_cnt == 0) begin
				reset <= 1'b1;
				state <= state + 1;
			end
		end
		
		// This is the entry point of our FSM
		16'h0001: begin 
			// wait til SPI goes busy, ....
			if(pc_slave_valid_sync == 0) begin
				state <= state + 1;
			end
		end
		
		16'h0002: begin
			// wait til spi is valid again ...
			if(pc_slave_valid_sync == 1) begin
				sdram_in_data <= {16'h0000, pc_slave_read};
				pc_slave_write <= pc_slave_read;
				state <= state + 1;
			end
		end
		
		// write data to sdram @ sdram_write_add
		16'h0003: begin  // sdram write enable
			if(ctrl_busy_sync == 0) begin
				write_enable <= 1'b1;
			end
			else begin
				state <= state + 1;
				write_enable <= 1'b0;
			end
		end
		16'h0004: begin  // wait for finish write
			if(ctrl_busy_sync == 0) begin
				state <= state + 1;
			end
		end
		
		16'h0005: begin  // return to read next from UART
			state <= 16'h0001;
			sdram_write_add <= sdram_write_add + 1;
		end
		
		


		// read data from sdram @ sdram_read_add
		16'h0006: begin  // sdram read enable
			if(ctrl_busy_sync == 0) begin
				read_enable <= 1'b1;
			end
			else begin
				state <= state + 1;
				read_enable <= 1'b0;
			end
		end
		16'h0007: begin  // wait for finish read
			if(ctrl_busy_sync == 0) begin
				state <= state + 1;
				last_read_data <= sdram_out_data;

				// if more read than written, just give 0x00
				if((sdram_read_add+1) > sdram_write_add) begin
					last_read_data <= 8'h00;
				end

				//last_read_data <= 8'h3F;
				//last_read_data <= last_read_data + 1;
			end
		end
		16'h0008: begin  
			// wait til spi gets busy
			if(spi_valid_sync == 0) begin
				// spi read now
				state <= state + 1;
				inactive_read_mode_cnt <= 32'h0;
			end
		end
		// after value handed, read next value from mem
		16'h0009: begin  
			if(spi_valid_sync == 1) begin 
				state <= state + 1;
			end
		end
		// finally, fetch next value from mem
		16'h000A: begin  
			// spi finished now
			state <= 16'h0006; 
			sdram_read_add <= sdram_read_add + 1;
		end
		
	endcase

end


endmodule
