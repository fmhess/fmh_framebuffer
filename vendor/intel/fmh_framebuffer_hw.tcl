# TCL File Generated by Component Editor 17.1
# Mon Jun 01 00:50:46 EDT 2020
# DO NOT MODIFY


# 
# fmh_framebuffer "fmh_framebuffer" v1.0
#  2020.06.01.00:50:46
# 
# 

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.1


# 
# module fmh_framebuffer
# 
set_module_property DESCRIPTION ""
set_module_property NAME fmh_framebuffer
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP "DSP/Video and Image Processing"
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME fmh_framebuffer
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL fmh_framebuffer
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file fmh_framebuffer.vhd VHDL PATH ../../src/fmh_framebuffer.vhd TOP_LEVEL_FILE


# 
# parameters
# 
add_parameter bits_per_color POSITIVE 8
set_parameter_property bits_per_color DEFAULT_VALUE 8
set_parameter_property bits_per_color DISPLAY_NAME bits_per_color
set_parameter_property bits_per_color TYPE POSITIVE
set_parameter_property bits_per_color UNITS None
set_parameter_property bits_per_color ALLOWED_RANGES 1:2147483647
set_parameter_property bits_per_color HDL_PARAMETER true
add_parameter colors_per_pixel_per_plane POSITIVE 4
set_parameter_property colors_per_pixel_per_plane DEFAULT_VALUE 4
set_parameter_property colors_per_pixel_per_plane DISPLAY_NAME colors_per_pixel_per_plane
set_parameter_property colors_per_pixel_per_plane TYPE POSITIVE
set_parameter_property colors_per_pixel_per_plane UNITS None
set_parameter_property colors_per_pixel_per_plane ALLOWED_RANGES 1:2147483647
set_parameter_property colors_per_pixel_per_plane HDL_PARAMETER true
add_parameter colors_per_beat POSITIVE 4
set_parameter_property colors_per_beat DEFAULT_VALUE 4
set_parameter_property colors_per_beat DISPLAY_NAME colors_per_beat
set_parameter_property colors_per_beat TYPE POSITIVE
set_parameter_property colors_per_beat UNITS None
set_parameter_property colors_per_beat ALLOWED_RANGES 1:2147483647
set_parameter_property colors_per_beat HDL_PARAMETER true
add_parameter num_color_planes POSITIVE 1
set_parameter_property num_color_planes DEFAULT_VALUE 1
set_parameter_property num_color_planes DISPLAY_NAME num_color_planes
set_parameter_property num_color_planes TYPE POSITIVE
set_parameter_property num_color_planes UNITS None
set_parameter_property num_color_planes ALLOWED_RANGES 1:2147483647
set_parameter_property num_color_planes HDL_PARAMETER true
add_parameter memory_bytes_per_pixel_per_plane POSITIVE 4
set_parameter_property memory_bytes_per_pixel_per_plane DEFAULT_VALUE 4
set_parameter_property memory_bytes_per_pixel_per_plane DISPLAY_NAME memory_bytes_per_pixel_per_plane
set_parameter_property memory_bytes_per_pixel_per_plane TYPE POSITIVE
set_parameter_property memory_bytes_per_pixel_per_plane UNITS None
set_parameter_property memory_bytes_per_pixel_per_plane HDL_PARAMETER true
add_parameter memory_address_width POSITIVE 32
set_parameter_property memory_address_width DEFAULT_VALUE 32
set_parameter_property memory_address_width DISPLAY_NAME memory_address_width
set_parameter_property memory_address_width TYPE POSITIVE
set_parameter_property memory_address_width UNITS None
set_parameter_property memory_address_width ALLOWED_RANGES 1:2147483647
set_parameter_property memory_address_width HDL_PARAMETER true
add_parameter memory_burstcount_width POSITIVE 5 ""
set_parameter_property memory_burstcount_width DEFAULT_VALUE 5
set_parameter_property memory_burstcount_width DISPLAY_NAME memory_burstcount_width
set_parameter_property memory_burstcount_width TYPE POSITIVE
set_parameter_property memory_burstcount_width UNITS None
set_parameter_property memory_burstcount_width ALLOWED_RANGES 1:2147483647
set_parameter_property memory_burstcount_width DESCRIPTION ""
set_parameter_property memory_burstcount_width HDL_PARAMETER true
add_parameter memory_data_width POSITIVE 64 ""
set_parameter_property memory_data_width DEFAULT_VALUE 64
set_parameter_property memory_data_width DISPLAY_NAME memory_data_width
set_parameter_property memory_data_width TYPE POSITIVE
set_parameter_property memory_data_width UNITS None
set_parameter_property memory_data_width ALLOWED_RANGES 1:2147483647
set_parameter_property memory_data_width DESCRIPTION ""
set_parameter_property memory_data_width HDL_PARAMETER true
add_parameter slave_address_width POSITIVE 5
set_parameter_property slave_address_width DEFAULT_VALUE 5
set_parameter_property slave_address_width DISPLAY_NAME slave_address_width
set_parameter_property slave_address_width TYPE POSITIVE
set_parameter_property slave_address_width UNITS None
set_parameter_property slave_address_width ALLOWED_RANGES 1:2147483647
set_parameter_property slave_address_width HDL_PARAMETER true
add_parameter slave_data_width POSITIVE 32
set_parameter_property slave_data_width DEFAULT_VALUE 32
set_parameter_property slave_data_width DISPLAY_NAME slave_data_width
set_parameter_property slave_data_width TYPE POSITIVE
set_parameter_property slave_data_width UNITS None
set_parameter_property slave_data_width ALLOWED_RANGES 1:2147483647
set_parameter_property slave_data_width HDL_PARAMETER true


