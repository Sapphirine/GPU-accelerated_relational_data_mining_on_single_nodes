#!/usr/bin/env bash
#
# This script generates the CSV input table files the GPU and SQL join
# programs. The output files are stored in the "tables" directory.
#
# (Unlike its earlier version  createtbls.sh, which can be found in the 'sav'
# directory, this script does not use mysql queries to create all three types
# of tables, LPT, PT and RT. It only does so to extract the RTs from the the
# `wikipedia` database `linkpage` table and then uses Linux system's "awk" and
# "uniq" programs to create the the LPTs and PTs , respectively, from the RTs.
# This is a # much faster implementation.
#
# Input: 
#  The mysql database `wikipedia` and it's `linkpage` table.
#  (The database and the tables are created by the createdb.sql script.)
#
# Usage:
#  create-csv-tbls [-h | --help] [-o | --options OPTS]
#  use the -h option to display useful usage details. Also see README.md for
#  additional important usage notes
#
# Running the script:
#  	1. Add the project's bin directory to path, e.g.,
#       $ export PATH=$PATH:/path/to/project/tree/bin
#  	2. from anywhere type:
#       $ create-csv-tbls
# Or
#  	3. from from the project's src directory, do
#       $ ./create-csv-tbls.sh
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
    echo -e "usage: $(basename $0) [-h | --help] [-o string]\n"
    echo -e "Generate table files for the GPU and SQL join programs\n"
    echo Optional arguments:
    echo "  -h, --help            show this help message and exit"
    echo "  -o, --options OPTS    OPTS is quoted string of options to pass"
	echo "                        to the mysql server. For several reasons,"
	echo "                        password options (-p & --password) are"
	echo "                        trapped and not passed. If necessary," 
	echo "                        mysql_config_editor can be used to establish"
	echo "                        encrypted login credentials via a"
	echo "                        ~/.mylogin.cnf file. Example usage:"
	echo "                        usage is: mysql_config_editor set \\"
	echo "                        --login-path=client --host=localhost \\"
    echo "                        --user=<mysql-username> --password"
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

# Function to round timer value 
round() {
    echo $(printf %.$2f $(echo "scale=$2;(((10^$2)*$1)+0.5)/(10^$2)" | bc))
};

# get real path to project's tables directory
tblsdir=$(readlink -f $(dirname $(readlink -f $0))/../tables)

