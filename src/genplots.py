#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#  genplots.py
#   Generate plots for report. Read GPU and MySQL performance times from files
#   and plot them.
#
# Rashad Barghouti
# rb3074@columbia.edu
# EECS E6893, Fall 2016
#------------------------------------------------------------------------------
import argparse
import sys
from pathlib import Path    # in Python 3.4+ only
import matplotlib.pyplot as plt

#------------------------------------------------------------------------------
# read_tmsfile(p)
#  This routine is copied from gpujoin.py. It reads a .tms file and returns its
#  data in lists.
#------------------------------------------------------------------------------
def read_tmsfile(p):
    l = []
    with p.open('r') as fd:
        for line in fd:
            # eval() doesn't like empty lines, so check for them
            if not line.isspace() and line[0] != '#':
                l.append(eval(line))
    return tuple(l)

#------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Plotdata entry point
#-------------------------------------------------------------------------------
# default paths to data files
prog = Path(__file__).resolve()
gpufp1 = prog.parents[1] / 'output/gpujoin-allsets.tms'
sqlfp1 = prog.parents[1] / 'output/sqljoin.tms'

# Plot 1: PT grows in size with LPT
#
skip = False
for p in [gpufp1, sqlfp1]:
    if not p.is_file():
        print("Error: file {} does not exist".format(p.name))
        skip = True

if not skip:
    _, gputm1, _, lptsz, _ = read_tmsfile(gpufp1)
    (sqltm1,) = read_tmsfile(sqlfp1)
    #plt.figure()
    #plt.subplot(121)
    plt.figure()
    plt.title("GPU and Indexed-MySQL Execution Times", size='large')
    plt.xlabel('LPT size (in rows) ', size='large')
    plt.ylabel('time (s)', size='large')
    plt.annotate('GPU gain = 1', xy=(2**24, 100),
            xytext=(4894304, 1), size=13, color='magenta',
            arrowprops=dict(arrowstyle="-|>", connectionstyle="arc3, rad=0.2"))

    # log scale for x-axis is 2, for y-axis is the 10 (default)
    plt.loglog(lptsz, sqltm1, 'r', basex=2, lw=2, label='MySQL')
    plt.loglog(lptsz, gputm1, 'b', basex=2, label='GPU', lw=2)

    plt.legend(loc='best', shadow=True, fontsize='medium', facecolor='#FFFFFF')
    plt.grid(True)
    plt.minorticks_off()
    savfile = prog.parents[1] / 'output/multiPT-performance.png'
    plt.savefig(str(savfile))

# ********
# Plot 2: PT size is fixed in all joins. PT10M, PT13M, and PT16M
# ********
#gpufp1 = prog.parents[1] / 'output/gpujoin-pt832K.tms'
#sqlfp1 = prog.parents[1] / 'output/sqljoin-pt832K.tms'

gpufp2 = prog.parents[1] / 'output/gpujoin-pt10M.tms'
sqlfp2 = prog.parents[1] / 'output/sqljoin-pt10M.tms'

gpufp3 = prog.parents[1] / 'output/gpujoin-pt13M.tms'
sqlfp3 = prog.parents[1] / 'output/sqljoin-pt13M.tms'

gpufp4 = prog.parents[1] / 'output/gpujoin-pt16M.tms'
sqlfp4 = prog.parents[1] / 'output/sqljoin-pt16M.tms'

for p in [gpufp2, sqlfp2, gpufp3, sqlfp3, gpufp4, sqlfp4]:
    if not p.is_file():
        print("Error: file {} does not exist. Terminating".format(p.name))
        sys.exit(1)

#plt.subplot(122)
fig = plt.figure()
_, gputm2, _, lptsz, _ = read_tmsfile(gpufp2)
_, gputm3, _, _, _ = read_tmsfile(gpufp3)
_, gputm4, _, _, _ = read_tmsfile(gpufp4)
(sqltm2,) = read_tmsfile(sqlfp2)
(sqltm3,) = read_tmsfile(sqlfp3)
(sqltm4,) = read_tmsfile(sqlfp4)
# Create 2 lists of GPU speed gain/loss factors
#ptall_gl = [ round((mtm/gtm), 2) for gtm, mtm in zip(gputm1, sqltm1)]
#pt832K_gl = [ round((mtm/gtm), 2) for gtm, mtm in zip(gputm1, sqltm1)]
pt10M_gl = [ round((mtm/gtm), 2) for gtm, mtm in zip(gputm2, sqltm2)]
pt13M_gl = [ round((mtm/gtm), 2) for gtm, mtm in zip(gputm3, sqltm3)]
pt16M_gl = [ round((mtm/gtm), 2) for gtm, mtm in zip(gputm4, sqltm4)]

plt.title('GPU Speed-Up When Same PT Is Used in All Joins with LPT',
        size='large')
plt.xlabel('LPT size (in rows) ', size='large')
plt.ylabel('Speed-Up Factor', size='large')
plt.grid(True)
plt.ylim(0, 5)
s = ['Large PTs nullify gains from\nparallel processing of LPT; there\n']
s += ['is little variance in speedup\nacross the range of LPT sizes.']
s = ''.join(s)
ax = fig.add_subplot(111)
plt.text(0.43, 0.6, s, color='white', size=11,
        bbox=dict(facecolor='black', alpha=0.8),
        linespacing=1.6, horizontalalignment='left',
        verticalalignment='bottom',
        transform=ax.transAxes)

# log scale for x-axis only
#plt.semilogx(lptsz, pt832K_gl, 'k', basex=2, lw=2)
plt.semilogx(lptsz, pt10M_gl, 'r', basex=2, lw=2,
        label = 'PT: 10M rows')
plt.semilogx(lptsz, pt13M_gl, 'b', basex=2, lw=2,
        label = 'PT: 13M rows')
plt.semilogx(lptsz, pt16M_gl, 'g', basex=2, lw=2,
        label = 'PT: 16M rows')

plt.legend(loc='upper left', shadow=True, fontsize='medium',
        facecolor='#FFFFFF')

savfile = prog.parents[1] / 'output/singlePT-performance.png'
plt.savefig(str(savfile))

# This is a blocking call; should be last one
plt.show()
plt.close('all')
