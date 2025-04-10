-- Full-Text Search Migration for QuantifyJiuJitsu
-- This migration adds full-text search capability to the posts table
-- Last updated: 2025-03-13

-- Step 1: Add the search vector column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'posts' AND column_name = 'search_vector'
    ) THEN
        ALTER TABLE posts ADD COLUMN search_vector tsvector;
        
        -- Add comment to the column
        COMMENT ON COLUMN posts.search_vector IS 'Stores preprocessed text for full-text search with weights: title (A), positions/practitioner (B), position types (C)';
    END IF;
END $$;

-- Step 2: Create the search function if it doesn't exist
CREATE OR REPLACE FUNCTION posts_search_update() RETURNS trigger AS $$
BEGIN
  NEW.search_vector := 
    setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.starting_position, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(NEW.ending_position, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(NEW.starting_top_bottom::text, '')), 'C') ||
    setweight(to_tsvector('english', COALESCE(NEW.ending_top_bottom::text, '')), 'C') ||
    setweight(to_tsvector('english', COALESCE(NEW.practitioner, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(NEW.movement_type, '')), 'B');
  RETURN NEW;
END
$$ LANGUAGE plpgsql;

-- Step 3: Create the trigger, replacing it if it already exists
DROP TRIGGER IF EXISTS posts_search_vector_update ON posts;
CREATE TRIGGER posts_search_vector_update
BEFORE INSERT OR UPDATE ON posts
FOR EACH ROW EXECUTE FUNCTION posts_search_update();

-- Step 4: Create the search index if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_posts_search_vector'
    ) THEN
        CREATE INDEX idx_posts_search_vector ON posts USING gin(search_vector);
    END IF;
END $$;

-- Step 5: Update existing posts with search vectors
UPDATE posts
SET search_vector = 
  setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
  setweight(to_tsvector('english', COALESCE(starting_position, '')), 'B') ||
  setweight(to_tsvector('english', COALESCE(ending_position, '')), 'B') ||
  setweight(to_tsvector('english', COALESCE(starting_top_bottom::text, '')), 'C') ||
  setweight(to_tsvector('english', COALESCE(ending_top_bottom::text, '')), 'C') ||
  setweight(to_tsvector('english', COALESCE(practitioner, '')), 'B') ||
  setweight(to_tsvector('english', COALESCE(movement_type, '')), 'B')
WHERE search_vector IS NULL;

-- Step 6: Add a function for searching posts
CREATE OR REPLACE FUNCTION search_posts(
    search_term TEXT,
    owner_id_filter BIGINT DEFAULT NULL,
    movement_type_filter VARCHAR DEFAULT NULL,
    gi_nogi_filter VARCHAR DEFAULT NULL
) RETURNS TABLE (
    id UUID,
    title VARCHAR,
    username VARCHAR,
    relevance FLOAT,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.title,
        pr.username,
        ts_rank(p.search_vector, q) AS relevance,
        p.created_at
    FROM 
        posts p
    JOIN 
        profiles pr ON p.owner_id = pr.user_id
    CROSS JOIN 
        plainto_tsquery('english', search_term) AS q
    WHERE 
        p.search_vector @@ q
        AND (owner_id_filter IS NULL OR p.owner_id = owner_id_filter)
        AND (movement_type_filter IS NULL OR p.movement_type = movement_type_filter)
        AND (gi_nogi_filter IS NULL OR p.gi_nogi = gi_nogi_filter)
        AND (p.public_status = 'public' OR p.owner_id = owner_id_filter)
    ORDER BY 
        relevance DESC, 
        p.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Add explanatory comment
COMMENT ON FUNCTION search_posts IS 'Function that performs a full-text search on posts with optional filters';