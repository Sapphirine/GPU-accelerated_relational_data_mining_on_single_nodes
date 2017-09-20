#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#  Module: gpujoin.py
#   This module contains routines that perform relational table JOIN on
#   Graphics Processing Units (GPUs).
#
# Rashad Barghouti
# rb3074@columbia.edu
# EECS E6893, Fall 2016
#------------------------------------------------------------------------------

# System imports
import io
import re
import sys
import time
import argparse
from pathlib import Path    # in Python 3.4+ only
from shutil import copy

# Dependency imports (may need to be added to default Python installation)
import numpy as np
import pyopencl as cl
import pyopencl.array
import prettytable

#** Begin project definitions **#

# Handler for controlled traceback display. Comment out for full traceback
def exceptionHandler(exception_type, exception, traceback):
    print('{}: {}'.format(exception_type.__name__, exception), file=sys.stderr)
sys.excepthook = exceptionHandler

# Absolute paths
prog_path = Path(__file__).resolve()
project_path = prog_path.parents[1]
output_path = project_path/'output'

# Ordered list of the tblset keys/names
allsets = ['208K', '416K', '832K', '2M', '3M', '7M', '10M', '13M', '16M']

# System data struct
class GPUJOIN_STRUCT:
    pass

#------------------------------------------------------------------------------
# _main():
#   This is the program's entry point. The function parses the cmdline and runs
#   table joins on sets specified on it. For each set, it loads ndarrays from
#   table files (csv or npy) and launches the GPU kernel to perform the join.
#------------------------------------------------------------------------------
def _main():

    args = parse_cmdline()

    # Create and initialize the gpujoin data structure
    gpu = init_gpujoin(args)

    # Loop over all table sets and do a gpu-join on each
    for gpu.tblset in gpu.sets:

        # Create the tables' ndarrays and load them from CSV/NPY files
        load_tables(gpu)

        # Launch the GPU kernel to join this set's tables
        equal = run_gpu(gpu)

        # Log any errors; if multiple GPU outputs have had errors, terminate
        if not equal:
            log_errors(gpu)
            if len(gpu.errinfo) > 1:
                break

    # All joins are done. Write execution data to files and display output info
    record_display_results(gpu)

    exit_prog(gpu)

