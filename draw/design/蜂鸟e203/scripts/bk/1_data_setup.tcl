#this is the setting for csmc130nm technology
#change to library V1.0
#
set std_path "/home/riscv/Soc/conv_icc/ref/db"
set tech_file_path "/home/riscv/Soc/conv_icc/ref/tf"

set search_path [list $std_path/ \
                    $tech_file_path/ ]

#target library-----------------------------------------------------------
set     target_library         saed32rvt_ff1p16vn40c.db
set     io_library             ""
set     link_library            "* $target_library $io_library"

#create library
create_mw_lib  -technology  /home/riscv/Soc/conv_icc/ref/tf/saed32nm_1p9m_mw.tf     \
               -mw_reference_library {/home/riscv/Soc/conv_icc/ref/mw_lib/saed32nm_rvt_1p9m} \
               -hier_separator {/} \
               -bus_naming_style {[%d]} \
               -open  /home/riscv/Soc/conv_icc/design_data/top_digital.mw

set_check_library_options -all

#set TLU+ files
set_tlu_plus_files   -max_tluplus   /home/riscv/Soc/conv_icc/ref/tluplus/saed32nm_1p9m_Cmax.tluplus     \
                     -min_tluplus   /home/riscv/Soc/conv_icc/ref/tluplus/saed32nm_1p9m_Cmin.tluplus     \
                     -tech2itf_map  /home/riscv/Soc/conv_icc/ref/tluplus/saed32nm_tf_itf_tluplus.map
#                                     -tech2itf_map  /home/library/wxsh/0d13um/VS013/BEView_STDIO/VS-CSMC-13-Tapeout-Kit-V0.5/TECH/CSMC013E_layer_m6.map

check_tlu_plus_files
list_libs

#import designs
import_designs -format verilog /home/riscv/Soc/conv_dc_SRAM/mapped/sirv_conv_slv.mapped.v

derive_pg_connection -power_net VDD -power_pin VDD -ground_net VSS -ground_pin VSS
derive_pg_connection -power_net VDD -ground_net VSS -tie
check_mv_design -power_nets

read_sdc /home/riscv/Soc/conv_dc_SRAM/mapped/sirv_conv_slv.sdc
check_timing
report_timing_requirements
report_disable_timing
report_case_analysis
report_clock -skew

set_fix_multiple_port_nets -all -buffer_constants
save_mw_cel -as 1_data_setup
