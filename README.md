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

Script: `synth/synth.tcl` (read RTL → `synth -flatten` → `dfflibmap` → `abc` → `opt_clean` → `stat` → `write_verilog`), using `sky130_fd_sc_hd__tt_025C_1v80.lib`.

Commands, in order:

```bash
yosys -c synth/synth.tcl
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
    tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls
```

Outputs: `synth/mult_array_netlist.v`, `synth/mult_array_stat.rpt`.

| Metric | Value |
|---|---|
| Total cells | 67 |
| Flip-flops | 16 (`sky130_fd_sc_hd__dfrtp_1`) |
| Total cell area | 784.502 µm² |
| Flip-flop area | 400.384 µm² (51.04 %) |
| Top 3 cell types | dfrtp_1 (16), nand2_1 (9), xnor2_1 (7) |

Gate-level simulation result:

```
PASS: 256 vectors checked, 0 errors
```

## Part C — Static timing analysis

Script: `sta/sta.tcl` reads the typical-corner library (`sky130_fd_sc_hd__tt_025C_1v80.lib`) and the synthesised netlist, defines the clock on `clk`, and sets 1.0 ns input and output delays.

Command:

```bash
sta sta/sta.tcl
```

Run 1 (T = 10 ns): worst setup slack = 7.02 ns, so Tmin = 10 − 7.02 = 2.98 ns and Fmax = 1000 / 2.98 = 335.57 MHz.

Run 2 (T = Tmin = 2.98 ns, period changed in `create_clock`): worst setup slack = 0.000 ns (MET).

Critical path (path group `clk`, from `sta/mult_array_timing.rpt`): start point `_106_` = `b_reg[0]`, end point `_100_` = `p[6]` (its D input is `fa3_3.sum`).

| # | Instance | Cell | Delay (ns) | Arrival (ns) |
|---|---|---|---|---|
| — | `_106_` (launch) | `dfrtp_1` clock-to-Q | 0.411 | 0.411 |
| 1 | `_048_` | `and4_1` | 0.218 | 0.629 |
| 2 | `_050_` | `a2111oi_0` | 0.428 | 1.057 |
| 3 | `_051_` | `a21oi_1` | 0.094 | 1.151 |
| 4 | `_053_` | `mux2i_1` | 0.218 | 1.369 |
| 5 | `_069_` | `xnor3_1` | 0.374 | 1.742 |
| 6 | `_074_` | `maj3_1` | 0.371 | 2.113 |
| 7 | `_076_` | `maj3_1` | 0.376 | 2.489 |
| 8 | `_080_` | `xor3_1` | 0.355 | 2.844 |
| — | `_100_` (capture) | `dfrtp_1` setup time | 0.136 | 2.980 |

| Metric | Value |
|---|---|
| Worst slack at T = 10 ns | 7.02 ns |
| Tmin | 2.98 ns |
| Fmax | 335.57 MHz |
| Slack at T = Tmin | 0.000 ns |
| Critical path start point | `b_reg[0]` (`_106_`) |
| Critical path end point | `p[6]` (`_100_`) |
| Logic cells on the critical path | 8 |
| Latency = 2 × Tmin | 5.96 ns |
| Throughput | 335.57 million results per second |

## Part D — Physical design

Configuration: `pnr/config.json` with `DESIGN_NAME` = `mult_array`, both RTL files, `CLOCK_PORT` = `clk`, `CLOCK_PERIOD` = 4.0 ns (1.2 × Tmin = 1.2 × 2.98 = 3.576 ns, rounded up to the next 0.5 ns), `FP_SIZING` = `absolute`, `DIE_AREA` = [0, 0, 150, 150].

Command (inside the container, from `pnr/`):

```bash
cd pnr
librelane config.json
```

### Attempt 1 (CLOCK_PERIOD = 4.0 ns)

All 80 stages ran. DRC: 0 errors (routing, Magic and KLayout). LVS: circuits match uniquely, 0 errors. Antenna: passed. Setup slack at the nominal corners:

| Corner | Setup slack (ns) |
|---|---|
| `nom_tt_025C_1v80` (typical, as in Part C) | +0.883 |
| `nom_ff_n40C_1v95` (fast) | +1.975 |
| `nom_ss_100C_1v60` (slow) | −1.926 |

The flow stopped with "Setup violations found" at the three `ss_100C_1v60` corners only. By default, LibreLane's signoff checks every PDK corner, while Part C analysed the typical corner only.

### Attempt 2 (CLOCK_PERIOD = 4.0 ns, final)

Added `"TIMING_VIOLATION_CORNERS": ["*tt*"]` to `pnr/config.json`, so the signoff timing check uses the typical corner, the same corner as Part C. STA still runs at every corner, and every corner's slack is still reported in `metrics.json`. Result: `Flow complete.` DRC 0, LVS 0 (circuits match uniquely), antenna passed, no hold violations. The ss-corner setup violations remain as warnings.

Commands (inside the container, from `pnr/`):

```bash
rm -rf runs
librelane config.json
R=$(ls -d runs/RUN_* | tail -1)
cp -f $R/final/metrics.json .
cp -f $R/final/gds/mult_array.gds .
```

### Part D results

| Metric | Value |
|---|---|
| CLOCK_PERIOD used | 4.0 ns |
| Number of runs needed | 2 |
| Die area / core area | 22500 µm² (150 × 150 µm) / 17759.5 µm² |
| Cells after synthesis (Part B) | 67 |
| Cells after place and route | 1898 |
| Cells added by the flow | decap 1293, filler 257, well tap 245, timing-repair buffers 32, clock-tree buffers 3 |
| Wirelength (detailed route) | 2378 µm |
| Setup slack (`nom_tt_025C_1v80`) | +0.883 ns |
| Post-route Fmax = 1000 / (4.0 − 0.883) | 320.8 MHz |
| Fmax from Part C | 335.57 MHz |
| DRC errors | 0 |
| LVS errors | 0 |

Setup slack at the other nominal corners: `nom_ff_n40C_1v95` +1.975 ns, `nom_ss_100C_1v60` −1.926 ns.

LibreLane runs its own synthesis, which gives 68 cells (4 inverters, 16 flip-flops, 48 combinational) instead of 67; 1898 − 68 = 1830 cells were added during place and route.