// uvm/uvm_tb_pkg.sv
`include "uvm_macros.svh"
import uvm_pkg::*;

package uvm_tb_pkg;

  // ============================================================================
  // Transaction Class
  // ============================================================================
  class mul_transaction extends uvm_sequence_item;
    rand bit [7:0] a, b;
    bit [15:0] result;
    bit [15:0] expected;
    int transaction_id;
    int input_cycle;
    int output_cycle;
    
    `uvm_object_utils_begin(mul_transaction)
      `uvm_field_int(a, UVM_ALL_ON)
      `uvm_field_int(b, UVM_ALL_ON) 
      `uvm_field_int(result, UVM_ALL_ON)
      `uvm_field_int(expected, UVM_ALL_ON)
      `uvm_field_int(transaction_id, UVM_ALL_ON)
    `uvm_object_utils_end
    
    function new(string name = "mul_transaction");
      super.new(name);
    endfunction
    
    function void post_randomize();
      expected = a * b;
    endfunction
    
    constraint c_data_range {
      a inside {[0:255]};
      b inside {[0:255]};
    }
    
    function string convert2string();
      return $sformatf("ID=%0d, a=%0d, b=%0d, expected=%0d, result=%0d", 
                       transaction_id, a, b, expected, result);
    endfunction
  endclass

  // ============================================================================
  // Sequencer
  // ============================================================================
  typedef uvm_sequencer#(mul_transaction) mul_sequencer;

  // ============================================================================
  // Driver
  // ============================================================================
  class mul_driver extends uvm_driver#(mul_transaction);
    `uvm_component_utils(mul_driver)
    
    virtual dut_if vif;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual dut_if)::get(this, "", "vif", vif))
        `uvm_fatal("DRIVER", "Could not get vif from config_db")
    endfunction
    
    task run_phase(uvm_phase phase);
      mul_transaction req;
      
      // Initialize signals
      vif.cb_driver.a <= '0;
      vif.cb_driver.b <= '0;
      
      forever begin
        seq_item_port.get_next_item(req);
        
        @(vif.cb_driver);
        vif.cb_driver.a <= req.a;
        vif.cb_driver.b <= req.b;
        
        `uvm_info("DRIVER", $sformatf("Driving: a=%0d, b=%0d at cycle %0d", 
                  req.a, req.b, vif.cycle_counter), UVM_HIGH)
        
        seq_item_port.item_done();
      end
    endtask
  endclass

  // ============================================================================
  // Monitor with Automatic Latency Detection
  // ============================================================================
  class mul_monitor extends uvm_monitor;
    `uvm_component_utils(mul_monitor)
    
    virtual dut_if vif;
    uvm_analysis_port#(mul_transaction) ap;
    
    // 延迟检测相关
    int detected_latency = -1;
    bit latency_detected = 0;
    int max_detection_cycles = 20;
    
    // 事务跟踪
    mul_transaction pending_queue[$];
    int transaction_id = 0;
    
    // 统计
    int total_transactions = 0;
    int matched_transactions = 0;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual dut_if)::get(this, "", "vif", vif))
        `uvm_fatal("MONITOR", "Could not get vif")
        
      // 尝试从配置获取已知延迟
      if(uvm_config_db#(int)::get(this, "", "pipeline_latency", detected_latency)) begin
        `uvm_info("MONITOR", $sformatf("Using configured latency: %0d", detected_latency), UVM_LOW)
        latency_detected = 1;
      end
    endfunction
    
    task run_phase(uvm_phase phase);
      fork
        detect_latency();
        monitor_transactions();
      join_none
    endtask
    
    // 自动检测延迟
    task detect_latency();
      mul_transaction detect_txn;
      bit [7:0] test_a, test_b;
      bit [15:0] expected_out;
      int start_cycle;
      
      if (latency_detected) return;  // 已经知道延迟
      
      `uvm_info("MONITOR", "Starting automatic latency detection...", UVM_LOW)
      
      // 等待复位完成
      wait(vif.rst_n == 1'b1);
      repeat(5) @(posedge vif.clk);
      
      // 发送特定的测试模式
      test_a = 8'hAA;
      test_b = 8'h55;
      expected_out = test_a * test_b;
      
      `uvm_info("MONITOR", $sformatf("Detection pattern: %0h x %0h = %0h", 
                test_a, test_b, expected_out), UVM_LOW)
      
      // 等待driver发送第一个真实数据
      wait(vif.a == test_a && vif.b == test_b);
      start_cycle = vif.cycle_counter;
      `uvm_info("MONITOR", $sformatf("Detection pattern seen at cycle %0d", start_cycle), UVM_LOW)
      
      // 等待输出出现
      repeat(max_detection_cycles) begin
        @(posedge vif.clk);
        if (vif.out == expected_out) begin
          detected_latency = vif.cycle_counter - start_cycle;
          latency_detected = 1;
          `uvm_info("MONITOR", $sformatf("✓ Latency detected: %0d cycles", detected_latency), UVM_LOW)
          
          // 保存到配置数据库
          uvm_config_db#(int)::set(null, "*", "detected_pipeline_latency", detected_latency);
          return;
        end
      end
      
      // 如果没检测到，使用默认值
      `uvm_warning("MONITOR", "Could not detect latency, using default value of 4")
      detected_latency = 4;
      latency_detected = 1;
    endtask
    
    // 监控事务
    task monitor_transactions();
      mul_transaction txn, out_txn;
      int output_delay_counter = 0;
      
      // 等待延迟检测完成
      wait(latency_detected == 1);
      `uvm_info("MONITOR", $sformatf("Starting transaction monitoring with latency=%0d", 
                detected_latency), UVM_LOW)
      
      forever begin
        @(vif.cb_monitor);
        
        if (!vif.rst_n) begin
          pending_queue.delete();
          output_delay_counter = 0;
          transaction_id = 0;
          continue;
        end
        
        // 捕获输入
        txn = mul_transaction::type_id::create("input_txn");
        txn.a = vif.cb_monitor.a;
        txn.b = vif.cb_monitor.b;
        txn.expected = txn.a * txn.b;
        txn.transaction_id = transaction_id++;
        txn.input_cycle = vif.cycle_counter;
        
        // 加入待处理队列
        pending_queue.push_back(txn);
        `uvm_info("MONITOR", $sformatf("Input[%0d]: a=%0d, b=%0d at cycle %0d", 
                  txn.transaction_id, txn.a, txn.b, txn.input_cycle), UVM_HIGH)
        
        // 检查是否有输出准备好
        if (pending_queue.size() > detected_latency) begin
          out_txn = pending_queue.pop_front();
          out_txn.result = vif.cb_monitor.out;
          out_txn.output_cycle = vif.cycle_counter;
          
          total_transactions++;
          if (out_txn.result == out_txn.expected) matched_transactions++;
          
          ap.write(out_txn);
          `uvm_info("MONITOR", $sformatf("Output[%0d]: result=%0d (expected=%0d) at cycle %0d", 
                    out_txn.transaction_id, out_txn.result, out_txn.expected, 
                    out_txn.output_cycle), UVM_HIGH)
        end
      end
    endtask
    
    function void report_phase(uvm_phase phase);
      `uvm_info("MONITOR", "=====================================", UVM_NONE)
      `uvm_info("MONITOR", $sformatf("Detected Pipeline Latency: %0d cycles", detected_latency), UVM_NONE)
      `uvm_info("MONITOR", $sformatf("Total Transactions: %0d", total_transactions), UVM_NONE)
      `uvm_info("MONITOR", $sformatf("Matched Transactions: %0d", matched_transactions), UVM_NONE)
      if (pending_queue.size() > 0) begin
        `uvm_warning("MONITOR", $sformatf("%0d transactions still in pipeline", pending_queue.size()))
      end
      `uvm_info("MONITOR", "=====================================", UVM_NONE)
    endfunction
  endclass

  // ============================================================================
  // Scoreboard
  // ============================================================================
  class mul_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(mul_scoreboard)
    
    uvm_analysis_export#(mul_transaction) analysis_export;
    uvm_tlm_analysis_fifo#(mul_transaction) txn_fifo;
    
    int pass_count = 0;
    int fail_count = 0;
    int total_count = 0;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      analysis_export = new("analysis_export", this);
      txn_fifo = new("txn_fifo", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      analysis_export.connect(txn_fifo.analysis_export);
    endfunction
    
    task run_phase(uvm_phase phase);
      mul_transaction txn;
      
      forever begin
        txn_fifo.get(txn);
        total_count++;
        
        if (txn.expected === txn.result) begin
          pass_count++;
          `uvm_info("SCOREBOARD", 
                    $sformatf("[%0d] PASS: %s", total_count, txn.convert2string()), 
                    UVM_MEDIUM)
        end else begin
          fail_count++;
          `uvm_error("SCOREBOARD", 
                     $sformatf("[%0d] FAIL: %s", total_count, txn.convert2string()))
        end
      end
    endtask
    
    function void report_phase(uvm_phase phase);
      real pass_rate;
      
      if (total_count > 0)
        pass_rate = (pass_count * 100.0) / total_count;
      else
        pass_rate = 0.0;
      
      `uvm_info("SCOREBOARD", "=====================================", UVM_NONE)
      `uvm_info("SCOREBOARD", "     VERIFICATION RESULTS", UVM_NONE)
      `uvm_info("SCOREBOARD", "=====================================", UVM_NONE)
      `uvm_info("SCOREBOARD", $sformatf("Total Tests: %0d", total_count), UVM_NONE)
      `uvm_info("SCOREBOARD", $sformatf("Passed: %0d", pass_count), UVM_NONE)
      `uvm_info("SCOREBOARD", $sformatf("Failed: %0d", fail_count), UVM_NONE)
      `uvm_info("SCOREBOARD", $sformatf("Pass Rate: %.2f%%", pass_rate), UVM_NONE)
      `uvm_info("SCOREBOARD", "=====================================", UVM_NONE)
      
      if (fail_count == 0 && pass_count > 0)
        `uvm_info("SCOREBOARD", "*** ALL TESTS PASSED ***", UVM_NONE)
      else if (fail_count > 0)
        `uvm_error("SCOREBOARD", "*** TESTS FAILED ***")
    endfunction
  endclass

  // ============================================================================
  // Coverage
  // ============================================================================
  class mul_coverage extends uvm_subscriber#(mul_transaction);
    `uvm_component_utils(mul_coverage)
    
    covergroup cg_multiplier;
      a_cp: coverpoint txn.a {
        bins zero = {0};
        bins low = {[1:127]};
        bins high = {[128:254]};
        bins max = {255};
      }
      
      b_cp: coverpoint txn.b {
        bins zero = {0};
        bins low = {[1:127]};
        bins high = {[128:254]};
        bins max = {255};
      }
      
      result_cp: coverpoint txn.result {
        bins zero = {0};
        bins low = {[1:16383]};
        bins mid = {[16384:49151]};
        bins high = {[49152:65280]};
        bins max = {65025};
      }
      
      cross a_cp, b_cp;
    endgroup
    
    mul_transaction txn;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg_multiplier = new();
    endfunction
    
    function void write(mul_transaction t);
      txn = t;
      cg_multiplier.sample();
    endfunction
    
    function void report_phase(uvm_phase phase);
      `uvm_info("COVERAGE", $sformatf("Coverage = %.2f%%", cg_multiplier.get_coverage()), UVM_LOW)
    endfunction
  endclass

  // ============================================================================
  // Agent
  // ============================================================================
  class mul_agent extends uvm_agent;
    `uvm_component_utils(mul_agent)
    
    mul_driver driver;
    mul_monitor monitor;
    mul_sequencer sequencer;
    mul_coverage coverage;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      
      if(get_is_active() == UVM_ACTIVE) begin
        driver = mul_driver::type_id::create("driver", this);
        sequencer = mul_sequencer::type_id::create("sequencer", this);
      end
      
      monitor = mul_monitor::type_id::create("monitor", this);
      coverage = mul_coverage::type_id::create("coverage", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if(get_is_active() == UVM_ACTIVE) begin
        driver.seq_item_port.connect(sequencer.seq_item_export);
      end
      monitor.ap.connect(coverage.analysis_export);
    endfunction
  endclass

  // ============================================================================
  // Environment
  // ============================================================================
  class mul_env extends uvm_env;
    `uvm_component_utils(mul_env)
    
    mul_agent agent;
    mul_scoreboard sb;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      
      agent = mul_agent::type_id::create("agent", this);
      sb = mul_scoreboard::type_id::create("sb", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      
      // Connect monitor to scoreboard
      agent.monitor.ap.connect(sb.analysis_export);
    endfunction
  endclass

  // ============================================================================
  // Sequences
  // ============================================================================
  
  // 基础序列
  class mul_sequence extends uvm_sequence#(mul_transaction);
    `uvm_object_utils(mul_sequence)
    
    rand int num_trans;
    
    constraint c_num_trans {
      num_trans inside {[10:1000]};
    }
    
    function new(string name = "mul_sequence");
      super.new(name);
    endfunction
    
    task body();
      mul_transaction txn;
      
      repeat(num_trans) begin
        txn = mul_transaction::type_id::create("txn");
        start_item(txn);
        assert(txn.randomize());
        finish_item(txn);
      end
    endtask
  endclass
  
  // 用于延迟检测的特殊序列
  class detection_sequence extends uvm_sequence#(mul_transaction);
    `uvm_object_utils(detection_sequence)
    
    function new(string name = "detection_sequence");
      super.new(name);
    endfunction
    
    task body();
      mul_transaction txn;
      
      // 发送特定的测试模式用于延迟检测
      txn = mul_transaction::type_id::create("detect_txn");
      start_item(txn);
      txn.a = 8'hAA;
      txn.b = 8'h55;
      finish_item(txn);
      
      // 再发送几个正常的事务
      repeat(10) begin
        txn = mul_transaction::type_id::create("txn");
        start_item(txn);
        assert(txn.randomize());
        finish_item(txn);
      end
    endtask
  endclass

  // ============================================================================
  // Tests
  // ============================================================================
  
  // 基础测试
  class basic_test extends uvm_test;
    `uvm_component_utils(basic_test)
    
    mul_env env;
    virtual dut_if vif;
    
    function new(string name = "basic_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = mul_env::type_id::create("env", this);
      
      if(!uvm_config_db#(virtual dut_if)::get(this, "", "vif", vif))
        `uvm_fatal("TEST", "Could not get vif from config_db")
    endfunction
    
    task run_phase(uvm_phase phase);
      detection_sequence det_seq;
      mul_sequence main_seq;
      
      phase.raise_objection(this);
      
      // 等待复位
      wait(vif.rst_n == 1'b1);
      repeat(5) @(posedge vif.clk);
      
      // 先运行检测序列
      `uvm_info("TEST", "Running detection sequence...", UVM_LOW)
      det_seq = detection_sequence::type_id::create("det_seq");
      det_seq.start(env.agent.sequencer);
      
      // 等待检测完成
      repeat(20) @(posedge vif.clk);
      
      // 运行主测试序列
      `uvm_info("TEST", "Running main test sequence...", UVM_LOW)
      main_seq = mul_sequence::type_id::create("main_seq");
      main_seq.num_trans = 100;
      main_seq.start(env.agent.sequencer);
      
      // 等待流水线清空
      repeat(20) @(posedge vif.clk);
      
      phase.drop_objection(this);
    endtask
  endclass
  
  // 随机测试
  class random_test extends basic_test;
    `uvm_component_utils(random_test)
    
    function new(string name = "random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction
    
    task run_phase(uvm_phase phase);
      detection_sequence det_seq;
      mul_sequence seq;
      
      phase.raise_objection(this);
      
      wait(vif.rst_n == 1'b1);
      repeat(5) @(posedge vif.clk);
      
      // 检测序列
      det_seq = detection_sequence::type_id::create("det_seq");
      det_seq.start(env.agent.sequencer);
      
      repeat(20) @(posedge vif.clk);
      
      // 随机测试
      seq = mul_sequence::type_id::create("seq");
      assert(seq.randomize() with {num_trans == 500;});
      seq.start(env.agent.sequencer);
      
      repeat(20) @(posedge vif.clk);
      
      phase.drop_objection(this);
    endtask
  endclass
  
  // 约束测试
  class constraint_test extends basic_test;
    `uvm_component_utils(constraint_test)
    
    function new(string name = "constraint_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction
    
    task run_phase(uvm_phase phase);
      detection_sequence det_seq;
      mul_transaction txn;
      
      phase.raise_objection(this);
      
      wait(vif.rst_n == 1'b1);
      repeat(5) @(posedge vif.clk);
      
      // 检测序列
      det_seq = detection_sequence::type_id::create("det_seq");
      det_seq.start(env.agent.sequencer);
      
      repeat(20) @(posedge vif.clk);
      
      // 测试边界条件
      // 0 x 0
      txn = mul_transaction::type_id::create("txn");
      txn.a = 0; txn.b = 0;
      env.agent.sequencer.execute_item(txn);
      
      // 255 x 255
      txn = mul_transaction::type_id::create("txn");
      txn.a = 255; txn.b = 255;
      env.agent.sequencer.execute_item(txn);
      
      // 1 x any
      repeat(10) begin
        txn = mul_transaction::type_id::create("txn");
        txn.a = 1;
        assert(txn.randomize() with {b inside {[0:255]};});
        env.agent.sequencer.execute_item(txn);
      end
      
      repeat(20) @(posedge vif.clk);
      
      phase.drop_objection(this);
    endtask
  endclass

endpackage