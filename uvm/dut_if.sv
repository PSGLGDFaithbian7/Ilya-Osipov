// testbench/dut_if.sv
interface dut_if #(
  parameter int DATA_WIDTH   = 8,
  parameter int RESULT_WIDTH = 16
)(
  input logic clk,
  input logic rst_n
);

  // Core signals
  logic [DATA_WIDTH-1:0]   a, b;
  logic [RESULT_WIDTH-1:0] out;
  
  // 简单的握手信号（可选）
  logic valid_in;
  logic valid_out;
  
  // 用于调试的信号
  int cycle_counter;

  // Driver clocking block - 简化版
  clocking cb_driver @(posedge clk);
    default input #1 output #1;
    output a, b, valid_in;
    input out, valid_out;
  endclocking

  // Monitor clocking block
  clocking cb_monitor @(posedge clk);
    default input #1 output #1;
    input a, b, out, valid_in, valid_out;
  endclocking

  // Modports
  modport driver_mp  (clocking cb_driver,  input clk, rst_n);
  modport monitor_mp (clocking cb_monitor, input clk, rst_n);
  modport dut_mp     (input a, b, clk, rst_n, output out);

  // 周期计数器
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      cycle_counter <= 0;
    else
      cycle_counter <= cycle_counter + 1;
  end

endinterface