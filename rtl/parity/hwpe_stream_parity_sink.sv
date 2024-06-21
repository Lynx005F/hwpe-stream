/*
 * hwpe_stream_parity_sink.sv
 * Maurus Item <itemm@student.ethz.ch>
 *
 * Copyright (C) 2024-2024 ETH Zurich, University of Bologna
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
 * The **hwpe_stream_parity_sink** module is used to monitor an input normal
 * stream `normal_i` and compare it with a parity stream `parity_i` which only
 * holds the handshake and one parity bit per strobe element. Together with
 * hwpe_stream_parity_source this allows for low area fault detection on HWPE
 * Streams by building a parity network that matches the original network.
 */

import hwpe_stream_package::*;

module hwpe_stream_parity_sink #(
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned STRB_WIDTH = DATA_WIDTH/8
) (
  input logic                     clk_i,
  input logic                     rst_ni,
  hwpe_stream_intf_stream.monitor normal_i,
  hwpe_stream_intf_stream.sink    parity_i,
  output logic                    fault_detected_o
);

  logic [STRB_WIDTH-1:0] local_parity_data;

  for (genvar i = 0; i < STRB_WIDTH; i++) begin
    assign local_parity_data[i]  = ^normal_i.data[i * DATA_WIDTH/STRB_WIDTH +: DATA_WIDTH/STRB_WIDTH];
  end

  assign parity_i.ready = normal_i.ready;

  logic fault_detected;
  assign fault_detected = (parity_i.valid != normal_i.valid || parity_i.strb != normal_i.strb || parity_i.data != local_parity_data);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      fault_detected_o <= '0;
    end else begin
      fault_detected_o <= fault_detected;
    end
  end

endmodule // hwpe_stream_parity_sink
