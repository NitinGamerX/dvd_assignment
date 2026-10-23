`timescale 1ns / 1ps

module tb_mult;
    reg        clk, rst_n;
    reg  [3:0] a, b;
    wire [7:0] p;
    reg  [7:0] expected;
    integer    i, j, errors, vectors;

    mult_array dut (.clk(clk), .rst_n(rst_n), .a(a), .b(b), .p(p));

    // 10 ns clock period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);
        errors = 0; vectors = 0; a = 0; b = 0;

        // Hold reset low for the first 2 clock cycles
        rst_n = 0;
        #20 rst_n = 1;

        // Exhaustive test: all 256 input combinations
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                @(negedge clk);                 // apply inputs away from the rising edge
                a = i[3:0];
                b = j[3:0];
                expected = i * j;               // * is allowed in the testbench only
                @(negedge clk);                 // rising edge 1: inputs registered
                @(negedge clk);                 // rising edge 2: product registered
                if (p !== expected) begin
                    $display("Mismatch: a=%0d b=%0d expected=%0d got=%0d", a, b, expected, p);
                    errors = errors + 1;
                end
                vectors = vectors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: %0d vectors checked, 0 errors", vectors);
        else
            $display("FAIL: %0d vectors checked, %0d errors", vectors, errors);
        $finish;
    end
endmodule