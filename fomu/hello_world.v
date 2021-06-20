//--------------------------------------------------------------
//   USB Serial.
//
//   Wrapping usb/usb_uart_ice40.v to output "Hello, I'm FOMU".
//
//--------------------------------------------------------------
//   @brief  FOMU version.
//   @author Juan Manuel Rico.
//--------------------------------------------------------------
//
`default_nettype none

module hello_world (
        input  clki,

        inout  usb_dp,
        inout  usb_dn,
        output usb_dp_pu,

        output rgb0,
        input touch_1
);

    wire clk_48mhz;
    assign clk_48mhz = clki; // FOMU use 48Mhz external clock

    // Generate reset signal
    reg [5:0] reset_cnt = 0;
    wire reset = ~reset_cnt[5];
    always @(posedge clk_48mhz)
        reset_cnt <= reset_cnt + reset;

    // uart pipeline in
    reg [7:0]  uart_in_data;
    reg        uart_in_valid;
    wire       uart_in_ready;

    // uart pipeline out
    wire [7:0] uart_out_data;
    wire       uart_out_valid;
    reg        uart_out_ready;

    // Create the text string
    localparam TEXT_LEN = 16;
    reg [7:0] hello [0:TEXT_LEN-1];
    reg [4:0] char_count;
    initial begin
        hello[0]  <= "H";
        hello[1]  <= "e";
        hello[2]  <= "l";
        hello[3]  <= "l";
        hello[4]  <= "o";
        hello[5]  <= ",";
        hello[6]  <= " ";
        hello[7]  <= "I";
        hello[8]  <= "'";
        hello[9]  <= "m";
        hello[10] <= " ";
        hello[11] <= "F";
        hello[12] <= "O";
        hello[13] <= "M";
        hello[14] <= "U";
        hello[15] <= "\n";
   end

    // send text through the serial port
    localparam DELAY_WIDTH = 26;
    reg [DELAY_WIDTH-1:0] delay_count;

    reg pardon;

    always @(posedge clk_48mhz) begin
        if (reset) begin
            uart_in_valid <= 0;
            delay_count <= 0;
            char_count <= 0;
            pardon <= 0;
        end else begin
            if (char_count < TEXT_LEN) begin
                if (pardon) begin
                    pardon <= 0;
                    uart_in_valid <= 0;
                    char_count <= char_count + 1;
                end else if (uart_in_valid) begin
                    if (!uart_in_ready) begin
                        pardon <= 1;
                    end
                end else begin
                    uart_in_valid <= 1;
                    uart_in_data <= hello[char_count];
                end
            end else begin
                delay_count <= delay_count + 1;
                if (&delay_count) begin
                    char_count <= 0;
                end
            end
        end
    end

    // LED status
    reg [23:0] ledCounter;
    wire led_nonzero = |ledCounter;
    always @(posedge clk_48mhz) begin
        if (led_nonzero || uart_in_valid) begin
            ledCounter <= ledCounter + 1;
        end
    end
    assign rgb0 = led_nonzero;

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

        // uart pipeline out
        .uart_out_data  (uart_out_data),
        .uart_out_valid (uart_out_valid),
        .uart_out_ready (uart_out_ready)

        // debug
        //.debug (debug)
    );

    // USB Host Detect Pull Up
    assign usb_dp_pu = 1'b1;

endmodule
