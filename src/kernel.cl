/******************************************************************************
 * Auto-generated kernel source
 * ----------------------------
 * The kernel source string used to build the OpenCL program for the GPU join
 * is generated from code in this file. The python function get_kernel()
 * performs this task. For reference, the generated OCL code is written to
 * '.kernel.generated.cl' in project's source directory.
 *****************************************************************************/

/******************************************************************************
 * __kernel void join_naive(global const uint* restrict lpt,
 *                          global const uint* restrict pt,
 *                          global uint ptsz,
 *                          global uint *lpid)
 *
 * This kernel performs a relational join on two input tables. The join's LEFT
 * (or FROM) table is named LPT, and the RIGHT (or TO) table is named PT.  Both
 * tables are 2-column relations that have an unsigned 32-bit integer "page id"
 * value in the first column and a 60-byte "page title" in the second. The
 * output of the join is new page id data for LPT.
 *
 * In this naive implemenation, a work-group (thread block) consists of L
 * threads, each of which scans the rows of PT to find a match for its title
 * string. When a match has been made, the page id from the matching PT row is
 * copied over to the id field in the LPT row. The entire process amounts to a
 * Cartesian Product, allbeit a partial one, since computation of output
 * (product) sets are halted when a title match has been made.
 *
 * The work-group/threadblk dimension tuple, known in OpenCL as the local_size,
 * has the generic form (L, K). The OpenCL kernels developed for this project
 * were written to run on Nvidia GPUs, which execute memory access operations
 * for blocks of 16 threads. Typically on these devices, a local_size that
 * utilizes this fact yields the best performance. In the kernels below, the
 * local_size that gave the best performance is:
 *
 *      local_size = (L, K) = (16, 1)
 *
 * K = 1 means that each thread is responsible for a single LPT row. That is, a
 * thread is assigned one row from LPT for which it is tasked with with
 * obtaining the page id. The values of L that were tested are 8, 16, and
 * 32. L = 16 means that each threadblk (i.e., instance of the kernel)
 * processes 16 LPT rows. For an input LPT of size (N, 1), the GPU grid is made
 * up of N/L threadblks, each assigned L rows from LPT.
 *
 * Input
 *  LPT: Nx1 'linkpage' table of (0, lnkpg_title) tuples
 *  PT: Mx1 'page' table of (pgid, pgtitle) tuples
 *  BLKSIZE: number of lpt rows processed by a work-group = LxK = 16
 *  ROWLEN: 16 for the naive kernel and 4 for the other kernels. Rows are
 *          processed as 32-bit values (either unsigned integers or floats),
 *          and 16 is the size of a 64-byte row in integers. In all kernels
 *          other than the naive one, the row data are vectorized using
 *          length-4 uint or float vectors. In this case, the ROWLEN is 4.
 *          Both BLKSIZE & ROWLEN are generated at build-time as #define
 *          statments in the kernel string (see get_kernel() in the Numpy
 *          code). BLKSIZE is defined mainly to enhance code readability, since
 *          the compiler can compute its value at build-time as
 *          local_size(0)*local_size(1)
 *
 * Output:
 *  lpid[N] array with the id values of LPT
 *
 * Rashad Barghouti: UNI: rb3074
 * ELEN E6893 term project, fall 2016
 *****************************************************************************/
