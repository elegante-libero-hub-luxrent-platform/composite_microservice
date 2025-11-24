# Database Connection Fix for Order Service

## Problem
The order service is trying to use the Unix socket path as a hostname, causing this error:
```
Unknown MySQL server host '/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-orders'
```

## Solution
Update the `get_connection()` function in the order service to detect Unix socket paths and use the `unix_socket` parameter.

## Code Fix

### Current Code (Incorrect):
```python
def get_connection():
    return mysql.connector.connect(
        host=os.getenv('DB_HOST'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_NAME'),
        port=int(os.getenv('DB_PORT', 3306))
    )
```

### Fixed Code:
```python
def get_connection():
    db_host = os.getenv('DB_HOST')
    
    # Check if using Unix socket (Cloud Run with Cloud SQL)
    if db_host.startswith('/cloudsql/'):
        # Use Unix socket connection
        return mysql.connector.connect(
            unix_socket=db_host,  # Use unix_socket parameter
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASSWORD'),
            database=os.getenv('DB_NAME')
        )
    else:
        # Use TCP connection (local development)
        return mysql.connector.connect(
            host=db_host,
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASSWORD'),
            database=os.getenv('DB_NAME'),
            port=int(os.getenv('DB_PORT', 3306))
        )
```

## Alternative: Using SQLAlchemy

If the service uses SQLAlchemy, update the connection string:

```python
from sqlalchemy import create_engine

db_host = os.getenv('DB_HOST')
db_user = os.getenv('DB_USER')
db_password = os.getenv('DB_PASSWORD')
db_name = os.getenv('DB_NAME')

if db_host.startswith('/cloudsql/'):
    # Unix socket connection for Cloud Run
    connection_string = f"mysql+pymysql://{db_user}:{db_password}@/{db_name}?unix_socket={db_host}"
else:
    # TCP connection for local development
    db_port = os.getenv('DB_PORT', 3306)
    connection_string = f"mysql+pymysql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"

engine = create_engine(connection_string)
```

## Steps to Fix

1. **Update the order service code** in the repository:
   - Find the `get_connection()` function or database connection code
   - Apply the fix above to detect Unix socket paths

2. **Commit and push** the changes:
   ```bash
   git add .
   git commit -m "Fix Cloud SQL Unix socket connection"
   git push
   ```

3. **Wait for Cloud Build** to redeploy the service automatically

4. **Test the connection**:
   ```bash
   curl -X POST "https://order-and-rental-service-plrurfl3kq-ew.a.run.app/orders" \
     -H 'Content-Type: application/json' \
     -d '{"user_id":1,"item_id":1,"start_date":"2025-01-05","end_date":"2025-01-09"}'
   ```

## Verification

After the fix is deployed, the connection should work. You can verify by:
- Checking service logs for successful database connections
- Testing the `/orders` endpoint
- Using the test endpoint if you added it: `/test/db-connection`




