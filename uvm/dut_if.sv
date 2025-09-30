//------------------------------------------
// 仅声明信号 + 时钟块，不含任何断言
//------------------------------------------
interface dut_if #(
  parameter int DATA_WIDTH   = 8,
  parameter int RESULT_WIDTH = 16
)(
  input logic clk,
  input logic rst_n
);

  // 核心数据
  logic [DATA_WIDTH-1:0]   a, b;
  logic [RESULT_WIDTH-1:0] out;

  // 可选握手
  logic valid, ready, done;

  // 驱动 / 采样时钟块
  clocking cb_driver @(posedge clk);
    output a, b, valid;
    input  ready, done, out;
  endclocking

  clocking cb_monitor @(posedge clk);
    input a, b, out, valid, ready, done;
  endclocking

  // 各种 modport
  modport driver_mp  (clocking cb_driver,  input clk, rst_n);
  modport monitor_mp (clocking cb_monitor, input clk, rst_n);
  modport dut_mp     (input a, b, clk, rst_n, output out);
  modport dut_hs_mp  (input a, b, valid, clk, rst_n,
                      output out, ready, done);

endinterface