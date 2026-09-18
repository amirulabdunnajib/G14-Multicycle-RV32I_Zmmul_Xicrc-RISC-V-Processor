

//  ---------- INLCUDED BLOCK: DMEM_v2  ---------- 
module DMEM_v2 (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] address_i,
    input  wire        we_i,
    input  wire        oe_i,
    input  wire [3:0]  bw_i,
    input  wire [31:0] data_i,
    output reg  [31:0] data_o
);
    reg [31:0] mem [0:2047];
    wire [10:0] word_addr = address_i[12:2];

    always @(posedge clk) begin
        if (we_i) begin
            if (bw_i[0]) mem[word_addr][7:0]   <= data_i[7:0];
            if (bw_i[1]) mem[word_addr][15:8]  <= data_i[15:8];
            if (bw_i[2]) mem[word_addr][23:16] <= data_i[23:16];
            if (bw_i[3]) mem[word_addr][31:24] <= data_i[31:24];
        end
        if (oe_i)
            data_o <= mem[word_addr];
    end
endmodule



//  ---------- INLCUDED BLOCK: LSU_v2  ---------- 
module LSU_v2 (
    input  wire [31:0] core_data_o,
    input  wire [31:0] core_address_o,
    input  wire [2:0]  op_size_o,
    output reg  [31:0] core_data_i,

    output wire [31:0] mem_address_i,
    output reg  [3:0]  byte_write_i,
    output reg  [31:0] mem_data_i,
    input  wire [31:0] mem_data_o
);

    assign mem_address_i = core_address_o;

    wire [1:0] byte_sel  = core_address_o[1:0];
    wire is_store = (op_size_o >= 3'b101);

    // ---------- STORE PATH ----------
    always @(*) begin
        byte_write_i = 4'b0000;
        mem_data_i   = 32'd0;

        if (is_store) begin
            case (op_size_o)
                3'b101: begin // SB
                    byte_write_i = 4'b0001 << byte_sel;
                    mem_data_i   = core_data_o[7:0] << (byte_sel * 8);
                end
                3'b110: begin // SH
                    byte_write_i = 4'b0011 << byte_sel;
                    mem_data_i   = core_data_o[15:0] << (byte_sel * 8);
                end
                3'b111: begin // SW
                    byte_write_i = 4'b1111;
                    mem_data_i   = core_data_o;
                end
                default: ;
            endcase
        end
    end

    // ---------- LOAD PATH ----------
    always @(*) begin
        core_data_i = 32'd0;

        if (!is_store) begin
            case (op_size_o)
                3'b000: core_data_i = {{24{mem_data_o[byte_sel*8+7]}},  mem_data_o[byte_sel*8 +: 8]};   // LB
                3'b011: core_data_i = {24'd0,                           mem_data_o[byte_sel*8 +: 8]};   // LBU
                3'b001: core_data_i = {{16{mem_data_o[byte_sel*8+15]}}, mem_data_o[byte_sel*8 +: 16]};  // LH
                3'b100: core_data_i = {16'd0,                           mem_data_o[byte_sel*8 +: 16]};  // LHU
                3'b010: core_data_i = mem_data_o;                                                        // LW
                default: ;
            endcase
        end
    end

endmodule



//  ---------- INLCUDED BLOCK: control_fsm  ---------- 
module control_fsm (
    input  wire       clk,
    input  wire       rst,
    output reg  [1:0] state
);
    localparam FETCH     = 2'b00;
    localparam DECODE    = 2'b01;
    localparam EXECUTE   = 2'b10;
    localparam WRITEBACK = 2'b11;

    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= FETCH;
        else begin
            case (state)
                FETCH:     state <= DECODE;
                DECODE:    state <= EXECUTE;
                EXECUTE:   state <= WRITEBACK;
                WRITEBACK: state <= FETCH;
                default:   state <= FETCH;
            endcase
        end
    end
endmodule



//  ---------- INLCUDED BLOCK: IR  ---------- 
module IR (
    input  wire        clk,
    input  wire        rst,
    input  wire        ir_write_en,     // NEW: only capture during FETCH
    input  wire [31:0] instruction_i,
    output reg  [31:0] instruction_o
);
    always @(posedge clk or posedge rst) begin
        if (rst) instruction_o <= 32'b0;
        else if (ir_write_en) instruction_o <= instruction_i;
        // else: hold -- same pattern PC already uses
    end
endmodule



