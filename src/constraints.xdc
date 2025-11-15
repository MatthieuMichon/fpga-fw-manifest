# shocked that 250 MHz JTAG clock actually closes STA on Zynq-7020
create_clock -name TCK -period 4 [get_pins */TCK]
