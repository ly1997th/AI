#read_verilog 
#set rtl_dir /home/student/Desktop/Soc_lab1/DC/rtl/e203
set rtl_dir ../rtl/conv

define_design_lib WORK -path WORK
analyze -format verilog [glob $rtl_dir/*.v]

elaborate $top


#read_verilog -rtl [glob $rtl_dir/*.v]
elaborate WORK -library [glob $std_path/*.db]