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
   parameter PL_LINK_CAP_MAX_LINK_WIDTH          = 8,            // 1- X1; 2 - X2; 4 - X4; 8 - X8
   parameter PL_SIM_FAST_LINK_TRAINING           = "FALSE",      // Simulation Speedup
   parameter PL_LINK_CAP_MAX_LINK_SPEED          = 4,             // 1- GEN1; 2 - GEN2; 4 - GEN3
   parameter C_DATA_WIDTH                        = 256 ,
   parameter EXT_PIPE_SIM                        = "FALSE",  // This Parameter has effect on selecting Enable External PIPE Interface in GUI.
   parameter C_ROOT_PORT                         = "FALSE",      // PCIe block is in root port mode
   parameter C_DEVICE_NUMBER                     = 0,            // Device number for Root Port configurations only
   parameter AXIS_CCIX_RX_TDATA_WIDTH     = 256, 
   parameter AXIS_CCIX_TX_TDATA_WIDTH     = 256,
   parameter AXIS_CCIX_RX_TUSER_WIDTH     = 46,
   parameter AXIS_CCIX_TX_TUSER_WIDTH     = 46
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
   localparam C_S_AXI_ID_WIDTH = 4; 
   localparam C_M_AXI_ID_WIDTH = 4; 
   localparam C_S_AXI_DATA_WIDTH = C_DATA_WIDTH;
   localparam C_M_AXI_DATA_WIDTH = C_DATA_WIDTH;
   localparam C_S_AXI_ADDR_WIDTH = 64;
   localparam C_M_AXI_ADDR_WIDTH = 64;

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
     reg [((2*C_NUM_USR_IRQ)-1):0]		usr_irq_function_number=0;
     reg [C_NUM_USR_IRQ-1:0] 		     usr_irq_req = 0;
     wire [C_NUM_USR_IRQ-1:0] 		     usr_irq_ack;

      //-- AXI Master Write Address Channel
     wire [C_M_AXI_ADDR_WIDTH-1:0] m_axi_awaddr;
     wire [C_M_AXI_ID_WIDTH-1:0] m_axi_awid;
     wire [2:0] 		 m_axi_awprot;
     wire [1:0] 		 m_axi_awburst;
     wire [2:0] 		 m_axi_awsize;
     wire [3:0] 		 m_axi_awcache;
     wire [7:0] 		 m_axi_awlen;
     wire 			 m_axi_awlock;
     wire 			 m_axi_awvalid;
     wire 			 m_axi_awready;

     //-- AXI Master Write Data Channel
     wire [C_M_AXI_DATA_WIDTH-1:0]     m_axi_wdata;
     wire [(C_M_AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb;
     wire 			       m_axi_wlast;
     wire 			       m_axi_wvalid;
     wire 			       m_axi_wready;
     //-- AXI Master Write Response Channel
     wire 			       m_axi_bvalid;
     wire 			       m_axi_bready;
     wire [C_M_AXI_ID_WIDTH-1 : 0]     m_axi_bid ;
     wire [1:0]                        m_axi_bresp ;

     //-- AXI Master Read Address Channel
     wire [C_M_AXI_ID_WIDTH-1 : 0]     m_axi_arid;
     wire [C_M_AXI_ADDR_WIDTH-1:0]     m_axi_araddr;
     wire [7:0]                        m_axi_arlen;
     wire [2:0]                        m_axi_arsize;
     wire [1:0]                        m_axi_arburst;
     wire [2:0] 		       m_axi_arprot;
     wire 			       m_axi_arvalid;
     wire 			       m_axi_arready;
     wire 			       m_axi_arlock;
     wire [3:0] 		       m_axi_arcache;

     //-- AXI Master Read Data Channel
     wire [C_M_AXI_ID_WIDTH-1 : 0]   m_axi_rid;
     wire [C_M_AXI_DATA_WIDTH-1:0]   m_axi_rdata;
     wire [1:0] 		     m_axi_rresp;
     wire 			     m_axi_rvalid;
     wire 			     m_axi_rready;





//////////////////////////////////////////////////  LITE
   //-- AXI Master Write Address Channel
    wire [31:0] m_axil_awaddr;
    wire [2:0]  m_axil_awprot;
    wire 	m_axil_awvalid;
    wire 	m_axil_awready;

    //-- AXI Master Write Data Channel
    wire [31:0] m_axil_wdata;
    wire [3:0]  m_axil_wstrb;
    wire 	m_axil_wvalid;
    wire 	m_axil_wready;
    //-- AXI Master Write Response Channel
    wire 	m_axil_bvalid;
    wire 	m_axil_bready;
    //-- AXI Master Read Address Channel
    wire [31:0] m_axil_araddr;
    wire [2:0]  m_axil_arprot;
    wire 	m_axil_arvalid;
    wire 	m_axil_arready;
    //-- AXI Master Read Data Channel
    wire [31:0] m_axil_rdata;
    wire [1:0]  m_axil_rresp;
    wire 	m_axil_rvalid;
    wire 	m_axil_rready;
    wire [1:0]  m_axil_bresp;

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

      // LITE interface   
      //-- AXI Master Write Address Channel
      .m_axil_awaddr    (m_axil_awaddr),
      .m_axil_awprot    (m_axil_awprot),
      .m_axil_awvalid   (m_axil_awvalid),
      .m_axil_awready   (m_axil_awready),
      //-- AXI Master Write Data Channel
      .m_axil_wdata     (m_axil_wdata),
      .m_axil_wstrb     (m_axil_wstrb),
      .m_axil_wvalid    (m_axil_wvalid),
      .m_axil_wready    (m_axil_wready),
      //-- AXI Master Write Response Channel
      .m_axil_bvalid    (m_axil_bvalid),
      .m_axil_bresp     (m_axil_bresp),
      .m_axil_bready    (m_axil_bready),
      //-- AXI Master Read Address Channel
      .m_axil_araddr    (m_axil_araddr),
      .m_axil_arprot    (m_axil_arprot),
      .m_axil_arvalid   (m_axil_arvalid),
      .m_axil_arready   (m_axil_arready),
      .m_axil_rdata     (m_axil_rdata),
      //-- AXI Master Read Data Channel
      .m_axil_rresp     (m_axil_rresp),
      .m_axil_rvalid    (m_axil_rvalid),
      .m_axil_rready    (m_axil_rready),




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
        .ctlAxil_awvalid(m_axil_awvalid),
        .ctlAxil_awaddr(m_axil_awaddr),
        // .ctlAxil_awprot(m_axil_awprot),
        .ctlAxil_awready(m_axil_awready),
        .ctlAxil_wvalid(m_axil_wvalid),
        .ctlAxil_wdata(m_axil_wdata),
        .ctlAxil_wstrb(m_axil_wstrb),
        .ctlAxil_wready(m_axil_wready),
        .ctlAxil_bvalid(m_axil_bvalid),
        .ctlAxil_bresp(m_axil_bresp),
        .ctlAxil_bready(m_axil_bready),
        .ctlAxil_arvalid(m_axil_arvalid),
        .ctlAxil_araddr(m_axil_araddr),
        // .ctlAxil_arprot(m_axil_arprot),
        .ctlAxil_arready(m_axil_arready),
        .ctlAxil_rvalid(m_axil_rvalid),
        .ctlAxil_rresp(m_axil_rresp),
        .ctlAxil_rdata(m_axil_rdata),
        .ctlAxil_rready(m_axil_rready),
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


    ila_0 your_instance_name (
      .clk(user_clk), // input wire clk


      .probe0(c2h_dsc_byp_src_addr_0), // input wire [31:0]  probe0  
      .probe1(c2h_dsc_byp_dst_addr_0), // input wire [31:0]  probe1 
      .probe2(c2h_dsc_byp_len_0), // input wire [31:0]  probe2 
      .probe3(c2h_dsc_byp_ctl_0), // input wire [31:0]  probe3 
      .probe4(h2c_dsc_byp_src_addr_0), // input wire [31:0]  probe4 
      .probe5(h2c_dsc_byp_dst_addr_0), // input wire [31:0]  probe5 
      .probe6(h2c_dsc_byp_len_0), // input wire [31:0]  probe6 
      .probe7(h2c_dsc_byp_ctl_0), // input wire [31:0]  probe7 
      .probe8(s_axis_c2h_tdata_0), // input wire [255:0]  probe8 
      .probe9(m_axis_h2c_tdata_0), // input wire [255:0]  probe9 
      .probe10(s_axis_c2h_tvalid_0), // input wire [0:0]  probe10 
      .probe11(s_axis_c2h_tready_0), // input wire [0:0]  probe11 
      .probe12(m_axis_h2c_tvalid_0), // input wire [0:0]  probe12 
      .probe13(m_axis_h2c_tready_0), // input wire [0:0]  probe13 
      .probe14(s_axis_c2h_tlast_0), // input wire [0:0]  probe14 
      .probe15(m_axis_h2c_tlast_0), // input wire [0:0]  probe15 
      .probe16(c2h_dsc_byp_ready_0), // input wire [0:0]  probe16 
      .probe17(c2h_dsc_byp_load_0), // input wire [0:0]  probe17 
      .probe18(h2c_dsc_byp_ready_0), // input wire [0:0]  probe18 
      .probe19(h2c_dsc_byp_load_0), // input wire [0:0]  probe19 
      .probe20(m_axil_awaddr), // input wire [31:0]  probe20 
      .probe21(m_axil_wdata), // input wire [31:0]  probe21 
      .probe22(m_axil_awvalid), // input wire [0:0]  probe22 
      .probe23(m_axil_wvalid) // input wire [0:0]  probe23
    );

endmodule