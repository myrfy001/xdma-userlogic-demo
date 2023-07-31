import FIFOF :: *;
import Connectable :: *;
import GetPut :: *;
import StmtFSM :: *;

import BusConversion :: *;
import SemiFifo :: *;
import AxiStreamTypes :: *;
import Axi4LiteTypes :: *;
import Axi4Types :: *;



typedef 12 CONTROL_ADDR_WIDTH;
typedef 4 CONTROL_DATA_STRB_WIDTH;
typedef TMul#(CONTROL_DATA_STRB_WIDTH, 8) CONTROL_DATA_WIDTH;
typedef 64 HOST_ADDR_WIDTH;
typedef 28 DESC_BYPASS_LENGTH_WIDTH;
typedef 16 DESC_BYPASS_CONTROL_WIDTH;
typedef 4 STREAM_FIFO_DEPTH;
typedef 256 STREAM_DATA_WIDTH;
typedef TDiv#(STREAM_DATA_WIDTH, 8) STREAM_KEEP_WIDTH;

Integer bypass_CONTROL_FLAGS = 'h01;

typedef enum {
    CtlRegAddrH2cSourceLow = 'h0000,
    CtlRegAddrH2cSourceHigh = 'h0001,
    CtlRegAddrC2hSourceLow = 'h0002,
    CtlRegAddrC2hSourceHigh = 'h0003,
    CtlRegAddTransSize = 'h0004
} ControlRegisterAddress deriving(Bits, Eq);

(*always_enabled, always_ready*)
interface UserLogic#(numeric type controlAddrWidth, numeric type dataStrbWidth);
    interface RawAxi4LiteSlave#(controlAddrWidth, dataStrbWidth) ctlAxil;
    interface RawAxiStreamSlave#(STREAM_KEEP_WIDTH, STREAM_DATA_WIDTH) dataAxisH2C;
    interface RawAxiStreamMaster#(STREAM_KEEP_WIDTH, STREAM_DATA_WIDTH) dataAxisC2H;
    interface DescriptorBypassIfc descBypH2C;
    interface DescriptorBypassIfc descBypC2H;
endinterface

(*always_enabled, always_ready*)
interface DescriptorBypassIfc;
    method Bool load();
    method Action ready(Bool is_ready);

    method Bit#(HOST_ADDR_WIDTH) dstAddr();
    method Bit#(HOST_ADDR_WIDTH) srcAddr();
    method Bit#(DESC_BYPASS_LENGTH_WIDTH) length();
    method Bit#(DESC_BYPASS_CONTROL_WIDTH) ctrl();
endinterface


