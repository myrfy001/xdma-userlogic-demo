import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;


typedef 12 CONTROL_ADDR_WIDTH;
typedef 32 CONTROL_DATA_WIDTH;

interface UserLogic#(numeric type controlAddrWidth, numeric type dataWidth);
    interface ControlAxiLiteSlave#(controlAddrWidth, dataWidth) ctlAxil;
    // interface DataAxiStreamH2C dataAxisH2C;
    // interface DataAxiStreamC2H dataAxisC2H;
    // interface DescBypassH2C descBypH2C;
    // interface DescBypassC2H descBypC2H;
endinterface

interface ControlAxiLiteSlave#(numeric type addrWidth, numeric type dataWidth);
    (*prefix=""*) method Action awaddr( (*port="awaddr"*) Bit#(addrWidth) addr);
    // (*prefix=""*) method Action awvalid( (*port="awvalid"*) Bool isValid);
    // (*prefix=""*) method Bool awready;

    // (*prefix=""*) method Action wdata( (*port="wdata"*) Bit#(dataWidth) data);
    // (*prefix=""*) method Action wvalid( (*port="wvalid"*) Bool isValid);
    // (*prefix=""*) method Bool wready;

    // (*prefix=""*) method Bool bvalid;
    // (*prefix=""*) method Action bready( (*port="bready"*) Bool isReady);

    // (*prefix=""*) method Action araddr( (*port="araddr"*) Bit#(addrWidth) addr);
    // (*prefix=""*) method Action arvalid( (*port="arvalid"*) Bool isValid);
    // (*prefix=""*) method Bool arready;

    // (*prefix=""*) method Action rdata( (*port="rdata"*) Bit#(dataWidth) data);
    // (*prefix=""*) method Action rvalid( (*port="rvalid"*) Bool isValid);
    // (*prefix=""*) method Bool rready;

endinterface

interface DataAxiStreamH2C;
endinterface

interface DataAxiStreamC2H;
endinterface

interface DescBypassH2C;
endinterface

interface DescBypassC2H;
endinterface

module mkUserLogic(UserLogic#(CONTROL_ADDR_WIDTH, CONTROL_DATA_WIDTH));

    FIFOF#(Bit#(CONTROL_ADDR_WIDTH)) q_addr <- mkPipelineFIFOF;
    // Wire#(Bool) wire_awvalid <- mkWire;
    // Wire#(Bit#(CONTROL_ADDR_WIDTH)) wire_awaddr <- mkWire;

    // Bool awready = q_addr.notFull;

    // rule accept_addr_write if (awready && wire_awvalid);
    //     q_addr.enq(wire_awaddr);
    // endrule

    interface ControlAxiLiteSlave ctlAxil;

        // interface awaddr = q_addr.enq;

        method Action awaddr(Bit#(CONTROL_ADDR_WIDTH) addr);
            if (True) begin
                q_addr.enq(addr);
            end
        endmethod
        // interface awvalid = wire_awvalid._write;

        
        // method Bool awready;
        //     return awready;
        // endmethod

        // method Action wdata(Bit#(dataWidth) data);
        // endmethod

        // method Action wvalid(Bool v);
        // endmethod

        // method Bool wready;
        //     return True;
        // endmethod

        // method Bool bvalid;
        //     return True;
        // endmethod

        // method Action bready(Bool isReady);
        // endmethod

        // method Action araddr(Bit#(addrWidth) addr);
        // endmethod

        // method Action arvalid(Bool isValid);
        // endmethod

        // method Bool arready;
        //     return True;
        // endmethod

        // method Action rdata(Bit#(dataWidth) data);
        // endmethod

        // method Action rvalid(Bool isValid);
        // endmethod

        // method Bool rready;
        //     return True;
        // endmethod

    endinterface


    // interface DataAxiStreamH2C dataAxisH2C;
    // endinterface

    // interface DataAxiStreamC2H dataAxisC2H;
    // endinterface

    // interface DescBypassH2C descBypH2C;
    // endinterface

    // interface DescBypassC2H descBypC2H;
    // endinterface

endmodule
