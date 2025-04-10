-- Create a table to store YouTube authentication tokens for users
CREATE TABLE IF NOT EXISTS youtube_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    token_type VARCHAR(20),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Create an index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_youtube_tokens_user_id ON youtube_tokens(user_id);

-- Create a function to update the 'updated_at' timestamp
CREATE OR REPLACE FUNCTION update_youtube_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to automatically update 'updated_at' on record update
DROP TRIGGER IF EXISTS update_youtube_tokens_updated_at ON youtube_tokens;
CREATE TRIGGER update_youtube_tokens_updated_at
BEFORE UPDATE ON youtube_tokens
FOR EACH ROW
EXECUTE FUNCTION update_youtube_tokens_updated_at();

COMMENT ON TABLE youtube_tokens IS 'Stores YouTube OAuth tokens for authenticated users';
COMMENT ON COLUMN youtube_tokens.user_id IS 'Reference to the users table';
COMMENT ON COLUMN youtube_tokens.access_token IS 'The OAuth access token for YouTube API';
COMMENT ON COLUMN youtube_tokens.refresh_token IS 'The refresh token used to get new access tokens';
COMMENT ON COLUMN youtube_tokens.token_type IS 'Type of token, usually "Bearer"';
COMMENT ON COLUMN youtube_tokens.expires_at IS 'When the access token expires';