# 
# display items
# 


# 
# connection point reset
# 
add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
set_interface_property reset ENABLED true
set_interface_property reset EXPORT_OF ""
set_interface_property reset PORT_NAME_MAP ""
set_interface_property reset CMSIS_SVD_VARIABLES ""
set_interface_property reset SVD_ADDRESS_GROUP ""

add_interface_port reset reset reset Input 1


# 
# connection point avalon_slave_0
# 
add_interface avalon_slave_0 avalon end
set_interface_property avalon_slave_0 addressUnits WORDS
set_interface_property avalon_slave_0 associatedClock clock
set_interface_property avalon_slave_0 associatedReset reset
set_interface_property avalon_slave_0 bitsPerSymbol 8
set_interface_property avalon_slave_0 burstOnBurstBoundariesOnly false
set_interface_property avalon_slave_0 burstcountUnits WORDS
set_interface_property avalon_slave_0 explicitAddressSpan 0
set_interface_property avalon_slave_0 holdTime 0
set_interface_property avalon_slave_0 linewrapBursts false
set_interface_property avalon_slave_0 maximumPendingReadTransactions 0
set_interface_property avalon_slave_0 maximumPendingWriteTransactions 0
set_interface_property avalon_slave_0 readLatency 0
set_interface_property avalon_slave_0 readWaitTime 1
set_interface_property avalon_slave_0 setupTime 0
set_interface_property avalon_slave_0 timingUnits Cycles
set_interface_property avalon_slave_0 writeWaitTime 0
set_interface_property avalon_slave_0 ENABLED true
set_interface_property avalon_slave_0 EXPORT_OF ""
set_interface_property avalon_slave_0 PORT_NAME_MAP ""
set_interface_property avalon_slave_0 CMSIS_SVD_VARIABLES ""
set_interface_property avalon_slave_0 SVD_ADDRESS_GROUP ""