#------------------------------------------------------------------------------
# def init_gpujoin(args)
#  This function creates and initializes the GPU data struct, including the
#  list of table sets to be joined and the OpenCL runtime. It also prints out
#  the parameters of the GPU run.
#
# Input:
#   args: cmdline argument object
#
# Output:
#   gpu: GPUJOIN_STRUCT data struct
#------------------------------------------------------------------------------
def init_gpujoin(args):

    # Create GPU struct
    gpu = GPUJOIN_STRUCT()

    # Set output verbosity
    gpu.verbose = args.verbose

    # Create output directory if it doesn't exist
    output_path.mkdir(exist_ok=True)

    # Open/create logfile
    lfp = output_path/'gpujoin.log' if args.log is None else Path(args.log[0])
    gpu.logfile = lfp.open('a')
    if lfp.stat().st_size == 0:
        print('** Created: {} **'.format(time.ctime()), file=gpu.logfile)
    prtlog(gpu)
    print('{:*<79}'.format(''), file=gpu.logfile)

    # If '--prt' option was used, print summary table and exit
    if args.tmsfile is not None:
        print_summary_table(gpu, tmsfp=Path(args.tmsfile))
        sys.exit(0)

    # timestamp this run
    prtlog(gpu, '{} – {}\n'.format(prog_path.name, time.ctime()))

    # Create OpenCL runtime
    gpu.platname = 'NVIDIA CUDA' if args.platname is None else args.platname[0]
    init_ocl_runtime(gpu)

    # Init tables path; terminate if it does not exist
    #
    gpu.tblspath = project_path/'tables'
    if args.tdir is not None:
        gpu.tblspath = Path(args.tdir[0])
    if not gpu.tblspath.is_dir():
        prtlog(gpu, 'Error: init_gpujoin(): no such directory: {}'
                .format(gpu.tblspath), fd=sys.stderr)
        exit_prog(gpu)

    # Create list of table sets to be joined
    if 'all' in args.tblset:
        gpu.sets = allsets
    else:
        gpu.sets = sorted(args.tblset, key=lambda x: allsets.index(x))

    # Note: if a single page table to be used for all joins (-p option), make
    # sure it is large enough for all the LPTs in the join sets; don't do the
    # joins for which it is not. E.g., if cmdline is something like "gpujoin -p
    # pt832K 208K 416K 832K 2M", then tblset 2M will be removed, since pt832K
    # is not large enough to produce a full join with lpt2M.
    gpu.ptbl = None
    if args.ptbl is not None:
        gpu.ptbl = args.ptbl[0]
        ptidx = allsets.index(gpu.ptbl[2:])
        ptlst = []
        new =[]
        for tblset in gpu.sets:
            if allsets.index(tblset) <= ptidx:
                new += [tblset]
                ptlst += [gpu.ptbl]
            else:
                break
        gpu.sets = new
    else:
        ptlst = [''.join(['pt', tblset]) for tblset in gpu.sets]

    lptlst = [''.join(['lpt', tblset]) for tblset in gpu.sets]
    rtlst = [''.join(['rt', tblset]) for tblset in gpu.sets]
    gpu.tbldict = {}
    for key, lpt, pt, rt in zip(gpu.sets, lptlst, ptlst, rtlst):
        gpu.tbldict[key] = (lpt, pt, rt)

    gpu.mknpy = args.mknpy
    gpu.usenpy = args.usenpy
    gpu.runs = 1 if args.runs is None else args.runs[0]

    # Create lists to hold execution times, sizes of consumed tables, & errinfo
    gpu.gputm, gpu.totaltm = [], []
    gpu.lptsz, gpu.ptsz = [], []
    gpu.errinfo = []

    # Development/test options.
    gpu.lclsz = (16, 1) if args.dim is None else tuple(args.dim)
    gpu.knlfname = project_path/'src/kernel.cl'
    if args.kfn is not None:
        gpu.knlfname = Path(args.kfn[0])

    # Get kernel src, build OpenCL program, and dump ptx code to file.
    #gpu.knlkwd = 'lmem' if args.knlkwd is None else args.knlkwd[0]
    gpu.knlkwd = 'lmem'
    knlstr = get_kernel(gpu)
    gpu.prg = cl.Program(gpu.ctx, knlstr).build()
    dump_ptx(gpu.prg)

    # Print out execution parameters for this run
    #
    # (OpenCL platform -- for some reason, the context properties list comes
    # back empty, so use devices list instead.)
    platname = gpu.ctx.devices[0].platform.name
    if args.platname is None:
        s = 'OpenCL platform: {} (default)'.format(platname)
    else:
        s = 'Selected OpenCL platform: {}'.format(platname)
    prtlog(gpu, s)
    if gpu.ptbl is None:
        prtlog(gpu, 'One PT for all joins: No')
    else:
        prtlog(gpu, 'One PT for all joins: Yes — {}'.format(gpu.ptbl))
    if gpu.sets is allsets:
        prtlog(gpu, 'Join sets: All')
    else:
        prtlog(gpu, 'Join sets: {}'.format(gpu.sets))
    prtlog(gpu, 'Scheduled GPU iterations per set: {}'.format(gpu.runs))


    return gpu
#------------------------------------------------------------------------------
# load_tables(gpu)
#   Creates the the tables' structured ndarrays and loads them from CSV or NPY
#   data files
#
# Input:
#   gpu: GPUJOIN_STRUCT
#
# Output:
#   ndarray tuple: (lpt, pt, rt), where
#      lpt: linkpage table array
#      pt:  page table array
#      rt:  reference linkpage table
#------------------------------------------------------------------------------
def load_tables(gpu):

    tblset = gpu.tbldict[gpu.tblset]

    # Print out simple header to stdout
    s = '\nTable set: {}'.format(gpu.tblset)
    prtlog(gpu, s, '\n{:—<{len}}'.format('', len=len(s)-1))

    p = gpu.tblspath
    sufx = '.npy' if gpu.usenpy else '.csv'

    # Construct tables' pathnames
    lptf, ptf, rtf = (p.joinpath(t).with_suffix(sufx) for t in tblset)

    # If one PT is to be used for all JOINs, reset ptf to point to it
    if gpu.ptbl:
        ptf = p.joinpath(gpu.ptbl).with_suffix(sufx)

    # Define structured array dtype
    dt = np.dtype([('id', 'u4'), ('title', 'S60')])

    # Load ndarrays from csv or npy files
    tblarrays = []
    for f in lptf, ptf, rtf:
        prtlog(gpu, 'Reading {}'.format(f.name))

        if sufx == '.csv':
            try:
                with f.open(encoding='unicode_escape', mode='r') as fd:
                    tm = time.clock()
                    arr = np.loadtxt(fd, dtype=dt)
                    tm = time.clock() - tm
                    prtlog(gpu, '{} rows loaded ({})'.format(arr.size, tmstr(tm)))
            except FileNotFoundError:
                prtlog(gpu, "Error: load_tables(): file not found: {}"
                        .format(f.resolve()), fd=sys.stderr)
                exit_prog(gpu)
            if gpu.mknpy:
                np.save(str(f.with_suffix('.npy')), arr)

        else:
            # Load from npy file
            tm = time.clock()
            try:
                arr = np.load(str(f.with_suffix('.npy')))
                tm = time.clock() - tm
                prtlog(gpu, '{} rows loaded ({})'.format(arr.size, tmstr(tm)))
            except IOError:
                prtlog(gpu, "Error: load_tables(): file not found: {}"
                        .format(f.resolve()), fd=sys.stderr)
                exit_prog(gpu)

        tblarrays.append(arr)

    # Init table pointers in gpu_struct and record current array sizes
    #
    gpu.lpt, gpu.pt, gpu.rt = tblarrays[0], tblarrays[1], tblarrays[2]

    gpu.lptsz.append(gpu.lpt.size)
    gpu.ptsz.append(gpu.pt.size)

