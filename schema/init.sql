-- QuantifyJiuJitsu Database Initialization
-- This file creates the database extensions and initial setup
-- Last updated: 2025-03-13

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  -- For UUID functions
CREATE EXTENSION IF NOT EXISTS "vector";     -- For vector operations
CREATE EXTENSION IF NOT EXISTS "pg_trgm";    -- For similarity matching

-- Create the application database user
CREATE USER lambda_user WITH PASSWORD 'refoldprayinganywhere3';
GRANT CONNECT ON DATABASE qj_database TO lambda_user;
GRANT USAGE ON SCHEMA public TO lambda_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO lambda_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO lambda_user;

-- Add a comment explaining the database setup
COMMENT ON DATABASE qj_database IS 'QuantifyJiuJitsu main database. Contains users, profiles, and posts.';