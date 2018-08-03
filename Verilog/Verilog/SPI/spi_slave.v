
module spi_slave(
   input CPOL, 
   input CPHA,
   
   input [7:0] datai,
   output reg [7:0] datao,
   
   output dout,
   input din,
   input csb,
   input sclk,

   output valid
   );

  reg [2:0] bit_cnt = 3'h0;

  assign valid = ((bit_cnt == 0)) ? 1 : 0;

  assign dout = (csb == 0) ? datai[7-bit_cnt] : 0;

  always @(posedge sclk or posedge csb) begin
    if (csb == 1) begin
      // reset
    end
    else if (csb == 0) begin
      // communicate
      if(sclk == 1) begin
        datao[7-bit_cnt] <= din;
      end
    end
  end

  always @(negedge sclk or posedge csb) begin
    if (csb == 1) begin
      // reset
      bit_cnt = 3'h0;
    end
    else if (csb == 0) begin
      bit_cnt <= bit_cnt + 1;
    end
  end

endmodule
   