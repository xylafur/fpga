`default_nettype none

`define IDLE_STATE     2'h0
`define START_STATE    2'h1
`define TRANSMIT_STATE 2'h2
`define STOP_STATE     2'h3

module write_shift(
    input [7:0] in_data,
    input valid,
    input clk,
    input rst,
    output transmit,
    output out_data
);
    reg stop_cnt;
    reg [1:0] state;
    reg [3:0] bit;
    reg [7:0] data;

    reg transmit_reg, out_data_reg;

    assign transmit = transmit_reg;
    assign out_data = out_data_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= `IDLE_STATE;
            stop_cnt <= 0;
            bit <= 4'h0;
            data <= 8'h00;
            transmit_reg <= 0;
            out_data_reg <= 0;
        end else begin
            case (state)
                // Capture data and transition to start state
                `IDLE_STATE: begin
                    if (valid) begin
                        state <= `START_STATE;
                        data <= in_data;
                    end
                    transmit_reg <= 0;
                    stop_cnt <= 0;
                    bit <= 4'h0;
                end
                // Send start bit, go to next state
                `START_STATE: begin
                    out_data_reg <= 0;
                    transmit_reg <= 1;
                    state <= `TRANSMIT_STATE;
                end
                `TRANSMIT_STATE: begin
                    transmit_reg <= 1;
                    out_data_reg <= data[8 - 1 - bit];
                    bit <= bit + 1;

                    if (bit == 7) begin
                        // We've transmitted all of the data, need to send stop bits
                        state <= `STOP_STATE;
                    end
                end
                `STOP_STATE: begin
                    transmit_reg <= 0;
                    //reset and go back to idle
                    if (stop_cnt == 1) begin
                        state <= `IDLE_STATE;
                    end else begin
                        stop_cnt <= stop_cnt + 1;
                    end

                end
            endcase
        end
    end
endmodule

module transmitter(
    input enable,
    input clk,
    input data,
    output tx
);
    reg tx_reg;
    always @(posedge clk) begin
        if (!enable) begin
            // Hold line high if we are not enabled
            tx_reg <= 1;
        end else begin
            // The write shift module should send the start bit
            tx_reg <= data;
        end
    end
    assign tx = tx_reg;
endmodule

module uart_tx(
    input enable,
    input [7:0] data,
    input clk,
    input rst,
    output active,
    output tx
);
    wire transmitter_enable;
    wire transmitter_out;

    assign active = transmitter_enable;

    write_shift wshifter(.in_data(data), .valid(enable), .clk(clk), .rst(rst),
                         .transmit(transmitter_enable), .out_data(transmitter_out));
    transmitter trans(.enable(transmitter_enable), .clk(clk), .data(transmitter_out), .tx(tx));
endmodule
