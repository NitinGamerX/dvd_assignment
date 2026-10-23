# 4-bit Array Multiplier — RTL to GDSII (SKY130)

Digital VLSI Design team assignment: a 4-bit × 4-bit unsigned array multiplier taken from Verilog RTL through synthesis, static timing analysis, and place and route to a GDSII layout with open-source tools.

## Team

| Name | Roll number |
|---|---|
| Vishnubhotla Nitin Sri Siva Kalyan | 2024112012 |
| Alapati Sai Pavan Adit | 2024102064 |

## Environment

- Docker image: `hpretl/iic-osic-tools:latest` (image ID `306585de35d1`, pulled 2026-10-21)
- PDK: `sky130A`, standard cells `sky130_fd_sc_hd`, set in `~/eda/designs/.designinit`
- All commands are run inside the container from `/foss/designs/mult_array` unless noted

## Part A — RTL design and verification

Files: `rtl/full_adder.v` (full adder with `assign` statements), `rtl/mult_array.v` (16 AND gates, 12 `full_adder` instances, registered inputs and output), `tb/tb_mult.v` (exhaustive self-checking testbench).

Commands, in order:

```bash
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
gtkwave mult.vcd
```

Result:

```
PASS: 256 vectors checked, 0 errors
```

Error-detection test: in `rtl/full_adder.v`, `assign sum = a ^ b ^ cin;` was temporarily changed to `assign sum = a ^ b;` and the two simulation commands above were rerun. The testbench reported mismatches (first: `a=3 b=3 expected=9 got=5`) and the summary:

```
FAIL: 256 vectors checked, 95 errors
```

The change was reverted with `git checkout -- rtl/full_adder.v`, and the testbench printed PASS again.

Worked example: A = 7, from the last digit of roll number 2024112012 (Vishnubhotla Nitin Sri Siva Kalyan) plus 5. Since A = 7, B = 9. Expected product 7 × 9 = 63. In the waveform, `b` changes to 9 at 3650 ns, the inputs are registered at the rising edge at 3655 ns, and `p` becomes 63 at the rising edge at 3665 ns: a latency of 2 clock cycles.

## Part B — Logic synthesis

## Part C — Static timing analysis

## Part D — Physical design