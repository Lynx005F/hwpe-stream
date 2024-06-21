/*
 * hwpe_stream_zero_source.sv
 * Maurus Item <itemm@student.ethz.ch>
 *
 * Copyright (C) 2024-2024 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a zero of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */

/**
 * The **hwpe_stream_zero_source** module is used to monitor an input normal
 * stream `normal_i` and zero it to an output stream `zero_o` but does not
 * assign the data, so it can be optimised away.
 * Together with hwpe_stream_zero_sink this allows for low area fault detection on
 * HWPE streams by building a zero network that matches the original network.
 */

import hwpe_stream_package::*;

module hwpe_stream_zero_source  (
  input logic                     clk_i,
  input logic                     rst_ni,
  hwpe_stream_intf_stream.monitor normal_i,
  hwpe_stream_intf_stream.source  zero_o,
  output logic                    fault_detected_o
);

  assign zero_o.strb = normal_i.strb;
  assign zero_o.valid = normal_i.valid;

  logic fault_detected;
  assign fault_detected = normal_i.ready != zero_o.ready;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      fault_detected_o <= '0;
    end else begin
      fault_detected_o <= fault_detected;
    end
  end

endmodule // hwpe_stream_zero_source
