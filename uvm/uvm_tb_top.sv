//=========================================================
//  Top-level testbench
//  使用新版 dut_if，但 top 层不连握手信号
//=========================================================

`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*;
import uvm_tb_pkg::*;

// ---------- 接口（完整版，含握手但 top 不连） ----------
interface dut_if #(
  parameter int DATA_WIDTH   = 8,
  parameter int RESULT_WIDTH = 16
)(
  input logic clk,
  input logic rst_n
);

  logic [DATA_WIDTH-1:0]   a, b;
  logic [RESULT_WIDTH-1:0] out;
  logic valid, ready, done;

  clocking cb_driver @(posedge clk);
    output a, b, valid;
    input  ready, done, out;
  endclocking

  clocking cb_monitor @(posedge clk);
    input a, b, out, valid, ready, done;
  endclocking

  modport driver_mp  (clocking cb_driver,  input clk, rst_n);
  modport monitor_mp (clocking cb_monitor, input clk, rst_n);
  modport dut_mp     (input a, b, clk, rst_n, output out);

endinterface

// ---------- Checker ----------
checker dut_if_checker (
  input logic        clk,
  input logic        rst_n,
  input logic [7:0]  a,
  input logic [7:0]  b,
  input logic [15:0] out
);
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  property p_reset_behavior;
    @(posedge clk) !rst_n |=> (out == 0);
  endproperty
  assert property(p_reset_behavior) else
    `uvm_error("DUT_IF_CHECKER", "复位断言失败：复位后 out != 0")

  property p_stable_out;
    @(posedge clk) disable iff (!rst_n)
      $stable({a,b}) |-> ##[1:3] $stable(out);
  endproperty
  assert property(p_stable_out) else
    `uvm_error("DUT_IF_CHECKER", "稳定性断言失败：输入不变时输出跳变")

endchecker

// ---------- Top ----------
module uvm_tb_top;

  logic clk = 0;
  logic rst_n;

  always #5 clk = ~clk;

  dut_if #(.DATA_WIDTH(8), .RESULT_WIDTH(16))
         dut_if_inst (.clk(clk), .rst_n(rst_n));

  // DUT 仅使用 dut_mp（无握手）
  Top_multiplier dut (
    .clk   (clk),
    .rst_n (rst_n),
    .A_in  (dut_if_inst.a),
    .B_in  (dut_if_inst.b),
    .out   (dut_if_inst.out)
  );

  // Checker 仅监听数据
  dut_if_checker dut_if_checker_inst (
    .clk   (clk),
    .rst_n (rst_n),
    .a     (dut_if_inst.a),
    .b     (dut_if_inst.b),
    .out   (dut_if_inst.out)
  );

  initial begin rst_n = 0; #50 rst_n = 1; end

  initial begin
    uvm_config_db#(virtual dut_if)::set(null, "*", "vif", dut_if_inst);
    uvm_config_db#(int)::set(null, "*", "timeout_cycles", 50000);

    if ($test$plusargs("DUMP_WAVES")) begin
      $dumpfile("uvm_multiplier.vcd");
      $dumpvars(0, uvm_tb_top);
      `uvm_info("WAVES", "VCD dumping enabled", UVM_LOW)
    end

    run_test();
  end

  initial begin
    int timeout_cycles = 50000;
    void'($value$plusargs("TIMEOUT=%d", timeout_cycles));
    repeat(timeout_cycles) @(posedge clk);
    `uvm_fatal("TIMEOUT", $sformatf("Simulation timed out after %0d cycles", timeout_cycles))
  end

endmodule