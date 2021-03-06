module DESCAN #(
  parameter[0:2047] SCAN_ROW = {
    8'd4, 8'd4, 8'd4, 8'd2, 8'd4, 8'd3, 8'd3, 8'd3,
    8'd4, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd4,
    8'd3, 8'd3, 8'd3, 8'd4, 8'd3, 8'd5, 8'd5, 8'd5,
    8'd5, 8'd5, 8'd5, 8'd5, 8'd6, 8'd6, 8'd6, 8'd6,
    8'd6, 8'd6, 8'd6, 8'd7, 8'd7, 8'd7, 8'd7, 8'd7,
    8'd7, 8'd7, 8'd1, 8'd0, 8'd1, 8'd0, 8'd1, 8'd0,
    8'd1, 8'd0, 8'd1, 8'd0, 8'd1, 8'd0, 8'd1, 8'd0,
    8'd1, 8'd1, 8'd1, 8'd0, 8'd1, 8'd1, 8'd1, 8'd1,
    8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
    8'd5, 8'd5, 8'd3, 8'd5, 8'd5, 8'd5, 8'd5, 8'd2,
    8'd7, 8'd4, 8'd7, 8'd4, 8'd6, 8'd6, 8'd4, 8'd5,
    8'd1, 8'd0, 8'd0, 8'd0, 8'd7, 8'd6, 8'd7, 8'd7,
    8'd4, 8'd5, 8'd5, 8'd7, 8'd2, 8'd7, 8'd7, 8'd7,
    8'd4, 8'd3, 8'd5, 8'd3, 8'd6, 8'd6, 8'd6, 8'd6,
    8'd6, 8'd5, 8'd2, 8'd2, 8'd4, 8'd4, 8'd4, 8'd7,
    8'd7, 8'd3, 8'd5, 8'd6, 8'd6, 8'd6, 8'd5, 8'd6,
    8'd6, 8'd5, 8'd0, 8'd0, 8'd0, 8'd1, 8'd0, 8'd0,
    8'd2, 8'd2, 8'd2, 8'd2, 8'd4, 8'd5, 8'd5, 8'd4,
    8'd2, 8'd3, 8'd0, 8'd0, 8'd4, 8'd2, 8'd2, 8'd0,
    8'd0, 8'd4, 8'd4, 8'd4, 8'd4, 8'd3, 8'd4, 8'd4,
    8'd4, 8'd3, 8'd3, 8'd2, 8'd4, 8'd7, 8'd3, 8'd0,
    8'd0, 8'd0, 8'd2, 8'd4, 8'd1, 8'd1, 8'd2, 8'd0,
    8'd1, 8'd1, 8'd1, 8'd3, 8'd7, 8'd6, 8'd6, 8'd6,
    8'd7, 8'd4, 8'd3, 8'd3, 8'd5, 8'd2, 8'd3, 8'd3,
    8'd6, 8'd5, 8'd5, 8'd3, 8'd5, 8'd7, 8'd5, 8'd4,
    8'd3, 8'd2, 8'd6, 8'd5, 8'd5, 8'd2, 8'd3, 8'd7,
    8'd3, 8'd6, 8'd2, 8'd3, 8'd3, 8'd3, 8'd6, 8'd2,
    8'd2, 8'd4, 8'd7, 8'd6, 8'd6, 8'd6, 8'd2, 8'd2,
    8'd2, 8'd5, 8'd4, 8'd2, 8'd3, 8'd3, 8'd2, 8'd7,
    8'd7, 8'd7, 8'd7, 8'd6, 8'd6, 8'd5, 8'd3, 8'd3,
    8'd7, 8'd7, 8'd7, 8'd7, 8'd1, 8'd1, 8'd1, 8'd4,
    8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1
  },
  parameter[0:2047] SCAN_COL = {
    8'd31, 8'd27, 8'd04, 8'd20, 8'd08, 8'd27, 8'd12, 8'd04,
    8'd12, 8'd27, 8'd08, 8'd16, 8'd04, 8'd12, 8'd31, 8'd16,
    8'd16, 8'd08, 8'd31, 8'd20, 8'd20, 8'd20, 8'd31, 8'd27,
    8'd12, 8'd08, 8'd16, 8'd04, 8'd20, 8'd31, 8'd16, 8'd08,
    8'd27, 8'd12, 8'd04, 8'd04, 8'd20, 8'd16, 8'd31, 8'd08,
    8'd27, 8'd12, 8'd16, 8'd16, 8'd08, 8'd08, 8'd12, 8'd12,
    8'd27, 8'd27, 8'd31, 8'd31, 8'd04, 8'd04, 8'd20, 8'd20,
    8'd17, 8'd21, 8'd09, 8'd00, 8'd00, 8'd05, 8'd13, 8'd24,
    8'd07, 8'd11, 8'd22, 8'd26, 8'd30, 8'd15, 8'd19, 8'd03,
    8'd13, 8'd21, 8'd00, 8'd28, 8'd17, 8'd01, 8'd05, 8'd00,
    8'd07, 8'd06, 8'd15, 8'd00, 8'd23, 8'd00, 8'd23, 8'd15,
    8'd28, 8'd28, 8'd05, 8'd06, 8'd06, 8'd14, 8'd22, 8'd10,
    8'd25, 8'd24, 8'd09, 8'd25, 8'd24, 8'd29, 8'd14, 8'd30,
    8'd14, 8'd23, 8'd22, 8'd14, 8'd13, 8'd28, 8'd21, 8'd05,
    8'd06, 8'd07, 8'd07, 8'd03, 8'd02, 8'd18, 8'd10, 8'd18,
    8'd02, 8'd06, 8'd30, 8'd29, 8'd26, 8'd11, 8'd18, 8'd19,
    8'd03, 8'd25, 8'd02, 8'd10, 8'd01, 8'd01, 8'd09, 8'd29,
    8'd22, 8'd19, 8'd15, 8'd11, 8'd11, 8'd10, 8'd02, 8'd03,
    8'd17, 8'd29, 8'd18, 8'd17, 8'd26, 8'd26, 8'd30, 8'd14,
    8'd13, 8'd17, 8'd24, 8'd09, 8'd01, 8'd01, 8'd05, 8'd21,
    8'd28, 8'd28, 8'd17, 8'd25, 8'd29, 8'd03, 8'd25, 8'd21,
    8'd25, 8'd24, 8'd09, 8'd19, 8'd10, 8'd02, 8'd01, 8'd23,
    8'd23, 8'd14, 8'd25, 8'd18, 8'd19, 8'd10, 8'd01, 8'd17,
    8'd11, 8'd13, 8'd13, 8'd21, 8'd14, 8'd28, 8'd24, 8'd05,
    8'd25, 8'd03, 8'd19, 8'd03, 8'd23, 8'd00, 8'd00, 8'd15,
    8'd09, 8'd18, 8'd18, 8'd26, 8'd29, 8'd29, 8'd02, 8'd26,
    8'd10, 8'd02, 8'd02, 8'd11, 8'd19, 8'd22, 8'd07, 8'd05,
    8'd21, 8'd22, 8'd23, 8'd22, 8'd30, 8'd15, 8'd14, 8'd23,
    8'd10, 8'd06, 8'd07, 8'd06, 8'd07, 8'd15, 8'd13, 8'd13,
    8'd28, 8'd21, 8'd05, 8'd24, 8'd09, 8'd11, 8'd26, 8'd30,
    8'd24, 8'd01, 8'd09, 8'd17, 8'd29, 8'd06, 8'd18, 8'd30,
    8'd03, 8'd07, 8'd11, 8'd26, 8'd22, 8'd30, 8'd15, 8'd19
  }
)(
  input   wire  [255:0]   scanned_i,

  output  wire  [255:0]   bpx_o
);
  // synopsys template

  wire  [0:31]  bitplaneXOR   [0:7];

  // descan
  genvar i;
  generate
    for (i = 0; i < 256; i = i + 1) begin : descan
      localparam  [7:0]   scan_row = SCAN_ROW[i * 8 : (i + 1) * 8 - 1];
      localparam  [7:0]   scan_col = SCAN_COL[i * 8 : (i + 1) * 8 - 1];
      assign bitplaneXOR[scan_row][scan_col] = scanned_i[255 - i];
    end
  endgenerate

  // rename output
  genvar j;
  generate
    for (j = 0; j < 8; j = j + 1) begin : output_rename
      assign bpx_o[(8 - j) * 32 - 1 : (7 - j) * 32] = bitplaneXOR[j];
    end
  endgenerate
endmodule

