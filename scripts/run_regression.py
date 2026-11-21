from pathlib import Path
import subprocess,re
r=Path(__file__).resolve().parent.parent
(r/'build').mkdir(exist_ok=True)
files=(r/'scripts/oled_sources.tcl').read_text().split('{',1)[1].split('}',1)[0].split()
files=['rtl/common/config_pkg.sv','rtl/common/sync_fifo.sv']+files
cases={'tb_common':['sim/tb_common.sv'],'tb_spi_master':['sim/tb_spi_master.v'],'tb_arbiter':['sim/arbiter/arb_system.v','sim/arbiter/synth_requester.v','sim/arbiter/tb_arbiter.v'],'tb_acl2_service':['sim/models/adxl362_model.sv','sim/tb_acl2_service.sv'],'tb_hygro_service':['sim/models/hdc1080_model.sv','sim/tb_hygro_service.sv'],'tb_sensor_hub':['sim/models/adxl362_model.sv','sim/models/hdc1080_model.sv','sim/tb_sensor_hub.sv'],'tb_sensor_oled_text':['sim/tb_sensor_oled_text.sv'],'tb_sensor_oled':['sim/models/adxl362_model.sv','sim/models/hdc1080_model.sv','sim/tb_sensor_oled.sv'],'hygro_test_top':['rtl/hygro_test_top.sv'],'acl2_test_top':['rtl/ACL2/acl_top.sv'],'sensor_oled_top':[],'oled_test_top':['rtl/OLED/srces/oled_test_top.sv'],'oled_dbg_top':['rtl/OLED/srces/oled_dbg_top.sv']}
cases['tb_arbiter_stress_demo']=['rtl/debug/arbiter_metrics.sv','rtl/debug/arbiter_stress_demo.sv','sim/tb_arbiter_stress_demo.sv']
cases['tb_arbiter_debug']=['rtl/debug/arbiter_metrics.sv','rtl/debug/arbiter_stress_demo.sv','rtl/debug/arbiter_debug.sv','sim/tb_arbiter_debug.sv']
cases['tb_arbitration_demo']=['rtl/debug/arbiter_metrics.sv','rtl/debug/arbiter_stress_demo.sv','sim/tb_arbitration_demo.sv']
for top,extra in cases.items():
 p=subprocess.run(['iverilog','-g2012','-s',top,'-o','build/'+top]+files+extra,cwd=r,capture_output=True,text=True)
 (r/'build'/f'{top}_compile.log').write_text(p.stdout+p.stderr)
 if p.returncode: print(top,'COMPILE FAILED',p.returncode,p.stderr[-1000:],flush=True); raise SystemExit(1)
 if top.startswith('tb_'):
  p=subprocess.run(['vvp','build/'+top],cwd=r,capture_output=True,text=True,timeout=45)
  (r/'build'/f'{top}.log').write_text(p.stdout+p.stderr)
  if p.returncode or re.search('FAIL|ERROR|TIMEOUT|FATAL',p.stdout+p.stderr) or 'PASS' not in p.stdout:
   print(top,'SIM FAILED',p.returncode,p.stdout[-3000:],p.stderr,flush=True);raise SystemExit(1)
 print(top,'PASS',flush=True)
