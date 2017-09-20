#!/bin/bash
#
# *** USE create-csv-tbls.sh to generate the csv files. It's much faster. ***
#
# This script generates the CSV table files needed for the table JOINs. The
# output files are stored in the project's "tables" directory.
#
# Input: 
#  wikipedia database and its two tables, 'page' and 'linkpage'. If it does not
#  exist, the db can be created with creat-db.sql
#
# Usage:
#  createtbls [-h | --help]
#
# See README.md for **important** usage notes
#
# Running the script:
#  1. Add the project's bin directory to path, e.g.,
#       $ export PATH=$PATH:/path/to/project/tree/bin
#  2. from anywhere type:
#       $ createtbls
#  Alternatively,
#  3. from the project's directory, execute the command:
#       $ ./src/createtbls.sh
#
# Rashad Barghouti
# rb3074@columbia.edu
# E6893, Fall 2016
#------------------------------------------------------------------------------

prog=$(basename $0)

#------------------------------------------------------------------------------
# parse_cmdline()
#  Parse command-line for mysql options. (Use straight bash without getopt[s])
#------------------------------------------------------------------------------
display_usage() {
    echo -e "usage: $(basename $0) [-h] [-o string]\n"
    echo -e "Generate table files for the GPU JOIN\n"
    echo Optional arguments:
    echo "  -h, --help            show this help message and exit"
    echo "  -o, --options string  quoted string of additional cmdline" 
    echo "                        arguments to pass to MySQL server. For"
	echo "                        reason (& implementation overhead), the -p"
	echo "						  and --password options are not passed to the"
	echo "						  server. If necessary, the utility"
	echo "						  mysql_config_editor can be used to establish"
	echo "						  encrypted login credentials via a"
	echo "						  ~/.mylogin.cnf file. An example/typical"
	echo "						  usage is: mysql_config_editor set \\"
	echo "						  --login-path=client --host=localhost \\"
    echo "  					  --user=<mysql-username> --password"
    exit 0
};

userargs=
while [[ $# -gt 0 ]]
do
    case $1 in
        -h|--help)
            display_usage
            ;;
        -o|--options)
            userargs="$2"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# Trap password argument
if [[ $userargs =~ .*\-p.* ]]; then
    echo "mysql userargs: $userargs"
    echo -n "$prog: Error: mysql password option is not supported. "
    echo "See usage."
    exit 0
fi

error_exit() {
    echo -e "$prog: Error: the command \"mysql ${allargs}\" failed."
    exit 1
};

#------------------------------------------------------------------------------
# Begin table generation (mysql processing)
#------------------------------------------------------------------------------

# get real path to project's tables directory
tblsdir=$(readlink -f $(dirname $(readlink -f $0))/../tables)

