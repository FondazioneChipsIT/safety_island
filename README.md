# Safety Island

This IP contains a safety island, designed for the [Carfield](https://github.com/pulp-platform/carfield) project. It consists of a Triple-Core Lockstep (TCLS)  CV32RT core and two memory banks. To interface with the rest of the SoC, it has both an AXI input and an AXI output port, as well as an optional wrapper with CDCs and synchronizers for all relevant nets.

The safety island, as well as [Carfield](https://github.com/pulp-platform/carfield), is developed as part of the PULP project, a joint effort between ETH Zurich and the University of Bologna.

## Architecture

![Block Diagram](doc/carfield_safety_ss.drawio.svg)

## Configuration

The safety island offers several configuration options for integration into an SoC.

Many configurations are in the configuration object:

| Parameter           | Default          | Function                                              |
|---------------------|------------------|-------------------------------------------------------|
| `HartId`            | `8`              | Core's Hart ID                                        |
| `BankNumBytes`      | `32'h0001_0000`  | Number of bytes in a memory bank                      |
| `NumBanks`          | `2`              | Number of memory banks in the island                  |
| `PulpJtagIdCode`    | `32'h1_0000_db3` | Debug module ID code                                  |
| `NumTimers`         | `1`              | CV32RT: Number of Timers (currently only 1 supported) |
| `UseClic`           | `1`              | Use CLIC of legacy CLINT                              |
| `ClicIntCtlBits`    | `8`              | Number of bits for level-priority encoding in CLIC    |
| `UseSSClic`         | `0`              | Enable Supervisor mode for CLIC                       |
| `UseUSClic`         | `0`              | Enable User mode for CLIC                             |
| `UseVSClic`         | `0`              | Enable Virtual Supervisor mode for CLIC               |
| `NVsCtxts`          | `0`              | CLIC: Number of virtual contexts supported            |
| `UseVSPrio`         | `0`              | CLIC: Enable virtual supervisor prioritization        |
| `UseFastIrq`        | `1`              | Use CV32RT with fast interrupt extension              |
| `UseFpu`            | `1`              | Enable FPU                                            |
| `UseIntegerCluster` | `0`              | Make CV32 aware of an external integer cluster        |
| `UseXPulp`          | `1`              | CV32: Enable PULP extensions                          |
| `UseZfinx`          | `1`              | CV32: Use ZFinX extension                             |
| `UseTCLS`           | `1`              | Enable Triple-Core LockStep                           |
| `NumInterrupts`     | `64`             | Number of input interrupts to the safety island       |
| `NumMhpmCounters`   | `1`              | CV32: Number of performance counters                  |

Some configurations are in the top-level module:

| Parameter           | Function                                                                 |
|---------------------|--------------------------------------------------------------------------|
| `GlobalAddrWidth`   | Global address width of SoC                                              |
| `BaseAddr`          | Base address of the safety island                                        |
| `AddrRange`         | Address range of the safety island                                       |
| `MemOffset`         | Address offset of the memory in the island                               |
| `PeriphOffset`      | Address offset of the peripherals in the island                          |
| `NumDebug`          | Number of external debug lines from safety island debug module           |
| `SelectableHarts`   | Selectable modules for external debug                                    |
| `HartInfo`          | Hart information about external debug                                    |
| `AxiUserAtop`       | Enable AXI ATOP to use User bits for ID                                  |
| `AxiUserAtopMsb`    | MSB of AXI ATOP User ID                                                  |
| `AxiUserAtopLsb`    | LSB of AXI ATOP User ID                                                  |
| `AxiUserEccErr`     | Enable AXI ECC error signal on user bits                                 |
| `AxiUserEccErrBit`  | Bit for AXI ECC error                                                    |
| `AxiDataWidth`      | Data width for AXI bus (in and out)                                      |
| `AxiAddrWidth`      | AXI address width                                                        |
| `AxiInputIdWidth`   | AXI ID width for input connection                                        |
| `AxiUserWidth`      | AXI User width                                                           |
| `axi_input_req_t`   | AXI input request type                                                   |
| `axi_input_resp_t`  | AXI input response type                                                  |
| `AxiOutputIdWidth`  | AXI ID width for output                                                  |
| `DefaultUser`       | Default User bits for output                                             |
| `axi_output_req_t`  | AXI output request type                                                  |
| `axi_output_resp_t` | AXI output response type                                                 |


## Bootmodes

| Bootmode  | Configuration |
|-----------|---------------|
| JTAG      | `00`          |
| Preloaded | `01`          |

## Memory Map

To simplify, we assume following configurations for address parameters. The address spaces below will all be moved when changing the `BaseAddr`, the memory banks will be moved further by `MemOffset`, and the Peripherals will be moved further by `PeriphOffset`. Note that the parameters can be set to collide, but this will not work in the device, so take care when configuring.

| Parameter      | Config          |
|----------------|-----------------|
| `BaseAddr`     | `32'h6000_0000` |
| `AddrRange`    | `32'h0080_0000` |
| `MemOffset`    | `32'h0000_0000` |
| `PeriphOffset` | `32'h0020_0000` |
| `BankNumBytes` | `32'h0001_0000` |
| `NumBanks`     | `2`             |

| Start Address   | Stop Address    | Description                                |
|-----------------|-----------------|--------------------------------------------|
| `32'h0000_0000` | `32'h6000_0000` | External - routed to AXI output            |
| `32'h6000_0000` | `32'h6001_0000` | Memory Bank 1                              |
| `32'h6001_0000` | `32'h6002_0000` | Memory Bank 2                              |
| `32'h6002_0000` | `32'h6020_0000` | Error - will respond with error            |
| `32'h6020_0000` | `32'h6020_1000` | SoC control registers                      |
| `32'h6020_1000` | `32'h6020_2000` | Boot ROM                                   |
| `32'h6020_2000` | `32'h6020_3000` | Error - will respond with error (reserved) |
| `32'h6020_3000` | `32'h6020_4000` | Debug ROM - debug module                   |
| `32'h6020_4000` | `32'h6020_4040` | ECC manager                                |
| `32'h6020_4040` | `32'h6020_6000` | Error - will respond with error            |
| `32'h6020_6000` | `32'h6020_7000` | Simulation Printf (error when synthesized) |
| `32'h6020_7000` | `32'h6020_8000` | Error - will respond with error            |
| `32'h6020_8000` | `32'h6020_D000` | Timer                                      |
| `32'h6020_D000` | `32'h6020_E000` | TCLS registers                             |
| `32'h6020_E000` | `32'h6021_0000` | Error - will respond with error            |
| `32'h6021_0000` | `32'h6022_0000` | CLIC                                       |
| `32'h6022_0000` | `32'h6022_0010` | Instruction bus error registers            |
| `32'h6022_0010` | `32'h6022_0020` | Data bus error registers                   |
| `32'h6022_0020` | `32'h6022_0030` | Shadow bus error registers                 |
| `32'h6022_0030` | `32'h6080_0000` | Error - will respond with error            |
| `32'h6080_0000` | `32'hFFFF_FFFF` | External - routed to AXI output            |

## Getting started

```
git clone <repository-url> safety_island
cd safety_island
source bootstrap.sh
```

That single command prepares the current shell for all the work on this
repository. When it finishes, `bender`, `vsim`, the RISC-V toolchain and the
project Python environment are available **in the shell where you ran it**.

> **`bootstrap.sh` must be sourced, not executed.** `module load` and
> `source .venv/bin/activate` only change the environment of the shell that runs
> them: a script started as `./bootstrap.sh` runs in a child process and everything
> it loaded would be lost on exit (the script detects this and refuses to run).
> Source it again in every new shell. Running it again is quick and changes
> nothing if nothing changed.

Compile the top with the `jtag` or `preloaded` testbench using Questasim

```
make build SIM_TOP=tb_safety_island_jtag
# or
make build SIM_TOP=tb_safety_island_preloaded
```

* JTAG bootmode: the debug module will handle the boot through the jtag interface
* Preloaded bootmode: it expectes an external master to handle the bootflow through the AXI slave (fot the safety_island) interface

Compile and execute a test with `pulp-runtime`

```
cd sw/tests/runtime_<test_name>
make clean all run
```

This will start a simulation in Questasim. To activate GUI mode, add `gui=1` to
the end of the last command. A passing run prints `[AXI] SUCCESS` (preloaded) or
`[JTAG] <time> - SUCCESS` (jtag) and `# Errors: 0`. Do not rely on the exit status of
`make run`, read that line (`FAILED: return code N` on a failing test).

The hardware is built in `sim/` (`work`, `compile.tcl`, `modelsim.ini`,
`transcript`), the software and the simulation output of each test in
`sw/tests/<test>/build/`: the ELF, `stdout/` with what the program printed, and
the `transcript`. All of it is git-ignored.

### What `bootstrap.sh` does

1. **Loads the environment modules** `bender/0.32.1`, `questa/2026.1_2` and
   `corev-gcc/14.1.0-v0.3`. If the `module` command is not defined in the shell
   (batch jobs, cron, `env -i`, ...), it initialises it first. On a machine
   without environment modules it accepts the tools already in `PATH`. It only
   prints a note if newer modules appear, it never switches version on its own.
2. **Creates or updates the Python virtual environment** `.venv` by calling
   `setup_env.py`, then activates it. See [Python environment](#python-environment).
3. **Checks out the Bender dependencies** with `bender checkout`, at the exact
   revisions pinned in `Bender.lock`. It refuses to continue if `Bender.lock` is
   missing, because bender would then silently resolve the newest versions.
4. **Clones `pulp-runtime`** into `sw/pulp-runtime` if it is not there yet
   (`make pulp-runtime`).
5. **Sets up the RISC-V toolchain for `pulp-runtime`**, which looks for
   `riscv32-unknown-elf-*`. If a native `riscv32-unknown-elf-gcc` is already in
   `PATH` (e.g. the PULP toolchain) it is used as it is. Otherwise the generic
   `riscv64-unknown-elf-*` tools of the `corev-gcc` module, which also build rv32
   code, are used through small wrappers generated in `.tools/bin`, and
   `PULP_ARCH_CFLAGS` / `PULP_ARCH_LDFLAGS` are set to flags that recent GCC
   releases accept (`zicsr`, `-fcommon`, ...). The code is built for
   `rv32imac_zicsr_zfinx` without the CORE-V (`xcv*`, Xpulp) extensions, see
   [Known limitations](#known-limitations).
6. **Sets the simulation and software variables**: `VSIM_PATH` (the Questa
   library that `make run` links), and `PULPRT_HOME` and `PULPRT_TARGET` from the
   `pulp-runtime` configuration. The `pulp-freertos` environment is loaded too if
   it was cloned.
7. Prints the versions that are now active.

### Requirements of the machine

- `bash`, `git` and GNU `make`.
- The Environment Modules `module` command with the `bender`, `questa` and
  `corev-gcc` modules, or the equivalent tools already in `PATH`.
- Python **3.9 or newer** with the `venv` module. The default `python3` of some
  machines is too old (3.6 on the cluster this was developed on): the script picks
  the newest of `python3.12 … python3.9` it finds.
- Network access to GitHub (Bender dependencies, `pulp-runtime`) and PyPI (Python
  packages).

### Overrides

Set these before sourcing the script:

| Variable        | Meaning                              | Default                                  |
|-----------------|--------------------------------------|------------------------------------------|
| `BENDER_MODULE` | bender module to load                | `bender/0.32.1`                          |
| `QUESTA_MODULE` | Questa module to load                | `questa/2026.1_2`                        |
| `RISCV_MODULE`  | RISC-V GCC module to load            | `corev-gcc/14.1.0-v0.3`                  |
| `PYTHON`        | interpreter used to build `.venv`    | newest `python3.x` (3.9 or newer) found |

```
QUESTA_MODULE=questa/2025.3 PYTHON=python3.11 source bootstrap.sh
```

### Python environment

Python is used by two parts of the flow:

- the register generator `regtool.py` (OpenTitan's `reggen`, shipped in the
  `register_interface` dependency), run by `make safed-hw-gen`;
- the scripts of `pulp-runtime` that `make run` starts (`pyelftools`, `numpy`).

`requirements.txt` pins every package to an exact version, including the
transitive `MarkupSafe`, so the environment is the same on every machine.
`setup_env.py` builds `.venv` from it, and rebuilds it from scratch whenever
`requirements.txt` or the interpreter version changes. Treat `.venv` as generated
output (it is git-ignored): never edit it by hand, delete it freely. To change a
dependency, edit `requirements.txt` and source `bootstrap.sh` again.

`make safed-hw-gen` uses the interpreter of `.venv` whenever it exists, even if
it is not active in the shell, and warns when it does not exist.

### Dependencies

`Bender.lock` is tracked and pins every dependency to a git revision. To start
from scratch delete `.bender/`, never `Bender.lock` (if it gets deleted, restore it
with `git checkout -- Bender.lock`). To update the dependencies on purpose run
`bender update`, review the diff of `Bender.lock` and commit it together with the
reason for the update.

### FreeRTOS tests

`bootstrap.sh` does not clone `pulp-freertos`: it only loads its environment if
`sw/pulp-freertos` already exists. To use the `freertos_*` tests, clone it once
and source the script again:

```
source bootstrap.sh
make pulp-freertos      # clones sw/pulp-freertos and its submodules
source bootstrap.sh     # again, to load the FreeRTOS environment
```

`make pulp-freertos` needs `bender` (it checks the dependencies out first), so
it must follow a first `source bootstrap.sh`: in a clean shell it stops with
`bender: Command not found`. The submodules are declared with `git@github.com:`
URLs, so it also needs an SSH key registered on GitHub.

The FreeRTOS flow does not work yet with this toolchain and testbench, see
[Known limitations](#known-limitations).

### Known limitations

- `pulp-runtime` is cloned from the head of its `safety-island` branch, not from
  a fixed commit.
- `pulp-runtime/bin/slm_hyper.py`, started by `make run`, has the shebang
  `#!/usr/bin/python3`, so it always runs with the system Python and ignores
  `.venv`. It needs `numpy` there: it is installed system-wide on the machine this
  flow was developed on, but on other machines `make run` fails at that step
  unless the system Python also has `numpy`.
- The FreeRTOS tests (`freertos_*`) do not work yet. What was found with
  `freertos_uart`:
  - the `Makefile` of the test and `default_flags.mk` of `pulp-freertos` use
    `-march=rv32imac`, without `zicsr`: recent toolchains stop with
    `unrecognized opcode 'csrc mstatus,8'`;
  - the flow gives the ELF to the testbench with `+srec`, while
    `tb_safety_island_jtag` reads `+BINARY=<elf>`, so it stops with
    `Failed to load ELF`;
  - with `+BINARY` given by hand the simulation printed nothing and ended by
    timeout. The cause was not investigated: the ELF is linked at the L2
    addresses of PULP (`0x1c000400`), while the memory of the island starts at
    `0x0`;
  - `make clean` does not remove `sim/`, and a second `make run` fails at
    `ln -s sim/boot` because the link points to a folder that does not exist.
- The software is built without the CORE-V (`xcv*`, Xpulp) extensions of the
  `cv32e40p`, so the compiler never emits `cv.*` instructions. Enabling them in
  `-march` does not work with the `cv32e40p` revision pinned in `Bender.lock`:
  that RTL decodes `cv.beqimm` / `cv.bneimm` in the `BRANCH` opcode (`0x63`),
  while `corev-gcc/14.1.0-v0.3` emits them in `custom-0` (`0x0b`), so the core
  raises an illegal instruction at the first one executed. Check the encodings of
  the toolchain against the core before using them when the core is updated.

### Troubleshooting

| Message / symptom | Cause and fix |
|---|---|
| `bootstrap.sh must be sourced, not executed` | Use `source bootstrap.sh` (or `. bootstrap.sh`). |
| `Bender.lock is missing` | `git checkout -- Bender.lock`, then source again. |
| `cannot load module …` | The module does not exist on this machine. Check `module avail bender questa corev-gcc`, then set `BENDER_MODULE` / `QUESTA_MODULE` / `RISCV_MODULE`. |
| `no Python >= 3.9 found` | Install or load one and set `PYTHON=/path/to/python3.x`. |
| `pip failed` | PyPI is not reachable. Behind a mirror/proxy set `PIP_INDEX_URL` (or the usual pip variables) before sourcing. |
| `(vopt-19) Failed to access library 'work'` from `make build` | An earlier `make build` failed (typically `bender: command not found` because `bootstrap.sh` was not sourced) and left a truncated `sim/compile.tcl`. Run `make clean`, source `bootstrap.sh`, build again. |
| Something looks stale | `rm -rf .venv .tools .bender`, then source `bootstrap.sh` again. |

This will start a simulation in Questasim. To activate GUI mode, add `gui=1` to
the end of the last command.

## Citing

The safety island was presented at the RISC-V Summit Europe 2024 as SentryCore. If you use the safety island in your work, you can cite us:

```
@inproceedings{rogenmoser_sentrycore_2024
  title = {SentryCore: A RISC-V Co-Processor System for Safe, Real-Time Control Applications},
  author = {Rogenmoser, Michael and Ottaviano, Alessandro and Benz, Thomas and Balas, Robert and Perotti, Matteo and Garofalo, Angelo and Benini, Luca},
  month = {June},
  year = {2024},
  abstract = {In the last decade, we have witnessed exponential growth in the complexity of control systems for safety-critical applications (automotive, robots, industrial automation) and their transition to heterogeneous mixed-criticality systems (MCSs). The growth of the RISC-V ecosystem is creating a major opportunity to develop open-source, vendor-neutral reference platforms for safety-critical computing. We present SentryCore, a reliable, real-time, self-contained, open-source mega-IP for advanced control functions that can be seamlessly integrated into Systems-on-Chip, e.g., for automotive applications, through industry-standard Advanced eXtensible Interface 4 (AXI4). SentryCore features three embedded RISC-V processor cores in lockstep with error-correcting code (ECC) protected data memory for reliable execution of any safety-critical application. Context switching is accelerated to under 110 clock cycles via a RISC-V core-local interrupt controller (CLIC) and dedicated hardware extensions, while a timer-based direct memory access (DMA) engine streamlines sensor data readout during periodic control loops. SentryCore was implemented in Intel’s 16nm process node and tested with FreeRTOS, ThreadX, and RTIC software support.},
  booktitle = {RISC-V Summit Europe 2024},
  language = {en},
  DOI = {10.3929/ethz-b-000673440},
  address = {Munich, Germany}
}
```

## License
Unless specified otherwise in the respective file headers, all code checked into this repository is made available under a permissive license. All hardware sources and tool scripts are licensed under the Solderpad Hardware License 0.51 (see `LICENSE.md`). All software sources are licensed under Apache 2.0.
