# Titanic API – Setup and Verification Guide

## Part 1: Containerization and Local Development

### Prerequisites

* Docker 20.10+
* Docker Compose 2.0+
* curl (for API testing)
* Python 3.8+ (for data import scripts)

### Quick Start

#### 1. Clone and Setup

```bash
# Clone the repository
# git clone <repository-url>
# cd titanic-api

# Start all services
docker-compose up -d

# Import Titanic data
./scripts/import-simple.sh

# Verify setup
curl http://localhost:5002/
```

#### 2. Services Overview

* API: [http://localhost:5002](http://localhost:5002)
* PostgreSQL: localhost:5432
* pgAdmin: [http://localhost:5050](http://localhost:5050) (optional)

#### 3. Credentials

* Database: titanic_user / titanic_password
* pgAdmin: [admin@titanic.com](mailto:admin@titanic.com) / admin123

---

## Detailed Setup

### A. Development Environment

```bash
# Build and start
docker-compose build --no-cache
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f app

# Stop services
docker-compose down
```

### B. Data Import

The Titanic dataset (887 passengers) is automatically imported via:

```bash
./scripts/import-simple.sh
```

This creates a temporary SQL file and imports it into PostgreSQL.

### C. API Testing

#### Basic Tests

```bash
# Root endpoint
curl http://localhost:5002/

# Get all passengers
curl http://localhost:5002/people

# Count passengers
curl -s http://localhost:5002/people | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data))"

# Get specific passenger (replace UUID)
curl http://localhost:5002/people/<uuid-here>
```

#### CRUD Operations

```bash
# Create new passenger
curl -X POST http://localhost:5002/people \
  -H "Content-Type: application/json" \
  -d '{
    "survived": 1,
    "passengerClass": 1,
    "name": "Test Name",
    "sex": "male",
    "age": 30,
    "siblingsOrSpousesAboard": 0,
    "parentsOrChildrenAboard": 0,
    "fare": 50.0
  }'

# Update passenger
curl -X PUT http://localhost:5002/people/<uuid> \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Name"}'

# Delete passenger
curl -X DELETE http://localhost:5002/people/<uuid>
```

### D. Database Access

```bash
# Direct database access
docker-compose exec postgres psql -U titanic_user -d titanic
```

Common queries:

```sql
SELECT COUNT(*) FROM people;  -- Total passengers
SELECT * FROM people LIMIT 5; -- First 5 passengers
```

### E. Production Build

```bash
# Build production image
docker build -t titanic-api:latest -f docker/prod/Dockerfile .

# Check image size (should be <200MB)
docker images titanic-api:latest

# Run production container
docker run -d -p 8080:5000 \
  -e DATABASE_URL=postgresql://user:pass@host:5432/db \
  -e JWT_SECRET_KEY=your-secret-key \
  titanic-api:latest
```

---

## Verification Checklist

### Container Status

* All containers running (docker-compose ps)
* Health checks passing (status: healthy)
* Ports mapped correctly (5002, 5432, 5050)

### API Functionality

* Root endpoint accessible
* GET /people returns 887 passengers
* CRUD operations working
* UUID-based resource access

### Database

* 887 passengers in database
* UUID primary keys generated
* Schema matches application needs

### Security

* Running as non-root user
* No hardcoded secrets
* Environment variables configured

### Performance

* Production image <200MB
* API response time <100ms
* Health checks working

---

## Troubleshooting

### Common Issues

#### Port already in use

```bash
# Check what's using the port
lsof -i :5002

# Or change port in docker-compose.yml
# Edit "5002:5000" to "5003:5000"
```

#### Database connection issues

```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Check logs
docker-compose logs postgres

# Test connection from app container
docker-compose exec app python3 -c "
import psycopg2
try:
    conn = psycopg2.connect('postgresql://titanic_user:titanic_password@postgres:5432/titanic')
    print('Connection successful')
    conn.close()
except Exception as e:
    print(f'Error: {e}')
"
```

#### Data import failed

```bash
# Check if CSV file exists in container
docker-compose exec postgres ls -la /docker-entrypoint-initdb.d/

# Manually import data
docker-compose exec -T postgres psql -U titanic_user -d titanic < /path/to/import.sql
```

---

## Project Structure Reference

```
titanic-api/
├── app/
│   ├── src/
│   │   ├── models/
│   │   └── views/
│   ├── requirements.txt
│   ├── titanic.csv
│   └── titanic.sql
├── docker/
│   ├── dev/Dockerfile
│   └── prod/Dockerfile
├── scripts/
│   ├── import-simple.sh
│   └── test-api.sh
├── docker-compose.yml
├── docker-compose.prod.yml
└── .env.example
```

---

## API Documentation

### Endpoints

| Method | Endpoint       | Description            |
| ------ | -------------- | ---------------------- |
| GET    | /              | Welcome message        |
| GET    | /people        | List all passengers    |
| POST   | /people        | Create new passenger   |
| GET    | /people/{uuid} | Get specific passenger |
| PUT    | /people/{uuid} | Update passenger       |
| DELETE | /people/{uuid} | Delete passenger       |

### Example Responses

```json
// GET /people (first item)
{
  "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "survived": 0,
  "passengerClass": 3,
  "name": "Mr. Owen Harris Braund",
  "sex": "male",
  "age": 22.0,
  "siblingsOrSpousesAboard": 1,
  "parentsOrChildrenAboard": 0,
  "fare": 7.25
}

// POST /people (response)
{
  "uuid": "new-uuid-here",
  "survived": 1,
  "passengerClass": 1,
  "name": "Test Passenger",
  "sex": "female",
  "age": 28.0,
  "siblingsOrSpousesAboard": 0,
  "parentsOrChildrenAboard": 0,
  "fare": 89.50
}
```

---

## Part 1 Completion Status

All requirements completed and verified.

Proceed to Part 2: Kubernetes Deployment.
