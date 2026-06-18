///////////Transaction Class
class transaction;
  rand bit w_en;
  rand bit r_en;
  rand bit [7:0] w_data;
  
  bit [7:0] r_data;
  bit full;
  bit empty;
  
  constraint ctrl_logic {
    w_en dist {0:=20, 1:=80}; 
    r_en dist {0:=50, 1:=50}; 
    
  }
endclass


//////////Generator
class generator;
  transaction trans;
  mailbox #(transaction) gen2drv;
  int repeat_count;
  event ended; 
  
  function new(mailbox #(transaction) gen2drv);
    this.gen2drv = gen2drv;
  endfunction
  
  task run();
    
    // PHASE 1: Directed Fill (Stress test the 'Full' flags)
    
    
    for(int i = 0; i < 20; i++) begin
      trans = new();
      
      if(!trans.randomize() with { w_en == 1; r_en == 0; }) $fatal(1, "Gen: Randomization failed");
      gen2drv.put(trans);
    end

    
    // PHASE 2: Directed Drain (Stress test the 'Empty' flags)
    
    for(int i = 0; i < 20; i++) begin
      trans = new();
      if(!trans.randomize() with { w_en == 0; r_en == 1; }) $fatal(1, "Gen: Randomization failed");
      gen2drv.put(trans);
    end

    
    // PHASE 3: Normal Constrained Random Operation
   
   
    for(int i = 0; i < (repeat_count - 40); i++) begin
      trans = new();
      if(!trans.randomize()) $fatal(1, "Gen: Randomization failed");
      gen2drv.put(trans);
    end
    
    -> ended; 
  endtask
endclass


///////////Driver
class driver;
  virtual fifo_if vif;
  mailbox #(transaction) gen2drv;
  int transactions_driven = 0;
  
  function new(virtual fifo_if vif, mailbox #(transaction) gen2drv);
    this.vif = vif;
    this.gen2drv = gen2drv;
  endfunction
  
  task run();
    forever begin
      transaction trans;
      gen2drv.get(trans);
      
      @(posedge vif.clk);
      if(!vif.rst_n) begin
        vif.w_en <= 0; vif.r_en <= 0; vif.w_data <= 0;
      end else begin
        vif.w_en <= trans.w_en;
        vif.r_en <= trans.r_en;
        vif.w_data <= trans.w_data;
      end
      
      transactions_driven++; 
    end
  endtask
 endclass

//////////Coverage Collector Class
class coverage_collector;
  transaction trans;
  mailbox #(transaction) mon2cov;

  covergroup fifo_cg;
    option.per_instance = 1;
    option.name = "FIFO_Coverage";

    cp_w_en:  coverpoint trans.w_en;
    cp_r_en:  coverpoint trans.r_en;
    cp_full:  coverpoint trans.full;
    cp_empty: coverpoint trans.empty;

    cross_write_full: cross cp_w_en, cp_full {
      ignore_bins normal_writes = binsof(cp_full) intersect {0};
    }
    cross_read_empty: cross cp_r_en, cp_empty {
      ignore_bins normal_reads = binsof(cp_empty) intersect {0};
    }
    cross_rw: cross cp_w_en, cp_r_en;
  endgroup

  function new(mailbox #(transaction) mon2cov);
    this.mon2cov = mon2cov;
    fifo_cg = new();
  endfunction

  task run();
    forever begin
      mon2cov.get(trans);
      fifo_cg.sample();
    end
  endtask
  
  function void print_coverage();
    $display("=======================================");
    $display(" Final Functional Coverage: %0.2f%%", fifo_cg.get_coverage());
    $display("=======================================");
  endfunction
endclass


////////////////Monitor
class monitor;
  virtual fifo_if vif;
  mailbox #(transaction) mon2scb;
  mailbox #(transaction) mon2cov; 
  
  function new(virtual fifo_if vif, mailbox #(transaction) mon2scb, mailbox #(transaction) mon2cov);
    this.vif = vif;
    this.mon2scb = mon2scb;
    this.mon2cov = mon2cov;
  endfunction
  
  task run();
    forever begin
      transaction trans = new();
      @(posedge vif.clk);
      #1; 
      
      trans.w_en   = vif.w_en;
      trans.r_en   = vif.r_en;
      trans.w_data = vif.w_data;
      trans.r_data = vif.r_data;
      trans.full   = vif.full;
      trans.empty  = vif.empty;
      
      mon2scb.put(trans);
      
      // Deep copy for the coverage collector
      begin
        transaction trans_cov = new();
        trans_cov.w_en   = trans.w_en;
        trans_cov.r_en   = trans.r_en;
        trans_cov.full   = trans.full;
        trans_cov.empty  = trans.empty;
        mon2cov.put(trans_cov);
      end
    end
  endtask
endclass


///////Scoreboard
class scoreboard;
  mailbox #(transaction) mon2scb;
  bit [7:0] golden_queue[$]; 
  
  function new(mailbox #(transaction) mon2scb);
    this.mon2scb = mon2scb;
  endfunction
  
  task run();
    forever begin
      transaction trans;
      mon2scb.get(trans);
      
      if(trans.w_en && !trans.full) begin
        golden_queue.push_back(trans.w_data);
      end
      
      if(trans.r_en && !trans.empty) begin
        bit [7:0] expected_data = golden_queue.pop_front();
        if(trans.r_data !== expected_data) begin
          $error("[SCB FAIL] Data Mismatch! Expected: %0h, Actual: %0h", expected_data, trans.r_data);
        end else begin
          $display("[SCB PASS] Data Match: %0h", trans.r_data);
        end
      end
    end
  endtask
endclass


////////////Environment Class
class environment;
  generator          gen;
  driver             drv;
  monitor            mon;
  scoreboard         scb;
  coverage_collector cov;
  
  mailbox #(transaction) m1; 
  mailbox #(transaction) m2_scb; 
  mailbox #(transaction) m2_cov;
  
  virtual fifo_if vif;
  
  function new(virtual fifo_if vif);
    this.vif = vif;
    m1 = new();
    m2_scb = new();
    m2_cov = new();
    
    gen = new(m1);
    drv = new(vif, m1);
    mon = new(vif, m2_scb, m2_cov);
    scb = new(m2_scb);
    cov = new(m2_cov);
  endfunction
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      scb.run();
      cov.run();
    join_none 
    
    wait(gen.ended.triggered); 
    
    
    wait(drv.transactions_driven == gen.repeat_count);       
    #50;                       
  endtask
endclass


////////////TB Module
module tb_top;
  logic clk, rst_n;
  
  fifo_if vif(clk, rst_n);
  
  fifo_dut dut (
    .clk(vif.clk),
    .rst_n(vif.rst_n),
    .w_en(vif.w_en),
    .r_en(vif.r_en),
    .w_data(vif.w_data),
    .r_data(vif.r_data),
    .full(vif.full),
    .empty(vif.empty)
  );
  
  environment env;
  
  initial begin clk = 0; forever #5 clk = ~clk; end
  
  initial begin
    $dumpfile("dump.vcd"); 
    $dumpvars;
    
    rst_n = 0;
    #20 rst_n = 1;
    
    env = new(vif);
    
    env.gen.repeat_count = 100; 
    env.test();
    
    env.cov.print_coverage(); 
    $display("Test Completed.");
    $finish;
  end
endmodule
