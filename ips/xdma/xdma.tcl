set dir_gen $::env(DIR_IP_GENERATED)

set properties [list \
  CONFIG.axil_master_64bit_en {true} \
  CONFIG.axilite_master_en {true} \
  CONFIG.cfg_mgmt_if {false} \
  CONFIG.dsc_bypass_rd {0001} \
  CONFIG.dsc_bypass_wr {0001} \
  CONFIG.mode_selection {Advanced} \
  CONFIG.pcie_extended_tag {true} \
  CONFIG.pcie_id_if {false} \
  CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
  CONFIG.pl_link_cap_max_link_width {X8} \
  CONFIG.xdma_axi_intf_mm {AXI_Stream} \
  CONFIG.xdma_pcie_64bit_en {true} \
]

file mkdir $dir_gen

create_ip -name xdma -vendor xilinx.com -library ip -module_name xdma_0 -dir $dir_gen -force
set_property -dict $properties [get_ips xdma_0]