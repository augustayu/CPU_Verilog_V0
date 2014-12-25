`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:15:05 12/18/2014 
// Design Name: 
// Module Name:    CPU 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
// data transfer & Arithmetic
`define NOP 5'b00000
`define HALT 5'b00001
`define LOAD 5'b00010
`define STORE 5'b00011
`define LDIH 5'b10000
`define ADD 5'b01000
`define ADDI 5'b01001
`define ADDC 5'b10001
`define SUB 5'b01011
`define SUBI 5'b10011
`define SUBC 5'b10111
`define CMP 5'b01100
// control
`define JUMP 5'b11000
`define JMPR 5'b11001
`define BZ 5'b11010
`define BNZ 5'b11011
`define BN 5'b11100
`define BNN 5'b11101
`define BC 5'b11110
`define BNC 5'b11111
// logic / shift
`define AND 5'b01101
`define OR 5'b01111
`define XOR 5'b01110
`define SLL 5'b00100
`define SRL 5'b00110
`define SLA 5'b00101
`define SRA 5'b00111
// general register
`define gr0  3'b000
`define gr1  3'b001
`define gr2  3'b010
`define gr3  3'b011
`define gr4  3'b100
`define gr5  3'b101
`define gr6  3'b110
`define gr7  3'b111
// FSM
`define idle 1'b0
`define exec 1'b1

module CPU(
 input clock, enable, reset, start,
 input  [15:0] d_datain,
 input  [15:0] i_datain,
 output reg [7:0] d_addr,
 output reg [15:0] d_dataout,
 output reg d_we
    );

reg signed [15:0] gr [7:0];
reg signed [15:0] data_memory [255:0];
reg signed [15:0] op_memory [255:0];
reg nf, zf, cf;
reg state, next_state;
reg dw;
reg [7:0] pc;
reg [15:0] id_ir;
reg [15:0] wb_ir;
reg [15:0] ex_ir;
reg [15:0] mem_ir;
reg [15:0] smdr = 0;
reg [15:0] smdr1 = 0;
reg [15:0] reg_C1;
reg [15:0] reg_A;
reg [15:0] reg_B;
reg [15:0] reg_C;
reg [15:0] ALUo;




