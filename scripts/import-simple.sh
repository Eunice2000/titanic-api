#!/bin/bash
set -e

echo "Simple Titanic Data Import"
echo "==========================="

# Create Python script to generate SQL
echo "Generating SQL insert statements..."
python3 > /tmp/titanic_inserts.sql << 'PYTHON'
import csv
import uuid

print("-- Titanic Data Import")
print("BEGIN;")
print("DELETE FROM people;")

with open('app/titanic.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    
    for i, row in enumerate(reader):
        # Escape single quotes in names
        name = row['Name'].replace("'", "''")
        sex = row['Sex']
        age = row['Age'] if row['Age'] else 'NULL'
        fare = row['Fare'] if row['Fare'] else 'NULL'
        survived = row['Survived']
        pclass = row['Pclass']
        siblings = row['Siblings/Spouses Aboard']
        parents = row['Parents/Children Aboard']
        
        print(f"INSERT INTO people (uuid, survived, \"passengerClass\", name, sex, age, \"siblingsOrSpousesAboard\", \"parentsOrChildrenAboard\", fare) VALUES ('{uuid.uuid4()}', {survived}, {pclass}, '{name}', '{sex}', {age}, {siblings}, {parents}, {fare});")
        
        if i % 100 == 0 and i > 0:
            print(f"-- Imported {i} records")

print("COMMIT;")
print(f"-- Total records imported: {i+1}")
PYTHON

echo "Generated SQL file with $(wc -l < /tmp/titanic_inserts.sql) lines"

echo ""
echo "Importing to database..."
docker-compose exec -T postgres psql -U titanic_user -d titanic < /tmp/titanic_inserts.sql

echo ""
echo "Verifying import..."
docker-compose exec -T postgres psql -U titanic_user -d titanic -c "SELECT COUNT(*) as total_passengers FROM people;"

echo ""
echo "Import completed!"
