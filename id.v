`include "defines.v"

module id( //���ܣ��ڸ�ָ������ͬʱ��ȡ�����������͸���һ��ִ�н׶�
    input rst,
    input wire[`InstAddrBus] pc_i,                      //����ĳ��������ֵ   ?����
    input wire[`InstBus] inst_i,                        //�����ָ��

    //---�ͼĴ�����������ȡ�Ĵ����е���������---
    output reg[`RegAddrBus] raddr1_o,                    //�Ĵ�����ַ�����ڸ��߼Ĵ�������ȡ���е�����
    output reg[`RegAddrBus] raddr2_o,
    output reg re1_o,                    //���Ĵ����Ķ�ʹ���ź�
    output reg re2_o,
    input wire[`RegBus] rdata1_i,                     //�ӼĴ����ж�ȡ��������
    input wire[`RegBus] rdata2_i,

    //---����һ��ִ�н׶ε��ź�---
    //�����ź�
    output reg[`AluOpBus] aluop_o,                      //���������ͣ�ѡ�����Ȳ�����
    output reg[`AluSelBus] alusel_o,                    //�������ͣ�ѡ���߼����㣬��������
    //������������ź�
    output reg[`RegBus] rdata1_o,                         //����ӼĴ������������� 
    output reg[`RegBus] rdata2_o,
    //�Ƿ�д�롢��д��Ĵ����ĵ�ַ���ź�
    output reg[`RegAddrBus] waddr_reg_o,                        //д��Ĵ����ĵ�ַ
    output reg we_reg_o                                    //дʹ���źţ���ʾ�Ƿ���Ҫд��ļĴ���
);


//���룺������ָ��ָ�ɲ�ͬ�Ĳ��֣���Ϊ��ǣ��������ʹ��
wire [5:0] op;
wire [`RegAddrBus] rs, rt, rd;          //Դ��ַ�Ĵ�����Ŀ�ĵ�ַ�Ĵ���
wire [5:0] op_fun;                      //������
wire [15:0] op_imm;                     //������
wire [5:0] sa;                          //��λ��

assign op = inst_i[31:26];               //ָ���룬���ڹ涨ָ�������
assign rs = inst_i[25:21];               //I��ָ���Դ�Ĵ���
assign rt = inst_i[20:16];               //I��ָ���Ŀ�ļĴ�����R��ָ���Դ�Ĵ���
assign op_imm = inst_i[15:0];            //I��ָ���������

assign rd = inst_i[15:11];               //R��ָ���Ŀ�ļĴ���
assign op_fun = inst_i[5:0];             //R��ָ��Ĺ�����
assign sa = inst_i[10:6];                //R��ָ����λ���ܵ���λ��

reg instvalid;                          //ָʾָ���Ƿ���Ч
reg [`RegBus] imm;


