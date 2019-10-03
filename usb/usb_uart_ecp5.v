/*
  usb_uart_ecp5

  Simple wrapper around the usb_uart which incorporates the Pin driver logic
  so this doesn't clutter the top level circuit

  Make the signature generic (usb_uart) and rely on the file inclusion process (makefile)
  to bring the correct architecture in

  ----------------------------------------------------
  usb_uart u_u (
    .clk_48mhz  (clk_48mhz),
    .reset      (reset),

    // pins
    .pin_usb_p( pin_usb_p ),
    .pin_usb_n( pin_usb_n ),

    // uart pipeline in (w.r.t module)
    .pipe_in( pipe_in )

    // uart pipeline out (w.r.t. module)
    .pipe_out( pipe_out )
  );

  Utilization

    707 LUTs?

*/

`include "../../pipe/rtl/pipe_defs.v"

module usb_uart  #( parameter PipeSpec = `PS_d8 ) (
        input  clk_48mhz,
        input reset,

        // USB pins
        inout  pin_usb_p,
        inout  pin_usb_n,

        inout [`P_m(PipeSpec):0] pipe_in,
        inout [`P_m(PipeSpec):0] pipe_out,

        output [11:0] debug
    );

    wire [`P_Data_m(PipeSpec):0] in_data;
    wire                     in_valid;
    wire                     in_ready;

    wire [`P_Data_m(PipeSpec):0] out_data;
    wire                     out_valid;
    wire                     out_ready;

    p_unpack_data #( .PipeSpec( PipeSpec ) ) in_unpack_data( .pipe(pipe_in), .data(in_data) );
    p_unpack_valid_ready #( .PipeSpec( PipeSpec ) ) in_unpack_valid_ready( .pipe(pipe_in), .valid(in_valid), .ready(in_ready) );

    // start and stop signals are ignored - packetization has to be escaped
    usb_uart_np  u_u_np(
            clk_48mhz, reset,

            pin_usb_p, pin_usb_n,

            in_data, in_valid, in_ready,
            out_data, out_valid, out_ready,

            debug
        );

    p_pack_data #( .PipeSpec( PipeSpec ) ) out_pack_d( .data(out_data), .pipe(pipe_out) );
    p_pack_valid_ready #( .PipeSpec( PipeSpec ) ) out_pack_vr( .valid(out_valid), .ready(out_ready), .pipe(pipe_out) );

endmodule

module usb_uart_np (
  input  clk_48mhz,
  input reset,

  // USB pins
  inout  pin_usb_p,
  inout  pin_usb_n,

  // uart pipeline in (out of the device, into the host)
  input [7:0] uart_in_data,
  input       uart_in_valid,
  output      uart_in_ready,

  // uart pipeline out (into the device, out of the host)
  output [7:0] uart_out_data,
  output       uart_out_valid,
  input        uart_out_ready,

  output [11:0] debug
);

    wire usb_p_tx;
    wire usb_n_tx;
    wire usb_p_rx;
    wire usb_n_rx;
    wire usb_tx_en;

    // wire [11:0] debug_dum;

    usb_uart_core_np u_u_c_np (
        .clk_48mhz  (clk_48mhz),
        .reset      (reset),

        // pins - these must be connected properly to the outside world.  See below.
        .usb_p_tx(usb_p_tx),
        .usb_n_tx(usb_n_tx),
        .usb_p_rx(usb_p_rx),
        .usb_n_rx(usb_n_rx),
        .usb_tx_en(usb_tx_en),

        // uart pipeline in
        .uart_in_data( uart_in_data ),
        .uart_in_valid( uart_in_valid ),
        .uart_in_ready( uart_in_ready ),

        // uart pipeline out
        .uart_out_data( uart_out_data ),
        .uart_out_valid( uart_out_valid ),
        .uart_out_ready( uart_out_ready ),

        .debug( debug )
    );

    wire usb_p_in;
    wire usb_n_in;

    assign usb_p_rx = usb_tx_en ? 1'b1 : usb_p_in;
    assign usb_n_rx = usb_tx_en ? 1'b0 : usb_n_in;

	// T = TRISTATE (not transmit)
	BB io_p( .I( usb_p_tx ), .T( !usb_tx_en ), .O( usb_p_in ), .B( pin_usb_p ) );
	BB io_n( .I( usb_n_tx ), .T( !usb_tx_en ), .O( usb_n_in ), .B( pin_usb_n ) );

endmodule
