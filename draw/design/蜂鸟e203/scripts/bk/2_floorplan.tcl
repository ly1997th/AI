create_die_area  \
        -poly { {0.000 0.000} {2000.000 0.000} {2000.000 500.000} {0.000 500.000} }

create_floorplan -control_type boundary -start_first_row -flip_first_row -left_io2core 20 -bottom_io2core 20 -right_io2core 20 -top_io2core 20

create_fp_virtual_pad -net VDD -point {10.000 100.000}
create_fp_virtual_pad -net VSS -point {100.000 10.000}
create_fp_virtual_pad -net VDD -point {1861.000 425.90}
create_fp_virtual_pad -net VSS -point {425.90 10.000}
create_fp_virtual_pad -net VDD -point {1861.000 10.000}
create_fp_virtual_pad -net VSS -point {1771.000 10.000}
create_fp_virtual_pad -net VDD -point {10.000 1771.000}
create_fp_virtual_pad -net VSS -point {10.000 1861.000}

save_mw_cel -as 2_floorplan

