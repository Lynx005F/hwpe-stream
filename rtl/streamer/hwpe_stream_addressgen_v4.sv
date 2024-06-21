/*
 * hwpe_stream_addressgen_v4.sv
 * Francesco Conti <f.conti@unibo.it>
 * Maurus Item <itemm@student.ethz.ch>
 *
 * Copyright (C) 2024 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */

/**
 * The **hwpe_stream_addressgen_v4** module is used to generate addresses to
 * load or store HWPE-Stream stream. In this version of the address generator,
 * the address is itself carried within a HWPE-Stream, making it easily stallable.
 * The address generator can be used to generate address from a
 * n-dimensional space, which can be visited with configurable strides in all dimensions.
 *
 * The multiple loop functionality is partially overlapped by the functionality
 * provided by the microcode processor `hwce_ctrl_ucode` that can be embedded
 * in HWPEs. The latter is much more flexible and smaller, but less fast.
 *
 * One iteration is performed per each cycle when `enable_i` is 1 and the output
 * `addr_o` stream is ready. `presample_i` should be 1 in the first cycle in which
 * the address generator can start generating addresses, and no further.
 * 
 * The address generator first starts with incrementing the lowest dimension and once it 
 * reaches it's length increases the next higher dimension E.g for a three dimensional case
 * (DIMENSIONS = 2) and each having a count of 3:
 * 
 *  Dimension 2   Dimension 1   Dimension 0   Total Count
 *                    
 *            0             0             0             0
 *            0             0             1             1
 *            0             0             2             2 
 *            0             1             0             3
 *            0             1             1             4
 *                                                   ....
 * 
 *                          ^             ^             ^
 *                          |             |             |
 *                          |             |             +---- Count up to tot_len then fininish
 *                          |             |
 *                          |             +---- Count up to stride_i[0].len then 
 *                          |                   increment  next higher dimension
 *                          |
 *                          +---- Count up to stride_i[1].len then
 *                                increment next higher dimension         
 * 
 *   While address = base_address + count[i] * stride[i] for i in dimensions.
 * 
 *   (Internally everything is done with adders and indexes start at one to make unit small, that doesn't affect functionality tho)
 *    
 * .. tabularcolumns:: |l|l|J|
 * .. _hwpe_stream_addressgen_v3_params:
 * .. table:: **hwpe_stream_addressgen_v3** design-time parameters.
 *
 *   +-------------------------+------------------------------------+---------------------------------------------------------------------------------------------+
 *   | **Name**                | **Default**                        | **Description**                                                                             |
 *   +-------------------------+------------------------------------+---------------------------------------------------------------------------------------------+
 *   | *TRANS_CNT*             | 32                                 | Number of bits supported in the transaction counter, which will overflow at 2^ `TRANS_CNT`. |
 *   +-------------------------+------------------------------------+---------------------------------------------------------------------------------------------+
 *   | *CNT*                   | 32                                 | Number of bits supported in non-transaction counters, which will overflow at 2^ `CNT`.      |
 *   +-------------------------+------------------------------------+---------------------------------------------------------------------------------------------+
 *   | *DIMENSIONS*            | 2                                  | Number of extra stride inputs, will affect size of the unit                                 |
 *   +-------------------------+------------------------------------+---------------------------------------------------------------------------------------------+
 *
 * .. tabularcolumns:: |l|l|J|
 * .. _hwpe_stream_addressgen_v4_ctrl:
 * .. table:: **hwpe_stream_addressgen_v4** input control signals.
 *
 *   +----------------------------------+----------------------+-------------------------------------------------------------------------------------------------------------+
 *   | **Name**                         | **Type**             | **Description**                                                                                             |
 *   +----------------------------------+----------------------+-------------------------------------------------------------------------------------------------------------+
 *   | *base_addr*                      | `logic[31:0]`        | Byte-aligned base address of the stream in the HWPE-accessible memory.                                      |
 *   +----------------------------------+----------------------+-------------------------------------------------------------------------------------------------------------+
 *   | *tot_len*                        | `logic[31:0]`        | Total number of transactions in stream; only the `TRANS_CNT` LSB are actually used.                         |
 *   +----------------------------------+----------------------+-------------------------------------------------------------------------------------------------------------+
 *
 * .. tabularcolumns:: |l|l|J|
 * .. _hwpe_stream_addressgen_v4_stride:
 * .. table:: **hwpe_stream_addressgen_v4** input stride control signals.
 *
 *   +----------------------------------+----------------------+------------------------------------------------------------------------------------------------------------------+
 *   | **Name**                         | **Type**             | **Description**                                                                                                  |
 *   +----------------------------------+----------------------+------------------------------------------------------------------------------------------------------------------+
 *   | *enable*                         | `logic`              | Run-time enable for this stride                                                                                  |
 *   +----------------------------------+----------------------+------------------------------------------------------------------------------------------------------------------+
 *   | *len*                            | `logic[31:0]`        | Amount of steps in this dimension before next higher dimension is used (In highest dimension repeat of pattern)  |
 *   +----------------------------------+----------------------+------------------------------------------------------------------------------------------------------------------+
 *   | *stride*                         | `logic[32:0]`        | stride in bytes (signed)                                                                                         |
 *   +----------------------------------+----------------------+------------------------------------------------------------------------------------------------------------------+
 *
 * .. tabularcolumns:: |l|l|J|
 * .. _hwpe_stream_addressgen_v34_flags:
 * .. table:: **hwpe_stream_addressgen_v4** output flags.
 *
 *   +-----------------+------------------+-----------------------------------------------+
 *   | **Name**        | **Type**         | **Description**                               |
 *   +-----------------+------------------+-----------------------------------------------+
 *   | *done*          | `logic`          | 1 when the address generation has finished.   |
 *   +-----------------+------------------+-----------------------------------------------+
 *
 */


