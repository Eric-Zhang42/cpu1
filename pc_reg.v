//PCģ�����ȡָ����

`include "defines.v"

module pc_reg (
    input clk,
    input rst,

    output reg[`InstAddrBus] pc, //ָ��ĵ�ַ
    output reg ce //��ָ��Ĵ���rom_programģ���ʹ���ź�
);
    always@(posedge clk) begin
        if(rst == `RstEnable) begin //�첽��λ
            pc <= 0;
            ce <= 1;
        end
        else begin //����������򵥵��ۼ�1
            pc <= pc + 1;
            ce <= 1;
        end
    end
    
endmodule
//ע����ʱ���·����clk���ƣ���D������������д����ʱע��1. posedge clk, 2. <=��ֵ