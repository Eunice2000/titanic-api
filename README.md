# Titanic API - DevOps Assessment

This repository contains a production-ready implementation of the Titanic API with complete DevOps practices.

## Quick Start
```bash
# Development
docker-compose up -d

# Production build
docker build -t titanic-api:latest -f docker/prod/Dockerfile ./app
