# Single-Cycle-MIPS

Microprocessor without Interlocked Pipeline Stages (MIPS) is a widely used instruction set architecture. In this project, we’re going to implement the single-cycle MIPS architecture using Verilog. This processor supports floating point and double instructions as well.

## Instruction Set
The instructions supported are listed as follows:
* Original Instructions

Instruction | Type | Opcode | Funct
----------- | ---- | ------ | ----- 
sll | R | 0 | 00 
srl | R | 0 | 02 
add | R | 0 | 20
sub | R | 0 | 22
and | R | 0 | 24
or | R | 0 | 25
slt | R | 0 | 2A
addi | I | 8 | N/A
lw | I | 23 | N/A
sw | I | 2B | N/A
beq | I | 4 | N/A
bne | I | 5 | N/A
j | J | 2 | N/A
jal | J | 3 | N/A
jr | R | 0 | 8

* Floating Point Unit (FPU) Instructions

Instruction | Type | Opcode (Hex) | FMT(Hex) | Func code (Hex)
------| ---- | ------ | ----- | -----
add.s | FR | 11 | 10 | 00
sub.s | FR | 11 | 10 | 01
mul.s | FR | 11 | 10 | 02
div.s | FR | 11 | 10 | 03
lwcl | I | 31 | N/A | N/A
swcl | I | 39 | N/A | N/A
c.eq.s | FR | 11 | 10 | 32
bclt | FI | 11 | 8 | N/A
add.d | FR | 11 | 11 | 00
sub.d | FR | 11 | 11 | 01
ldcl | I | 35 | N/A | N/A
sdcl | I | 3D | N/A | N/A
 

## The architecture 
The framework can be shown as follows, while both the register file and ALU have 2 parts, one for the original instructions and the other for the FPU.
![image](/img/MIPS.png "MIPS architecture")
<center>Centered text</center>


