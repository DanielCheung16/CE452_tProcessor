# *****************************************************************************************
# Minimal Vivado project recreation script for tproc_452
# - Create project under script directory
# - Add source / constraint / simulation files
# - No synth/impl run customization
# - No DCP / incremental checkpoint dependency
# *****************************************************************************************

# Script directory
set origin_dir [file dirname [file normalize [info script]]]

# Allow override from command line if desired
if { [info exists ::origin_dir_loc] } {
  set origin_dir [file normalize $::origin_dir_loc]
}

# Project name
set _xil_proj_name_ "tproc_452"
if { [info exists ::user_project_name] } {
  set _xil_proj_name_ $::user_project_name
}

puts "origin_dir = $origin_dir"
puts "project_dir = [file normalize "$origin_dir/${_xil_proj_name_}"]"

# Create project
create_project -force ${_xil_proj_name_} [file normalize "$origin_dir/${_xil_proj_name_}"] -part xczu48dr-ffvg1517-2-e

# Current project handle
set proj_obj [current_project]
set proj_dir [get_property directory $proj_obj]

# Basic project properties
set_property board_part "realdigital.org:rfsoc4x2:part0:1.0" $proj_obj
set_property default_lib "xil_defaultlib" $proj_obj
set_property enable_resource_estimation 0 $proj_obj
set_property enable_vhdl_2008 1 $proj_obj
set_property ip_cache_permissions {read write} $proj_obj
set_property ip_output_repo "$proj_dir/${_xil_proj_name_}.cache/ip" $proj_obj
set_property mem.enable_memory_map_generation 1 $proj_obj
set_property platform.board_id "rfsoc4x2" $proj_obj
set_property revised_directory_structure 1 $proj_obj
set_property sim.central_dir "$proj_dir/${_xil_proj_name_}.ip_user_files" $proj_obj
set_property sim.ip.auto_export_scripts 1 $proj_obj
set_property simulator_language Mixed $proj_obj

# ------------------------------------------------------------------------------
# sources_1
# ------------------------------------------------------------------------------
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}
set srcset [get_filesets sources_1]

set src_files [list \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/dsp_macro_0/dsp_macro_0.xci"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/axis_read.v"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/axis_write.v"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/data_mem_ctrl.v"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/mem_rw.v"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qcore_mem.v"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qproc_mem_ctrl.v"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/_qproc_defines.svh"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/_qproc_ips.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qcore_cpu.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qcore_ctrl_hazard.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qcore_reg_bank.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qick_processor_452.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qproc_axi_reg.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qproc_core.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qproc_ctrl.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qproc_dispatcher.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qproc_inport_reg.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qproc_time_ctrl.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/axi_slv_qproc.vhd"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/axis_qick_processor.sv"] \
]
add_files -norecurse -fileset $srcset $src_files

# File type fixes
foreach f [list \
 "${origin_dir}/../ip/qick_processor_452/src/_qproc_defines.svh" \
] {
  set fobj [get_files -of_objects $srcset [list "*[file normalize $f]"]]
  if {$fobj ne ""} { set_property file_type {Verilog Header} $fobj }
}

foreach f [list \
 "${origin_dir}/../ip/qick_processor_452/src/_qproc_ips.sv" \
 "${origin_dir}/../ip/qick_processor_452/src/qcore_cpu.sv" \
 "${origin_dir}/../ip/qick_processor_452/src/qcore_ctrl_hazard.sv" \
 "${origin_dir}/../ip/qick_processor_452/src/qcore_reg_bank.sv" \
 "${origin_dir}/../ip/qick_processor_452/src/qick_processor_452.sv" \
 "${origin_dir}/../ip/qick_processor_452/src/qproc_axi_reg.sv" \
 "${origin_dir}/../ip/qick_processor_452/src/qproc_core.sv" \
 "${origin_dir}/../ip/qick_processor_452/src/qproc_ctrl.sv" \
 "${origin_dir}/../ip/qick_processor_452/src/qproc_dispatcher.sv" \
 "${origin_dir}/../ip/qick_processor_452/src/qproc_inport_reg.sv" \
 "${origin_dir}/../ip/qick_processor_452/src/qproc_time_ctrl.sv" \
 "${origin_dir}/../ip/qick_processor_452/src/axis_qick_processor.sv" \
] {
  set fobj [get_files -of_objects $srcset [list "*[file normalize $f]"]]
  if {$fobj ne ""} { set_property file_type {SystemVerilog} $fobj }
}

set f [file normalize "${origin_dir}/../ip/qick_processor_452/src/axi_slv_qproc.vhd"]
set fobj [get_files -of_objects $srcset [list "*$f"]]
if {$fobj ne ""} { set_property file_type {VHDL} $fobj }