# Delete existing npy files; csv files will be overwritten
if [ -d $tblsdir ]; then
    rm $tblsdir/*.npy &>/dev/null;
else 
    echo -e "\nCreating project's tables directory"
    mkdir -p $tblsdir;
fi

# Use -N to suppress column headers
allargs="${userargs} -Ne"

echo -e "\n$(date)"

# Create linkpage tables. Use -N option to exclude header rows
echo -e "\nCreating linkpage tables' files"
echo -------------------------------
#echo lpt1K.csv
#$(mysql ${allargs} "SELECT 0 AS id, title FROM linkpage \
#WHERE LENGTH(title) < 61 LIMIT 1024" > $tblsdir/lpt1K.csv wikipedia)
#if [[ $? != 0 ]]; then error_exit; fi

echo lpt5K.csv
$(mysql $userargs -Ne "SELECT 0 AS id, title FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 5120" > $tblsdir/lpt5K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo lpt10K.csv
$(mysql $userargs -Ne "SELECT 0 AS id, title FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 10240" > $tblsdir/lpt10K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo lpt20K.csv
$(mysql $userargs -Ne "SELECT 0 AS id, title FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 20480" > $tblsdir/lpt20K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo lpt40K.csv
$(mysql $userargs -Ne "SELECT 0 AS id, title FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 40960" > $tblsdir/lpt40K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo lpt80K.csv
$(mysql $userargs -Ne "SELECT 0 AS id, title FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 81920" > $tblsdir/lpt80K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo lpt160K.csv
$(mysql $userargs -Ne "SELECT 0 AS id, title FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 163840" > $tblsdir/lpt160K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo lpt320K.csv
$(mysql $userargs -Ne "SELECT 0 AS id, title FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 327680" > $tblsdir/lpt320K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo lpt640K.csv
$(mysql $userargs -Ne "SELECT 0 AS id, title FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 655360" > $tblsdir/lpt640K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo lpt1280K.csv
$(mysql $userargs -Ne "SELECT 0 AS id, title FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 1310720" > $tblsdir/lpt1280K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo lpt2560K.csv
$(mysql $userargs -Ne "SELECT 0 AS id, title FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 2611440" > $tblsdir/lpt2560K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo lpt5M.csv
$(mysql $userargs -Ne "SELECT 0 AS id, title FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 5242880" > $tblsdir/lpt5M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo lpt10M.csv
$(mysql $userargs -Ne "SELECT 0 AS id, title FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 10485760" > $tblsdir/lpt10M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

# Create linkpage reference tables
echo -e "\nCreating linkpage reference tables' files"
echo -----------------------------------------
#echo rt1K.csv
#$(mysql $userargs -Ne "SELECT * FROM linkpage \
#WHERE LENGTH(title) < 61 LIMIT 1024" > $tblsdir/rt1K.csv wikipedia)
#if [[ $? != 0 ]]; then error_exit; fi

echo rt5K.csv
$(mysql $userargs -Ne "SELECT * FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 5120" > $tblsdir/rt5K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt10K.csv
$(mysql $userargs -Ne "SELECT * FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 10240" > $tblsdir/rt10K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt20K.csv
$(mysql $userargs -Ne "SELECT * FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 20480" > $tblsdir/rt20K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt40K.csv
$(mysql $userargs -Ne "SELECT * FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 40960" > $tblsdir/rt40K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt80K.csv
$(mysql $userargs -Ne "SELECT * FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 81920" > $tblsdir/rt80K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt160K.csv
$(mysql $userargs -Ne "SELECT * FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 163840" > $tblsdir/rt160K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt320K.csv
$(mysql $userargs -Ne "SELECT * FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 327680" > $tblsdir/rt320K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt640K.csv
$(mysql $userargs -Ne "SELECT * FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 655360" > $tblsdir/rt640K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt1280K.csv
$(mysql $userargs -Ne "SELECT * FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 1310720" > $tblsdir/rt1280K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt2560K.csv
$(mysql $userargs -Ne "SELECT * FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 2611440" > $tblsdir/rt2560K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt5M.csv
$(mysql $userargs -Ne "SELECT * FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 5242880" > $tblsdir/rt5M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt10M.csv
$(mysql $userargs -Ne "SELECT * FROM linkpage \
WHERE LENGTH(title) < 61 LIMIT 10485760" > $tblsdir/rt10M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

# Create page tables
echo -e "\nCreating page tables' files"
echo ---------------------------
echo pt320K.csv
$(mysql $userargs -Ne "SELECT * from page \
WHERE title REGEXP BINARY '^\'2014_' \
AND LENGTH(title) < 61" > $tblsdir/pt320K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

#echo pt640K.csv
#$(mysql $userargs -Ne "SELECT * from page \
#WHERE title REGEXP BINARY '^\'2014' \
#AND LENGTH(title) < 61" > $tblsdir/pt640K.csv wikipedia)
#if [[ $? != 0 ]]; then error_exit; fi

echo pt1280K.csv
$(mysql $userargs -Ne "SELECT * from page \
WHERE title REGEXP BINARY '^\'201[45]' \
AND LENGTH(title) < 61" > $tblsdir/pt1280K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo pt2560K.csv
$(mysql $userargs -Ne "SELECT * from page \
WHERE title REGEXP BINARY '^\'([2-9][0-9]{3,}|A[A-R])' \
AND LENGTH(title) < 61" > $tblsdir/pt2560K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo pt5M.csv
$(mysql $userargs -Ne "SELECT * from page \
WHERE title REGEXP BINARY '^\'([2-9][0-9]{3,}|A[A-Za-d])' \
AND LENGTH(title) < 61" > $tblsdir/pt5M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo pt10M.csv
$(mysql $userargs -Ne "SELECT * from page \
WHERE title REGEXP BINARY '^\'([2-9][0-9]{3,}|A[A-Za-l])' \
AND LENGTH(title) < 61" > $tblsdir/pt10M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

#echo pt15M.csv
#$(mysql $userargs -Ne "SELECT * from page \
#WHERE title REGEXP BINARY '^\'([2-9][0-9]{3,}|A[A-Za-n])' \
#AND LENGTH(title) < 61" > $tblsdir/pt15M.csv wikipedia)
#if [[ $? != 0 ]]; then error_exit; fi

#echo ptall.csv
#$(mysql $userargs -Ne "SELECT * from page \
#WHERE title REGEXP BINARY '^\'(201|A[a-n])' \
#AND LENGTH(title) < 61" > $tblsdir/ptall.csv wikipedia)
#if [[ $? != 0 ]]; then error_exit; fi

# Done mysql processing

#------------------------------------------------------------------------------

