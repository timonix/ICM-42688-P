set_device GW1NR-LV9QN88PC6/I5 -name GW1NR-9C
add_file brute_42688.vhd
add_file brute_pkg.vhd
add_file ICM_timing_pkg.vhd
add_file tb_brute_42688.vhd
add_file top_brute.vhd
add_file top_brute.cst
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -rw_check_on_ram 1
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
set_option -vhdl_std vhd2008
set_option -gen_sdf 0
set_option -gen_posp 0
set_option -top_module top_brute
run all
