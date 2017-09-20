#!/bin/bash
#
# See mysql-join.sh for version of the implemenation MySQL table JOINs.
#
# ** This is the first version of mysql-join.sh. It's a crude implemenation
#    that performs all MySQL table joins sequentially, without any looping or
#    indirection.
#
# Rashad Barghouti
# rb3074@columbia.edu
# E6893, Fall 2016
#------------------------------------------------------------------------------

prog=$(basename $0)

#------------------------------------------------------------------------------
# Parse command line
#------------------------------------------------------------------------------
display_usage() {
    echo -e "usage: $prog [-h] [-d path] [-o options]\n"
    echo -e "Do table JOINs in MySQL on all table pairs.\n"
    echo Optional arguments:
    echo "  -h, --help            show this help message and exit"
    echo "  -d, --directory path  path to tables' csv files (default: "
    echo "                        proj-root-dir/tables)"
    echo "  -o, --options string  quoted string of mysql options. Password"
    echo "                        options, -p & --password, are not accepted."
    echo "                        See MySQL documentation about setting up"
    echo "                        encrypted user credentials via a"
    echo "                        ~/.mylogin.cnf file"
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
if [[ $userargs =~ .*\-p.* ]]; then
    echo "mysql userargs: $userargs"
    echo -n "$prog: Error: mysql password option is not supported. "
    echo "See usage."
    exit 0
fi

# If tblsdir has been specified, get its absolute path. Else, set it default
if [ -n "$tblsdir" ]; then
    tblsdir=$(readlink -f $tblsdir)
else
    tblsdir=$(readlink -f $(dirname $(readlink -f $0))/../tables)
fi

# Exit if tblsdir does not exist
[ ! -d $tblsdir ] && echo "$prog: Error: $tblsdir does not exist" && exit 1

#------------------------------------------------------------------------------
# Begin JOIN ops.
#
# Do JOINs with pt320K
#------------------------------------------------------------------------------
date
allargs="${userargs} -e"
exit_msg() {
    echo -e "\n$prog: Error: mysql command, with args \"${allargs}\", failed."
    exit 1
};

# Function for rounding timer values
round()
{
echo $(printf %.$2f $(echo "scale=$2;(((10^$2)*$1)+0.5)/(10^$2)" | bc))
};

# Note: the dummy variable assignment in the statements below is used to
# absorb mysql's stdout dumps (in edge error cases) while still capturing
# return code in $?

# Create pt320K and load it
echo -e "\nCreating page table pt320K"
echo -n -e "Reading pt320K.csv\t" 
start=$(date +%s.%N)

dummy=$(mysql $userargs -e "DROP TABLE IF EXISTS pt320K; \
CREATE TABLE pt320K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '', \
 INDEX (title)) \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/pt320K.csv' INTO TABLE pt320K" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

#-----------------------------------+
# lpt1K-pt320K JOIN                 +
#-----------------------------------+
echo -e "\nlpt1K-pt320K JOIN"
L=$(printf "%-22s" "\u2014")
echo -e "${L// /'\u2014'}"

# Load linkpage table lpt1K 
echo -e "Creating linkpage table lpt1K"
echo -n -e "Reading lpt1K.csv\t"
start=$(date +%s.%N)

dummy=$(mysql $userargs -e "DROP TABLE IF EXISTS lpt1K; \
CREATE TABLE lpt1K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt1K.csv' INTO TABLE lpt1K" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt1K, pt320K \
SET lpt1K.id = pt320K.id \
WHERE lpt1K.title = pt320K.title" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# Drop lpt1K
$(mysql $userargs -e "DROP TABLE lpt1K" wikipedia)
if [[ $? != 0 ]]; then exit_msg; fi

#-----------------------------------+
# lpt5K-pt320K JOIN                 +
#-----------------------------------+
echo -e "\nlpt5K-pt320K JOIN"
echo -e "${L// /'\u2014'}"

# Load linkpage table (lpt5K) 
echo -e "Creating linkpage table lpt5K"
echo -n -e "Reading lpt5K.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS lpt5K; \
CREATE TABLE lpt5K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt5K.csv' INTO TABLE lpt5K" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt5K, pt320K \
SET lpt5K.id = pt320K.id \
WHERE lpt5K.title = pt320K.title" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

$(mysql $userargs -e "DROP TABLE lpt5K" wikipedia)
if [[ $? != 0 ]]; then exit_msg; fi

#-----------------------------------+
# lpt10K-pt320K JOIN                +
#-----------------------------------+
echo -e "\nlpt10K-pt320K JOIN"
L=$(printf "%-23s" "\u2014")
echo -e "${L// /'\u2014'}"

# Load linkpage table (lpt10K) 
echo -e "Creating linkpage table lpt10K"
echo -n -e "Reading lpt10K.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS lpt10K; \
CREATE TABLE lpt10K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt10K.csv' INTO TABLE lpt10K" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt10K, pt320K \
SET lpt10K.id = pt320K.id \
WHERE lpt10K.title = pt320K.title" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

$(mysql $userargs -e "DROP TABLE lpt10K" wikipedia)
if [[ $? != 0 ]]; then exit_msg; fi

#-----------------------------------+
# lpt20K-pt320K JOIN                +
#-----------------------------------+
echo -e "\nlpt20K-pt320K JOIN"
echo -e "${L// /'\u2014'}"

# Load linkpage table (lpt20K) 
echo -e "Creating linkpage table lpt20K"
echo -n -e "Reading lpt20K.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS lpt20K; \
CREATE TABLE lpt20K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt20K.csv' INTO TABLE lpt20K" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt20K, pt320K \
SET lpt20K.id = pt320K.id \
WHERE lpt20K.title = pt320K.title" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

$(mysql $userargs -e "DROP TABLE lpt20K" wikipedia)
if [[ $? != 0 ]]; then exit_msg; fi

#-----------------------------------+
# lpt40K-pt320K JOIN                +
#-----------------------------------+
echo -e "\nlpt40K-pt320K JOIN"
echo -e "${L// /'\u2014'}"

# Load linkpage table (lpt40K) 
echo -e "Creating linkpage table lpt40K"
echo -n -e "Reading lpt40K.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS lpt40K; \
CREATE TABLE lpt40K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt40K.csv' INTO TABLE lpt40K" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt40K, pt320K \
SET lpt40K.id = pt320K.id \
WHERE lpt40K.title = pt320K.title" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

$(mysql $userargs -e "DROP TABLE lpt40K" wikipedia)
if [[ $? != 0 ]]; then exit_msg; fi

#-----------------------------------+
# lpt80K-pt320K JOIN                +
#-----------------------------------+
echo -e "\nlpt80K-pt320K JOIN"
echo -e "${L// /'\u2014'}"

# Load linkpage table (lpt80K) 
echo -e "Creating linkpage table lpt80K"
echo -n -e "Reading lpt80K.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS lpt80K; \
CREATE TABLE lpt80K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt80K.csv' INTO TABLE lpt80K" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt80K, pt320K \
SET lpt80K.id = pt320K.id \
WHERE lpt80K.title = pt320K.title" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

$(mysql $userargs -e "DROP TABLE lpt80K" wikipedia)
if [[ $? != 0 ]]; then exit_msg; fi

#-----------------------------------+
# lpt160K-pt320K JOIN               +
#-----------------------------------+
echo -e "\nlpt160K-pt320K JOIN"
L=$(printf "%-24s" "\u2014")
echo -e "${L// /'\u2014'}"

# Load linkpage table (lpt160K) 
echo -e "Creating linkpage table lpt160K"
echo -n -e "Reading lpt160K.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS lpt160K; \
CREATE TABLE lpt160K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt160K.csv' INTO TABLE lpt160K" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt160K, pt320K \
SET lpt160K.id = pt320K.id \
WHERE lpt160K.title = pt320K.title" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

$(mysql $userargs -e "DROP TABLE lpt160K" wikipedia)
if [[ $? != 0 ]]; then exit_msg; fi

#-----------------------------------+
# lpt320K-pt320K JOIN               +
#-----------------------------------+
echo -e "\nlpt320K-pt320K JOIN"
echo -e "${L// /'\u2014'}"

# Load linkpage table (lpt320K) 
echo -e "Creating linkpage table lpt320K"
echo -n -e "Reading lpt320K.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS lpt320K; \
CREATE TABLE lpt320K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt320K.csv' INTO TABLE lpt320K" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt320K, pt320K \
SET lpt320K.id = pt320K.id \
WHERE lpt320K.title = pt320K.title" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

$(mysql $userargs -e "DROP TABLE lpt320K" wikipedia)
if [[ $? != 0 ]]; then exit_msg; fi
$(mysql $userargs -e "DROP TABLE pt320K" wikipedia)
if [[ $? != 0 ]]; then exit_msg; fi

#------------------------------------------------------------------------------
# Do the JOINs with pt1280K
#------------------------------------------------------------------------------

# Create pt1280K and load it
echo -e "\n******"
echo -e "Creating page table pt1280K"
echo -n -e "Reading pt1280K.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS pt1280K; \
CREATE TABLE pt1280K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '', \
 INDEX (title)) \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/pt1280K.csv' INTO TABLE pt1280K" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi

echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

#-----------------------------------+
# lpt640K-pt1280K JOIN              +
#-----------------------------------+
echo -e "\nlpt640K-pt1280K JOIN"
L=$(printf "%-25s" "\u2014")
echo -e "${L// /'\u2014'}"

# Load linkpage table (lpt640K) 
echo -e "Creating linkpage table lpt640K"
echo -n -e "Reading lpt640K.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS lpt640K; \
CREATE TABLE lpt640K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt640K.csv' INTO TABLE lpt640K" wikipedia)

if [[ $? != 0 ]]; then exit_msg; fi
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt640K, pt1280K \
SET lpt640K.id = pt1280K.id \
WHERE lpt640K.title = pt1280K.title" wikipedia)
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

$(mysql $userargs -e "DROP TABLE lpt640K" wikipedia)

#-----------------------------------+
# lpt1280K-pt1280K JOIN             +
#-----------------------------------+
echo -e "\nlpt1280K-pt1280K JOIN"
L=$(printf "%-26s" "\u2014")
echo -e "${L// /'\u2014'}"

# Load linkpage table (lpt1280K) 
echo -e "Creating linkpage table lpt1280K"
echo -n -e "Reading lpt1280K.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS lpt1280K; \
CREATE TABLE lpt1280K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt1280K.csv' INTO TABLE lpt1280K" wikipedia)
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt1280K, pt1280K \
SET lpt1280K.id = pt1280K.id \
WHERE lpt1280K.title = pt1280K.title" wikipedia)
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

$(mysql $userargs -e "DROP TABLE lpt1280K" wikipedia)
$(mysql $userargs -e "DROP TABLE pt1280K" wikipedia)

#------------------------------------------------------------------------------
# Do remaining JOINs with page tables pt2560K, pt5M, and pt10M
#------------------------------------------------------------------------------

#-----------------------------------+
# lpt2560K-pt2560K JOIN             +
#-----------------------------------+

# Create pt2560K and load it
echo -e "\n******" 
echo -e "Creating page table pt2560K"
echo -n -e "Reading pt2560K.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS pt2560K; \
CREATE TABLE pt2560K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '', \
 INDEX (title)) \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/pt2560K.csv' INTO TABLE pt2560K" wikipedia)

echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# Load linkpage table (lpt2560K) 
echo -e "\nlpt2560K-pt2560K JOIN"
echo -e "${L// /'\u2014'}"
echo -e "Creating linkpage table lpt2560K"
echo -n -e "Reading lpt2560K.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS lpt2560K; \
CREATE TABLE lpt2560K ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt2560K.csv' INTO TABLE lpt2560K" wikipedia)
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt2560K, pt2560K \
SET lpt2560K.id = pt2560K.id \
WHERE lpt2560K.title = pt2560K.title" wikipedia)
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

$(mysql $userargs -e "DROP TABLE lpt2560K" wikipedia)
$(mysql $userargs -e "DROP TABLE pt2560K" wikipedia)

#-----------------------------------+
# lpt5M-pt5M JOIN                   +
#-----------------------------------+

# Create pt5M and load it
echo -e "\n******"
echo -e "Creating page table pt5M"
echo -n -e "Reading pt5M.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS pt5M; \
CREATE TABLE pt5M ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '', \
 INDEX (title)) \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/pt5M.csv' INTO TABLE pt5M" wikipedia)

echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# Load linkpage table (lpt5M) 
echo -e "\nlpt5M-pt5M JOIN"
L=$(printf "%-20s" "\u2014")
echo -e "${L// /'\u2014'}"
echo -e "Creating linkpage table lpt5M"
echo -n -e "Reading lpt5M.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS lpt5M; \
CREATE TABLE lpt5M ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt5M.csv' INTO TABLE lpt5M" wikipedia)
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt5M, pt5M \
SET lpt5M.id = pt5M.id \
WHERE lpt5M.title = pt5M.title" wikipedia)
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

