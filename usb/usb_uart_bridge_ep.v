/*
    usb_uart_bridge_ep

    This is the endpoint to uart translator.  Two things to highlight:  the directions
    IN and OUT are set with respect to the HOST, and also the HOST runs all
    endpoint interactions.

    Pins

    The out endpoint interface.  This is the out w.r.t. the host, hence in to
    us.  There are request grant, data available and data get signals, stall and
    acked signals.  And the data itself.

    The in endpoint interface.  This is the in w.r.t. the host, hence out to us.
    This interface also has a req and grant.  There's a put signal and a free
    signal.  Stall and acked.  And the data.

    To get data in and out there are two pipeline interfaces - one in and one out.

    ToDo

    The arbitration code to mux the senders and receivers is combinatorial logic,
    not latched, so a cycle doesn't need to be spent on them.

        wire uart_byte_out_xfr_ready = out_ep_grant && out_ep_data_avail;
        wire uart_byte_in_xfr_ready = in_ep_grant && in_ep_data_free;

    We can just test this one thing.  Note this means we do not have to release it.

    In the original, endpoints are used to read and write at the same time (SPI traffic)
    so it is certainly possible.  It looks like they're even doing single cycle
    stuff, so there's some magic happening that we're not doing here.  Sadly a lot
    of the flow is implemented in combinatorial logic without training wheel
    comments so it's a little opaque to the uninitiated.

*/

