#!/usr/bin/env python3
"""Run both OLED benches directly with Vivado Simulator; Python standard library only."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--vivado-bin", type=Path, help="Vivado bin folder; otherwise use PATH or XILINX_VIVADO")
args = parser.parse_args()
bin_dir = args.vivado_bin
if bin_dir is None and os.environ.get("XILINX_VIVADO"):
    bin_dir = Path(os.environ["XILINX_VIVADO"]) / "bin"
work = root / "build" / "oled_cli"
work.mkdir(parents=True, exist_ok=True)

def tool(name):
    filename = name + (".bat" if os.name == "nt" else "")
    path = str(bin_dir / filename) if bin_dir else shutil.which(filename)
    if not path or not Path(path).is_file():
        raise SystemExit("Cannot find " + filename + "; use a Vivado command shell or --vivado-bin.")
    return path

def run(name, arguments, log_name, require_pass=False):
    result = subprocess.run([tool(name)] + arguments, cwd=work,
                            text=True, capture_output=True, timeout=180)
    output = result.stdout + result.stderr
    (work / log_name).write_text(output, encoding="utf-8")
    if result.returncode or re.search(r"ERROR:|Fatal:|FATAL", output) or (require_pass and "PASS" not in output):
        print(output)
        raise SystemExit("Failed: " + name + "; see " + str(work / log_name))
    for line in output.splitlines():
        if "PASS" in line:
            print(line, flush=True)

sources = re.findall(r"rtl/[^\s{}]+\.(?:sv|v)", (root / "scripts/oled_sources.tcl").read_text())
sources += ["sim/models/adxl362_model.sv", "sim/models/hdc1080_model.sv",
            "sim/tb_sensor_oled_text.sv", "sim/tb_sensor_oled.sv"]
print("Compiling OLED integration and testbenches...", flush=True)
run("xvlog", ["--sv"] + [str(root / f) for f in sources], "compile.txt")
(work / "run.tcl").write_text("run all\nquit\n")
for top in ("tb_sensor_oled_text", "tb_sensor_oled"):
    print("Running " + top + "...", flush=True)
    run("xelab", [top, "-s", top, "--debug", "typical"], top + "_elaborate.txt")
    run("xsim", [top, "-tclbatch", "run.tcl"], top + "_simulate.txt", require_pass=True)
print("ALL OLED XSIM TESTS PASSED", flush=True)