$(mysql $userargs -e "DROP TABLE lpt5M" wikipedia)
$(mysql $userargs -e "DROP TABLE pt5M" wikipedia)

#-----------------------------------+
# lpt10M-pt10M JOIN                 +
#-----------------------------------+

# Create pt10M and load it
echo -e "\n******"
echo -e "Creating page table pt10M"
echo -n -e "Reading pt10M.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS pt10M; \
CREATE TABLE pt10M ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '', \
 INDEX (title)) \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/pt10M.csv' INTO TABLE pt10M" wikipedia)

echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# Load linkpage table (lpt10M) 
echo -e "\nlpt10M-pt10M JOIN"
L=$(printf "%-22s" "\u2014")
echo -e "${L// /'\u2014'}"
echo -e "Creating linkpage table lpt10M"
echo -n -e "Reading lpt10M.csv\t" 
start=$(date +%s.%N)

$(mysql $userargs -e "DROP TABLE IF EXISTS lpt10M; \
CREATE TABLE lpt10M ( \
 id INT(8) UNSIGNED NOT NULL DEFAULT 0, \
 title VARBINARY(60) NOT NULL DEFAULT '') \
ENGINE = MyISAM DEFAULT CHARSET = BINARY; \
LOAD DATA INFILE '${tblsdir}/lpt10M.csv' INTO TABLE lpt10M" wikipedia)
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

# JOIN
echo -n -e "Table JOIN\t\t" 
start=$(date +%s.%N)
$(mysql $userargs -e "UPDATE lpt10M, pt10M \
SET lpt10M.id = pt10M.id \
WHERE lpt10M.title = pt10M.title" wikipedia)
echo "time: $(round $(echo "$(date +%s.%N) - $start" | bc) 2) sec"

$(mysql $userargs -e "DROP TABLE lpt10M" wikipedia)
$(mysql $userargs -e "DROP TABLE pt10M" wikipedia)

echo -e "\nSQL table JOINs done!"
