//`include "Control.v"
//`include "ProgramCounterProcessor.v"
//`include "SignExtend.v"
//`include "ALUControlDecoder.v"
//`include "DataWriteBack.v"
//`include "CompleteRegFile.v"
//`include "CompleteALU.v"


module SingleCycleMIPS( 
    clk,
    rst_n,     //reset when value is 0
    IR_addr,
    IR,
    ReadDataMem,
    CEN,        //chip enable: set low to read/write data
    WEN,        //write enable: set low to write data in memory
    A,          //address of data memory
    Data2Mem,
    OEN         //read enable
);

//==== in/out declaration =================================
    //-------- processor ----------------------------------
    input         clk, rst_n;
    input  [31:0] IR;
    output [31:0] IR_addr; //program counter
    //-------- data memory --------------------------------
    input  [31:0] ReadDataMem;  
    output        CEN;  
    output        WEN;  
    output  [6:0] A; 
    output [31:0] Data2Mem;  
    output        OEN;  

//==== reg/wire declaration ===============================


//==== wire connection to submodule ======================
    
    //output from Control
    wire RegDst;
    wire Jump; 
    wire Branch;
    wire BranchNotEqual;
    wire MemRead;
    wire MemtoReg;
    wire [1:0] ALUop;
    wire MemWrite;
    wire ALUSrc;
    wire RegWrite;
    wire SavePC;
    wire JumpReturn;
    wire ReadFromFpReg;
    wire FPURegWrite;
    wire ReadFromFpALU;
    wire Double;
    wire DoubleLoadStore;
    wire BranchOnFP;
    wire StoreFpReg;

    Control ctrl(
        .clk(clk),
        .opcode(IR[31:26]), //[31:26] of IR
        .fmt(IR[25:21]),
        .funct(IR[5:0]),
        .Jump(Jump),
        .RegDst(RegDst),
        .Branch(Branch),
        .BranchNotEqual(BranchNotEqual),
        .MemRead(MemRead),
        .MemtoReg(MemtoReg),
        .ALUop(ALUop),
        .MemWrite(MemWrite),
        .ALUSrc(ALUSrc),
        .RegWrite(RegWrite),
        .SavePC(SavePC),
        .JumpReturn(JumpReturn),
        .ReadFromFpReg(ReadFromFpReg),
        .FPURegWrite(FPURegWrite),
        .ReadFromFpALU(ReadFromFpALU),
        .Double(Double), //double operations
        .DoubleLoadStore(DoubleLoadStore),
        .BranchOnFP(BranchOnFP),
        .StoreFpReg(StoreFpReg)
    );

    //output from register file
    wire [63:0] readData1;
    wire [63:0] readData2;
    wire [63:0] writeData;
    wire [63:0] storeData;

    CompleteRegisterFile comRegFile(
        .clk(clk),
        .rst_n(rst_n),
        .IR(IR),
        .IR_addr(IR_addr),
        .writeData(writeData),
        .readData1(readData1),
        .readData2(readData2),
        .storeData(storeData),
        .RegWrite(RegWrite),
        .RegDst(RegDst),
        .SavePC(SavePC),
        .FPURegWrite(FPURegWrite),
        .ReadFromFpReg(ReadFromFpReg),
        .Double(Double),
        .StoreFpReg(StoreFpReg)
    );

    //output from sign extend
    wire [5:0] funct;
    wire [31:0] byteAddrOffset;

    SignExtend signExtend(
        .clk(clk),
        .rst_n(rst_n),
        .IR_LSB(IR[15:0]),
        .funct(funct), //g-bit funct for R-Type
        .byteAddrOffset(byteAddrOffset) //for branch instruction

    );

    wire [3:0] ALUControl;

    ALUControlDecoder ALUcontroller(
        .funct(IR[5:0]),
        .fmt(IR[25:21]),
        .ALUop(ALUop),
        .ALUControl(ALUControl)
    );

    wire ALUzero;
    wire [63:0] ALUresult;
    wire FPcond;

    CompleteALU comALU(

        .clk(clk),
        .rst_n(rst_n),
        .readData1(readData1),
        .readData2(readData2),
        .byteAddrOffset(byteAddrOffset),
        .ALUControl(ALUControl),
        .shamt(IR[10:6]),
        .ALUSrc(ALUSrc),
        .ReadFromFpALU(ReadFromFpALU),
        .ALUzero(ALUzero),
        .ALUresult(ALUresult),
        .FPcond(FPcond)
    );

    wire DoubleFlag;

    DataWriteBack dataWB(
        .clk(clk),
        .rst_n(rst_n),
        .ALUresult(ALUresult),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .MemtoReg(MemtoReg),
        .DoubleLoadStore(DoubleLoadStore),
        .A(A),
        .Data2Mem(Data2Mem),
        .storeData(storeData),
        .ReadDataMem(ReadDataMem),
        .writeData(writeData),
        .CEN(CEN),
        .WEN(WEN),
        .OEN(OEN),
        .DoubleFlag(DoubleFlag)
    );

    ProgramCounterProcessor PC(
        .clk(clk),
        .rst_n(rst_n),
        .pc_current(IR_addr),
        .byteAddrOffset(byteAddrOffset),
        .IRjumpAddrPart(IR[25:0]),
        .Branch(Branch),
        .BranchNotEqual(BranchNotEqual),
        .Jump(Jump),
        .JumpReturn(JumpReturn),
        .ALUzero(ALUzero),
        .BranchOnFP(BranchOnFP),
        .FPcond(FPcond),
        .DoubleLoadStore(DoubleLoadStore),
        .DoubleFlag(DoubleFlag),
        .savedIRAddr(readData1[63:32])
    );