#------------------------------------------------------------------------------
# def run_gpu(gpu):
#   Launches the GPU kernel to join the set's tables. Compares the output LPT
#   to the set's RT and returns a boolean indicating whether they are
#   identical (True) or not (False).
#
# Input:
#  gpu: GPU data structure
#
# Output:
#  equal: True if GPU output == reference, else False
#  Other: This lists gputm[] and totaltm[] are appended with this set's
#         execution times
#------------------------------------------------------------------------------
def run_gpu(gpu):

    # Set global size.
    gpu.glbsz = gpu.lpt.size, 1

    # Create device buffers
    mf = cl.mem_flags.READ_ONLY
    mp = cl.tools.MemoryPool(cl.tools.ImmediateAllocator(gpu.cq,
            mem_flags=mf))
    gpu.d_lpt = cl.array.to_device(gpu.cq, gpu.lpt, allocator=mp)
    gpu.d_pt = cl.array.to_device(gpu.cq, gpu.pt, allocator=mp)

    mf = cl.mem_flags.WRITE_ONLY
    mp = cl.tools.MemoryPool(cl.tools.ImmediateAllocator(gpu.cq,
            mem_flags=mf))
    gpu.d_lpid = cl.array.empty(gpu.cq, gpu.lpt.size, dtype=np.uint32,
            allocator=mp)

    # Allocate shared memory for 16 PT rows + 1 int (for matchcntr)
    d_lmem = cl.LocalMemory(gpu.pt.itemsize*gpu.lclsz[0]+4)

    prtlog(gpu, '\nBegin GPU processing')

    # Launch the GPU kernel
    ptsz = np.uint32(gpu.pt.size)
    gputm, totaltm = 0.0, 0.0
    for gpurun in range(gpu.runs):

        # Record walltime start
        tm = time.perf_counter()

        evt = gpu.prg.join_vecdata_lmem(
                    gpu.cq, gpu.glbsz, gpu.lclsz,
                    gpu.d_lpt.data, gpu.d_pt.data,
                    ptsz, gpu.d_lpid.data, d_lmem)
        evt.wait()

        # Read GPU output into id column of the host linkpage array
        gpu.lpt['id'] = gpu.d_lpid.get()

        # record times in sec
        totaltm += time.perf_counter() - tm
        tm = 1e-9*(evt.profile.end - evt.profile.start)
        if gpu.runs > 1:
            prtlog(gpu, 'run {} time: {}'.format(gpurun, tmstr(tm)))
        gputm += tm

        # There's little value in averaging times for large sets; skip
        if allsets.index(gpu.tblset) > allsets.index('3M'):
            prtlog(gpu, 'Running only once for this tblset')
            gputm = gputm * gpu.runs
            totaltm = totaltm * gpu.runs
            break;

    gputm = gputm/gpu.runs
    totaltm = totaltm/gpu.runs

    # Print JOIN times to output file and record them for final messaging
    prtlog(gpu, 'Done!')
    if gpu.runs == 1:
        prtlog(gpu, ' GPU (profiling) time: {}'.format(tmstr(gputm)))
        prtlog(gpu, ' total (GPU+Host) time: {}'.format(tmstr(totaltm)))
    else:
        prtlog(gpu, ' avg. GPU time: {}'.format(tmstr(gputm)))
        prtlog(gpu, ' avg. total time: {}'.format(tmstr(totaltm)))

    # keep full precision here and do the rounding when printing results
    gpu.gputm.append(gputm)
    gpu.totaltm.append(totaltm)

    # Verify GPU output against reference table
    equal = np.array_equal(gpu.lpt['id'], gpu.rt['id'])
    prtlog(gpu, ' output == reference: {}'.format((equal)))

    return equal

