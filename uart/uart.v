module uart #(
    parameter CLK_FREQ_MHZ = 12,
    parameter BAUD         = 9600
) (
    input        clk,
    input        rst,

    input        rx,
    output [7:0] rx_data,
    output       rx_valid,
    output       rx_busy,

    output       tx,
    input  [7:0] tx_data,
    input        tx_start,
    output       tx_busy,
    output       tx_clkpulse, // TODO: Should be removed, but TB uses it
);
    parameter divider      = CLK_FREQ_MHZ * 1000000 / BAUD;
    parameter half_divider = CLK_FREQ_MHZ * 1000000 / (2 * BAUD);
    parameter div_bits     = $clog2(divider);

    // Receiver
    reg [7:0] rx_state                       = 0;
    reg [$clog2(divider):0] rx_clk_counter   = 0;
    reg [7:0] rx_data_buffer                 = 0;
    reg       rx_buf_valid                   = 0;

    assign rx_data  = rx_data_buffer;
    assign rx_valid = rx_buf_valid;
    assign rx_busy  = rx_state == 0 ? 0 : 1;

    always @(posedge clk) begin
        if (rst) begin
            rx_data_buffer <= 8'h00;
            rx_buf_valid   <= 0;
            rx_state       <= 2'h0;
            rx_clk_counter <= 5'h00;

        end else begin
            rx_clk_counter <= rx_clk_counter + 1;
            case (rx_state)
                0: begin       // Waiting for start bit
                    rx_buf_valid   <= 0;
                    if (rx == 0) begin
                        rx_state       <= rx_state + 1;
                        rx_data_buffer <= 8'h00;
                    end
                end
                1: begin      // Counting start bit
                    if (rx_clk_counter > divider/2) begin
                        rx_state       <= rx_state + 1;
                        rx_clk_counter <= 0; // reset the clock counter so we poll halfway through data
                    end
                end
                10: begin     // Counting stop bit
                    if (rx_clk_counter > divider) begin
                        rx_buf_valid   <= 1;
                        rx_state       <= 0;
                        rx_clk_counter <= 0;
                    end
                end
                default begin // Sampling data bits
                    // sampling in the middle of the data, comes from divider/2 in state 1
                    if (rx_clk_counter > divider) begin
                        rx_state       <= rx_state + 1;
                        rx_data_buffer <= {rx, rx_data_buffer[7:1]};
                        rx_clk_counter <= 0;
                    end
                end
            endcase
        end
    end

    // Transmitter
    reg [div_bits-1:0] tx_div_cnt = 0;
    reg [9:0]          tx_buffer  = 10'h3ff;
    reg                dummy      = 0;
    reg [7:0]          bitcnt     = 0;

    assign tx          = tx_buffer[0];
    assign tx_busy     = bitcnt > 0 ? 1 : 0;
    assign tx_clkpulse = tx_busy && tx_div_cnt == 0;

    always @(posedge clk) begin
        if (rst) begin
            dummy      <= 1;
            tx_div_cnt <= 0;
            tx_buffer  <= ~0;
            bitcnt     <= 0;

        end else begin
            if (dummy == 1) begin
                dummy  <= 0;
                bitcnt <= 15;
            end else if (tx_div_cnt == divider) begin
                if (bitcnt == 0 && tx_start) begin
                    tx_buffer <= {1'b1, tx_data[7:0], 1'b0};
                    bitcnt    <= 10;
                end else if (bitcnt > 0) begin
                    bitcnt    <= bitcnt - 1;
                    tx_buffer <= {1'b1, tx_buffer[9:1]};
                end

                tx_div_cnt <= 0;
            end else begin
                tx_div_cnt <= tx_div_cnt + 1;
            end
        end
    end
endmodule
