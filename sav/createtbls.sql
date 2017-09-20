/******************************************************************************
* This script can be used to generate the table files for the GPU JOIN.
* However, it requires a complicated setup of the mysql server on localhost.
* The shell script create-tbl-files.sh can be used instead to obtain the
* tables.
******************************************************************************/
USE wikipedia

/* Create lpt csv files */
SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 1024
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt1K.csv';

SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 5120
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt5K.csv';

SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 10240
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt10K.csv';

SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 20480
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt20K.csv';

SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 40961
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt40K.csv';

SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 81920
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt80K.csv';

SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 163840
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt160K.csv';

SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 327680
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt320K.csv';

SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 655361
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt640K.csv';

SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 1310720
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt1280K.csv';

SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 2611440
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt2560K.csv';

SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 5242880
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt5M.csv';

SELECT 0 AS id, title FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 10485761
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/lpt10M.csv';

/* Create linkpage-reference table files */
SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 1024
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt1K.csv';

SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 5120
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt5K.csv';

SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 10240
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt10K.csv';

SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 20480
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt20K.csv';

SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 40961
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt40K.csv';

SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 81920
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt80K.csv';

SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 163840
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt160K.csv';

SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 327680
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt320K.csv';

SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 655361
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt640K.csv';

SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 1310720
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt1280K.csv';

SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 2611440
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt2560K.csv';

SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 5242880
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt5M.csv';

SELECT * FROM linkpage
WHERE LENGTH(title) < 61 LIMIT 10485761
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/rt10M.csv';

/* page table files */
SELECT * from page
WHERE title REGEXP BINARY '^\'2014_'
AND LENGTH(title) < 61
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/pt320K.csv';

SELECT * from page
WHERE title REGEXP BINARY '^\'2014'
AND LENGTH(title) < 61
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/pt640K.csv';

SELECT * from page
WHERE title REGEXP BINARY '^\'201[45]'
AND LENGTH(title) < 61
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/pt1280K.csv';

SELECT * from page
WHERE title REGEXP BINARY '^\'([2-9][0-9]{3,}|A[A-R])'
AND LENGTH(title) < 61
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/pt2560K.csv';

SELECT * from page
WHERE title REGEXP BINARY '^\'([2-9][0-9]{3,}|A[A-Za-d])'
AND LENGTH(title) < 61
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/pt5M.csv';

SELECT * from page
WHERE title REGEXP BINARY '^\'([2-9][0-9]{3,}|A[A-Za-l])'
AND LENGTH(title) < 61
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/pt10M.csv';

SELECT * from page
WHERE title REGEXP BINARY '^\'([2-9][0-9]{3,}|A[A-Za-n])'
AND LENGTH(title) < 61
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/pt15M.csv';

SELECT * from page
WHERE title REGEXP BINARY '^\'(201|A[a-n])'
AND LENGTH(title) < 61
INTO OUTFILE '/home/rasbar/coursework/e6893/project/tables/ptall.csv';