#------------------------------------------------------------------------------
# get_kernel(gpu)
#  This function reads the OpenCL source file, adds #defines, and returns
#  the kernel string needed to build the OpenCL program
#
# Inputs:
#   gpu: GPUJOIN_STRUCT
#
# Outputs:
#   krnlsrc: kernel source string
#------------------------------------------------------------------------------
def get_kernel(gpu):

    # Read kernel source and build OpenCL program #
    with Path(gpu.knlfname).open(mode='r') as fd:
        krnlsrc = fd.read()

    # Skip past auto-gen header
    sep = ''.join(['/', 78*'*', '\n * __kernel'])
    hdr, sep, code = krnlsrc.partition(sep);

    # Set up the "#define" statements. ROWLEN is '16' for the naive kernel and
    # '4' for the vector-data kernels; BLKSIZE is 16; and M is the length of
    # PT, as determined during loading from CSV
    #rowlen = '16' if gpu.knlkwd == 'naive' else '4'
    #kdefs = ['#define ROWLEN\t',  rowlen, 'U\n']
    kdefs = ['#define ROWLEN\t4U\n']
    kdefs += ['#define BLKSIZE\t', str(gpu.lclsz[0]*gpu.lclsz[1]), 'U\n']

    kdefs += ['\n']

    kdefs += ['#define NAIVE\t1\n']
    kdefs += ['#define XOR\t\t2\n']
    kdefs += ['#define OCLFNS\t3\n']
    kdefs += ['#define LMEM\t4\n']
    kdefs += ['#define LPTSEGS\t\t5\n']

    kdefs += ['\n']

    #if gpu.knlkwd == 'lmem':
    #    kdefs += ['#define KERNEL\tLMEM\n']
    kdefs += ['#define KERNEL\tLMEM\n']
    #elif gpu.knlkwd == 'lptsegs':
    #    kdefs += ['#define KERNEL\tLPTSEGS\n']
    #elif gpu.knlkwd == 'oclfns':
    #    kdefs += ['#define KERNEL\tOCLFNS\n']
    #elif gpu.knlkwd == 'xor':
    #    kdefs += ['#define KERNEL\tXOR\n']
    #elif gpu.knlkwd == 'naive':
    #    kdefs += ['#define KERNEL\tNAIVE\n']

    kdefs += ['\n']

    # Default kernel is shared memory kernel 'lmem'
    kdefs += ['#ifndef KERNEL\n#define KERNEL\tLMEM\n#endif\n']

    kdefs += ['\n']

    #prtlog(gpu, 'kdefs:\n{}'.format(kdefs));
    khdr = ['/', 78*'*', '\n', '* Auto-generated kernel source\n']
    khdr += [78*'*', '/' ,'\n\n']
    ksrc = ''.join(khdr + kdefs) + sep + code
    with project_path.joinpath('src/.kernel.generated.cl').open('w') as fd:
        print(gpu, ksrc, file=fd)
    #sys.exit(0)

    return ksrc
#------------------------------------------------------------------------------
# init_ocl_runtime(platname)
#  Sets up OpenCL runtime (context & command queue)
#
# Input:
#  gpu: GPUJOIN_STRUCT with platname initialized
#
# Return
#   gpu.ctx & gpu.cq are set to the OpenCL context and command-queue values
#------------------------------------------------------------------------------
def init_ocl_runtime(gpu):

    # Case 1: platname is a valid platform, probably 'NVIDIA CUDA', the default
    #
    if gpu.platname not in ['any', 'interactive']:
        # Get list of devices in platform given by platname
        platforms = cl.get_platforms()
        devices = None
        for platform in platforms:
            if platform.name.lower() == gpu.platname.lower():
                devices = platform.get_devices(device_type=cl.device_type.GPU)

        estr = 'Error: init_ocl_runtime(): '
        if devices is None:
            emsg = 'OpenCL platform "{}" not found'.format(gpu.platname)
            prtlog(gpu, estr, emsg, fd=sys.stderr)
            exit_prog(gpu)

        # get_devices() does not raise exception if no devices found; it
        # returns an empty list instead. Check for this case here.
        if not devices:
            emsg = 'no GPUs found on "{}" platform'.format(gpu.platname)
            prtlog(gpu, estr, emsg, fd=sys.stderr)
            exit_prog(gpu)

        # Create the execution context and the host's command queue. Enable
        # profiling on the device (the 'properties' kword argument is a bit
        # field)
        gpu.ctx = cl.Context(devices)

    elif gpu.platname == 'any':
        gpu.ctx = cl.create_some_context(interactive=False)
    else:
        gpu.ctx = cl.create_some_context()

    gpu.cq = cl.CommandQueue(gpu.ctx,
            properties=cl.command_queue_properties.PROFILING_ENABLE)

