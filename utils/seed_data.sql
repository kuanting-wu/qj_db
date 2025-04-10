-- Sample Data for Testing and Development
-- This script inserts test data for local development purposes
-- Last updated: 2025-03-13

-- Start transaction
BEGIN;

-- Insert sample users
INSERT INTO users (id, email, hashed_password, email_verified, created_at) VALUES
(1, 'john@example.com', '$2a$12$1234567890123456789012uGsvPvqrRnJA.pRXLm3hPKbRrBZ80LO', TRUE, NOW() - INTERVAL '90 days'),
(2, 'jane@example.com', '$2a$12$1234567890123456789012uRtKqbJYG1rLTiLJYlWBYHvA3JmqbWm', TRUE, NOW() - INTERVAL '60 days'),
(3, 'carlos@example.com', '$2a$12$1234567890123456789012uaqPKGKAFUz9G5P3PG5xTb3VK.vw5pi', TRUE, NOW() - INTERVAL '30 days')
ON CONFLICT (id) DO NOTHING;

-- Insert sample profiles
INSERT INTO profiles (user_id, username, belt, academy, avatar_url, created_at) VALUES
(1, 'johndoe', 'Black', 'Gracie Academy', 'https://example.com/avatar1.jpg', NOW() - INTERVAL '90 days'),
(2, 'janedoe', 'Purple', 'AOJ', 'https://example.com/avatar2.jpg', NOW() - INTERVAL '60 days'),
(3, 'carlosjr', 'Brown', 'B-Team', 'https://example.com/avatar3.jpg', NOW() - INTERVAL '30 days')
ON CONFLICT (user_id) DO NOTHING;

-- Insert sample posts
INSERT INTO posts (id, title, video_id, video_platform, owner_id, movement_type, starting_position, 
                  ending_position, starting_top_bottom, ending_top_bottom, gi_nogi, practitioner,
                  public_status, created_at) VALUES
(uuid_generate_v4(), 'Deep Half Guard Sweep', 'abc123', 'YouTube', 1, 'Sweep', 'Deep Half Guard', 
 'Top Side Control', 'BOTTOM', 'TOP', 'Gi', 'Bernardo Faria', 'public', NOW() - INTERVAL '14 days'),
(uuid_generate_v4(), 'Butterfly Guard Pass', 'def456', 'YouTube', 2, 'Pass', 'Butterfly Guard', 
 'Side Control', 'TOP', 'TOP', 'No-Gi', 'Gordon Ryan', 'public', NOW() - INTERVAL '10 days'),
(uuid_generate_v4(), 'Triangle from Guard', 'ghi789', 'YouTube', 3, 'Submission', 'Closed Guard', 
 'Submission Finish', 'BOTTOM', 'BOTTOM', 'Gi', 'Roger Gracie', 'public', NOW() - INTERVAL '7 days'),
(uuid_generate_v4(), 'Leg Lock Entry from 50/50', 'jkl012', 'YouTube', 2, 'Submission', '50/50 Guard', 
 'Submission Finish', 'NEUTRAL', 'BOTTOM', 'No-Gi', 'Craig Jones', 'public', NOW() - INTERVAL '5 days'),
(uuid_generate_v4(), 'Berimbolo Technique', 'mno345', 'YouTube', 1, 'Sweep', 'De La Riva Guard', 
 'Back Control', 'BOTTOM', 'TOP', 'Gi', 'Mikey Musumeci', 'public', NOW() - INTERVAL '3 days'),
(uuid_generate_v4(), 'Anaconda Choke Setup', 'pqr678', 'YouTube', 3, 'Submission', 'Front Headlock', 
 'Submission Finish', 'TOP', 'TOP', 'No-Gi', 'Marcelo Garcia', 'public', NOW() - INTERVAL '1 day')
ON CONFLICT DO NOTHING;

-- Update search vectors for all posts
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

-- Commit the changes
COMMIT;

-- Verify data insertion
SELECT 'Users count: ' || COUNT(*)::text AS users_count FROM users;
SELECT 'Profiles count: ' || COUNT(*)::text AS profiles_count FROM profiles;
SELECT 'Posts count: ' || COUNT(*)::text AS posts_count FROM posts;