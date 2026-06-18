
# SystemVerilog Synchronous FIFO Verification Environment

[![Language](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](#)
[![Methodology](https://img.shields.io/badge/Methodology-Coverage--Driven%20Verification-success.svg)](#)
[![Simulator](https://img.shields.io/badge/Simulator-EDA%20Playground%20%7C%20Riviera--PRO-lightgrey.svg)](#)

## 📌 Overview
This repository contains a complete, layered Design Verification (DV) environment for a standard 16-depth Synchronous FIFO. The testbench is architected using object-oriented SystemVerilog principles, mirroring industry-standard UVM methodologies. 

It features a completely isolated stimulus generation path, a self-checking scoreboard utilizing an ideal reference model, and functional coverage collection to quantify verification completeness.

## 🏗️ Testbench Architecture
The environment is separated into distinct classes to maximize reusability and scalability, communicating via SystemVerilog `mailboxes` and `events`.

* **Transaction (`transaction.sv`):** Defines the randomized data packet (write enable, read enable, 8-bit payload) with constraint logic to stress-test specific hardware states.
* **Generator (`generator.sv`):** Generates constrained-random stimulus and pushes it to the driver.
* **Driver (`driver.sv`):** Acts as the standard BFM (Bus Functional Model), translating transaction packets into pin-level signal toggles at the active clock edge.
* **Monitor (`monitor.sv`):** Passively observes the virtual interface, packing pin-level activity back into transaction objects, broadcasting them to both the Scoreboard and Coverage Collector.
* **Scoreboard (`scoreboard.sv`):** The Golden Reference Model. It utilizes a SystemVerilog Queue (`[$]`) to emulate ideal FIFO behavior (0-cycle latency FWFT), mathematically comparing the actual DUT output against the expected data on-the-fly.
* **Coverage Collector (`coverage_collector.sv`):** Implements a `covergroup` with targeted `coverpoints` and `cross-coverage` bins to ensure all critical edge cases (Full, Empty, Simultaneous Read/Write, Overflow/Underflow attempts) are successfully hit during simulation.

## 🚀 Key Features Demonstrated
* **Constrained-Random Generation:** Utilized `dist` constraints to favor specific operational modes (e.g., heavily weighting writes during initialization to quickly achieve a `full` state).
* **Inter-Process Communication (IPC):** Deep copies of objects passed via parameterized Mailboxes to prevent memory overwrites in concurrent threads.
* **Self-Checking Assertions:** Automated `$error` flagging upon data mismatches, eliminating the need for manual waveform inspection.
* **Coverage-Driven Verification (CDV):** Achieved 100% functional coverage on target corner-cases.

## 📁 Directory Structure
```text
├── design/
│   ├── fifo_dut.sv         # RTL code for the Synchronous FIFO
│   └── fifo_if.sv          # Physical SystemVerilog Interface
├── verification/
│   ├── transaction.sv      # Packet definition
│   ├── generator.sv        # Stimulus generation
│   ├── driver.sv           # Pin wiggler
│   ├── monitor.sv          # Passive bus observation
│   ├── scoreboard.sv       # Reference model & comparator
│   ├── coverage.sv         # Covergroups and bins
│   └── environment.sv      # Top-level class instantiation and wiring
├── tb_top.sv               # Top-level module (Clock gen & DUT instantiation)
└── README.md

## ⚙️ How to Run
This environment was developed and simulated using Aldec Riviera-PRO, but is fully compatible with standard SystemVerilog simulators (Questa, VCS, Xcelium).

**To run via command line (batch mode):**
```bash
vlib work
vlog -timescale 1ns/1ns design.sv testbench.sv
vsim -c -do "run -all; exit" tb_top

## 📊 Sample Output
```text
[SCB PASS] Data Match: 59
[SCB PASS] Data Match: 55
[SCB PASS] Data Match: bc
...
=======================================
 Final Functional Coverage: 100.00%
=======================================
Test Completed.

## 👨‍💻 Author
**[Madhujya Kalita]** *Electronics and Communication Engineering* [linkedin.com/in/madhujya-kalita-360328192] | [madhujyahere1@gmail.com]
