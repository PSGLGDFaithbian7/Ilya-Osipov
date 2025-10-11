// testbench/uvm_tb_top.sv
`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*;
import uvm_tb_pkg::*;

// Interface definition
interface dut_if #(
  parameter int DATA_WIDTH   = 8,
  parameter int RESULT_WIDTH = 16
)(
  input logic clk,
  input logic rst_n
);

  logic [DATA_WIDTH-1:0]   a, b;
  logic [RESULT_WIDTH-1:0] out;
  
  // 用于延迟检测的特殊信号
  logic detection_mode;
  int cycle_counter;

  clocking cb_driver @(posedge clk);
    default input #1 output #1;
    output a, b;
    input out;
  endclocking

  clocking cb_monitor @(posedge clk);
    default input #1 output #1;
    input a, b, out;
  endclocking

  modport driver_mp  (clocking cb_driver,  input clk, rst_n);
  modport monitor_mp (clocking cb_monitor, input clk, rst_n);
  
  // 周期计数器 - 用于延迟检测
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      cycle_counter <= 0;
    else
      cycle_counter <= cycle_counter + 1;
  end

endinterface

// Top module
module uvm_tb_top;

  logic clk = 0;
  logic rst_n;

  always #5 clk = ~clk;

  dut_if #(.DATA_WIDTH(8), .RESULT_WIDTH(16))
         dut_if_inst (.clk(clk), .rst_n(rst_n));

  // DUT instantiation - 你的乘法器
  Top_multiplier dut (
    .clk   (clk),
    .rst_n (rst_n),
    .A_in  (dut_if_inst.a),
    .B_in  (dut_if_inst.b),
    .out   (dut_if_inst.out)
  );

  initial begin 
    rst_n = 0; 
    #50 
    rst_n = 1; 
    `uvm_info("TB_TOP", "Reset released", UVM_LOW)
  end

  initial begin
    uvm_config_db#(virtual dut_if)::set(null, "*", "vif", dut_if_inst);
    
    // 可配置的超时
    uvm_config_db#(int)::set(null, "*", "timeout_cycles", 50000);
    
    // 如果知道延迟，可以在这里设置（可选）
    // uvm_config_db#(int)::set(null, "*", "pipeline_latency", 4);

    // FSDB dumping
    $fsdbDumpfile("arithmetic_unit.fsdb");
    $fsdbDumpvars(0, uvm_tb_top);
    `uvm_info("TB_TOP", "FSDB dumping enabled: arithmetic_unit.fsdb", UVM_LOW)

    run_test();
  end

  initial begin
    int timeout_cycles = 50000;
    void'($value$plusargs("TIMEOUT=%d", timeout_cycles));
    repeat(timeout_cycles) @(posedge clk);
    `uvm_fatal("TIMEOUT", $sformatf("Simulation timed out after %0d cycles", timeout_cycles))
  end

endmodule