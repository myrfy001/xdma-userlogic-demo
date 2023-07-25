set dir_output $::env(DIR_OUTPUT)
set dir_rtl $::env(DIR_RTL)
set dir_xdc $::env(DIR_XDC)
set dir_ips $::env(DIR_IPS)
set part $::env(PART)

file mkdir $dir_output



set_param general.maxthreads 24
set device [get_parts $part]; # xcvu13p-fhgb2104-2-i; #
set_part $device


# read_verilog [ glob $dir_rtl/*.v ]
read_xdc [ glob $dir_xdc/*.xdc ]


foreach file [ glob $dir_ips/**/*.tcl] {
    source $file
}

report_property $device -file $dir_output/pre_synth_dev_prop.rpt
generate_target all [ get_ips * ]