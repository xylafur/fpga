`define assert(signal, value) \
    if (signal !== value) begin\
        $display("ASSERTION FAILED in %m: signal != value");\
        $finish;\
    end

module uart_tb;
    parameter CLK_FREQ_MHZ = 12;
    parameter BAUD         = 1200000;
    parameter divider      = CLK_FREQ_MHZ * 1000000 / BAUD;
    parameter half_divider = CLK_FREQ_MHZ * 1000000 / (2 * BAUD);
    parameter div_cnt      = $clog2(divider);

    reg               clk         = 0;
    reg [div_cnt-1:0] clk_counter = 0;

    reg [7:0]         data;
    reg               rst;
    reg               tx_enable;

    wire              tx_clkpulse;
    wire              tx;
    wire              tx_busy;

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (clk_counter == divider) begin
            clk_counter <= 0;
        end else begin
            clk_counter <= clk_counter + 1;
        end
    end

    uart #(.BAUD(1200000)) myuart (
        .clk(clk),
        .rst(rst),

        .tx(tx),
        .tx_data(data),
        .tx_start(tx_enable),
        .tx_busy(tx_busy),

        // TODO: Update tb to not be based on this, should just count clock cycles
        .tx_clkpulse(tx_clkpulse),

        .rx(),
        .rx_data(),
        .rx_valid(),
        .rx_busy()
    );

    task wait_till_high(
        input signal
    );
        begin
            while (signal == 0) begin
                #5;
            end
        end
    endtask

    integer ii;
    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);
        //$monitor("Time:%0t tx_clkp:%0d rst:%0d txe:%0d busy:%0d tx:%0d data:%c",
        //         $time, tx_clkpulse, rst, tx_enable, tx_busy, tx, data);

        data = 8'h00;
        tx_enable = 0;
        rst = 1;

        #10 rst       = 0;
            data      = "a";
            tx_enable = 1;

        $display("Waiting for Uart TX to go busy");
        while (tx_busy == 0) begin
            #5;
        end

        $display("Waiting for all dummy data to be transmitted");
        for (ii = 0; ii < 15; ii = ii + 1) begin
            while (tx_clkpulse == 0) begin
                #5;
            end
            $display("Time:%0t tx_clkp:%0d rst:%0d txe:%0d busy:%0d tx:%0d data:%c",
                     $time, tx_clkpulse, rst, tx_enable, tx_busy, tx, data);
            // Clkpulse is high for 10 time units
            #10;
        end

        $display("Waiting for Uart TX to go idle");
        while (tx_busy == 1) begin
            #5;
        end

        $display("Waiting for Uart TX to go busy");
        while (tx_busy == 0) begin
            #5;
        end

        $display("Deasserting the enable bit");
        tx_enable = 0;

        $display("Validating data is as expected");
        for (ii = 0; ii < 10; ii = ii + 1) begin
            while (tx_clkpulse == 0) begin
                #5;
            end
            $display("Time:%0t tx_clkp:%0d rst:%0d txe:%0d busy:%0d tx:%0d data:%c",
                     $time, tx_clkpulse, rst, tx_enable, tx_busy, tx, data);
            if (ii == 0) begin
                // Start bit
                `assert(tx, 0);
            end else if (ii == 9) begin
                // Stop bit
                `assert(tx, 1);
            end else begin
                `assert(tx, data[ii-1]);
            end
            // Clkpulse is high for 10 time units
            #10;
        end

        $display("Waiting for Uart TX to go idle");
        while (tx_busy == 1) begin
            #5;
        end

        $display("Time:%0t tx_clkp:%0d rst:%0d txe:%0d busy:%0d tx:%0d data:%c",
                 $time, tx_clkpulse, rst, tx_enable, tx_busy, tx, data);


        $finish;
    end
endmodule
