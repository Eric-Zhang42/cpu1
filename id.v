`include "defines.v"

module id( //功能：在给指令解码的同时，取两个操作数送给下一级执行阶段
    input rst,
    input wire[`InstAddrBus] pc_i,                      //输入的程序计数器值   ?何用
    input wire[`InstBus] inst_i,                        //输入的指令

    //读到的寄存器值
    input wire[`RegBus] rdata1_i,                     //从寄存器中读取到的数据
    input wire[`RegBus] rdata2_i,

    //执行阶段运算结果
    input wire ex_we_reg_i,                             //此时执行阶段写使能
    input wire[`RegBus] ex_wdata_i,                     //此时执行阶段写数据
    input wire[`RegAddrBus] ex_waddr_reg_i,             //此时执行阶段写地址

    //访存阶段结果
    input wire mem_we_reg_i,                            //此时访存阶段写使能
    input wire[`RegBus] mem_wdata_i,                    //此时访存阶段写数据
    input wire[`RegAddrBus] mem_waddr_reg_i,            //此时访存阶段写地址  //什么用？

    //当前是否为延迟槽指令
    input wire now_in_delayslot_i,                      //当前是否为延迟槽指令

    //<-in out->

    //给寄存器堆的控制信号
    output reg[`RegAddrBus] raddr1_o,                    //寄存器地址，用于告诉寄存器，读取其中的数据
    output reg[`RegAddrBus] raddr2_o,
    output reg re1_o,                    //给寄存器的读使能信号
    output reg re2_o,

    //---给下一个执行阶段的信号---
    //控制信号
    output reg[`AluOpBus] aluop_o,                      //运算子类型，选择或，与等操作数
    output reg[`AluSelBus] alusel_o,                    //运算类型，选择逻辑运算，算术运算
    //待处理的数据信号
    output reg[`RegBus] rdata1_o,                         //输出数据给执行阶段
    output reg[`RegBus] rdata2_o,
    //是否写入、待写入寄存器的地址的信号
    output reg[`RegAddrBus] waddr_reg_o,                        //写入寄存器的地址
    output reg we_reg_o,                                    //写使能信号，表示是否有要写入的寄存器

    //给取指阶段，用于实现跳转
    output reg branch_flag_o,                             //跳转使能
    output reg[`InstAddrBus] branch_target_addr_o,         //跳转目标地址

    //告诉下一阶段下一条指令以及当前指令是否为延迟槽
    output reg next_in_delayslot_o,                         //下一条指令是否为延迟槽
    output reg now_in_delayslot_o,                          //当前指令是否为延迟槽

    //跳转成功后可能会返回当前下一条语句的地址
    output reg [`InstAddrBus] return_addr_o,                 //返回32位的地址存入寄存器堆

    //暂停请求信号
    output reg stallreq_upstream_o,                         //请求暂停上游信号
    output reg stallreq_downstream_o                        //请求暂停下游信号
    
);


//译码：将整条指令分割成不同的部分，做为标记，方便后续使用
wire [5:0] op;
wire [`RegAddrBus] rs, rt, rd;          //源地址寄存器，目的地址寄存器
wire [5:0] op_fun;                      //功能码
wire [15:0] op_imm;                     //立即数
wire [5:0] sa;                          //移位量

assign op = inst_i[31:26];               //指令码，用于规定指令的类型
assign rs = inst_i[25:21];               //I型指令的源寄存器
assign rt = inst_i[20:16];               //I型指令的目的寄存器，R型指令的源寄存器
assign op_imm = inst_i[15:0];            //I型指令的立即数

assign rd = inst_i[15:11];               //R型指令的目的寄存器
assign op_fun = inst_i[5:0];             //R型指令的功能码
assign sa = inst_i[10:6];                //R型指令移位功能的移位量

wire [`InstAddrBus] pc_plus_1;
wire [`InstAddrBus] pc_plus_2;
assign pc_plus_1 = pc_i + 1;
assign pc_plus_2 = pc_i + 2;

reg instvalid;                          //指示指令是否有效
reg [`RegBus] imm;



