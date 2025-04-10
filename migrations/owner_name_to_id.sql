-- Owner Name to Owner ID Migration
-- This script migrates the posts table from using owner_name to owner_id
-- Last updated: 2025-03-13

-- Start a transaction for atomic operation
BEGIN;

-- Step 1: Add owner_id column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'posts' AND column_name = 'owner_id'
    ) THEN
        ALTER TABLE posts ADD COLUMN owner_id BIGINT;
    END IF;
END $$;

-- Step 2: Update the owner_id based on the username in owner_name
UPDATE posts p
SET owner_id = (
    SELECT user_id 
    FROM profiles 
    WHERE username = p.owner_name
)
WHERE owner_id IS NULL AND owner_name IS NOT NULL;

-- Step 3: Add a NOT NULL constraint and foreign key if all records have been updated
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM posts WHERE owner_id IS NULL
    ) THEN
        -- Add foreign key constraint
        ALTER TABLE posts 
        ADD CONSTRAINT fk_posts_owner_id 
        FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE;
        
        -- Add NOT NULL constraint
        ALTER TABLE posts 
        ALTER COLUMN owner_id SET NOT NULL;
        
        -- Create an index on owner_id
        CREATE INDEX IF NOT EXISTS idx_posts_owner_id ON posts(owner_id);
    ELSE
        RAISE EXCEPTION 'Some records could not be migrated. Check records with owner_id IS NULL.';
    END IF;
END $$;

-- Step 4: Create a posts_with_owner view to maintain backward compatibility
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

-- Step 5: Verify the migration
SELECT COUNT(*) FROM posts WHERE owner_id IS NULL;
-- Should return 0

-- Commit if all steps are successful
COMMIT;