module mkUserLogic(UserLogic#(CONTROL_ADDR_WIDTH, CONTROL_DATA_STRB_WIDTH));
    FIFOF#(Axi4LiteWrAddr#(CONTROL_ADDR_WIDTH)) ctrlWrAddrFifo <- mkFIFOF;
    FIFOF#(Axi4LiteWrData#(CONTROL_DATA_STRB_WIDTH)) ctrlWrDataFifo <- mkFIFOF;
    FIFOF#(Axi4LiteWrResp) ctrlWrRespFifo <- mkFIFOF;
    FIFOF#(Axi4LiteRdAddr#(CONTROL_ADDR_WIDTH)) ctrlRdAddrFifo <- mkFIFOF;
    FIFOF#(Axi4LiteRdData#(CONTROL_DATA_STRB_WIDTH)) ctrlRdDataFifo <- mkFIFOF;

    Integer streamFifoDepth = valueOf(STREAM_FIFO_DEPTH);
    FIFOF#(AxiStream#(STREAM_KEEP_WIDTH, STREAM_DATA_WIDTH)) streamFifo <- mkSizedFIFOF(streamFifoDepth);


    Reg#(Bit#(HOST_ADDR_WIDTH)) h2cSourceAddress <- mkRegU;
    Reg#(Bit#(HOST_ADDR_WIDTH)) c2hDestAddress <- mkRegU;
    Reg#(Bit#(DESC_BYPASS_LENGTH_WIDTH)) transSize[2] <- mkCReg(2, 0);


    let ctlAxilSlave <- mkPipeToRawAxi4LiteSlave(
        convertFifoToPipeIn(ctrlWrAddrFifo),
        convertFifoToPipeIn(ctrlWrDataFifo),
        convertFifoToPipeOut(ctrlWrRespFifo),

        convertFifoToPipeIn(ctrlRdAddrFifo),
        convertFifoToPipeOut(ctrlRdDataFifo)
    );

    let rawAxiStreamMaster <- mkPipeOutToRawAxiStreamMaster(convertFifoToPipeOut(streamFifo));
    let rawAxiStreamSlave <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(streamFifo));
    

    rule readControlCmd if (ctrlWrAddrFifo.notEmpty && ctrlWrDataFifo.notEmpty && transSize[1] == 0);
        ctrlWrAddrFifo.deq;
        ctrlWrDataFifo.deq;
        
        let addr_to_match = unpack(truncate(pack(ctrlWrAddrFifo.first.awAddr)));
        case (addr_to_match) matches
            CtlRegAddrH2cSourceLow: h2cSourceAddress[31:0] <= ctrlWrDataFifo.first.wData;
            CtlRegAddrH2cSourceHigh: h2cSourceAddress[63:32] <= ctrlWrDataFifo.first.wData;
            CtlRegAddrC2hSourceLow: c2hDestAddress[31:0] <= ctrlWrDataFifo.first.wData;
            CtlRegAddrC2hSourceHigh: c2hDestAddress[63:32] <= ctrlWrDataFifo.first.wData;
            CtlRegAddTransSize: begin
                transSize[1] <= truncate(ctrlWrDataFifo.first.wData);
                $display("set size");
            end
            default: begin 
                $display("unknown addr");
            end
        endcase

        ctrlWrRespFifo.enq(0);
    endrule

    rule respondToControlCmdRead;
        ctrlRdAddrFifo.deq;
        ctrlRdDataFifo.enq(Axi4LiteRdData{rResp: 'h0, rData: 'hABCD4321});
    endrule
    
    interface ctlAxil = ctlAxilSlave;
    interface dataAxisH2C = rawAxiStreamSlave;
    interface  dataAxisC2H = rawAxiStreamMaster;

    interface DescriptorBypassIfc descBypH2C;
        method Bool load();
            return transSize[0] != 0;
        endmethod

        method Action ready(Bool is_ready);
            if (is_ready) begin
                transSize[0] <= 0;
            end
        endmethod

        method Bit#(HOST_ADDR_WIDTH) dstAddr();
            return 0;
        endmethod

        method Bit#(HOST_ADDR_WIDTH) srcAddr();
            return h2cSourceAddress;
        endmethod

        method Bit#(DESC_BYPASS_LENGTH_WIDTH) length();
            return transSize[0];
        endmethod

        method Bit#(DESC_BYPASS_CONTROL_WIDTH) ctrl();
            return fromInteger(bypass_CONTROL_FLAGS);
        endmethod
    endinterface

    interface DescriptorBypassIfc descBypC2H;
        method Bool load();
            return transSize[0] != 0;
        endmethod

        method Action ready(Bool is_ready);
            if (is_ready) begin
                transSize[0] <= 0;
            end
        endmethod

        method Bit#(HOST_ADDR_WIDTH) dstAddr();
            return c2hDestAddress;
        endmethod

        method Bit#(HOST_ADDR_WIDTH) srcAddr();
            return 0;
        endmethod

        method Bit#(DESC_BYPASS_LENGTH_WIDTH) length();
            return transSize[0];
        endmethod

        method Bit#(DESC_BYPASS_CONTROL_WIDTH) ctrl();
            return fromInteger(bypass_CONTROL_FLAGS);
        endmethod
    endinterface

endmodule


