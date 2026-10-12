import glob
import os
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
scripts = sorted(glob.glob(os.path.join(here, "[0-9][0-9].py")))
red = 0
for script in scripts:
    result = subprocess.run([sys.executable, "-I", script], capture_output=True, text=True, timeout=120)
    first = (result.stdout.strip().split("\n") or [""])[0] or result.stderr.strip().split("\n")[-1]
    print("%s exit %d  %s" % (os.path.basename(script), result.returncode, first))
    red += 1 if result.returncode else 0
print("%d von %d Skripten melden einen Fehler (Exit 1)" % (red, len(scripts)))
sys.exit(1 if red else 0)
