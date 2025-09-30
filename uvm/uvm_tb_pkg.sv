`include "uvm_macros.svh"
import uvm_pkg::*;

package uvm_tb_pkg;

  // Transaction class
  class mul_transaction extends uvm_sequence_item;
    rand bit [7:0] a, b;
    bit [15:0] result;
    bit [15:0] expected;
    
    `uvm_object_utils_begin(mul_transaction)
      `uvm_field_int(a, UVM_ALL_ON)
      `uvm_field_int(b, UVM_ALL_ON) 
      `uvm_field_int(result, UVM_ALL_ON)
      `uvm_field_int(expected, UVM_ALL_ON)
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
      return $sformatf("a=%0d, b=%0d, expected=%0d, result=%0d", 
                       a, b, expected, result);
    endfunction
  endclass

  // Sequence class
  class mul_sequence extends uvm_sequence#(mul_transaction);
    `uvm_object_utils(mul_sequence)
    
    int num_trans = 100;
    
    function new(string name = "mul_sequence");
      super.new(name);
    endfunction
    
    task body();
      repeat(num_trans) begin
        `uvm_do(req)
      end
    endtask
  endclass

  // Sequencer
  typedef uvm_sequencer#(mul_transaction) mul_sequencer;

  // Driver
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
        
        `uvm_info("DRIVER", $sformatf("Driving: %s", req.convert2string()), UVM_DEBUG)
        
        seq_item_port.item_done();
      end
    endtask
  endclass

  // Monitor
  class mul_monitor extends uvm_monitor;
    `uvm_component_utils(mul_monitor)
    
    virtual dut_if vif;
    uvm_analysis_port#(mul_transaction) ap;
    
    // Coverage
    covergroup cg_operations @(vif.cb_monitor);
      option.per_instance = 1;
      
      a_cp: coverpoint vif.cb_monitor.a {
        bins zero = {8'h00};
        bins max = {8'hFF};
        bins low = {[8'h00:8'h0F]};
        bins mid_low = {[8'h10:8'h7F]};
        bins mid_high = {[8'h80:8'hEF]};
        bins high = {[8'hF0:8'hFE]};
      }
      
      b_cp: coverpoint vif.cb_monitor.b {
        bins zero = {8'h00};
        bins max = {8'hFF};
        bins low = {[8'h00:8'h0F]};
        bins mid_low = {[8'h10:8'h7F]};
        bins mid_high = {[8'h80:8'hEF]};
        bins high = {[8'hF0:8'hFE]};
      }
      
      out_cp: coverpoint vif.cb_monitor.out {
        bins zero = {16'h0000};
        bins low = {[16'h0001:16'h00FF]};
        bins mid = {[16'h0100:16'hFE00]};
        bins high = {[16'hFE01:16'hFFFE]};
        bins max = {16'hFFFF};
      }
      
      a_b_cross: cross a_cp, b_cp;
    endgroup
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
      cg_operations = new();
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual dut_if)::get(this, "", "vif", vif))
        `uvm_fatal("MONITOR", "Could not get vif from config_db")
    endfunction
    
    task run_phase(uvm_phase phase);
      mul_transaction obs_txn;
      
      forever begin
        @(vif.cb_monitor);
        
        obs_txn = mul_transaction::type_id::create("obs_txn");
        obs_txn.a = vif.cb_monitor.a;
        obs_txn.b = vif.cb_monitor.b;
        obs_txn.result = vif.cb_monitor.out;
        
        ap.write(obs_txn);
        `uvm_info("MONITOR", $sformatf("Observed: %s", obs_txn.convert2string()), UVM_DEBUG)
      end
    endtask
    
    function void report_phase(uvm_phase phase);
      `uvm_info("COVERAGE", $sformatf("Coverage = %.2f%%", cg_operations.get_coverage()), UVM_LOW)
    endfunction
  endclass

  // FIXED: Predictor with proper timing and ordering
  class mul_predictor extends uvm_subscriber#(mul_transaction);
    `uvm_component_utils(mul_predictor)
    
    // FIXED: Added vif declaration and build_phase
    virtual dut_if vif;
    uvm_analysis_port#(mul_transaction) ap;
    
    // FIXED: Use FIFO for ordered prediction
    uvm_tlm_analysis_fifo#(mul_transaction) input_fifo;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
    
    // FIXED: Added build_phase to get vif
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual dut_if)::get(this, "", "vif", vif))
        `uvm_fatal("PREDICTOR", "Could not get vif from config_db")
      input_fifo = new("input_fifo", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      this.analysis_export.connect(input_fifo.analysis_export);
    endfunction
    
    // FIXED: Changed to proper write function without timing
    function void write(mul_transaction t);
      // Just forward to the FIFO for ordered processing
      input_fifo.write(t);
    endfunction
    
    // FIXED: Separate task for timing-sensitive prediction
    task run_phase(uvm_phase phase);
      mul_transaction input_txn, pred_txn;
      
      forever begin
        input_fifo.get(input_txn);
        
        // Create predicted transaction
        pred_txn = mul_transaction::type_id::create("pred_txn");
        pred_txn.copy(input_txn);
        pred_txn.expected = input_txn.a * input_txn.b;
        
        // FIXED: Proper timing delay for pipeline
        repeat(2) @(posedge vif.clk); // 2-cycle pipeline delay
        
        ap.write(pred_txn);
        `uvm_info("PREDICTOR", $sformatf("Predicted: %s", pred_txn.convert2string()), UVM_DEBUG)
      end
    endtask
  endclass

  // Scoreboard with proper FIFO ordering
  class mul_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(mul_scoreboard)
    
    uvm_analysis_export#(mul_transaction) exp_export;
    uvm_analysis_export#(mul_transaction) obs_export;
    
    // FIXED: Use ordering FIFOs to maintain transaction sequence
    uvm_tlm_analysis_fifo#(mul_transaction) exp_fifo;
    uvm_tlm_analysis_fifo#(mul_transaction) obs_fifo;
    
    int pass_count = 0;
    int fail_count = 0;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      
      exp_export = new("exp_export", this);
      obs_export = new("obs_export", this);
      exp_fifo = new("exp_fifo", this);
      obs_fifo = new("obs_fifo", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      exp_export.connect(exp_fifo.analysis_export);
      obs_export.connect(obs_fifo.analysis_export);
    endfunction
    
    task run_phase(uvm_phase phase);
      mul_transaction exp_txn, obs_txn;
      
      forever begin
        // FIXED: Sequential FIFO operations maintain order
        fork
          exp_fifo.get(exp_txn);
          obs_fifo.get(obs_txn);
        join
        
        // Compare in-order transactions
        if (exp_txn.expected === obs_txn.result && 
            exp_txn.a === obs_txn.a && exp_txn.b === obs_txn.b) begin
          pass_count++;
          `uvm_info("SCOREBOARD", $sformatf("PASS: %s", obs_txn.convert2string()), UVM_LOW)
        end else begin
          fail_count++;
          `uvm_error("SCOREBOARD", $sformatf("FAIL: Expected=%0d, Actual=%0d, a=%0d, b=%0d", 
                     exp_txn.expected, obs_txn.result, obs_txn.a, obs_txn.b))
        end
      end
    endtask
    
    function void report_phase(uvm_phase phase);
      real pass_rate = (pass_count > 0) ? (pass_count * 100.0) / (pass_count + fail_count) : 0.0;
      
      `uvm_info("FINAL_REPORT", 
                $sformatf("==== VERIFICATION RESULTS ===="), UVM_NONE)
      `uvm_info("FINAL_REPORT", 
                $sformatf("Pass: %0d, Fail: %0d", pass_count, fail_count), UVM_NONE)
      `uvm_info("FINAL_REPORT", 
                $sformatf("Pass Rate: %.2f%%", pass_rate), UVM_NONE)
      
      if (fail_count == 0 && pass_count > 0)
        `uvm_info("FINAL_REPORT", "*** TEST PASSED ***", UVM_NONE)
      else
        `uvm_error("FINAL_REPORT", "*** TEST FAILED ***")
    endfunction
  endclass

  // Agent
  class mul_agent extends uvm_agent;
    `uvm_component_utils(mul_agent)
    
    mul_driver driver;
    mul_monitor monitor;
    mul_sequencer sequencer;
    
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
    endfunction
    
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if(get_is_active() == UVM_ACTIVE) begin
        driver.seq_item_port.connect(sequencer.seq_item_export);
      end
    endfunction
  endclass

  // Environment
  class mul_env extends uvm_env;
    `uvm_component_utils(mul_env)
    
    mul_agent agent;
    mul_scoreboard sb;
    mul_predictor pred;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      
      agent = mul_agent::type_id::create("agent", this);
      sb = mul_scoreboard::type_id::create("sb", this);
      pred = mul_predictor::type_id::create("pred", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      
      // FIXED: Proper connection for ordered prediction
      agent.monitor.ap.connect(pred.analysis_export);
      pred.ap.connect(sb.exp_export);
      agent.monitor.ap.connect(sb.obs_export);
    endfunction
  endclass

  // Test classes
  class mul_base_test extends uvm_test;
    `uvm_component_utils(mul_base_test)
    
    mul_env env;
    
    function new(string name = "mul_base_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = mul_env::type_id::create("env", this);
    endfunction
    
    task run_phase(uvm_phase phase);
      mul_sequence seq;
      
      phase.raise_objection(this);
      
      // Wait for reset deassertion
      @(posedge env.agent.monitor.vif.rst_n);
      repeat(5) @(posedge env.agent.monitor.vif.clk);
      
      seq = mul_sequence::type_id::create("seq");
      if(!$value$plusargs("NUM_TRANS=%d", seq.num_trans))
        seq.num_trans = 1000;
      
      `uvm_info("TEST", $sformatf("Starting test with %0d transactions", seq.num_trans), UVM_LOW)
      
      seq.start(env.agent.sequencer);
      
      // Wait for pipeline to empty
      repeat(10) @(posedge env.agent.monitor.vif.clk);
      
      phase.drop_objection(this);
    endtask
  endclass

  // Specific test for corner cases
  class mul_corner_test extends mul_base_test;
    `uvm_component_utils(mul_corner_test)
    
    function new(string name = "mul_corner_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction
    
    task run_phase(uvm_phase phase);
      mul_transaction corner_txns[$];
      
      phase.raise_objection(this);
      
      // Wait for reset
      @(posedge env.agent.monitor.vif.rst_n);
      repeat(5) @(posedge env.agent.monitor.vif.clk);
      
      // Create corner case transactions
      corner_txns.push_back(create_txn(0, 0));       // Zero multiplication
      corner_txns.push_back(create_txn(255, 255));   // Maximum values
      corner_txns.push_back(create_txn(1, 255));     // Identity cases
      corner_txns.push_back(create_txn(255, 1));
      corner_txns.push_back(create_txn(128, 128));   // Mid-range
      
      foreach(corner_txns[i]) begin
        env.agent.sequencer.execute_item(corner_txns[i]);
        `uvm_info("CORNER_TEST", $sformatf("Sent: %s", corner_txns[i].convert2string()), UVM_LOW)
      end
      
      repeat(20) @(posedge env.agent.monitor.vif.clk);
      phase.drop_objection(this);
    endtask
    
    function mul_transaction create_txn(bit [7:0] a, bit [7:0] b);
      mul_transaction txn = mul_transaction::type_id::create("corner_txn");
      txn.a = a;
      txn.b = b;
      txn.expected = a * b;
      return txn;
    endfunction
  endclass

endpackage