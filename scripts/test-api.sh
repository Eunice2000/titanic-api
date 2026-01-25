#!/bin/bash
echo "API Test Script"
echo "==============="
echo "Testing endpoint: http://localhost:5002/"
curl -s http://localhost:5002/ | head -2
echo ""
echo "Total passengers:"
curl -s http://localhost:5002/people | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data))"