#------------------------------------------------------------------------------
# dump_ptx()
#   Dump ptx code in a file named './.gpu.ptx'
#------------------------------------------------------------------------------
def dump_ptx(oclprog):

    # In python 3, use bytes.decode()
    ptx = oclprog.binaries
    f = project_path/'src/.gpu.ptx'
    with f.open(mode='w') as fd:
        fd.write(''.join(ptx[0].decode('utf8')))

#------------------------------------------------------------------------------
# log_errors(gpu)
#  This function writes the error rows in the GPU output a log file.
#
# Input:
#   gpu: system data structure
#
# Output:
#   gpu.errinfo[] is appended with errinfo = [tblset, num_errors]
#   Error log file: the output errors are written to a file in the logs
#                   directory, named after gpujoin-${currset}-errors.log
#------------------------------------------------------------------------------
def log_errors(gpu):

    # If this is the first set of errors, create/overwrite log file
    if not gpu.errinfo:
        gpu.errfile = output_path/'gpujoin-errors.log'
        gpu.errfd = gpu.errfile.open('w')
        print('** {} error log — {}.'.format(prog_path.name, time.ctime()),
                file=gpu.errfd)

    # Init errinfo list for this set
    errinfo = [gpu.tblset]

    # Generate a boolean array of error locations in output LPT
    neq = np.not_equal(gpu.lpt['id'], gpu.rt['id'])

    # Create formatted list of the error rows
    err_rows = [(n, gpu.rt['id'][n], gpu.lpt['id'][n], gpu.rt['title'][n])
                for n in range(gpu.lpt.size) if neq[n]]

    errinfo += [len(err_rows)]

    print('\n\n# Table set {} errors\n'.format(gpu.tblset), file=gpu.errfd)
    print('{:^8}  {:<9}  {:<9}  {:<8}'.format('row', 'ref pg_id',
        'GPU pg_id', 'pg_title'), file=gpu.errfd)
    print('--------  ---------  ---------  ---------'.format('  '),
            file=gpu.errfd)

    for row in err_rows[:len(err_rows)]:
        print('{0[0]:>8}  {0[1]:<9}  {0[2]:<9}  {0[3]:<60}'.format(row),
            file=gpu.errfd)

    gpu.errinfo.append(errinfo)

#------------------------------------------------------------------------------
# record_and_display_results(gpu)
#   If no errors occurred in any GPU output, this function writes times data to
#   file and displays summary table on stdout. Otherwise, display summary of
#   output errors.
# Input:
#   gpu: system data structure
# return:
#   none.
#------------------------------------------------------------------------------
def record_display_results(gpu):

    if not gpu.errinfo:
        prtlog(gpu, '\nGPU table join(s) completed with no errors.')

        # Write execution times to tms file(s) in output directory
        p, cp = write_tmsfile(gpu)
        if cp:
            prtlog(gpu, 'Execution data written to {} & {} in output directory'
                    .format(p.name, cp.name))
        else:
            prtlog(gpu, 'Execution data written to {} in output directory'
                    .format(p.name))


        # Display table of all results
        print_summary_table(gpu)

    else:
        prtlog(gpu, '\nGPU output had errors:', fd=sys.stderr)

        # Display a summary of the errors
        s = [' Table set ', ' errors']
        for e in gpu.errinfo:
            prtlog(gpu, "{0[0]}{1[0]}: {1[1]}{0[1]}".format(s, e),
                    fd=sys.stderr)
        prtlog(gpu, 'Errors written to {}'.format(gpu.errfile), fd=sys.stderr)

        # Close error log file
        gpu.errfd.close()

