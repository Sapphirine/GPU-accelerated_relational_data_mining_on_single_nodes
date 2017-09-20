#!/usr/bin/env bash
#
# This script performs SQL table joins that mimic the GPU processing of the
# same operations. For each join, two mysql tables are created and loaded from
# correpsonding CSV files. They are then joined together to populate the FROM
# table's ID column. Unlike the gpujoin program, selection of a specific pair
# of tables to join is not possible; all table pairs are joined. 
# Execution times are recorded and written to a file named sqljoin.tms or
# sqljoin-${ptname}.tms in the output directory, depending on whether the joins
# were performed with a single page table ($ptname). 
#
# For usage info, use option -h or --help at the command line.
#
# NOTE: This script uses the bash-shell here_document feature, which requires
# hard tabs in the text. If it is edited in an editor that expands tabs
# to spaces automatically, it will not execute correctly, if at all. The two
# here_document sections must be re-tabbed at that point. If this becomes too
# complex, the script sqljoin-v1.0.sh, in the sav directory, can be used
# instead. 
#
# Input:
#  wikipedia database and its two tables, 'page' and 'linkpage'. If the
#  database does not exist, it can be created, along with the needed tables,
#  using the createdb.sql program.
#
# See README.md for important usage notes
#
# Rashad Barghouti
# rb3074@columbia.edu
# E6893, Fall 2016
#------------------------------------------------------------------------------

prog=$(basename $(readlink $0))

# Function to display error message and terminate script
error_exit() {
    echo -e "\n$prog: Error: mysql command terminated with error"
    echo -e "error log: $errlog"
    exit 1
};

# Function to round timer value 
round() {
    echo $(printf %.$2f $(echo "scale=$2;(((10^$2)*$1)+0.5)/(10^$2)" | bc))
};

# Function to display program command-line usage information
display_usage() {
    echo "usage: $prog [-h | --help] [-p PTNAME] [-d TBLSDIR] [-o MySQLOPTS]"
	echo
    echo -en "JOIN all table pairs in MySQL and send output to stdout and "
    echo -e "output file.\n"
    echo Optional arguments:
    echo "  -h, --help    show this help message and exit"
    echo "  -p PTNAME     use same PT for all joins. PTNAME should be the PT" 
    echo "                filename's prefix, e.g., pt208K, pt7M, ..."
    echo "  -d TBLSDIR    pathname of directory containing the tables' CSV"
	echo "                files (default: 'tables' directory in project tree)"
    echo "  -o MySQLOPTS  quoted string of command-line options to be passed"
	echo "                to the mysql server. (The password options -p and"
	echo "                --password are not passed along, and the script will"
	echo "                terminate if either is part of the string. The" 
	echo "                utility program, mysql_config_editor, can be used to"
	echo "                establish login credentials via an encrypted "
	echo "                ~/.mylogin.cnf. See MySQL documentation for "
	echo "                setup instructions."
    exit 0
};

# Define the arrays of all the LPT and PT tables that will be joined
#
lptbls=(lpt208K lpt416K lpt832K lpt2M lpt3M lpt7M lpt10M lpt13M lpt16M)
ptbls=(pt208K pt416K pt832K pt2M pt3M pt7M pt10M pt13M pt16M)

# Parse command-line
#
tblsdir=
userargs=
ptname=
while [[ $# -gt 0 ]]
do
    case $1 in
        -h|--help)
            display_usage
            ;;
        -d)
            tblsdir="$2"
            shift
            ;;
        -p)
            ptname="$2"
			shift
            ;;
        -o)
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

# MySQL's password argument is a headache; check for it and exit if found
if [[ $userargs =~ .*\-p.* ]]; then
    echo "mysql userargs: $userargs"
    echo -n "$prog: Error: mysql password option is not supported. See usage."
    exit 0
fi

# If tblsdir has been specified, get its absolute path. Else, set it default
if [[ -n $tblsdir ]]; then
    tblsdir=$(readlink -f $tblsdir)
else
    tblsdir=$(readlink -f $(dirname $(readlink -f $0))/../tables)
fi
# Exit if tblsdir does not exist
[ ! -d $tblsdir ] && echo "$prog: Error: $tblsdir does not exist" && exit 1

# If a PT has been specified with -p | --pgtbl, make sure it is a valid one
if [[ -n $ptname ]]; then
	pt=
	for tblname in ${ptbls[@]}; do
		if [[ $tblname == $ptname ]]; then
			pt=$ptname
			break
		fi
	done
	if [[ -z $pt ]]; then
		echo "$prog: Error: unknown PT ($ptname)"
		exit 1
	fi
