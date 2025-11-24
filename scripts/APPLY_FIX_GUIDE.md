# How to Fix Order Service Database Connection

## Problem Location
Based on the error logs, the issue is in:
- **File**: `main.py` (or `app/main.py` depending on structure)
- **Function**: `get_connection()` 
- **Approximate line**: Around line 57

## Step-by-Step Fix

### 1. Clone/Open the Order Service Repository

```bash
# If you haven't already
git clone https://github.com/elegante-libero-hub-luxrent-platform/order_and_rental_service.git
cd order_and_rental_service
```

### 2. Find the Database Connection Code

Search for the `get_connection()` function:

```bash
# Search for the function
grep -n "def get_connection" main.py
# or
grep -n "mysql.connector.connect" main.py
```

### 3. Locate the Current Code

The current code likely looks like this:

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

### 4. Replace with Fixed Code

Replace the function with this:

```python
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
```

### 5. If Using Connection Pooling

If your code uses a connection pool, update it like this:

```python
# Find the pool configuration code and update it
pool_config = {
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD'),
    'database': os.getenv('DB_NAME'),
    'pool_name': 'order_pool',
    'pool_size': 5,
    'pool_reset_session': True
}

db_host = os.getenv('DB_HOST')
if db_host and db_host.startswith('/cloudsql/'):
    pool_config['unix_socket'] = db_host
else:
    pool_config['host'] = db_host
    pool_config['port'] = int(os.getenv('DB_PORT', 3306))

pool = mysql.connector.pooling.MySQLConnectionPool(**pool_config)
```

### 6. Test Locally (Optional)

If you want to test locally first:

```bash
# Set environment variables for local testing
export DB_HOST=localhost  # or your local MySQL host
export DB_USER=your_user
export DB_PASSWORD=your_password
export DB_NAME=your_database
export DB_PORT=3306

# Run the service
python main.py
```

### 7. Commit and Push

```bash
git add main.py  # or the file you modified
git commit -m "Fix Cloud SQL Unix socket connection for Cloud Run"
git push
```

### 8. Wait for Cloud Build to Deploy

Cloud Build will automatically:
1. Build a new Docker image
2. Deploy to Cloud Run
3. Create a new revision

### 9. Verify the Fix

After deployment (usually 2-5 minutes), test the connection:

```bash
curl -X POST "https://order-and-rental-service-plrurfl3kq-ew.a.run.app/orders" \
  -H 'Content-Type: application/json' \
  -d '{"user_id":1,"item_id":1,"start_date":"2025-01-05","end_date":"2025-01-09"}'
```

### 10. Check Logs if Still Failing

```bash
gcloud run services logs read order-and-rental-service \
  --region=europe-west1 \
  --limit=50
```

## Key Points

- **Unix socket path**: `/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-orders`
- **Use `unix_socket` parameter**, not `host` when the path starts with `/cloudsql/`
- **Keep TCP connection** for local development (when host is not a Unix socket path)

## Files to Check

1. `main.py` - Most likely location
2. `database.py` - If database code is separated
3. `config.py` or `settings.py` - If connection is configured there
4. Any file with `mysql.connector.connect` in it




