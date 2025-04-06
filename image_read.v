`include "parameter.v"

module image_read
#(
  parameter WIDTH = 768, 
  parameter HEIGHT = 512,
  parameter INFILE = "N5.hex", 
  parameter INFILE1 = "sky.hex",
  parameter START_UP_DELAY = 100, 
  parameter HSYNC_DELAY = 160,
  parameter VALUE = 1, 
  parameter THRESHOLD = 90, 
  parameter SIGN = 1
)
(
  input HCLK, 
  input HRESETn,
  output VSYNC,
  output reg HSYNC,
  output reg [7:0] DATA_R0,
  output reg [7:0] DATA_G0,
  output reg [7:0] DATA_B0,
  output reg [7:0] DATA_R1,
  output reg [7:0] DATA_G1,
  output reg [7:0] DATA_B1,
  output ctrl_done
);

parameter sizeOfWidth = 8;
parameter sizeOfLengthReal = 1179648; // 768 * 512 * 3 (for RGB)

localparam ST_IDLE = 2'b00, ST_VSYNC = 2'b01, ST_HSYNC = 2'b10, ST_DATA = 2'b11;

reg [1:0] cstate, nstate;
reg start;
reg HRESETn_d;
reg ctrl_vsync_run;
reg [8:0] ctrl_vsync_cnt;
reg ctrl_hsync_run;
reg [8:0] ctrl_hsync_cnt;
reg ctrl_data_run;
reg [7:0] total_memory [0:sizeOfLengthReal-1];
reg [7:0] total_memory1 [0:sizeOfLengthReal-1];
integer org_Y [0:WIDTH*HEIGHT-1];
integer org_Y1 [0:WIDTH*HEIGHT-1];
integer i, j;
reg [9:0] row;
reg [10:0] col;
reg [18:0] data_count;

wire [15:0] Y0_mul, Y1_mul;

// Instantiate the multiplier for luminance (Y) channel
mul mul_Y0 (
    .a({8'b0, org_Y[WIDTH*row+col][7:0]}), 
    .b({8'b0, org_Y1[WIDTH*row+col][7:0]}), 
    .p(Y0_mul)
);

mul mul_Y1 (
    .a({8'b0, org_Y[WIDTH*row+col+1][7:0]}), 
    .b({8'b0, org_Y1[WIDTH*row+col+1][7:0]}), 
    .p(Y1_mul)
);

// Read input images into memory
initial begin
  $readmemh(INFILE, total_memory, 0, sizeOfLengthReal-1);
  $readmemh(INFILE1, total_memory1, 0, sizeOfLengthReal-1);
end

// Load image data into org_Y and org_Y1 arrays
always@(start) begin
  if(start == 1'b1) begin
    for(i = 0; i < HEIGHT; i = i + 1) begin
      for(j = 0; j < WIDTH; j = j + 1) begin
        org_Y[WIDTH*i+j] = total_memory[WIDTH*(HEIGHT-i-1)+j];
        org_Y1[WIDTH*i+j] = total_memory1[WIDTH*(HEIGHT-i-1)+j];
      end
    end
  end
end

// Start signal generation
always@(posedge HCLK, negedge HRESETn) begin
  if(!HRESETn) begin
    start <= 0;
    HRESETn_d <= 0;
  end else begin
    HRESETn_d <= HRESETn;
    if(HRESETn == 1'b1 && HRESETn_d == 1'b0)
      start <= 1'b1;
    else
      start <= 1'b0;
  end
end

// State machine for controlling image processing
always@(posedge HCLK, negedge HRESETn) begin
  if(~HRESETn) begin
    cstate <= ST_IDLE;
  end else begin
    cstate <= nstate;
  end
end

// Next state logic
always @(*) begin
  case(cstate)
    ST_IDLE: nstate = start ? ST_VSYNC : ST_IDLE;
    ST_VSYNC: nstate = (ctrl_vsync_cnt == START_UP_DELAY) ? ST_HSYNC : ST_VSYNC;
    ST_HSYNC: nstate = (ctrl_hsync_cnt == HSYNC_DELAY) ? ST_DATA : ST_HSYNC;
    ST_DATA: nstate = ctrl_done ? ST_IDLE : ((col == WIDTH-2) ? ST_HSYNC : ST_DATA);
  endcase
end

// Control signal generation
always @(*) begin
  ctrl_vsync_run = 0;
  ctrl_hsync_run = 0;
  ctrl_data_run  = 0;
  case(cstate)
    ST_VSYNC: ctrl_vsync_run = 1;
    ST_HSYNC: ctrl_hsync_run = 1;
    ST_DATA:  ctrl_data_run  = 1;
  endcase
end

// VSYNC and HSYNC counters
always@(posedge HCLK, negedge HRESETn) begin
  if(~HRESETn) begin
    ctrl_vsync_cnt <= 0;
    ctrl_hsync_cnt <= 0;
  end else begin
    if(ctrl_vsync_run) ctrl_vsync_cnt <= ctrl_vsync_cnt + 1;
    else ctrl_vsync_cnt <= 0;
    
    if(ctrl_hsync_run) ctrl_hsync_cnt <= ctrl_hsync_cnt + 1;
    else ctrl_hsync_cnt <= 0;
  end
end

// Row and column counters
always@(posedge HCLK, negedge HRESETn) begin
  if(~HRESETn) begin
    row <= 0;
    col <= 0;
  end else if(ctrl_data_run) begin
    if(col == WIDTH-2) begin
      row <= row + 1; // Move to the next row
      col <= 0;       // Reset column counter
    end else begin
      col <= col + 2; // Process two pixels per clock cycle
    end
  end
end

// Data counter for tracking progress
always@(posedge HCLK, negedge HRESETn) begin
  if(~HRESETn) begin
    data_count <= 0;
  end else if(ctrl_data_run) begin
    data_count <= data_count + 1;
  end
end

// VSYNC and control done signals
assign VSYNC = ctrl_vsync_run;
assign ctrl_done = (data_count == (WIDTH * HEIGHT / 2 - 1)) ? 1'b1 : 1'b0;

// Output pixel data
always @(*) begin
  HSYNC   = 1'b0;
  DATA_R0 = 0;
  DATA_G0 = 0;
  DATA_B0 = 0;
  DATA_R1 = 0;
  DATA_G1 = 0;
  DATA_B1 = 0;

  if(ctrl_data_run) begin
    HSYNC = 1'b1;
    if(SIGN == 1) begin
      // Y0
      DATA_R0 = (Y0_mul >> 8) > 255 ? 255 : (Y0_mul >> 8);
      DATA_G0 = DATA_R0;
      DATA_B0 = DATA_R0;
      // Y1
      DATA_R1 = (Y1_mul >> 8) > 255 ? 255 : (Y1_mul >> 8);
      DATA_G1 = DATA_R1;
      DATA_B1 = DATA_R1;
    end else begin
      // Y0
      DATA_R0 = (org_Y[WIDTH*row+col] > VALUE) ? (org_Y[WIDTH*row+col] - VALUE) : 0;
      DATA_G0 = DATA_R0;
      DATA_B0 = DATA_R0;
      // Y1
      DATA_R1 = (org_Y[WIDTH*row+col+1] > VALUE) ? (org_Y[WIDTH*row+col+1] - VALUE) : 0;
      DATA_G1 = DATA_R1;
      DATA_B1 = DATA_R1;
    end
  end
end

endmodule