always@(*) begin
    if(rst == `RstEnable) begin
        aluop_o = `EXE_NOP_OP;
        alusel_o = `EXE_RES_NOP;
        waddr_reg_o = `NOPRegAddr;
        we_reg_o = `WriteDisable;
        instvalid = `InstValid;
        re1_o = `ReadDisable;
        re2_o = `ReadDisable;
        raddr1_o = `NOPRegAddr;
        raddr2_o = `NOPRegAddr;
        imm = `ZeroWord;
    end
    
    //�ⲿ�ָ�Ĭ��ֵ, �൱�ڷ��ں����default���Ϊ����SPECIAL_INST��R��ָ�������
    else begin
        aluop_o = `EXE_NOP_OP;
        alusel_o = `EXE_RES_NOP;
        waddr_reg_o = rd;               //Ĭ��R��ָ��
        we_reg_o = `WriteDisable;
        instvalid = `InstInvalid;
        re1_o = `ReadDisable;
        re2_o = `ReadDisable;
        raddr1_o = `NOPRegAddr;
        raddr2_o = `NOPRegAddr;
        raddr1_o = rs;                  //Ĭ��R��ָ��
        raddr2_o = rt;                  //Ĭ��R��ָ��
        imm = `ZeroWord;

        case(op)
            `EXE_SPECIAL_INST: begin        //R��ָ��
                if(sa == 5'b00000) begin    //��saΪ00000ʱ����ʾ�߼�����λv����   
                    we_reg_o = `WriteEnable;        //R��ָ��Ĺ����ص�    
                    re1_o = `ReadEnable;    
                    re2_o = `ReadEnable;    
                    instvalid = `InstValid;

                    case(op_fun)
                        `EXE_FUN_AND: begin
                            aluop_o = `EXE_AND_OP;
                            alusel_o = `EXE_RES_LOGIC;
                            // re1_o = `ReadEnable;     //���ﲻ��Ҫ�ٸ�ֵ����Ϊcaseǰ�Ѹ�ֵ��Ĭ��ֵ����
                            // re2_o = `ReadEnable;
                            // instvalid = `InstValid;
                            // we_reg_o = `WriteEnable;
                            // waddr_reg_o = rd;       //����Ҳͬ����Ҫ�ٸ�ֵ
                            // raddr1_o = rs;
                            // raddr2_o = rt;
                        end
                        `EXE_FUN_OR: begin
                            aluop_o = `EXE_OR_OP;
                            alusel_o = `EXE_RES_LOGIC;
                        end
                        `EXE_FUN_XOR: begin
                            aluop_o = `EXE_XOR_OP;
                            alusel_o = `EXE_RES_LOGIC;
                        end
                        `EXE_FUN_NOR: begin
                            aluop_o = `EXE_NOR_OP;
                            alusel_o = `EXE_RES_LOGIC;
                        end
                        `EXE_FUN_SLLV: begin
                            aluop_o = `EXE_SLL_OP;
                            alusel_o = `EXE_RES_SHIFT;
                        end
                        `EXE_FUN_SRLV: begin
                            aluop_o = `EXE_SRL_OP;
                            alusel_o = `EXE_RES_SHIFT;
                        end
                        `EXE_FUN_SRAV: begin
                            aluop_o = `EXE_SRA_OP;
                            alusel_o = `EXE_RES_SHIFT;
                        end
                        `EXE_FUN_SYNC: begin
                            we_reg_o = `WriteDisable;
                            aluop_o = `EXE_NOP_OP;
                            alusel_o = `EXE_RES_NOP;
                            re1_o = `ReadDisable;
                            re2_o = `ReadEnable;//?
                            raddr1_o = `NOPRegAddr;
                            raddr2_o = `NOPRegAddr;
                            instvalid = `InstValid;
                        end
                        default: begin
                        end
                    endcase
                end
                // else if(rs == 5'b00000)begin                   //��sa��Ϊ00000ʱ����ʾ��λ(��v)���� ������waddr_reg_o��Ҫ��
                //     case(op_fun)
                //         `EXE_FUN_SLL: begin
                //             aluop_o = `EXE_SLL_OP;
                //             alusel_o = `EXE_RES_SHIFT;
                //             re1_o = `ReadEnable;
                //             re2_o = `ReadDisable;
                //             instvalid = `InstValid;
                //         end
                //         `EXE_FUN_SRL: begin
                //             aluop_o = `EXE_SRL_OP;
                //             alusel_o = `EXE_RES_SHIFT;
                //             re1_o = `ReadEnable;
                //             re2_o = `ReadDisable;
                //             instvalid = `InstValid;
                //         end
                //         `EXE_FUN_SRA: begin
                //             aluop_o = `EXE_SRA_OP;
                //             alusel_o = `EXE_RES_SHIFT;
                //             re1_o = `ReadEnable;
                //             re2_o = `ReadDisable;
                //             instvalid = `InstValid;
                //         end
                //         default: begin
                //         end
                //     endcase
                // end
                else begin
                end
            end
            `EXE_ORI: begin
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_OR_OP;               //ע�����������`EXE_OR_OP��`EXE_ORI��ָ�
                alusel_o = `EXE_RES_LOGIC;
                re1_o = `ReadEnable;
                re2_o = `ReadDisable;
                raddr1_o = rs;
                raddr2_o = `NOPRegAddr;
                imm = {16'h0000, op_imm};           //������,�޷�����չ
                waddr_reg_o = rt;
                instvalid = `InstValid;
            end
            `EXE_ANDI: begin                           //��������
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_AND_OP;
                alusel_o = `EXE_RES_LOGIC;
                re1_o = `ReadEnable;
                re2_o = `ReadDisable;
                raddr1_o = rs;
                raddr2_o = `NOPRegAddr;
                imm = {16'h0000, op_imm};      //������,�޷�����չ
                waddr_reg_o = rt;
                instvalid = `InstValid;
            end
            `EXE_XORI: begin                           //���������
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_XOR_OP;
                alusel_o = `EXE_RES_LOGIC;
                re1_o = `ReadEnable;
                re2_o = `ReadDisable;
                raddr1_o = rs;
                raddr2_o = `NOPRegAddr;
                imm = {16'h0000, op_imm};      //������,�޷�����չ
                waddr_reg_o = rt;
                instvalid = `InstValid;
            end
            `EXE_LUT: begin                            //���������� //�Ȳ���
                we_reg_o = `WriteEnable;
                aluop_o = `EXE_OR_OP;
                alusel_o = `EXE_RES_LOGIC;
                re1_o = `ReadDisable;
                re2_o = `ReadDisable;
                raddr1_o = `NOPRegAddr;
                raddr2_o = `NOPRegAddr;
                imm = {op_imm, 16'h0000};      //������,�޷�����չ
                waddr_reg_o = rt;
                instvalid = `InstValid;
            end
            //����prefָ��

            default : begin //���︳��Ĭ��ֵ���������case���ǰ
            end
            
        endcase
    end //end of else
end //end of always

//****************************************************************//
//**************************ȷ��������1****************************//
//****************************************************************//

always@(*) begin
    if(rst == `RstEnable) begin
        rdata1_o = `ZeroWord;
    end
    else if (re1_o == `ReadEnable) begin
        rdata1_o = rdata1_i;
    end
    else if (re1_o == `ReadDisable) begin
        rdata1_o = imm;
    end
    else begin                                      //��ʵ�����Ѿ���������������������else�Ƕ����
        rdata1_o = `ZeroWord;
    end
end

//****************************************************************//
//**************************ȷ��������2****************************//
//****************************************************************//

always@(*) begin
    if(rst == `RstEnable) begin
        rdata2_o = `ZeroWord;
    end
    else if (re2_o == `ReadEnable) begin
        rdata2_o = rdata2_i;
    end
    else begin                                      //��ʵ�����Ѿ���������������������else�Ƕ����
        rdata2_o = `ZeroWord;
    end
end


endmodule
//�������Լ�д��ԭʼ���룬����ϰ�߲����ϰ����ܷ����Ҫ�󡣰����ܷ��࣬�����ǰ���ֵ�������������cpu����Ƹ�����
// //ָʾָ���Ƿ���Ч
// reg instvalid;

// always@(*) begin
//     if(rst == `RstEnable) begin
//         instvalid = 0;
//     end
//     else begin
//         instvalid = 1;
//     end
// end


// //---�ͼĴ�����������ȡ�Ĵ����е���������---

// //��reg1_read_o��reg2_read_o��ֵ
// always@(*) begin
//     if(rst == `RstEnable) begin
//         reg1_read_o = 0;
//         reg2_read_o = 0;
//     end
//     else begin
//         reg1_read_o = 1;
//         reg2_read_o = 1;
//     end
// end

// //��reg1_addr_o��reg2_addr_o��ֵ
// always@(*) begin
//     if(rst == `RstEnable) begin
//         reg1_addr_o = 0;
//         reg2_addr_o = 0;
//     end
//     else begin
//         reg1_addr_o = rs;
//         reg2_addr_o = rt;
//     end
// end


// //---����һ��ִ�н׶ε��ź�---

// //�����źţ���aluop_o��alusel_o��ֵ,����֪��ori�����Ӧʲôaluop_o��alusel_o
// always@(*) begin
//     if (rst == `RstEnable) begin
//         aluop_o = `EXE_NOP_OP;
//         alusel_o = `EXE_RES_NOP;
//     end
//     else begin
//         case(op)
//             `EXE_ORI: begin
//                 aluop_o = `EXE_OR_OP;
//                 alusel_o = `EXE_RES_LOGIC;
//             end
//             default: begin
//                 aluop_o = `EXE_NOP_OP;
//                 alusel_o = `EXE_RES_NOP;
//             end
//         endcase
//     end
// end
// //������������ź�: ��reg1_o��reg2_o��ֵ
// always@(*) begin
//     if(rst == `RstEnable) begin
//         reg1_o = 0;
//         reg2_o = 0;
//     end
//     else begin
//         reg1_o = reg1_data_i;
//         reg2_o = reg2_data_i;
//     end
// end


// //�Ƿ�д�롢��д��Ĵ����ĵ�ַ���ź�: ��wd_o��wreg_o��ֵ
// always@(*) begin
//     if(rst == `RstEnable) begin
//         wd_o = 0;
//         wreg_o = 0;
//     end
//     else begin
//         wd_o = rt;
//         wreg_o = 1;
//     end
// end

