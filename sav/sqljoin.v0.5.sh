#!/usr/bin/env bash
#
# This script is equivalent in function to the final one, src/sqljoin.sh,
# but differs from it in the use the 'here_document' shell
# feature. This one does not use that feature in the main loop. It can be used
# to perform the MySQL table joins if needed. (The hear_document version
# requires hard tabs and may not work if pre-edited with an editor that expands
# tabs automatically.)
#
# Description:
# This script emulates the GPU JOIN processing by creating mysql tables from
# scratch, loading them from csv files, and performing a SQL JOIN on each pair.
#
# Input:
#  wikipedia database and its two tables, 'page' and 'linkpage'. If it does not
#  exist, the db can be created with creat-db.sql
#
# See README.md for important usage notes
#
# Rashad Barghouti
# rb3074@columbia.edu
# E6893, Fall 2016
#------------------------------------------------------------------------------

prog=$(basename $(readlink $0))

#------------------------------------------------------------------------------
# Parse command line
#------------------------------------------------------------------------------
display_usage() {
    echo -e "usage: $prog [-h] [-d path] [-o options]\n"
    echo -e "Do table JOINs in MySQL on all table pairs.\n"
    echo Optional arguments:
    echo "  -h, --help            show this help message and exit"
    echo "  -d, --directory path  path to tables' csv files (default: "
    echo "                        path/to/project-directory/tables)"
    echo "  -o, --options string  quoted string of mysql cmdline args."
    echo "                        Secure processing of password options (-p" 
	echo "						  and --password) is not implemented. Their"
	echo "						  inclusion in the string will terminate"
	echo "						  execution. For secure processing, the script"
    echo "                        is best run with login credentials stored in"
    echo "                        an encrypted ~/.mylogin.cnf file. See"
    echo "                        MySQL documentation for setup instructions."
    exit 0
};

tblsdir=
userargs=
while [[ $# -gt 0 ]]
do
    case $1 in
        -h|--help)
            display_usage
            ;;
        -d|--dir)
            tblsdir="$2"
            shift
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
#if [[ $userargs =~ .*\-p.* ]]; then
#    echo "mysql userargs: $userargs"
#    echo -n "$prog: Error: mysql password option is not supported. "
#    echo "See usage."
#    exit 0
#fi

# If tblsdir has been specified, get its absolute path. Else, set it default
if [ -n "$tblsdir" ]; then
    tblsdir=$(readlink -f $tblsdir)
else
    tblsdir=$(readlink -f $(dirname $(readlink -f $0))/../tables)
fi
# Exit if tblsdir does not exist
[ ! -d $tblsdir ] && echo "$prog: Error: $tblsdir does not exist" && exit 1

# Init path to logs directory; create it if it doesn't exist already
logsdir=$(readlink -f $(dirname $(readlink -f $0))/../logs)
[ ! -d $logsdir ] && mkdir -p $logsdir

allargs="${userargs} -e"
now=$(date)

#******************************************************************************
# Begin Processing
#******************************************************************************

error_exit() {
    # Display error message and exit
    echo -e "\n$prog: Error: mysql command terminated with error. See error"
    echo -e "log: $errlog"
    exit 1
};
round() {
    # Round input (timer) value
    echo $(printf %.$2f $(echo "scale=$2;(((10^$2)*$1)+0.5)/(10^$2)" | bc))
};

# Create error and output logs
#
errlog="${logsdir}/${prog}.err.log"
echo "*** mysql-join.sh: $now ***" > $errlog
logfile="${logsdir}/${prog}.output"
echo "*** mysql-join.sh: $now ***" > $logfile

# Create mysql-times[] array and initialize JOIN tables lists 
#
declare -a mysqltm

lptbls=(lpt1K lpt5K lpt10K lpt20K lpt40K lpt80K lpt160K
        lpt320K lpt640K lpt1280K lpt2560K lpt5M lpt10M)

ptbls=(pt320K pt320K pt320K pt320K pt320K pt320K pt320K
       pt320K pt1280K pt1280K pt2560K pt5M pt10M)

# Echo timestamp
echo -e "\n$now"

