-- Game Plan Feature Schema Migration
-- This migration adds the game plan feature tables and functions
-- Last updated: 2025-03-13

-- Create position_type enum if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'position_type') THEN
        CREATE TYPE position_type AS ENUM ('TOP', 'BOTTOM', 'NEUTRAL');
    END IF;
END$$;

-- Create game_plans table
CREATE TABLE IF NOT EXISTS game_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- Foreign key to users table
    name VARCHAR(63) NOT NULL,
    description TEXT,
    language VARCHAR(30) CHECK (language IN ('English', 'Japanese', 'Traditional Chinese')) DEFAULT 'English',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    public_status VARCHAR(20) CHECK (public_status IN ('public', 'private', 'subscribers')) DEFAULT 'public'  -- Added public_status column
);

SELECT * FROM game_plans;


-- Add index for fast lookup by user
CREATE INDEX IF NOT EXISTS idx_game_plans_owner_id ON game_plans(owner_id);

-- Create nodes table (positions)
CREATE TABLE IF NOT EXISTS nodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    position VARCHAR(63) UNIQUE NOT NULL,
    top_bottom position_type DEFAULT 'NEUTRAL',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create edges table (transitions)
CREATE TABLE IF NOT EXISTS edges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_position VARCHAR(63) NOT NULL,
    to_position VARCHAR(63) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (from_position) REFERENCES nodes(position) ON DELETE CASCADE,
    FOREIGN KEY (to_position) REFERENCES nodes(position) ON DELETE CASCADE,
    UNIQUE(from_position, to_position)
);

-- Create game_plan_posts table (relating posts to game plans)
CREATE TABLE IF NOT EXISTS game_plan_posts (
    game_plan_id UUID NOT NULL,
    post_id UUID NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    PRIMARY KEY (game_plan_id, post_id),
    FOREIGN KEY (game_plan_id) REFERENCES game_plans(id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
);

-- Add index for fast lookup by game plan
CREATE INDEX IF NOT EXISTS idx_game_plan_posts_game_plan_id ON game_plan_posts(game_plan_id);

-- Add index for fast lookup by post
CREATE INDEX IF NOT EXISTS idx_game_plan_posts_post_id ON game_plan_posts(post_id);

-- Create function for automatic node and edge creation when posts are added
CREATE OR REPLACE FUNCTION create_nodes_and_edges_for_post()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert starting position node if it doesn't exist
    INSERT INTO nodes (position, top_bottom)
    VALUES (NEW.starting_position, NEW.starting_top_bottom)
    ON CONFLICT (position) DO NOTHING;
    
    -- Insert ending position node if it doesn't exist
    INSERT INTO nodes (position, top_bottom)
    VALUES (NEW.ending_position, NEW.ending_top_bottom)
    ON CONFLICT (position) DO NOTHING;
    
    -- If starting and ending positions are different, create an edge
    IF NEW.starting_position <> NEW.ending_position THEN
        INSERT INTO edges (from_position, to_position)
        VALUES (NEW.starting_position, NEW.ending_position)
        ON CONFLICT (from_position, to_position) DO NOTHING;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create or replace the trigger
DROP TRIGGER IF EXISTS after_post_insert_update ON posts;
CREATE TRIGGER after_post_insert_update
AFTER INSERT OR UPDATE ON posts
FOR EACH ROW
EXECUTE FUNCTION create_nodes_and_edges_for_post();

-- Insert initial data for commonly used positions
INSERT INTO nodes (position, top_bottom)
VALUES 
    ('Closed Guard', 'BOTTOM'),
    ('Half Guard', 'BOTTOM'),
    ('Open Guard', 'BOTTOM'),
    ('Side Control', 'TOP'),
    ('Mount', 'TOP'),
    ('Back Control', 'TOP'),
    ('Standing', 'NEUTRAL'),
    ('Turtle', 'BOTTOM')
ON CONFLICT (position) DO NOTHING;

-- Function to get all available positions for a user
CREATE OR REPLACE FUNCTION get_available_positions(
    user_id_param BIGINT
)
RETURNS TABLE (
    position VARCHAR,
    top_bottom position_type,
    count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.position,
        n.top_bottom,
        COUNT(p.id) AS count
    FROM 
        nodes n
    LEFT JOIN 
        posts p ON (p.starting_position = n.position OR p.ending_position = n.position)
                   AND (p.public_status = 'public' OR p.owner_id = user_id_param)
    GROUP BY 
        n.position, n.top_bottom
    ORDER BY 
        count DESC, n.position;
END;
$$ LANGUAGE plpgsql;

-- Function to get all transitions (edges) with post counts
CREATE OR REPLACE FUNCTION get_position_transitions(
    user_id_param BIGINT
)
RETURNS TABLE (
    from_position VARCHAR,
    from_top_bottom position_type,
    to_position VARCHAR,
    to_top_bottom position_type,
    count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.from_position,
        n1.top_bottom AS from_top_bottom,
        e.to_position,
        n2.top_bottom AS to_top_bottom,
        COUNT(p.id) AS count
    FROM 
        edges e
    JOIN 
        nodes n1 ON e.from_position = n1.position
    JOIN 
        nodes n2 ON e.to_position = n2.position
    LEFT JOIN 
        posts p ON p.starting_position = e.from_position 
               AND p.ending_position = e.to_position
               AND (p.public_status = 'public' OR p.owner_id = user_id_param)
    GROUP BY 
        e.from_position, e.to_position, n1.top_bottom, n2.top_bottom
    ORDER BY 
        count DESC, e.from_position, e.to_position;
END;
$$ LANGUAGE plpgsql;

-- Add explanatory comments
COMMENT ON TABLE game_plans IS 'Stores user-created game plans with collections of BJJ techniques in a specific sequence';
COMMENT ON TABLE nodes IS 'Represents BJJ positions (nodes in the position graph)';
COMMENT ON TABLE edges IS 'Represents transitions between BJJ positions (edges in the position graph)';
COMMENT ON TABLE game_plan_posts IS 'Junction table linking posts to game plans';
COMMENT ON FUNCTION create_nodes_and_edges_for_post() IS 'Automatically creates position nodes and transitions when posts are added or updated';
COMMENT ON FUNCTION get_available_positions(BIGINT) IS 'Returns all positions with counts of available techniques for each position';
COMMENT ON FUNCTION get_position_transitions(BIGINT) IS 'Returns all transitions between positions with counts of available techniques';