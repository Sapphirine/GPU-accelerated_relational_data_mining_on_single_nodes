#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#  xtndpt.py
#   This script extends the size of a page-table CSV file. It computes the
#   number of rows the file contains, and, if necessary, appends 'null' lines
#   to the file so that number becomes a multiple of 16 rows. This is to
#   accomodate the 'lmem' kernel, which copies blocks of 16 PT rows to local
#   memory to perform string-compare operations on them. (If there's
#   time, this task needs to be done automatically either in createtbls.sh or
#   by in gpujoin.py, by resizing the PT ndarray in-place).
#
# Rashad Barghouti
# rb3074@columbia.edu
# EECS E6893, Fall 2016
#------------------------------------------------------------------------------
import subprocess
from pathlib import Path

ROW_MULT = 16

p = Path('.')
#pt_files = list(p.glob('pt*.csv'))
pt_files = sorted(p.glob('pt*.csv'))
for pt in pt_files:
    print("{} - ".format(pt.name), end='')
    cp = subprocess.run(['wc', '-l', pt.name], stdout=subprocess.PIPE,
            encoding='UTF_8')
    ptsz = int(cp.stdout.split(maxsplit=1)[0])
    rem = ptsz % ROW_MULT
    if rem:
        xtra_rows = ROW_MULT - rem
        # Form string of null rows
        append_str = ''.join(["0\t''\n"]*xtra_rows)
        # append str to pt*.csv file
        with pt.open('a') as f:
            f.write(append_str)
        print("added {} nullrows".format(xtra_rows))
    else:
        print("nothing done")
