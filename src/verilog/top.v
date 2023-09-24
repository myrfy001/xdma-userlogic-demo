//-----------------------------------------------------------------------------
//
// (c) Copyright 2012-2012 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
//
// Project    : The Xilinx PCI Express DMA 
// File       : xilinx_dma_pcie_ep.sv
// Version    : 4.1
//-----------------------------------------------------------------------------
`timescale 1ps / 1ps

module top #
  (
   parameter PL_LINK_CAP_MAX_LINK_WIDTH          = 16,            // 1- X1; 2 - X2; 4 - X4; 8 - X8
   parameter PL_LINK_CAP_MAX_LINK_SPEED          = 4,             // 1- GEN1; 2 - GEN2; 4 - GEN3
   parameter C_ADDR_WIDTH                        = 64,
   parameter C_DATA_WIDTH                        = 512
   )
   (
    output [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0] pci_exp_txp,
    output [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0] pci_exp_txn,
    input [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxp,
    input [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxn,

//VU9P_TUL_EX_String= FALSE




    input 					 sys_clk_p,
    input 					 sys_clk_n,
    input 					 sys_rst_n
 );

   //-----------------------------------------------------------------------------------------------------------------------

   
   // Local Parameters derived from user selection
   localparam integer 				   USER_CLK_FREQ         = ((PL_LINK_CAP_MAX_LINK_SPEED == 3'h4) ? 5 : 4);
   localparam TCQ = 1;


   localparam C_NUM_USR_IRQ	 = 1;

   
   wire 					   user_lnk_up;
   
   //----------------------------------------------------------------------------------------------------------------//
   //  AXI Interface                                                                                                 //
   //----------------------------------------------------------------------------------------------------------------//
   
   wire 					   user_clk;
   wire 					   user_resetn;
   
  // Wires for Avery HOT/WARM and COLD RESET
   wire 					   avy_sys_rst_n_c;
   wire 					   avy_cfg_hot_reset_out;
   reg 						   avy_sys_rst_n_g;
   reg 						   avy_cfg_hot_reset_out_g;
   assign avy_sys_rst_n_c = avy_sys_rst_n_g;
   assign avy_cfg_hot_reset_out = avy_cfg_hot_reset_out_g;
   initial begin 
      avy_sys_rst_n_g = 1;
      avy_cfg_hot_reset_out_g =0;
   end
   


  //----------------------------------------------------------------------------------------------------------------//
  //    System(SYS) Interface                                                                                       //
  //----------------------------------------------------------------------------------------------------------------//

    wire                                    sys_clk;
    wire                                    sys_clk_gt;
    wire                                    sys_rst_n_c;

  // User Clock LED Heartbeat
     reg [25:0] 			     user_clk_heartbeat;
     reg [C_NUM_USR_IRQ-1:0] 		     usr_irq_req = 0;
     wire [C_NUM_USR_IRQ-1:0] 		     usr_irq_ack;




//////////////////////////////////////////////////
   //-- AXI Master Write Address Channel
    (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [C_ADDR_WIDTH-1:0] m_axib_awaddr;
    (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [2:0]  m_axib_awprot;
    (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire 	m_axib_awvalid;
    (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire 	m_axib_awready;

    //-- AXI Master Write Data Channel
    (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [C_DATA_WIDTH-1:0] m_axib_wdata;
    (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [C_DATA_WIDTH/8-1:0]  m_axib_wstrb;
    (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire 	m_axib_wvalid;
    (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire 	m_axib_wready;
    //-- AXI Master Write Response Channel
    wire 	m_axib_bvalid;
    wire 	m_axib_bready;
    //-- AXI Master Read Address Channel
    (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [C_ADDR_WIDTH-1:0] m_axib_araddr;
    wire [2:0]  m_axib_arprot;
    (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire 	m_axib_arvalid;
    (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire 	m_axib_arready;
    //-- AXI Master Read Data Channel
    (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [C_DATA_WIDTH-1:0] m_axib_rdata;
    wire [1:0]  m_axib_rresp;
    wire 	m_axib_rvalid;
    wire 	m_axib_rready;
    wire [1:0]  m_axib_bresp;

    wire [2:0]    msi_vector_width;
    wire          msi_enable;

      // AXI streaming ports
    wire [C_DATA_WIDTH-1:0]	m_axis_h2c_tdata_0;
    wire 			m_axis_h2c_tlast_0;
    wire 			m_axis_h2c_tvalid_0;
    wire 			m_axis_h2c_tready_0;
    wire [C_DATA_WIDTH/8-1:0]	m_axis_h2c_tkeep_0;
    wire [C_DATA_WIDTH-1:0] s_axis_c2h_tdata_0; 
    wire s_axis_c2h_tlast_0;
    wire s_axis_c2h_tvalid_0;
    wire s_axis_c2h_tready_0;
    wire [C_DATA_WIDTH/8-1:0] s_axis_c2h_tkeep_0; 

    wire [3:0]                  leds;

 wire free_run_clock;
    
  wire [5:0]                          cfg_ltssm_state;

        wire          soft_reset_n;

  // Ref clock buffer

  IBUFDS_GTE4 # (.REFCLK_HROW_CK_SEL(2'b00)) refclk_ibuf (.O(sys_clk_gt), .ODIV2(sys_clk), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));
  // Reset buffer
  IBUF   sys_reset_n_ibuf (.O(sys_rst_n_c), .I(sys_rst_n));
     
  // Descriptor Bypass Control Logic
  (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*) wire c2h_dsc_byp_ready_0;
  (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [63 : 0] c2h_dsc_byp_src_addr_0;
  (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [63 : 0] c2h_dsc_byp_dst_addr_0;
  (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [27 : 0] c2h_dsc_byp_len_0;
  (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [15 : 0] c2h_dsc_byp_ctl_0;
  (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire c2h_dsc_byp_load_0;
  (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire h2c_dsc_byp_ready_0;
  (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [63 : 0] h2c_dsc_byp_src_addr_0;
  (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [63 : 0] h2c_dsc_byp_dst_addr_0;
  (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [27 : 0] h2c_dsc_byp_len_0;
  (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire [15 : 0] h2c_dsc_byp_ctl_0;
  (*mark_debug,mark_debug_valid="true",mark_debug_clock="user_clk"*)wire h2c_dsc_byp_load_0;




//
//



  // Core Top Level Wrapper
  xdma_0 xdma_0_i
     (
      //---------------------------------------------------------------------------------------//
      //  PCI Express (pci_exp) Interface                                                      //
      //---------------------------------------------------------------------------------------//
      .sys_rst_n       ( sys_rst_n_c ),

      .sys_clk         ( sys_clk ),
      .sys_clk_gt      ( sys_clk_gt),
      
      // Tx
      .pci_exp_txn     ( pci_exp_txn ),
      .pci_exp_txp     ( pci_exp_txp ),
      
      // Rx
      .pci_exp_rxn     ( pci_exp_rxn ),
      .pci_exp_rxp     ( pci_exp_rxp ),



      // AXI streaming ports
      .s_axis_c2h_tdata_0(s_axis_c2h_tdata_0),  
      .s_axis_c2h_tlast_0(s_axis_c2h_tlast_0),
      .s_axis_c2h_tvalid_0(s_axis_c2h_tvalid_0), 
      .s_axis_c2h_tready_0(s_axis_c2h_tready_0),
      .s_axis_c2h_tkeep_0(s_axis_c2h_tkeep_0),
      .m_axis_h2c_tdata_0(m_axis_h2c_tdata_0),
      .m_axis_h2c_tlast_0(m_axis_h2c_tlast_0),
      .m_axis_h2c_tvalid_0(m_axis_h2c_tvalid_0),
      .m_axis_h2c_tready_0(m_axis_h2c_tready_0),
      .m_axis_h2c_tkeep_0(m_axis_h2c_tkeep_0),

      // PCIe Bypass Bridge interface   
      //-- AXI Master Write Address Channel
      .m_axib_awaddr    (m_axib_awaddr),
      .m_axib_awprot    (m_axib_awprot),
      .m_axib_awvalid   (m_axib_awvalid),
      .m_axib_awready   (m_axib_awready),
      //-- AXI Master Write Data Channel
      .m_axib_wdata     (m_axib_wdata),
      .m_axib_wstrb     (m_axib_wstrb),
      .m_axib_wvalid    (m_axib_wvalid),
      .m_axib_wready    (m_axib_wready),
      //-- AXI Master Write Response Channel
      .m_axib_bvalid    (m_axib_bvalid),
      .m_axib_bresp     (m_axib_bresp),
      .m_axib_bready    (m_axib_bready),
      //-- AXI Master Read Address Channel
      .m_axib_araddr    (m_axib_araddr),
      .m_axib_arprot    (m_axib_arprot),
      .m_axib_arvalid   (m_axib_arvalid),
      .m_axib_arready   (m_axib_arready),

      //-- AXI Master Read Data Channel
      .m_axib_rdata     (m_axib_rdata),
      .m_axib_rlast     (1),  // todo FIX me
      .m_axib_rresp     (m_axib_rresp),
      .m_axib_rvalid    (m_axib_rvalid),
      .m_axib_rready    (m_axib_rready),




      // Descriptor Bypass
      .c2h_dsc_byp_ready_0    (c2h_dsc_byp_ready_0),
      .c2h_dsc_byp_src_addr_0 (c2h_dsc_byp_src_addr_0),
      .c2h_dsc_byp_dst_addr_0 (c2h_dsc_byp_dst_addr_0),
      .c2h_dsc_byp_len_0      (c2h_dsc_byp_len_0),
      .c2h_dsc_byp_ctl_0      (c2h_dsc_byp_ctl_0),
      .c2h_dsc_byp_load_0     (c2h_dsc_byp_load_0),
      .h2c_dsc_byp_ready_0    (h2c_dsc_byp_ready_0),
      .h2c_dsc_byp_src_addr_0 (h2c_dsc_byp_src_addr_0),
      .h2c_dsc_byp_dst_addr_0 (h2c_dsc_byp_dst_addr_0),
      .h2c_dsc_byp_len_0      (h2c_dsc_byp_len_0),
      .h2c_dsc_byp_ctl_0      (h2c_dsc_byp_ctl_0),
      .h2c_dsc_byp_load_0     (h2c_dsc_byp_load_0),



      .usr_irq_req  (usr_irq_req),
      .usr_irq_ack  (usr_irq_ack),
      .msi_enable        (msi_enable),
      .msi_vector_width  (msi_vector_width),








      //-- AXI Global
      .axi_aclk        ( user_clk ),
      .axi_aresetn     ( user_resetn ),
  





      .user_lnk_up     ( user_lnk_up )
    );


  mkUserLogic user_logic_inst(
        .CLK(user_clk),
        .RST_N(user_resetn),
        .ctlAxi4_awvalid(m_axib_awvalid),
        .ctlAxi4_awaddr(m_axib_awaddr),
        // .ctlAxi4_awprot(m_axib_awprot),
        .ctlAxi4_awready(m_axib_awready),
        .ctlAxi4_wvalid(m_axib_wvalid),
        .ctlAxi4_wdata(m_axib_wdata),
        .ctlAxi4_wstrb(m_axib_wstrb),
        .ctlAxi4_wready(m_axib_wready),
        .ctlAxi4_bvalid(m_axib_bvalid),
        .ctlAxi4_bresp(m_axib_bresp),
        .ctlAxi4_bready(m_axib_bready),
        .ctlAxi4_arvalid(m_axib_arvalid),
        .ctlAxi4_araddr(m_axib_araddr),
        // .ctlAxi4_arprot(m_axib_arprot),
        .ctlAxi4_arready(m_axib_arready),
        .ctlAxi4_rvalid(m_axib_rvalid),
        .ctlAxi4_rresp(m_axib_rresp),
        .ctlAxi4_rdata(m_axib_rdata),
        .ctlAxi4_rready(m_axib_rready),
        .dataAxisH2C_tvalid(m_axis_h2c_tvalid_0),
        .dataAxisH2C_tdata(m_axis_h2c_tdata_0),
        .dataAxisH2C_tkeep(m_axis_h2c_tkeep_0),
        .dataAxisH2C_tlast(m_axis_h2c_tlast_0),
        .dataAxisH2C_tuser(),
        .dataAxisH2C_tready(m_axis_h2c_tready_0),
        .dataAxisC2H_tvalid(s_axis_c2h_tvalid_0),
        .dataAxisC2H_tdata(s_axis_c2h_tdata_0),
        .dataAxisC2H_tkeep(s_axis_c2h_tkeep_0),
        .dataAxisC2H_tlast(s_axis_c2h_tlast_0),
        .dataAxisC2H_tuser(),
        .dataAxisC2H_tready(s_axis_c2h_tready_0),
        .descBypH2C_load(h2c_dsc_byp_load_0),
        .descBypH2C_ready_is_ready(h2c_dsc_byp_ready_0),
        .descBypH2C_dstAddr(h2c_dsc_byp_dst_addr_0),
        .descBypH2C_srcAddr(h2c_dsc_byp_src_addr_0),
        .descBypH2C_length(h2c_dsc_byp_len_0),
        .descBypH2C_ctrl(h2c_dsc_byp_ctl_0),
        .descBypC2H_load(c2h_dsc_byp_load_0),
        .descBypC2H_ready_is_ready(c2h_dsc_byp_ready_0),
        .descBypC2H_dstAddr(c2h_dsc_byp_dst_addr_0),
        .descBypC2H_srcAddr(c2h_dsc_byp_src_addr_0),
        .descBypC2H_length(c2h_dsc_byp_len_0),
        .descBypC2H_ctrl(c2h_dsc_byp_ctl_0)
    );

endmodule