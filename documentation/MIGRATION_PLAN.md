# Migration Plan

## 1. Removing owner_name from posts

This section outlines the steps to migrate from using `owner_name` to `owner_id` in the posts table.

### Overview

Currently, posts are linked to users through a text field `owner_name` which contains the username. This creates referential integrity issues when usernames change. The migration will replace this with a proper foreign key relationship using `owner_id` that references `users.id`.

### Migration Steps

#### 1. Database Migration

Run the migration script in a transaction to ensure atomicity:

```sql
BEGIN;

-- Run the migration script
\i /path/to/convert_owner_name_to_id.sql

-- Verify the migration
SELECT COUNT(*) FROM posts WHERE owner_id IS NULL;
-- Should return 0

COMMIT;
```

#### 2. Backend Code Updates

Update the following Lambda functions:

1. `handleNewPost`: Update to store owner_id instead of owner_name
2. `handleSearch`: Update to join with profiles to get username
3. `handleViewPost`: Update to join with profiles to get username
4. `handleEditPost`: Update ownership check to use owner_id
5. `handleEditProfile`: Remove the code that updates posts.owner_name
6. `handleDeletePost`: Update ownership check to use owner_id

#### 3. Deployment Steps

1. **Create a backup**:
   ```
   pg_dump -U username -d dbname -f backup_before_migration.sql
   ```

2. **Apply database changes**:
   - Run the migration script
   - Verify data integrity after migration

3. **Deploy backend code**:
   - Update Lambda function code with the new handlers
   - Test each endpoint thoroughly

4. **Monitor and rollback plan**:
   - Monitor error rates after deployment
   - If issues occur, restore from backup

### Testing Checklist

- [ ] Creating new posts works correctly
- [ ] Searching posts returns correct owner information
- [ ] Viewing posts shows correct owner information
- [ ] Editing posts works with proper authorization
- [ ] Deleting posts works with proper authorization
- [ ] Changing usernames works without breaking post ownership
- [ ] All API endpoints return correct data structure

### Benefits

1. **Referential Integrity**: Posts are properly linked to users via their stable IDs
2. **Simplified Code**: No need for complex transactions when usernames change
3. **Better Performance**: Joining on integer IDs is faster than text
4. **Proper Normalization**: Follows database design best practices

## 2. Full-Text Search Implementation

### Migration Steps

1. Add the search_vector column to the posts table:
```sql
ALTER TABLE posts ADD COLUMN search_vector tsvector;
```

2. Create a function to update the search vector:
```sql
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
```

3. Create a trigger to automatically update the search_vector:
```sql
CREATE TRIGGER posts_search_vector_update
BEFORE INSERT OR UPDATE ON posts
FOR EACH ROW EXECUTE FUNCTION posts_search_update();
```

4. Create a GIN index on the search_vector column:
```sql
CREATE INDEX idx_posts_search_vector ON posts USING gin(search_vector);
```

5. Populate search_vector for existing rows:
```sql
UPDATE posts
SET search_vector = 
  setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
  setweight(to_tsvector('english', COALESCE(starting_position, '')), 'B') ||
  setweight(to_tsvector('english', COALESCE(ending_position, '')), 'B') ||
  setweight(to_tsvector('english', COALESCE(starting_top_bottom::text, '')), 'C') ||
  setweight(to_tsvector('english', COALESCE(ending_top_bottom::text, '')), 'C') ||
  setweight(to_tsvector('english', COALESCE(practitioner, '')), 'B') ||
  setweight(to_tsvector('english', COALESCE(movement_type, '')), 'B');
```

### Notes on Implementation

- The search_vector column uses PostgreSQL's tsvector type, which stores preprocessed text for full-text search.
- We use setweight to give different weights to different fields:
  - Title (A): Highest priority
  - Starting position, ending position, practitioner, movement type (B): Medium priority
  - Position types (C): Lower priority
- The GIN index enables fast full-text search queries.
- The trigger automatically updates the search_vector column whenever a post is inserted or updated.

### Testing Checklist

- [ ] Search functionality works with single keywords
- [ ] Search functionality works with multiple keywords
- [ ] Search returns results from all searchable fields (title, positions, practitioner, etc.)
- [ ] Results are properly ranked with title matches getting higher priority
- [ ] Performance is acceptable even with large datasets
- [ ] New posts are immediately searchable without manual updates