package tb_pkg;

  // ---- 复位应用工具任务 ----
  static automatic task apply_reset(input logic clk, ref logic rst_n, int n = 5);
    rst_n = 0;
    repeat(n) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
  endtask

  // ---- 操作类型（用于未来ALU扩展） ----
  typedef enum logic [2:0] {
    OP_MUL = 0,
    OP_ADD = 1,
    OP_SUB = 2,
    OP_SQRT = 3,  // 未来使用
    OP_DIV = 4    // 未来使用
  } op_e;

  // ---- 事务类 ----
  class txn;
    rand bit [15:0] a, b;  // 为未来可扩展性而加宽
    rand op_e op;          // 操作类型
    bit [31:0] result;     // 结果（为未来使用而加宽）
    bit [31:0] expected;   // 期望结果

    // 不同操作的约束
    constraint c_mul_data {
      if (op == OP_MUL) {
        a inside {[0:255]};  // 当前乘法器使用8位
        b inside {[0:255]};
      }
      // 稍后为其他操作添加约束
    }

    constraint c_op_dist {
      op dist {
        OP_MUL := 8,  // 当前专注于乘法
        OP_ADD := 1,  // 未来使用
        OP_SUB := 1   // 未来使用
      };
    }

    // 通用计算函数（可扩展）
    static function automatic bit [31:0] calculate(bit [15:0] a, b, op_e op);
      case (op)
        OP_MUL: return a * b;
        OP_ADD: return a + b;      // 未来使用
        OP_SUB: return a - b;      // 未来使用
        // OP_SQRT: return sqrt(a); // 未来实现
        default: return 32'hDEAD_BEEF;
      endcase
    endfunction

    function void post_randomize();
      expected = calculate(a[7:0], b[7:0], op);  // 当前DUT使用8位
    endfunction

    function string to_string();
      return $sformatf("op=%s, a=%0d, b=%0d, expected=%0d, actual=%0d",
                       op.name(), a, b, expected, result);
    endfunction
  endclass

  // ---- 日志宏 ----
  `define INFO(fmt, args...)  $display("[%0t][INFO ] "  fmt, $time, ##args)
  `define ERROR(fmt, args...) $display("[%0t][ERROR] " fmt, $time, ##args)
  `define DEBUG(fmt, args...) $display("[%0t][DEBUG] " fmt, $time, ##args)

  // ---- 驱动类 ----
  class driver;
    virtual dut_if.driver_mp vif;
    mailbox #(txn) tx_mb;
    mailbox #(txn) exp_mb;

    function new(virtual dut_if.driver_mp vif,
                 mailbox #(txn) tx_mb,
                 mailbox #(txn) exp_mb);
      this.vif = vif;
      this.tx_mb = tx_mb;
      this.exp_mb = exp_mb;
    endfunction

    task run();
      txn t;

      // 初始化信号
      vif.cb_driver.a <= '0;
      vif.cb_driver.b <= '0;
      // vif.cb_driver.op <= OP_MUL;  // 用于未来ALU使用

      forever begin
        tx_mb.get(t);

        @(vif.cb_driver);
        vif.cb_driver.a <= t.a[7:0];  // 当前DUT使用8位
        vif.cb_driver.b <= t.b[7:0];
        // vif.cb_driver.op <= t.op;   // 用于未来ALU使用

        exp_mb.put(t);
        `DEBUG("驱动: %s", t.to_string());
      end
    endtask
  endclass

  // ---- 监视器类 ----
  class monitor;
    virtual dut_if.monitor_mp vif;
    mailbox #(txn) obs_mb;

    // 覆盖率模型（可为不同操作扩展）
    covergroup cg_operations @(vif.cb_monitor);
      option.per_instance = 1;

      // 输入覆盖率
      a_cp: coverpoint vif.cb_monitor.a {
        bins zero     = {8'h00};
        bins max      = {8'hFF};
        bins low      = {[8'h00:8'h0F]};
        bins mid_low  = {[8'h10:8'h7F]};
        bins mid_high = {[8'h80:8'hEF]};
        bins high     = {[8'hF0:8'hFE]};
      }

      b_cp: coverpoint vif.cb_monitor.b {
        bins zero     = {8'h00};
        bins max      = {8'hFF};
        bins low      = {[8'h00:8'h0F]};
        bins mid_low  = {[8'h10:8'h7F]};
        bins mid_high = {[8'h80:8'hEF]};
        bins high     = {[8'hF0:8'hFE]};
      }

      // 结果覆盖率
      out_cp: coverpoint vif.cb_monitor.out {
        bins zero     = {16'h0000};
        bins low      = {[16'h0001:16'h00FF]};
        bins mid      = {[16'h0100:16'hFE00]};
        bins high     = {[16'hFE01:16'hFFFE]};
        bins max      = {16'hFFFF};
      }

      // 交叉覆盖率
      a_b_cross: cross a_cp, b_cp;

      // 未来：操作特定覆盖率
      /*
      op_cp: coverpoint vif.cb_monitor.op {
        bins mul  = {OP_MUL};
        bins add  = {OP_ADD};
        bins sub  = {OP_SUB};
        bins sqrt = {OP_SQRT};
      }
      op_cross: cross a_cp, b_cp, op_cp;
      */
    endgroup

    function new(virtual dut_if.monitor_mp vif, mailbox #(txn) obs_mb);
      this.vif = vif;
      this.obs_mb = obs_mb;
      cg_operations = new();
    endfunction

    task run();
      txn obs_txn;

      forever begin
        @(vif.cb_monitor);

        obs_txn = new();
        obs_txn.a = vif.cb_monitor.a;
        obs_txn.b = vif.cb_monitor.b;
        obs_txn.op = OP_MUL;  // 当前操作
        obs_txn.result = vif.cb_monitor.out;

        obs_mb.put(obs_txn);
        `DEBUG("观察到: %s", obs_txn.to_string());
      end
    endtask
  endclass

  // ---- 记分板类 ----
  class scoreboard;
    mailbox #(txn) exp_mb;
    mailbox #(txn) obs_mb;

    int pass_count = 0;
    int fail_count = 0;
    int error_count = 0;

    function new(mailbox #(txn) exp_mb, mailbox #(txn) obs_mb);
      this.exp_mb = exp_mb;
      this.obs_mb = obs_mb;
    endfunction

    task run();
      txn exp_txn, obs_txn;

      forever begin
        fork
          exp_mb.get(exp_txn);
          obs_mb.get(obs_txn);
        join

        // 考虑流水线延迟（当前DUT为2个周期）
        if (exp_txn.expected === obs_txn.result) begin
          pass_count++;
          `INFO("通过: %s", obs_txn.to_string());
        end else begin
          fail_count++;
          `ERROR("失败: 期望值=%0d, 实际值=%0d, 输入: a=%0d, b=%0d",
                 exp_txn.expected, obs_txn.result, obs_txn.a, obs_txn.b);
        end
      end
    endtask

    function void report();
      real pass_rate = (pass_count * 100.0) / (pass_count + fail_count);
      `INFO("=== 最终报告 ===");
      `INFO("通过: %0d, 失败: %0d, 错误: %0d", pass_count, fail_count, error_count);
      `INFO("通过率: %.2f%%", pass_rate);
      if (fail_count == 0) begin
        `INFO("*** 测试通过 ***");
      end else begin
        `ERROR("*** 测试失败 ***");
      end
    endfunction
  endclass

  // ---- 环境类 ----
  class env;
    virtual dut_if vif;

    mailbox #(txn) tx_mb;
    mailbox #(txn) exp_mb;
    mailbox #(txn) obs_mb;

    driver m_driver;
    monitor m_monitor;
    scoreboard m_scoreboard;

    function new(virtual dut_if vif);
      this.vif = vif;
      tx_mb = new();
      exp_mb = new();
      obs_mb = new();

      m_driver = new(vif.driver_mp, tx_mb, exp_mb);
      m_monitor = new(vif.monitor_mp, obs_mb);
      m_scoreboard = new(exp_mb, obs_mb);
    endfunction

    task run_test();
      fork
        m_driver.run();
        m_monitor.run();
        m_scoreboard.run();
      join_none
    endtask

    task generate_stimulus(int n, int seed = 1);
      txn t;

      void'($urandom(seed));

      for (int i = 0; i < n; i++) begin
        t = new();
        assert(t.randomize()) else `ERROR("随机化失败");
        tx_mb.put(t);

        if (i % 100 == 0) `INFO("已生成 %0d/%0d 个事务", i, n);
      end

      `INFO("生成完成: %0d 个事务", n);
    endtask

    // 未来：为不同操作类型添加测试序列
    /*
    task run_mul_test(int n);
      // 专注的乘法测试
    endtask

    task run_alu_test(int n);
      // 扩展时的完整ALU测试
    endtask

    task run_cpu_test(string program);
      // 使用指令序列进行CPU测试
    endtask
    */
  endclass

endpackage

// ---- 接口定义 ----
interface dut_if #(
  parameter int DATA_WIDTH = 8,
  parameter int RESULT_WIDTH = 16
)(
  input logic clk,
  input logic rst_n
);

  logic [DATA_WIDTH-1:0] a, b;
  logic [RESULT_WIDTH-1:0] out;

  // 未来：添加操作和握手信号
  /*
  logic [2:0] op;
  logic valid_in, ready_in;
  logic valid_out, ready_out;
  */

  // 驱动时钟块
  clocking cb_driver @(posedge clk);
    output a, b;
    // output op, valid_in;  // 未来使用
    // input ready_in;       // 未来使用
  endclocking

  // 监视器时钟块
  clocking cb_monitor @(posedge clk);
    input a, b, out;
    // input op, valid_in, ready_in;   // 未来使用
    // input valid_out, ready_out;     // 未来使用
  endclocking

  // 模式端口
  modport driver_mp (
    clocking cb_driver,
    input clk, rst_n
  );

  modport monitor_mp (
    clocking cb_monitor,
    input clk, rst_n
  );

  // SVA属性（用于协议检查）
  /*
  // 复位行为
  property p_reset_behavior;
    @(posedge clk) !rst_n |-> ##1 (out == 0);
  endproperty
  a_reset: assert property(p_reset_behavior);

  // 流水线时序（用于未来带握手协议的使用）
  property p_valid_stable;
    @(posedge clk) disable iff (!rst_n)
      valid_in && !ready_in |-> ##1 ($stable({valid_in, a, b, op}));
  endproperty
  a_valid_stable: assert property(p_valid_stable);
  */

endinterface

// ---- 测试平台顶层模块 ----
`timescale 1ns / 1ps
module tb_top;

  import tb_pkg::*;

  // 时钟和复位
  localparam real CLK_PERIOD = 10; // 100MHz
  logic clk = 0, rst_n;

  always #(CLK_PERIOD/2) clk = ~clk;

  // 接口实例
  dut_if #(.DATA_WIDTH(8), .RESULT_WIDTH(16)) dut_if_inst(.clk(clk), .rst_n(rst_n));

  // DUT实例 - 连接到您的 Top_multiplier
  Top_multiplier dut (
    .clk(clk),
    .rst_n(rst_n),
    .A_in(dut_if_inst.a),
    .B_in(dut_if_inst.b),
    .out(dut_if_inst.out)
  );

  // 测试参数
  int NUM_CASES = 1000;
  int SEED = 32'hCAFE_BABE;
  int TIMEOUT_CYCLES = 50000;

  // 环境实例
  env test_env;

  initial begin
    // 解析命令行参数
    void'($value$plusargs("NUM_CASES=%d", NUM_CASES));
    void'($value$plusargs("SEED=%d", SEED));
    void'($value$plusargs("TIMEOUT_CYCLES=%d", TIMEOUT_CYCLES));

    `INFO("开始测试，参数: NUM_CASES=%0d, SEED=0x%0h", NUM_CASES, SEED);

    // 创建环境
    test_env = new(dut_if_inst);

    // 应用复位
    apply_reset(clk, rst_n, 5);

    // 启动测试环境
    test_env.run_test();



    // 生成激励并运行测试
    fork
      begin
        // 等待复位完成
        wait(rst_n);
        repeat(5) @(posedge clk);

        // 生成测试用例
        test_env.generate_stimulus(NUM_CASES, SEED);

        // 等待所有事务完成（考虑流水线）
        repeat(NUM_CASES + 10) @(posedge clk);

        `INFO("测试正常完成");
      end

      begin: watchdog
        repeat(TIMEOUT_CYCLES) @(posedge clk);
        `ERROR("测试在 %0d 个周期后超时！", TIMEOUT_CYCLES);
      end   
    join_any

    disable fork;

    // 最终报告并结束
    test_env.m_scoreboard.report();
    $finish;
  end

  // 可选：导出波形文件
  initial begin
    if ($test$plusargs("DUMP_VCD")) begin
      $dumpfile("tb_multiplier.vcd");
      $dumpvars(0, tb_top);
    end
  end

endmodule