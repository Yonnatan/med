import os
import boto3
import psycopg2
import json

def get_secret():
    secret_name = os.environ['DB_SECRET_NAME']
    region_name = os.environ['AWS_REGION']
    session = boto3.session.Session()
    client = session.client(service_name='secretsmanager', region_name=region_name)
    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
    except Exception as e:
        print(f"Failed to retrieve secret: {e}")
        raise e
    else:
        if 'SecretString' in get_secret_value_response:
            secret = get_secret_value_response['SecretString']
            return json.loads(secret)
        else:
            raise ValueError("Secret not found")

def setup_rls(conn, cur):
    try:
        print("Setting up RLS...")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                tenant_id INTEGER,
                username TEXT,
                email TEXT
            )
        """)
        cur.execute("ALTER TABLE users ENABLE ROW LEVEL SECURITY")
        cur.execute("""
            CREATE OR REPLACE FUNCTION get_current_tenant_id() RETURNS INTEGER AS $$
            BEGIN
                RETURN NULLIF(current_setting('app.current_tenant_id', TRUE), '')::INTEGER;
            END;
            $$ LANGUAGE plpgsql
        """)
        cur.execute("""
            DROP POLICY IF EXISTS tenant_isolation_policy ON users;
            CREATE POLICY tenant_isolation_policy ON users
            USING (tenant_id = get_current_tenant_id())
        """)
        conn.commit()
        print("RLS setup completed successfully.")
    except Exception as e:
        print(f"Failed to set up RLS: {e}")
        raise

def insert_sample_data(conn, cur):
    try:
        print("Inserting sample data...")
        cur.execute("TRUNCATE TABLE users RESTART IDENTITY")
        cur.execute("""
            INSERT INTO users (tenant_id, username, email) VALUES
            (1, 'user1', 'user1@tenant1.com'),
            (1, 'user2', 'user2@tenant1.com'),
            (2, 'user3', 'user3@tenant2.com'),
            (2, 'user4', 'user4@tenant2.com')
        """)
        conn.commit()
        print("Sample data inserted successfully.")
    except Exception as e:
        print(f"Failed to insert sample data: {e}")
        raise

def user_exists(cur, username):
    cur.execute("SELECT 1 FROM pg_roles WHERE rolname=%s", (username,))
    return cur.fetchone() is not None

def create_tenant_users(conn, cur):
    try:
        print("Creating tenant users...")
        if not user_exists(cur, 'tenant1_user'):
            cur.execute("CREATE USER tenant1_user WITH PASSWORD 'tenant1pass'")
        else:
            print("User tenant1_user already exists.")
        if not user_exists(cur, 'tenant2_user'):
            cur.execute("CREATE USER tenant2_user WITH PASSWORD 'tenant2pass'")
        else:
            print("User tenant2_user already exists.")
        cur.execute("GRANT SELECT ON users TO tenant1_user")
        cur.execute("GRANT SELECT ON users TO tenant2_user")
        conn.commit()
        print("Tenant users created successfully.")
    except Exception as e:
        print(f"Failed to create tenant users: {e}")
        raise

def query_data_as_user(tenant_id, user, password):
    try:
        print(f"Querying data for tenant ID: {tenant_id} using user: {user}")
        secret = get_secret()
        host = os.environ['DB_HOST']
        db_name = secret['dbname']
        conn = psycopg2.connect(
            host=host,
            database=db_name,
            user=user,
            password=password
        )
        with conn.cursor() as cur:
            cur.execute("SELECT set_config('app.current_tenant_id', %s, TRUE)", (str(tenant_id),))
            cur.execute("SELECT * FROM users ORDER BY id")
            rows = cur.fetchall()
            print(f"Data queried successfully for tenant ID: {tenant_id} using user: {user}")
            return [dict(id=row[0], tenant_id=row[1], username=row[2], email=row[3]) for row in rows]
    except Exception as e:
        print(f"Failed to query data for tenant ID {tenant_id} using user {user}: {e}")
        raise
    finally:
        if conn:
            conn.close()

def format_data(data):
    return '\n'.join([f" ID: {item['id']}, Tenant ID: {item['tenant_id']}, Username: {item['username']}, Email: {item['email']}" for item in data])

def lambda_handler(event, context):
    print("Lambda function started")
    try:
        secret = get_secret()
        host = os.environ['DB_HOST']
        db_name = secret['dbname']
        username = secret['username']
        password = secret['password']
        conn = psycopg2.connect(
            host=host,
            database=db_name,
            user=username,
            password=password
        )
        with conn.cursor() as cur:
            print(f"Connected to database: {db_name} on host: {host}")
            setup_rls(conn, cur)
            insert_sample_data(conn, cur)
            create_tenant_users(conn, cur)

        # Query data as tenant users
        tenant1_data = query_data_as_user(1, 'tenant1_user', 'tenant1pass')
        tenant2_data = query_data_as_user(2, 'tenant2_user', 'tenant2pass')
        all_data = query_data_as_user(None, username, password)

        rls_working = len(tenant1_data) < len(all_data) and len(tenant2_data) < len(all_data)
        multi_tenancy_working = all(user['tenant_id'] == 1 for user in tenant1_data) and all(user['tenant_id'] == 2 for user in tenant2_data)

        output = f"""
        <pre>
        Multi-tenancy and Row-Level Security Test Results:

        Tenant 1 Data:
        {format_data(tenant1_data)}

        Tenant 2 Data:
        {format_data(tenant2_data)}

        All Data:
        {format_data(all_data)}

        RLS Working: {rls_working}
        Multi-tenancy Working: {multi_tenancy_working}
        </pre>
        """
        return {
            'statusCode': 200,
            'body': output
        }
    except Exception as e:
        print(f"Error during Lambda execution: {e}")
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }
    finally:
        if conn:
            conn.close()
            print("Database connection closed.")