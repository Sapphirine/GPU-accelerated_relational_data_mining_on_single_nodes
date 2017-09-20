/******************************************************************************
 * This script creates the MySQL wikipedia database and its two tables, `page`
 * and `linkpage`. The tables are 2-column relations with the tuple (id, title)
 * as headers. MySQL's LOAD DATA INFILE command is then used to load the tables
 * from csv files created from Wikipedia's sql dumps with the bin/sql2txt
 * utility. (See README.md for details on preprocessing steps taken to obtain
 * the csv files.) Finally, the script joins `linkpage` with `page` to
 * obtain the former's id
 * column data.
 *
 * Input: page.csv and pagelinks-01.csv
 *  The CSV files that contain wikipedia's page table and the '01' subset of
 *  the pagelinks table. The location of these files is hardcoded in the LOAD
 *  DATA INFILE command to be the server's secure-files directory. The mysql
 *  server used in this project was compliled from source, and the server's
 *  secure directory (on localhost) was specified at compile-time. (The
 *  pathnames used below are relative the server's data directory.) To run this
 *  script on a different configuration, the two LOAD DATA INFILE statements
 *  will need to be edited to include the correct pathnames to these files. If
 *  the server is running remotely and configured (along with the client) to
 *  accept client-local files, the 'LOCAL' keyword will need to be added to the
 *  LOAD DATA INFILE commands, as well as the files' pathnames on the client
 *  machine. 
 *
 * Output:
 *  The file samples/createdb.output.sql contains an example output of this
 *  script
 *
 * To run the script, any of the following will work.
 *  1. Run from shell 
 *      $ mysql [options] < createdb.sql
 *  2. Use the included timeit utility to time the execution
 *      $ timeit mysql [options] < createdb.sql
 *  2. Source inside the mysql client (or mysql workbench)
 *      mysql> source createdb.sql
 *  3. copy and paste entire content at the client's prompt. (This option is
 *     the best one for seeing formatted output messages from the server.)
 *
 * Rashad Barghouti
 * rb3074@columbia.edu
 * E6893, Fall 2016
 *****************************************************************************/
SYSTEM date

/* Server was compiled with default CHARSET = BINARY. Check CHARSETS */
-- SHOW VARIABLES LIKE 'character%';

DROP DATABASE IF EXISTS wikipedia;
CREATE DATABASE wikipedia;
USE wikipedia

/* Create and load page table */
DROP TABLE IF EXISTS page;
CREATE TABLE page (
 id INT(8) UNSIGNED NOT NULL AUTO_INCREMENT,
 namespace INT(10) NOT NULL DEFAULT '0',
 title VARBINARY(255) NOT NULL DEFAULT '',
 PRIMARY KEY (id))
ENGINE = MyISAM DEFAULT CHARSET = BINARY;

/* Load the first three columns only -- id, ns, and title */
LOAD DATA INFILE '../files/page.csv' INTO TABLE page (id, namespace, title);

/* Remove pages not in namespace 0 */ 
DELETE FROM page WHERE namespace != 0;
ALTER TABLE page DROP COLUMN namespace;

/* Create and load linkpage table, setting id values to 0 */
DROP TABLE IF EXISTS linkpage;
CREATE TABLE linkpage (
 id INT(8) UNSIGNED NOT NULL DEFAULT 0,
 title VARBINARY(255) NOT NULL DEFAULT '')
ENGINE = MyISAM DEFAULT CHARSET = BINARY;

/* Load only the third column in the csv file -- title column */
LOAD DATA INFILE '../files/pagelinks-01.csv'
INTO TABLE linkpage (@dummy, @dummy, title, @dummy);

/* Clean table: remove single-letter and non-alphanumeric titles */
DELETE FROM linkpage
WHERE title NOT REGEXP BINARY '^\'[0-9]{4,}|^\'[a-zA-Z]{2,}';

/* JOIN linkpage and page tables to populate the id column in linkpage.
 *
 * (Create index on page.title to avoid running forever.)
*/ 
CREATE INDEX title ON page (title);
UPDATE linkpage, page
SET linkpage.id = page.id
WHERE linkpage.title = page.title;

/* Remove bad IDs */
DELETE FROM linkpage WHERE id < 10;

/* Display tables and their sizes (including indexes)
 *
 * Note: If running inside mysql client, uncomment these lines to obtain the
 * statistics they put out. If running from the system shell, keep the lines
 * commented out, because their output on stdout will display unformatted.
*/
-- SHOW TABLES;
-- DESCRIBE page;
-- DESCRIBE linkpage;
-- SELECT COUNT(*) AS `numrows in page` FROM page;
-- SELECT COUNT(*) AS `numRows in linkpage` FROM linkpage;
-- 
-- SELECT table_name as `Page Table`,
-- ROUND(data_length/1024/1024, 2) `Data length (MiB)`,
-- ROUND(index_length/1024/1024, 2) `Index length (MiB)`
-- FROM information_schema.TABLES
-- WHERE table_schema = "wikipedia" and table_name = "page";
-- 
-- SELECT table_name as `Linkpage Table`,
-- ROUND(data_length/1024/1024, 2) `Data length (MiB)`,
-- ROUND(index_length/1024/1024, 2) `Index length (MiB)`
-- FROM information_schema.TABLES
-- WHERE table_schema = "wikipedia" and table_name = "linkpage";