#------------------------------------------------------------------------------
# print_summary_table(gpu, tmsfp=None):
#   Print a summary table from data produced by this run, or, if a file path
#   object is passed in the keyword parameter tmsfp, print from data in that
#   file.
#------------------------------------------------------------------------------
def print_summary_table(gpu, tmsfp=None):

    # If tmsfp is not None, read table data from file
    if tmsfp is not None:
        gpu.sets, gpu.gputm, gpu.totaltm, gpu.lptsz, gpu.ptsz = \
                read_tmsfile(tmsfp)
        # Check if this is a single-pt file, i.e., name is like *-pt13M*.tms
        gpu.ptbl = None
        if 'pt' in tmsfp.name:
            gpu.ptbl = re.findall('pt[0-9]{2,3}[KM]{1}', tmsfp.name)[0]

    t = prettytable.PrettyTable([''] + gpu.sets)
    t.add_row(['linkpage table size'] + gpu.lptsz)
    t.add_row(['page table size'] + gpu.ptsz)
    t.add_row(['device time'] + gpu.gputm)
    #t.add_row(['GPU processing time'] + gpu.totaltm)
    t.add_row(['total time'] + gpu.totaltm)

    # If there are mysql data, add to table
    sqlfname = ['sqljoin', '.tms']

    # If gpujoin.tms file was obtained through joins with one PT, get the
    # corresopnding sqljoin.tms file. If no file exist, carry on without
    # print out sqldata
    if gpu.ptbl:
        sqlfname[1:1] = ['-', gpu.ptbl]
    sqlfp = output_path/''.join(sqlfname)

    if sqlfp.exists():
        # extract values that correspond to the sets in this run
        (tmdata,) = read_tmsfile(sqlfp)
        if gpu.sets is not allsets:
            sqltms = [tmdata[allsets.index(name)] for name in gpu.sets]
        else:
            sqltms = tmdata
        t.add_row(['MySQL processing time'] + sqltms)

        # Create list of GPU speed gain/loss factors
        factor = [ (str(round((mtm/gtm), 2)), 'x')
                    for gtm, mtm in zip(gpu.gputm, sqltms)]
        # Add list to table
        t.add_row(['GPU speed-up'] + [''.join(a) for a in factor])

    # Print table; override gpu.verbose to ensure table is always printed out
    # to stdout as well as to logfile
    verbose = gpu.verbose
    gpu.verbose = True
    t.align = 'r'
    prtlog(gpu, '\nOutput Summary. All times in sec.')
    prtlog(gpu, t)

    if not sqlfp.exists():
        s = '\nSQLjoin data not included. {} was not found'.format(sqlfp.name)
        prtlog(gpu, s)

    gpu.verbose = verbose

#------------------------------------------------------------------------------
# write_tmsfile(gpu):
#  Write processing results to "gpujoin.tms" in the output directory. Also,
#  make a copy of the file with a name that contains this run's parameters.
#
# Return:
#   (p, cp): Path() objects for the two files created
#------------------------------------------------------------------------------
def write_tmsfile(gpu):

    # Round the timing data here
    gpu.gputm = np.around(gpu.gputm, decimals=4).tolist()
    gpu.totaltm = np.around(gpu.totaltm, decimals=4).tolist()

    # Construct file pathname
    p = output_path/'gpujoin.tms'

    # Write output data
    with p.open(mode='w') as fd:

        print('{:-<79}'.format('#'), file=fd)
        s = '# GPU Processing Times'
        print(s, '\n# {:\u2014<{len}}'.format('', len=len(s)-2), file=fd)
        print('# {}'.format(time.ctime()), file=fd)
        print('#\n# GPU runs per table set: {}'.format(gpu.runs), file=fd)
        print('# Join input pairs: ', file=fd)
        print("#  ", end='', file=fd)

        nsets= len(gpu.sets)
        for i, currset in zip(range(nsets), gpu.sets):
            print('{}'.format(gpu.tbldict[currset][:2]), end='', file=fd)
            if i == nsets-1:
                print("\n#\n#", file=fd)
            elif not (i+1)%3:
                print(",\n#  ", end='', file=fd)
            else:
                print(", ", end='', file=fd)

        print('# Output lists:', file=fd)

        print('#  1. tblsets[]', file=fd)
        if gpu.runs == 1:
            s = '#  2. device_time[] (sec)\n#  2. total_time[] (sec)'
        else:
            s = '#  2. avg_device_time[] (sec)\n#  2. avg_total_time[] (sec)'

        print(s, file=fd)
        print('#  3. linkpage_table_size[] (rows)', file=fd)
        print('#  4. page_table_size[] (rows)', file=fd)
        print('{:-<79}'.format('#'), file=fd)
        print('{}'.format(repr(gpu.sets)), file=fd)
        print('{}'.format(repr(gpu.gputm)), file=fd)
        print('{}'.format(repr(gpu.totaltm)), file=fd)
        print('{}'.format(repr(gpu.lptsz)), file=fd)
        print('{}'.format(repr(gpu.ptsz)), file=fd)

    # Make a copy with name that describes this run's parameters
    cp = None
    cf = []
    if gpu.sets is allsets:
        cf += ['-allsets']
    if gpu.ptbl:
        cf += ['-', gpu.ptbl]
    if gpu.runs > 1:
        cf += ['-iter', str(gpu.runs)]

    if any(cf):
        cf.insert(0, p.stem)
        cf.append('.tms')
        cp = p.with_name(''.join(cf))
        copy(str(p), str(cp))

    return p, cp