import hwpe_stream_package::*;

module hwpe_stream_addressgen_v4
#(
  parameter int unsigned TRANS_CNT  = 32,
  parameter int unsigned CNT        = 32,  // number of bits used within the internal counter
  parameter int unsigned DIMENSIONS = 2
)
(
  // global signals
  input  logic                                   clk_i,
  input  logic                                   rst_ni,
  // local enable and clear
  input  logic                                   enable_i,
  input  logic                                   clear_i,
  input  logic                                   presample_i,
  // generated output address
  hwpe_ieam_intf_ieam.source                     addr_o,
  // control channel
  input  ctrl_addressgen_v4_t                    ctrl_i,
  input  stride_addressgen_v4_t [DIMENSIONS-1:0] stride_i,
  output flags_addressgen_v4_t                   flags_o
);
  
  if (DIMENSIONS < 1) begin: assert_min_1d
    else $fatal(1, "Error in hwpe_stream_addressgen_v4: DIMENSIONS must be at least 1.\n");
  end

  logic                                 done;
  logic [TRANS_CNT-1:0]                 overall_counter_d, overall_counter_q;
  logic [DIMENSIONS-1:0][CNT-1:0]       counter_d, counter_q;
  logic [DIMENSIONS-1:0][31:0]          addr_d, addr_q;
  logic                                 addr_valid_d, addr_valid_q;

  // Helper signal for finding out which counter to increment
  logic                                 counter_active;

  // address generation
  always_comb
  begin : address_gen_counters_comb
    overall_counter_d     = overall_counter_q;
    counter_d             = counter_q;
    addr_d                = addr_q;
    addr_valid_d          = addr_valid_q;
    done = '0;

    if (addr_o.ready) begin
      if (overall_counter_q < ctrl_i.tot_len) begin
        addr_valid_d = 1'b1;

        // Increment dimensional counters
        counter_active = '1;
        for (int unsigned i = 0; i < DIMENSIONS; i++) 
        begin: gen_counters
          // If this counter is enabled and no lower counter is incrementing ...
          if (stride_i[i].enable && counter_active) begin
            // if there is space to increment, do it and stop all higher counters from incrementing
            if (counter_q[i] < stride_i[i].len) begin
              addr_d[i]      = addr_q[i] + stride_i[i].stride ;
              counter_d[i]   = counter_q[i] + 1;
              counter_active = '0;
            end
            // else reset, keep higher counters active
            else begin
              addr_d[i]    = '0;
              counter_d[i] = '1;
            end
          end
        end

        // Increment Overall Counter
        overall_counter_d = overall_counter_q + 1;
      end
      else begin
        addr_valid_d = 1'b0;
        done = 1'b1;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : address_gen_counters_ff
    if (~rst_ni) begin
      overall_counter_q           <= '1;
      addr_valid_q                <= '0;
      for (int i = 0; i < DIMENSIONS; i++)
      begin: gen_reset_default
        counter_q[i]   <= '1;   
        addr_q[i]      <= '0;      
      end 
    end
    else if (clear_i || presample_i) begin
      overall_counter_q           <= '1;
      addr_valid_q                <= presample_i;  // presample_i is just clear but the next cycle is the valid cycle with address 0  
      for (int i = 0; i < DIMENSIONS; i++)
      begin: gen_reset_default
        counter_q[i]   <= '1;   
        addr_q[i]      <= '0;     
      end 
    end
    else if(enable_i) begin
      overall_counter_q           <= overall_counter_d;
      addr_valid_q                <= addr_valid_d;
      addr_q                      <= addr_d;      
      counter_q                   <= counter_d;   
    end
  end

  // Add all adresses in an adder tree
  parameter int ADDENDS    = DIMENSIONS + 2;      // 1x base_address, (n + 1)x stride_address
  parameter int ADDITIONS  = ADDENDS - 1;         // Always one less than addends e.g. x + y -> 2 Addends 1 Addition 
  parameter int TREE_NODES = ADDENDS + ADDITIONS;

  // Array of addresses for tree adder
  logic [TREE_NODES-1:0][31:0]          gen_addr_int;

  // Assign Input Nodes, keep one slot for each addition free
  for (genvar i = 0; i < DIMENSIONS + 1; i++) 
  begin: gen_adder_tree_input
    assign gen_addr_int[ADDITIONS + i]              = addr_q[i];
  end
  assign gen_addr_int[ADDITIONS + DIMENSIONS + 1] = ctrl_i.base_addr;

  // Calculate output
  for (genvar i = 0; i < ADDITIONS; i++) 
  begin: gen_adder_tree
    assign gen_addr_int[i] = gen_addr_int[i * 2 + 1] + gen_addr_int[i * 2 + 2];
  end

  assign addr_o.data  = gen_addr_int[0];
  assign addr_o.ib  = '1;
  assign addr_o.valid = addr_valid_q;

  assign flags_o.done = done;

endmodule // hwpe_stream_addressgen_v4
