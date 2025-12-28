"""
Database Configuration - Raw SQL Connection
No ORM - Direct MySQL queries
"""

import mysql.connector
from mysql.connector import pooling
import os
from dotenv import load_dotenv
from contextlib import contextmanager

load_dotenv()

# Database configuration
DB_CONFIG = {
    "host": os.getenv("DATABASE_HOST", "localhost"),
    "port": int(os.getenv("DATABASE_PORT", 3306)),
    "database": os.getenv("DATABASE_NAME", "lockspot_db"),
    "user": os.getenv("DATABASE_USER", "root"),
    "password": os.getenv("DATABASE_PASSWORD", ""),
    "charset": "utf8mb4",
    "collation": "utf8mb4_unicode_ci",
    "autocommit": False,  # Manual transaction control
}

# Connection pool for better performance
connection_pool = None

def init_connection_pool(pool_size: int = 10):
    """Initialize connection pool"""
    global connection_pool
    try:
        connection_pool = pooling.MySQLConnectionPool(
            pool_name="lockspot_pool",
            pool_size=pool_size,
            pool_reset_session=True,
            **DB_CONFIG
        )
        print(f"✅ Database connection pool initialized (size: {pool_size})")
        return True
    except Exception as e:
        print(f"❌ Failed to initialize connection pool: {e}")
        return False


def get_db_connection():
    """Get a connection from the pool or create a new one"""
    global connection_pool
    
    try:
        if connection_pool:
            return connection_pool.get_connection()
        else:
            return mysql.connector.connect(**DB_CONFIG)
    except Exception as e:
        print(f"❌ Database connection error: {e}")
        raise


@contextmanager
def get_db_cursor(dictionary: bool = True, commit: bool = False):
    """
    Context manager for database cursor.
    
    Usage:
        with get_db_cursor() as (cursor, conn):
            cursor.execute("SELECT * FROM User WHERE UserID = %s", (user_id,))
            result = cursor.fetchone()
    
    Args:
        dictionary: Return results as dictionaries (default: True)
        commit: Auto-commit on successful execution (default: False)
    """
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=dictionary)
        yield cursor, conn
        if commit:
            conn.commit()
    except Exception as e:
        if conn:
            conn.rollback()
        raise e
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


def execute_query(query: str, params: tuple = None, fetch_one: bool = False, 
                  fetch_all: bool = False, commit: bool = False):
    """
    Execute a raw SQL query.
    
    Args:
        query: SQL query string
        params: Query parameters (tuple)
        fetch_one: Return single row
        fetch_all: Return all rows
        commit: Commit transaction
    
    Returns:
        Query results or affected row count
    """
    with get_db_cursor(commit=commit) as (cursor, conn):
        cursor.execute(query, params)
        
        if fetch_one:
            return cursor.fetchone()
        elif fetch_all:
            return cursor.fetchall()
        else:
            if commit:
                return cursor.lastrowid if cursor.lastrowid else cursor.rowcount
            return cursor.rowcount


def execute_procedure(proc_name: str, params: tuple = None):
    """
    Execute a stored procedure.
    
    Args:
        proc_name: Stored procedure name
        params: Input/Output parameters
    
    Returns:
        Output parameters and result sets
    """
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Call stored procedure
        result_args = cursor.callproc(proc_name, params)
        
        # Fetch any result sets
        results = []
        for result in cursor.stored_results():
            results.extend(result.fetchall())
        
        conn.commit()
        
        return {
            "output_params": result_args,
            "results": results
        }
    except Exception as e:
        if conn:
            conn.rollback()
        raise e
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


# Initialize connection pool on module load
init_connection_pool()
