-- QuantifyJiuJitsu Full-Text Search Functions
-- This file contains functions and triggers for full-text search
-- Last updated: 2025-03-13

-- Function to update the search vector on posts
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

COMMENT ON FUNCTION posts_search_update IS 'Trigger function to update search_vector column with weighted values from multiple fields';

-- Function to search posts with various filters
CREATE OR REPLACE FUNCTION search_posts(
    search_term TEXT,
    owner_id_filter BIGINT DEFAULT NULL,
    movement_type_filter VARCHAR DEFAULT NULL,
    position_filter VARCHAR DEFAULT NULL,
    gi_nogi_filter VARCHAR DEFAULT NULL,
    current_user_id BIGINT DEFAULT NULL,
    sort_by TEXT DEFAULT 'relevance',  -- 'relevance', 'newest', 'oldest'
    limit_count INTEGER DEFAULT 100
) RETURNS TABLE (
    id UUID,
    title VARCHAR,
    username VARCHAR,
    video_id VARCHAR,
    video_platform VARCHAR,
    belt VARCHAR,
    academy VARCHAR,
    avatar_url TEXT,
    movement_type VARCHAR,
    gi_nogi VARCHAR,
    relevance FLOAT,
    created_at TIMESTAMP
) AS $$
DECLARE
    position_query TEXT;
    sort_clause TEXT;
BEGIN
    -- Handle position filtering (check both starting and ending positions)
    IF position_filter IS NOT NULL THEN
        position_query := '(p.starting_position = ' || quote_literal(position_filter) || 
                          ' OR p.ending_position = ' || quote_literal(position_filter) || ')';
    ELSE
        position_query := 'TRUE';
    END IF;
    
    -- Determine sorting based on user preference
    IF sort_by = 'newest' THEN
        sort_clause := 'p.created_at DESC';
    ELSIF sort_by = 'oldest' THEN
        sort_clause := 'p.created_at ASC';
    ELSE  -- Default to relevance-based sorting
        sort_clause := 'ts_rank(p.search_vector, q) DESC, p.created_at DESC';
    END IF;
    
    -- Build and execute the query
    RETURN QUERY EXECUTE 
    'SELECT 
        p.id,
        p.title,
        pr.username,
        p.video_id,
        p.video_platform,
        pr.belt,
        pr.academy,
        pr.avatar_url,
        p.movement_type,
        p.gi_nogi,
        ts_rank(p.search_vector, q) AS relevance,
        p.created_at
    FROM 
        posts p
    JOIN 
        profiles pr ON p.owner_id = pr.user_id
    CROSS JOIN 
        plainto_tsquery(''english'', $1) AS q
    WHERE 
        ($1 = '''' OR p.search_vector @@ q)
        AND ($2 IS NULL OR p.owner_id = $2)
        AND ($3 IS NULL OR p.movement_type = $3)
        AND ' || position_query || '
        AND ($4 IS NULL OR p.gi_nogi = $4)
        AND (p.public_status = ''public'' 
             OR (p.public_status = ''subscribers'' AND $5 IS NOT NULL)
             OR (p.owner_id = $5))
    ORDER BY ' || sort_clause || '
    LIMIT $6'
    USING 
        search_term,
        owner_id_filter,
        movement_type_filter,
        gi_nogi_filter,
        current_user_id,
        limit_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION search_posts IS 'Advanced full-text search for posts with multiple filters and optional ranking';

-- Function to get similar posts based on a post ID
CREATE OR REPLACE FUNCTION get_similar_posts(
    post_id UUID,
    max_results INTEGER DEFAULT 5
) RETURNS TABLE (
    id UUID,
    title VARCHAR,
    username VARCHAR,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    WITH source_post AS (
        SELECT search_vector
        FROM posts
        WHERE id = post_id
    )
    SELECT 
        p.id,
        p.title,
        pr.username,
        ts_rank(p.search_vector, to_tsquery('english', 
            array_to_string(
                array(
                    SELECT lexeme
                    FROM ts_stat('SELECT search_vector FROM source_post')
                    ORDER BY ndoc DESC, nentry DESC 
                    LIMIT 5
                ),
                ' | '
            )
        )) AS similarity
    FROM 
        posts p
    JOIN 
        profiles pr ON p.owner_id = pr.user_id
    WHERE 
        p.id != post_id
        AND p.public_status = 'public'
    ORDER BY 
        similarity DESC
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_similar_posts IS 'Returns similar posts based on text content overlap';