//  ---------- INLCUDED BLOCK: PC  ---------- 
//  ---------- INLCUDED BLOCK: PC  ---------- 
module PC (
    input  wire        clk,
    input  wire        rst,
    input  wire        pc_write_en,
    input  wire [31:0] pc_next_i,
    output reg  [31:0] pc_o
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            pc_o <= 32'h0040_0000;  // FIX: Boot address shifted to IMEM base
        else if (pc_write_en)
            pc_o <= pc_next_i;
    end
endmodule



//  ---------- INLCUDED BLOCK: IMEM_v3  ---------- 
module IMEM_v3 (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] address_i,
    input  wire        oe_i,
    output reg  [31:0] data_o
);
    always @(*) begin
        if (!oe_i) begin
            data_o = 32'b0;
        end else begin
            case (address_i)
        32'h00400000: data_o = 32'h123452B7;
        32'h00400004: data_o = 32'h12345337;
        32'h00400008: data_o = 32'h3E629463;
        32'h0040000C: data_o = 32'h00001297;
        32'h00400010: data_o = 32'h3E028063;
        32'h00400014: data_o = 32'h00A00293;
        32'h00400018: data_o = 32'hFFD28313;
        32'h0040001C: data_o = 32'h00700393;
        32'h00400020: data_o = 32'h3C731863;
        32'h00400024: data_o = 32'h006283B3;
        32'h00400028: data_o = 32'h01100E13;
        32'h0040002C: data_o = 32'h3DC39263;
        32'h00400030: data_o = 32'h405E03B3;
        32'h00400034: data_o = 32'h3A639E63;
        32'h00400038: data_o = 32'h0FF00293;
        32'h0040003C: data_o = 32'h0F02C313;
        32'h00400040: data_o = 32'h00F00393;
        32'h00400044: data_o = 32'h3A731663;
        32'h00400048: data_o = 32'h7002E313;
        32'h0040004C: data_o = 32'h7FF00393;
        32'h00400050: data_o = 32'h3A731063;
        32'h00400054: data_o = 32'h0F02F313;
        32'h00400058: data_o = 32'h0F000393;
        32'h0040005C: data_o = 32'h38731A63;
        32'h00400060: data_o = 32'h0AA00293;
        32'h00400064: data_o = 32'h05500313;
        32'h00400068: data_o = 32'h0062C3B3;
        32'h0040006C: data_o = 32'h0FF00E13;
        32'h00400070: data_o = 32'h39C39063;
        32'h00400074: data_o = 32'h0062E3B3;
        32'h00400078: data_o = 32'h37C39C63;
        32'h0040007C: data_o = 32'h0062F3B3;
        32'h00400080: data_o = 32'h36039863;
        32'h00400084: data_o = 32'h00100293;
        32'h00400088: data_o = 32'h00429313;
        32'h0040008C: data_o = 32'h01000393;
        32'h00400090: data_o = 32'h36731063;
        32'h00400094: data_o = 32'h0023D313;
        32'h00400098: data_o = 32'h00400E13;
        32'h0040009C: data_o = 32'h35C31A63;
        32'h004000A0: data_o = 32'hFF000293;
        32'h004000A4: data_o = 32'h4022D313;
        32'h004000A8: data_o = 32'hFFC00393;
        32'h004000AC: data_o = 32'h34731263;
        32'h004000B0: data_o = 32'h00100293;
        32'h004000B4: data_o = 32'h00400313;
        32'h004000B8: data_o = 32'h006293B3;
        32'h004000BC: data_o = 32'h01000E13;
        32'h004000C0: data_o = 32'h33C39863;
        32'h004000C4: data_o = 32'h00200313;
        32'h004000C8: data_o = 32'h006E53B3;
        32'h004000CC: data_o = 32'h00400E93;
        32'h004000D0: data_o = 32'h33D39063;
        32'h004000D4: data_o = 32'hFF000293;
        32'h004000D8: data_o = 32'h4062D3B3;
        32'h004000DC: data_o = 32'hFFC00E93;
        32'h004000E0: data_o = 32'h31D39863;
        32'h004000E4: data_o = 32'h00A00293;
        32'h004000E8: data_o = 32'h0142A313;
        32'h004000EC: data_o = 32'h00100393;
        32'h004000F0: data_o = 32'h30731063;
        32'h004000F4: data_o = 32'hFF600293;
        32'h004000F8: data_o = 32'h0142B313;
        32'h004000FC: data_o = 32'h2E031A63;
        32'h00400100: data_o = 32'h00A00293;
        32'h00400104: data_o = 32'h01400313;
        32'h00400108: data_o = 32'h0062A3B3;
        32'h0040010C: data_o = 32'h00100E13;
        32'h00400110: data_o = 32'h2FC39063;
        32'h00400114: data_o = 32'h005333B3;
        32'h00400118: data_o = 32'h2C039C63;
        32'h0040011C: data_o = 32'h0FC10417;
        32'h00400120: data_o = 32'hEE440413;
        32'h00400124: data_o = 32'h12345337;
        32'h00400128: data_o = 32'h67830313;
        32'h0040012C: data_o = 32'h00642023;
        32'h00400130: data_o = 32'h0000B3B7;
        32'h00400134: data_o = 32'hABB38393;
        32'h00400138: data_o = 32'h00741223;
        32'h0040013C: data_o = 32'h0CC00E13;
        32'h00400140: data_o = 32'h01C40423;
        32'h00400144: data_o = 32'h00042E83;
        32'h00400148: data_o = 32'h2A6E9463;
        32'h0040014C: data_o = 32'h00441F03;
        32'h00400150: data_o = 32'hFFFFBFB7;
        32'h00400154: data_o = 32'hABBF8F93;
        32'h00400158: data_o = 32'h29FF1C63;
        32'h0040015C: data_o = 32'h00445F03;
        32'h00400160: data_o = 32'h0000BFB7;
        32'h00400164: data_o = 32'hABBF8F93;
        32'h00400168: data_o = 32'h29FF1463;
        32'h0040016C: data_o = 32'h00840F03;
        32'h00400170: data_o = 32'hFCC00F93;
        32'h00400174: data_o = 32'h27FF1E63;
        32'h00400178: data_o = 32'h00844F03;
        32'h0040017C: data_o = 32'h0CC00F93;
        32'h00400180: data_o = 32'h27FF1863;
        32'h00400184: data_o = 32'h00500293;
        32'h00400188: data_o = 32'h00A00313;
        32'h0040018C: data_o = 32'h00500393;
        32'h00400190: data_o = 32'hFF600E13;
        32'h00400194: data_o = 32'hFF600E93;
        32'h00400198: data_o = 32'h00728463;
        32'h0040019C: data_o = 32'h2540006F;
        32'h004001A0: data_o = 32'h01DE0463;
        32'h004001A4: data_o = 32'h24C0006F;
        32'h004001A8: data_o = 32'h00629463;
        32'h004001AC: data_o = 32'h2440006F;
        32'h004001B0: data_o = 32'h01C29463;
        32'h004001B4: data_o = 32'h23C0006F;
        32'h004001B8: data_o = 32'h0062C463;
        32'h004001BC: data_o = 32'h2340006F;
        32'h004001C0: data_o = 32'h005E4463;
        32'h004001C4: data_o = 32'h22C0006F;
        32'h004001C8: data_o = 32'h00535463;
        32'h004001CC: data_o = 32'h2240006F;
        32'h004001D0: data_o = 32'h01C2D463;
        32'h004001D4: data_o = 32'h21C0006F;
        32'h004001D8: data_o = 32'h0062E463;
        32'h004001DC: data_o = 32'h2140006F;
        32'h004001E0: data_o = 32'h01C2E463;
        32'h004001E4: data_o = 32'h20C0006F;
        32'h004001E8: data_o = 32'h00537463;
        32'h004001EC: data_o = 32'h2040006F;
        32'h004001F0: data_o = 32'h005E7463;
        32'h004001F4: data_o = 32'h1FC0006F;
        32'h004001F8: data_o = 32'h00800F6F;
        32'h004001FC: data_o = 32'h1F40006F;
        32'h00400200: data_o = 32'h00000F97;
        32'h00400204: data_o = 32'h010F8F93;
        32'h00400208: data_o = 32'h000F8067;
        32'h0040020C: data_o = 32'h1E40006F;
        32'h00400210: data_o = 32'h00100013;
        32'h00400214: data_o = 32'h1C001E63;
        32'h00400218: data_o = 32'hDEADC2B7;
        32'h0040021C: data_o = 32'hEEF28293;
        32'h00400220: data_o = 32'h00028313;
        32'h00400224: data_o = 32'h00030393;
        32'h00400228: data_o = 32'h00038F93;
        32'h0040022C: data_o = 32'hDEADC2B7;
        32'h00400230: data_o = 32'hEEF28293;
        32'h00400234: data_o = 32'h1A5F9E63;
        32'h00400238: data_o = 32'h000185B7;
        32'h0040023C: data_o = 32'h6A058593;
        32'h00400240: data_o = 32'h00200613;
        32'h00400244: data_o = 32'hEE6B36B7;
        32'h00400248: data_o = 32'h80068693;
        32'h0040024C: data_o = 32'h000312B7;
        32'h00400250: data_o = 32'hD4028293;
        32'h00400254: data_o = 32'hDCD65337;
        32'h00400258: data_o = 32'hFFF00393;
        32'h0040025C: data_o = 32'h00100E13;
        32'h00400260: data_o = 32'h02C58533;
        32'h00400264: data_o = 32'h18551663;
        32'h00400268: data_o = 32'h02C68533;
        32'h0040026C: data_o = 32'h18651263;
        32'h00400270: data_o = 32'h02C59533;
        32'h00400274: data_o = 32'h16051E63;
        32'h00400278: data_o = 32'h02C69533;
        32'h0040027C: data_o = 32'h16751A63;
        32'h00400280: data_o = 32'h02C6B533;
        32'h00400284: data_o = 32'h17C51663;
        32'h00400288: data_o = 32'h02C6A533;
        32'h0040028C: data_o = 32'h16751263;
        32'h00400290: data_o = 32'h02D62533;
        32'h00400294: data_o = 32'h15C51E63;
        32'h00400298: data_o = 32'h000028B7;
        32'h0040029C: data_o = 32'hE8288893;
        32'h004002A0: data_o = 32'h00010437;
        32'h004002A4: data_o = 32'hFFF40413;
        32'h004002A8: data_o = 32'h01200493;
        32'h004002AC: data_o = 32'h03400913;
        32'h004002B0: data_o = 32'h05600993;
        32'h004002B4: data_o = 32'h07800A13;
        32'h004002B8: data_o = 32'h09000A93;
        32'h004002BC: data_o = 32'h0AB00B13;
        32'h004002C0: data_o = 32'h0CD00B93;
        32'h004002C4: data_o = 32'h0EF00C13;
        32'h004002C8: data_o = 32'h80848433;
        32'h004002CC: data_o = 32'h80890433;
        32'h004002D0: data_o = 32'h80898433;
        32'h004002D4: data_o = 32'h808A0433;
        32'h004002D8: data_o = 32'h808A8433;
        32'h004002DC: data_o = 32'h808B0433;
        32'h004002E0: data_o = 32'h808B8433;
        32'h004002E4: data_o = 32'h808C0433;
        32'h004002E8: data_o = 32'h11141463;
        32'h004002EC: data_o = 32'h000102B7;
        32'h004002F0: data_o = 32'hFFF28293;
        32'h004002F4: data_o = 32'h00001337;
        32'h004002F8: data_o = 32'h23430313;
        32'h004002FC: data_o = 32'h000053B7;
        32'h00400300: data_o = 32'h67838393;
        32'h00400304: data_o = 32'h00009E37;
        32'h00400308: data_o = 32'h0ABE0E13;
        32'h0040030C: data_o = 32'h0000DEB7;
        32'h00400310: data_o = 32'hDEFE8E93;
        32'h00400314: data_o = 32'h805312B3;
        32'h00400318: data_o = 32'h805392B3;
        32'h0040031C: data_o = 32'h805E12B3;
        32'h00400320: data_o = 32'h805E92B3;
        32'h00400324: data_o = 32'h0D129663;
        32'h00400328: data_o = 32'h00010537;
        32'h0040032C: data_o = 32'hFFF50513;
        32'h00400330: data_o = 32'h123455B7;
        32'h00400334: data_o = 32'h67858593;
        32'h00400338: data_o = 32'h90ABD637;
        32'h0040033C: data_o = 32'hDEF60613;
        32'h00400340: data_o = 32'h80A5A533;
        32'h00400344: data_o = 32'h80A62533;
        32'h00400348: data_o = 32'h0B151463;
        32'h0040034C: data_o = 32'h00000297;
        32'h00400350: data_o = 32'h0AC28293;
        32'h00400354: data_o = 32'h0002A303;
        32'h00400358: data_o = 32'h0042A383;
        32'h0040035C: data_o = 32'h00010537;
        32'h00400360: data_o = 32'hFFF50513;
        32'h00400364: data_o = 32'h80A32533;
        32'h00400368: data_o = 32'h80A3A533;
        32'h0040036C: data_o = 32'h000028B7;
        32'h00400370: data_o = 32'hE8288893;
        32'h00400374: data_o = 32'h07151E63;
        32'h00400378: data_o = 32'h01400293;
        32'h0040037C: data_o = 32'h00A00313;
        32'h00400380: data_o = 32'h006283B3;
        32'h00400384: data_o = 32'h40628E33;
        32'h00400388: data_o = 32'h03C38EB3;
        32'h0040038C: data_o = 32'h12C00F13;
        32'h00400390: data_o = 32'h07EE9063;
        32'h00400394: data_o = 32'h00000297;
        32'h00400398: data_o = 32'h06C28293;
        32'h0040039C: data_o = 32'h0FC10317;
        32'h004003A0: data_o = 32'hC7430313;
        32'h004003A4: data_o = 32'h00300393;
        32'h004003A8: data_o = 32'h0002AE03;
        32'h004003AC: data_o = 32'h01C32023;
        32'h004003B0: data_o = 32'h00428293;
        32'h004003B4: data_o = 32'h00430313;
        32'h004003B8: data_o = 32'hFFF38393;
        32'h004003BC: data_o = 32'hFE0396E3;
        32'h004003C0: data_o = 32'h0FC10317;
        32'h004003C4: data_o = 32'hC5030313;
        32'h004003C8: data_o = 32'h00032E03;
        32'h004003CC: data_o = 32'h11111EB7;
        32'h004003D0: data_o = 32'h111E8E93;
        32'h004003D4: data_o = 32'h01DE1E63;
        32'h004003D8: data_o = 32'h00832E03;
        32'h004003DC: data_o = 32'h33333EB7;
        32'h004003E0: data_o = 32'h333E8E93;
        32'h004003E4: data_o = 32'h01DE1663;
        32'h004003E8: data_o = 32'h00000213;
        32'h004003EC: data_o = 32'h0000006F;
        32'h004003F0: data_o = 32'hFFF00213;
        32'h004003F4: data_o = 32'h0000006F;
        32'h004003F8: data_o = 32'h12345678;
        32'h004003FC: data_o = 32'h90ABCDEF;
        32'h00400400: data_o = 32'h11111111;
        32'h00400404: data_o = 32'h22222222;
        32'h00400408: data_o = 32'h33333333;
                default: data_o = 32'h00000013; // NOP
            endcase
        end
    end