module usb_uart_bridge_ep (
  input clk,
  input reset,

  ////////////////////
  // out endpoint interface
  ////////////////////
  output out_ep_req,               // request the data interface for the out endpoint
  input out_ep_grant,              // data interface granted
  input out_ep_data_avail,         // flagging data available to get from the host
  input out_ep_setup,              // [setup packet sent? - not used here]
  output out_ep_data_get,          // request to get the data - note this takes 2 cycles
  input [7:0] out_ep_data,         // data from the host
  output out_ep_stall,             // an output enabling the device to stop inputs
  input out_ep_acked,              // indicating that the outgoing data was acked

  ////////////////////
  // in endpoint interface
  ////////////////////
  output in_ep_req,                // request the data interface for the in endpoint
  input in_ep_grant,               // data interface granted
  input in_ep_data_free,           // end point is ready for data
  output in_ep_data_put,           // forces end point to read our data
  output [7:0] in_ep_data,         // data back to the host
  output in_ep_data_done,          // signalling that we're done sending data
  output in_ep_stall,              // an output enabling the device to stop outputs
  input in_ep_acked,               // indicating that the outgoing data was acked

  // uart pipeline in
  input [7:0] uart_in_data,
  input       uart_in_valid,
  output      uart_in_ready,

  // uart pipeline out
  output [7:0] uart_out_data,
  output       uart_out_valid,
  input        uart_out_ready,

  output [3:0] debug
);

  // We don't stall
  assign out_ep_stall = 1'b0;
  assign in_ep_stall = 1'b0;

  // Registers for the out pipeline (out of the module)
  reg [7:0] uart_out_data_reg;
  reg [7:0] uart_out_data_overflow_reg;
  reg       uart_out_valid_reg;

  // registers for the out end point (out of the host)
  reg       out_ep_req_reg;
  reg       out_ep_data_get_reg;

  // out pipeline / out endpoint state machine state (6 states -> 3 bits)
  reg [2:0] pipeline_out_state;

  localparam PipelineOutState_Idle         = 0;
  localparam PipelineOutState_WaitData     = 1;
  localparam PipelineOutState_GetData      = 2;
  localparam PipelineOutState_PushData     = 3;
  localparam PipelineOutState_Overflow     = 4;
  localparam PipelineOutState_WaitPipeline = 5;

  // connect the pipeline registers to the outgoing pins
  assign uart_out_data = uart_out_data_reg;
  assign uart_out_valid = uart_out_valid_reg;

  // connect the end point registers to the outgoing pins
  assign out_ep_req = ( out_ep_req_reg || out_ep_data_avail );

  wire out_granted_data_available;

  assign out_granted_data_available = out_ep_req && out_ep_grant;

  assign out_ep_data_get = out_ep_data_get_reg;

  // Handle the bus requesting and granting combinatorially
  // ... someday

  // do HOST OUT, DEVICE IN, PIPELINE OUT (!)
  always @(posedge clk) begin
      if ( reset ) begin
          pipeline_out_state <= PipelineOutState_Idle;
          uart_out_data_reg <= 0;
          uart_out_valid_reg <= 0;
          out_ep_req_reg <= 0;
          out_ep_data_get_reg <= 0;
      end else begin
          case( pipeline_out_state )
              PipelineOutState_Idle: begin
                  // waiting for pipeline ready and waiting for a character and bus granted
                  if ( out_granted_data_available ) begin
                      out_ep_data_get_reg <= 1;
                      out_ep_req_reg <= 1;
                      // now wait for the data to set up
                      pipeline_out_state <= PipelineOutState_WaitData;
                  end
              end
              PipelineOutState_WaitData: begin
                  uart_out_valid_reg <= 0;
                  // it takes one cycle for the juices to start flowing
                  pipeline_out_state <= PipelineOutState_PushData;
              end
              // PipelineOutState_GetData: begin
              //     uart_out_data_reg <= out_ep_data;
              //     uart_out_valid_reg <= 1;
              //     pipeline_out_state <= PipelineOutState_PushData;
              // end
              PipelineOutState_PushData: begin
                  // now we really have got some data
                  uart_out_data_reg <= out_ep_data;
                  uart_out_valid_reg <= 1;
                  // But what's next?
                  if ( uart_out_ready ) begin
                      // We continue!
                      // but what if there's no more?
                      if ( ~out_ep_data_avail ) begin
                          // stop streaming, now just going to wait until the character is accepted
                          out_ep_data_get_reg <= 0;
                          pipeline_out_state <= PipelineOutState_WaitPipeline;
                      end
                  end else begin
                      // hold the sender up
                      out_ep_data_get_reg <= 0;
                      // go to overflow state
                      if ( ~out_ep_data_avail ) begin
                          pipeline_out_state <= PipelineOutState_WaitPipeline;
                      end else begin
                          pipeline_out_state <= PipelineOutState_Overflow;
                      end
                  end
              end
              PipelineOutState_Overflow: begin
                  if ( uart_out_ready ) begin
                      uart_out_valid_reg <= 0;
                      out_ep_data_get_reg <= 1;
                      pipeline_out_state <= PipelineOutState_PushData;
                  end
              end
              PipelineOutState_WaitPipeline: begin
                  // unhand the bus (don't want to block potential incoming) - be careful, this works instantly!
                  out_ep_req_reg <= 0;
                  if ( uart_out_ready ) begin
                      uart_out_valid_reg <= 0;
                      pipeline_out_state <= PipelineOutState_Idle;
                  end

              end

          endcase
      end
  end

  reg [7:0] pipeline_in_data;

  // in pipeline ready register
  reg       uart_in_ready_reg;

  // in endpoint control & data registers
  reg       in_ep_req_reg;
  reg       in_ep_data_put_reg;
  reg       in_ep_data_done_reg;
  reg [7:0] in_ep_data_reg;

  // in pipeline / in endpoint state machine state (5 states -> 3 bits)
  reg [2:0] pipeline_in_state;

  localparam PipelineInState_InHoldOff = 0;
  localparam PipelineInState_Idle      = 1;
  localparam PipelineInState_WaitBus   = 2;
  localparam PipelineInState_WaitData  = 3;
  localparam PipelineInState_CycleData = 4;
  localparam PipelineInState_WaitEP    = 5;

  // connect the pipeline register to the outgoing pin
  assign uart_in_ready = uart_in_ready_reg;

  // connect the end point registers to the outgoing pins
  assign in_ep_req = ( uart_in_valid && in_ep_data_free ) || in_ep_req_reg;

  wire in_granted_in_valid = in_ep_grant && uart_in_valid;

  assign in_ep_data_put = in_ep_data_put_reg;
  assign in_ep_data_done = in_ep_data_done_reg;
  assign in_ep_data = in_ep_data_reg;

  //eg uart_in_valid_fake;
  reg [12:0] in_hold_off;

  // do PIPELINE IN, Device OUT, Host IN
  always @(posedge clk) begin
      //uart_in_valid_fake <= 0;
      if ( reset ) begin
          // pipeline_in_state <= PipelineInState_Idle;
          pipeline_in_state <= PipelineInState_InHoldOff;
          // pipeline_in_data <= 0;
          uart_in_ready_reg <= 0;
          in_ep_req_reg <= 0;
          in_ep_data_put_reg <= 0;
          in_ep_data_done_reg <= 0;
          in_ep_data_reg <= 0;
          in_hold_off <= 0;
      end else begin
          case( pipeline_in_state )
              PipelineInState_InHoldOff:  begin
              uart_in_ready_reg <= 0;
                in_hold_off <= in_hold_off + 1;
                if ( in_hold_off[ 12 ] )
                    pipeline_in_state <= PipelineInState_Idle;
              end
              PipelineInState_Idle: begin
                  uart_in_ready_reg <= 1;
                  in_ep_data_done_reg <= 0;
                  // what if the bus was NOT granted... need to catch the lost char
                  if ( in_granted_in_valid  ) begin
                      // confirm request bus - this will hold the request up until we're done with it
                      in_ep_req_reg <= 1;

                      // data is valid
                      in_ep_data_reg <= uart_in_data;
                      in_ep_data_put_reg <= 1;

                      pipeline_in_state <= PipelineInState_CycleData;
                  end
              end
              PipelineInState_CycleData: begin

                  if  (uart_in_valid ) begin
                      // got the bus put data
                      // data is valid
                      in_ep_data_reg <= uart_in_data;

                      if ( ~in_ep_data_free ) begin
                          // we have this extra byte now
                          uart_in_ready_reg <= 0;

                          in_ep_data_put_reg <= 1;

                          // no need to "DONE" now
                          in_ep_data_done_reg <= 1;

                          pipeline_in_state <= PipelineInState_WaitEP;
                      end

                  end else begin
                      // signal that we're now done reading / writing
                      uart_in_ready_reg <= 0;

                      in_ep_data_put_reg <= 0;

                      in_ep_data_done_reg <= 1;

                      pipeline_in_state <= PipelineInState_WaitEP;
                 end
              end
              PipelineInState_WaitEP: begin
                  in_ep_data_put_reg <= 0;
                  in_ep_data_done_reg <= 0;

                  // back to idle
                  pipeline_in_state <= PipelineInState_Idle;
                  // release the bus
                  in_ep_req_reg <= 0;
              end
          endcase
      end
  end


  // Debug port
  // output debug data
  // assign debug = { /*in_ep_data_done,*/ in_ep_data_put_reg, in_ep_req_reg, uart_in_valid, uart_in_ready };  // this has worked GREAT
  // in & pipeline debug data
  // assign debug = { uart_in_valid, uart_out_valid_reg, out_ep_data_get_reg, out_ep_data_avail };
  // in debug data
  // assign debug = { uart_out_ready, out_ep_data_get, out_ep_grant, out_ep_data_avail }; // unhappy
  // (worked) assign debug = { 1'b0, out_ep_data_get, out_ep_grant, out_ep_data_avail };
  // assign debug = { uart_in_ready, out_ep_data_get, out_ep_grant, out_ep_data_avail };  // this has worked (port there... missing some daata?)
  // assign debug = 0;  // this has worked (port there... missing some daata?) // this has also resulted in no port

  // assign debug = { /*in_ep_data_done,*/ in_ep_data_put_reg, in_ep_req_reg, uart_in_valid, uart_in_ready }; // works great
  // assign debug = { /*in_ep_data_done,*/ in_ep_data_put_reg, in_ep_req_reg, uart_in_valid, 1'b0 }; // works great
  // assign debug = { /*in_ep_data_done,*/ in_ep_data_put_reg, in_ep_req_reg, 2'b00 }; // works great
  // assign debug = { /*in_ep_data_done,*/ in_ep_data_put_reg, 3'b000 };   // works great
  //  assign debug = {  out_ep_req_reg, out_ep_data_avail, reset, clk };
  // assign debug = {  4'b0000 }; // No serial port
  // assign debug = {  1'b0, pipeline_in_state };  // works great

  // post creating debug buffers.
  // assign debug = {  pipeline_out_state };
  // assign debug = {  4'b0000 }; // Serial port! Data a little crappy (glitch on full)

  // post fixing the loops (nothing works!)

  // assign debug = { 1'b0, uart_out_valid_reg, out_ep_req, out_ep_data_avail };
  assign debug = { 1'b0, uart_out_valid_reg, out_granted_data_available, out_ep_data_avail };


endmodule
