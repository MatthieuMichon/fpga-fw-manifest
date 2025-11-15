`default_nettype none
`timescale 1ns/1ps

module manifest; // self contained

localparam MANIFEST_HEX_FILE = "manifest.hex";
localparam logic [4-1:0] READ_CMD_MSB = 4'hA; // ignore zero-filled cmd
localparam int USER4 = 4; // 1 and 2 reserved, 3 and 4 available

localparam int ADDR_WIDTH = 10; // 32 kbit shall be enough
localparam int DATA_WIDTH = 32;
typedef logic [ADDR_WIDTH-1:0] addr_t;
typedef logic [DATA_WIDTH-1:0] data_t;

data_t rom [0:1023];
initial $readmemh(MANIFEST_HEX_FILE, rom);

addr_t addr;
data_t data;
logic tck, tdi, tdo;
always_ff @(posedge tck) data <= rom[addr];

logic tap_test_logic_reset, tap_run_test_idle, tap_ir_user_defined;
logic tap_capture_dr, tap_shift_dr, tap_update_dr;

BSCANE2 #(
    .JTAG_CHAIN(USER4)
) bscane2_manifest (
    .TCK(tck),
    .TDI(tdi), // inbound TDI signal, LSB first
    .TDO(tdo), // outbound TDO signal, LSB first

    // PL TAP controller states
    .RESET(tap_test_logic_reset),
    .RUNTEST(tap_run_test_idle),
    .SEL(tap_ir_user_defined), // IR = USER<JTAG_CHAIN>
    .CAPTURE(tap_capture_dr),
    .SHIFT(tap_shift_dr),
    .UPDATE(tap_update_dr)
);

logic [16-1:0] tdi_shift_reg; // act if set to 0b1010_xxxx_xxxx_xxxx

always_ff @(posedge tck) begin: read_addr_from_tap
    if (tap_test_logic_reset) begin // PL TAP in Test-Logic-Reset state
        tdi_shift_reg <= '0;
        addr <= '0;
    end else if (tap_ir_user_defined) begin // IR = USER<JTAG_CHAIN>
        if (tap_shift_dr) // PL TAP in Shift-DR state
            tdi_shift_reg <= {tdi, tdi_shift_reg[16-1:1]};
        else if (tap_update_dr) // PL TAP in Update-DR state
            if (tdi_shift_reg[16-1:12] == READ_CMD_MSB) // filter unrelated cmd
                addr <= tdi_shift_reg[ADDR_WIDTH-1:0];
    end
end

data_t tdo_shift_reg;

always_ff @(posedge tck) begin: write_data_to_tap
    if (tap_test_logic_reset) begin
        tdo_shift_reg <= '0;
    end else if (tap_ir_user_defined) begin
        if (tap_capture_dr) // PL TAP in Capture-DR state
            tdo_shift_reg <= data;
        else if (tap_shift_dr)
            tdo_shift_reg <= {tdi, tdo_shift_reg[DATA_WIDTH-1:1]};
    end
end

assign tdo = tdo_shift_reg[0];

endmodule
`default_nettype wire