always@(*) begin
    if(rst == `RstEnable) begin
        aluop_o = `EXE_NOP_OP;
        alusel_o = `EXE_RES_NOP;
        waddr_reg_o = `NOPRegAddr;
        we_reg_o = `WriteDisable;
        instvalid = `InstInvalid;
        re1_o = `ReadDisable;
        re2_o = `ReadDisable;
        raddr1_o = `NOPRegAddr;
        raddr2_o = `NOPRegAddr;
        imm = `ZeroWord;
        branch_flag_o = `JumpDisable;
        branch_target_addr_o = `NOPRegAddr;
        next_in_delayslot_o = `IsNotDelaySlot;
        stallreq_upstream_o = `NoStop;
    end
    
    //这部分赋默认值, 相当于放在后面的default里，是为了让SPECIAL_INST（R型指令）更方便
    else begin
        aluop_o = `EXE_NOP_OP;
        alusel_o = `EXE_RES_NOP;
        waddr_reg_o = rd;               //默认R型指令
        we_reg_o = `WriteDisable;
        instvalid = `InstInvalid;
        re1_o = `ReadDisable;
        re2_o = `ReadDisable;
        raddr1_o = `NOPRegAddr;
        raddr2_o = `NOPRegAddr;
        raddr1_o = rs;                  //默认R型指令
        raddr2_o = rt;                  //默认R型指令
        imm = `ZeroWord;
        branch_flag_o = `JumpDisable;
        branch_target_addr_o = `NOPRegAddr;
        next_in_delayslot_o = `IsNotDelaySlot;
        stallreq_upstream_o = `NoStop;

        case(op)
            `EXE_SPECIAL_INST: begin        //R型指令
                if(sa == 5'b00000) begin    //当sa(op2)为00000时，表示逻辑或移位v功能或跳转指令
                    instvalid = `InstValid;

                    case(op_fun)            //op_fun(op3)为功能码
                        `EXE_FUN_AND: begin
                            aluop_o = `EXE_AND_OP;
                            alusel_o = `EXE_RES_LOGIC;
                            we_reg_o = `WriteEnable;
                            re1_o = `ReadEnable;
                            re2_o = `ReadEnable;
                            // waddr_reg_o = rd;       //这里也同理不需要再赋值
                            // raddr1_o = rs;
                            // raddr2_o = rt;
                        end
                        `EXE_FUN_OR: begin
                            aluop_o = `EXE_OR_OP;
                            alusel_o = `EXE_RES_LOGIC;
                            we_reg_o = `WriteEnable;
                            re1_o = `ReadEnable;    
                            re2_o = `ReadEnable;    
                        end
                        `EXE_FUN_XOR: begin
                            aluop_o = `EXE_XOR_OP;
                            alusel_o = `EXE_RES_LOGIC;
                            we_reg_o = `WriteEnable;
                            re1_o = `ReadEnable;    
                            re2_o = `ReadEnable;   
                        end
                        `EXE_FUN_NOR: begin
                            aluop_o = `EXE_NOR_OP;
                            alusel_o = `EXE_RES_LOGIC;
                            we_reg_o = `WriteEnable;
                            re1_o = `ReadEnable;    
                            re2_o = `ReadEnable;   
                        end
                        `EXE_FUN_SLLV: begin
                            aluop_o = `EXE_SLL_OP;
                            alusel_o = `EXE_RES_SHIFT;
                            we_reg_o = `WriteEnable;
                            re1_o = `ReadEnable;    
                            re2_o = `ReadEnable;   
                        end
                        `EXE_FUN_SRLV: begin
                            aluop_o = `EXE_SRL_OP;
                            alusel_o = `EXE_RES_SHIFT;
                            we_reg_o = `WriteEnable;
                            re1_o = `ReadEnable;    
                            re2_o = `ReadEnable;   
                        end
                        `EXE_FUN_SRAV: begin
                            aluop_o = `EXE_SRA_OP;
                            alusel_o = `EXE_RES_SHIFT;
                            we_reg_o = `WriteEnable;
                            re1_o = `ReadEnable;    
                            re2_o = `ReadEnable;   
                        end
                        `EXE_FUN_SYNC: begin
                            we_reg_o = `WriteDisable;
                            aluop_o = `EXE_NOP_OP;
                            alusel_o = `EXE_RES_NOP;
                            re1_o = `ReadDisable;
                            re2_o = `ReadEnable;//?
                            raddr1_o = `NOPRegAddr;
                            raddr2_o = `NOPRegAddr;
                        end
                        //跳转
                        `EXE_FUN_JR: begin
                            we_reg_o = `WriteDisable;   //不向寄存器写数据，只是跳转指令行
                            aluop_o = `EXE_JR_OP;
                            alusel_o = `EXE_RES_JUMP_BRANCH;
                            re1_o = `ReadEnable;
                            re2_o = `ReadDisable;
                            raddr1_o = rs;
                            raddr2_o = `NOPRegAddr;

                            branch_flag_o = `JumpEnable;
                            branch_target_addr_o = rdata1_o;     //跳转目标地址，这里是rdata1_o，不是rdata1_i，可以解决相邻指令间的数据冲突?
                            next_in_delayslot_o = `IsDelaySlot;
                            return_addr_o = `ZeroWord;
                            instvalid = `InstValid;
                            stallreq_upstream_o = `Stop;
                        end
                        `EXE_FUN_JALR: begin
                            we_reg_o = `WriteEnable;
                            aluop_o = `EXE_JALR_OP;
                            alusel_o = `EXE_RES_JUMP_BRANCH;
                            re1_o = `ReadEnable;
                            re2_o = `ReadDisable;
                            raddr1_o = rs;
                            raddr2_o = `NOPRegAddr;
                            waddr_reg_o = rd != 5'b00000 ? rd : 5'd31; //rd为0时，写入31号寄存器

                            branch_flag_o = `JumpEnable;
                            branch_target_addr_o = rdata1_o;
                            next_in_delayslot_o = `IsDelaySlot;
                            return_addr_o = pc_plus_1;
                            instvalid = `InstValid;
                            stallreq_upstream_o = `Stop;
                        end
                        //算术
                        `EXE_FUN_SLT: begin
                        we_reg_o = `WriteEnable;
                        aluop_o = `EXE_SLT_OP;
                        alusel_o = `EXE_RES_ARITHMETIC;
                        re1_o = `ReadEnable;
                        re2_o = `ReadEnable;
                        instvalid = `InstValid;
                        end
                        `EXE_FUN_SLTU: begin
                            we_reg_o = `WriteEnable;
                            aluop_o = `EXE_SLTU_OP;
                            alusel_o = `EXE_RES_ARITHMETIC;
                            re1_o = `ReadEnable;
                            re2_o = `ReadEnable;
                            instvalid = `InstValid;
                        end
                        `EXE_FUN_ADD: begin
                            we_reg_o = `WriteEnable;
                            aluop_o = `EXE_ADD_OP;
                            alusel_o = `EXE_RES_ARITHMETIC;
                            re1_o = `ReadEnable;
                            re2_o = `ReadEnable;
                            instvalid = `InstValid;
                        end
                        `EXE_FUN_ADDU: begin
                            we_reg_o = `WriteEnable;
                            aluop_o = `EXE_ADDU_OP;
                            alusel_o = `EXE_RES_ARITHMETIC;
                            re1_o = `ReadEnable;
                            re2_o = `ReadEnable;
                            instvalid = `InstValid;
                        end
                        `EXE_FUN_SUB: begin
                            we_reg_o = `WriteEnable;
                            aluop_o = `EXE_SUB_OP;
                            alusel_o = `EXE_RES_ARITHMETIC;
                            re1_o = `ReadEnable;
                            re2_o = `ReadEnable;
                            instvalid = `InstValid;
                        end
                        `EXE_FUN_SUBU: begin
                            we_reg_o = `WriteEnable;
                            aluop_o = `EXE_SUBU_OP;
                            alusel_o = `EXE_RES_ARITHMETIC;
                            re1_o = `ReadEnable;
                            re2_o = `ReadEnable;
                            instvalid = `InstValid;
                        end
                        `EXE_FUN_MULT: begin
                            we_reg_o = `WriteDisable;
                            aluop_o = `EXE_MULT_OP;
                            re1_o = `ReadEnable;
                            re2_o = `ReadEnable;
                            instvalid = `InstValid;
                        end
                        `EXE_FUN_MULTU: begin
                            we_reg_o = `WriteDisable;
                            aluop_o = `EXE_MULTU_OP;
                            re1_o = `ReadEnable;
                            re2_o = `ReadEnable;
                            instvalid = `InstValid;
                        end

                        default: begin
                        end
                    endcase
                end
                else if(rs == 5'b00000)begin                   //当sa不为00000时，表示移位(无v)功能 、这里waddr_reg_o都要改
                    case(op_fun)
                        `EXE_FUN_SLL: begin
                            aluop_o = `EXE_SLL_OP;
                            alusel_o = `EXE_RES_SHIFT;
                            re1_o = `ReadEnable;
                            re2_o = `ReadDisable;
                            instvalid = `InstValid;
                        end
                        `EXE_FUN_SRL: begin
                            aluop_o = `EXE_SRL_OP;
                            alusel_o = `EXE_RES_SHIFT;
                            re1_o = `ReadEnable;
                            re2_o = `ReadDisable;
                            instvalid = `InstValid;
                        end
                        `EXE_FUN_SRA: begin
                            aluop_o = `EXE_SRA_OP;
                            alusel_o = `EXE_RES_SHIFT;
                            re1_o = `ReadEnable;
                            re2_o = `ReadDisable;
                            instvalid = `InstValid;
                        end
                        default: begin
                        end
                    endcase
                end
                else begin
                end
            end
            `EXE_ORI: begin
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_OR_OP;               //注意区分这里的`EXE_OR_OP和`EXE_ORI（指令）
                alusel_o = `EXE_RES_LOGIC;
                re1_o = `ReadEnable;
                re2_o = `ReadDisable;
                raddr1_o = rs;
                raddr2_o = `NOPRegAddr;
                imm = {16'h0000, op_imm};           //立即数,无符号扩展
                waddr_reg_o = rt;
                instvalid = `InstValid;
            end
            `EXE_ANDI: begin                           //立即数与
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_AND_OP;
                alusel_o = `EXE_RES_LOGIC;
                re1_o = `ReadEnable;
                re2_o = `ReadDisable;
                raddr1_o = rs;
                raddr2_o = `NOPRegAddr;
                imm = {16'h0000, op_imm};      //立即数,无符号扩展
                waddr_reg_o = rt;
                instvalid = `InstValid;
            end
            `EXE_XORI: begin                           //立即数异或
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_XOR_OP;
                alusel_o = `EXE_RES_LOGIC;
                re1_o = `ReadEnable;
                re2_o = `ReadDisable;
                raddr1_o = rs;
                raddr2_o = `NOPRegAddr;
                imm = {16'h0000, op_imm};      //立即数,无符号扩展
                waddr_reg_o = rt;
                instvalid = `InstValid;
            end
            `EXE_LUT: begin                    //立即数保存
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_OR_OP;
                alusel_o = `EXE_RES_LOGIC;
                re1_o = `ReadDisable;
                re2_o = `ReadDisable;
                raddr1_o = `NOPRegAddr;
                raddr2_o = `NOPRegAddr;
                imm = {op_imm, 16'h0000};      //立即数,无符号扩展
                waddr_reg_o = rt;
                instvalid = `InstValid;
            end
            `EXE_PREF: begin                            //预取指令,在本项目中无缓存，不做处理
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_NOP_OP;
                alusel_o = `EXE_RES_NOP;
                re1_o = `ReadDisable;
                re2_o = `ReadDisable;
                waddr_reg_o = `NOPRegAddr;
                instvalid = `InstValid;
            end

            `EXE_J: begin
                we_reg_o = `WriteDisable;
                aluop_o = `EXE_JR_OP;
                alusel_o = `EXE_RES_JUMP_BRANCH;
                re1_o = `ReadDisable;
                re2_o = `ReadDisable;
                // raddr1_o = `NOPRegAddr;  //可以不写
                // raddr2_o = `NOPRegAddr;
                // waddr_reg_o = `NOPRegAddr;
                
                branch_flag_o = `JumpEnable;
                branch_target_addr_o = {6'b000000, inst_i[25:0]}; //跳转目标地址
                // branch_target_addr_o = {pc_plus_1[31:28], inst_i[25:0], 2'b00}; //跳转目标地址
                next_in_delayslot_o = `IsDelaySlot;
                return_addr_o = `ZeroWord;
                instvalid = `InstValid;
                stallreq_upstream_o = `Stop;
            end
            `EXE_JAL: begin
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_JALR_OP;
                alusel_o = `EXE_RES_JUMP_BRANCH;
                re1_o = `ReadDisable;
                re2_o = `ReadDisable;
                waddr_reg_o = 5'd31; //写入31号寄存器
                
                branch_flag_o = `JumpEnable;
                branch_target_addr_o = {6'b000000, inst_i[25:0]}; //跳转目标地址
                next_in_delayslot_o = `IsDelaySlot;
                return_addr_o = pc_plus_1;
                instvalid = `InstValid;
                stallreq_upstream_o = `Stop;
            end
            `EXE_SLTI: begin
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_SLT_OP;
                alusel_o = `EXE_RES_ARITHMETIC;
                re1_o = `ReadEnable;
                re2_o = `ReadDisable;
                imm = {{16{inst_i[15]}}, inst_i[15:0]};
                waddr_reg_o = inst_i[20:16];
                instvalid = `InstValid;
            end
            `EXE_SLTI: begin
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_SLTU_OP;
                alusel_o = `EXE_RES_ARITHMETIC;
                re1_o = `ReadEnable;
                re2_o = `ReadDisable;
                imm = {{16{inst_i[15]}}, inst_i[15:0]};
                waddr_reg_o = inst_i[20:16];
                instvalid = `InstValid;
            end
            `EXE_ADDI: begin
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_ADDI_OP;
                alusel_o = `EXE_RES_ARITHMETIC;
                re1_o = `ReadEnable;
                re2_o = `ReadDisable;
                imm = {{16{inst_i[15]}}, inst_i[15:0]};
                waddr_reg_o = inst_i[20:16];
                instvalid = `InstValid;
            end
            `EXE_ADDIU: begin
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_ADDIU_OP;
                alusel_o = `EXE_RES_ARITHMETIC;
                re1_o = `ReadEnable;
                re2_o = `ReadDisable;
                imm = {{16{inst_i[15]}}, inst_i[15:0]};
                waddr_reg_o = inst_i[20:16];
                instvalid = `InstValid;
            end
            `EXE_SPECIAL2_INST: begin                   //special2指令码
                case(op_fun)
                    `EXE_FUN_CLZ: begin
                        we_reg_o = `WriteEnable;
                        aluop_o = `EXE_CLZ_OP;
                        alusel_o = `EXE_RES_ARITHMETIC;
                        re1_o = `ReadEnable;
                        re2_o = `ReadDisable;
                        instvalid = `InstValid;
                    end
                    `EXE_FUN_CLO: begin
                        we_reg_o = `WriteEnable;
                        aluop_o = `EXE_CLO_OP;
                        alusel_o = `EXE_RES_ARITHMETIC;
                        re1_o = `ReadEnable;
                        re2_o = `ReadDisable;
                        instvalid = `InstValid;
                    end
                    `EXE_FUN_MUL: begin
                        we_reg_o = `WriteEnable;
                        aluop_o = `EXE_MUL_OP;
                        alusel_o = `EXE_RES_MUL;
                        re1_o = `ReadEnable;
                        re2_o = `ReadEnable;
                        instvalid = `InstValid;
                    end
                    default: begin 
                    end
                endcase 
            end
            default: begin end
        endcase
    end //end of else
end //end of always

//****************************************************************//
//**************************确定操作数1****************************//
//****************************************************************//

always@(*) begin
    if(rst == `RstEnable) begin
        rdata1_o = `ZeroWord;
    end
    else if (re1_o == `ReadEnable && ex_we_reg_i == `WriteEnable && ex_waddr_reg_i == raddr1_o)begin
        rdata1_o = ex_wdata_i;
    end
    else if (re1_o == `ReadEnable && mem_we_reg_i == `WriteEnable && mem_waddr_reg_i == raddr1_o)begin
        rdata1_o = mem_wdata_i;
    end
    else if (re1_o == `ReadEnable) begin
        rdata1_o = rdata1_i;
    end
    else if (re1_o == `ReadDisable) begin
        rdata1_o = imm;
    end
    else begin                                      //其实上面已经包含了所有情况，这里的else是多余的
        rdata1_o = `ZeroWord;
    end
end

//****************************************************************//
//**************************确定操作数2****************************//
//****************************************************************//

always@(*) begin
    if(rst == `RstEnable) begin
        rdata2_o = `ZeroWord;
    end
    else if (re2_o == `ReadEnable && ex_we_reg_i == `WriteEnable && ex_waddr_reg_i == raddr2_o)begin
        rdata2_o = ex_wdata_i;
    end
    else if (re2_o == `ReadEnable && mem_we_reg_i == `WriteEnable && mem_waddr_reg_i == raddr2_o)begin
        rdata2_o = mem_wdata_i;
    end
    else if (re2_o == `ReadEnable) begin
        rdata2_o = rdata2_i;
    end
    else if (re2_o == `ReadDisable) begin
        rdata2_o = imm;
    end
    else begin                                      //其实上面已经包含了所有情况，这里的else是多余的
        rdata2_o = `ZeroWord;
    end
end

//确定当前译码阶段的指令是否为延迟槽指令
always @(*)begin
    if(rst == `RstEnable)begin
        now_in_delayslot_o = `IsNotDelaySlot;
    end
    else begin
        now_in_delayslot_o = `IsDelaySlot;
    end
end

//暂停下游的请求信号
always @(*)begin
    if(rst == `RstEnable)begin
        stallreq_downstream_o = `NoStop;
    end
    else begin
        stallreq_downstream_o = `NoStop;
    end
end

endmodule