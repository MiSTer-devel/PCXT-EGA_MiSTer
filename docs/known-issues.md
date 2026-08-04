# Known issues

Open problems and fixes still awaiting hardware confirmation. Closed work lives
in the git history.

---

## The 8088 core does not close timing

**Status: open, and predates the EGA work.**

The build does not close timing in `clk_100`: around -0.9 ns worst slack and
-30 to -60 ns of total negative slack depending on the corner and the fit.

`clk_100` drives exactly one thing. In [PCXT-EGA.sv](../PCXT-EGA.sv) the net
appears three times — its declaration, the PLL output that produces it, and
`.CORE_CLK(clk_100)` on the `i8088` instance. The whole MCL86 core registers on
it: `mcl86_eu_core` and `biu_max` both use `always @(posedge CORE_CLK_INT)`, so
the microsequencer, the BIU and the prefetch queue are all inside the failing
domain. `clk_chipset`, which carries the 8237, 8259, 8253, `RAM.sv` and
`Peripherals.sv`, closes with margin.

The chipset around the CPU meets timing. The CPU inside it does not.

This entry previously described `clk_100` as "the ascal scaler domain". That was
wrong — the scaler's clock is `clk_100m`, in `sys/sys_top.v` — and the same
mistake is corrected in [max-speed-stability.md](max-speed-stability.md), RC7,
which carries the full analysis.

**It is not known to have caused any reported symptom.** The palette fault that
prompted this to be re-examined turned out to be RC8, the video I/O read path
having no completion handshake, and was fixed there. Closing this domain would
not have fixed it. What the open timing does cost is confidence: while it is
open, an unrelated change can appear to move a symptom at the fastest CPU
speed, because what it actually moves is placement. That happened during the
RC8 investigation and cost real time.

No testbench in this project can see it either. They all model registers as
ideal, so a setup violation is invisible to every one of them; a green bench
rules out a logic bug and says nothing about this.

An attempt to close it — rewriting the EU's ripple adder onto the device carry
chain and flattening the operand multiplexers — took worst slack to -0.205 ns
and total negative slack to -0.33 ns without changing any observed behaviour.
It was not kept, to leave the vendored MCL86 core as it came, but the approach
works and is recorded in RC7.

---

## SD card interface timing

**Status: open, predates the EGA work, and no symptom is known.**

`VCLK_SDIO` does not close either, at around -0.7 ns. These are output paths
from the MMC block to the `SDIO_*` pins, constrained against a virtual 50 MHz
clock declared by the MiSTer framework while the interface itself runs far
below that rate, so this may be an over-constraint rather than a real problem.
Worth comparing against a stock MiSTer core before spending time on it.