//==== combinational part =================================

//==== sequential part ====================================

endmodule
        


module Control(
    clk,
    opcode,
    fmt,
    funct,
    Jump,
    RegDst,
    Branch,
    BranchNotEqual,
    MemRead,
    MemtoReg,
    ALUop,
    MemWrite,
    ALUSrc,
    RegWrite,
    SavePC,
    JumpReturn,
    ReadFromFpReg,
    FPURegWrite,
    ReadFromFpALU,
    Double, //double operations
    DoubleLoadStore,
    BranchOnFP,
    StoreFpReg

);
//==== in/out declaration =====
    input clk;
    input [5:0] opcode;
    input [4:0] fmt;
    input [5:0] funct;
    output reg Jump;
    output reg RegDst;
    output reg Branch;
    output reg BranchNotEqual;
    output reg MemRead;
    output reg MemtoReg;
    output reg [1:0] ALUop;
    output reg MemWrite;
    output reg ALUSrc;
    output reg RegWrite;
    output reg SavePC;
    output reg JumpReturn;
    output reg ReadFromFpReg;
    output reg FPURegWrite;
    output reg ReadFromFpALU;
    output reg Double;
    output reg DoubleLoadStore;
    output reg BranchOnFP;
    output reg StoreFpReg;

//==== reg/wire declaration =====
    

