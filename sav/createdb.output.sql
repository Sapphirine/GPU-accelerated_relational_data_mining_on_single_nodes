/******************************************************************************
 * This file contains the output from a run of the MySQL script createdb.sql.
 * It has been edited slightly to remove 'mysql> ' prompts and make the output
 * messages more discernible. (As shown, the contents can be cut and pasted in
 * a mysql client to produce similar output.)
 *****************************************************************************/

SYSTEM date
-- Wed Dec 28 20:30:36 PST 2016

SHOW VARIABLES LIKE 'character%';
/* +--------------------------+----------------------------------------------+
 * | Variable_name            | Value                                        |
 * +--------------------------+----------------------------------------------+
 * | character_set_client     | utf8                                         |
 * | character_set_connection | utf8                                         |
 * | character_set_database   | binary                                       |
 * | character_set_filesystem | binary                                       |
 * | character_set_results    | utf8                                         |
 * | character_set_server     | binary                                       |
 * | character_set_system     | utf8                                         |
 * | character_sets_dir       | /home/rasbar/opt/mysql/share/mysql/charsets/ |
 * +--------------------------+----------------------------------------------*/
-- 8 rows in set (0.00 sec)

DROP DATABASE IF EXISTS wikipedia;
-- Query OK, 2 rows affected (0.00 sec)

CREATE DATABASE wikipedia;
-- Query OK, 1 row affected (0.00 sec)

USE wikipedia
-- Database changed

DROP TABLE IF EXISTS page;
-- Query OK, 0 rows affected, 1 warning (0.00 sec)

CREATE TABLE page (
 id INT(8) UNSIGNED NOT NULL AUTO_INCREMENT,
 namespace INT(10) NOT NULL DEFAULT '0',
 title VARBINARY(255) NOT NULL DEFAULT '',
 PRIMARY KEY (id))
ENGINE = MyISAM DEFAULT CHARSET = BINARY;
-- Query OK, 0 rows affected (0.01 sec)

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

DELETE FROM linkpage
WHERE title NOT REGEXP BINARY '^\'[0-9]{4,}|^\'[a-zA-Z]{2,}';
-- Query OK, 3863467 rows affected (25.88 sec)

CREATE INDEX title ON page (title);
-- Query OK, 12847379 rows affected (36.44 sec)
-- Records: 12847379  Duplicates: 0  Warnings: 0

UPDATE linkpage, page
SET linkpage.id = page.id
WHERE linkpage.title = page.title;
-- Query OK, 24814938 rows affected (3 min 18.19 sec)
-- Rows matched: 24814938  Changed: 24814938  Warnings: 0

DELETE FROM linkpage WHERE id < 10;
-- Query OK, 1619271 rows affected (10.80 sec)

SHOW TABLES;
/* +---------------------+
 * | Tables_in_wikipedia |
 * +---------------------+
 * | linkpage            |
 * | page                |
 * +---------------------+ */
-- 2 rows in set (0.00 sec)

DESCRIBE page;
/* +-------+-----------------+------+-----+---------+----------------+
 * | Field | Type            | Null | Key | Default | Extra          |
 * +-------+-----------------+------+-----+---------+----------------+
 * | id    | int(8) unsigned | NO   | PRI | NULL    | auto_increment |
 * | title | varbinary(255)  | NO   | MUL |         |                |
 * +-------+-----------------+------+-----+---------+----------------+ */
-- 2 rows in set (0.00 sec)

DESCRIBE linkpage;
/* +-------+-----------------+------+-----+---------+-------+
 * | Field | Type            | Null | Key | Default | Extra |
 * +-------+-----------------+------+-----+---------+-------+
 * | id    | int(8) unsigned | NO   |     | 0       |       |
 * | title | varbinary(255)  | NO   |     |         |       |
 * +-------+-----------------+------+-----+---------+-------+ */
-- 2 rows in set (0.00 sec)

SELECT COUNT(*) AS `numrows in page` FROM page;
/* +-----------------+
 * | numrows in page |
 * +-----------------+
 * |        12847379 |
 * +-----------------+ */
-- 1 row in set (0.00 sec)

SELECT COUNT(*) AS `numRows in linkpage` FROM linkpage;
/* +---------------------+
 * | numRows in linkpage |
 * +---------------------+
 * |            24814938 |
 * +---------------------+ */
-- 1 row in set (0.00 sec)


SELECT table_name as `Page Table`,
ROUND(data_length/1024/1024, 2) `Data length (MiB)`,
ROUND(index_length/1024/1024, 2) `Index length (MiB)`
FROM information_schema.TABLES
WHERE table_schema = "wikipedia" and table_name = "page";
/* +------------+-------------------+--------------------+
 * | Page Table | Data length (MiB) | Index length (MiB) |
 * +------------+-------------------+--------------------+
 * | page       |            399.36 |             482.22 |
 * +------------+-------------------+--------------------+ */
-- 1 row in set (0.00 sec)

SELECT table_name as `Linkpage Table`,
ROUND(data_length/1024/1024, 2) `Data length (MiB)`,
ROUND(index_length/1024/1024, 2) `Index length (MiB)`
FROM information_schema.TABLES
WHERE table_schema = "wikipedia" and table_name = "linkpage";
/* +----------------+-------------------+--------------------+
 * | Linkpage Table | Data length (MiB) | Index length (MiB) |
 * +----------------+-------------------+--------------------+
 * | linkpage       |           1135.45 |               0.00 |
 * +----------------+-------------------+--------------------+ */
-- 1 row in set (0.00 sec)