# Delete existing npy files; csv files will be overwritten
if [ -d $tblsdir ]; then
    rm $tblsdir/*.npy &>/dev/null;
else 
    echo -e "\n'tables' directory doesn't exist. Creating it"
    mkdir -p $tblsdir;
fi

# Use -N to suppress column headers
allargs="${userargs} -Ne"

# Timestamp this run and start
echo -e "\n$(date)"

start=$(date +%s.%N)
echo -e "\nExtracting reference tables from wikipedia DB's \`linkpage\` table" 
echo       ----------------------------------------------------------------

#echo rt104K.csv
#$(mysql -Ne "select * from linkpage where length(title) < 61 limit 106496" > \
#	$tblsdir/rt104K.csv wikipedia)
#if [[ $? != 0 ]]; then error_exit; fi

echo rt208K.csv
$(mysql -Ne "select * from linkpage where length(title) < 61 limit 212992" > \
	$tblsdir/rt208K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt416K.csv
$(mysql -Ne "select * from linkpage where length(title) < 61 limit 425984" > \
	$tblsdir/rt416K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt832K.csv
$(mysql -Ne "select * from linkpage where length(title) < 61 limit 851968" > \
	$tblsdir/rt832K.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt2M.csv
$(mysql -Ne "select * from linkpage where length(title) < 61 limit 1703936" > \
	$tblsdir/rt2M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt3M.csv
$(mysql -Ne "select * from linkpage where length(title) < 61 limit 3407872" > \
	$tblsdir/rt3M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt7M.csv
$(mysql -Ne "select * from linkpage where length(title) < 61 limit 6815744" > \
	$tblsdir/rt7M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt10M.csv
$(mysql -Ne "select * from linkpage where length(title) < 61 limit 10223616" > \
	$tblsdir/rt10M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt13M.csv
$(mysql -Ne "select * from linkpage where length(title) < 61 limit 13631488" > \
	$tblsdir/rt13M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt16M.csv
$(mysql -Ne "select * from linkpage where length(title) < 61 limit 17039360" > \
	$tblsdir/rt16M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

echo rt20M.csv
$(mysql -Ne "select * from linkpage where length(title) < 61 limit 20447232" > \
	$tblsdir/rt20M.csv wikipedia)
if [[ $? != 0 ]]; then error_exit; fi

# Rather than use a mysql query to do so, create LPTs by setting page-id values
# in corresponding RTs to 0

echo -e "\nCreating linkpage table (LPT) files"
echo -----------------------------------
#echo lpt104K.csv
#awk '{print $1=0"\t"$2}' $tblsdir/rt104K.csv > $tblsdir/lpt104K.csv
echo lpt208K.csv
awk '{print $1=0"\t"$2}' $tblsdir/rt208K.csv > $tblsdir/lpt208K.csv
echo lpt416K.csv
awk '{print $1=0"\t"$2}' $tblsdir/rt416K.csv > $tblsdir/lpt416K.csv
echo lpt832K.csv
awk '{print $1=0"\t"$2}' $tblsdir/rt832K.csv > $tblsdir/lpt832K.csv
echo lpt2M.csv
awk '{print $1=0"\t"$2}' $tblsdir/rt2M.csv > $tblsdir/lpt2M.csv
echo lpt3M.csv
awk '{print $1=0"\t"$2}' $tblsdir/rt3M.csv > $tblsdir/lpt3M.csv
echo lpt7M.csv
awk '{print $1=0"\t"$2}' $tblsdir/rt7M.csv > $tblsdir/lpt7M.csv
echo lpt10M.csv
awk '{print $1=0"\t"$2}' $tblsdir/rt10M.csv > $tblsdir/lpt10M.csv
echo lpt13M.csv
awk '{print $1=0"\t"$2}' $tblsdir/rt13M.csv > $tblsdir/lpt13M.csv
echo lpt16M.csv
awk '{print $1=0"\t"$2}' $tblsdir/rt16M.csv > $tblsdir/lpt16M.csv
echo lpt20M.csv
awk '{print $1=0"\t"$2}' $tblsdir/rt20M.csv > $tblsdir/lpt20M.csv

echo
echo -e "\nCreating page table (PT) files" 
echo ------------------------------
#echo pt104K.csv
#uniq $tblsdir/rt104K.csv > $tblsdir/pt104K.csv
echo pt208K.csv
uniq $tblsdir/rt208K.csv > $tblsdir/pt208K.csv
echo pt416K.csv
uniq $tblsdir/rt416K.csv > $tblsdir/pt416K.csv
echo pt832K.csv
uniq $tblsdir/rt832K.csv > $tblsdir/pt832K.csv
echo pt2M.csv
uniq $tblsdir/rt2M.csv > $tblsdir/pt2M.csv
echo pt3M.csv
uniq $tblsdir/rt3M.csv > $tblsdir/pt3M.csv
echo pt7M.csv
uniq $tblsdir/rt7M.csv > $tblsdir/pt7M.csv
echo pt10M.csv
uniq $tblsdir/rt10M.csv > $tblsdir/pt10M.csv
echo pt13M.csv
uniq $tblsdir/rt13M.csv > $tblsdir/pt13M.csv
echo pt16M.csv
uniq $tblsdir/rt16M.csv > $tblsdir/pt16M.csv
echo pt20M.csv
uniq $tblsdir/rt20M.csv > $tblsdir/pt20M.csv

# Call extendpt.py to add null rows to PTs if needed
echo -e "\nExtending PTs to lengths divisible by 16 (saves time in gpujoin.py)"
echo       -------------------------------------------------------------------
extendpt

echo -e "\nTime: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"
