module DECOMPRESSOR #(
  parameter   NUM_PATTERNS          = 8,
  parameter   NUM_FIRST_TRANSFORMER = 2,
  parameter   NUM_LAST_TRANSFORMER  = 6,
  parameter   NUM_TRANSFORMER       = NUM_LAST_TRANSFORMER-NUM_FIRST_TRANSFORMER+1,
  parameter   NUM_MODULES           = NUM_PATTERNS-1,

  parameter   LEN_ENCODE            = $clog2(NUM_PATTERNS)
)(
  input   wire  [255 + LEN_ENCODE:0]  data_i,
  input   wire                        clk,
  input   wire                        rst_n,
  input   wire                        en_i,

  output  wire  [255:0]               data_o,
  output  wire                        en_o
);

  wire  [           255:0]  data;
  wire  [  LEN_ENCODE-1:0]  select;
  wire  [           255:0]  scanned;
  wire                      en;

  STAGE1 #(
    .NUM_PATTERNS   (NUM_PATTERNS)
  ) PIPELINE_STAGE1 (
    .data_i         (data_i),

    .clk            (clk),
    .rst_n          (rst_n),
    .en_i           (en_i),

    .data_o         (data),
    .select_o       (select),
    .scanned_o      (scanned),
    .en_o           (en)
  );

  STAGE2 #(
    .NUM_PATTERNS           (NUM_PATTERNS),
    .NUM_FIRST_TRANSFORMER  (NUM_FIRST_TRANSFORMER),
    .NUM_LAST_TRANSFORMER   (NUM_LAST_TRANSFORMER)
  ) PIPELINE_STAGE2 (
    .data_i         (data),
    .select_i       (select),
    .scanned_i      (scanned),

    .clk            (clk),
    .rst_n          (rst_n),
    .en_i           (en),

    .data_o         (data_o),
    .en_o           (en_o)
  );

endmodule

module STAGE1 #(
  parameter   NUM_PATTERNS  = 8,
  parameter   LEN_ENCODE    = $clog2(NUM_PATTERNS)
)(
  input   wire  [255 + LEN_ENCODE:0]  data_i,

  input   wire                        clk,
  input   wire                        rst_n,
  input   wire                        en_i,

  output  wire  [             255:0]  data_o,
  output  wire  [  LEN_ENCODE - 1:0]  select_o,
  output  wire  [             255:0]  scanned_o,
  output  wire                        en_o
);
  // synopsys template

  wire  [255:0]             data;
  wire  [LEN_ENCODE-1:0]    select;
  wire  [255:0]             scanned;
  wire                      delayed_en_i;

  assign data   = data_i[255:0];
  assign select = data_i[255+LEN_ENCODE:256];

  // deconcat consumes 3 cycles
  DECONCAT #(
    .NUM_PATTERNS       (NUM_PATTERNS)
  )   DECAT   (
    .data_i             (data),
    .clk                (clk),
    .rst_n              (rst_n),
    .en_i               (en_i),

    .scanned_o          (scanned),
    .en_o               (delayed_en_i)
  );


  // -------------------------------------------------
  wire [255:0]            one_clk_delayed_data;
  wire [255:0]            two_clk_delayed_data;
  wire [255:0]            thr_clk_delayed_data;

  wire [LEN_ENCODE-1:0]   one_clk_delayed_select;
  wire [LEN_ENCODE-1:0]   two_clk_delayed_select;
  wire [LEN_ENCODE-1:0]   thr_clk_delayed_select;

  D_FF  #(
    .BITWIDTH     (256)
  )   DATA_IN_1_DFF  (
    .d_i          (data),
    .clk          (clk),
    .rst_n        (rst_n),

    .q_o          (one_clk_delayed_data)
  );

  D_FF  #(
    .BITWIDTH     (256)
  )   DATA_IN_2_DFF  (
    .d_i          (one_clk_delayed_data),
    .clk          (clk),
    .rst_n        (rst_n),

    .q_o          (two_clk_delayed_data)
  );

  D_FF  #(
    .BITWIDTH     (256)
  )   DATA_IN_3_DFF  (
    .d_i          (two_clk_delayed_data),
    .clk          (clk),
    .rst_n        (rst_n),

    .q_o          (thr_clk_delayed_data)
  );

  D_FF  #(
    .BITWIDTH     (LEN_ENCODE)
  )   SEL_IN_1_DFF  (
    .d_i          (select),
    .clk          (clk),
    .rst_n        (rst_n),

    .q_o          (one_clk_delayed_select)
  );

  D_FF  #(
    .BITWIDTH     (LEN_ENCODE)
  )   SEL_IN_2_DFF  (
    .d_i          (one_clk_delayed_select),
    .clk          (clk),
    .rst_n        (rst_n),

    .q_o          (two_clk_delayed_select)
  );

  D_FF  #(
    .BITWIDTH     (LEN_ENCODE)
  )   SEL_IN_3_DFF  (
    .d_i          (two_clk_delayed_select),
    .clk          (clk),
    .rst_n        (rst_n),

    .q_o          (thr_clk_delayed_select)
  );

  // -------------------------------------------------
  assign data_o     = thr_clk_delayed_data;
  assign select_o   = thr_clk_delayed_select;
  assign scanned_o  = scanned;
  assign en_o       = delayed_en_i;
endmodule