# Loop over all tables
#
for index in ${!lptbls[@]}; do

    if [ $index = '3' ]; then break; fi

    # Set current pair
    lpt=${lptbls[index]}
    pt=${ptbls[index]}

    # Don't create/load the same page table more than once
    case $index in
        0|8|10|11|12)
            echo -e "\n\nCreating page table ${pt}" | tee -a $logfile
            echo -n -e "Loading ${pt}.csv\t"  | tee -a $logfile
            
            start=$(date +%s.%N)

            $(mysql $userargs -e "DROP TABLE IF EXISTS ${pt}; \
            CREATE TABLE ${pt} ( \
             id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
             title VARBINARY(60) NOT NULL DEFAULT '', \
             INDEX (title)) \
            ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
            LOAD DATA INFILE '${tblsdir}/${pt}.csv' \
            INTO TABLE ${pt}" wikipedia 2>>$errlog)

            if [[ $? != 0 ]]; then error_exit; fi
            s="time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"
            echo "$s" | tee -a $logfile
            ;;
    esac

    # Display JOIN header
    hdrstr=$(printf "${lpt}-${pt} JOIN")
    hdrlen=${#hdrstr}
    echo -e "\n${hdrstr}" | tee -a $logfile
    printf -v line "%*s" ${hdrlen}
    echo -e "${line// /'\u2014'}" | tee -a $logfile

    # Load linkpage table lpt1K 
    echo -e "Creating linkpage table ${lpt}" | tee -a $logfile
    echo -n -e "Loading ${lpt}.csv\t" | tee -a $logfile
    start=$(date +%s.%N)

    dummy=$(mysql $userargs -e "DROP TABLE IF EXISTS ${lpt}; \
    CREATE TABLE ${lpt} ( \
     id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
     title VARBINARY(60) NOT NULL DEFAULT '') \
    ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
    LOAD DATA INFILE '${tblsdir}/${lpt}.csv' INTO TABLE ${lpt}" wikipedia)

    if [[ $? != 0 ]]; then error_exit; fi
    s="time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"
    echo "$s" | tee -a $logfile

    # JOIN
    echo -n -e "Table JOIN\t\t" | tee -a $logfile 
    start=$(date +%s.%N)
    $(mysql $userargs -e "UPDATE ${lpt}, ${pt} \
    SET ${lpt}.id = ${pt}.id \
    WHERE ${lpt}.title = ${pt}.title" wikipedia)

    if [[ $? != 0 ]]; then error_exit; fi

    # Record JOIN time
    mysqltm[index]=$(round $(echo "$(date +%s.%N) - $start" | bc) 2)
    echo "time: ${mysqltm[$index]} sec" | tee -a $logfile

    # Drop lpt
    $(mysql $userargs -e "DROP TABLE ${lpt}" wikipedia)
    if [[ $? != 0 ]]; then error_exit; fi

    # Drop pt
    case $index in 7|9|11|12|13)
        $(mysql $userargs -e "DROP TABLE ${pt}" wikipedia)
        ;;
    esac

done

echo -e "\nSQL table JOINs done!" | tee -a $logfile

# Write mysqltm[] to logs/mysql.tms as a python list 
#
mysqltm=(0.02 0.05 0.07 0.13 0.24 0.46 0.91 1.83 3.86 7.65 15.84 31.83 65.13)
f="${logsdir}/mysql.tms"
printf -v line1 "%78s"
echo -e "#${line1// /'-'}" > $f
echo "# MySQL JOIN Times (sec)" >> $f
printf -v line2 "%22s"
echo -e "# ${line2// /'\u2014'}" >> $f
echo -e "# $(date)\n#" >> $f

# Display JOIN table pairs
echo -en "# JOIN'd table pairs:\n#  " >> $f
for i in ${!lptbls[@]}; do
    case $i in
        3|7|11)
            echo -ne "(${lptbls[i]}, ${ptbls[i]}),\n#  " >> $f
            ;;
        12)
            echo -ne "(${lptbls[i]}, ${ptbls[i]})\n" >> $f
            ;;
        *)
            echo -n "(${lptbls[i]}, ${ptbls[i]}), " >> $f
            ;;
    esac
done
echo -e "#${line1// /'-'}" >> $f

# Write times array as Python list
max_i=${#mysqltm[@]}-1
echo -n "[" >> $f
for i in ${!mysqltm[@]}; do
    echo -n "${mysqltm[i]}" >> $f
    if [[ $i -lt $max_i ]]; then 
        echo -n ", " >> $f
    else
        echo -n "]" >> $f
    fi
done

echo "\nMySQL JOIN times (sec): [${mysqltm[@]}]" | tee -a $logfile
echo "Times' list written to $f" | tee -a $logfile 