# Handle dsp_macro_0 IP
set ip_f [file normalize "${origin_dir}/../ip/qick_processor_452/src/dsp_macro_0/dsp_macro_0.xci"]
set ip_obj [get_files -of_objects $srcset [list "*$ip_f"]]
if {$ip_obj ne ""} {
  set_property generate_files_for_reference 0 $ip_obj
  if {![get_property is_locked $ip_obj]} {
    set_property generate_synth_checkpoint 0 $ip_obj
  }
  set_property registered_with_manager 1 $ip_obj
  catch {generate_target all $ip_obj}
  catch {export_ip_user_files -of_objects $ip_obj -no_script -sync -force -quiet}
}

set_property top axis_qick_processor $srcset
set_property top_auto_set 0 $srcset

# ------------------------------------------------------------------------------
# constrs_1
# ------------------------------------------------------------------------------
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}
set constrset [get_filesets constrs_1]

set c1 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qick_processor.xdc"]
add_files -norecurse -fileset $constrset [list $c1]
set c1_obj [get_files -of_objects $constrset [list "*$c1"]]
if {$c1_obj ne ""} {
  set_property file_type XDC $c1_obj
  set_property is_enabled 0 $c1_obj
}

set c2 [file normalize "${origin_dir}/../ip/qick_processor_452/src/qick_processor_ooc.xdc"]
add_files -norecurse -fileset $constrset [list $c2]
set c2_obj [get_files -of_objects $constrset [list "*$c2"]]
if {$c2_obj ne ""} {
  set_property file_type XDC $c2_obj
}

# ------------------------------------------------------------------------------
# sim_1
# ------------------------------------------------------------------------------
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}
set simset [get_filesets sim_1]

set sim_files [list \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/axi_mst_0/axi_mst_0.xci"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/_qproc_defines.svh"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/tb_qick_processor_issue35.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/tb_axis_qick_processor.sv"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/tb_qproc_issue35.wcfg"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/wave.bin"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/wave_issue35.mem"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/tb_qproc_issue37.wcfg"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/prog_issue35.mem"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/tb_qproc.wcfg"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/dmem_issue35.mem"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/prog.bin"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/wave_rabi.mem"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/dmem_rabi.mem"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/prog_rabi.mem"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/new_wave_rabi.mem"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/new_dmem_rabi.mem"] \
 [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/new_prog_rabi.mem"] \
]
add_files -norecurse -fileset $simset $sim_files

# Simulation file type fixes
set sim_hdr [file normalize "${origin_dir}/../ip/qick_processor_452/src/_qproc_defines.svh"]
set sim_hdr_obj [get_files -of_objects $simset [list "*$sim_hdr"]]
if {$sim_hdr_obj ne ""} { set_property file_type {Verilog Header} $sim_hdr_obj }

foreach f [list \
 "${origin_dir}/../ip/qick_processor_452/src/tb/tb_qick_processor_issue35.sv" \
 "${origin_dir}/../ip/qick_processor_452/src/tb/tb_axis_qick_processor.sv" \
] {
  set fobj [get_files -of_objects $simset [list "*[file normalize $f]"]]
  if {$fobj ne ""} { set_property file_type {SystemVerilog} $fobj }
}

foreach f [list \
 "${origin_dir}/../ip/qick_processor_452/src/tb/wave_issue35.mem" \
 "${origin_dir}/../ip/qick_processor_452/src/tb/prog_issue35.mem" \
 "${origin_dir}/../ip/qick_processor_452/src/tb/dmem_issue35.mem" \
 "${origin_dir}/../ip/qick_processor_452/src/tb/wave_rabi.mem" \
 "${origin_dir}/../ip/qick_processor_452/src/tb/dmem_rabi.mem" \
 "${origin_dir}/../ip/qick_processor_452/src/tb/prog_rabi.mem" \
 "${origin_dir}/../ip/qick_processor_452/src/tb/new_wave_rabi.mem" \
 "${origin_dir}/../ip/qick_processor_452/src/tb/new_dmem_rabi.mem" \
 "${origin_dir}/../ip/qick_processor_452/src/tb/new_prog_rabi.mem" \
] {
  set fobj [get_files -of_objects $simset [list "*[file normalize $f]"]]
  if {$fobj ne ""} { set_property file_type {Memory File} $fobj }
}

# Handle axi_mst_0 IP in sim set
set sim_ip [file normalize "${origin_dir}/../ip/qick_processor_452/src/tb/axi_mst_0/axi_mst_0.xci"]
set sim_ip_obj [get_files -of_objects $simset [list "*$sim_ip"]]
if {$sim_ip_obj ne ""} {
  set_property generate_files_for_reference 0 $sim_ip_obj
  set_property registered_with_manager 1 $sim_ip_obj
  catch {generate_target all $sim_ip_obj}
  catch {export_ip_user_files -of_objects $sim_ip_obj -no_script -sync -force -quiet}
}

set_property top tb_qick_processor_issue35 $simset
set_property top_auto_set 0 $simset
set_property top_lib xil_defaultlib $simset

# ------------------------------------------------------------------------------
# Update compile order only
# ------------------------------------------------------------------------------
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "INFO: Minimal project created: ${_xil_proj_name_}"
puts "INFO: No synthesis/implementation runs were customized by this script."