"""
Fix for order service database connection.
Based on error logs, the issue is in /app/main.py around line 57.

Replace the get_connection() function with this code.
"""

# BEFORE (Current - Incorrect):
"""
def get_connection():
    return mysql.connector.connect(
        host=os.getenv('DB_HOST'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_NAME'),
        port=int(os.getenv('DB_PORT', 3306))
    )
"""

# AFTER (Fixed - Correct):
def get_connection():
    """
    Get database connection, supporting both Unix socket (Cloud Run) and TCP (local dev).
    """
    db_host = os.getenv('DB_HOST')
    db_user = os.getenv('DB_USER')
    db_password = os.getenv('DB_PASSWORD')
    db_name = os.getenv('DB_NAME')
    db_port = os.getenv('DB_PORT', '3306')
    
    # Check if using Unix socket (Cloud Run with Cloud SQL)
    if db_host and db_host.startswith('/cloudsql/'):
        # Use Unix socket connection for Cloud Run
        return mysql.connector.connect(
            unix_socket=db_host,  # Use unix_socket parameter, not host
            user=db_user,
            password=db_password,
            database=db_name
        )
    else:
        # Use TCP connection for local development
        return mysql.connector.connect(
            host=db_host,
            user=db_user,
            password=db_password,
            database=db_name,
            port=int(db_port)
        )


# Alternative: If using connection pooling, update the pool config:
def get_connection_pool():
    """
    Get connection pool with Unix socket support.
    """
    db_host = os.getenv('DB_HOST')
    db_user = os.getenv('DB_USER')
    db_password = os.getenv('DB_PASSWORD')
    db_name = os.getenv('DB_NAME')
    db_port = os.getenv('DB_PORT', '3306')
    
    pool_config = {
        'user': db_user,
        'password': db_password,
        'database': db_name,
        'pool_name': 'order_pool',
        'pool_size': 5,
        'pool_reset_session': True
    }
    
    if db_host and db_host.startswith('/cloudsql/'):
        pool_config['unix_socket'] = db_host
    else:
        pool_config['host'] = db_host
        pool_config['port'] = int(db_port)
    
    return mysql.connector.pooling.MySQLConnectionPool(**pool_config)




