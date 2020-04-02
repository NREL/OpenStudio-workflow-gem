import os
import sys
print("sys.argv:", sys.argv)
print("os.getcwd():", os.getcwd())
print("os.environ:", os.environ)
import matplotlib
matplotlib.use('Agg')

import pyfmi
import pylab

from pymodelica import compile_fmu
from pyfmi import load_fmu

#model_name = "HelloWorld"
#mo_file = "/var/oscli/clones/openstudio-workflow/lib/openstudio/workflow/jobs/HelloWorld.mo"
file = sys.argv[1]

if file.endswith('.mo'):
  print "compile fmu"
  model_name = sys.argv[2]
  fmu = compile_fmu(model_name, file)
elif file.endswith('.fmu'):
  print "use fmu"
  fmu = file  
else:
  print "no .mo or .fmu file"

print "load_fmu"
hello_world = load_fmu(fmu)
print "fmu.simulate"
res = hello_world.simulate(start_time=0,final_time=5)