fi

# Initialize path to output directory; create it if needed 
outdir=$(readlink -f $(dirname $(readlink -f $0))/../output)
[ ! -d $outdir ] && mkdir -p $outdir

# Enable safe-updates in case server was not compiled with that flag
allargs="--silent ${userargs} -e"
now=$(date)
echo -e "\n$now"

# Create output files
prog_prefix=${prog%.sh}
if [[ -n $ptname ]]; then
	prog_prefix=${prog_prefix}-${ptname}
fi
errlog="${outdir}/${prog_prefix}.err.log"
echo "*** ${prog}: $now ***" > $errlog
outfile="${outdir}/${prog_prefix}.output"
echo "*** ${prog}: $now ***" > $outfile

tmsfile="${outdir}/${prog_prefix}.tms"

# Array to hold execution times
#declare -a sqltms

# Loop over all linkpage tables and perform the joins * 
#
for index in ${!lptbls[@]}; do

	# Set the LPT and PT for this join
    lpt=${lptbls[index]}
	if [[ -z $ptname ]]; then
    	pt=${ptbls[index]}
	fi

    # Print out start header for this set
    hdrstr=$(printf "${lpt}-${pt} JOIN")
    hdrlen=${#hdrstr}
    echo -e "\n${hdrstr}" | tee -a $outfile
    printf -v line "%*s" ${hdrlen}
    echo -e "${line// /'\u2014'}" | tee -a $outfile

	# mysql CREATE TABLE command string for PT
	read -d '' CREATE_TABLE <<-EOF
		DROP TABLE IF EXISTS ${pt};
		CREATE TABLE ${pt} (
			id INT(8) UNSIGNED NOT NULL DEFAULT 0,
			title VARBINARY(60) NOT NULL DEFAULT '',
			INDEX (title))
		ENGINE = MyISAM DEFAULT CHARSET = BINARY;
	EOF

	# LOAD DATA INFILE string
	read -d '' LOAD_TABLE <<-EOF
		LOAD DATA LOCAL INFILE '${tblsdir}/${pt}.csv' INTO TABLE ${pt};
		SELECT ROW_COUNT()
	EOF

	# Create and load PT from csv file.
	#
	# If using a single PT for all joins, create and load it once only
	if [[ -n $ptname ]]; then

		if [[ $index == '0' ]]; then

			echo -e "Creating mysql table ${pt}"  | tee -a $outfile
			mysql $allargs "$CREATE_TABLE" wikipedia 2>>$errlog
			if [[ $? != 0 ]]; then error_exit; fi

			echo -n -e "Loading table from ${pt}.csv\t"  | tee -a $outfile
			start=$(date +%s.%N)
			nrows=$(mysql $allargs "$LOAD_TABLE" wikipedia) 2>>$errlog
			if [[ $? != 0 ]]; then error_exit; fi
			s="time: $(round $(echo "$(date +%s.%N) - $start" | bc) 4) sec"
			echo "$s, $nrows rows read" | tee -a $outfile;
		fi

	else

		echo -e "Creating mysql table ${pt}"  | tee -a $outfile
		mysql $allargs "$CREATE_TABLE" wikipedia 2>>$errlog
		if [[ $? != 0 ]]; then error_exit; fi

		echo -n -e "Loading table from ${pt}.csv\t"  | tee -a $outfile
		start=$(date +%s.%N)

		nrows=$(mysql $allargs "$LOAD_TABLE" wikipedia) 2>>$errlog
		if [[ $? != 0 ]]; then error_exit; fi

		s="time: $(round $(echo "$(date +%s.%N) - $start" | bc) 4) sec"
		echo "$s, $nrows rows read" | tee -a $outfile;
	fi

    # CREATE TABLE command string
	read -d '' CREATE_TABLE <<-EOF
		DROP TABLE IF EXISTS ${lpt};
		CREATE TABLE ${lpt} (
			id INT(8) UNSIGNED NOT NULL DEFAULT 0,
			title VARBINARY(60) NOT NULL DEFAULT '')
		ENGINE = MyISAM DEFAULT CHARSET = BINARY;
	EOF

    # LOAD DATA INFILE string
	read -d '' LOAD_TABLE <<-EOF
		LOAD DATA LOCAL INFILE '${tblsdir}/${lpt}.csv' INTO TABLE ${lpt};
		SELECT ROW_COUNT()
	EOF

    # Create lpt
    echo -e "Creating mysql table ${lpt}" | tee -a $outfile
	mysql $allargs "$CREATE_TABLE" wikipedia 2>>$errlog
	if [[ $? != 0 ]]; then error_exit; fi

    echo -n -e "Loading table from ${lpt}.csv\t" | tee -a $outfile
    start=$(date +%s.%N)

    # Load it 
	nrows=$(mysql $allargs "$LOAD_TABLE" wikipedia) 2>>$errlog
	if [[ $? != 0 ]]; then error_exit; fi

    # Display load time
    s="time: $(round $(echo "$(date +%s.%N) - $start" | bc) 4) sec"
    echo "$s, $nrows rows read" | tee -a $outfile

    # TABLE JOIN string 
	read -d '' UPDATE_TABLE <<-EOF
		UPDATE ${lpt}, ${pt}
    	SET ${lpt}.id = ${pt}.id
    	WHERE ${lpt}.title = ${pt}.title; 
	EOF

    echo -n -e "Performing table join\t\t" | tee -a $outfile 
    start=$(date +%s.%N)

    # JOIN tables 
    mysql $allargs "$UPDATE_TABLE" wikipedia 2>>$errlog
    if [[ $? != 0 ]]; then error_exit; fi

    # Record JOIN time
    sqltms[index]=$(round $(echo "$(date +%s.%N) - $start" | bc) 4)
    echo "time: ${sqltms[$index]} sec" | tee -a $outfile

    # Drop LPT
    $(mysql $allargs "DROP TABLE ${lpt}" wikipedia)
    if [[ $? != 0 ]]; then error_exit; fi

    # Drop PT
	if [[ -z $ptname ]]; then
		$(mysql $allargs "DROP TABLE ${pt}" wikipedia)
		if [[ $? != 0 ]]; then error_exit; fi
	fi

	# If using one PT, don't continue if LPT is of larger size
	if [[ ${ptbls[index]} == ${ptname} ]]; then
		#echo -e "Stopping at ${lptbls[index]}"
		break
	fi
done

# If one common PT was used, drop it here
if [[ -n $ptname ]]; then
	$(mysql $allargs "DROP TABLE ${pt}" wikipedia)
	if [[ $? != 0 ]]; then error_exit; fi
fi

# If we're here, then processing concluded with no errors; delete errlog
#rm -f $errlog
# If errlog contains no data, delete it
if [[ $(wc -l $errlog | awk '{print $1}') == '1' ]]; then
	#echo Deleting errlog file $errlog
	rm -f $errlog
fi

echo -e "\nSQL table JOINs done!" | tee -a $outfile

#******************************************************************
# Done processing table joins. Write processing times to $tmsfile *
#******************************************************************
printf -v line1 "%78s"
echo -e "#${line1// /'-'}" > $tmsfile
echo "# MySQL JOIN Times" >> $tmsfile
printf -v line2 "%16s"
echo -e "# ${line2// /'\u2014'}" >> $tmsfile
echo -e "# $(date)\n#" >> $tmsfile

# Display JOIN table pairs
if [[ -n ${ptname} ]]; then
	echo -en "# One page table, ${ptname}, is used for all joins " >> $tmsfile
	echo -en "\n# Lnkpg tbls: " >> $tmsfile
	echo -ne "(${lptbls[@]})\n#" >> $tmsfile
else
	echo -en "# Joined table pairs:\n#  " >> $tmsfile
	for i in ${!lptbls[@]}; do
		if ! (( ${#lptbls[@]} - (i+1) )); then
			echo -ne "\n#  " >> $tmsfile
		else
			echo -n "(${lptbls[i]}, ${ptbls[i]}), " >> $tmsfile
			if ! (( (i + 1) % 3 )); then
				echo -ne "\n#  " >> $tmsfile
			fi
		fi
	done
fi
echo -e "\n# Times in sec\n#${line1// /'-'}" >> $tmsfile

# Write times array as Python list
max_i=${#sqltms[@]}-1
echo -n "[" >> $tmsfile
for i in ${!sqltms[@]}; do
    echo -n "${sqltms[i]}" >> $tmsfile
    if [[ $i -lt $max_i ]]; then 
        echo -n ", " >> $tmsfile
    else
        echo -n "]" >> $tmsfile
    fi
done

echo -e "\nMySQL JOIN times (sec): [${sqltms[@]}]" | tee -a $outfile
echo "List written to $outdir/$(basename $tmsfile)" | tee -a $outfile 

