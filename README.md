## GPU-Accelerated Relational Data Mining on Single Nodes

[Rashad Barghouti][]  
E6893, Fall 2016  
Project ID: 201612-103


- [Overview][]
- [Dependencies][]
- [Development System Specs][]
- [Processing Steps][]
- [Preparing to Run the Code][]
  - [Making the Program Files Executable][]
  - [Adding `bin` to `$PATH`][]
  - [The Programs' Command Names][]
- [Running `gpujoin.py`][]
  - [Using the Included Table Sets][]
  - [The TBLSET Argument][]
  - [Basic Invocation][]
  - [Verbose Output with the `-v` Option][]
  - [Faster Table Loads with Options `-m` & `-n`][]
  - [Specifying/Choosing an OpenCL Platform with the `-t` option][]
- [The `output` Directory][]
- [The `sav` Directory][]
- [The Dataset and MySQL Processing][]
  - [The Dataset][]
  - [`sql2txt` — Converting the SQL Dumps to CSV Tables][]
  - [`split` — Extracting a Subset of `pagelinks`][]
  - [`createdb.sql` — Creating & Fast-Loading the `wikipedia` Database][]
  - [`create-csv-tbls.sh` — Generating The GPU's Input Table Sets][]
  - [`sqljoin.sh` — Joining the Table sets on the MySQL Server][]
- [Additional Python Scripts — `genplots.py`][]


### Overview

The main component of this project is a Numerical Python (NumPy) and OpenCL
implementation that executes relational table joins on a Graphic Processing
Unit (GPU). The implementation is designed to run on a 'single-node', defined
loosely as a modern personal computing platform comprised of a host CPU system
with an attached GPU subsystem. The goal is to determine how GPU processing can
be leveraged on such machines to accelerate complex (but very common)
relational algebra computations. In each processing run, the GPU joins a pair
of 2-column tables to obtain new column data for one of them. In all, nine (9)
pairs of input tables are joined, with sizes ranging from
208*K* = 208 × 2<sup>10</sup> rows to 13*M* = 13 × 2<sup>20</sup> rows.

In addition to the GPU implementation, four others were developed, and one
imported and built from an open-source project on GitHub. The first part of
these additional implementations processes that input large input dataset to
enable its fast-loading into MySQL tables. The second is a Bash program that
executes indexed SQL table join on a MySQL server. (All results presented in
this and other project's documents were obtained from a localhost MySQL
server.) The SQL joins are designed to mimic the GPU processing and produce
execution data that can reliably be used to provide accurate comparisons with
GPU's processing.

The **input dataset is Wikipedia's** `page` and `pagelinks` tables, downloaded from
the [Wikimedia][] website. In uncompressed form, `pagelinks` is
34 GB and `page` is 5 GB. In preprocessing, a 1 GB subset is extracted from
`pagelinks` and used, along with `page`, to create a MySQL database called
`wikipedia`. After some filtering, the tables are joined to create a new table
called `linkpage`. Nine (9) subsets of `linkpage` and `page` are then generated
and written to the project's `tables` directory as CSV files, which are then
used as input to the GPU and SQL join programs.

The `-h` | `--help` options for most project programs are a good source of
information on them.

### Dependencies

-   OpenCL v1.2 
-   Python v3.4+
-   NumPy v1.12+
-   PyOpenCL 2016.1+
-   Matplotlib v2.0.0
-   MySQL v5.7.17+
-   Bash shell v4.0+
-   Prettytable][]

Specific **Python 3** features are used in the project, including the `pathlib`
module, which was added in Python v3.4. Modifying the code to run in a Python 2
environment will likely not work. For the other dependencies, lower-versioned
releases should work fine. **OpenCL** support should be available as
part of the system's GPU driver. A **PyOpenCL** installation may require
special steps on some systems; [Andreas Klöckner's wiki][] is a great source
for help. The **prettytable** module can be downloaded from the provided link
and installed on the system as a python package. If a full installation is
overkill, the file `prettytable.py` in the `sav` directory can simply be copied
to `src`. **Matplotlib v2.0.0** is only needed if the script `plotdata.py` will
be used for plotting. Finally, all shell scripts in the project utilize
**Bash**-specific features that will need to be re-coded if Bash is not the
system shell.

### Development System Specs

The system on which all code developed and tested has the following specs:

- **Host system**: 1 CPU: Intel(R) Core(TM) Quad-Core i7-6700K CPU @ 4.00GHz
- **GPU subsystem**: 1 device: Nvidia GeForce 970, Maxwell microarchitecture,
  4 GB global memory, 13 compute units (CUs), 48 KB shared memory/CU
- **OS**: Linux Mint 18 (Sarah), x86\_64
- **Linux kernel**: 4.4.0-53-generic \#74-Ubuntu SMP Fri Dec 2 15:59:10 UTC
  2016 x86\_64 GNU/Linux

### Processing Steps 

The following is the processing sequence for running the full implementation on
a new dataset.

1. Download the dataset's compressed SQL-dump files
2. Run `sql2txt` on the downloaded `.sql.gz` dumps to convert them to CSV files
3. Run `createdb.sql` to create the `wikipedia` database and load its tables
4. Run `create-csv-tbls.sh` to extract the GPU join table sets from `wikipedia`
5. Run `sqljoin.sh` to join all the table sets in MySQL
6. Run `gpujoin.py` to join tables in the GPU

The input tables for the GPU program, `gpujoin.py`, are included in the file
`tables.tar.gz` in the project's `tables` directory and can be used to run and
test GPU the program without processing any preceding steps in the list above.
However, if `sqljoin.sh` has not been run, `gpujoin.py` will not output
comparative data of its performance against MySQL's. This requires `sqljoin.sh`
to be run to produce MySQL timing data, which in turn requires creating the
`wikipedia` database and running all the steps leading up to that.

### Preparing to Run the Code 

The main code modules developed for this project are in the `src` directory.
Others, including ones that were imported and/or built from external
open-source projects (like `sql2txt`), are in the `bin` directory.

#### Making the Program Files Executable 

Before attempting to run the programs in `src`, it is good idea to ensure their
executable bits are turned on. This `chmod` command, run from a terminal window
inside `src`, should do the job.

``` bash
$ chmod +x *.py *.sh
```

#### Adding `bin` to `$PATH`

At this point, programs in `src` can be run by specifying their full (relative
or absolute) pathnames at the command-line. During development, and in the
examples discussed in this README, symbolic links to these programs are used
instead. These links, along with other non-`src` utilities, are in the
project's `bin` directory, and to use them, the directory must be added to the
user's path. To do so, the user's shell-login script (e.g., `~/.bash_profile`
or `~/.profile`) is edited to add the necessary lines. The following are two
examples. (In both, the string '/path/to/project' must be replaced with the
actual pathname `bin`.)

* Edit the shell login file directly to append the following lines. 
  Save and exit the edited file, and then source it from the command line to
  allow the changes to take effect. (Instead of sourcing the file manually,
  opening and working from a new terminal window would do it automatically.) 

    ``` bash
    # Add GPU table join `bin` directory to PATH
    export PATH="$PATH:/path/to/project/bin"
    ```

* Instead of editing the login file directly, modify it by typing the following
  long command at the shell prompt. Source the login script when done.

    ``` bash
    echo -e "\n#Add GPU table join bin directory to PATH" >> ~/.bash_profile && \
    echo 'export PATH="${PATH}:/path/to/project/bin"' >> ~/.bash_profile
    ```

#### The Programs' Command Names

Once `bin` has been added, a program in `src` can be run from anywhere in the
filesystem by using its name prefix, e.g., `gpujoin`, `sqljoin`, and
`create-csv-tbls`.

### Running `gpujoin.py`

#### Using the Included Table Sets

As mentioned in the [Processing Steps][] section, `gpujoin` can be run with
tables included in the file `tables.tar.gz` in the `tables` directory. The
following `tar` command, executed from inside the `tables` directory, will
extract the CSV table files

``` bash
$ tar xzf tables.tar.gz
```

In each GPU run, the program joins one `lpt` (*linkpage table*) with one `pt`
(*page table*). The two tables are two-column relations that *share* the
following **schema**:

|   Field   | Type           | Size (bytes) | Default |
|:---------:|----------------|:------------:|:-------:|
|   **id**  | `unsigned int` |       4      |    0    |
| **title** | `char[60]`     |      60      |         |

The `id` column data in `lpt` are set to `0`, an invalid value, and the object
of the join is to populate them with the correct values from `pt`. In total,
there are **8** `lpt–pt` pairs, shown in the table below, each named after the
length (in rows) of its `lpt`. This name/keyword is used at the `gpujoin`
command-line to specify the input tables for the join. 

*Join Table Sets (`tblsets`)*

| Set Name | Tables                    | LPT Length (rows)     |
|:--------:|---------------------------|-----------------------|
| **208K** | (lpt208K.csv, pt208K.csv) | 208*1K = 212,992      |
| **416K** | (lpt416K.csv, pt416K.csv) | 416*1K = 425,984      |
| **832K** | (lpt832K.csv, pt832K.csv) | 832*1K = 851,968      |
| **2M**   | (lpt2M.csv, pt2M.csv)     | 1.664*1M = 1,703,936  |
| **3M**   | (lpt3M.csv, pt3M.csv)     | 3.328*1M = 3,407,872  |
| **7M**   | (lpt7M.csv, pt7M.csv)     | 9984*1M = 6,815,744   |
| **10M**  | (lpt10M.csv, pt10M.csv)   | 6656*1M = 6,815,744   |
| **13M**  | (lpt13M.csv, pt13M.csv)   | 13312*1M = 13,631,488 |
| **16M**  | (lpt16M.csv, pt16M.csv)   | 16384*1M = 16,777,488 |

Although not shown in the table, a full `tblset` is the tuple `(lpt, pt, rt)`,
which includes an `rt` (*reference table*). This table is simply an `lpt` with
correct `id` data that are used the end of each GPU run to verify the
correctness of join output data.

#### The TBLSET Argument

The `gpujoin` program has the following command-line usage:

``` bash
$ gpujoin [OPTIONS] TBLSET [TBLSET ...]
```

The positional argument `TBLSET` specifies the input table set for the join and
can be any one of the name keywords shown in the first column of the `tblsets`
table. The following are some examples:

```bash
# Run gpujoin on set 104K, i.e., join tables lpt104K.csv and pt104.csv and
# verify output with data from with rt104K.csv
$ gpujoin 104K

# Run on sets 832K, 3M, and 7M
$ gpujoin 832K 3M 7M
```

**The `all` keyword** can be used as a `TBLSET` positional argument to run
`gpujoin` on all sets:

```bash
# Join tables in all sets
$ gpujoin all
```

#### Basic Invocation 

`gpujoin` is controlled through several command-line arguments. The help option
`[-h | --help]` displays detailed information on all.

The basic invocation of `gpujoin` requires only the positional argument
`TBLSET`. The following command runs a join on sets `416K` and `832K`. A
summary table is printed out at the end of all runs.

```bash
$ gpujoin 416K 832K

GPU table join(s) completed with no errors.

Output Summary. All times in sec.
+-----------------------+--------+--------+
|                       |   416K |   832K |
+-----------------------+--------+--------+
|   linkpage table size | 425984 | 851968 |
|       page table size |   5664 |  11696 |
|           device time | 0.0536 | 0.2089 |
|            total time | 0.0576 | 0.2149 |
| MySQL processing time | 2.3744 | 4.9065 |
|          GPU speed-up |  44.3x | 23.49x |
+-----------------------+--------+--------+
```

#### Verbose Output with the `-v` Option

```bash
$ gpujoin -v 832K 2M

Time: Sat Dec 31 00:58:58 2016
Using default OpenCL platform: NVIDIA CUDA

Table set: 832K 
———————————————
Reading lpt832K.csv
851968 rows loaded (4.035 sec)
Reading pt832K.csv
11696 rows loaded (0.05826 sec)
Reading rt832K.csv
851968 rows loaded (4.018 sec)

Begin GPU processing
Kernel: join_vecdata_lmem()
Done!
 GPU (profiling) time: 0.218 sec
 total (GPU+Host) time: 0.2243 sec
 output == reference: True

Table set: 2M 
—————————————
Reading lpt2M.csv
1703936 rows loaded (7.864 sec)
Reading pt2M.csv
22832 rows loaded (0.1123 sec)
Reading rt2M.csv
1703936 rows loaded (8.083 sec)

Begin GPU processing
Kernel: join_vecdata_lmem()
Done!
 GPU (profiling) time: 0.7812 sec
 total (GPU+Host) time: 0.7918 sec
 output == reference: True


GPU table join(s) completed with no errors.
Processing times written to "gpujoin.tms" & "gpujoin-lmem.tms" in output directory

Output Summary. All times in sec.
+-----------------------+--------+---------+
|                       |   832K |      2M |
+-----------------------+--------+---------+
|   linkpage table size | 851968 | 1703936 |
|       page table size |  11696 |   22832 |
|           device time |  0.218 |  0.7812 |
|            total time | 0.2243 |  0.7918 |
| MySQL processing time | 4.9065 |  9.7493 |
|          GPU speed-up | 22.51x |  12.48x |
+-----------------------+--------+---------+
```

#### Faster Table Loads with Options `-m` & `-n`

NumPy's `loadtxt()` is used by `gpujoin.py` to load csv tables into structured
*ndarrays*. Its is much slower than other csv readers but offers specific
functionality for structured *ndarrays* that are time-consuming to workaround.
A workaround is to use the `-m` option to dump the *ndarrays* to binary `npy`
files and, in subsequent runs, use the `-n` to load the ndarrays from those
`npy` files. The speed-ups are substantial—over 450-fold for the `7M` set, as
shown below. On the downside, `npy` dumps are typically 3-4 times larger than
their csv counterparts, which can possibly prohibit their use with very large
tables.

```bash
$ gpujoin -vm 7M

Time: Sat Dec 31 01:07:32 2016
Using default OpenCL platform: NVIDIA CUDA

Table set: 7M 
—————————————
Reading lpt7M.csv
6815744 rows loaded (31.87 sec)
Reading pt7M.csv
158064 rows loaded (0.8194 sec)
Reading rt7M.csv
6815744 rows loaded (33 sec)

Begin GPU processing

$ gpujoin -vn 7M

Time: Sat Dec 31 17:46:06 2016
Using default OpenCL platform: NVIDIA CUDA

Table set: 7M 
—————————————
Reading lpt7M.npy
6815744 rows loaded (0.0654 sec)
Reading pt7M.npy
158064 rows loaded (0.002469 sec)
Reading rt7M.npy
6815744 rows loaded (0.0639 sec)

Begin GPU processing

$ l -Gg lpt7M.*
-rw-r--r-- 1 170M Dec 31 03:00 lpt7M.csv
-rw-r--r-- 1 417M Dec 31 17:08 lpt7M.npy
```

#### Specifying/Choosing an OpenCL Platform with the `-t` option

This default OpenCL platform is 'NVIDIA CUDA'. The `-t` option can be used to
explicitly enter a platform name, if one is known (e.g., AMD or INTEL). It can
can also be used to have `gpujoin` look for available platforms and then either
(1) choose one automatically for the user or (2) prompt him or her for a
choice.

Use `gpujoin -h | --help` to show details on the `-t` option.

The utility `oclplat.py` in the `src` directory can also be used to list OpenCL
platforms and attached GPUs on the system. Here's its output for the
platform used in this development

```bash

$ oclplat

OpenCL platform
---------------
 name: NVIDIA CUDA
 vendor: NVIDIA Corporation
 version: OpenCL 1.2 CUDA 8.0.0
 device:
 ------
  Name: GeForce GTX 970
  Type: GPU
  Max clock frequency: 1177 MHz
  Number of compute units: 13
  Global mem size: 4036 MiB
  Global mem cache type: READ_WRITE_CACHE
  Global mem cache size: 208 KiB
  Global mem cacheline size: 128 bytes
  Local mem size: 48 KiB
  Profiling timer resolution: 1000 nanoseconds
  Max work group size: 1024
  Driver version: 378.13
  OpenCL version: OpenCL C 1.2 
```

### The `output` Directory

Logs and output files generated by the project's programs are written to this
directory. `gpujoin` and `sqljoin` write their execution data at the end of
every run to `.tms` files in that directory as well. These data files are
read by gpujoin for displaying output performance data and for plotting
report figures. 

### The `sav` Directory

This directory has some older versions and/or different implementations of the
programs in 'src'. It also included sample output files generated from various
runs.

### The Dataset and MySQL Processing

The following corresponds to [Processing Steps][] 1-5. To make gains from GPU
worthwhile, it was important to optimize these steps and process them as fast
as possible. Collectively, they were completed in a little less than 15
minutes, starting with ingestion of a 40 GB dataset.

For a quick start, this listing shows the commands for running all the programs
leading up to `gpujoin`. For the details, see the sections that follow.

```bash
# Run sql2txt in the dataset directory to convert the sql dumps to csv format
$ sql2txt -s *pagelinks*.gz -t pagelinks; mv pagelinks pagelinks.csv
$ sql2txt -s *page.sql.gz -t page; mv page page.csv

# Use Linux 'split' command to extract a 1-GB section from pagelinks.csv
$ split -d -n l/2/34 pagelinks.csv > pagelinks-01.csv

# 1. Move pagelinks-01.csv & page.csv to MySQL server's 'files' directory
# 2. Run createdb.sql
$ mysql < createdb.sql

# Run create-csv-tables.sh to generate the GPU-join sets (LPT, PT, RT)
$ create-csv-files

# Run SQL joins on all (LPT, PT) pairs to obtain MySQL performance data
$ sqljoin

```

#### The Dataset

Two Wikipedia tables, `page` and `pagelinks`, are the dataset. They can be 
downloaded from the encyclopedia's [enwiki dump progress on 20161020][]. The 
specific links are:

-   [enwiki-20161020-page.sql.gz (1.4 GB)][] and
-   [enwiki-20161020-pagelinks.sql.gz (4.9 GB)][]

> If these are not valid links, then it is very likely this particular SQL
> dump has been taken offline. Newer en-lang dumps will do and can be obtained
> from [Wikimedia][])

This is listing of the dataset directory on the development system

```bash
$ l -Gg
total 6.3G
-rw-r--r-- 1 5.0G Nov 21 12:05 enwiki-20161020-pagelinks.sql.gz
-rw-r--r-- 1 1.4G Nov 23 05:35 enwiki-20161020-page.sql.gz
```

In uncompressed form, the SQL dumps' sizes are 4.4 GB (`page`) and 36 GB
(`pagelinks`). `page` contains information on all pages in the encyclopedia,
and `pagelinks` has records of all the hyperlinks pages contain to other pages.
One row in `page` contains 14 fields, of which only two are consumed and used
by the implementation. Similarly, only two out of four `pagelinks'` fields are
kept. The full schemas of both tables can be found on MediaWiki's website at
[page table schema][] and [pagelinks table schema][].

#### `sql2txt` — Converting the SQL Dumps to CSV Tables

If the 40+ GB SQL dumps were to be loaded into MySQL, the process, on a personal
machine, will most likely hang after 2+ days of running. To accelerate these
loads, MySQL's **LOAD DATA INFILE** command—which takes a text (CSV)
file as input and loads its content into a MySQL table—is used. Although
not measured, the speed-up from using this command is well over 30x. 

To convert the input SQL dump files to CSV format, an open-source C-language
program, called `sql2txt.c`, was used. It is part of [this open-source project
on GitHub][], which must be built entirely in order to obtain the `sql2txt`
binary. The program is in included in `bin`. Use `sql2txt -h` to obtain its
usage information. Here's a timed run of it that converts the dumps directly
from their compressed form.

> `timeit` is a simple utility, also included in `bin`, that uses GNU's `time`
> command.*

``` bash
# Convert the pagelinks SQL dump
$ timeit sql2txt -s *pagelinks*.gz -t pagelinks; mv pagelinks pagelinks.csv

  Time: 6:47.35 (min:sec)

# Convert the page SQL dump
$ timeit sql2txt -s *page.sql.gz -t page; mv page page.csv

  Time: 1:03.08 (min:sec)

# Show the CSV files
$ l -Gg           
total 44G
-rw-r--r-- 1 5.0G Nov 21 12:05 enwiki-20161020-pagelinks.sql.gz
-rw-r--r-- 1 1.4G Nov 23 05:35 enwiki-20161020-page.sql.gz
-rw-r--r-- 1 4.3G Dec 28 23:57 page.csv
-rw-r--r-- 1  34G Dec 28 23:56 pagelinks.csv
```

***sql2txt processing summary***

| SQL Input        | Size   | CSV Output    | Size   | Conversion time |
|------------------|--------|---------------|--------|-----------------|
| pagelinks.sql.gz | 5.0 GB | pagelinks.csv | 34 GB  | 6 min 47 sec    |
| page.sql.gz      | 1.4 GB | page.csv      | 4.3 GB | 1 min 3 sec     |


#### `split` — Extracting a Subset of `pagelinks` 

A 1-GB subset of `pagelinks` is used to generate the `gpujoin's` (LPT, RT)
sets. Linux split(1) command is used to extract this subset from
`pagelinks.csv`.

``` bash
# Split the 34-GB pagelinks.csv into 34 equal parts without breaking any lines
$ timeit split -d -n l/34 pagelinks.csv pagelinks-

  Time: 2:20.32 (min:sec)

# Long-list to show the split files
$ l -Gg
total 78G
-rw-r--r-- 1  5.0G Nov 21 12:05 enwiki-20161020-pagelinks.sql.gz
-rw-r--r-- 1  1.4G Nov 23 05:35 enwiki-20161020-page.sql.gz
-rw-r--r-- 1  4.3G Dec 28 23:57 page.csv
-rw-r--r-- 1 1007M Dec 29 02:04 pagelinks-00
-rw-r--r-- 1 1007M Dec 29 02:04 pagelinks-01
...
-rw-r--r-- 1 1007M Dec 29 02:07 pagelinks-33
-rw-r--r-- 1   34G Dec 28 23:56 pagelinks.csv
```

`split` can be used to extract only the needed 1-GB subset. This shows the
extraction of the second 1-GB segment of `pagelinks.csv` in **0.47 sec**. The
output file is `pagelinks-01.csv` 

``` bash
$ rm pagelinks-*
$ timeit split -d -n l/2/34 pagelinks.csv > pagelinks-01.csv

  Time: 0:00.47 (min:sec)

$ l -gG
total 45G
-rw-r--r-- 1  5.0G Nov 21 12:05 enwiki-20161020-pagelinks.sql.gz
-rw-r--r-- 1  1.4G Nov 23 05:35 enwiki-20161020-page.sql.gz
-rw-r--r-- 1  4.3G Dec 28 23:57 page.csv
-rw-r--r-- 1 1007M Dec 29 02:23 pagelinks-01.csv
-rw-r--r-- 1   34G Dec 28 23:56 pagelinks.csv
```

#### `createdb.sql` — Creating & Fast-Loading the `wikipedia` Database

Once the CSV tables have been created, the script `src/createdb.sql` can be
used to:

1. Create a MySQL database named `wikipedia` and its two tables, `page` and
   `linkpage`
2. Load the tables from `page.csv` and `pagelinks-01.csv` using the `LOAD DATA
   INFILE` statement
3. filter and join the tables to obtain the populate the `id` column of
   `linkpage`. This data will be used as reference for checking the output of
   the GPU.

Assuming a connection to a mysql server, `createdb.sql` can be sourced by a
mysql client at the command-line:

``` bash
$ timeit mysql < createdb.sql
Thu Dec 29 07:05:21 PST 2016

  Time: 7:57.61 (min:sec)
$
```

To examine details of `createdb.sql's` execution, the statements in the file
can be cut and pasted in a mysql client. A file containing such output details
is `createdb.output.sql` in the `output` directory. An excerpt from it below
CREATE TABLE commands for the tables `page` and `linkpage` and the loading of
of their data from `page.csv` and `pagelinks-01.csv`, respectively. 

> **Note**: The LOAD DATA INFILE command, when used without the `LOCAL` keyword
> (as is the case in `createdb.sql`), causes the server to read the input CSV
> files directly—i.e., without the client's involvement in moving the data to
> the server's host. The MySQL's system variable `secure_file_priv` determines
> the directory in which the server expects to find the files. It is a secure
> location that requires FILE privileges to access. To execute the LOAD command
> in createdb.sql, `pagelinks-01.csv` and `page.csv` must be moved to that
> directory. Its location on the host can be determined from inside a client
> app with the command:`SHOW VARIABLES LIKE 'secure_files_priv'`. (In a typical
> Debian installation, the directory is /var/lib/mysql-files.) To move the CSV
> files to this directory, the user must have FILE privileges. On a localhost
> server, root privileges can be used. Once moved, the `LOAD DATA INFILE` in
> `createdb.sql` needs to be modified to include the correct path to the files.
> For this project, the MySQL server was compiled from source and installed in
> a way that granted all necessary privileges to one user on the localhost. The
> paths shown in the LOAD statement below are relative to this installation's
> directory.

``` sql
DROP DATABASE IF EXISTS wikipedia;
CREATE DATABASE wikipedia;
USE wikipedia
DROP TABLE IF EXISTS page;

CREATE TABLE page (
 id INT(8) UNSIGNED NOT NULL AUTO_INCREMENT,
 namespace INT(10) NOT NULL DEFAULT '0',
 title VARBINARY(255) NOT NULL DEFAULT '',
 PRIMARY KEY (id))
ENGINE = MyISAM DEFAULT CHARSET = BINARY;

LOAD DATA INFILE '../files/page.csv' INTO TABLE page (id, namespace, title);
-- Query OK, 40668831 rows affected, 65535 warnings (1 min 23.73 sec)
-- Records: 40668831  Deleted: 0  Skipped: 0  Warnings: 40668846

DELETE FROM page WHERE namespace != 0;
-- Query OK, 27821452 rows affected (1 min 36.34 sec)
ALTER TABLE page DROP COLUMN namespace;
-- Query OK, 12847379 rows affected (15.91 sec)
-- Records: 12847379  Duplicates: 0  Warnings: 0

DROP TABLE IF EXISTS linkpage;
-- Query OK, 0 rows affected, 1 warning (0.00 sec)
CREATE TABLE linkpage (
 id INT(8) UNSIGNED NOT NULL DEFAULT 0,
 title VARBINARY(255) NOT NULL DEFAULT '')
ENGINE = MyISAM DEFAULT CHARSET = BINARY;
-- Query OK, 0 rows affected (0.01 sec)

LOAD DATA INFILE '../files/pagelinks-01.csv'
INTO TABLE linkpage (@dummy, @dummy, title, @dummy);
-- Query OK, 30297676 rows affected (14.84 sec)
-- Records: 30297676  Deleted: 0  Skipped: 0  Warnings: 0
```

*summary table*

| Table      | CSV Input        | Number of Rows Loaded | Time             |
|------------|------------------|-----------------------|------------------|
| `page`     | page.csv         | 40,668,831            | 6 min 47 sec     |
| `linkpage` | pagelinks-01.csv | 30,297,676            | 15 sec           |

Next, `linkpage` and `page` are joined to obtain the data for the `id` column
in `linkpage`. This output `linkpage` table is the one from which the `gpujoin`
input sets are extracted. The following are the statements in `createdb.sql`
that perform the join.

```sql
CREATE INDEX title ON page (title);
-- Query OK, 12847379 rows affected (36.44 sec)
-- Records: 12847379  Duplicates: 0  Warnings: 0

UPDATE linkpage, page
SET linkpage.id = page.id
WHERE linkpage.title = page.title;
-- Query OK, 24814938 rows affected (3 min 18.19 sec)
-- Rows matched: 24814938  Changed: 24814938  Warnings: 0
```

Finally, `createdb.sql` produces prints out statistics on the database tables.

```sql
+-----------------+
| numrows in page |
+-----------------+
|        12847379 |
+-----------------+
+-------+-------------------+--------------------+
| Table | Data length (MiB) | Index length (MiB) |
+-------+-------------------+--------------------+
| page  |            399.36 |             482.22 |
+-------+-------------------+--------------------+

+---------------------+
| numRows in linkpage |
+---------------------+
|            24814938 |
+---------------------+
+----------+-------------------+--------------------+
| Table    | Data length (MiB) | Index length (MiB) |
+----------+-------------------+--------------------+
| linkpage |           1135.45 |               0.00 |
+----------+-------------------+--------------------+
```

#### `create-csv-tbls.sh` — Generating The GPU's Input Table Sets

`create-csv-tbls.sh` is a bash script that runs SELECT queries on the mysql
server to extract `RT` tables from `linkpage` table. The Linux `awk` command is
then used to obtain `LPT` by setting to 0 the `id` column values in
corresponding `RT`. Finally, the Linux `uniq` command is used to create `PT` by
selecting the unique rows in `RT`.

``` bash
$ timeit create-csv-tbls > output/create-csv-tbls.output

  Time: 0:33.32 (min:sec)
```

#### `sqljoin.sh` — Joining the Table sets on the MySQL Server

`sqljoin.sh` runs joins on the mysql server on **all** table sets. It emulates
the GPU processing by first reading each input set from CSV files and then
executing a SQL UPDATE command to do the JOIN. 

**Table Indexes**: Table joins performed in MySQL use **indexes**. The
computations would otherwise be extremely time-consuming (on the order of
hours) and inadequate as reference for GPU performance.

`sqljoin` can be run by simply typing its name at the command-line. However, if
options need to be passed to the mysql server, the script provides a mechanism
to do so. Use `sqljoin -h` to display the necessary usage information.

``` bash
sqljoin
```

### Additional Python Scripts — `genplots.py`

**genplots.py** is a matplotlib python script that reads JOIN times data from
“allsets” `.tms` files in the `output` directory and plots them

-------------------------------------------------------------------------------

[Rashad Barghouti]: rb3074@columbia.edu
[Overview]: #overview
[Dependencies]: #dependencies
[Development System Specs]: #development-system-specs
[Processing Steps]: #processing-steps
[Preparing to Run the Code]: #preparing-to-run-the-code
[Making the Program Files Executable]: #making-the-program-files-executable
[Adding `bin` to `$PATH`]: #adding-bin-to-path
[The Programs' Command Names]: #the-programs-command-names
[Running `gpujoin.py`]: #running-gpujoinpy
[Using the Included Table Sets]: #using-the-included-table-sets
[The TBLSET Argument]: #the-tblset-argument
[Basic Invocation]: #basic-invocation
[Verbose Output with the `-v` Option]: #verbose-output-with-the--v-option
[Faster Table Loads with Options `-m` & `-n`]: #faster-table-loads-with-options--m---n
[Specifying/Choosing an OpenCL Platform with the `-t` option]: #specifyingchoosing-an-opencl-platform-with-the--t-option
[The `output` Directory]: #the-output-directory
[The `sav` Directory]: #the-sav-directory
[The Dataset and MySQL Processing]: #the-dataset-and-mysql-processing
[The Dataset]: #the-dataset
[`sql2txt` — Converting the SQL Dumps to CSV Tables]: #sql2txt--converting-the-sql-dumps-to-csv-tables
[`split` — Extracting a Subset of `pagelinks`]: #split--extracting-a-subset-of-pagelinks
[`createdb.sql` — Creating & Fast-Loading the `wikipedia` Database]: #createdbsql--creating--fast-loading-the-wikipedia-database
[`create-csv-tbls.sh` — Generating The GPU's Input Table Sets]: #create-csv-tblssh--generating-the-gpus-input-table-sets
[`sqljoin.sh` — Joining the Table sets on the MySQL Server]: #sqljoinsh--joining-the-table-sets-on-the-mysql-server
[Additional Python Scripts — `genplots.py`]: #additional-python-scripts--genplotspy


[Wikimedia]: https://dumps.wikimedia.org/enwiki
[Prettytable]: https://github.com/dprince/python-prettytable "prettytable on GitHub"
[Andreas Klöckner's wiki]: https://wiki.tiker.net/PyOpenCL
[enwiki dump progress on 20161020]: https://dumps.wikimedia.org/enwiki/20161020 "Wikimedia's Oct. 16, 2016 dumps"
[enwiki-20161020-page.sql.gz (1.4 GB)]: https://dumps.wikimedia.org/enwiki/20161020/enwiki-20161020-page.sql.gz "page table sql dump"
[enwiki-20161020-pagelinks.sql.gz (4.9 GB)]: https://dumps.wikimedia.org/enwiki/20161020/enwiki-20161020-pagelinks.sql.gz "pagelinks table sql dump"
[page table schema]: https://www.mediawiki.org/wiki/Manual:Page_table
[pagelinks table schema]: https://www.mediawiki.org/wiki/Manual:Pagelinks_table
[this open-source project on GitHub]: https://github.com/nforrester/6.834-final-project "Troy Astorino's and Neil Forrester's 6.834-final-project"