#------------------------------------------------------------------------------
# read_tmsfile(p)
#   Return all non-comment lines from a '.tms' file.
# Input:
#   p: file Path() object
# Output:
#   tmsdata = (l1, l2, ...) - a tuple of all data lists in file
#------------------------------------------------------------------------------
def read_tmsfile(p):

    tmsdata = []
    with p.open('r') as fd:
        for line in fd:
            # eval() doesn't like empty lines, so check for them
            if not line.isspace() and line[0] != '#':
                tmsdata.append(eval(line))
    return tuple(tmsdata)

#def read_tmsfile(tmsfile):
#
#    tmsdata = []
#    for line in tmsfile:
#        # eval() doesn't like empty lines, so check for them
#        if not line.isspace() and line[0] != '#':
#            tmsdata.append(eval(line))
#    return tuple(tmsdata)

#------------------------------------------------------------------------------
# def tmstr(tm):
#   Input:
#       tm: float seconds value
#   Output:
#       tmstr: 'x hrs y min z sec'
#------------------------------------------------------------------------------
def tmstr(tm):

    tmstr = []

    t = tm/60.0/60.0
    hrs = int(t)
    if hrs:
        tmstr.append('{:d} hrs '.format(hrs))

    t = (t-hrs)*60.0
    mins = int(t)
    if mins:
        tmstr.append('{:d} min '.format(mins))

    secs = (t-mins)*60.0
    #tmstr.append('{:.1g} sec'.format(secs))
    if int(secs*10000):
        tmstr.append('{:.4f} sec'.format(secs))
    else:
        tmstr.append('{:.0e} sec'.format(secs))

    return ''.join(tmstr)

