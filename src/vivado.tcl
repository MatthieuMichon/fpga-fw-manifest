package require Vivado

proc parse_named_arguments {arg_list} {
    # convert a list of argument pairs into a dictionary

    set arg_dict {}
    foreach arg_pair $arg_list {
        if {[regexp {([^=]+)=(.+)} $arg_pair -> key value]} {
            dict set arg_dict $key $value
        }
    }
    return $arg_dict
}

proc build {arg_dict} {
    # build the firmware

    create_project -part [dict get $arg_dict PART] -in_memory
    report_property [get_parts -of [current_project]] -file part_properties.txt
    read_verilog -sv [glob ../src/*.sv]
    read_xdc [glob ../src/*.xdc]

    # build in performance mode because why not
    synth_design -top [lindex [find_top] 0] \
        -directive PerformanceOptimized \
        -debug_log -verbose
    opt_design \
        -debug_log -verbose
    place_design \
        -directive ExtraPostPlacementOpt \
        -timing_summary \
        -debug_log -verbose
    phys_opt_design \
        -directive AggressiveExplore \
        -verbose
    route_design \
        -directive Explore \
        -tns_cleanup \
        -debug_log -verbose
    phys_opt_design \
        -directive AggressiveExplore \
        -verbose

    report_clock_utilization -file clock_utilization.txt
    report_design_analysis -file design_analysis_report.txt -quiet
    report_io -file io.txt
    report_methodology -no_waivers -file methodology_report.txt
    report_operating_conditions -file operating_conditions.txt
    report_power -file power.txt
    report_qor_assessment -file qor_assessment_report.txt -full_assessment_details -quiet
    report_qor_suggestions -file qor_suggestions_report.txt -report_all_suggestions -quiet
    report_ram_utilization -file ram_utilization.txt
    report_timing -slack_lesser_than 0.010 -max_paths 99 -file timing.txt
    report_utilization -file utilization.txt

    write_checkpoint -force project.dcp

    set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
    set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]
    set_property BITSTREAM.CONFIG.USERID [dict get $arg_dict GIT_COMMIT] [current_design]
    write_bitstream -force -logic_location_file -file fpga.bit -verbose

}

proc configure {} {

    open_hw_manager -quiet
    connect_hw_server -quiet
    open_hw_target -quiet
    set_property PROGRAM.FILE [glob *.bit] [current_hw_device]
    program_hw_devices [current_hw_device]
    refresh_hw_device -quiet

}

proc report_manifest {} {

    # compute IR length of the complete JTAG chain (ARM DAPs)
    set jtag_taps 0
    set total_ir_length 0
    foreach hw_device [get_hw_devices] {
        set index [get_property INDEX $hw_device]
        report_property $hw_device -file hw_device_${index}_properties.txt
        incr total_ir_length [get_property IR_LENGTH $hw_device]
        incr jtag_taps
    }

    # connect to board in *expert* mode
    open_hw_manager -quiet
    connect_hw_server -quiet
    open_hw_target -quiet
    close_hw_target -quiet
    open_hw_target -jtag_mode on -quiet

    # WARNING:
    # THE FOLLOWING IR AND DR LENGTHS AND VALUES ARE HARD-CODED FOR ZYNQ-7 

    # set FPGA PL TAP IR to USER4
    run_state_hw_jtag RESET
    run_state_hw_jtag IDLE
    scan_ir_hw_jtag 10 -tdi 3E3

    # dump manifest ROM stop at first empty word (assume filled with zeros)
    set fh [open manifest.csv w]
    set tap_rd_data 0xFFFFFFFF
    set tap_wr_data_dec [expr 0xA000]
    while {$tap_rd_data != {0x00000000}} {
        run_state_hw_jtag IDLE
        scan_dr_hw_jtag 17 -tdi [format %04x $tap_wr_data_dec]
        run_state_hw_jtag IDLE
        set tap_rd_data 0x[scan_dr_hw_jtag 32 -tdi 0]

        puts $fh "0x[format %04x $tap_wr_data_dec],$tap_rd_data"
        incr tap_wr_data_dec
    }
    flush $fh
}

set arg_dict [::parse_named_arguments $argv]

switch [dict get $arg_dict TASK] {
    "all" {
        ::build $arg_dict
        ::configure
        ::report_manifest
    }
    "build" {
        ::build $arg_dict
    }
    "configure" {
        ::configure
    }
    "report_manifest" {
        ::report_manifest
    }
}