#if KERNEL == NAIVE
 __kernel void join_naive(global const uint* restrict lpt,
                          global const uint* restrict pt,
                          const uint ptsz,
                          global uint *lpid) {

    uint i = get_local_id(0) + get_group_id(0)*BLKSIZE; // thread id
    global const uint *lp = &lpt[i*ROWLEN];
    global const uint *p;
    uint r0;                                            // title match output

    // Loop over all rows of PT
    for (uint m = 0; m < ptsz; m++) {
        p = &pt[m*ROWLEN];
        r0 = 0;
        for (uint j = 1; j < ROWLEN && !r0; j++)
            r0 = lp[j] ^ p[j];

        // if r0 = 0, a match has been found. Copy page id and bolt
        if (!r0) {
            lpid[i] = p[0];
            break;
        }
    }
}
#endif
/******************************************************************************
 * __kernel void join_vecdata_xor_ops(global const uint4* restrict lpt,
 *                                    global const uint4* restrict pt,
 *                                    const uint ptsz,
 *                                    global uint *lpid)
 *
 * This kernel uses vectors of length 4 as the data type. it is considerably
 * faster than the naive kernel. The vector length is 4, and a vector element
 * is an unsigned (32-bit) integer. A table row is an array of 4 vectors, i.e.,
 * rowlen = 4.
 *
 * Input & Output:
 *  Same as the naive kernel
 *
 * Rashad Barghouti: UNI: rb3074
 * ELEN E6893 term project, fall 2016
 *****************************************************************************/
#if KERNEL == XOR
__kernel void join_vecdata_xor_ops(global const uint4* restrict lpt,
                                   global const uint4* restrict pt,
                                   const uint ptsz,
                                   global uint *lpid) {

    // Get inidex of this thread's LPT row
    int i = get_local_id(0) + get_group_id(0)*BLKSIZE;
    global const uint4 *lp = &lpt[i*ROWLEN];
    global const uint4 *ptrow;
    int r1 = 0, m;
    uint4 r0;

    // Loop over PT to find a match for this thread's title string
    for (m = 0; m < ptsz; m++) {

        ptrow = &pt[m*ROWLEN];

        r0 = lp[0] ^ ptrow[0];
        // ignore r0.x, which contains the XOR of page-id words
        if (r0.y + r0.z + r0.w) continue;
        r0 = lp[1] ^ ptrow[1];
        if (r0.x + r0.y + r0.z + r0.w) continue;
        r0 = lp[2] ^ ptrow[2];
        if (r0.x + r0.y + r0.z + r0.w) continue;
        r0 = lp[3] ^ ptrow[3];
        if (r0.x + r0.y + r0.z + r0.w) continue;

        lpid[i] = ptrow[0].x;
        break;
    }
}
#endif
/******************************************************************************
 * __kernel void join_vecdata_oclfns(global const float4* restrict lpt,
 *                                   global const float4* restrict pt,
 *                                   const uint ptsz,
 *                                   global uint *lpid)
 *
 * This kernel also operates on vector data but uses OpenCL builtin functions
 * to perform the title-string comparisons. These functions result in fewer
 * device (PTX) instructions than do the XOR ops in the previous kernel. The
 * outcome is faster execution times, espcially for larger input sets
 *
 * Implementation note: The OpenCL built-in function isnotequal() is used to do
 * the string-compares.  This function takes float arguments, and in the first
 * implemenation of this kernel, the input data type (i.e., NumPy's arrays'
 * dtype) in gpujoin.py was changed from "dt = np.dtype[('id', 'u4'), ('title',
 * 'S60')]" to to "dt = np.dtype[('id', 'f4'), ('title', * 's60')]". This, it
 * turned out, caused loss of precision when the float id value was cast back
 * to an integer type.  The solution was to revert to 'u4', type the lpid[]
 * array below as float, and set its values without integer casting. In the
 * numpy code, the returned lpid data was simply read as uints. The loss of
 * precision was avoided.
 *
 * Rashad Barghouti: UNI: rb3074
 * ELEN E6893 term project, fall 2016
 *****************************************************************************/
