import FIFOF :: *;
import Connectable :: *;
import GetPut :: *;
import StmtFSM :: *;

import BusConversion :: *;
import SemiFifo :: *;
import AxiStreamTypes :: *;
import Axi4Types :: *;


typedef 4 AXI_ID_WIDTH;
typedef 1 AXI_USER_ID_WIDTH;
typedef 12 CONTROL_ADDR_WIDTH;
typedef 64 CONTROL_DATA_STRB_WIDTH;
typedef TMul#(CONTROL_DATA_STRB_WIDTH, 8) CONTROL_DATA_WIDTH;
typedef 64 HOST_ADDR_WIDTH;
typedef 28 DESC_BYPASS_LENGTH_WIDTH;
typedef 16 DESC_BYPASS_CONTROL_WIDTH;
typedef 4 STREAM_FIFO_DEPTH;
typedef 512 STREAM_DATA_WIDTH;
typedef TDiv#(STREAM_DATA_WIDTH, 8) STREAM_KEEP_WIDTH;

Integer bypass_CONTROL_FLAGS = 'h01;

typedef enum {
    CtlRegAddrH2cSourceLow = 'h0000,
    CtlRegAddrH2cSourceHigh = 'h0004,
    CtlRegAddrC2hSourceLow = 'h0008,
    CtlRegAddrC2hSourceHigh = 'h00C,
    CtlRegAddTransSize = 'h0010,
    CtlRegDemoStart = 'h0014,
    CtlRegDemoPoll = 'h0018

} ControlRegisterAddress deriving(Bits, Eq);


(*always_enabled, always_ready*)
interface UserLogic#(numeric type controlAddrWidth, numeric type dataStrbWidth, numeric type idWidth, numeric type usrWidth);
    interface RawAxi4Slave#(idWidth, controlAddrWidth, dataStrbWidth, usrWidth) ctlAxi4;
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


