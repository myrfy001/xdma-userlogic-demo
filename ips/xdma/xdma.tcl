set gen_dir $::env(DIR_IP_GENERATED)

set properties [list \
  CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
  CONFIG.pl_link_cap_max_link_width {X8} \
  CONFIG.xdma_rnum_chnl {4} \
  CONFIG.xdma_wnum_chnl {4} \
  CONFIG.dsc_bypass_rd {0010} \
  CONFIG.dsc_bypass_wr {0010} \
  CONFIG.axi_bypass_64bit_en {true} \
  CONFIG.axil_master_64bit_en {true} \
  CONFIG.axilite_master_en {true} \
  CONFIG.axist_bypass_en {true} \
  CONFIG.xdma_pcie_64bit_en {true} \
  CONFIG.xdma_axi_intf_mm AXI_Stream \
]

file mkdir $gen_dir

create_ip -name xdma -vendor xilinx.com -library ip -module_name xdma_0 -dir $gen_dir -force
set_property -dict $properties [get_ips xdma_0]