// Cause yosys to throw an error when we implicitly declare nets
`default_nettype none


// Project entry point
module top (
    input BTN1,
    input CLK,

    input  RX,
    output TX,

    output reg LED1
);
    reg       rst = 0;

    reg [7:0] tx_data = 8'h41;
    reg       tx_start = 0;
    wire      tx_busy;

    wire [7:0] rx_data;
    wire       rx_valid;
    wire       rx_busy;

    reg rx_captured = 0;
    reg [7:0] buffer = 8'h00;

    always @(posedge CLK) begin
        if (tx_busy == 1 && tx_start == 1) begin
            tx_start <= 0;

        end else if (rx_valid == 1 && rx_captured == 0) begin
            rx_captured <= 1;
            buffer <= rx_data;

        end else if (rx_captured == 1) begin
            if (tx_busy == 0 && tx_start == 0) begin
                tx_data  <= buffer;
                tx_start <= 1;
                rx_captured <= 0;
            end
        end

        if (BTN1 == 1) begin
            rst <= 1;
        end else begin
            rst <= 0;
        end

        if (rst == 1) begin
            LED1 <= 1;
        end else begin
            LED1 <= 0;
        end
    end

    uart myuart(.clk(CLK), .rst(rst),
                .tx(TX), .tx_data(tx_data), .tx_start(tx_start), .tx_busy(tx_busy),
                .rx(RX), .rx_data(rx_data), .rx_valid(rx_valid), .rx_busy(rx_busy));
endmodule
