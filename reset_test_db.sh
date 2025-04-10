#!/bin/bash
# Test Database Reset Script
# This script drops and recreates the test database

# Configuration
TEST_DB_NAME="qj_test_db"
DB_USER="postgres"  # Change to your PostgreSQL user

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}QuantifyJiuJitsu Test Database Reset${NC}"
echo "================================================"

# Drop the database if it exists
echo -e "${BLUE}Dropping test database if it exists...${NC}"
dropdb --if-exists $TEST_DB_NAME
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Database dropped successfully.${NC}"
else
    echo -e "${RED}Error dropping database.${NC}"
    exit 1
fi

# Create a fresh database
echo -e "${BLUE}Creating fresh test database...${NC}"
createdb $TEST_DB_NAME
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Test database created successfully.${NC}"
else
    echo -e "${RED}Error creating test database.${NC}"
    exit 1
fi

# Initialize database with extensions
echo -e "${BLUE}Initializing test database...${NC}"
psql -d $TEST_DB_NAME -f schema/init.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Test database initialized successfully.${NC}"
else
    echo -e "${RED}Error initializing test database.${NC}"
    exit 1
fi

# Create tables
echo -e "${BLUE}Creating tables...${NC}"
psql -d $TEST_DB_NAME -f schema/tables.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Tables created successfully.${NC}"
else
    echo -e "${RED}Error creating tables.${NC}"
    exit 1
fi

# Create functions
echo -e "${BLUE}Creating functions...${NC}"
psql -d $TEST_DB_NAME -f functions/search_vector.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Functions created successfully.${NC}"
else
    echo -e "${RED}Error creating functions.${NC}"
    exit 1
fi

# Load sample test data
echo -e "${BLUE}Loading test data...${NC}"
psql -d $TEST_DB_NAME -f utils/seed_data.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Test data loaded successfully.${NC}"
else
    echo -e "${RED}Error loading test data.${NC}"
    exit 1
fi

echo -e "${GREEN}Test database setup complete!${NC}"
echo ""
echo -e "${BLUE}Connection information:${NC}"
echo "Database: $TEST_DB_NAME"
echo "User: $DB_USER"
echo "================================================"
echo -e "${BLUE}You can now run tests against this database.${NC}"