#if KERNEL == OCLFNS
__kernel void join_vecdata_oclfns(global const float4* restrict lpt,
                                  global const float4* restrict pt,
                                  const uint ptsz,
                                  //global uint *lpid,
                                  global float *lpid) {

    // Index to lpt row and set up pointers
    int i = get_local_id(0) + get_group_id(0)*BLKSIZE, m;
    global const float4 *lpdata = &lpt[i*ROWLEN];
    global const float4 *pdata;

    // Loop over PT to find a match for this thread's title string
    for (m = 0; m < ptsz; m++) {

        pdata = &pt[m*ROWLEN];

        if (any(isnotequal(lpdata[0].yzw,  pdata[0].yzw))) continue;
        if (any(isnotequal(lpdata[1],  pdata[1]))) continue;
        if (any(isnotequal(lpdata[2],  pdata[2]))) continue;
        if (any(isnotequal(lpdata[3],  pdata[3]))) continue;

        //lpid[i] = (uint)(pdata[0].x);
        lpid[i] = pdata[0].x;
        break;
    }
}
#endif
/******************************************************************************
 * __kernel void join_vecdata_lmem(global const float4* restrict lpt,
 *                                 global const float4* restrict pt,
                                   const uint ptsz,
 *                                 global uint *lpid,
 *                                 local float2 *lmem)
 *
 * This kernel makes use of fast local (shared) memory to accelerate execution
 * further. Each thread in a work-group copies a corresponding page table (PT)
 * row into local memory. The title-string compares are then performed by all
 * 16 threads in a work-group on blocks of 16 PT rows in local memory.
 *
 * The Nvidia GPU used in this work is a Maxwell microarchitecture device that
 * contains 13 Streaming Multiprocessor Maxwell (SMM), althernatively denoted
 * Compute Units (CUs) in OpenCL.  Each CU is configured with with 48 KB of
 * shared memory for kernel execution. A work-group of 16 threads copies
 * 16 64-byte PT rows (1K=1024 bytes) to shared memory. For
 * the Maxwell architecutre GPU used in this work, a maximum of 32 threadblks
 * can simultaneous be active in a Compute Unit, putting the kernel's shared
 * memory usage of 32 KB well below the 48 KB available cache.
 *
 * This kernel solved the performance disadvantage the GPU had in processing
 * the larger sets (2560K, 5M, and 10M), which it processes at speed-ups of
 * ~4x, ~3x, and ~2x, respectively.
 *
 * Rashad Barghouti: UNI: rb3074
 * ELEN E6893 term project, fall 2016
 *****************************************************************************/
#if KERNEL == LMEM
__kernel void join_vecdata_lmem(global const float4* restrict lpt,
                                global const float4* restrict pt,
                                const uint ptsz,
                                global float *lpid,
                                local float2 *lmem) {

    int tid = get_local_id(0);
    int rownum = get_local_id(0) + get_group_id(0)*BLKSIZE;
    int gotmatch = false, num_matches = 0, m, k;
    global const float4 *lpd = &lpt[rownum*ROWLEN]; // ptr to LPT row data
    global const float4 *pd;                        // ptr to PT data
    volatile local int *match_cntr = &lmem[2*ROWLEN*BLKSIZE];

    // Use thread 0 to init atomic match-counter
    if (tid == 0) *match_cntr = 1;
    barrier(CLK_LOCAL_MEM_FENCE);

    // Loop over all PT rows, processing them in blocks of 16
    for (m = 0; m < ptsz && num_matches < BLKSIZE; m += BLKSIZE) {

        // Copy this thread's corresponding PT row into local memory. This step
        // needs to be done even if a title match has been made for this
        // thread. The PT row is still needed for other threads that may not
        // have yet made a title match
        //
        pd = &pt[(tid+m)*ROWLEN];
        lmem[tid] = pd[0].xy, lmem[tid+16] = pd[0].zw;
        lmem[tid+32] = pd[1].xy, lmem[tid+48] = pd[1].zw;
        lmem[tid+64] = pd[2].xy, lmem[tid+80] = pd[2].zw;
        lmem[tid+96] = pd[3].xy, lmem[tid+112] = pd[3].zw;

        // Sync threads here to ensure all PT rows are in local memory
        barrier(CLK_LOCAL_MEM_FENCE);

        for (k = 0; k < BLKSIZE && gotmatch == false; k++) {

            if (isnotequal(lpd[0].y,  lmem[k].y)) continue;
            if (any(isnotequal(lpd[0].zw, lmem[k+16]))) continue;

            if (any(isnotequal(lpd[1].xy, lmem[k+32]))) continue;
            if (any(isnotequal(lpd[1].zw, lmem[k+48]))) continue;

            if (any(isnotequal(lpd[2].xy, lmem[k+64]))) continue;
            if (any(isnotequal(lpd[2].zw, lmem[k+80]))) continue;

            if (any(isnotequal(lpd[3].xy, lmem[k+96]))) continue;
            if (any(isnotequal(lpd[3].zw, lmem[k+112]))) continue;

            gotmatch = true;
            num_matches = atomic_inc(match_cntr);
            lpid[rownum] = lmem[k].x;

        }
    }
}
#endif
/******************************************************************************
 * __kernel void join_vecdata_LPTsegments(global const float4* restrict lpt,
 *                                      const uint segoffset,
 *                                      global const float4* restrict pt,
 *                                      const uint ptsz,
 *                                      global float *lpid,
 *                                      local float2 *lmem) {
 *
 *  This kernel is called multiple times from the host to compute joins on
 *  segments of LPT. The size of PT does not change for
 *****************************************************************************/
