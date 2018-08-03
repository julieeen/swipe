
NOTE: Our implementation will not easily work out of the box,
because it is bound to the specific devices we have used and
requires some proprietary Software Components (Quartus II).
Anyhow, the Verilog code can be synthesized on any other FPGA and
hence can be used as a reference implementation for educational
purposes or to test similar devices.

The Design is built out of four main components.
1. An SPI Interface directly attached to the card
2. The MatchOnCard Module to spoof or pass-though the data
3. An SPI Interface to fetch data from the SDRAM
4. An SDRAM controller to access the memory and program it via UART

THIS DESIGN WAS BUILT WITH OPEN SOURCE COMPONENTS.

The SDRAM memory controller was built by Stafford Horne.
https://github.com/stffrdhrn/sdram-controller

The UART modules were built by Dmitry Nedospasov and Thorsten Schroeder.
Die Datenkrake (DDK). https://github.com/ddk

The SPI master module was built by Lane Brooks.
https://github.com/ksnieck/spi_master/blob/master/spi_master.v

THANKS A LOT TO ALL OF YOU!