endmodule



//  ---------- INLCUDED BLOCK: REGISTER_FILE_G14  ---------- 
module REGISTER_FILE_G14 (
    input  wire        clk_i,
    input  wire        rst_i,
    input  wire [4:0]  rs1_addr_i,
    input  wire [4:0]  rs2_addr_i,
    input  wire [4:0]  rd_addr_i,
    input  wire [31:0] rd_data_i,
    input  wire        we_i,
    output wire [31:0] rs1_data_o,
    output wire [31:0] rs2_data_o
);
    reg [31:0] r_Registers [0:31];
    integer i;

    wire group_we0 = we_i && (rd_addr_i[4:3] == 2'd0) && (rd_addr_i != 5'h0);
    wire group_we1 = we_i && (rd_addr_i[4:3] == 2'd1);
    wire group_we2 = we_i && (rd_addr_i[4:3] == 2'd2);
    wire group_we3 = we_i && (rd_addr_i[4:3] == 2'd3);

    always @(posedge clk_i) begin
        if (rst_i) begin
            for (i = 0; i < 32; i = i + 1) r_Registers[i] <= 32'h0;
        end else begin
            if (group_we0) r_Registers[{2'b00, rd_addr_i[2:0]}] <= rd_data_i;
            if (group_we1) r_Registers[{2'b01, rd_addr_i[2:0]}] <= rd_data_i;
            if (group_we2) r_Registers[{2'b10, rd_addr_i[2:0]}] <= rd_data_i;
            if (group_we3) r_Registers[{2'b11, rd_addr_i[2:0]}] <= rd_data_i;
        end
    end

    wire [31:0] rs1_l0 = r_Registers[{3'b000, rs1_addr_i[1:0]}];
    wire [31:0] rs1_l1 = r_Registers[{3'b001, rs1_addr_i[1:0]}];
    wire [31:0] rs1_l2 = r_Registers[{3'b010, rs1_addr_i[1:0]}];
    wire [31:0] rs1_l3 = r_Registers[{3'b011, rs1_addr_i[1:0]}];
    wire [31:0] rs1_l4 = r_Registers[{3'b100, rs1_addr_i[1:0]}];
    wire [31:0] rs1_l5 = r_Registers[{3'b101, rs1_addr_i[1:0]}];
    wire [31:0] rs1_l6 = r_Registers[{3'b110, rs1_addr_i[1:0]}];
    wire [31:0] rs1_l7 = r_Registers[{3'b111, rs1_addr_i[1:0]}];
    wire [31:0] rs1_p0 = rs1_addr_i[2] ? rs1_l1 : rs1_l0;
    wire [31:0] rs1_p1 = rs1_addr_i[2] ? rs1_l3 : rs1_l2;
    wire [31:0] rs1_p2 = rs1_addr_i[2] ? rs1_l5 : rs1_l4;
    wire [31:0] rs1_p3 = rs1_addr_i[2] ? rs1_l7 : rs1_l6;
    assign rs1_data_o = (rs1_addr_i[4:3] == 2'd0) ? rs1_p0 :
                         (rs1_addr_i[4:3] == 2'd1) ? rs1_p1 :
                         (rs1_addr_i[4:3] == 2'd2) ? rs1_p2 : rs1_p3;

    wire [31:0] rs2_l0 = r_Registers[{3'b000, rs2_addr_i[1:0]}];
    wire [31:0] rs2_l1 = r_Registers[{3'b001, rs2_addr_i[1:0]}];
    wire [31:0] rs2_l2 = r_Registers[{3'b010, rs2_addr_i[1:0]}];
    wire [31:0] rs2_l3 = r_Registers[{3'b011, rs2_addr_i[1:0]}];
    wire [31:0] rs2_l4 = r_Registers[{3'b100, rs2_addr_i[1:0]}];
    wire [31:0] rs2_l5 = r_Registers[{3'b101, rs2_addr_i[1:0]}];
    wire [31:0] rs2_l6 = r_Registers[{3'b110, rs2_addr_i[1:0]}];
    wire [31:0] rs2_l7 = r_Registers[{3'b111, rs2_addr_i[1:0]}];
    wire [31:0] rs2_p0 = rs2_addr_i[2] ? rs2_l1 : rs2_l0;
    wire [31:0] rs2_p1 = rs2_addr_i[2] ? rs2_l3 : rs2_l2;
    wire [31:0] rs2_p2 = rs2_addr_i[2] ? rs2_l5 : rs2_l4;
    wire [31:0] rs2_p3 = rs2_addr_i[2] ? rs2_l7 : rs2_l6;
    assign rs2_data_o = (rs2_addr_i[4:3] == 2'd0) ? rs2_p0 :
                         (rs2_addr_i[4:3] == 2'd1) ? rs2_p1 :
                         (rs2_addr_i[4:3] == 2'd2) ? rs2_p2 : rs2_p3;
endmodule



//  ---------- INLCUDED BLOCK: PC_PLUS4_TAP  ---------- 
module PC_PLUS4_TAP (
    input  wire [31:0] in,
    output wire [31:0] out1,
    output wire [31:0] out2
);
    assign out1 = in;
    assign out2 = in;
endmodule



//  ---------- INLCUDED BLOCK: INSTR_SLICE  ---------- 
module INSTR_SLICE (
    input  wire [31:0] instr_i,
    output wire [4:0]  rs1_addr_o,
    output wire [4:0]  rs2_addr_o,
    output wire [4:0]  rd_addr_o,
    output wire [2:0]  funct3_o
);
    assign rs1_addr_o = instr_i[19:15];
    assign rs2_addr_o = instr_i[24:20];
    assign rd_addr_o  = instr_i[11:7];
    assign funct3_o   = instr_i[14:12];
endmodule



//  ---------- INLCUDED BLOCK: INSTR_TAP  ---------- 
module INSTR_TAP (
    input  wire [31:0] in,
    output wire [31:0] out1,
    output wire [31:0] out2,
    output wire [31:0] out3,
    output wire [31:0] out4
);
    assign out1 = in;
    assign out2 = in;
    assign out3 = in;
    assign out4 = in;
endmodule



//  ---------- INLCUDED BLOCK: DECODE_CONTROL  ---------- 
module DECODE_CONTROL (
    input  wire [31:0] instr_i,
    input  wire [1:0]  state_i,
    output reg  [3:0]  ALU_Op,
    output wire        ALU_A_Sel,
    output wire        ALU_B_Sel,
    output wire        is_branch,
    output wire        is_jump,
    output wire        is_load,
    output reg  [2:0]  op_size_o,
    output wire        mem_write_enable,
    output wire        mem_read_enable,
    output wire        RegWrite_enable,
    output wire        pc_write_en,
    output wire        is_mult,
    output wire        is_crc,
    output wire [1:0]  mult_sel,
    output wire [1:0]  crc_sel
);
    localparam EXECUTE = 2'b10, WRITEBACK = 2'b11;

    wire [6:0] opcode = instr_i[6:0];
    wire [2:0] funct3 = instr_i[14:12];
    wire [6:0] funct7 = instr_i[31:25];

    wire is_r_type     = (opcode == 7'b0110011);
    wire is_i_type_alu = (opcode == 7'b0010011);
    assign is_branch   = (opcode == 7'b1100011);
    wire is_jal        = (opcode == 7'b1101111);
    wire is_jalr       = (opcode == 7'b1100111);
    assign is_jump     = is_jal || is_jalr;
    assign is_load     = (opcode == 7'b0000011);
    wire is_store      = (opcode == 7'b0100011);
    wire is_lui        = (opcode == 7'b0110111);
    wire is_auipc      = (opcode == 7'b0010111);

    assign is_mult  = is_r_type && (funct7 == 7'b0000001);
    assign is_crc   = is_r_type && (funct7 == 7'b1000000);
    assign mult_sel = funct3[1:0];
    assign crc_sel  = funct3[1:0];

    wire produces_result = is_r_type || is_i_type_alu || is_jump || is_load || is_lui || is_auipc;

    assign ALU_A_Sel = is_branch || is_jal || is_auipc;
    assign ALU_B_Sel = is_i_type_alu || is_branch || is_jump || is_load || is_store || is_lui || is_auipc;

    always @(*) begin
        if (is_r_type) begin
            case ({funct7, funct3})
                {7'b0000000, 3'b000}: ALU_Op = 4'h1;
                {7'b0100000, 3'b000}: ALU_Op = 4'h2;
                {7'b0000000, 3'b001}: ALU_Op = 4'h6;
                {7'b0000000, 3'b010}: ALU_Op = 4'h9;
                {7'b0000000, 3'b011}: ALU_Op = 4'hA;
                {7'b0000000, 3'b100}: ALU_Op = 4'h5;
                {7'b0000000, 3'b101}: ALU_Op = 4'h7;
                {7'b0100000, 3'b101}: ALU_Op = 4'h8;
                {7'b0000000, 3'b110}: ALU_Op = 4'h4;
                {7'b0000000, 3'b111}: ALU_Op = 4'h3;
                default:              ALU_Op = 4'h0;
            endcase
        end else if (is_i_type_alu) begin
            case (funct3)
                3'b000:  ALU_Op = 4'h1;
                3'b010:  ALU_Op = 4'h9;
                3'b011:  ALU_Op = 4'hA;
                3'b100:  ALU_Op = 4'h5;
                3'b110:  ALU_Op = 4'h4;
                3'b111:  ALU_Op = 4'h3;
                3'b001:  ALU_Op = 4'h6;
                3'b101:  ALU_Op = funct7[5] ? 4'h8 : 4'h7;
                default: ALU_Op = 4'h0;
            endcase
        end else if (is_branch || is_jump || is_load || is_store || is_auipc) begin
            ALU_Op = 4'h1;
        end else begin
            ALU_Op = 4'h0;
        end
    end

    always @(*) begin
        if (is_load) begin
            case (funct3)
                3'b000:  op_size_o = 3'b000;
                3'b001:  op_size_o = 3'b001;
                3'b010:  op_size_o = 3'b010;
                3'b100:  op_size_o = 3'b011;
                3'b101:  op_size_o = 3'b100;
                default: op_size_o = 3'b010;
            endcase
        end else if (is_store) begin
            case (funct3)
                3'b000:  op_size_o = 3'b101;
                3'b001:  op_size_o = 3'b110;
                3'b010:  op_size_o = 3'b111;
                default: op_size_o = 3'b111;
            endcase
        end else begin
            op_size_o = 3'b010;
        end
    end

    assign mem_read_enable  = is_load  && (state_i == EXECUTE || state_i == WRITEBACK);
    assign mem_write_enable = is_store && (state_i == EXECUTE);
    assign RegWrite_enable  = produces_result && (state_i == WRITEBACK);
    assign pc_write_en      = (state_i == WRITEBACK);
endmodule



//  ---------- INLCUDED BLOCK: STATE_TAP  ---------- 
module STATE_TAP (
    input  wire [1:0] in,
    output wire [1:0] out1,
    output wire [1:0] out2
);
    assign out1 = in;
    assign out2 = in;
endmodule



//  ---------- INLCUDED BLOCK: ALU_ExternalMUX_G14  ---------- 
// ================================================================
// ALU - EXTERNAL MUX VERSION
// ================================================================
// A/B source selection (rs1 vs PC, rs2 vs immediate) is done
// OUTSIDE this module, using separate MUX2_32 blocks. This module
// only receives the already-selected i_A / i_B operands.
//
// Encoding matches ChampionCHIP Block Guide, Table 9 exactly.
//
// Sign convention: i_A, i_B, o_Q are declared `signed` by default.
// $unsigned(...) is applied ONLY where Table 9 explicitly requires
// unsigned behavior (SRL, SLTU). SLT and MRS need no cast at all,
// since signed is already the module's default.
// ================================================================

module ALU_ExternalMUX_G14 (
    input  signed [31:0] i_A,
    input  signed [31:0] i_B,
    input         [3:0]  i_Sel,
    output reg signed [31:0] o_Q
);

    localparam c_ALU_OP_PASS_B = 4'h0;
    localparam c_ALU_OP_ADD    = 4'h1;
    localparam c_ALU_OP_SUB    = 4'h2;
    localparam c_ALU_OP_AND    = 4'h3;
    localparam c_ALU_OP_OR     = 4'h4;
    localparam c_ALU_OP_XOR    = 4'h5;
    localparam c_ALU_OP_SLL    = 4'h6;
    localparam c_ALU_OP_SRL    = 4'h7;
    localparam c_ALU_OP_MRS    = 4'h8;
    localparam c_ALU_OP_SLT    = 4'h9;
    localparam c_ALU_OP_SLTU   = 4'hA;

    always @ (*) begin
        case (i_Sel)

            c_ALU_OP_PASS_B: o_Q = i_B;

            c_ALU_OP_ADD:    o_Q = i_A + i_B;

            c_ALU_OP_SUB:    o_Q = i_A - i_B;

            c_ALU_OP_AND:    o_Q = i_A & i_B;

            c_ALU_OP_OR:     o_Q = i_A | i_B;

            c_ALU_OP_XOR:    o_Q = i_A ^ i_B;

            c_ALU_OP_SLL:    o_Q = i_A << i_B[4:0];

            // Only op needing an unsigned override: forces zero-fill
            // instead of the sign-fill that `signed >>` would imply.
            c_ALU_OP_SRL:    o_Q = $unsigned(i_A) >> i_B[4:0];

            // No cast needed: i_A is already signed, so >>> naturally
            // sign-extends from i_A's MSB.
            c_ALU_OP_MRS:    o_Q = i_A >>> i_B[4:0];

            // No cast needed: i_A/i_B already signed, so < is already
            // a signed comparison.
            c_ALU_OP_SLT:    o_Q = (i_A < i_B) ? 32'sd1 : 32'sd0;

            // Only other op needing an unsigned override: forces
            // magnitude comparison instead of signed comparison.
            c_ALU_OP_SLTU:   o_Q = ($unsigned(i_A) < $unsigned(i_B)) ? 32'sd1 : 32'sd0;

            default:         o_Q = 32'sd0;

        endcase
    end

endmodule



//  ---------- INLCUDED BLOCK: RISCV_IMM_GENERATOR_G14  ---------- 
module RISCV_IMM_GENERATOR_G14 (
    input [31:0] i_Instruction,
    output reg [31:0] o_Immediate
);
    /* Instruction Opcodes */
    localparam c_OPCODE_JAL    = 7'b1101111;
    localparam c_OPCODE_BRANCH = 7'b1100011;
    localparam c_OPCODE_STORE  = 7'b0100011;
    localparam c_OPCODE_LUI    = 7'b0110111;
    localparam c_OPCODE_AUIPC  = 7'b0010111;

    wire [11:0] w_I_Type_Imm = i_Instruction[31:20];
    wire [11:0] w_S_Type_Imm = {i_Instruction[31:25], i_Instruction[11:7]};
    wire [12:0] w_B_Type_Imm = {i_Instruction[31], i_Instruction[7], i_Instruction[30:25], i_Instruction[11:8], 1'b0};
    wire [20:0] w_J_Type_Imm = {i_Instruction[31], i_Instruction[19:12], i_Instruction[20], i_Instruction[30:25], i_Instruction[24:21], 1'b0};
    wire [31:0] w_U_Type_Imm = {i_Instruction[31:12], 12'b0};
       
    always @ (*) begin
        case (i_Instruction[6:0])
            c_OPCODE_JAL: 
                o_Immediate = $signed(w_J_Type_Imm);

            c_OPCODE_BRANCH: 
                o_Immediate = $signed(w_B_Type_Imm);

            c_OPCODE_STORE: 
                o_Immediate = $signed(w_S_Type_Imm);

            c_OPCODE_LUI,c_OPCODE_AUIPC:
                o_Immediate = w_U_Type_Imm;

            default: 
                o_Immediate = $signed(w_I_Type_Imm);
        endcase
    end 

endmodule



//  ---------- INLCUDED BLOCK: ALU_B_MUX  ---------- 
module ALU_B_MUX (
    input  wire [31:0] rs2_data,
    input  wire [31:0] imm_data,
    input  wire        sel,     // 0 = rs2 (R-type), 1 = immediate (I-type)
    output wire [31:0] out
);
    assign out = sel ? imm_data : rs2_data;
endmodule



//  ---------- INLCUDED BLOCK: ALU_A_MUX  ---------- 
module ALU_A_MUX (
    input  wire [31:0] rs1_data,
    input  wire [31:0] pc_data,
    input  wire        sel,     // 0 = rs1 (everything so far), 1 = PC (branch target calc)
    output wire [31:0] out
);
    assign out = sel ? pc_data : rs1_data;
endmodule



//  ---------- INLCUDED BLOCK: BRANCH_PC_SEL_G14  ---------- 
module BRANCH_PC_SEL_G14 (
    input  wire is_branch,
    input  wire branch_taken,
    output wire pc_sel   // 0 = PC+4, 1 = branch target
);
    assign pc_sel = is_branch && branch_taken;
endmodule



//  ---------- INLCUDED BLOCK: PC_NEXT_MUX_G14  ---------- 
module PC_NEXT_MUX_G14 (
    input  wire [31:0] pc_plus_4,
    input  wire [31:0] branch_target,
    input  wire        pc_sel,
    output wire [31:0] pc_next
);
    assign pc_next = pc_sel ? branch_target : pc_plus_4;
endmodule



//  ---------- INLCUDED BLOCK: RS1_TAP  ---------- 
module RS1_TAP (
    input  wire [31:0] in,
    output wire [31:0] out1,
    output wire [31:0] out2,
    output wire [31:0] out3   // new: feeds RISCV_MULTIPLIER.i_Reg_A AND crc_unit_v2.rs1_i
);
    assign out1 = in;
    assign out2 = in;
    assign out3 = in;
endmodule



//  ---------- INLCUDED BLOCK: RS2_TAP  ---------- 
module RS2_TAP (
    input  wire [31:0] in,
    output wire [31:0] out1,
    output wire [31:0] out2,
    output wire [31:0] out3,
    output wire [31:0] out4   // new: feeds RISCV_MULTIPLIER.i_Reg_B AND crc_unit_v2.rs2_i
);
    assign out1 = in;
    assign out2 = in;
    assign out3 = in;
    assign out4 = in;
endmodule



//  ---------- INLCUDED BLOCK: PC_TAP  ---------- 
module PC_TAP (
    input  wire [31:0] in,
    output wire [31:0] out1,
    output wire [31:0] out2
);
    assign out1 = in;
    assign out2 = in;
endmodule



//  ---------- INLCUDED BLOCK: RISCV_BRANCH_COMPARATOR_G14  ---------- 
module RISCV_BRANCH_COMPARATOR_G14 (
    input signed [31:0] i_Reg_A,
    input signed [31:0] i_Reg_B,
    input [2:0] i_Branch_Sel,
    output reg o_Branch_Taken
);   
    /* Branches */
    localparam c_BEQ  = 3'b000;
    localparam c_BNE  = 3'b001;
    localparam c_BLT  = 3'b100;
    localparam c_BGE  = 3'b101;
    localparam c_BLTU = 3'b110;   // ADDED
    localparam c_BGEU = 3'b111;   // ADDED
    
    wire w_Branch_Equal = (i_Reg_A == i_Reg_B);
    wire w_Branch_Less_Than = (i_Reg_A < i_Reg_B);
    wire w_Branch_Less_Than_U = ($unsigned(i_Reg_A) < $unsigned(i_Reg_B)); // ADDED
    always @ (*) begin
        case (i_Branch_Sel)
            c_BEQ:  o_Branch_Taken = w_Branch_Equal;
            c_BNE:  o_Branch_Taken = !w_Branch_Equal;
            c_BLT:  o_Branch_Taken = w_Branch_Less_Than;
            c_BGE:  o_Branch_Taken = !w_Branch_Less_Than;    // CHANGED: was "default", now explicit
            c_BLTU: o_Branch_Taken = w_Branch_Less_Than_U;   // ADDED
            c_BGEU: o_Branch_Taken = !w_Branch_Less_Than_U;  // ADDED
            default: o_Branch_Taken = 1'b0;                  // CHANGED: was "!w_Branch_Less_Than"
        endcase
    end
endmodule



//  ---------- INLCUDED BLOCK: WB_MUX_G14  ---------- 
module WB_MUX_G14 (
    input  wire [31:0] alu_result,
    input  wire [31:0] pc_plus_4,
    input  wire [31:0] mem_data,
    input  wire        is_jump,
    input  wire        is_load,
    output wire [31:0] out,
    // ---- appended for MULT/CRC ----
    input  wire [31:0] mult_result,
    input  wire [31:0] crc_result,
    input  wire        is_mult,
    input  wire        is_crc
);
    assign out = is_jump ? pc_plus_4   :
                 is_load ? mem_data    :
                 is_mult ? mult_result :
                 is_crc  ? crc_result  :
                 alu_result;
endmodule



//  ---------- INLCUDED BLOCK: JUMP_TARGET_MASK  ---------- 
module JUMP_TARGET_MASK (
    input  wire [31:0] target_in,
    output wire [31:0] target_out
);
    assign target_out = {target_in[31:1], 1'b0};  // JALR: force bit 0 to 0
endmodule



//  ---------- INLCUDED BLOCK: PC_SEL_OR  ---------- 
module PC_SEL_OR (
    input  wire branch_pc_sel,  // from BRANCH_PC_SEL_G14, unchanged
    input  wire is_jump,
    output wire pc_sel
);
    assign pc_sel = branch_pc_sel || is_jump;
endmodule



//  ---------- INLCUDED BLOCK: PC_PLUS_4  ---------- 
module PC_PLUS_4 (
    input  wire [31:0] a,
    output wire [31:0] y
);
    assign y = a + 32'd4;
endmodule



//  ---------- INLCUDED BLOCK: IS_JUMP_TAP  ---------- 
module IS_JUMP_TAP (
    input  wire in,
    output wire out1,
    output wire out2
);
    assign out1 = in;
    assign out2 = in;
endmodule



//  ---------- INLCUDED BLOCK: address_decoder_G14  ---------- 
module address_decoder_G14 (
    // ---- From CPU core (LSU) ----
    input  wire [31:0] address_i,   // full byte address from core
    input  wire        we_i,        // write enable request from core
    input  wire        oe_i,        // read (output enable) request from core
    input  wire [3:0]  bw_i,        // byte-write mask from core (for sb/sh)


    // ---- To DMEM ----
    output wire [31:0] dmem_address_o,
    output wire        dmem_we_o,
    output wire        dmem_oe_o,
    output wire [3:0]  dmem_bw_o,
    input  wire [31:0] dmem_data_i, // data read back from DMEM


    // ---- To IMEM ----
    output wire [31:0] imem_address_o,
    output wire        imem_oe_o,   // IMEM is read-only, so no we_o here
    input  wire [31:0] imem_data_i, // data read back from IMEM


    // ---- Back to CPU core ----
    output wire [31:0] data_o       // muxed read data returned to core
);


    // ------------------------------------------------------------
    // Address range detection
    // Decide which device (IMEM or DMEM) the incoming address_i
    // belongs to, based on the fixed base addresses in Table 13.
    // ------------------------------------------------------------
    wire is_imem = (address_i[31:22] == 10'd1) ? 1'b1 : 1'b0;
    wire is_dmem = (address_i[31:13] == 19'b0001_0000_0000_0001_000) ? 1'b1 : 1'b0;


    // ------------------------------------------------------------
    // Address forwarding
    // Both memories are word-addressed internally, so the bottom
    // 2 bits (byte offset within a word) are cleared before the
    // address is forwarded.
    // ------------------------------------------------------------
    assign dmem_address_o = {address_i[31:2], 2'b00};
    assign imem_address_o = {address_i[31:2], 2'b00};


    // ------------------------------------------------------------
    // Write enable routing
    // we_i is only ever forwarded to DMEM, and only when the
    // address actually falls in DMEM's range. IMEM is ROM, so it
    // has no we_o port at all - writes to it are silently dropped.
    // ------------------------------------------------------------
    assign dmem_we_o = (is_dmem && we_i);


    // ------------------------------------------------------------
    // Read enable routing
    // oe_i is gated separately for each device by its own
    // is_xxx range-select signal.
    // ------------------------------------------------------------
    assign dmem_oe_o = (is_dmem && oe_i);
    assign imem_oe_o = (is_imem && oe_i);


    // ------------------------------------------------------------
    // Byte-write mask routing
    // bw_i is only meaningful for DMEM, since IMEM can't be
    // written at all.
    // ------------------------------------------------------------
    assign dmem_bw_o = is_dmem ? bw_i : 4'b0000;


    // ------------------------------------------------------------
    // Read-data mux
    // If the address matches neither device, return 0.
    // ------------------------------------------------------------
    assign data_o = is_dmem ? dmem_data_i :
                    is_imem ? imem_data_i :
                              32'b0;


endmodule



//  ---------- INLCUDED BLOCK: crc_unit_v2  ---------- 
module crc_unit_v2 (
    input  wire [31:0] rs1_i,      // data
    input  wire [31:0] rs2_i,      // seed
    input  wire [1:0]  sel_i,      // 00=crcb, 01=crch, 10=crcw
    output wire [31:0] rd_o
);
    // Single shared byte array, always in CRCW's byte order.
    // crcb/crch just start partway through the same sequence instead of
    // running three independent 8/16/32-round chains in parallel.
    reg  [7:0] byte_arr [0:3];
    reg  [15:0] crc_calc;
    reg  [1:0]  start_idx;
    integer b, i;

    always @(*) begin
        byte_arr[0] = rs1_i[31:24];
        byte_arr[1] = rs1_i[23:16];
        byte_arr[2] = rs1_i[15:8];
        byte_arr[3] = rs1_i[7:0];

        case (sel_i)
            2'b00:   start_idx = 3;  // crcb: only the last byte (rs1_i[7:0])
            2'b01:   start_idx = 2;  // crch: last 2 bytes
            default: start_idx = 0;  // crcw: all 4 bytes
        endcase

        crc_calc = rs2_i[15:0];
        for (b = 0; b < 4; b = b + 1) begin
            if (b >= start_idx) begin
                crc_calc = ({8'b0, byte_arr[b]} << 8) ^ crc_calc;
                for (i = 0; i < 8; i = i + 1) begin
                    if (crc_calc[15])
                        crc_calc = (crc_calc << 1) ^ 16'h1021;
                    else
                        crc_calc = crc_calc << 1;
                end
            end
        end
    end

    assign rd_o = (sel_i == 2'b11) ? 32'b0 : {16'b0, crc_calc};
endmodule



//  ---------- INLCUDED BLOCK: RISCV_MULTIPLIER  ---------- 
module RISCV_MULTIPLIER (
    input         [31:0] i_Reg_A,       // Operand A (rs1)
    input         [31:0] i_Reg_B,       // Operand B (rs2)
    input         [1:0]  i_Mult_Sel,    // Operation selector: 00=MUL, 01=MULH, 10=MULHSU, 11=MULHU
    output reg    [31:0] o_Mult_Result  // 32-bit final result output
);


    // Multiplication operation selection encoding
    localparam c_MUL    = 2'b00;
    localparam c_MULH   = 2'b01;
    localparam c_MULHSU = 2'b10;
    localparam c_MULHU  = 2'b11;


    // ------------------------------------------------------------------
    // Step 1: Decode sign-extension control flags for Operand A and B
    // - signA: 1 for signed operation, 0 for unsigned operation
    // - signB: 1 for signed operation, 0 for unsigned operation
    // ------------------------------------------------------------------
    reg signA, signB;


    always @ (*) begin
        case (i_Mult_Sel)
            c_MUL:    {signA, signB} = 2'b11; // Signed x Signed
            c_MULH:   {signA, signB} = 2'b11; // Signed x Signed (Upper)
            c_MULHSU: {signA, signB} = 2'b10; // Signed (A) x Unsigned (B)
            c_MULHU:  {signA, signB} = 2'b00; // Unsigned x Unsigned
            default:  {signA, signB} = 2'b00; // Safe default to unsigned
        endcase
    end


    // ------------------------------------------------------------------
    // Step 2: Expand 32-bit operands to 64-bit based on extension control
    // - If sign flag is 1: Perform sign-extension using the MSB ([31])
    // - If sign flag is 0: Perform zero-extension with upper 32-bits as 0
    // ------------------------------------------------------------------
    wire signed [63:0] w_Ext_A;
    wire signed [63:0] w_Ext_B;


    assign w_Ext_A = signA ? {{32{i_Reg_A[31]}}, i_Reg_A} : {32'b0, i_Reg_A};
    assign w_Ext_B = signB ? {{32{i_Reg_B[31]}}, i_Reg_B} : {32'b0, i_Reg_B};  


    // ------------------------------------------------------------------
    // Step 3: Perform 64x64 signed multiplication
    // Since both operands are properly pre-extended, the arithmetic product
    // accurately captures the 64-bit mathematical result.
    // ------------------------------------------------------------------
    wire signed [63:0] w_Product;


    assign w_Product = w_Ext_A * w_Ext_B;


    // ------------------------------------------------------------------
    // Step 4: Output Multiplexer (Result Slicing)
    // - Select lower 32-bits [31:0] for standard MUL instruction
    // - Select upper 32-bits [63:32] for MULH, MULHSU, and MULHU instructions
    // ------------------------------------------------------------------
    always @ (*) begin
        case (i_Mult_Sel)
            c_MUL:    o_Mult_Result = w_Product[31:0];
            default:  o_Mult_Result = w_Product[63:32];
        endcase
    end


endmodule



//  ---------- INLCUDED BLOCK: CORE_MEM_MUX  ---------- 
module CORE_MEM_MUX (
    input  wire [1:0]  state_i,
    input  wire [31:0] pc_addr,
    input  wire [31:0] lsu_addr,
    input  wire        mem_read_enable,
    output wire [31:0] mem_addr_o,
    output wire        mem_oe_o,
    output wire        is_fetch_o       // NEW: doubles as IR's write-enable
);
    localparam FETCH = 2'b00;
    assign is_fetch_o = (state_i == FETCH);
    assign mem_addr_o = is_fetch_o ? pc_addr : lsu_addr;
    assign mem_oe_o    = is_fetch_o || mem_read_enable;
endmodule


// Automatically generated by ChipInventor Cloud EDA Tool - 3.15
// Careful: this file (hdl.v) will be automatically replaced
// when you ask tool to generate top Verilog code by clicking
// at BLOCKS button.

module top (

  input wire clk,
  input wire rst,
  output wire [31:0] instruction_o,
  output wire [1:0] state,
  output wire [31:0] immediate_debug,
  output wire [31:0] pc_o

);

//Internal Wires
 wire [31:0] w_1;
 wire [31:0] w_2;
 wire [3:0] w_3;
 wire [31:0] w_4;
 wire [31:0] w_7;
 wire [31:0] w_8;
 wire [31:0] w_10;
 wire w_11;
 wire [31:0] w_12;
 wire [31:0] w_13;
 wire [31:0] w_14;
 wire [31:0] w_15;
 wire [31:0] w_16;
 wire [31:0] w_17;
 wire [4:0] w_18;
 wire [4:0] w_19;
 wire [4:0] w_20;
 wire [2:0] w_21;
 wire [31:0] w_22;
 wire w_23;
 wire [31:0] w_24;
 wire [31:0] w_25;
 wire w_26;
 wire w_27;
 wire w_28;
 wire [31:0] w_29;
 wire [31:0] w_30;
 wire w_31;
 wire [31:0] w_32;
 wire w_33;
 wire [31:0] w_34;
 wire [31:0] w_35;
 wire w_36;
 wire w_37;
 wire [31:0] w_38;
 wire [2:0] w_39;
 wire [31:0] w_40;
 wire [31:0] w_41;
 wire [31:0] w_42;
 wire [3:0] w_43;
 wire [31:0] w_44;
 wire [31:0] w_45;
 wire w_46;
 wire w_47;
 wire [31:0] w_48;
 wire [31:0] w_49;
 wire [31:0] w_50;
 wire w_51;
 wire w_52;
 wire [3:0] w_53;
 wire [31:0] w_54;
 wire w_55;
 wire [31:0] w_57;
 wire [31:0] w_58;
 wire [31:0] w_60;
 wire [31:0] w_61;
 wire [1:0] w_63;
 wire [31:0] w_64;
 wire w_65;
 wire [31:0] w_66;
 wire w_67;
 wire w_68;
 wire [31:0] w_69;
 wire w_70;
 wire w_71;
 wire [1:0] w_75;
 wire [1:0] w_76;
 wire w_77;
 wire w_78;
 wire [1:0] w_79;

//Interface Assigns
assign immediate_debug[31:0] = w_8;
assign pc_o[31:0] = w_15;

//Instances of Modules
ALU_ExternalMUX_G14 blk3519_44 (
         .i_A (w_1),
         .i_B (w_2),
         .i_Sel (w_3),
         .o_Q (w_4)
     );

RISCV_IMM_GENERATOR_G14 blk3558_45 (
         .o_Immediate (w_8),
         .i_Instruction (w_7)
     );

ALU_B_MUX blk3561_46 (
         .out (w_2),
         .imm_data (w_8),
         .rs2_data (w_10),
         .sel (w_11)
     );

INSTR_TAP blk3511_48 (
         .out1 (instruction_o[31:0]),
         .out4 (w_7),
         .in (w_12),
         .out2 (w_13),
         .out3 (w_14)
     );

PC_TAP blk3616_52 (
         .in (w_15),
         .out1 (w_16),
         .out2 (w_17)
     );

INSTR_SLICE blk3508_53 (
         .instr_i (w_13),
         .rs1_addr_o (w_18),
         .rs2_addr_o (w_19),
         .rd_addr_o (w_20),
         .funct3_o (w_21)
     );

ALU_A_MUX blk3611_54 (
         .out (w_1),
         .pc_data (w_17),
         .rs1_data (w_22),
         .sel (w_23)
     );

RISCV_BRANCH_COMPARATOR_G14 blk3617_57 (
         .i_Branch_Sel (w_21),
         .i_Reg_A (w_24),
         .i_Reg_B (w_25),
         .o_Branch_Taken (w_26)
     );

BRANCH_PC_SEL_G14 blk3612_62 (
         .branch_taken (w_26),
         .is_branch (w_27),
         .pc_sel (w_28)
     );

PC_NEXT_MUX_G14 blk3613_63 (
         .pc_plus_4 (w_29),
         .branch_target (w_30),
         .pc_sel (w_31),
         .pc_next (w_32)
     );

JUMP_TARGET_MASK blk3623_66 (
         .target_in (w_4),
         .target_out (w_30)
     );

PC_SEL_OR blk3624_67 (
         .branch_pc_sel (w_28),
         .pc_sel (w_31),
         .is_jump (w_33)
     );

PC_PLUS4_TAP blk3503_69 (
         .out1 (w_29),
         .in (w_34),
         .out2 (w_35)
     );

PC_PLUS_4 blk3625_71 (
         .a (w_16),
         .y (w_34)
     );

IS_JUMP_TAP blk3627_72 (
         .out1 (w_33),
         .in (w_36),
         .out2 (w_37)
     );

LSU_v2 blk2940_75 (
         .core_address_o (w_4),
         .core_data_o (w_38),
         .op_size_o (w_39),
         .mem_data_o (w_40),
         .core_data_i (w_41),
         .mem_address_i (w_42),
         .byte_write_i (w_43),
         .mem_data_i (w_44)
     );

address_decoder_G14 blk3674_76 (
         .data_o (w_40),
         .bw_i (w_43),
         .address_i (w_45),
         .we_i (w_46),
         .oe_i (w_47),
         .dmem_data_i (w_48),
         .imem_data_i (w_49),
         .dmem_address_o (w_50),
         .dmem_we_o (w_51),
         .dmem_oe_o (w_52),
         .dmem_bw_o (w_53),
         .imem_address_o (w_54),
         .imem_oe_o (w_55)
     );

RS1_TAP blk3614_90 (
         .out1 (w_22),
         .out2 (w_24),
         .in (w_57),
         .out3 (w_58)
     );

RS2_TAP blk3615_91 (
         .out1 (w_10),
         .out2 (w_25),
         .out3 (w_38),
         .in (w_60),
         .out4 (w_61)
     );

crc_unit_v2 blk3732_92 (
         .rs1_i (w_58),
         .rs2_i (w_61),
         .sel_i (w_63),
         .rd_o (w_64)
     );

WB_MUX_G14 blk3622_94 (
         .alu_result (w_4),
         .pc_plus_4 (w_35),
         .is_jump (w_37),
         .mem_data (w_41),
         .crc_result (w_64),
         .is_load (w_65),
         .mult_result (w_66),
         .is_mult (w_67),
         .is_crc (w_68),
         .out (w_69)
     );

IR blk3409_103 (
         .clk (clk),
         .rst (rst),
         .instruction_o (w_12),
         .instruction_i (w_40),
         .ir_write_en (w_70)
     );

PC blk3437_104 (
         .clk (clk),
         .rst (rst),
         .pc_o (w_15),
         .pc_next_i (w_32),
         .pc_write_en (w_71)
     );

STATE_TAP blk3517_111 (
         .out1 (state[1:0]),
         .in (w_75),
         .out2 (w_76)
     );

DECODE_CONTROL blk3515_113 (
         .ALU_Op (w_3),
         .ALU_B_Sel (w_11),
         .instr_i (w_14),
         .ALU_A_Sel (w_23),
         .is_branch (w_27),
         .is_jump (w_36),
         .op_size_o (w_39),
         .mem_write_enable (w_46),
         .crc_sel (w_63),
         .is_load (w_65),
         .is_mult (w_67),
         .is_crc (w_68),
         .pc_write_en (w_71),
         .state_i (w_76),
         .mem_read_enable (w_77),
         .RegWrite_enable (w_78),
         .mult_sel (w_79)
     );

control_fsm blk3394_114 (
         .clk (clk),
         .rst (rst),
         .state (w_75)
     );

REGISTER_FILE_G14 blk3498_117 (
         .clk_i (clk),
         .rst_i (rst),
         .rs1_addr_i (w_18),
         .rs2_addr_i (w_19),
         .rd_addr_i (w_20),
         .rs1_data_o (w_57),
         .rs2_data_o (w_60),
         .rd_data_i (w_69),
         .we_i (w_78)
     );

CORE_MEM_MUX blk3753_118 (
         .lsu_addr (w_42),
         .mem_addr_o (w_45),
         .mem_oe_o (w_47),
         .is_fetch_o (w_70),
         .pc_addr (w_15),
         .mem_read_enable (w_77),
         .state_i (w_75)
     );

RISCV_MULTIPLIER blk3733_119 (
         .i_Reg_A (w_58),
         .i_Reg_B (w_61),
         .o_Mult_Result (w_66),
         .i_Mult_Sel (w_79)
     );

IMEM_v3 blk3472_126 (
         .clk (clk),
         .rst (rst),
         .data_o (w_49),
         .address_i (w_54),
         .oe_i (w_55)
     );

DMEM_v2 blk2871_127 (
         .clk (clk),
         .rst (rst),
         .data_i (w_44),
         .data_o (w_48),
         .address_i (w_50),
         .we_i (w_51),
         .oe_i (w_52),
         .bw_i (w_53)
     );


endmodule
