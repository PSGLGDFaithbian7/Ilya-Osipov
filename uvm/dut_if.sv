interface dut_if #(
  parameter int DATA_WIDTH   = 8,
  parameter int RESULT_WIDTH = 16,
  parameter bit HAS_HANDSHAKE = 0  // Parameter to enable/disable
)(
  input logic clk,
  input logic rst_n
);

  // Core signals
  logic [DATA_WIDTH-1:0]   a, b;
  logic [RESULT_WIDTH-1:0] out;

  // Optional handshake signals
  logic valid, ready, done;

  // Driver clocking block
  clocking cb_driver @(posedge clk);
    output a, b;
    if (HAS_HANDSHAKE) output valid;
    if (HAS_HANDSHAKE) input ready, done;
    input out;
  endclocking

  // Monitor clocking block  
  clocking cb_monitor @(posedge clk);
    input a, b, out;
    if (HAS_HANDSHAKE) input valid, ready, done;
  endclocking

  // 各种 modport
  modport driver_mp  (clocking cb_driver,  input clk, rst_n);
  modport monitor_mp (clocking cb_monitor, input clk, rst_n);
  modport dut_mp     (input a, b, clk, rst_n, output out);
  modport dut_hs_mp  (input a, b, valid, clk, rst_n,
                      output out, ready, done);

endinterface

/* dut_if #(.DATA_WIDTH(8), .RESULT_WIDTH(16), .HAS_HANDSHAKE(0)) 
       dut_if_inst(.clk(clk), .rst_n(rst_n));  */