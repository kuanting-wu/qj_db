#!/bin/bash
# Database setup script for QuantifyJiuJitsu
# This script sets up the database schema and applies migrations

# Configuration
DB_NAME="qj_database"
DB_USER="postgres"  # Change to your PostgreSQL user

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}QuantifyJiuJitsu Database Setup${NC}"
echo "================================================"

# Check if database exists
echo -e "${BLUE}Checking if database exists...${NC}"
if psql -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
    echo -e "${GREEN}Database $DB_NAME already exists.${NC}"
else
    echo -e "Creating database $DB_NAME..."
    createdb $DB_NAME
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Database created successfully.${NC}"
    else
        echo -e "${RED}Error creating database. Please create it manually.${NC}"
        exit 1
    fi
fi

# Initialize database with extensions
echo -e "${BLUE}Initializing database...${NC}"
psql -d $DB_NAME -f schema/init.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Database initialized successfully.${NC}"
else
    echo -e "${RED}Error initializing database.${NC}"
    exit 1
fi

# Create tables
echo -e "${BLUE}Creating tables...${NC}"
psql -d $DB_NAME -f schema/tables.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Tables created successfully.${NC}"
else
    echo -e "${RED}Error creating tables.${NC}"
    exit 1
fi

# Create functions
echo -e "${BLUE}Creating functions...${NC}"
psql -d $DB_NAME -f functions/search_vector.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Functions created successfully.${NC}"
else
    echo -e "${RED}Error creating functions.${NC}"
    exit 1
fi

# Ask if sample data should be loaded
echo -e "${BLUE}Do you want to load sample data? (y/n)${NC}"
read -r load_sample

if [[ $load_sample =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Loading sample data...${NC}"
    psql -d $DB_NAME -f utils/seed_data.sql
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Sample data loaded successfully.${NC}"
    else
        echo -e "${RED}Error loading sample data.${NC}"
    fi
fi

echo -e "${GREEN}Database setup complete!${NC}"
echo ""
echo -e "${BLUE}Connection information:${NC}"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "================================================"