#!/usr/bin/env python


# Module Import
import mariadb
from mariadb.constants import *
import time
from datetime import datetime
import sys
import os
from pprint import pprint

# connection parameters
db_connection_params = {
  "host" : os.getenv("MYSQL_HOST", "127.0.0.1"),
  "port" : int(os.getenv("MYSQL_PORT", "3306")),
  "user" : os.getenv("MYSQL_USER", "testuser"),
  "password" : os.getenv("MYSQL_PASSWORD", ""),
  "database" : os.getenv("MYSQL_DBNAME", "testdb"),
  "reconnect" : True,
  "autocommit": True
}

# pool size
pool_size = 5

# additional parameters
test_table_name = os.getenv("MYSQL_TEST_TBL", 'test1')

# table structure -- for automatic table creation
TABLE_DDL = (
    f"CREATE TABLE `{test_table_name}` ("
    "   `id` int(11) NOT NULL AUTO_INCREMENT,"
    "   `datestr` varchar(30) NOT NULL,"
    "   `created_at` timestamp NOT NULL DEFAULT current_timestamp(),"
    "    PRIMARY KEY (`id`),"
    "    KEY `datestr` (`datestr`)"
    ") ENGINE=InnoDB"
)

# Create Connection Pool
def create_connection_pool():
    """Creates and returns a Connection Pool"""

    # Create Connection Pool
    pool = mariadb.ConnectionPool(pool_name = "testapp", pool_size  = pool_size, pool_reset_connection = False, **db_connection_params)
    # print("Pool size of '%s': %s" % (pool.pool_name, pool.pool_size))

    # Return Connection Pool
    return pool

# Create table used for this test
def create_table(cursor):
    """Creates testing table"""
    try:
        print(f"Creating table `{test_table_name}`: ... ", end='')
        cursor.execute(TABLE_DDL)
        print("success!")
    except mariadb.OperationalError as e:
        if e.errno == ERR.ER_TABLE_EXISTS_ERROR:
            print("already exists.")
        else:
            print(e.msg)

# insert a row with local date representation
def insert_current_time(cursor):
    """Inserts a record into testing table"""
    format_string = '%Y-%m-%d %H:%M:%S.%f'
    dt_now = datetime.now()
    current_time_string = dt_now.strftime(format_string)
    try:
        cursor.execute(f"INSERT INTO `{test_table_name}` (datestr) VALUES (%s)", (current_time_string,))
        return True
    except mariadb.InterfaceError as e:
        print(f"DB connection error: {e}", file=sys.stderr)
        return False
    except mariadb.OperationalError as e:
        print(f"DB operational error: {e}", file=sys.stderr)
        return False
    
# print details of the last inserted row
def print_last_row(cursor):
    """Fetches and prints last inserted record"""
    try:
        cursor.execute(f"SELECT id, datestr, created_at FROM `{test_table_name}` ORDER BY id DESC LIMIT 1")
        # data = cur.fetchone()
        format_string = '%Y-%m-%d %H:%M:%S'
        for (id, datestr, created_at) in cursor:
            created_at_str = created_at.strftime(format_string)
            print(", ".join([str(id), datestr, created_at_str]))
        return True
    except mariadb.InterfaceError as e:
        print(f"DB connection error: {e}", file=sys.stderr)
        return False

# Establish Pool Connection
def main():
    try:
        pool = create_connection_pool()
    except mariadb.PoolError as e:
        # Report Error
        print(f"Error opening connection from pool: {e}", file=sys.stderr)
        return 1
    
    pconn = None
    break_indicated = False
    try:
        pconn = pool.get_connection()
        pconn.auto_reconnect = True
    except mariadb.PoolError as e:
        # Report Error and abort further execution
        print(f"Error opening connection from pool: {e}", file=sys.stderr)
        return 1      

    cur = pconn.cursor()
    create_table(cur)
    cur.close()

    for (j) in range(0, 200):
        try:
            if not pconn:
                pconn = pool.get_connection()
                pconn.auto_reconnect = True
    
            # main working loop ...
            ok = False
            for (k) in range(0,10):
                # Instantiate Cursor
                cur = pconn.cursor()
                if insert_current_time(cur):
                    try:
                        pconn.commit()
                    except mariadb.OperationalError as e:
                        print(f"Error in pconn.commit: {e}", file=sys.stderr)
                        time.sleep(5)
                        break
                else:
                    break
                time.sleep(1)
                if print_last_row(cur):
                    pass
                    cur.close()
                    ok = True
                else:
                    break
                time.sleep(2)

            if not ok:
                break_indicated = True

        except mariadb.OperationalError as e:
            print(f"Error in pool.get_connection(): {e}", file=sys.stderr)
            time.sleep(1)
            if break_indicated:
                print("Breaking operation due to excessive connection errors")
                break
            else:
                time.sleep(4)
                continue
    
        except mariadb.PoolError as e:
            # Report Error
            print(f"Error opening connection from pool: {e}", file=sys.stderr)
            return 1            

        finally:
            if pconn:
                try:
                    pconn.close()
                except:
                    # Not really expected, but if this ever happens it should not alter
                    # whatever happened in the try or except sections above.
                    print(f"Error in pconn.close: {e}", file=sys.stderr)
                    time.sleep(5)
                finally:
                    pconn = None
      
    print("Job done.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
