"""
Example FastAPI endpoint to test Cloud SQL connection.
Add this to your order service's main.py or routers.
"""
from fastapi import APIRouter, HTTPException
from typing import Dict, Any
import os

router = APIRouter(prefix="/test", tags=["testing"])


@router.get("/db-connection")
async def test_database_connection() -> Dict[str, Any]:
    """
    Test endpoint to verify Cloud Run can connect to Cloud SQL.
    Returns connection status and database info.
    """
    db_host = os.getenv('DB_HOST', '')
    db_user = os.getenv('DB_USER', '')
    db_name = os.getenv('DB_NAME', '')
    db_port = os.getenv('DB_PORT', '3306')
    
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
        # Try MySQL connector first
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
            
            # Test a simple table query if orders table exists
            try:
                cursor.execute("SELECT COUNT(*) FROM orders")
                count = cursor.fetchone()[0]
                result['orders_table_exists'] = True
                result['orders_count'] = count
            except Exception:
                result['orders_table_exists'] = False
            
            cursor.close()
            conn.close()
            
        except ImportError:
            # Fallback to SQLAlchemy
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
        raise HTTPException(status_code=503, detail=result)
    
    return result




