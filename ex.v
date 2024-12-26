`include "defines.v"

module ex(
    input rst,
    
    //译码的输入
    input wire[`AluOpBus] aluop_i,                  //操作子类型
    input wire[`AluSelBus] alusel_i,                //操作类型
    input wire[`RegBus] rdata1_i,                   //操作数1
    input wire[`RegBus] rdata2_i,                   //操作数2
    input wire[`RegAddrBus] waddr_reg_i,            //写目标寄存器地址
    input wire we_reg_i,                            //写使能信号

    input wire now_in_delayslot_i,                  //当前指令是否是延迟槽指令
    input wire [`InstAddrBus] return_addr_i,         //返回地址

    //执行后结果
    output reg[`RegAddrBus] waddr_reg_o,            //写目标寄存器地址
    output reg we_reg_o,                            //写使能信号
    output reg[`RegBus] wdata_o,                     //处理后的数据

    output reg stallreq_o                           //暂停请求信号

);

//保存逻辑运算的结果
reg[`RegBus] logicout;
//保存移位运算结果
reg[`RegBus] shiftres;
//
reg[`RegBus] moveres;

//
reg[`RegBus] HI;
reg[`RegBus] LO;

//保存溢出情况
wire ov_sum;
wire rdata1_eq_rdata2;          //第一个操作数是否等于第二个
wire rdata1_lt_rdata2;          //第一个操作数是否小于第二个
reg [`RegBus] arithmeticres;//算术运算结果

wire [`RegBus] rdata2_i_mux;  //rdata2_i的补码
wire [`RegBus] rdata1_i_not;  //rdata1_i的取反

wire [`RegBus] result_sum;  //加法结果
wire [`RegBus] opdata1_mult;//被乘数
wire [`RegBus] opdata2_mult;//乘数
wire [`DoubleRegBus] hilo_temp; //临时保存乘法结果
reg [`DoubleRegBus] mulres; //保存乘法结果

