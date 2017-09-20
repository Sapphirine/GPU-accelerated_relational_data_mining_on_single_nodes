#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#  gpu-info.py
#   Print out info on the OpenCL platform(s) available on the system and the
#   devices attached to them
#
# Rashad Barghouti
# rb3074@columbia.edu
# EECS E6893, Fall 2016
#------------------------------------------------------------------------------
import pyopencl as cl

for plt in cl.get_platforms():
    print('\nOpenCL platform')
    print('---------------')
    print(' name: {}'.format(plt.name))
    print(' vendor: {}'.format(plt.vendor))
    print(' version: {}'.format(plt.version))

    for device in plt.get_devices():
        print(' device:')
        print(' ------')
        print('  Name: {}'.format(device.name))
        print('  Type: {}'.format(cl.device_type.to_string(device.type)))
        print('  Max clock frequency: {} MHz'
                .format(device.max_clock_frequency))
        print('  Number of compute units: {}'.format(device.max_compute_units))
        print('  Global mem size: {} MiB'
                .format(device.global_mem_size//1024//1024))
        print('  Global mem cache type: {}'
                .format(cl.device_mem_cache_type
                    .to_string(device.global_mem_cache_type)))
        print('  Global mem cache size: {} KiB'
                   .format(device.global_mem_cache_size//1024))
        print('  Global mem cacheline size: {} bytes'
                   .format(device.global_mem_cacheline_size))
        print('  Local mem size: {} KiB'.format(device.local_mem_size//1024))
        print('  Profiling timer resolution: {} nanoseconds'
                   .format(device.profiling_timer_resolution))
        print('  Max work group size: {}'.format(device.max_work_group_size))
        print('  Driver version: {}'.format(device.driver_version))
        print('  OpenCL version: {}'.format(device.opencl_c_version))