add_interface_port avalon_slave_0 slave_address address Input slave_address_width
add_interface_port avalon_slave_0 slave_readdata readdata Output slave_data_width
add_interface_port avalon_slave_0 slave_read read Input 1
add_interface_port avalon_slave_0 slave_writedata writedata Input slave_data_width
add_interface_port avalon_slave_0 slave_write write Input 1
set_interface_assignment avalon_slave_0 embeddedsw.configuration.isFlash 0
set_interface_assignment avalon_slave_0 embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment avalon_slave_0 embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment avalon_slave_0 embeddedsw.configuration.isPrintableDevice 0


# 
# connection point video_out
# 
add_interface video_out avalon_streaming start
set_interface_property video_out associatedClock clock
set_interface_property video_out associatedReset reset
set_interface_property video_out dataBitsPerSymbol 8
set_interface_property video_out errorDescriptor ""
set_interface_property video_out firstSymbolInHighOrderBits true
set_interface_property video_out maxChannel 0
set_interface_property video_out readyLatency 1
set_interface_property video_out ENABLED true
set_interface_property video_out EXPORT_OF ""
set_interface_property video_out PORT_NAME_MAP ""
set_interface_property video_out CMSIS_SVD_VARIABLES ""
set_interface_property video_out SVD_ADDRESS_GROUP ""

add_interface_port video_out video_out_endofpacket endofpacket Output 1
add_interface_port video_out video_out_startofpacket startofpacket Output 1
add_interface_port video_out video_out_data data Output bits_per_color*colors_per_beat
add_interface_port video_out video_out_ready ready Input 1
add_interface_port video_out video_out_valid valid Output 1


# 
# connection point clock
# 
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock clock clk Input 1


# 
# connection point memory_master
# 
add_interface memory_master avalon start
set_interface_property memory_master addressUnits SYMBOLS
set_interface_property memory_master associatedClock clock
set_interface_property memory_master associatedReset reset
set_interface_property memory_master bitsPerSymbol 8
set_interface_property memory_master burstOnBurstBoundariesOnly false
set_interface_property memory_master burstcountUnits WORDS
set_interface_property memory_master doStreamReads false
set_interface_property memory_master doStreamWrites false
set_interface_property memory_master holdTime 0
set_interface_property memory_master linewrapBursts false
set_interface_property memory_master maximumPendingReadTransactions 0
set_interface_property memory_master maximumPendingWriteTransactions 0
set_interface_property memory_master readLatency 0
set_interface_property memory_master readWaitTime 1
set_interface_property memory_master setupTime 0
set_interface_property memory_master timingUnits Cycles
set_interface_property memory_master writeWaitTime 0
set_interface_property memory_master ENABLED true
set_interface_property memory_master EXPORT_OF ""
set_interface_property memory_master PORT_NAME_MAP ""
set_interface_property memory_master CMSIS_SVD_VARIABLES ""
set_interface_property memory_master SVD_ADDRESS_GROUP ""

add_interface_port memory_master memory_address address Output memory_address_width
add_interface_port memory_master memory_burstcount burstcount Output memory_burstcount_width
add_interface_port memory_master memory_read read Output 1
add_interface_port memory_master memory_readdata readdata Input memory_data_width
add_interface_port memory_master memory_readdatavalid readdatavalid Input 1
add_interface_port memory_master memory_waitrequest waitrequest Input 1


# 
# connection point interrupt_sender
# 
add_interface interrupt_sender interrupt end
set_interface_property interrupt_sender associatedAddressablePoint ""
set_interface_property interrupt_sender associatedClock clock
set_interface_property interrupt_sender associatedReset reset
set_interface_property interrupt_sender bridgedReceiverOffset ""
set_interface_property interrupt_sender bridgesToReceiver ""
set_interface_property interrupt_sender ENABLED true
set_interface_property interrupt_sender EXPORT_OF ""
set_interface_property interrupt_sender PORT_NAME_MAP ""
set_interface_property interrupt_sender CMSIS_SVD_VARIABLES ""
set_interface_property interrupt_sender SVD_ADDRESS_GROUP ""

add_interface_port interrupt_sender slave_irq irq Output 1