module mkTB(Empty);

    UserLogic#(CONTROL_ADDR_WIDTH, CONTROL_DATA_STRB_WIDTH) dut <- mkUserLogic();

    FIFOF#(Axi4LiteWrAddr#(CONTROL_ADDR_WIDTH)) ctrlWrAddrFifo <- mkFIFOF;
    FIFOF#(Axi4LiteWrData#(CONTROL_DATA_STRB_WIDTH)) ctrlWrDataFifo <- mkFIFOF;
    FIFOF#(Axi4LiteWrResp) ctrlWrRespFifo <- mkFIFOF;
    FIFOF#(Axi4LiteRdAddr#(CONTROL_ADDR_WIDTH)) ctrlRdAddrFifo <- mkFIFOF;
    FIFOF#(Axi4LiteRdData#(CONTROL_DATA_STRB_WIDTH)) ctrlRdDataFifo <- mkFIFOF;

    FIFOF#(AxiStream#(STREAM_KEEP_WIDTH, STREAM_DATA_WIDTH)) streamTbSendFifo <- mkSizedFIFOF(1);
    FIFOF#(AxiStream#(STREAM_KEEP_WIDTH, STREAM_DATA_WIDTH)) streamTbRecvFifo <- mkSizedFIFOF(1);


    let ctlAxilMaster <- mkPipeToRawAxi4LiteMaster(
            convertFifoToPipeOut(ctrlWrAddrFifo),
            convertFifoToPipeOut(ctrlWrDataFifo),
            convertFifoToPipeIn(ctrlWrRespFifo),

            convertFifoToPipeOut(ctrlRdAddrFifo),
            convertFifoToPipeIn(ctrlRdDataFifo)
        );

    let tbStreamSender <- mkPipeOutToRawAxiStreamMaster(convertFifoToPipeOut(streamTbSendFifo));
    let tbStreamReceiver <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(streamTbRecvFifo));

    Reg#(Bool) running <- mkReg(False);

    Stmt testFlow = seq
        ctrlWrAddrFifo.enq(Axi4LiteWrAddr{awAddr:0, awProt:0});
        ctrlWrDataFifo.enq(Axi4LiteWrData{wData:'hEEEE, wStrb:1});
        delay(5);
        ctrlWrAddrFifo.enq(Axi4LiteWrAddr{awAddr:1, awProt:0});
        ctrlWrDataFifo.enq(Axi4LiteWrData{wData:'hBBBB, wStrb:1});
        delay(5);
        ctrlWrAddrFifo.enq(Axi4LiteWrAddr{awAddr:2, awProt:0});
        ctrlWrDataFifo.enq(Axi4LiteWrData{wData:'hCCCC, wStrb:1});
        delay(5);
        ctrlWrAddrFifo.enq(Axi4LiteWrAddr{awAddr:3, awProt:0});
        ctrlWrDataFifo.enq(Axi4LiteWrData{wData:'hDDDD, wStrb:1});
        delay(5);
        ctrlWrAddrFifo.enq(Axi4LiteWrAddr{awAddr:4, awProt:0});
        ctrlWrDataFifo.enq(Axi4LiteWrData{wData:'h0010, wStrb:1});
        delay(50);

    endseq;

    FSM test <- mkFSM(testFlow);

    rule forward_ctl;
        dut.ctlAxil.wrSlave.awValidData(
            ctlAxilMaster.wrMaster.awValid,
            ctlAxilMaster.wrMaster.awAddr,
            ctlAxilMaster.wrMaster.awProt);
        ctlAxilMaster.wrMaster.awReady(dut.ctlAxil.wrSlave.awReady);

        dut.ctlAxil.wrSlave.wValidData(
            ctlAxilMaster.wrMaster.wValid,
            ctlAxilMaster.wrMaster.wData,
            ctlAxilMaster.wrMaster.wStrb);
        ctlAxilMaster.wrMaster.wReady(dut.ctlAxil.wrSlave.wReady);

        dut.ctlAxil.wrSlave.bReady(ctlAxilMaster.wrMaster.bReady);
        ctlAxilMaster.wrMaster.bValidData(
            dut.ctlAxil.wrSlave.bValid,
            dut.ctlAxil.wrSlave.bResp);

        dut.ctlAxil.rdSlave.arValidData(
            ctlAxilMaster.rdMaster.arValid,
            ctlAxilMaster.rdMaster.arAddr,
            ctlAxilMaster.rdMaster.arProt);
        ctlAxilMaster.rdMaster.arReady(dut.ctlAxil.rdSlave.arReady);

        dut.ctlAxil.rdSlave.rReady(ctlAxilMaster.rdMaster.rReady);
        ctlAxilMaster.rdMaster.rValidData(
            dut.ctlAxil.rdSlave.rValid,
            dut.ctlAxil.rdSlave.rResp,
            dut.ctlAxil.rdSlave.rData);
        
    endrule

    rule forward_stream;
        dut.dataAxisH2C.tValid(
            tbStreamSender.tValid,
            tbStreamSender.tData,
            tbStreamSender.tKeep,
            tbStreamSender.tLast,
            tbStreamSender.tUser);
        tbStreamSender.tReady(dut.dataAxisH2C.tReady);

        tbStreamReceiver.tValid(
            dut.dataAxisC2H.tValid,
            dut.dataAxisC2H.tData,
            dut.dataAxisC2H.tKeep,
            dut.dataAxisC2H.tLast,
            dut.dataAxisC2H.tUser);
        dut.dataAxisC2H.tReady(tbStreamReceiver.tReady);
    endrule

    rule run if (running == False);
        test.start;
        running <= True;
        $display("start");
    endrule

    rule show_desc_byp;
        dut.descBypC2H.ready(True);
        // dut.descBypH2C.ready(True);
        $display("%x, load=%d, length=%x", dut.descBypC2H.dstAddr, dut.descBypC2H.load, dut.descBypC2H.length);
    endrule

    rule discard_response;
        ctrlWrRespFifo.deq;
        $display("get response");
    endrule

    rule stop if(running == True && test.done);
        $finish;
    endrule
endmodule