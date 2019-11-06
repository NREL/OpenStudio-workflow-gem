import os
import sys
print("sys.argv:", sys.argv)
print("os.getcwd():", os.getcwd())
print("os.environ:", os.environ)
import matplotlib
matplotlib.use('Agg')

from fmpy.ssp.simulation import simulate_ssp
from fmpy.util import plot_result

#model_name = "HelloWorld"
#mo_file = "/var/oscli/clones/openstudio-workflow/lib/openstudio/workflow/jobs/HelloWorld.mo"
ssp_filename = sys.argv[1]

print("Simulating %s..." % ssp_filename)
result = simulate_ssp(ssp_filename, stop_time=10, step_size=1e-3)

show_plot=True

if show_plot:
    print("Plotting results...")
    dir, _ = os.path.split(ssp_filename)
    save_name = dir + 'ssp.png'
    plot_result(result, names=['constant.y', 'space.T', 'load.Qgenerated'], window_title=ssp_filename, filename=save_name)

print('result: ', result)
print('Done.')
