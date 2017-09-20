* The file table.tar.gz contains the table sets for both the GPU and SQL join
  programs. They can all be generated using the processing steps that precede
  the join operation, as described in the projects README.md

* The shell scripts in this programs can be used to generate tables to perform
  joins with a single PT size.
  
  For example: the 'gen-pt832K-sets.sh' script creates LPTs and RTs by
  replicating lpt208K.csv and rt208K.csv, respectively. The PTs are all copies
  of pt208K.csv.