//************* CPU control *************//
always @(posedge clock)
	begin
		if (!reset)
			state <= `idle;
		else
			state <= next_state;
	end
	
always @(*)
	begin
		case (state)
			`idle : 
				if ((enable == 1'b1) 
				&& (start == 1'b1))
					next_state <= `exec;
				else	
					next_state <= `idle;
			`exec :
				if ((enable == 1'b0) 
				|| (wb_ir[15:11] == `HALT))
					next_state <= `idle;
				else
					next_state <= `exec;
		endcase
	end
	
	
	
//************* IF *************//
always @(posedge clock or negedge reset)
	begin
		if (!reset)
			begin
            id_ir <= 16'b0000_0000_0000_0000;
            pc <= 8'b0000_0000;
			end
			
		else if (state ==`exec)
			begin
				id_ir <= i_datain;
				// BZ & BNZ
				if(((mem_ir[15:11] == `BZ)
					&& (zf == 1'b1)) 
				|| ((mem_ir[15:11] == `BNZ)
					&& (zf == 1'b0)))
					pc <= reg_C[7:0];
				// BN & BNN	
				else if(((mem_ir[15:11] == `BN)
					&& (nf == 1'b1)) 
				|| ((mem_ir[15:11] == `BNN)
					&& (nf == 1'b0)))
					pc <= reg_C[7:0];
				// BC & BNC	
				else if(((mem_ir[15:11] == `BC)
					&& (cf == 1'b1)) 
				|| ((mem_ir[15:11] == `BNC)
					&& (cf == 1'b0)))
					pc <= reg_C[7:0];
				// JUMP 
				else if((mem_ir[15:11] == `JUMP)			
				|| (mem_ir[15:11] == `JMPR))					
					pc <= reg_C[7:0];
				else
					pc <= pc + 1;
			end
	end
	
	
//************* ID *************//
always @(posedge clock or negedge reset) 
    begin
	    if (!reset)
			begin
				ex_ir <= 16'b0000_0000_0000_0000;
				reg_A <= 0;
				reg_B <= 0;
			end
			
		else if (state == `exec)
			begin
				ex_ir <= id_ir;
			    // ********************reg_A 赋值******************* //
				// reg_A <= r1: 要用到 r1 参与运算的指令，即除 "JUMP" 外的控制指令和一些运算指令,将寄存器r1中的值赋给reg_A
				if ((id_ir[15:14] == 2'b11 && id_ir[15:11] != `JUMP) 
				|| (id_ir[15:11] == `LDIH)
				|| (id_ir[15:11] == `ADDI)
				|| (id_ir[15:11] == `SUBI))
					reg_A <= gr[(id_ir[10:8])];
				//reg_A <= r2: 如果运算中不用到 r1，要用到 r2， 则将 gr[r2]
				else 
					reg_A <= gr[id_ir[6:4]];
					
				//************************* reg_B赋值************************//
				if  ((id_ir[15:11] == `ADD)
                    || (id_ir[15:11] == `ADDC)
				    || (id_ir[15:11] == `SUB)
				    || (id_ir[15:11] == `SUBC)
					|| (id_ir[15:11] == `CMP)
					|| (id_ir[15:11] == `AND)
					|| (id_ir[15:11] == `OR)
					|| (id_ir[15:11] == `XOR))
					
					reg_B <= gr[id_ir[2:0]];
					
				else if (id_ir[15:11] == `STORE)
					begin
						reg_B <= {12'b0000_0000_0000, id_ir[3:0]}; //value3
						smdr <= gr[id_ir[10:8]]; // r1
					end
				
			end
	end		

	//************* ALUo *************//	
always @ (*) 
    begin
	    // {val2, val3}
		if  (ex_ir[15:11] == `JUMP)
			ALUo <= {8'b0, ex_ir[7:0]};
		// 跳转指令 r1 + {vla2, val3}
		else if  (ex_ir[15:14] == 2'b11)
		    ALUo <= reg_A + {8'b0, ex_ir[7:0]};
	    //算数运算，逻辑运算，计算结果到ALUo， 并计算cf标志位
		else 
		begin
			case(ex_ir[15:11])
			`LOAD: ALUo <= reg_A + {12'b0000_0000_0000, ex_ir[3:0]};
			`STORE: ALUo <= reg_A + reg_B;
			`LDIH: {cf, ALUo} <= reg_A + { ex_ir[7:0], 8'b0 };
			`ADD: {cf, ALUo} <= reg_A + reg_B;
			`ADDI:{cf, ALUo} <= reg_A + { 8'b0, ex_ir[7:0] };
			`ADDC: {cf, ALUo} <= reg_A + reg_B + cf;
			`SUB: {cf, ALUo} <= {{1'b0, reg_A} - reg_B};
			`SUBI: {cf, ALUo} <= {1'b0, reg_A }- { 8'b0, ex_ir[7:0] };
			`SUBC:{cf, ALUo} <= {{1'b0, reg_A} - reg_B - cf};
			`CMP: {cf, ALUo} <= {{1'b0, reg_A} - reg_B};
			`AND: {cf, ALUo} <= {1'b0, reg_A & reg_B};
			`OR: {cf, ALUo} <= {1'b0, reg_A | reg_B};
			`XOR: {cf, ALUo} <= {1'b0, reg_A ^ reg_B};
			`SLL: {cf, ALUo} <= {reg_A[16 - ex_ir[3:0]], reg_A << ex_ir[3:0]};
			`SRL: {cf, ALUo} <= {reg_A[ex_ir[3:0] - 1], reg_A >> ex_ir[3:0]};
			`SLA: {cf, ALUo} <= {reg_A[ex_ir[3:0] - 1], reg_A <<< ex_ir[3:0]};
			`SRA: {cf, ALUo} <= {reg_A[16 - ex_ir[3:0]], reg_A >>> ex_ir[3:0]};
			default: begin
			         cf <= 0;
					 // ALUo <= 
					 end
        endcase								
		end
 end
	
//************* EX *************//	
always @(posedge clock or negedge reset) 
    begin
	    if (!reset)
			begin
				mem_ir <= 16'b0;
				reg_C <= 15'b0;
			end
			
		else if (state == `exec)
			begin
				mem_ir <= ex_ir;
				reg_C <= ALUo;

				if (ex_ir[15:11] == `STORE)
					begin
						dw <= 1'b1;
						smdr1 <= smdr;
					end
				// 设置标志位zf, nf, 算数和逻辑运算
				else if((ex_ir[15:14] != 2'b11) && ex_ir[15:14] != `LOAD)
				     begin
				       zf <= (ALUo == 0)? 1:0;
						 nf <= (ALUo[15] == 1'b1)? 1:0;
				     end							
			end			
    end
//************* MEM *************//
always @(posedge clock or negedge reset) 
    begin
	    if (!reset)
			begin
				wb_ir <= 16'b0;
				reg_C1 <= 15'b0;
			end
			
		else if (state == `exec)
			begin
				wb_ir <= mem_ir;
				
				if (mem_ir[15:11] == `LOAD)
					reg_C1 <= d_datain;
				else if(mem_ir[15:11] == `STORE)
				    d_dataout <= smdr1; 
				else if(mem_ir[15:14] != 2'b11)
					reg_C1 <= reg_C;				
			end			
	end
//************* WB *************//
always @(posedge clock or negedge reset) 
    begin
	    if (!reset)
			begin
			   gr[0] <= 15'b0;
				gr[1] <= 15'b0;
				gr[2] <= 15'b0;
				gr[3] <= 15'b0;
				gr[4] <= 15'b0;
				gr[5] <= 15'b0;
				gr[6] <= 15'b0;
				gr[7] <= 15'b0;
			end			
			
		else if (state == `exec)
			begin
			    // 回写到 r1
				if ((wb_ir[15:14] != 2'b11) 
				   &&(wb_ir[15:11] != `STORE)		  
				   &&(wb_ir[15:11] != `CMP)
				)
					gr[wb_ir[10:8]] <= reg_C1;
			end	
   end

endmodule
