//--------------------------------------------------------------
//   USB Serial.
//
//   Wrapping usb/usb_uart_ice40.v to create a loopback.
//
//--------------------------------------------------------------
//   @brief  FOMU version.
//   @author Juan Manuel Rico.
//--------------------------------------------------------------
//
module uart_echo (
        input  clki,

        inout  usb_dp,
        inout  usb_dn,
        output usb_dp_pu,

        output rgb1
);

    wire clk_48mhz;
    assign clk_48mhz = clki; // FOMU use 48Mhz external clock

    // LED status
    reg [23:0] ledCounter;
    always @(posedge clk_48mhz) begin
        ledCounter <= ledCounter + 1;
    end
    assign rgb1 = ledCounter[23];

    // Generate reset signal
    reg [5:0] reset_cnt = 0;
    wire reset = ~reset_cnt[5];
    always @(posedge clk_48mhz)
        reset_cnt <= reset_cnt + reset;

    // uart pipeline in
    wire [7:0] uart_in_data;
    wire       uart_in_valid;
    wire       uart_in_ready;

    // usb uart - this instanciates the entire USB device.
    usb_uart uart (
        .clk_48mhz (clk_48mhz),
        .reset     (reset),

        // pins
        .pin_usb_p (usb_dp),
        .pin_usb_n (usb_dn),

        // uart pipeline in
        .uart_in_data  (uart_in_data),
        .uart_in_valid (uart_in_valid),
        .uart_in_ready (uart_in_ready),

        .uart_out_data  (uart_in_data),
        .uart_out_valid (uart_in_valid),
        .uart_out_ready (uart_in_ready)

        // debug
        //.debug (debug)
    );

    // USB Host Detect Pull Up
    assign usb_dp_pu = 1'b1;

endmodule