#------------------------------------------------------------------------------
# def parse_cmdline():
#   Parse command line
# Input:
#   None # Output:
#   Namespace object containing the parsed arguments
#------------------------------------------------------------------------------
def parse_cmdline():

    desc = 'Perform relational table join on the GPU'
    usage = '%(prog)s [OPTIONS] TBLSET [TBLSET ...]'
    parser = argparse.ArgumentParser(description=desc, usage=usage,
            add_help=False)

    pgrp = parser.add_argument_group()
    optgrp = parser.add_argument_group('OPTIONS')

    # Note: to form help strings, use lists instead of concatenating string
    # literals; the latter can be costly

    # arg: tblset
    #
    s = ["input table set. %(metavar)s can be the keyword 'all' or one or"]
    s += ["more keywords from", str(allsets)+'.', "Example: '%(prog)s all' or"]
    s += ["'%(prog)s 416K 832K 3M'. Each %(metavar)s identifies a tuple"]
    s += ["(LPT, PT, RT) of tables on which to perform the GPU join, e.g.,"]
    s += ["416K specifies the tuple (lpt416K, pt416K, rt416K)."]
    s += ["See the README file for details."]
    hstr = ' '.join(s)
    tblsets = allsets + ['all']
    pgrp.add_argument('tblset', nargs='+', metavar='TBLSET', choices=tblsets,
            help=hstr)

    # arg: -h, --help
    hstr = 'show this help message and exit'
    optgrp.add_argument('-h', '--help', action='help', help=hstr)

    # arg: -d TBLSDIR
    hstr = 'tables directory pathname (default:/path/to/project/tables)'
    optgrp.add_argument('-d', nargs=1, dest='tdir', help=hstr)

    # arg: -m (mknpy)
    s = ["make npy files. Dump the ndarrays (loaded from CSV tables) into"]
    s += ["*.npy files in the 'tables' directory. The -n option can be"]
    s += ["used in subsequent program invocations to load the ndarrays"]
    s += ["from these files at much higher speed"]
    hstr = ' '.join(s)
    optgrp.add_argument('-m', dest='mknpy', action='store_true', help=hstr)

    # arg: -n (usenpy)
    hstr = 'load tables from npy files (see option -m)'
    optgrp.add_argument('-n', dest='usenpy', action='store_true', help=hstr)

    # arg: -i ITER
    s = ["number of times to run the GPU kernel for each input set. ITER can"]
    s += ["be 1, 2, 3, or 4 (default: 1). This is used to obtain the average"]
    s += ["execution time for the GPU"]
    hstr = ' '.join(s)
    optgrp.add_argument('-i', nargs=1, dest='runs', type=int, help=hstr,
            metavar='ITER', choices=[1, 2, 3, 4])

    # arg: -p PGTBL
    s = ['use %(metavar)s as the PT for all joins (default: None).']
    s += ["%(metavar)s is the prefix of the table's PT file, e.g.,"]
    s += ["pt832K or pt3M. By fixing the PT size, GPU perfromance can be"]
    s += ["evaluated in terms of LPT size only. When this option is given,"]
    s += ["joins that require larger PTs than the one specified will not be"]
    s += ["performed"]
    hstr = ' '.join(s)
    optgrp.add_argument('-p', nargs=1, dest='ptbl', metavar='PGTBL',
            choices=[''.join(['pt', tblset]) for tblset in allsets],
            help=hstr)

    # arg: -o FNAME
    #hstr = ["redirect output to file %(metavar)s (default: stdout)"]
    #hstr = ' '.join(hstr)
    #optgrp.add_argument('-o', dest='of', metavar='FNAME', default=sys.stdout,
    #    type=argparse.FileType('w'), help=hstr)

    # arg: -t PLAT
    s = ["OpenCL platform to use (default: 'NVIDIA CUDA'). If %(metavar)s"]
    s += ["is not known, one of the keywords 'any' and 'interactive' can be"]
    s += ["used. If %(metavar)s is 'any', and multiple platforms"]
    s += ["and/or GPUs exist on the system, then one is chosen automatically."]
    s += ["If %(metavar)s is 'interactive', and (again) multiple"]
    s += ["platforms and/or devices exist, then the user is prompted to make"]
    s += ["a choice of one of them. Alternatively,"]
    s += ["The utility oclplat.py in the src directory can be tried to list"]
    s += ["available OpenCL platforms, and, if successful, one of them"]
    s += ["can be specified with this option"]
    hstr = ' '.join(s)
    optgrp.add_argument('-t', nargs=1, dest='platname', metavar='PLATNAME',
            type=str, help=hstr)

    # arg: -v
    # Enable verbose output
    hstr = 'verbose output'
    optgrp.add_argument('-v', dest='verbose', action='store_true', help=hstr)

    #***********************************************************************
    # All DEVELOPMENT OPTIONS from this point (suppressed in help message) *
    #***********************************************************************

    # arg: --log FNAME
    hstr = '(devel option): use %(metavar)s as log file'
    optgrp.add_argument('--log', nargs=1, metavar='FNAME',
            #help=hstr)
            help=argparse.SUPPRESS)

    # arg: --kfn FNAME
    hstr = '(devel option): use %(metavar)s as kernel source file'
    optgrp.add_argument('--kfn', nargs=1, metavar='FNAME',
            #help=hstr)
            help=argparse.SUPPRESS)

    # arg: --dim XD YD
    hstr = "(devel option): local_size tuple: (XD, YD)"
    optgrp.add_argument('--dim', nargs=2, type=int,
            #help=hstr)
            help=argparse.SUPPRESS)

    # arg: --ptx
    # (disabled -- ptx code is now always written to '.gpu.ptx')
    #
    #hstr = "(devel option): dump ptx code in gpu.ptx"
    #optgrp.add_argument('--ptx', action='store_true', help=argparse.SUPPRESS)

    # arg: --prt FNAME
    # This option, if specified with FNAME, must be the last one the cmdline
    #
    s = ['(devel option): print output summary table from data in %(metavar)s']
    s += ['and exit. If specified, this option must be the last one on the']
    s += ['comand line. (Default %(metavar)s: "gpujoin.tms" in the logs']
    s += ['directory)']
    hstr = ' '.join(s)
    #tmsfname = str(output_path.joinpath('gpujoin.tms').resolve())
    #optgrp.add_argument('--prt', nargs='?', dest='tmsfile', metavar='FNAME',
    #        type=argparse.FileType('r'), const=tmsfname,
    #        #help=hstr)
    #        help=argparse.SUPPRESS)
    tmsfname = str(output_path.joinpath('gpujoin.tms').resolve())
    optgrp.add_argument('--prt', nargs='?', dest='tmsfile', metavar='FNAME',
            const=tmsfname,
            #help=hstr)
            help=argparse.SUPPRESS)

    # parse the command line
    return parser.parse_args()

#------------------------------------------------------------------------------
# prtlog(gpu, *o, os='', oe='\n', fd=stdout.sys, fl=False)
#   This function prints the objects *o to the log file and to the output
#   stream given by keyword parameter fd
#------------------------------------------------------------------------------
def prtlog(gpu, *o, os='', oe='\n', fd=sys.stdout, flush=False):

    # always output to log file
    print(*o, sep=os, end=oe, file=gpu.logfile, flush=flush)

    if gpu.verbose or fd is sys.stderr:
        print(*o, sep=os, end=oe, file=fd, flush=flush)

#------------------------------------------------------------------------------
# def exit_prog()
#   Closes log file and exits
#------------------------------------------------------------------------------
def exit_prog(gpu):

    # Close logfile
    gpu.logfile.close()
    sys.exit(0)

#------------------------------------------------------------------------------
# Define the entry point to the program
#------------------------------------------------------------------------------
if __name__ == '__main__':

    DEBUG = False
    if DEBUG:
        import pdb
        pdb.set_trace()

    _main()
