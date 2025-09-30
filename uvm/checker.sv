
checker dut_if_checker (
  input logic              clk,
  input logic              rst_n,
  input logic [7:0]        a,
  input logic [7:0]        b,
  input logic [15:0]       out
);

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // 复位后 out 必须为 0
  property p_reset_behavior;
    @(posedge clk) !rst_n |=> (out == 0);
  endproperty
  assert property(p_reset_behavior) else
    `uvm_error("DUT_IF_CHECKER", "复位断言失败：复位后 out != 0")

  // 输入稳定 => 输出 1~3 周期内也稳定
  property p_stable_out;
    @(posedge clk) disable iff (!rst_n)
      $stable({a,b}) |-> ##[1:3] $stable(out);
  endproperty
  assert property(p_stable_out) else
    `uvm_error("DUT_IF_CHECKER", "稳定性断言失败：输入不变时输出跳变")

endchecker