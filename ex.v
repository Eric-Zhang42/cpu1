`include "defines.v"

module ex(
    input rst,
    
    //���������
    input wire[`AluOpBus] aluop_i,                  //����������
    input wire[`AluSelBus] alusel_i,                //��������
    input wire[`RegBus] rdata1_i,                   //������1
    input wire[`RegBus] rdata2_i,                   //������2
    input wire[`RegAddrBus] waddr_reg_i,            //дĿ��Ĵ�����ַ
    input wire we_reg_i,                            //дʹ���ź�

    input wire now_in_delayslot_i,                  //��ǰָ���Ƿ����ӳٲ�ָ��
    input wire [`InstAddrBus] return_addr_i,         //���ص�ַ

    // HILOģ�����HI,LO�Ĵ�����ֵ
    input wire[`RegBus] hi_i,
    input wire[`RegBus] lo_i,

    //��HILO������ؿ������ݴ�����
    input wire[`RegBus] wb_hi_i,
    input wire[`RegBus] wb_lo_i,
    input wire wb_whilo_i,
    input wire[`RegBus] mem_hi_i,
    input wire[`RegBus] mem_lo_i,
    input wire mem_whilo_i,

    //ִ�к���
    output reg[`RegAddrBus] waddr_reg_o,            //дĿ��Ĵ�����ַ
    output reg we_reg_o,                            //дʹ���ź�
    output reg[`RegBus] wdata_o,                     //����������

    output reg stallreq_o,                           //��ͣ�����ź�

    //HILOд��ص����
    output reg[`RegBus] hi_o,
    output reg[`RegBus] lo_o,
    output reg whilo_o
);

//�����߼�����Ľ��
reg[`RegBus] logicout;
//��λ������
reg[`RegBus] shiftres;
//�ƶ��������
reg[`RegBus] moveres;
//HI�Ĵ�������ֵ
reg[`RegBus] HI;
//LO�Ĵ�������ֵ
reg[`RegBus] LO;

//����������
wire ov_sum;
wire rdata1_eq_rdata2;          //��һ���������Ƿ���ڵڶ���
wire rdata1_lt_rdata2;          //��һ���������Ƿ�С�ڵڶ���
reg [`RegBus] arithmeticres;//����������

wire [`RegBus] rdata2_i_mux;  //rdata2_i�Ĳ���
wire [`RegBus] rdata1_i_not;  //rdata1_i��ȡ��
wire [`RegBus] result_sum;  //�ӷ����
wire [`RegBus] opdata1_mult;//������
wire [`RegBus] opdata2_mult;//����
wire [`DoubleRegBus] hilo_temp; //��ʱ����˷����
wire [`DoubleRegBus] mulres; //����˷����
assign mulres = {HI, LO};
//�ж��Ƿ�Ϊ�������з��űȽ����㣬�Բ�����2ȡ��
assign reg2_i_mux = (   (aluop_i == `EXE_SUB_OP) || 
                        (aluop_i == `EXE_SUBU_OP) || 
                        (aluop_i == `EXE_SLT_OP)) ?
                        (~rdata2_i) + 1 : rdata2_i;
//����Ӽ����Լ��Ƚ�������
assign result_sum = rdata1_i + rdata2_i_mux;
//�������
assign ov_sum = (   (!rdata1_i[31] && !rdata2_i[31] && result_sum[31]) || 
                    (rdata1_i[31] && rdata2_i[31] && !result_sum[31]));
//�жϲ�����1�Ƿ�С�ڲ�����2
assign rdata1_lt_rdata2 = (aluop_i == `EXE_SLT_OP) ?
                        (   (rdata1_i[31] && !rdata2_i[31]) ||
                            (!rdata1_i[31] && !rdata2_i[31] && result_sum[31]) ||
                            (rdata1_i[31] && rdata2_i[31] && result_sum[31]))
                            : (rdata1_i < rdata2_i);
//�Բ�����1ȡ��
assign rdata1_i_not = ~rdata1_i;
assign opdata1_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP)) && (rdata1_i[31] == 1'b1)) ? (~rdata1_i + 1) : rdata1_i;
assign opdata2_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP)) && (rdata2_i[31] == 1'b1)) ? (~rdata2_i + 1) : rdata2_i;
assign hilo_temp = opdata1_mult * opdata2_mult;

//***************************************************************************************************//
//*******************************�õ�����HILO��ֵ������������****************************************//
//***************************************************************************************************//

always@(*) begin
    if (rst == `RstEnable) begin
        {HI, LO} = {`ZeroWord, `ZeroWord};
    end
    else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MUL_OP)) begin
        if (rdata1_i[31] ^ rdata2_i[31] == 1'b1)
            {HI, LO} = ~hilo_temp + 1;
        else
            {HI, LO} = hilo_temp;
    end
    else begin
        {HI, LO} = hilo_temp;
    end
end

// always@(*) begin
//     if(rst == `RstEnable) begin
//         {HI,LO} = {`ZeroWord,`ZeroWord};
//     end
//     else if(mem_whilo_i == `WriteEnable) begin
//         {HI,LO} = {mem_hi_i,mem_lo_i};
//     end
//     else if(wb_whilo_i == `WriteEnable) begin
//         {HI,LO} = {wb_hi_i,wb_lo_i};
//     end
//     else begin
//         {HI,LO} = {hi_i,lo_i};
//     end
// end

//***************************************************************************************************//
//*******************************��������������aluop_i���м���*****************************************//
//***************************************************************************************************//

always@(*) begin
    if(rst == `RstEnable) begin
        logicout = `ZeroWord;
    end
    else begin
        case(aluop_i) 
            `EXE_OR_OP: begin                                   //������
                logicout = rdata1_i | rdata2_i;
            end
            `EXE_AND_OP: begin                                  //������
                logicout = rdata1_i & rdata2_i;
            end
            `EXE_NOR_OP: begin
                logicout = ~(rdata1_i | rdata2_i);
            end
            `EXE_XOR_OP: begin                                  //�������
                logicout = rdata1_i ^ rdata2_i;
            end
            default: begin
                logicout = `ZeroWord;
            end
        endcase
    end
end

always@(*) begin
    if(rst == `RstEnable) begin
        shiftres = `ZeroWord;
    end
    else begin
        case(aluop_i) 
            `EXE_SLL_OP: begin
                shiftres = (rdata2_i << rdata1_i[4:0]);
            end
            `EXE_SRL_OP: begin
                shiftres = (rdata2_i >> rdata1_i[4:0]);
            end
            `EXE_SRA_OP: begin
                shiftres = ({32{rdata2_i[31]}}<<(6'd32-{1'b0,rdata1_i[4:0]})) | rdata2_i >> rdata1_i[4:0]; 
            end
            default: begin
                shiftres = `ZeroWord;
            end
        endcase
    end
end

always@(*) begin
    if(rst == `RstEnable) begin
        moveres = `ZeroWord;
    end
    else begin
        moveres = `ZeroWord;
        case(aluop_i)
            `EXE_MFHI_OP: begin
                moveres = HI;
            end
            `EXE_MFLO_OP: begin
                moveres = LO;
            end
            `EXE_MOVZ_OP: begin
                moveres = rdata1_i;
            end
            `EXE_MOVN_OP: begin
                moveres = rdata1_i;
            end
            default: begin
            end
        endcase
    end
