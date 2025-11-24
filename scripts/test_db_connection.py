#!/usr/bin/env python3
"""
Test script to verify Cloud Run to Cloud SQL connection.
This can be added as a test endpoint in the order service.
"""
import os
import sys
from typing import Optional

def test_cloud_sql_connection() -> dict:
    """
    Test connection to Cloud SQL using Unix socket.
    Returns a dict with connection status and details.
    """
    db_host = os.getenv('DB_HOST', '')
    db_user = os.getenv('DB_USER', '')
    db_name = os.getenv('DB_NAME', '')
    db_port = os.getenv('DB_PORT', '3306')
    
    # Check if using Unix socket (Cloud Run with Cloud SQL)
    use_unix_socket = db_host.startswith('/cloudsql/')
    
    result = {
        'connected': False,
        'method': 'unix_socket' if use_unix_socket else 'tcp',
        'host': db_host,
        'user': db_user,
        'database': db_name,
        'port': db_port,
        'error': None
    }
    
    try:
        # Try MySQL connector
        try:
            import mysql.connector
            config = {
                'user': db_user,
                'password': os.getenv('DB_PASSWORD', ''),
                'database': db_name,
            }
            
            if use_unix_socket:
                config['unix_socket'] = db_host
            else:
                config['host'] = db_host
                config['port'] = int(db_port)
            
            conn = mysql.connector.connect(**config)
            cursor = conn.cursor()
            cursor.execute("SELECT 1 as test, DATABASE() as db, USER() as user, VERSION() as version")
            row = cursor.fetchone()
            
            result['connected'] = True
            result['test_query'] = {
                'test': row[0],
                'database': row[1],
                'user': row[2],
                'version': row[3]
            }
            
            cursor.close()
            conn.close()
            
        except ImportError:
            # Try SQLAlchemy as fallback
            from sqlalchemy import create_engine, text
            
            if use_unix_socket:
                connection_string = f"mysql+pymysql://{db_user}:{os.getenv('DB_PASSWORD', '')}@/{db_name}?unix_socket={db_host}"
            else:
                connection_string = f"mysql+pymysql://{db_user}:{os.getenv('DB_PASSWORD', '')}@{db_host}:{db_port}/{db_name}"
            
            engine = create_engine(connection_string)
            with engine.connect() as conn:
                result_set = conn.execute(text("SELECT 1 as test, DATABASE() as db, USER() as user, VERSION() as version"))
                row = result_set.fetchone()
                
                result['connected'] = True
                result['test_query'] = {
                    'test': row[0],
                    'database': row[1],
                    'user': row[2],
                    'version': row[3]
                }
                
    except Exception as e:
        result['error'] = str(e)
        result['error_type'] = type(e).__name__
    
    return result


if __name__ == "__main__":
    result = test_cloud_sql_connection()
    if result['connected']:
        print("✅ Database connection successful!")
        print(f"   Method: {result['method']}")
        print(f"   Database: {result['test_query']['database']}")
        print(f"   User: {result['test_query']['user']}")
        print(f"   MySQL Version: {result['test_query']['version']}")
        sys.exit(0)
    else:
        print("❌ Database connection failed!")
        print(f"   Error: {result['error']}")
        print(f"   Host: {result['host']}")
        sys.exit(1)