module STAGE2 #(
  parameter   NUM_PATTERNS            = 8,
  parameter   NUM_FIRST_TRANSFORMER   = 2,
  parameter   NUM_LAST_TRANSFORMER    = 6,
  parameter   NUM_TRANSFORMER         = NUM_LAST_TRANSFORMER-NUM_FIRST_TRANSFORMER+1,
  parameter   NUM_MODULES             = NUM_PATTERNS-1,

  parameter   LEN_ENCODE              = $clog2(NUM_PATTERNS)
)(
  input   wire  [             255:0]  data_i,
  input   wire  [  LEN_ENCODE - 1:0]  select_i,
  input   wire  [             255:0]  scanned_i,

  input   wire                        clk,
  input   wire                        rst_n,
  input   wire                        en_i,

  output  wire  [255:0]               data_o,
  output  wire                        en_o
);
  // synopsys template

  // Descan ===============================================================
  wire  [255:0]     bpx   [NUM_FIRST_TRANSFORMER:NUM_LAST_TRANSFORMER];
  wire  [255:0]     diff  [NUM_FIRST_TRANSFORMER:NUM_LAST_TRANSFORMER];
  DESCAN  #(
    .SCAN_ROW               ({
               8'd0, 8'd1, 8'd4, 8'd2, 8'd2, 8'd1, 8'd2, 8'd1,
               8'd2, 8'd1, 8'd2, 8'd2, 8'd1, 8'd2, 8'd2, 8'd1,
               8'd1, 8'd2, 8'd2, 8'd1, 8'd2, 8'd1, 8'd1, 8'd2,
               8'd1, 8'd2, 8'd1, 8'd2, 8'd1, 8'd1, 8'd2, 8'd1,
               8'd1, 8'd2, 8'd2, 8'd1, 8'd2, 8'd1, 8'd1, 8'd2,
               8'd2, 8'd1, 8'd1, 8'd2, 8'd2, 8'd1, 8'd1, 8'd2,
               8'd2, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5,
               8'd3, 8'd4, 8'd3, 8'd4, 8'd3, 8'd4, 8'd3, 8'd4,
               8'd3, 8'd4, 8'd6, 8'd3, 8'd4, 8'd3, 8'd4, 8'd6,
               8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd1, 8'd3, 8'd3,
               8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd5, 8'd5,
               8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd0, 8'd7, 8'd7,
               8'd3, 8'd5, 8'd0, 8'd3, 8'd0, 8'd0, 8'd7, 8'd3,
               8'd3, 8'd7, 8'd7, 8'd3, 8'd3, 8'd0, 8'd7, 8'd7,
               8'd0, 8'd3, 8'd0, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3,
               8'd3, 8'd3, 8'd3, 8'd3, 8'd4, 8'd4, 8'd4, 8'd4,
               8'd4, 8'd4, 8'd4, 8'd4, 8'd7, 8'd4, 8'd7, 8'd7,
               8'd4, 8'd4, 8'd5, 8'd0, 8'd7, 8'd4, 8'd0, 8'd7,
               8'd4, 8'd4, 8'd0, 8'd7, 8'd7, 8'd7, 8'd4, 8'd0,
               8'd5, 8'd7, 8'd7, 8'd4, 8'd0, 8'd5, 8'd7, 8'd5,
               8'd5, 8'd5, 8'd5, 8'd1, 8'd5, 8'd6, 8'd4, 8'd4,
               8'd6, 8'd5, 8'd1, 8'd4, 8'd4, 8'd4, 8'd2, 8'd2,
               8'd6, 8'd4, 8'd6, 8'd2, 8'd6, 8'd6, 8'd2, 8'd2,
               8'd2, 8'd1, 8'd1, 8'd2, 8'd2, 8'd1, 8'd4, 8'd1,
               8'd1, 8'd6, 8'd1, 8'd6, 8'd4, 8'd0, 8'd7, 8'd7,
               8'd6, 8'd7, 8'd6, 8'd7, 8'd7, 8'd7, 8'd6, 8'd6,
               8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd5, 8'd5, 8'd5,
               8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd5, 8'd0, 8'd0,
               8'd5, 8'd5, 8'd5, 8'd7, 8'd0, 8'd5, 8'd7, 8'd7,
               8'd7, 8'd7, 8'd7, 8'd7, 8'd7, 8'd0, 8'd0, 8'd0,
               8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd3,
               8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6
    }),
    .SCAN_COL               ({
               8'd00, 8'd27, 8'd00, 8'd31, 8'd27, 8'd31, 8'd00, 8'd08,
               8'd08, 8'd28, 8'd01, 8'd02, 8'd29, 8'd29, 8'd04, 8'd05,
               8'd09, 8'd09, 8'd21, 8'd21, 8'd19, 8'd20, 8'd19, 8'd20,
               8'd16, 8'd15, 8'd15, 8'd17, 8'd17, 8'd12, 8'd11, 8'd11,
               8'd13, 8'd13, 8'd23, 8'd25, 8'd25, 8'd23, 8'd24, 8'd24,
               8'd06, 8'd06, 8'd04, 8'd05, 8'd28, 8'd01, 8'd02, 8'd16,
               8'd12, 8'd12, 8'd16, 8'd28, 8'd01, 8'd20, 8'd05, 8'd24,
               8'd01, 8'd01, 8'd28, 8'd28, 8'd16, 8'd16, 8'd12, 8'd12,
               8'd24, 8'd24, 8'd24, 8'd05, 8'd05, 8'd20, 8'd20, 8'd20,
               8'd05, 8'd16, 8'd28, 8'd01, 8'd12, 8'd00, 8'd03, 8'd07,
               8'd30, 8'd22, 8'd10, 8'd14, 8'd26, 8'd18, 8'd17, 8'd06,
               8'd09, 8'd02, 8'd21, 8'd29, 8'd13, 8'd16, 8'd24, 8'd12,
               8'd13, 8'd25, 8'd05, 8'd09, 8'd20, 8'd28, 8'd01, 8'd02,
               8'd21, 8'd20, 8'd05, 8'd06, 8'd29, 8'd01, 8'd28, 8'd16,
               8'd24, 8'd17, 8'd12, 8'd25, 8'd19, 8'd11, 8'd23, 8'd15,
               8'd31, 8'd27, 8'd04, 8'd08, 8'd08, 8'd07, 8'd26, 8'd30,
               8'd22, 8'd14, 8'd10, 8'd03, 8'd15, 8'd18, 8'd04, 8'd31,
               8'd13, 8'd09, 8'd00, 8'd09, 8'd09, 8'd25, 8'd25, 8'd25,
               8'd21, 8'd02, 8'd02, 8'd02, 8'd17, 8'd06, 8'd06, 8'd06,
               8'd23, 8'd13, 8'd29, 8'd29, 8'd29, 8'd04, 8'd21, 8'd15,
               8'd27, 8'd19, 8'd08, 8'd07, 8'd31, 8'd10, 8'd23, 8'd04,
               8'd14, 8'd11, 8'd22, 8'd15, 8'd31, 8'd11, 8'd30, 8'd26,
               8'd07, 8'd19, 8'd26, 8'd03, 8'd30, 8'd18, 8'd10, 8'd22,
               8'd07, 8'd03, 8'd26, 8'd18, 8'd14, 8'd30, 8'd27, 8'd14,
               8'd18, 8'd22, 8'd10, 8'd03, 8'd17, 8'd17, 8'd27, 8'd19,
               8'd21, 8'd23, 8'd00, 8'd08, 8'd00, 8'd11, 8'd13, 8'd17,
               8'd29, 8'd02, 8'd06, 8'd09, 8'd25, 8'd07, 8'd30, 8'd26,
               8'd22, 8'd14, 8'd10, 8'd03, 8'd30, 8'd14, 8'd26, 8'd07,
               8'd22, 8'd03, 8'd10, 8'd14, 8'd18, 8'd18, 8'd07, 8'd03,
               8'd22, 8'd26, 8'd10, 8'd30, 8'd18, 8'd13, 8'd21, 8'd19,
               8'd23, 8'd15, 8'd11, 8'd08, 8'd04, 8'd31, 8'd27, 8'd00,
               8'd23, 8'd27, 8'd31, 8'd04, 8'd19, 8'd15, 8'd11, 8'd08
    })
  )   PATTERN2_DESCAN   (
    .scanned_i      (scanned_i),

    .bpx_o          (bpx[2])
  );
  DEDBX   PATTERN2_DEDBX  (
    .bpx_i          (bpx[2]),

    .diff_o         (diff[2])
  );

  DESCAN  #(
    .SCAN_ROW               ({
               8'd7, 8'd5, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3,
               8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd2, 8'd2, 8'd2,
               8'd2, 8'd4, 8'd4, 8'd4, 8'd4, 8'd5, 8'd5, 8'd5,
               8'd5, 8'd5, 8'd5, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4,
               8'd4, 8'd4, 8'd4, 8'd2, 8'd2, 8'd2, 8'd0, 8'd1,
               8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd1, 8'd0,
               8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd1, 8'd1, 8'd2,
               8'd1, 8'd2, 8'd2, 8'd2, 8'd2, 8'd1, 8'd1, 8'd1,
               8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd5,
               8'd3, 8'd7, 8'd7, 8'd7, 8'd6, 8'd6, 8'd7, 8'd5,
               8'd6, 8'd6, 8'd6, 8'd7, 8'd6, 8'd5, 8'd6, 8'd6,
               8'd5, 8'd6, 8'd7, 8'd6, 8'd5, 8'd7, 8'd7, 8'd7,
               8'd7, 8'd7, 8'd6, 8'd6, 8'd2, 8'd1, 8'd1, 8'd1,
               8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1,
               8'd1, 8'd3, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2,
               8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd4, 8'd3,
               8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3,
               8'd3, 8'd3, 8'd3, 8'd5, 8'd3, 8'd2, 8'd4, 8'd4,
               8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4,
               8'd4, 8'd4, 8'd6, 8'd3, 8'd2, 8'd5, 8'd5, 8'd5,
               8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5,
               8'd5, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6,
               8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd0, 8'd7, 8'd5,
               8'd4, 8'd6, 8'd2, 8'd1, 8'd3, 8'd4, 8'd7, 8'd5,
               8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
               8'd0, 8'd0, 8'd0, 8'd0, 8'd7, 8'd7, 8'd7, 8'd7,
               8'd7, 8'd7, 8'd7, 8'd7, 8'd7, 8'd7, 8'd7, 8'd7,
               8'd1, 8'd5, 8'd4, 8'd2, 8'd3, 8'd3, 8'd1, 8'd2,
               8'd4, 8'd5, 8'd4, 8'd6, 8'd1, 8'd0, 8'd0, 8'd7,
               8'd4, 8'd5, 8'd6, 8'd7, 8'd3, 8'd2, 8'd0, 8'd7,
               8'd6, 8'd7, 8'd6, 8'd0, 8'd5, 8'd6, 8'd0, 8'd7,
               8'd0, 8'd1, 8'd6, 8'd7, 8'd4, 8'd5, 8'd3, 8'd2
    }),
    .SCAN_COL               ({
               8'd31, 8'd23, 8'd29, 8'd27, 8'd25, 8'd23, 8'd21, 8'd14,
               8'd12, 8'd10, 8'd08, 8'd06, 8'd04, 8'd31, 8'd29, 8'd27,
               8'd25, 8'd04, 8'd06, 8'd08, 8'd31, 8'd14, 8'd12, 8'd10,
               8'd08, 8'd06, 8'd04, 8'd29, 8'd10, 8'd27, 8'd25, 8'd23,
               8'd21, 8'd14, 8'd12, 8'd23, 8'd21, 8'd14, 8'd21, 8'd02,
               8'd31, 8'd29, 8'd27, 8'd25, 8'd23, 8'd17, 8'd06, 8'd14,
               8'd12, 8'd10, 8'd08, 8'd06, 8'd04, 8'd04, 8'd08, 8'd12,
               8'd27, 8'd10, 8'd08, 8'd06, 8'd04, 8'd31, 8'd29, 8'd25,
               8'd10, 8'd23, 8'd21, 8'd19, 8'd17, 8'd14, 8'd12, 8'd21,
               8'd31, 8'd21, 8'd06, 8'd14, 8'd27, 8'd04, 8'd04, 8'd31,
               8'd08, 8'd06, 8'd12, 8'd12, 8'd14, 8'd29, 8'd31, 8'd29,
               8'd27, 8'd21, 8'd10, 8'd23, 8'd25, 8'd23, 8'd25, 8'd27,
               8'd29, 8'd08, 8'd25, 8'd10, 8'd02, 8'd11, 8'd20, 8'd24,
               8'd09, 8'd13, 8'd03, 8'd22, 8'd26, 8'd28, 8'd07, 8'd05,
               8'd30, 8'd02, 8'd28, 8'd11, 8'd22, 8'd20, 8'd03, 8'd05,
               8'd07, 8'd09, 8'd24, 8'd26, 8'd13, 8'd30, 8'd02, 8'd11,
               8'd09, 8'd07, 8'd13, 8'd20, 8'd22, 8'd24, 8'd26, 8'd28,
               8'd30, 8'd03, 8'd05, 8'd02, 8'd19, 8'd19, 8'd26, 8'd28,
               8'd30, 8'd24, 8'd22, 8'd20, 8'd11, 8'd09, 8'd07, 8'd05,
               8'd03, 8'd13, 8'd02, 8'd17, 8'd17, 8'd24, 8'd22, 8'd20,
               8'd26, 8'd28, 8'd30, 8'd11, 8'd09, 8'd07, 8'd05, 8'd03,
               8'd13, 8'd13, 8'd11, 8'd09, 8'd07, 8'd05, 8'd03, 8'd20,
               8'd22, 8'd24, 8'd26, 8'd28, 8'd30, 8'd02, 8'd02, 8'd19,
               8'd19, 8'd19, 8'd18, 8'd18, 8'd18, 8'd18, 8'd19, 8'd18,
               8'd13, 8'd11, 8'd09, 8'd07, 8'd05, 8'd03, 8'd22, 8'd20,
               8'd24, 8'd26, 8'd28, 8'd30, 8'd20, 8'd22, 8'd24, 8'd26,
               8'd28, 8'd30, 8'd11, 8'd09, 8'd07, 8'd05, 8'd03, 8'd13,
               8'd01, 8'd17, 8'd17, 8'd01, 8'd01, 8'd15, 8'd15, 8'd15,
               8'd15, 8'd15, 8'd01, 8'd18, 8'd16, 8'd19, 8'd18, 8'd18,
               8'd16, 8'd16, 8'd16, 8'd16, 8'd16, 8'd16, 8'd16, 8'd15,
               8'd15, 8'd17, 8'd17, 8'd15, 8'd01, 8'd01, 8'd01, 8'd01,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00
    })
  )   PATTERN3_DESCAN   (
    .scanned_i      (scanned_i),

    .bpx_o          (bpx[3])
  );
  DEDBX   PATTERN3_DEDBX  (
    .bpx_i          (bpx[3]),

    .diff_o         (diff[3])
  );

  DESCAN  #(
    .SCAN_ROW               ({
               8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd3, 8'd3,
               8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd4, 8'd4, 8'd4,
               8'd4, 8'd4, 8'd4, 8'd4, 8'd1, 8'd1, 8'd1, 8'd1,
               8'd1, 8'd1, 8'd1, 8'd0, 8'd3, 8'd1, 8'd2, 8'd5,
               8'd6, 8'd3, 8'd1, 8'd2, 8'd5, 8'd6, 8'd3, 8'd1,
               8'd2, 8'd5, 8'd6, 8'd3, 8'd1, 8'd2, 8'd5, 8'd6,
               8'd3, 8'd1, 8'd2, 8'd5, 8'd6, 8'd3, 8'd1, 8'd2,
               8'd5, 8'd6, 8'd2, 8'd5, 8'd6, 8'd2, 8'd1, 8'd1,
               8'd2, 8'd3, 8'd7, 8'd0, 8'd7, 8'd0, 8'd0, 8'd7,
               8'd0, 8'd7, 8'd0, 8'd0, 8'd7, 8'd0, 8'd7, 8'd7,
               8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd5, 8'd5,
               8'd5, 8'd5, 8'd5, 8'd5, 8'd4, 8'd5, 8'd0, 8'd1,
               8'd5, 8'd2, 8'd3, 8'd4, 8'd6, 8'd7, 8'd6, 8'd6,
               8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd3, 8'd0, 8'd0,
               8'd0, 8'd0, 8'd7, 8'd7, 8'd7, 8'd7, 8'd0, 8'd0,
               8'd0, 8'd7, 8'd7, 8'd7, 8'd1, 8'd1, 8'd1, 8'd1,
               8'd1, 8'd1, 8'd1, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2,
               8'd2, 8'd2, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3,
               8'd3, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4,
               8'd4, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5,
               8'd5, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6,
               8'd7, 8'd0, 8'd7, 8'd7, 8'd0, 8'd0, 8'd7, 8'd0,
               8'd0, 8'd7, 8'd0, 8'd7, 8'd0, 8'd1, 8'd1, 8'd1,
               8'd1, 8'd1, 8'd1, 8'd1, 8'd7, 8'd2, 8'd2, 8'd2,
               8'd2, 8'd2, 8'd2, 8'd2, 8'd3, 8'd3, 8'd3, 8'd3,
               8'd3, 8'd3, 8'd3, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4,
               8'd4, 8'd4, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5,
               8'd0, 8'd6, 8'd7, 8'd2, 8'd0, 8'd1, 8'd3, 8'd4,
               8'd0, 8'd0, 8'd5, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6,
               8'd7, 8'd7, 8'd6, 8'd6, 8'd7, 8'd7, 8'd5, 8'd2,
               8'd3, 8'd0, 8'd7, 8'd4, 8'd6, 8'd1, 8'd5, 8'd7,
               8'd7, 8'd7, 8'd7, 8'd0, 8'd0, 8'd0, 8'd0, 8'd6
    }),
    .SCAN_COL               ({
               8'd22, 8'd19, 8'd30, 8'd07, 8'd03, 8'd26, 8'd23, 8'd12,
               8'd27, 8'd04, 8'd08, 8'd31, 8'd16, 8'd12, 8'd16, 8'd27,
               8'd31, 8'd23, 8'd08, 8'd04, 8'd23, 8'd16, 8'd12, 8'd08,
               8'd04, 8'd31, 8'd27, 8'd15, 8'd07, 8'd07, 8'd12, 8'd12,
               8'd12, 8'd19, 8'd19, 8'd16, 8'd16, 8'd16, 8'd22, 8'd22,
               8'd23, 8'd23, 8'd23, 8'd26, 8'd26, 8'd27, 8'd27, 8'd27,
               8'd30, 8'd30, 8'd31, 8'd31, 8'd31, 8'd03, 8'd03, 8'd04,
               8'd04, 8'd04, 8'd08, 8'd08, 8'd08, 8'd15, 8'd15, 8'd11,
               8'd11, 8'd11, 8'd12, 8'd08, 8'd04, 8'd23, 8'd16, 8'd16,
               8'd12, 8'd08, 8'd04, 8'd31, 8'd27, 8'd27, 8'd23, 8'd31,
               8'd30, 8'd22, 8'd07, 8'd19, 8'd03, 8'd26, 8'd26, 8'd19,
               8'd03, 8'd07, 8'd22, 8'd30, 8'd11, 8'd11, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd19, 8'd03,
               8'd07, 8'd22, 8'd30, 8'd26, 8'd11, 8'd15, 8'd11, 8'd07,
               8'd22, 8'd26, 8'd19, 8'd03, 8'd07, 8'd11, 8'd19, 8'd03,
               8'd30, 8'd22, 8'd26, 8'd30, 8'd29, 8'd21, 8'd25, 8'd10,
               8'd02, 8'd06, 8'd14, 8'd14, 8'd21, 8'd29, 8'd25, 8'd10,
               8'd02, 8'd06, 8'd06, 8'd14, 8'd21, 8'd29, 8'd25, 8'd10,
               8'd02, 8'd02, 8'd10, 8'd25, 8'd21, 8'd29, 8'd14, 8'd06,
               8'd15, 8'd15, 8'd10, 8'd25, 8'd21, 8'd29, 8'd14, 8'd06,
               8'd02, 8'd02, 8'd10, 8'd25, 8'd14, 8'd29, 8'd21, 8'd06,
               8'd06, 8'd06, 8'd14, 8'd29, 8'd29, 8'd14, 8'd21, 8'd25,
               8'd10, 8'd10, 8'd02, 8'd02, 8'd21, 8'd24, 8'd28, 8'd13,
               8'd09, 8'd05, 8'd01, 8'd20, 8'd25, 8'd13, 8'd09, 8'd05,
               8'd01, 8'd24, 8'd28, 8'd20, 8'd20, 8'd13, 8'd09, 8'd05,
               8'd01, 8'd24, 8'd28, 8'd28, 8'd24, 8'd13, 8'd09, 8'd05,
               8'd01, 8'd20, 8'd13, 8'd05, 8'd01, 8'd24, 8'd28, 8'd20,
               8'd24, 8'd15, 8'd15, 8'd18, 8'd18, 8'd18, 8'd18, 8'd18,
               8'd28, 8'd20, 8'd09, 8'd13, 8'd05, 8'd24, 8'd28, 8'd09,
               8'd13, 8'd05, 8'd01, 8'd20, 8'd17, 8'd01, 8'd18, 8'd17,
               8'd17, 8'd17, 8'd18, 8'd17, 8'd18, 8'd17, 8'd17, 8'd24,
               8'd28, 8'd20, 8'd09, 8'd05, 8'd13, 8'd09, 8'd01, 8'd17
    })
  )   PATTERN4_DESCAN   (
    .scanned_i      (scanned_i),

    .bpx_o          (bpx[4])
  );
  DEDBX   PATTERN4_DEDBX  (
    .bpx_i          (bpx[4]),

    .diff_o         (diff[4])
  );

  DESCAN  #(
    .SCAN_ROW               ({
               8'd4, 8'd4, 8'd4, 8'd4, 8'd3, 8'd3, 8'd3, 8'd3,
               8'd4, 8'd3, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd4,
               8'd4, 8'd3, 8'd3, 8'd2, 8'd2, 8'd5, 8'd5, 8'd5,
               8'd5, 8'd5, 8'd5, 8'd5, 8'd6, 8'd6, 8'd6, 8'd6,
               8'd6, 8'd6, 8'd6, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1,
               8'd1, 8'd0, 8'd1, 8'd0, 8'd7, 8'd7, 8'd1, 8'd7,
               8'd0, 8'd0, 8'd7, 8'd0, 8'd0, 8'd7, 8'd7, 8'd7,
               8'd0, 8'd0, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd2,
               8'd2, 8'd2, 8'd2, 8'd3, 8'd3, 8'd2, 8'd3, 8'd3,
               8'd3, 8'd4, 8'd4, 8'd7, 8'd7, 8'd6, 8'd5, 8'd4,
               8'd7, 8'd6, 8'd7, 8'd5, 8'd6, 8'd3, 8'd3, 8'd2,
               8'd1, 8'd1, 8'd2, 8'd4, 8'd4, 8'd5, 8'd3, 8'd2,
               8'd1, 8'd0, 8'd7, 8'd7, 8'd6, 8'd6, 8'd5, 8'd5,
               8'd4, 8'd3, 8'd3, 8'd4, 8'd2, 8'd1, 8'd1, 8'd2,
               8'd0, 8'd2, 8'd2, 8'd2, 8'd4, 8'd4, 8'd5, 8'd5,
               8'd0, 8'd0, 8'd0, 8'd2, 8'd2, 8'd4, 8'd4, 8'd6,
               8'd5, 8'd5, 8'd6, 8'd7, 8'd7, 8'd2, 8'd4, 8'd3,
               8'd3, 8'd0, 8'd6, 8'd6, 8'd6, 8'd2, 8'd2, 8'd2,
               8'd4, 8'd5, 8'd6, 8'd7, 8'd2, 8'd2, 8'd4, 8'd0,
               8'd0, 8'd0, 8'd0, 8'd0, 8'd6, 8'd6, 8'd7, 8'd7,
               8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd2,
               8'd1, 8'd3, 8'd3, 8'd3, 8'd3, 8'd1, 8'd1, 8'd1,
               8'd0, 8'd0, 8'd0, 8'd3, 8'd5, 8'd5, 8'd7, 8'd6,
               8'd6, 8'd1, 8'd1, 8'd1, 8'd1, 8'd6, 8'd6, 8'd6,
               8'd6, 8'd6, 8'd7, 8'd1, 8'd1, 8'd1, 8'd5, 8'd7,
               8'd6, 8'd6, 8'd1, 8'd0, 8'd2, 8'd5, 8'd3, 8'd4,
               8'd4, 8'd4, 8'd4, 8'd4, 8'd5, 8'd5, 8'd5, 8'd3,
               8'd3, 8'd5, 8'd5, 8'd4, 8'd6, 8'd5, 8'd2, 8'd3,
               8'd3, 8'd5, 8'd3, 8'd4, 8'd4, 8'd4, 8'd3, 8'd7,
               8'd0, 8'd1, 8'd5, 8'd5, 8'd5, 8'd4, 8'd7, 8'd6,
               8'd3, 8'd4, 8'd5, 8'd2, 8'd7, 8'd7, 8'd7, 8'd7,
               8'd7, 8'd7, 8'd7, 8'd7, 8'd0, 8'd1, 8'd7, 8'd6
    }),
    .SCAN_COL               ({
               8'd27, 8'd31, 8'd08, 8'd23, 8'd23, 8'd08, 8'd31, 8'd27,
               8'd19, 8'd19, 8'd31, 8'd23, 8'd08, 8'd19, 8'd04, 8'd04,
               8'd12, 8'd12, 8'd04, 8'd27, 8'd12, 8'd12, 8'd04, 8'd08,
               8'd23, 8'd31, 8'd27, 8'd19, 8'd08, 8'd23, 8'd31, 8'd27,
               8'd12, 8'd04, 8'd19, 8'd08, 8'd12, 8'd23, 8'd31, 8'd27,
               8'd04, 8'd00, 8'd19, 8'd19, 8'd27, 8'd12, 8'd00, 8'd31,
               8'd23, 8'd27, 8'd19, 8'd08, 8'd04, 8'd23, 8'd08, 8'd04,
               8'd12, 8'd31, 8'd15, 8'd22, 8'd30, 8'd07, 8'd11, 8'd22,
               8'd15, 8'd07, 8'd30, 8'd22, 8'd15, 8'd11, 8'd11, 8'd07,
               8'd30, 8'd22, 8'd15, 8'd13, 8'd05, 8'd05, 8'd05, 8'd05,
               8'd20, 8'd20, 8'd01, 8'd01, 8'd01, 8'd01, 8'd05, 8'd05,
               8'd05, 8'd01, 8'd01, 8'd01, 8'd20, 8'd20, 8'd20, 8'd20,
               8'd20, 8'd20, 8'd16, 8'd09, 8'd09, 8'd16, 8'd16, 8'd09,
               8'd09, 8'd09, 8'd16, 8'd16, 8'd16, 8'd16, 8'd09, 8'd09,
               8'd05, 8'd21, 8'd06, 8'd29, 8'd30, 8'd07, 8'd15, 8'd22,
               8'd22, 8'd30, 8'd11, 8'd02, 8'd17, 8'd18, 8'd03, 8'd30,
               8'd30, 8'd07, 8'd07, 8'd07, 8'd30, 8'd14, 8'd28, 8'd28,
               8'd24, 8'd01, 8'd06, 8'd21, 8'd29, 8'd18, 8'd26, 8'd03,
               8'd11, 8'd11, 8'd11, 8'd11, 8'd10, 8'd25, 8'd26, 8'd25,
               8'd10, 8'd29, 8'd21, 8'd06, 8'd22, 8'd15, 8'd15, 8'd22,
               8'd15, 8'd07, 8'd02, 8'd17, 8'd16, 8'd09, 8'd24, 8'd13,
               8'd13, 8'd14, 8'd21, 8'd06, 8'd29, 8'd18, 8'd26, 8'd03,
               8'd26, 8'd18, 8'd03, 8'd02, 8'd03, 8'd18, 8'd18, 8'd18,
               8'd03, 8'd29, 8'd21, 8'd06, 8'd02, 8'd02, 8'd14, 8'd25,
               8'd10, 8'd17, 8'd26, 8'd25, 8'd17, 8'd14, 8'd13, 8'd28,
               8'd24, 8'd26, 8'd10, 8'd13, 8'd28, 8'd28, 8'd13, 8'd02,
               8'd14, 8'd29, 8'd21, 8'd06, 8'd06, 8'd21, 8'd29, 8'd18,
               8'd03, 8'd02, 8'd14, 8'd13, 8'd28, 8'd24, 8'd24, 8'd25,
               8'd10, 8'd26, 8'd26, 8'd25, 8'd10, 8'd17, 8'd17, 8'd03,
               8'd14, 8'd24, 8'd25, 8'd10, 8'd17, 8'd24, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd06, 8'd02, 8'd14, 8'd17,
               8'd21, 8'd29, 8'd25, 8'd10, 8'd28, 8'd28, 8'd24, 8'd13
    })
  )   PATTERN5_DESCAN   (
    .scanned_i      (scanned_i),

    .bpx_o          (bpx[5])
  );
  DEDBX   PATTERN5_DEDBX  (
    .bpx_i          (bpx[5]),

    .diff_o         (diff[5])
  );

  DESCAN  #(
    .SCAN_ROW               ({
               8'd3, 8'd4, 8'd3, 8'd4, 8'd5, 8'd3, 8'd5, 8'd2,
               8'd2, 8'd4, 8'd6, 8'd6, 8'd5, 8'd6, 8'd7, 8'd7,
               8'd7, 8'd2, 8'd1, 8'd1, 8'd1, 8'd0, 8'd1, 8'd0,
               8'd1, 8'd0, 8'd1, 8'd3, 8'd2, 8'd2, 8'd2, 8'd3,
               8'd3, 8'd3, 8'd4, 8'd4, 8'd4, 8'd0, 8'd0, 8'd5,
               8'd5, 8'd0, 8'd5, 8'd1, 8'd1, 8'd1, 8'd3, 8'd3,
               8'd3, 8'd7, 8'd6, 8'd6, 8'd6, 8'd5, 8'd5, 8'd7,
               8'd2, 8'd2, 8'd2, 8'd4, 8'd4, 8'd4, 8'd7, 8'd5,
               8'd5, 8'd5, 8'd4, 8'd5, 8'd4, 8'd6, 8'd6, 8'd6,
               8'd0, 8'd0, 8'd7, 8'd7, 8'd7, 8'd0, 8'd4, 8'd3,
               8'd3, 8'd3, 8'd2, 8'd2, 8'd2, 8'd1, 8'd1, 8'd0,
               8'd5, 8'd6, 8'd4, 8'd0, 8'd1, 8'd0, 8'd4, 8'd2,
               8'd2, 8'd2, 8'd4, 8'd4, 8'd4, 8'd6, 8'd6, 8'd6,
               8'd5, 8'd5, 8'd6, 8'd7, 8'd7, 8'd7, 8'd1, 8'd1,
               8'd1, 8'd3, 8'd3, 8'd3, 8'd4, 8'd4, 8'd5, 8'd5,
               8'd5, 8'd5, 8'd7, 8'd7, 8'd7, 8'd6, 8'd6, 8'd0,
               8'd0, 8'd0, 8'd3, 8'd3, 8'd6, 8'd6, 8'd6, 8'd0,
               8'd0, 8'd0, 8'd1, 8'd1, 8'd1, 8'd3, 8'd2, 8'd2,
               8'd7, 8'd7, 8'd7, 8'd1, 8'd5, 8'd4, 8'd0, 8'd3,
               8'd6, 8'd2, 8'd6, 8'd5, 8'd4, 8'd2, 8'd3, 8'd1,
               8'd0, 8'd7, 8'd5, 8'd6, 8'd4, 8'd0, 8'd3, 8'd4,
               8'd2, 8'd1, 8'd1, 8'd0, 8'd0, 8'd1, 8'd0, 8'd7,
               8'd7, 8'd7, 8'd7, 8'd2, 8'd2, 8'd2, 8'd5, 8'd6,
               8'd0, 8'd2, 8'd3, 8'd1, 8'd0, 8'd1, 8'd2, 8'd7,
               8'd7, 8'd7, 8'd7, 8'd6, 8'd5, 8'd4, 8'd5, 8'd5,
               8'd6, 8'd6, 8'd6, 8'd5, 8'd4, 8'd1, 8'd3, 8'd3,
               8'd3, 8'd4, 8'd4, 8'd4, 8'd3, 8'd2, 8'd0, 8'd1,
               8'd5, 8'd5, 8'd5, 8'd3, 8'd4, 8'd4, 8'd3, 8'd3,
               8'd2, 8'd2, 8'd2, 8'd7, 8'd7, 8'd7, 8'd6, 8'd6,
               8'd6, 8'd2, 8'd2, 8'd5, 8'd3, 8'd4, 8'd6, 8'd4,
               8'd3, 8'd5, 8'd6, 8'd1, 8'd0, 8'd1, 8'd1, 8'd1,
               8'd0, 8'd0, 8'd0, 8'd7, 8'd7, 8'd0, 8'd1, 8'd2
    }),
    .SCAN_COL               ({
               8'd15, 8'd08, 8'd08, 8'd15, 8'd15, 8'd23, 8'd08, 8'd23,
               8'd15, 8'd23, 8'd15, 8'd08, 8'd23, 8'd23, 8'd15, 8'd23,
               8'd08, 8'd08, 8'd22, 8'd30, 8'd23, 8'd23, 8'd15, 8'd15,
               8'd08, 8'd08, 8'd14, 8'd31, 8'd22, 8'd30, 8'd14, 8'd14,
               8'd22, 8'd30, 8'd30, 8'd22, 8'd14, 8'd30, 8'd14, 8'd22,
               8'd14, 8'd22, 8'd30, 8'd24, 8'd16, 8'd01, 8'd01, 8'd16,
               8'd24, 8'd17, 8'd02, 8'd25, 8'd17, 8'd02, 8'd25, 8'd25,
               8'd16, 8'd24, 8'd01, 8'd01, 8'd16, 8'd24, 8'd02, 8'd16,
               8'd24, 8'd01, 8'd25, 8'd17, 8'd02, 8'd16, 8'd24, 8'd01,
               8'd24, 8'd16, 8'd16, 8'd24, 8'd01, 8'd01, 8'd17, 8'd02,
               8'd25, 8'd17, 8'd02, 8'd25, 8'd17, 8'd02, 8'd25, 8'd02,
               8'd31, 8'd31, 8'd31, 8'd25, 8'd17, 8'd17, 8'd11, 8'd10,
               8'd18, 8'd03, 8'd03, 8'd10, 8'd18, 8'd18, 8'd03, 8'd10,
               8'd27, 8'd19, 8'd11, 8'd27, 8'd19, 8'd11, 8'd10, 8'd18,
               8'd03, 8'd03, 8'd10, 8'd18, 8'd27, 8'd19, 8'd11, 8'd10,
               8'd18, 8'd03, 8'd03, 8'd18, 8'd10, 8'd27, 8'd19, 8'd10,
               8'd18, 8'd03, 8'd27, 8'd19, 8'd22, 8'd30, 8'd14, 8'd29,
               8'd21, 8'd13, 8'd13, 8'd21, 8'd29, 8'd11, 8'd27, 8'd19,
               8'd00, 8'd31, 8'd09, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd09, 8'd09, 8'd09, 8'd09, 8'd09, 8'd09,
               8'd09, 8'd26, 8'd26, 8'd26, 8'd04, 8'd26, 8'd26, 8'd26,
               8'd11, 8'd27, 8'd19, 8'd19, 8'd27, 8'd11, 8'd11, 8'd28,
               8'd22, 8'd30, 8'd14, 8'd29, 8'd21, 8'd13, 8'd04, 8'd04,
               8'd31, 8'd04, 8'd04, 8'd04, 8'd04, 8'd26, 8'd26, 8'd04,
               8'd05, 8'd20, 8'd12, 8'd28, 8'd28, 8'd28, 8'd12, 8'd05,
               8'd05, 8'd20, 8'd12, 8'd20, 8'd05, 8'd07, 8'd13, 8'd29,
               8'd21, 8'd13, 8'd29, 8'd21, 8'd28, 8'd28, 8'd28, 8'd28,
               8'd21, 8'd29, 8'd13, 8'd05, 8'd20, 8'd12, 8'd20, 8'd12,
               8'd05, 8'd20, 8'd12, 8'd21, 8'd29, 8'd13, 8'd21, 8'd29,
               8'd13, 8'd06, 8'd07, 8'd06, 8'd06, 8'd06, 8'd06, 8'd07,
               8'd07, 8'd07, 8'd07, 8'd06, 8'd06, 8'd12, 8'd20, 8'd05,
               8'd05, 8'd20, 8'd12, 8'd07, 8'd06, 8'd07, 8'd31, 8'd31
    })
  )   PATTERN6_DESCAN   (
    .scanned_i      (scanned_i),

    .bpx_o          (bpx[6])
  );
  DEDBX   PATTERN6_DEDBX  (
    .bpx_i          (bpx[6]),

    .diff_o         (diff[6])
  );

  // Destransform =========================================================
  wire  [255:0]                     decomp_data;
  wire  [256*(NUM_TRANSFORMER)-1:0] detransformed_concat;
  wire  [255:0]                     detransformed   [NUM_FIRST_TRANSFORMER:NUM_LAST_TRANSFORMER];

  DETRANSFORMER   #(
    .ROOT_IDX               (8'd8),
    .LEVEL                  (8'd3),
    .LEN_LEVEL              ({
               8'd06, 8'd19, 8'd06, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00
    }),
    .LEVEL_START            ({
               8'd00, 8'd06, 8'd25, 8'd31, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00
    }),
    .TARGET_IDX             ({
               8'd04, 8'd07, 8'd09, 8'd16, 8'd20, 8'd28, 8'd00, 8'd02,
               8'd03, 8'd05, 8'd06, 8'd10, 8'd12, 8'd14, 8'd15, 8'd17,
               8'd18, 8'd19, 8'd21, 8'd22, 8'd24, 8'd26, 8'd29, 8'd30,
               8'd31, 8'd01, 8'd11, 8'd13, 8'd23, 8'd25, 8'd27, 8'd00
    }),
    .BASE_IDX               ({
               8'd28, 8'd00, 8'd16, 8'd04, 8'd08, 8'd04, 8'd16, 8'd08,
               8'd08, 8'd08, 8'd16, 8'd12, 8'd16, 8'd12, 8'd16, 8'd16,
               8'd08, 8'd16, 8'd04, 8'd20, 8'd08, 8'd20, 8'd16, 8'd24,
               8'd16, 8'd24, 8'd16, 8'd00, 8'd08, 8'd28, 8'd16, 8'd04
    }),
    .SHIFT_VAL              ({
                8'd0,  8'd0,  8'd3,  8'd0,  8'd0,  8'd0,  8'd3,  8'd0,
                8'd0,  8'd0,  8'd3,  8'd0,  8'd0,  8'd0,  8'd3,  8'd0,
                8'd0,  8'd0,  8'd3,  8'd0,  8'd0,  8'd0,  8'd3,  8'd0,
                8'd0,  8'd0,  8'd3,  8'd0,  8'd0,  8'd0,  8'd3,  8'd0
    })
  )   PATTERN2_DETRAN   (
    .diff_i             (diff[2]),

    .detransformed_o    (detransformed[2])
  );
  DETRANSFORMER   #(
    .ROOT_IDX               (8'd16),
    .LEVEL                  (8'd7),
    .LEN_LEVEL              ({
               8'd03, 8'd03, 8'd03, 8'd08, 8'd04, 8'd08, 8'd02, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00
    }),
    .LEVEL_START            ({
               8'd00, 8'd03, 8'd06, 8'd09, 8'd17, 8'd21, 8'd29, 8'd31,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00
    }),
    .TARGET_IDX             ({
               8'd00, 8'd14, 8'd18, 8'd12, 8'd15, 8'd20, 8'd03, 8'd10,
               8'd22, 8'd05, 8'd07, 8'd08, 8'd09, 8'd11, 8'd13, 8'd17,
               8'd24, 8'd01, 8'd06, 8'd19, 8'd26, 8'd04, 8'd21, 8'd23,
               8'd25, 8'd27, 8'd28, 8'd29, 8'd31, 8'd02, 8'd30, 8'd00
    }),
    .BASE_IDX               ({
               8'd16, 8'd17, 8'd04, 8'd15, 8'd06, 8'd03, 8'd08, 8'd03,
               8'd10, 8'd03, 8'd12, 8'd03, 8'd14, 8'd03, 8'd16, 8'd14,
               8'd16, 8'd03, 8'd16, 8'd17, 8'd18, 8'd19, 8'd20, 8'd19,
               8'd22, 8'd19, 8'd24, 8'd19, 8'd26, 8'd19, 8'd28, 8'd19
    }),
    .SHIFT_VAL              ({
                8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
                8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
                8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
                8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0
    })
  )   PATTERN3_DETRAN   (
    .diff_i             (diff[3]),

    .detransformed_o    (detransformed[3])
  );
  DETRANSFORMER   #(
    .ROOT_IDX               (8'd19),
    .LEVEL                  (8'd5),
    .LEN_LEVEL              ({
               8'd04, 8'd08, 8'd09, 8'd08, 8'd02, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00
    }),
    .LEVEL_START            ({
               8'd00, 8'd04, 8'd12, 8'd21, 8'd29, 8'd31, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00
    }),
    .TARGET_IDX             ({
               8'd15, 8'd16, 8'd17, 8'd23, 8'd08, 8'd09, 8'd11, 8'd12,
               8'd14, 8'd20, 8'd25, 8'd27, 8'd01, 8'd04, 8'd06, 8'd07,
               8'd10, 8'd21, 8'd22, 8'd24, 8'd31, 8'd00, 8'd02, 8'd03,
               8'd13, 8'd18, 8'd28, 8'd29, 8'd30, 8'd05, 8'd26, 8'd00
    }),
    .BASE_IDX               ({
               8'd04, 8'd09, 8'd10, 8'd07, 8'd08, 8'd13, 8'd14, 8'd11,
               8'd16, 8'd17, 8'd14, 8'd15, 8'd16, 8'd21, 8'd15, 8'd19,
               8'd19, 8'd19, 8'd10, 8'd19, 8'd16, 8'd25, 8'd14, 8'd19,
               8'd20, 8'd17, 8'd18, 8'd23, 8'd24, 8'd21, 8'd22, 8'd27
    }),
    .SHIFT_VAL              ({
                8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
                8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
                8'd7,  8'd7,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
                8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0
    })
  )   PATTERN4_DETRAN   (
    .diff_i             (diff[4]),

    .detransformed_o    (detransformed[4])
  );
  DETRANSFORMER   #(
    .ROOT_IDX               (8'd15),
    .LEVEL                  (8'd6),
    .LEN_LEVEL              ({
               8'd03, 8'd05, 8'd05, 8'd10, 8'd06, 8'd02, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00
    }),
    .LEVEL_START            ({
               8'd00, 8'd03, 8'd08, 8'd13, 8'd23, 8'd29, 8'd31, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00
    }),
    .TARGET_IDX             ({
               8'd07, 8'd12, 8'd23, 8'd01, 8'd05, 8'd19, 8'd21, 8'd31,
               8'd11, 8'd18, 8'd27, 8'd28, 8'd29, 8'd03, 8'd09, 8'd13,
               8'd14, 8'd17, 8'd20, 8'd22, 8'd24, 8'd25, 8'd26, 8'd02,
               8'd04, 8'd06, 8'd08, 8'd16, 8'd30, 8'd00, 8'd10, 8'd00
    }),
    .BASE_IDX               ({
               8'd04, 8'd07, 8'd03, 8'd11, 8'd20, 8'd07, 8'd14, 8'd15,
               8'd24, 8'd11, 8'd02, 8'd19, 8'd15, 8'd27, 8'd18, 8'd15,
               8'd24, 8'd27, 8'd19, 8'd07, 8'd28, 8'd23, 8'd18, 8'd15,
               8'd27, 8'd27, 8'd27, 8'd19, 8'd31, 8'd31, 8'd22, 8'd23
    }),
    .SHIFT_VAL              ({
                8'd0,  8'd1,  8'd0,  8'd0,  8'd0,  8'd1,  8'd0,  8'd0,
                8'd0,  8'd1,  8'd0,  8'd0,  8'd2,  8'd1,  8'd0,  8'd0,
                8'd0,  8'd1,  8'd0,  8'd0,  8'd0,  8'd1,  8'd0,  8'd0,
                8'd1,  8'd1,  8'd0,  8'd0,  8'd0,  8'd1,  8'd0,  8'd0
    })
  )   PATTERN5_DETRAN   (
    .diff_i             (diff[5]),

    .detransformed_o    (detransformed[5])
  );
  DETRANSFORMER   #(
    .ROOT_IDX               (8'd8),
    .LEVEL                  (8'd10),
    .LEN_LEVEL              ({
               8'd03, 8'd02, 8'd03, 8'd03, 8'd03, 8'd03, 8'd05, 8'd03,
               8'd03, 8'd03, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00
    }),
    .LEVEL_START            ({
               8'd00, 8'd03, 8'd05, 8'd08, 8'd11, 8'd14, 8'd17, 8'd22,
               8'd25, 8'd28, 8'd31, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00,
               8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00
    }),
    .TARGET_IDX             ({
               8'd00, 8'd09, 8'd16, 8'd24, 8'd25, 8'd17, 8'd26, 8'd31,
               8'd01, 8'd18, 8'd23, 8'd10, 8'd15, 8'd20, 8'd02, 8'd07,
               8'd12, 8'd03, 8'd04, 8'd05, 8'd06, 8'd28, 8'd13, 8'd14,
               8'd19, 8'd11, 8'd21, 8'd22, 8'd27, 8'd29, 8'd30, 8'd00
    }),
    .BASE_IDX               ({
               8'd08, 8'd17, 8'd10, 8'd02, 8'd07, 8'd07, 8'd07, 8'd15,
               8'd08, 8'd08, 8'd18, 8'd19, 8'd15, 8'd05, 8'd06, 8'd23,
               8'd08, 8'd25, 8'd26, 8'd03, 8'd23, 8'd13, 8'd14, 8'd31,
               8'd16, 8'd09, 8'd25, 8'd11, 8'd12, 8'd21, 8'd22, 8'd24
    }),
    .SHIFT_VAL              ({
                8'd0,  8'd0,  8'd0,  8'd0,  8'd1,  8'd1,  8'd1,  8'd0,
                8'd0,  8'd0,  8'd0,  8'd0,  8'd1,  8'd0,  8'd0,  8'd0,
                8'd0,  8'd0,  8'd0,  8'd0,  8'd1,  8'd0,  8'd0,  8'd0,
                8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd6
    })
  )   PATTERN6_DETRAN   (
    .diff_i             (diff[6]),

    .detransformed_o    (detransformed[6])
  );

  genvar i;
  generate
    for (i = NUM_FIRST_TRANSFORMER; i <= NUM_LAST_TRANSFORMER; i = i + 1) begin : detransformed_rename
      assign detransformed_concat[256*(NUM_TRANSFORMER)-256*(i-NUM_FIRST_TRANSFORMER)-1:256*(NUM_TRANSFORMER)-256*(i-NUM_FIRST_TRANSFORMER+1)] = detransformed[i];
    end
  endgenerate

  SEL_DETRANSFORMER #(
    .NUM_PATTERNS             (NUM_PATTERNS),
    .NUM_FIRST_TRANSFORMER    (NUM_FIRST_TRANSFORMER),
    .NUM_LAST_TRANSFORMER     (NUM_LAST_TRANSFORMER)
  )   SELECTOR    (
    .select_i           (select_i),
    .detransformed_i    (detransformed_concat),
    .data_i             (data_i),

    .data_o             (decomp_data)
  );
  
  // -------------------------------------------------

  D_FF  #(
    .BITWIDTH     (256)
  )   DECOMP_DFF  (
    .d_i          (decomp_data),
    .clk          (clk),
    .rst_n        (rst_n),

    .q_o          (data_o)
  );

  D_FF  #(
    .BITWIDTH     (1)
  )   EN4_DFF   (
    .d_i          (en_i),
    .clk          (clk),
    .rst_n        (rst_n),

    .q_o          (en_o)
  );

endmodule