end
//��������
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
//*******************************������������alusel_iѡ��������**************************************//
//***************************************************************************************************//

always@(*) begin
    waddr_reg_o = waddr_reg_i;
    // we_reg_o = we_reg_i;                                //дĿ���ַ��дʹ���ź�ֱ��ͨ��
    if (((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) || (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1)) begin
        we_reg_o <= `WriteDisable;
    end
    else begin
        we_reg_o = we_reg_i;
    end
    case(alusel_i) 
        `EXE_RES_LOGIC: begin           //�߼���������
            wdata_o = logicout;
        end
        `EXE_RES_SHIFT: begin           //��λ��������
            wdata_o = shiftres;
        end
        `EXE_RES_MOVE: begin
            wdata_o = moveres;
        end
        `EXE_RES_JUMP_BRANCH: begin     //��ת������ͣ�������תǰλ�ô���ָ�����ڵ�ַ
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

//��ͣ�����ź�
always @(*)begin
    if(rst == `RstEnable)begin
        stallreq_o = `NoStop;
    end
    else begin
        stallreq_o = `NoStop;
    end
end




//***************************************************************************************************//
//*******************************����LO��HI��ؽ��***************************************************//
//***************************************************************************************************//

always@(*) begin
    if(rst == `RstEnable) begin
        whilo_o = `WriteDisable;
        hi_o = `ZeroWord;
        lo_o = `ZeroWord;
    end
    else if((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MULTU_OP)) begin
        whilo_o = `WriteEnable;
        hi_o = mulres[63:32];
        lo_o = mulres[31:0];
    end
    else if(aluop_i == `EXE_MTLO_OP) begin
        whilo_o = `WriteEnable;
        hi_o = HI;                  
        lo_o = rdata1_i;
    end
    else if(aluop_i == `EXE_MTHI_OP) begin
        whilo_o = `WriteEnable;
        hi_o = rdata1_i;
        lo_o = LO;
    end
    else begin
        whilo_o = `WriteDisable;
        hi_o = `ZeroWord;
        lo_o = `ZeroWord;
    end
end


endmodule

//����Ĵ����ŵ㣺����logicout��shiftres����������
//�ֱ𱣴��߼��������  λ����Ľ����Ȼ����ݲ�ͬ���������ͣ�ѡ��ͬ�Ľ�������
//�����Ĵ���ṹ��������Ƕ�׵�case�����������Σ�ʹ�ô���Ŀɶ��ԺͿ�ά���Զ��кܴ����ߡ�
//���ǲ�������idģ�飬��Ϊ�Ǳ��������̫���ˣ����˴�exģ��ֻ��1��������������Կ�������д��