//`include "Control.v"
//`include "ProgramCounterProcessor.v"
//`include "RegFile.v"
//`include "SignExtend.v"
//`include "ALUControlDecoder.v"
//`include "ArithLogicUnit.v"
//`include "DataWriteBack.v"

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

    Control ctrl(
        .clk(clk),
        .opcode(IR[31:26]), //[31:26] of IR
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
        .JumpReturn(JumpReturn)
    );

    //output from register file
    wire [31:0] readData1;
    wire [31:0] readData2;
    wire [31:0] writeData;

    RegisterFile regFile(
        .clk(clk),
        .rst_n(rst_n),
        .IR(IR),
        .IR_addr(IR_addr),
        .writeData(writeData),
        .readData1(readData1),
        .readData2(readData2),
        .RegWrite(RegWrite),
        .RegDst(RegDst),
        .SavePC(SavePC)
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
        .ALUop(ALUop),
        .ALUControl(ALUControl)
    );

    wire ALUzero;
    wire [31:0] ALUresult;

    ArithLogicUnit ALU(
        .clk(clk),
        .rst_n(rst_n),
        .readData1(readData1),
        .readData2(readData2),
        .byteAddrOffset(byteAddrOffset),
        .ALUControl(ALUControl),
        .shamt(IR[10:6]),
        .ALUSrc(ALUSrc),
        .ALUzero(ALUzero),
        .ALUresult(ALUresult)
    );

    

    DataWriteBack dataWB(
        .clk(clk),
        .rst_n(rst_n),
        .ALUresult(ALUresult),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .MemtoReg(MemtoReg),
        .A(A),
        .Data2Mem(Data2Mem),
        .readData2(readData2),
        .ReadDataMem(ReadDataMem),
        .writeData(writeData),
        .CEN(CEN),
        .WEN(WEN),
        .OEN(OEN)
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
        .savedIRAddr(readData1)
    );
//==== combinational part =================================

//==== sequential part ====================================

endmodule
		


module Control(
    clk,
    opcode,
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
    JumpReturn

);
//==== in/out declaration =====
    input clk;
    input [5:0] opcode;
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
        branchMuxSelect = (Branch & ALUzero) | (BranchNotEqual & ~(ALUzero));

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
        
        if(JumpReturn == 1'b1) begin
            pc_nxt = savedIRAddr;
        end
        else begin
            pc_nxt = jumpMuxOutput;
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
    ALUop,
    ALUControl
);
//==== in/out declaration =====
    input [5:0] funct;
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
            
        end    
    end

    //==== sequential part ====
    //always@(posedge clk) begin
        

    //end

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
    ALUresult,
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

module DataWriteBack(
    clk,
    rst_n,
    ALUresult,
    MemRead,
    MemWrite,
    MemtoReg,
    A,
    Data2Mem,
    readData2,
    ReadDataMem,
    writeData,
    CEN,
    WEN,
    OEN
);
//==== in/out declaration =====
    input clk, rst_n;
    input [31:0] ALUresult;
    input MemRead, MemtoReg, MemWrite;
    output reg [6:0] A;
    output [31:0] Data2Mem;
    input [31:0] readData2;
    input [31:0] ReadDataMem;
    output reg [31:0] writeData;
    output reg CEN;
    output reg WEN;
    output reg OEN;

//==== reg/wire declaration =====

    assign Data2Mem = readData2;
//==== combinational part ====

    always@(*) begin
        A = ALUresult[8:2];
    end

    always@(*) begin
        if(MemtoReg == 1'b1) begin
            writeData = ReadDataMem;
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

endmodule
