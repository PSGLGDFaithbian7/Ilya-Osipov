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
    OP_SQRT = 3,
    OP_DIV = 4
  } op_e;

  // ---- 事务类 ----
  class txn;
    rand bit [15:0] a, b;
    rand op_e op;
    bit [31:0] result;
    bit [31:0] expected;

    constraint c_mul_data {
      if (op == OP_MUL) {
        a inside {[0:255]};
        b inside {[0:255]};
      }
    }

    constraint c_op_dist {
      op dist {
        OP_MUL := 8,
        OP_ADD := 1,
        OP_SUB := 1
      };
    }

    static function automatic bit [31:0] calculate(bit [15:0] a, b, op_e op);
      case (op)
        OP_MUL: return a * b;
        OP_ADD: return a + b;
        OP_SUB: return a - b;
        default: return 32'hDEAD_BEEF;
      endcase
    endfunction

    function void post_randomize();
      expected = calculate(a[7:0], b[7:0], op);
    endfunction

    function string to_string();
      return $sformatf("op=%s, a=%0d, b=%0d, expected=%0d, actual=%0d",
                       op.name(), a, b, expected, result);
    endfunction
  endclass

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

      vif.cb_driver.a <= '0;
      vif.cb_driver.b <= '0;

      forever begin
        tx_mb.get(t);

        @(vif.cb_driver);
        vif.cb_driver.a <= t.a[7:0];
        vif.cb_driver.b <= t.b[7:0];

        exp_mb.put(t);
        `DEBUG("驱动: %s", t.to_string());
      end
    endtask
  endclass

  // ---- 监视器类 ----（修改）
  class monitor;
    virtual dut_if.monitor_mp vif;
    mailbox #(txn) obs_mb;

    covergroup cg_operations @(vif.cb_monitor);
      option.per_instance = 1;

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

      out_cp: coverpoint vif.cb_monitor.out {
        bins zero     = {16'h0000};
        bins low      = {[16'h0001:16'h00FF]};
        bins mid      = {[16'h0100:16'hFE00]};
        bins high     = {[16'hFE01:16'hFFFE]};
        bins max      = {16'hFFFF};
      }

      a_b_cross: cross a_cp, b_cp;
    endgroup

    function new(virtual dut_if.monitor_mp vif, mailbox #(txn) obs_mb);
      this.vif = vif;
      this.obs_mb = obs_mb;
      cg_operations = new();
    endfunction

    task run();
      txn obs_txn;
      int skip_count = 0;

      // **修改：等待复位完成**
      @(posedge vif.rst_n);

      forever begin
        @(vif.cb_monitor);
        
        // **修改：跳过初始周期**
        if (skip_count < 5) begin
          skip_count++;
          continue;
        end

        obs_txn = new();
        obs_txn.a = vif.cb_monitor.a;
        obs_txn.b = vif.cb_monitor.b;
        obs_txn.op = OP_MUL;
        obs_txn.result = vif.cb_monitor.out;

        obs_mb.put(obs_txn);
        `DEBUG("观察到: result=%0d", obs_txn.result);
      end
    endtask
  endclass

  // ---- 记分板类 ----（修改）
  class scoreboard;
    mailbox #(txn) exp_mb;
    mailbox #(txn) obs_mb;
    
    // **新增：延迟队列**
    txn exp_queue[$];
    int pipeline_delay = 4;

    int pass_count = 0;
    int fail_count = 0;
    int error_count = 0;

    function new(mailbox #(txn) exp_mb, mailbox #(txn) obs_mb);
      this.exp_mb = exp_mb;
      this.obs_mb = obs_mb;
      void'($value$plusargs("PIPELINE_DELAY=%d", pipeline_delay));
    endfunction

    task run();
      txn exp_txn, obs_txn;

      forever begin
        fork
          begin
            exp_mb.get(exp_txn);
            exp_queue.push_back(exp_txn);  // **修改：加入队列**
          end
          obs_mb.get(obs_txn);
        join

        // **修改：考虑流水线延迟**
        if (exp_queue.size() > pipeline_delay) begin
          exp_txn = exp_queue.pop_front();
          
          if (exp_txn.expected === obs_txn.result) begin
            pass_count++;
            `INFO("通过 [%0d]: a=%0d, b=%0d, result=%0d", 
                  pass_count, exp_txn.a, exp_txn.b, obs_txn.result);
          end else begin
            fail_count++;
            `ERROR("失败: 期望=%0d, 实际=%0d (a=%0d, b=%0d)",
                   exp_txn.expected, obs_txn.result, exp_txn.a, exp_txn.b);
          end
        end
      end
    endtask

    function void report();
      real pass_rate;
      if (pass_count + fail_count > 0)
        pass_rate = (pass_count * 100.0) / (pass_count + fail_count);
      else
        pass_rate = 0.0;
        
      `INFO("=====================================");
      `INFO("=== 最终报告 ===");
      `INFO("=====================================");
      `INFO("流水线延迟: %0d 周期", pipeline_delay);
      `INFO("通过: %0d, 失败: %0d", pass_count, fail_count);
      `INFO("通过率: %.2f%%", pass_rate);
      `INFO("=====================================");
      if (fail_count == 0 && pass_count > 0) begin
        `INFO("*** 测试通过 ***");
      end else begin
        `ERROR("*** 测试失败 ***");
      end
    endfunction
  endclass

  // ---- 环境类 ----（不变）
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
  endclass

endpackage