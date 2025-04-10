-- QuantifyJiuJitsu Main Database Tables
-- This file defines the core tables for the application
-- Last updated: 2025-03-13

-- Users table - Stores authentication information
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    hashed_password VARCHAR(255),
    google_id VARCHAR(255) UNIQUE,
    email_verified BOOLEAN DEFAULT FALSE,
    verification_token VARCHAR(255),
    verification_token_expiry TIMESTAMP,
    reset_token VARCHAR(255),
    reset_token_expiry TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Profiles table - Stores user profile information
CREATE TABLE IF NOT EXISTS profiles (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    username VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100),
    belt VARCHAR(20),
    academy VARCHAR(100),
    bio TEXT,
    location VARCHAR(100),
    nationality VARCHAR(50),
    weight_class VARCHAR(30),
    height VARCHAR(30),
    date_of_birth DATE,
    social_links JSONB,
    achievements TEXT,
    website_url VARCHAR(255),
    contact_email VARCHAR(255),
    avatar_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create position type enum
CREATE TYPE position_type AS ENUM ('TOP', 'BOTTOM', 'NEUTRAL');

-- Posts table - Stores BJJ technique posts
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY,
    title VARCHAR(63) NOT NULL,
    video_id VARCHAR(30) NOT NULL,
    video_platform VARCHAR(10) NOT NULL,
    owner_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movement_type VARCHAR(50),
    starting_position VARCHAR(50),
    ending_position VARCHAR(50),
    starting_top_bottom position_type DEFAULT 'NEUTRAL',
    ending_top_bottom position_type DEFAULT 'NEUTRAL',
    gi_nogi VARCHAR(10) DEFAULT 'Gi',
    practitioner VARCHAR(100) DEFAULT NULL,
    sequence_start_time VARCHAR(10),
    public_status VARCHAR(20) CHECK (public_status IN ('public', 'private', 'subscribers')) DEFAULT 'public',
    language VARCHAR(30) CHECK (language IN ('English', 'Japanese', 'Traditional Chinese')) DEFAULT 'English',
    notes_path TEXT,
    search_vector tsvector, -- Full-text search column
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SELECT * FROM posts;

-- View that joins posts with profiles (for backward compatibility)
CREATE OR REPLACE VIEW posts_with_owner AS
SELECT 
    p.*,
    pr.username AS owner_name,
    pr.avatar_url,
    pr.belt,
    pr.academy
FROM 
    posts p
JOIN 
    profiles pr ON p.owner_id = pr.user_id;



-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);
CREATE INDEX IF NOT EXISTS idx_posts_owner_id ON posts(owner_id);
CREATE INDEX IF NOT EXISTS idx_posts_movement_type ON posts(movement_type);
CREATE INDEX IF NOT EXISTS idx_posts_gi_nogi ON posts(gi_nogi);
CREATE INDEX IF NOT EXISTS idx_posts_public_status ON posts(public_status);
CREATE INDEX IF NOT EXISTS idx_posts_search_vector ON posts USING gin(search_vector);

-- Add comments to explain the fields
COMMENT ON TABLE posts IS 'Positions have starting_position and ending_position text fields with associated top/bottom position type enum fields. gi_nogi indicates if the technique is for Gi, No-Gi, or Both contexts. practitioner field stores the name of the BJJ practitioner/instructor demonstrating the technique.';
COMMENT ON COLUMN posts.public_status IS 'Public status can be public (visible to everyone), private (visible only to owner), or subscribers (visible to subscribers only)';
COMMENT ON COLUMN posts.search_vector IS 'Stores preprocessed text from multiple columns for full-text search with weights: title (A), positions/practitioner (B), position types (C)';