#if KERNEL == LPTSEGS
__kernel void join_vecdata_LPTsegments(global const float4* restrict lpt,
                                       const uint segoffset,
                                       global const float4* restrict pt,
                                       const uint ptsz,
                                       global float *lpid,
                                       local float2 *lmem) {

    int tid = get_local_id(0);
    int rownum = get_local_id(0) + get_group_id(0)*BLKSIZE;
    int gotmatch = false, num_matches = 0, m, k;
    global const float4 *lpd = &lpt[(segoffset+rownum)*ROWLEN];
    global const float4 *pd;
    global float *id = &lpid[segoffset];
    volatile local int *match_cntr = &lmem[2*ROWLEN*BLKSIZE];

    // Use thread 0 to init atomic match-counter
    if (tid == 0) *match_cntr = 1;
    barrier(CLK_LOCAL_MEM_FENCE);

    // Loop over all PT rows, processing them in blocks of 16
    for (m = 0; m < ptsz && num_matches < BLKSIZE; m += BLKSIZE) {

        // Copy this thread's corresponding PT row into local memory. This step
        // needs to be done even if a title match has been made for this
        // thread. The PT row is still needed for other threads that may not
        // have yet made a title match
        //
        pd = &pt[(tid+m)*ROWLEN];
        lmem[tid] = pd[0].xy, lmem[tid+16] = pd[0].zw;
        lmem[tid+32] = pd[1].xy, lmem[tid+48] = pd[1].zw;
        lmem[tid+64] = pd[2].xy, lmem[tid+80] = pd[2].zw;
        lmem[tid+96] = pd[3].xy, lmem[tid+112] = pd[3].zw;

        // Sync threads here to ensure all PT rows are in local memory
        barrier(CLK_LOCAL_MEM_FENCE);

        for (k = 0; k < BLKSIZE && gotmatch == false; k++) {

            if (isnotequal(lpd[0].y,  lmem[k].y)) continue;
            if (any(isnotequal(lpd[0].zw, lmem[k+16]))) continue;

            if (any(isnotequal(lpd[1].xy, lmem[k+32]))) continue;
            if (any(isnotequal(lpd[1].zw, lmem[k+48]))) continue;

            if (any(isnotequal(lpd[2].xy, lmem[k+64]))) continue;
            if (any(isnotequal(lpd[2].zw, lmem[k+80]))) continue;

            if (any(isnotequal(lpd[3].xy, lmem[k+96]))) continue;
            if (any(isnotequal(lpd[3].zw, lmem[k+112]))) continue;

            gotmatch = true;
            num_matches = atomic_inc(match_cntr);
            id[rownum] = lmem[k].x;

        }
    }
}
#endif
/******************************************************************************
 * __kernel void join_vecdata_lwg(global const float4* restrict lpt,
 *                                const uint nblks,
 *                                global const float4* restrict pt,
 *                                const uint ptsz,
 *                                global uint *lpid,
 *                                local float2 *lmem)
 *
 * This kernel expands the responsibility of a work-group to include processing
 * of multiple blocks of LPT, not just a single 16x1 block. The
 * local_size tuple stays the same - (16, 1) - but the global size is adjusted.
 * The number of blocks per kernel instantiation is passed in a new 'nblks'
 * parameter.
 *
 * This kernel is much slower than previous implementations and is not used.
 *
 * Rashad Barghouti: UNI: rb3074
 * ELEN E6893 term project, fall 2016
 *****************************************************************************/