module mkUserLogic(UserLogic#(CONTROL_ADDR_WIDTH, CONTROL_DATA_STRB_WIDTH, AXI_ID_WIDTH, AXI_USER_ID_WIDTH));
    FIFOF#(Axi4WrAddr#(AXI_ID_WIDTH, CONTROL_ADDR_WIDTH, AXI_USER_ID_WIDTH)) ctrlWrAddrFifo <- mkFIFOF;
    FIFOF#(Axi4WrData#(AXI_ID_WIDTH, CONTROL_DATA_STRB_WIDTH, AXI_USER_ID_WIDTH)) ctrlWrDataFifo <- mkFIFOF;
    FIFOF#(Axi4WrResp#(AXI_ID_WIDTH, AXI_USER_ID_WIDTH)) ctrlWrRespFifo <- mkFIFOF;
    FIFOF#(Axi4RdAddr#(AXI_ID_WIDTH, CONTROL_ADDR_WIDTH, AXI_USER_ID_WIDTH)) ctrlRdAddrFifo <- mkFIFOF;
    FIFOF#(Axi4RdData#(AXI_ID_WIDTH, CONTROL_DATA_STRB_WIDTH, AXI_USER_ID_WIDTH)) ctrlRdDataFifo <- mkFIFOF;

    Integer streamFifoDepth = valueOf(STREAM_FIFO_DEPTH);
    FIFOF#(AxiStream#(STREAM_KEEP_WIDTH, STREAM_DATA_WIDTH)) streamFifo <- mkSizedFIFOF(streamFifoDepth);


    Reg#(Bit#(HOST_ADDR_WIDTH)) h2cSourceAddress <- mkRegU;
    Reg#(Bit#(HOST_ADDR_WIDTH)) c2hDestAddress <- mkRegU;
    Reg#(Bit#(DESC_BYPASS_LENGTH_WIDTH)) transSize[2] <- mkCReg(2, 0);
    Reg#(Bool) startReceived <- mkReg(False); 


    let ctlAxi4Slave <- mkPipeToRawAxi4Slave(
        convertFifoToPipeIn(ctrlWrAddrFifo),
        convertFifoToPipeIn(ctrlWrDataFifo),
        convertFifoToPipeOut(ctrlWrRespFifo),

        convertFifoToPipeIn(ctrlRdAddrFifo),
        convertFifoToPipeOut(ctrlRdDataFifo)
    );

    let rawAxiStreamMaster <- mkPipeOutToRawAxiStreamMaster(convertFifoToPipeOut(streamFifo));
    let rawAxiStreamSlave <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(streamFifo));
    

    (* conflict_free = "respondToControlCmdRead, readControlCmd" *)
    rule readControlCmd if (ctrlWrAddrFifo.notEmpty && ctrlWrDataFifo.notEmpty && transSize[1] == 0);
        ctrlWrAddrFifo.deq;
        ctrlWrDataFifo.deq;
        
        let addr_to_match = unpack(truncate(pack(ctrlWrAddrFifo.first.awAddr)));
        case (addr_to_match) matches
            CtlRegAddrH2cSourceLow: h2cSourceAddress[31:0] <= ctrlWrDataFifo.first.wData[31:0];
            CtlRegAddrH2cSourceHigh: h2cSourceAddress[63:32] <= ctrlWrDataFifo.first.wData[31:0];
            CtlRegAddrC2hSourceLow: c2hDestAddress[31:0] <= ctrlWrDataFifo.first.wData[31:0];
            CtlRegAddrC2hSourceHigh: c2hDestAddress[63:32] <= ctrlWrDataFifo.first.wData[31:0];
            CtlRegAddTransSize: begin
                transSize[1] <= truncate(ctrlWrDataFifo.first.wData[31:0]);
                $display("set size");
            end
            CtlRegDemoStart: begin
                if (startReceived == False) begin
                    startReceived <= True;
                end
                $display("set demo");
            end
            default: begin 
                $display("unknown addr");
            end
        endcase

        ctrlWrRespFifo.enq(Axi4WrResp{bId:0, bResp: 0, bUser: 0});
    endrule

    rule respondToControlCmdRead;
        ctrlRdAddrFifo.deq;
        let addr_to_match = unpack(truncate(pack(ctrlRdAddrFifo.first.arAddr)));
        Bit#(CONTROL_DATA_WIDTH) respData = 'h0;
        case (addr_to_match) matches
            CtlRegDemoPoll: begin
                if (startReceived == True) begin
                    startReceived <= False;
                    respData = 'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
                end
                ctrlRdDataFifo.enq(Axi4RdData{rResp: 'h0, rData: respData, rUser: 0, rLast: True, rId: 0});
            end
            default: ctrlRdDataFifo.enq(Axi4RdData{rResp: 'h0, rData: 'h3F3E3D3C3B3A393837363534333231302F2E2D2C2B2A292827262524232221201F1E1D1C1B1A191817161514131211100F0E0D0C0B0A09080706050403020100, rUser: 0, rLast: True, rId: 0});
        endcase
        
    endrule
    
    interface ctlAxi4 = ctlAxi4Slave;
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

    UserLogic#(CONTROL_ADDR_WIDTH, CONTROL_DATA_STRB_WIDTH, AXI_ID_WIDTH, AXI_USER_ID_WIDTH) dut <- mkUserLogic();

    FIFOF#(Axi4WrAddr#(AXI_ID_WIDTH, CONTROL_ADDR_WIDTH, AXI_USER_ID_WIDTH)) ctrlWrAddrFifo <- mkFIFOF;
    FIFOF#(Axi4WrData#(AXI_ID_WIDTH, CONTROL_DATA_STRB_WIDTH, AXI_USER_ID_WIDTH)) ctrlWrDataFifo <- mkFIFOF;
    FIFOF#(Axi4WrResp#(AXI_ID_WIDTH, AXI_USER_ID_WIDTH)) ctrlWrRespFifo <- mkFIFOF;
    FIFOF#(Axi4RdAddr#(AXI_ID_WIDTH, CONTROL_ADDR_WIDTH, AXI_USER_ID_WIDTH)) ctrlRdAddrFifo <- mkFIFOF;
    FIFOF#(Axi4RdData#(AXI_ID_WIDTH, CONTROL_DATA_STRB_WIDTH, AXI_USER_ID_WIDTH)) ctrlRdDataFifo <- mkFIFOF;

    FIFOF#(AxiStream#(STREAM_KEEP_WIDTH, STREAM_DATA_WIDTH)) streamTbSendFifo <- mkSizedFIFOF(1);
    FIFOF#(AxiStream#(STREAM_KEEP_WIDTH, STREAM_DATA_WIDTH)) streamTbRecvFifo <- mkSizedFIFOF(1);


    let ctlAxi4Master <- mkPipeToRawAxi4Master(
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
        ctrlWrAddrFifo.enq(Axi4WrAddr{awAddr:0, awProt:0, awUser: 0, awQos: 0, awCache: 0, awLock: 0, awBurst: 0, awSize: 3'b110, awLen: 0, awId: 0});
        ctrlWrDataFifo.enq(Axi4WrData{wData:'hEEEE, wStrb:1, wUser: 0, wLast: True, wId: 0});
        // delay(5);

        // 1st Read
        ctrlRdAddrFifo.enq(Axi4RdAddr{arAddr: 'h18, arId: 0, arLen: 0, arSize: 3'b110, arBurst: 0, arLock: 0, arCache: 0, arProt: 0, arQos: 0, arUser: 0});
        // delay(5);
        $display(fshow(ctrlRdDataFifo.first));
        ctrlRdDataFifo.deq;

        // new trigger
        ctrlWrAddrFifo.enq(Axi4WrAddr{awAddr:'h14, awProt:0, awUser: 0, awQos: 0, awCache: 0, awLock: 0, awBurst: 0, awSize: 3'b110, awLen: 0, awId: 0});
        ctrlWrDataFifo.enq(Axi4WrData{wData:'h1, wStrb:1, wUser: 0, wLast: True, wId: 0});
        // delay(5);
        
        // 2nd read
        ctrlRdAddrFifo.enq(Axi4RdAddr{arAddr: 'h18, arId: 0, arLen: 0, arSize: 3'b110, arBurst: 0, arLock: 0, arCache: 0, arProt: 0, arQos: 0, arUser: 0});
        // delay(5);
        $display(fshow(ctrlRdDataFifo.first));
        ctrlRdDataFifo.deq;

        // 3rd read
        ctrlRdAddrFifo.enq(Axi4RdAddr{arAddr: 'h18, arId: 0, arLen: 0, arSize: 3'b110, arBurst: 0, arLock: 0, arCache: 0, arProt: 0, arQos: 0, arUser: 0});
        // delay(5);
        $display(fshow(ctrlRdDataFifo.first));
        ctrlRdDataFifo.deq;

        // new trigger
        ctrlWrAddrFifo.enq(Axi4WrAddr{awAddr:'h14, awProt:0, awUser: 0, awQos: 0, awCache: 0, awLock: 0, awBurst: 0, awSize: 3'b110, awLen: 0, awId: 0});
        ctrlWrDataFifo.enq(Axi4WrData{wData:'h1, wStrb:1, wUser: 0, wLast: True, wId: 0});
        // delay(5);

        // 4th read
        ctrlRdAddrFifo.enq(Axi4RdAddr{arAddr: 'h18, arId: 0, arLen: 0, arSize: 3'b110, arBurst: 0, arLock: 0, arCache: 0, arProt: 0, arQos: 0, arUser: 0});
        // delay(5);
        $display(fshow(ctrlRdDataFifo.first));
        ctrlRdDataFifo.deq;

        // 5th rad
        ctrlRdAddrFifo.enq(Axi4RdAddr{arAddr: 'h18, arId: 0, arLen: 0, arSize: 3'b110, arBurst: 0, arLock: 0, arCache: 0, arProt: 0, arQos: 0, arUser: 0});
        // delay(5);
        $display(fshow(ctrlRdDataFifo.first));
        ctrlRdDataFifo.deq;
        
        // ctrlWrAddrFifo.enq(Axi4WrAddr{awAddr:1, awProt:0});
        // ctrlWrDataFifo.enq(Axi4WrData{wData:'hBBBB, wStrb:1});
        // delay(5);
        // ctrlWrAddrFifo.enq(Axi4WrAddr{awAddr:2, awProt:0});
        // ctrlWrDataFifo.enq(Axi4WrData{wData:'hCCCC, wStrb:1});
        // delay(5);
        // ctrlWrAddrFifo.enq(Axi4WrAddr{awAddr:3, awProt:0});
        // ctrlWrDataFifo.enq(Axi4WrData{wData:'hDDDD, wStrb:1});
        // delay(5);
        // ctrlWrAddrFifo.enq(Axi4WrAddr{awAddr:4, awProt:0});
        // ctrlWrDataFifo.enq(Axi4WrData{wData:'h0010, wStrb:1});
        // delay(50);

    endseq;

    FSM test <- mkFSM(testFlow);

    rule forward_ctl;
        dut.ctlAxi4.wrSlave.awValidData(
            ctlAxi4Master.wrMaster.awValid,
            ctlAxi4Master.wrMaster.awId,
            ctlAxi4Master.wrMaster.awAddr,
            ctlAxi4Master.wrMaster.awLen,
            ctlAxi4Master.wrMaster.awSize,
            ctlAxi4Master.wrMaster.awBurst,
            ctlAxi4Master.wrMaster.awLock,
            ctlAxi4Master.wrMaster.awCache,
            ctlAxi4Master.wrMaster.awProt,
            ctlAxi4Master.wrMaster.awQos,
            ctlAxi4Master.wrMaster.awUser);
        ctlAxi4Master.wrMaster.awReady(dut.ctlAxi4.wrSlave.awReady);

        dut.ctlAxi4.wrSlave.wValidData(
            ctlAxi4Master.wrMaster.wValid,
            ctlAxi4Master.wrMaster.wId,
            ctlAxi4Master.wrMaster.wData,
            ctlAxi4Master.wrMaster.wStrb,
            ctlAxi4Master.wrMaster.wLast,
            ctlAxi4Master.wrMaster.wUser);
        ctlAxi4Master.wrMaster.wReady(dut.ctlAxi4.wrSlave.wReady);

        dut.ctlAxi4.wrSlave.bReady(ctlAxi4Master.wrMaster.bReady);
        ctlAxi4Master.wrMaster.bValidData(
            dut.ctlAxi4.wrSlave.bValid,
            dut.ctlAxi4.wrSlave.bId,
            dut.ctlAxi4.wrSlave.bResp,
            dut.ctlAxi4.wrSlave.bUser);

        dut.ctlAxi4.rdSlave.arValidData(
            ctlAxi4Master.rdMaster.arValid,
            ctlAxi4Master.rdMaster.arId,
            ctlAxi4Master.rdMaster.arAddr,
            ctlAxi4Master.rdMaster.arLen,
            ctlAxi4Master.rdMaster.arSize,
            ctlAxi4Master.rdMaster.arBurst,
            ctlAxi4Master.rdMaster.arLock,
            ctlAxi4Master.rdMaster.arCache,
            ctlAxi4Master.rdMaster.arProt,
            ctlAxi4Master.rdMaster.arQos,
            ctlAxi4Master.rdMaster.arUser);
        ctlAxi4Master.rdMaster.arReady(dut.ctlAxi4.rdSlave.arReady);

        dut.ctlAxi4.rdSlave.rReady(ctlAxi4Master.rdMaster.rReady);
        ctlAxi4Master.rdMaster.rValidData(
            dut.ctlAxi4.rdSlave.rValid,
            dut.ctlAxi4.rdSlave.rId,
            dut.ctlAxi4.rdSlave.rData,
            dut.ctlAxi4.rdSlave.rResp,
            dut.ctlAxi4.rdSlave.rLast,
            dut.ctlAxi4.rdSlave.rUser);
        
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
        $display("get write response");
    endrule

    rule stop if(running == True && test.done);
        $finish;
    endrule
endmodule