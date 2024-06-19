/*
 * hwpe_stream_zero_sink.sv
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
 * The **hwpe_stream_zero_sink** module is used to monitor an input normal 
 * stream `normal_i` and compare it with a zero stream `zero_i` but does not 
 * assign the data, so it can be optimised away.
 * Together with hwpe_stream_zero_source this allows for low area fault detection 
 * on HWPE streams by building a zero network that matches the original network.
 */

import hwpe_stream_package::*;

module hwpe_stream_zero_sink (
  hwpe_stream_intf_stream.monitor   normal_i,
  hwpe_stream_intf_stream.sink      zero_i,
  output logic fault_detected_o
);
  
  assign zero_i.ready = normal_i.ready;

  assign fault_detected_o = (zero_i.valid != normal_i.valid || zero_i.strb != normal_i.strb);

endmodule // hwpe_stream_zero_sink