#if KERNEL == LWG
__kernel void join_vecdata_lwg(global const float4* restrict lpt,
                               const uint nblks,
                               global const float4* restrict pt,
                               const uint ptsz,
                               global float *lpid,
                               local float2 *lmem) {

    global const float4 *lpd, *pd;
    volatile local int *match_cntr = &lmem[2*ROWLEN*BLKSIZE];
    int tid = get_local_id(0);
    int rownum = get_local_id(0) + get_group_id(0)*nblks*BLKSIZE;
    int gotmatch, num_matches;
    int n, m, k;

    for (n = 0; n < nblks; n++, rownum += BLKSIZE) {

        num_matches = 0;
        gotmatch = false;

        // Use thread 0 to initialize atomic match-counter
        if (tid == 0) *match_cntr = 1;

        // Sync to ensure no threads proceed before cntr has been initialized
        barrier(CLK_LOCAL_MEM_FENCE);

        // Point to this thread's LPT row data
        lpd = &lpt[rownum*ROWLEN];

        // Loop over all PT rows, processing them in blocks of 16
        for (m = 0; m < ptsz && num_matches < BLKSIZE; m += BLKSIZE) {

            // Copy this thread's PT row into local memory. This must be done
            // even if a title match for this thread has been made. It's
            // corresponding PT row is needed for other threads until all 16
            // titles have been matched.
            //
            pd = &pt[(tid+m)*ROWLEN];
            lmem[tid] = pd[0].xy, lmem[tid+16] = pd[0].zw;
            lmem[tid+32] = pd[1].xy, lmem[tid+48] = pd[1].zw;
            lmem[tid+64] = pd[2].xy, lmem[tid+80] = pd[2].zw;
            lmem[tid+96] = pd[3].xy, lmem[tid+112] = pd[3].zw;

            // Sync threads here to ensure all PT rows are in local memory
            barrier(CLK_LOCAL_MEM_FENCE);

            // Iterate over PT rows in local memory and do a title string
            // compare with each. When a match is found, stop.
            for (k = 0; k < BLKSIZE && gotmatch == false; k++) {

                if (isnotequal(lpd[0].y,  lmem[k].y)) continue;
                if (any(isnotequal(lpd[0].zw, lmem[k+16]))) continue;

                if (any(isnotequal(lpd[1].xy, lmem[k+32]))) continue;
                if (any(isnotequal(lpd[1].zw, lmem[k+48]))) continue;

                if (any(isnotequal(lpd[2].xy, lmem[k+64]))) continue;
                if (any(isnotequal(lpd[2].zw, lmem[k+80]))) continue;

                if (any(isnotequal(lpd[3].xy, lmem[k+96]))) continue;
                if (any(isnotequal(lpd[3].zw, lmem[k+112]))) continue;

                gotmatch = true;
                num_matches = atomic_inc(match_cntr);
                lpid[rownum] = lmem[k].x;
            }
        }
    }
}
#endif