//判断是否为减法或有符号比较运算，对操作数2取反
assign reg2_i_mux = (   (aluop_i == `EXE_SUB_OP) || 
                        (aluop_i == `EXE_SUBU_OP) || 
                        (aluop_i == `EXE_SLT_OP)) ?
                        (~rdata2_i) + 1 : rdata2_i;

//计算加减法以及比较运算结果
assign result_sum = rdata1_i + rdata2_i_mux;
//计算溢出
assign ov_sum = (   (!rdata1_i[31] && !rdata2_i[31] && result_sum[31]) || 
                    (rdata1_i[31] && rdata2_i[31] && !result_sum[31]));

//判断操作数1是否小于操作数2
assign rdata1_lt_rdata2 = (aluop_i == `EXE_SLT_OP) ?
                        (   (rdata1_i[31] && !rdata2_i[31]) ||
                            (!rdata1_i[31] && !rdata2_i[31] && result_sum[31]) ||
                            (rdata1_i[31] && rdata2_i[31] && result_sum[31]))
                            : (rdata1_i < rdata2_i);
//对操作数1取反
assign rdata1_i_not = ~rdata1_i;

assign opdata1_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP)) && (rdata1_i[31] == 1'b1)) ? (~rdata1_i + 1) : rdata1_i;
assign opdata2_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP)) && (rdata2_i[31] == 1'b1)) ? (~rdata2_i + 1) : rdata2_i;
assign hilo_temp = opdata1_mult * opdata2_mult;
always@(*) begin
    if (rst == `RstEnable) begin
        mulres = {`ZeroWord, `ZeroWord};
    end
    else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MUL_OP)) begin
        if (rdata1_i[31] ^ rdata2_i[31] == 1'b1)
            mulres = ~hilo_temp + 1;
        else
            mulres = hilo_temp;
    end
    else begin
        mulres = hilo_temp;
    end
end
//***************************************************************************************************//
//*******************************根据运算子类型aluop_i进行计算*****************************************//
//***************************************************************************************************//

always@(*) begin
    if(rst == `RstEnable) begin
        logicout = `ZeroWord;
    end
    else begin
        case(aluop_i) 
            `EXE_OR_OP: begin                                   //或运算
                logicout = rdata1_i | rdata2_i;
            end
            `EXE_AND_OP: begin                                  //与运算
                logicout = rdata1_i & rdata2_i;
            end
            `EXE_NOR_OP: begin
                logicout = ~(rdata1_i | rdata2_i);
            end
            `EXE_XOR_OP: begin                                  //异或运算
                logicout = rdata1_i ^ rdata2_i;
            end
            default: begin
                logicout = `ZeroWord;
            end
        endcase
    end
end
//移位运算
always@(*) begin
    if(rst == `RstEnable) begin
        shiftres = `ZeroWord;
    end
    else begin
        case(aluop_i) 
            `EXE_SLL_OP: begin                                   //逻辑左移
                shiftres = rdata1_i << rdata2_i[4:0];
                                                // rdata1_i：要进行左移操作的数值。
                                                // rdata2_i：左移的位数。
            end
            `EXE_SRL_OP: begin                                  //逻辑右移
                shiftres = rdata1_i >> rdata2_i[4:0];
            end
            `EXE_SRA_OP: begin                                  //算术右移
                // shiftres = rdata1_i >>> rdata2_i[4:0];
                shiftres = ({32{rdata2_i[31]}}<<(6'd32-{1'b0,rdata1_i[4:0]})) | rdata2_i >> rdata1_i[4:0]; //具体算法
            end
            default: begin
                shiftres = `ZeroWord;
            end
        endcase
    end
end
//算术运算
always@(*) begin
    if (rst == `RstEnable) begin
        arithmeticres = `ZeroWord;
    end
    else begin
        case (aluop_i)
            `EXE_SLT_OP, `EXE_SLTU_OP: begin
                arithmeticres = rdata1_lt_rdata2;
            end
            `EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP: begin
                arithmeticres = result_sum;
            end
            `EXE_SUB_OP, `EXE_SUBU_OP: begin
                arithmeticres = result_sum;
            end
            `EXE_CLZ_OP: begin
                arithmeticres = rdata1_i[31] ? 0 :
                                rdata1_i[30] ? 1 :
                                rdata1_i[29] ? 2 :
                                rdata1_i[28] ? 3 :
                                rdata1_i[27] ? 4 :
                                rdata1_i[26] ? 5 :
                                rdata1_i[25] ? 6 :
                                rdata1_i[24] ? 7 :
                                rdata1_i[23] ? 8 :
                                rdata1_i[22] ? 9 :
                                rdata1_i[21] ? 10 :
                                rdata1_i[20] ? 11 :
                                rdata1_i[19] ? 12 :
                                rdata1_i[18] ? 13 :
                                rdata1_i[17] ? 14 :
                                rdata1_i[16] ? 15 :
                                rdata1_i[15] ? 16 :
                                rdata1_i[14] ? 17 :
                                rdata1_i[13] ? 18 :
                                rdata1_i[12] ? 19 :
                                rdata1_i[11] ? 20 :
                                rdata1_i[10] ? 21 :
                                rdata1_i[9] ? 22 :
                                rdata1_i[8] ? 23 :
                                rdata1_i[7] ? 24 :
                                rdata1_i[6] ? 25 :
                                rdata1_i[5] ? 26 :
                                rdata1_i[4] ? 27 :
                                rdata1_i[3] ? 28 :
                                rdata1_i[2] ? 29 :
                                rdata1_i[1] ? 30 :
                                rdata1_i[0] ? 31 :
                                32;
            end
            `EXE_CLO_OP: begin
                arithmeticres = rdata1_i_not[31] ? 0 :
                                rdata1_i_not[30] ? 1 :
                                rdata1_i_not[29] ? 2 :
                                rdata1_i_not[28] ? 3 :
                                rdata1_i_not[27] ? 4 :
                                rdata1_i_not[26] ? 5 :
                                rdata1_i_not[25] ? 6 :
                                rdata1_i_not[24] ? 7 :
                                rdata1_i_not[23] ? 8 :
                                rdata1_i_not[22] ? 9 :
                                rdata1_i_not[21] ? 10 :
                                rdata1_i_not[20] ? 11 :
                                rdata1_i_not[19] ? 12 :
                                rdata1_i_not[18] ? 13 :
                                rdata1_i_not[17] ? 14 :
                                rdata1_i_not[16] ? 15 :
                                rdata1_i_not[15] ? 16 :
                                rdata1_i_not[14] ? 17 :
                                rdata1_i_not[13] ? 18 :
                                rdata1_i_not[12] ? 19 :
                                rdata1_i_not[11] ? 20 :
                                rdata1_i_not[10] ? 21 :
                                rdata1_i_not[9] ? 22 :
                                rdata1_i_not[8] ? 23 :
                                rdata1_i_not[7] ? 24 :
                                rdata1_i_not[6] ? 25 :
                                rdata1_i_not[5] ? 26 :
                                rdata1_i_not[4] ? 27 :
                                rdata1_i_not[3] ? 28 :
                                rdata1_i_not[2] ? 29 :
                                rdata1_i_not[1] ? 30 :
                                rdata1_i_not[0] ? 31 :
                                32;
            end
            default: begin
                arithmeticres = `ZeroWord;
            end
        endcase
    end
end
//***************************************************************************************************//
//*******************************根据运算类型alusel_i选择运算结果**************************************//
//***************************************************************************************************//

always@(*) begin
    waddr_reg_o = waddr_reg_i;
    // we_reg_o = we_reg_i;                                //写目标地址与写使能信号直接通过
    if (((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) || (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1)) begin
        we_reg_o <= `WriteDisable;
    end
    else begin
        we_reg_o = we_reg_i;
    end
    case(alusel_i) 
        `EXE_RES_LOGIC: begin           //逻辑运算类型
            wdata_o = logicout;
        end
        `EXE_RES_SHIFT: begin           //移位运算类型
            wdata_o = shiftres;
        end
        `EXE_RES_JUMP_BRANCH: begin     //跳转结果类型，返回跳转前位置处的指令所在地址
            wdata_o = return_addr_i;
        end
        `EXE_RES_ARITHMETIC: begin
            wdata_o = arithmeticres;
        end
        `EXE_RES_MUL: begin
            wdata_o = mulres[31:0];
        end
        default: begin
            wdata_o = `ZeroWord;
        end
    endcase
end

//暂停请求信号
always @(*)begin
    if(rst == `RstEnable)begin
        stallreq_o = `NoStop;
    end
    else begin
        stallreq_o = `NoStop;
    end
end

always@(*) begin
    if (rst == `RstEnable) begin
    //
    end
    else if((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MULTU_OP)) begin
        whilo_o = `WriteEnable;
        hi_o = mulres[63:32];
        lo_o = mulres[31:0];
endmodule

//这里的代码优点：利用logicout和shiftres两个变量，
//分别保存逻辑运算和移位运算的结果，然后根据不同的运算类型，选择不同的结果输出。
//这样的代码结构，将两层嵌套的case语句独立成两段，使得代码的可读性和可维护性都有很大的提高。
//但是不适用于id模块，因为那边输出变量太多了，而此处ex模块只有1个输出变量，所以可以这样写。