//==== combinational part ====
    always@(*) begin
        RegDst = 1;
        Jump = 0;
        Branch = 0;
        BranchNotEqual = 0;
        MemRead = 0;
        MemtoReg = 0;
        ALUop = 2'b00;
        MemWrite = 0;
        ALUSrc = 0;
        RegWrite = 0;
        SavePC = 0;
        JumpReturn = 0;
        ReadFromFpReg = 0; //1 means readData1, readData2 are from FPU and writeData will be written to FPU registers
        FPURegWrite = 0;
        ReadFromFpALU = 0;
        Double = 0;
        StoreFpReg = 0;
        DoubleLoadStore = 0;
        BranchOnFP = 0;

        if (opcode==6'h0) begin// opcode is 0 -> all R-type instructions, including "jr"
            ALUop = 2'b10;
            RegWrite = 1'b1; // RegWrite is 1 for R-type instructions

            if(funct == 6'b00_1000) begin //jr
                JumpReturn = 1'b1;
            end
        end
        else if (opcode==6'h8) begin //opcode is 8 -> addi
            ALUSrc = 1'b1;
            RegDst = 1'b0;
            RegWrite = 1'b1;
            //ALUop = 2'b00; already assigned
        end
        else if (opcode==6'h23) begin //opcode is 23hex -> lw
            RegDst = 0;
            MemRead = 1;
            MemtoReg = 1;
            ALUSrc = 1;
            RegWrite = 1;

        end
        else if (opcode==6'h2B) begin //opcode is 2Bhex -> sw
            MemWrite = 1;
            ALUSrc = 1;

        end
        else if (opcode==6'h4) begin //opcode is 4hex -> beq
            Branch = 1;
            ALUop = 2'b01;
    
        end
        else if (opcode==6'h5) begin //opcode is 5hex -> bne
            BranchNotEqual = 1;
            ALUop = 2'b01;

        end
        else if (opcode==6'h2) begin //opcode is 2hex-> j
            Jump = 1'b1;
            
        end
        else if (opcode==6'h3) begin //opcode is 3hex -> jal
            Jump = 1'b1;
            SavePC = 1'b1;
        end
        else if(opcode==6'h11 && fmt==5'h10) begin // add.s, sub.s, div.s, mul.s, compare
            ReadFromFpReg = 1'b1;
            FPURegWrite = 1'b1;
            ReadFromFpALU = 1'b1;
            ALUop = 2'b11;

            if(funct==6'h32) begin //c.eq.s (compare)
                FPURegWrite = 1'b1;
            end

        end
        else if(opcode==6'h11 && fmt==5'h11) begin // add.d, sub.d
            ReadFromFpReg = 1'b1;
            FPURegWrite = 1'b1;
            ReadFromFpALU = 1'b1;
            ALUop = 2'b11;
            Double = 1'b1;

        end
        else if(opcode==6'h11 && fmt==5'h8) begin //bclt
            BranchOnFP = 1'b1;

        end
        else if(opcode==6'h31) begin //lwc1 (load word: single)
            FPURegWrite = 1'b1;
            RegDst = 0;
            MemRead = 1;
            MemtoReg = 1;
            ALUSrc = 1;
            //ALUop = 2'b00; already assigned
        end
        else if(opcode==6'h39) begin //swcl (store word: single)
            MemWrite = 1;
            ALUSrc = 1;
            StoreFpReg = 1'b1;
            
        end
        else if(opcode==6'h35) begin //lwdl (load word: double)
            FPURegWrite = 1'b1;
            RegDst = 0;
            MemRead = 1;
            MemtoReg = 1;
            ALUSrc = 1;
            Double = 1'b1;
            DoubleLoadStore = 1'b1;

        end
        else if(opcode==6'h3d) begin //swdl (store word: double)
            MemWrite = 1;
            ALUSrc = 1;
            StoreFpReg = 1'b1;
            Double = 1'b1;
            DoubleLoadStore = 1'b1;

        end
        
    end

    //==== sequential part ====
    //always@(posedge clk) begin
        

    //end

endmodule

module ProgramCounterProcessor(
    clk,
    rst_n,
    pc_current,
    byteAddrOffset,
    IRjumpAddrPart,
    Branch,
    BranchNotEqual,
    Jump,
    JumpReturn,
    ALUzero, //output 1 if Reg[rs]==Reg[rt]
    BranchOnFP,
    FPcond,
    DoubleLoadStore,
    DoubleFlag,
    savedIRAddr
);
//==== in/out declaration =================================
    input clk, rst_n;
    output reg [31:0] pc_current; //the next IR_addr
    input [31:0] byteAddrOffset;
    input [25:0] IRjumpAddrPart;
    input Branch;
    input BranchNotEqual;
    input Jump;
    input JumpReturn;
    input ALUzero;
    input BranchOnFP;
    input FPcond;
    input DoubleLoadStore;
    input DoubleFlag;
    input [31:0] savedIRAddr;


//==== reg/wire declaration ===============================
    reg [31:0] pc_nxt;
    reg [31:0] pc_increment4;

    reg [31:0] jumpAddr;
    reg [31:0] branchAddr;

    
    reg branchMuxSelect;
    reg [31:0] branchMuxOutput;
    reg [31:0] jumpMuxOutput;
    //reg readALUzeroInput; //becomes 1 when the ALUzero is refreshed for the current_pc

    //==== combinational part ====
    always@(*) begin
        pc_increment4 = pc_current + 32'h0000_0004; //PC = PC +4
        jumpAddr = { pc_increment4[31:28], IRjumpAddrPart, 2'b00};
        branchAddr = (byteAddrOffset << 2) + pc_increment4;
    end

    always@(*) begin
        branchMuxSelect = (Branch & ALUzero) | (BranchNotEqual & ~(ALUzero) | (BranchOnFP & FPcond));

        if(branchMuxSelect == 1'b1) begin
            branchMuxOutput = branchAddr;
        end
        else begin
            branchMuxOutput = pc_increment4;
        end

        if(Jump == 1'b1) begin
            jumpMuxOutput = jumpAddr;
        end
        else begin
            jumpMuxOutput = branchMuxOutput;
        end
        /*
        if(JumpReturn == 1'b1) begin
            pc_nxt = savedIRAddr;
        end
        else begin
            pc_nxt = jumpMuxOutput;
        end
        */
        if(DoubleLoadStore && !DoubleFlag) begin
            pc_nxt = pc_current; 
        end
        else begin
            pc_nxt = (JumpReturn) ? savedIRAddr : jumpMuxOutput; 
        end
    end

    //==== sequential part ====
    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            pc_current <= 32'h0000_0000;
        end
        else begin
            pc_current <= pc_nxt;   
        end
    end

endmodule

module SignExtend(
    clk,
    rst_n,
    IR_LSB,
    funct, //g-bit funct for R-Type
    byteAddrOffset //for branch instruction

);
//==== in/out declaration =================================
    input clk, rst_n;
    input [15:0] IR_LSB;
    output reg [5:0] funct;
    output reg [31:0] byteAddrOffset;
    

//==== reg/wire declaration ===============================
    
    //==== combinational part ====
    always@(*) begin
        funct = IR_LSB[5:0];
        if(IR_LSB[15] == 1'b0) begin
            byteAddrOffset = {16'h0000, IR_LSB};
        end
        else begin
            byteAddrOffset = {16'hFFFF, IR_LSB}; //if the orginal 16 bit is a negative number
        end
    end

endmodule


module ALUControlDecoder(
    funct,
    fmt,
    ALUop,
    ALUControl
);
//==== in/out declaration =====
    input [5:0] funct;
    input [4:0] fmt; // yen
    input [1:0] ALUop;
    output reg [3:0] ALUControl;

//==== reg/wire declaration =====
    

//==== combinational part ====
    always@(*) begin
        ALUControl = 4'b0000;

        if(ALUop == 2'b00) begin
            ALUControl = 4'b0010;
        end
        else if(ALUop == 2'b01) begin
            ALUControl = 4'b0110;
        end
        else if(ALUop == 2'b10) begin
            if (funct == 6'h00) begin //sll
                ALUControl = 4'b1101;
            end
            else if (funct == 6'h02) begin //srl
                ALUControl = 4'b1110;
            end
            else if (funct == 6'h20) begin //add
                ALUControl = 4'b0010;
            end
            else if (funct == 6'h22) begin //sub
                ALUControl = 4'b0110;
            end
            else if (funct == 6'h24) begin //AND
                ALUControl = 4'b0000;
            end
            else if (funct == 6'h25) begin //OR
                ALUControl = 4'b0001;
            end
            else if (funct == 6'h2A) begin //slt
                ALUControl = 4'b0111;
            end
            else begin
                ALUControl = 4'd0;
            end
        end
        else if(ALUop == 2'b11) begin
            if (funct == 6'h0) begin
                if(fmt == 5'h10) begin //add.s
                    ALUControl = 4'b0011;   
                end
                else if(fmt == 5'h11) begin //add.d
                    ALUControl = 4'b0100; 
                end
            end
            else if (funct == 6'h1) begin 
                if(fmt == 5'h10) begin     //sub.s
                    ALUControl = 4'b0101;
                end
                else if(fmt == 5'h11) begin  //sub.d
                    ALUControl = 4'b1000;
                end
            end
            else if (funct == 6'h2) begin // mul.s
                ALUControl = 4'b1001;
            end
            else if (funct == 6'h3) begin // div.s
                ALUControl = 4'b1010;
            end 
            else if (funct == 6'h32) begin // compare
                ALUControl = 4'b1011;
            end
            else 
                ALUControl = 4'd0;
        end    
        else
            ALUControl = 4'd0;
        // ********************************************* //
    end

    //==== sequential part ====
    //always@(posedge clk) begin
        

    //end

endmodule


module DataWriteBack(
    clk,
    rst_n,
    ALUresult,
    MemRead,
    MemWrite,
    MemtoReg,
    DoubleLoadStore,
    A,
    Data2Mem,
    storeData,
    ReadDataMem,
    writeData,
    CEN,
    WEN,
    OEN,
    DoubleFlag
    
);
//==== in/out declaration =====
    input clk, rst_n;
    input [63:0] ALUresult;
    input MemRead, MemtoReg, MemWrite, DoubleLoadStore;
    output reg [6:0] A;
    output reg [31:0] Data2Mem;
    input [63:0] storeData;
    input [31:0] ReadDataMem;
    output reg [63:0] writeData;
    output reg CEN;
    output reg WEN;
    output reg OEN;
    output reg DoubleFlag;

//==== reg/wire declaration =====
    wire [31:0] ALUresultSingle;
    reg [31:0] doubleFirstLoad;

    assign ALUresultSingle = ALUresult[63:32];
//==== combinational part ====

    always@(*) begin
        if(!DoubleFlag) begin
            A = ALUresultSingle[8:2];
            Data2Mem = storeData[63:32];
        end
        else begin
            A = ALUresultSingle[8:2] + 7'b1;
            Data2Mem = storeData[31:0];
        end
    end

    always@(*) begin
        if(MemtoReg == 1'b1) begin
            if(DoubleLoadStore) begin
                if(!DoubleFlag) begin
                    writeData = 64'h0; //to be modified
                end
                else begin
                    writeData = {doubleFirstLoad, ReadDataMem};
                end  
            end
            else begin
                writeData = {ReadDataMem, 32'h0000_0000};
            end
        end
        else begin
            writeData = ALUresult;
        end
    end

    always@(*) begin
        if(MemRead == 1'b1) begin
            CEN = 1'b0;
            WEN = 1'b1;
            OEN = 1'b0;
        end
        else if(MemWrite == 1'b1) begin
            CEN = 1'b0;
            WEN = 1'b0;
            OEN = 1'b1;
        end
        else begin
            CEN = 1'b1; 
            WEN = 1'b1; 
            OEN = 1'b0;
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            DoubleFlag <= 1'b0;
            doubleFirstLoad <= 32'h0;
        end
        else begin
            DoubleFlag <= 1'b0;
            doubleFirstLoad <= doubleFirstLoad;

            if(DoubleLoadStore && !DoubleFlag) begin
                DoubleFlag <= 1'b1;
                doubleFirstLoad <= ReadDataMem;
            end
        end
        
    end

endmodule



module CompleteRegisterFile(
    clk,
    rst_n,
    IR,
    IR_addr,
    writeData,
    readData1,
    readData2,
    storeData,
    RegWrite,
    RegDst,
    SavePC,
    FPURegWrite,
    ReadFromFpReg,
    Double,
    StoreFpReg

);
//==== in/out declaration =====
    input clk, rst_n;
    input [31:0] IR;
    input [31:0] IR_addr;
    input [63:0] writeData;
    output reg [63:0] readData1;
    output reg [63:0] readData2;
    output reg [63:0] storeData;

    input RegWrite;
    input RegDst;
    input SavePC;
    input FPURegWrite;
    input ReadFromFpReg;
    input Double;
    input StoreFpReg;

//==== reg/wire declaration =====
    wire [31:0] readData1Reg;
    wire [31:0] readData2Reg;

    wire [63:0] readData1RegFPU;
    wire [63:0] readData2RegFPU;

//==== wire connection to submodule =======

    RegisterFile regFile(
        .clk(clk),
        .rst_n(rst_n),
        .IR(IR),
        .IR_addr(IR_addr),
        .writeData(writeData[63:32]),
        .readData1(readData1Reg),
        .readData2(readData2Reg),
        .RegWrite(RegWrite),
        .RegDst(RegDst),
        .SavePC(SavePC)
    );

    RegisterFileFPU regFileFPU( 
        .clk(clk),
        .rst_n(rst_n),
        .IR(IR),
        .IR_addr(IR_addr),
        .writeData(writeData),
        .readData1(readData1RegFPU),
        .readData2(readData2RegFPU),
        .FPURegWrite(FPURegWrite),
        .RegDst(RegDst),
        .Double(Double)
    );

//==== combinational part ====
    always@(*) begin
        if(ReadFromFpReg == 1'b1) begin
            readData1 = readData1RegFPU;
            readData2 = readData2RegFPU;
        end
        else begin
            readData1 = {readData1Reg, 32'h0000_0000 };
            readData2 = {readData2Reg, 32'h0000_0000 };
        end
        if(StoreFpReg) begin
            storeData = readData2RegFPU;
        end
        else begin
            storeData = {readData2Reg, 32'h0000_0000 };
        end
        
    end

    //==== sequential part ====
    //always@(posedge clk) begin
        

    //end

endmodule


module RegisterFile(
    clk,
    rst_n,
    IR,
    IR_addr,
    writeData,
    readData1,
    readData2,
    RegWrite,
    RegDst,
    SavePC
);
//==== parameter definition =======

//==== in/out declaration =================================
    input clk, rst_n;
    input [31:0] IR;
    input [31:0] IR_addr;
    input [31:0] writeData;
    output [31:0] readData1;
    output [31:0] readData2;

    //control signal
    input RegWrite;
    input RegDst;
    input SavePC;

//==== reg/wire declaration ===============================
    // The register file that includes 32 registers. Each register stores 32 bits.
    reg [31:0] registerFile [0:31];
    reg [4:0] writeAddr;
    integer i;

    assign readData1 = registerFile[ IR[25:21] ];
    assign readData2 = registerFile[ IR[20:16] ]; 

    always@(*) begin
        if(RegDst == 1'b0) begin
            writeAddr = IR[20:16];
        end
        else begin
            writeAddr = IR[15:11];
        end
    end

    always@ (posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            for (i=0; i<32; i=i+1) begin
                registerFile[i] <= 32'd0; //initial value = 0
            end
        end
        else begin
            if (RegWrite) begin
                registerFile[writeAddr] <= writeData;
            end
            else if(SavePC) begin
                registerFile[31] <= IR_addr + 32'h4;
            end
            else begin
                registerFile[writeAddr] <= registerFile[writeAddr];
            end
        end
    end
    //==== combinational part ====
    //==== sequential part ====
    

endmodule


module RegisterFileFPU(
    clk,
    rst_n,
    IR,
    IR_addr,
    writeData,
    readData1,
    readData2,
    FPURegWrite,
    RegDst,
    Double
    
);
//==== parameter definition =======

//==== in/out declaration =================================
    input clk, rst_n;
    input [31:0] IR;
    input [31:0] IR_addr;
    input [63:0] writeData;
    output [63:0] readData1; //for double
    output [63:0] readData2; //for double

    //control signal
    input FPURegWrite;
    input RegDst;
    input Double;

//==== reg/wire declaration ===============================
    // The register file that includes 32 registers. Each register stores 32 bits.
    reg [31:0] registerFile [0:31];
    reg [4:0] writeAddr;
    integer i;

    assign readData1[63:32] = registerFile[ IR[15:11] ];
    assign readData1[31:0] = Double ? registerFile[ IR[15:11] + 5'd1 ] : 32'h0; //read the second register value if Double
    assign readData2[63:32] = registerFile[ IR[20:16] ]; 
    assign readData2[31:0] = Double ? registerFile[ IR[20:16] + 5'd1 ] : 32'h0; 

    always@(*) begin
        //store floating point does not need writeAddr
        if(RegDst == 1'b0) begin 
            writeAddr = IR[20:16]; //for load floating point -> rt
        end
        else begin
            writeAddr = IR[10:6]; //for most inst-> fd
        end
    end

    always@ (posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            for (i=0; i<32; i=i+1) begin
                registerFile[i] <= 32'd0; //initial value = 0
            end
        end
        else begin
            if (FPURegWrite && Double) begin
                registerFile[writeAddr] <= writeData[63:32];
                registerFile[writeAddr + 5'd1] <= writeData[31:0];
            end
            else if(FPURegWrite) begin //only write data to F[rt], not F[rt+1]
                registerFile[writeAddr] <= writeData[63:32];
                registerFile[writeAddr + 5'd1] <= registerFile[writeAddr + 5'd1];
            end
            else begin
                registerFile[writeAddr] <= registerFile[writeAddr];
                registerFile[writeAddr + 5'd1] <= registerFile[writeAddr + 5'd1];
            end
        end
    end
    //==== combinational part ====
    //==== sequential part ====
    

endmodule


module CompleteALU(
    clk,
    rst_n,
    readData1,
    readData2,
    byteAddrOffset,
    ALUControl,
    shamt,
    ALUSrc,
    ReadFromFpALU,
    ALUzero,
    ALUresult,
    FPcond
);
//==== in/out declaration =====
    input clk, rst_n;
    input [63:0] readData1;
    input [63:0] readData2;
    input [31:0] byteAddrOffset;
    input [3:0] ALUControl;
    input [4:0] shamt;
    input ALUSrc;
    input ReadFromFpALU;
    output ALUzero;
    output reg signed [63:0] ALUresult;
    output FPcond;

//==== reg/wire declaration =====
    wire [31:0] ALUOriResult;
    wire [63:0] ALUFpResult;

//==== connnect submodules =====

    ArithLogicUnit ALUOriginal(
        .clk(clk),
        .rst_n(rst_n),
        .readData1(readData1[63:32]),
        .readData2(readData2[63:32]),
        .byteAddrOffset(byteAddrOffset),
        .ALUControl(ALUControl),
        .shamt(shamt),
        .ALUSrc(ALUSrc),
        .ALUzero(ALUzero),
        .ALUresult(ALUOriResult)
    );

    ArithLogicUnitFPU ALUFp(
        .clk(clk),
        .rst_n(rst_n),
        .readData1(readData1),
        .readData2(readData2),
        .ALUControl(ALUControl),
        .ALUresult(ALUFpResult),
        .FPcond(FPcond) 
    );

//==== combinational part ====
    always@(*) begin
        if(ReadFromFpALU == 1'b1)  begin
            ALUresult = ALUFpResult;
        end
        else begin
            ALUresult = {ALUOriResult, 32'h0000_0000};
        end
    end
    //==== sequential part ====

endmodule


module ArithLogicUnit(
    clk,
    rst_n,
    readData1,
    readData2,
    byteAddrOffset,
    ALUControl,
    shamt,
    ALUSrc,
    ALUzero,
    ALUresult
);
//==== in/out declaration =====
    input clk, rst_n;
    input [31:0] readData1;
    input [31:0] readData2;
    input [31:0] byteAddrOffset;
    input [3:0] ALUControl;
    input [4:0] shamt;
    input ALUSrc;
    output reg ALUzero;
    output reg signed [31:0] ALUresult;

//==== reg/wire declaration =====
    reg signed [31:0] ALUinput1;
    reg signed [31:0] ALUinput2;

//==== combinational part ====
    always@(*) begin
        ALUinput1 = readData1;
        if(ALUSrc == 1'b0) begin
            ALUinput2 = readData2;
        end
        else begin
            ALUinput2 = byteAddrOffset;
        end

        if (ALUinput1 == ALUinput2) begin
            ALUzero = 1'b1;
        end
        else begin
            ALUzero = 1'b0;
        end
    end

    always@(*) begin

        if(ALUControl == 4'b0000) begin //AND
            ALUresult = ALUinput1 & ALUinput2;
        end
        else if(ALUControl == 4'b0001) begin //OR
            ALUresult = ALUinput1 | ALUinput2;
        end
        else if(ALUControl == 4'b0010) begin //add
            ALUresult = ALUinput1 + ALUinput2;
        end
        else if(ALUControl == 4'b0110) begin //subtract
            ALUresult = ALUinput1 - ALUinput2;
        end
        else if(ALUControl == 4'b0111) begin //set on less than
            ALUresult = (ALUinput1 < ALUinput2) ? 32'h0000_0001 : 32'h0000_0000;
        end
        else if(ALUControl == 4'b1101) begin //shift left
            ALUresult = ALUinput2 << shamt;
        end
        else if(ALUControl == 4'b1110) begin //shift right
            ALUresult = ALUinput2 >> shamt;
        end
        else begin
            ALUresult = 0;
        end

    end

    //==== sequential part ====

endmodule


module ArithLogicUnitFPU(
    clk,
    rst_n,
    readData1,
    readData2,
    ALUControl,
    ALUresult,
    FPcond 
);
//==== in/out declaration =====
    input clk, rst_n;
    input [63:0] readData1;
    input [63:0] readData2;
    input [3:0] ALUControl;
    output reg signed [63:0] ALUresult;
    output reg FPcond;

//==== reg/wire declaration =====
    wire signed [63:0] ALUinput1;
    wire signed [63:0] ALUinput2;
    wire [2:0] round;
    wire opSingle;
    wire opDouble;

    //==== for submodule output===
    wire [31:0] addSubSingleResult;
    wire [7:0] addSubSingleStatus;
    wire [31:0] multSingleResult;
    wire [7:0] multSingleStatus;
    wire [31:0] divSingleResult;
    wire [7:0] divSingleStatus;

    wire [63:0] addSubDoubleResult;
    wire [7:0] addSubDoubleStatus;


//==== Connnect Submodules ======

    DW_fp_addsub addSubSingle( .a(ALUinput1[63:32]), .b(ALUinput2[63:32]), .rnd(round), .op(opSingle), .z(addSubSingleResult), .status(addSubSingleStatus) );
    DW_fp_mult multSingle( .a(ALUinput1[63:32]), .b(ALUinput2[63:32]), .rnd(round), .z(multSingleResult), .status(multSingleStatus) );
    DW_fp_div divSingle( .a(ALUinput1[63:32]), .b(ALUinput2[63:32]), .rnd(round), .z(divSingleResult), .status(divSingleStatus) );
    DW_fp_addsub #(.sig_width(52), .exp_width(11)) addSubDouble(.a(ALUinput1), .b(ALUinput2), .rnd(round), .op(opDouble), .z(addSubDoubleResult), .status(addSubDoubleStatus) );


//==== combinational part ====
    assign ALUinput1 = readData1;
    assign ALUinput2 = readData2;
    assign round = 3'b000;
    assign opSingle = (ALUControl==4'b0101) ? 1'b1 : 1'b0;
    assign opDouble = (ALUControl==4'b1000) ? 1'b1 : 1'b0;

    always@(*) begin
        //ALUresult = 64'h0;

        if(ALUControl == 4'b0011) begin //add.s
            ALUresult = { addSubSingleResult, 32'h0000_0000 };
        end
        else if(ALUControl == 4'b0100) begin //add.d
            ALUresult = addSubDoubleResult;
        end
        else if(ALUControl == 4'b0101) begin //sub.s
            ALUresult = { addSubSingleResult, 32'h0000_0000 };
        end
        else if(ALUControl == 4'b1000) begin //sub.d
            ALUresult = addSubDoubleResult;
        end
        else if(ALUControl == 4'b1001) begin //mul.s
            ALUresult = { multSingleResult, 32'h0000_0000 };
        end
        else if(ALUControl == 4'b1010) begin //div.s
            ALUresult = { divSingleResult, 32'h0000_0000 };
        end
	    else 
	        ALUresult = 64'h0;
    end

    always@ (posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            FPcond <= 1'b0;
        end
        else begin
            if (ALUControl == 4'b1011) begin
                FPcond <= (ALUinput1 == ALUinput2) ? 1'b1 : 1'b0 ; //update FPcond in the next cycle
            end
            else begin
                FPcond <= FPcond;
            end
        end
    end
    //==== sequential part ====

endmodule
