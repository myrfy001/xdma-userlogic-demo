set dir_gen $::env(DIR_IP_GENERATED)

set properties [list \
  CONFIG.axist_bypass_en {true} \
  CONFIG.cfg_mgmt_if {false} \
  CONFIG.dsc_bypass_rd {0001} \
  CONFIG.dsc_bypass_wr {0001} \
  CONFIG.functional_mode {DMA} \
  CONFIG.mode_selection {Advanced} \
  CONFIG.pf0_msix_enabled {true} \
  CONFIG.pipe_sim {true} \
  CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
  CONFIG.pl_link_cap_max_link_width {X16} \
  CONFIG.xdma_axi_intf_mm {AXI_Stream} \
]

file mkdir $dir_gen

create_ip -name xdma -vendor xilinx.com -library ip -module_name xdma_0 -dir $dir_gen -force
set_property -dict $properties [get_ips xdma_0]