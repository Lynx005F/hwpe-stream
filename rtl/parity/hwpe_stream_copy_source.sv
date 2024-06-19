/*
 * hwpe_stream_copy_source.sv
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
 * The **hwpe_stream_copy_source** module is used to monitor an input normal 
 * stream `normal_i` and copy it to an output stream `copy_o`.
 * Together with hwpe_stream_copy_sink this allows for low area fault detection on 
 * HWPE streams by building a copy network that matches the original network.
 */

import hwpe_stream_package::*;

module hwpe_stream_copy_source  (
  hwpe_stream_intf_stream.monitor normal_i,
  hwpe_stream_intf_stream.source  copy_o,
  output logic fault_detected_o
);

  assign copy_o.data = normal_i.data;
  assign copy_o.strb = normal_i.strb;
  assign copy_o.valid = normal_i.valid;
  assign fault_detected_o = normal_i.ready != copy_o.ready;

endmodule // hwpe_stream_copy_source
