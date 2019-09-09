import os
print os.getcwd()
import matplotlib
matplotlib.use('Agg')

import pyfmi
import pylab

from pymodelica import compile_fmu
from pyfmi import load_fmu

model_name = "HelloWorld"
mo_file = "/home/ubuntu/Projects/OpenStudio-workflow-gem-fmu/lib/openstudio/workflow/jobs/HelloWorld.mo"
print "compile_fmu"
my_fmu = compile_fmu(model_name, mo_file)
print "load_fmu"
hello_world = load_fmu(my_fmu)
print "fmu.simulate"
res = hello_world.simulate(start_time=0,final_time=5)


