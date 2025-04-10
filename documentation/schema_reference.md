# QuantifyJiuJitsu Database Schema Reference

This document provides comprehensive reference information about the database schema for the QuantifyJiuJitsu application.

## Core Tables

### Table: users

Stores core user authentication data.

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| id | BIGSERIAL | Primary key | PRIMARY KEY |
| email | VARCHAR(255) | User's email address | NOT NULL, UNIQUE |
| hashed_password | VARCHAR(255) | Bcrypt hashed password | NULL for OAuth users |
| google_id | VARCHAR(255) | Google OAuth ID | UNIQUE, NULL for password users |
| email_verified | BOOLEAN | Whether email is verified | DEFAULT FALSE |
| verification_token | VARCHAR(255) | Email verification token | NULL |
| verification_token_expiry | TIMESTAMP | When token expires | NULL |
| reset_token | VARCHAR(255) | Password reset token | NULL |
| reset_token_expiry | TIMESTAMP | When reset token expires | NULL |
| created_at | TIMESTAMP | Account creation time | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMP | Account update time | DEFAULT CURRENT_TIMESTAMP |

**Indexes**:
- PRIMARY KEY on `id`
- UNIQUE INDEX on `email`
- INDEX on `verification_token` (partial, where not null)

### Table: profiles

Stores user profile information.

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| user_id | BIGINT | References users.id | PRIMARY KEY, FOREIGN KEY |
| username | VARCHAR(50) | User's display name | NOT NULL, UNIQUE |
| name | VARCHAR(100) | User's real name | NULL |
| belt | VARCHAR(20) | BJJ belt rank | NULL |
| academy | VARCHAR(100) | BJJ academy/school | NULL |
| bio | TEXT | User biography | NULL |
| location | VARCHAR(100) | User location | NULL |
| nationality | VARCHAR(50) | User nationality | NULL |
| weight_class | VARCHAR(30) | Competition weight class | NULL |
| height | VARCHAR(30) | User height | NULL |
| date_of_birth | DATE | User DOB | NULL |
| social_links | JSONB | Social media links | NULL |
| achievements | TEXT | Competitions/achievements | NULL |
| website_url | VARCHAR(255) | Personal website | NULL |
| contact_email | VARCHAR(255) | Public contact email | NULL |
| avatar_url | TEXT | Profile image URL | NULL |
| created_at | TIMESTAMP | Profile creation time | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMP | Profile update time | DEFAULT CURRENT_TIMESTAMP |

**Indexes**:
- PRIMARY KEY on `user_id`
- UNIQUE INDEX on `username`

### Table: posts

Stores BJJ technique posts.

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| id | UUID | Primary key | PRIMARY KEY |
| title | VARCHAR(63) | Post title | NOT NULL |
| video_id | VARCHAR(30) | Video identifier | NOT NULL |
| video_platform | VARCHAR(10) | Video hosting platform | NOT NULL |
| owner_id | BIGINT | References users.id | NOT NULL, FOREIGN KEY |
| movement_type | VARCHAR(50) | Type of movement | NULL |
| starting_position | VARCHAR(50) | Starting position name | NULL |
| ending_position | VARCHAR(50) | Ending position name | NULL |
| starting_top_bottom | position_type | Starting position type | ENUM('TOP','BOTTOM','NEUTRAL') |
| ending_top_bottom | position_type | Ending position type | ENUM('TOP','BOTTOM','NEUTRAL') |
| gi_nogi | VARCHAR(10) | Gi, No-Gi, or Both | DEFAULT 'Gi' |
| practitioner | VARCHAR(100) | Featured practitioner | NULL |
| sequence_start_time | VARCHAR(10) | Video start time | NULL |
| public_status | VARCHAR(20) | Visibility setting | CHECK IN ('public','private','subscribers') |
| language | VARCHAR(30) | Content language | CHECK IN ('English','Japanese','Traditional Chinese') |
| notes_path | TEXT | Path to notes in S3 | NULL |
| search_vector | tsvector | Full-text search index | NULL |
| created_at | TIMESTAMP | Post creation time | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMP | Post update time | DEFAULT CURRENT_TIMESTAMP |

**Indexes**:
- PRIMARY KEY on `id`
- INDEX on `owner_id`
- INDEX on `movement_type`
- INDEX on `gi_nogi`
- INDEX on `public_status`
- GIN INDEX on `search_vector`

## Game Plan Feature Tables

### Table: game_plans

Stores user-created game plans with collections of BJJ techniques.

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| id | UUID | Primary key | PRIMARY KEY |
| user_id | BIGINT | References users.id | NOT NULL, FOREIGN KEY |
| name | VARCHAR(63) | Game plan name | NOT NULL |
| description | TEXT | Game plan description | NULL |
| created_at | TIMESTAMP | Creation time | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMP | Update time | DEFAULT CURRENT_TIMESTAMP |

**Indexes**:
- PRIMARY KEY on `id`
- INDEX on `user_id`

### Table: nodes

Represents BJJ positions (nodes in the position graph).

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| id | UUID | Primary key | PRIMARY KEY |
| position | VARCHAR(63) | Position name | NOT NULL, UNIQUE |
| top_bottom | position_type | Position type | ENUM('TOP','BOTTOM','NEUTRAL') |
| created_at | TIMESTAMP | Creation time | DEFAULT CURRENT_TIMESTAMP |

**Indexes**:
- PRIMARY KEY on `id`
- UNIQUE INDEX on `position`

### Table: edges

Represents transitions between BJJ positions (edges in the position graph).

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| id | UUID | Primary key | PRIMARY KEY |
| from_position | VARCHAR(63) | Starting position | NOT NULL, FOREIGN KEY |
| to_position | VARCHAR(63) | Ending position | NOT NULL, FOREIGN KEY |
| created_at | TIMESTAMP | Creation time | DEFAULT CURRENT_TIMESTAMP |

**Indexes**:
- PRIMARY KEY on `id`
- UNIQUE INDEX on `(from_position, to_position)`

### Table: game_plan_posts

Junction table linking posts to game plans.

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| game_plan_id | UUID | References game_plans.id | NOT NULL, FOREIGN KEY |
| post_id | UUID | References posts.id | NOT NULL, FOREIGN KEY |
| added_at | TIMESTAMP | When added to game plan | DEFAULT CURRENT_TIMESTAMP |
| notes | TEXT | User notes about this technique in this game plan | NULL |

**Indexes**:
- PRIMARY KEY on `(game_plan_id, post_id)`
- INDEX on `game_plan_id`
- INDEX on `post_id`

## Views and Functions

### View: posts_with_owner

Joins posts with profile information for convenience.

```sql
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
```

### Function: create_nodes_and_edges_for_post()

Automatically creates position nodes and transitions when posts are added or updated.

```sql
CREATE FUNCTION create_nodes_and_edges_for_post() RETURNS TRIGGER
```

Trigger: `AFTER INSERT OR UPDATE ON posts`

### Function: get_available_positions()

Returns all positions with counts of available techniques for each position.

```sql
CREATE FUNCTION get_available_positions(user_id_param BIGINT)
RETURNS TABLE (
    position VARCHAR,
    top_bottom position_type,
    count BIGINT
)
```

### Function: get_position_transitions()

Returns all transitions between positions with counts of available techniques.

```sql
CREATE FUNCTION get_position_transitions(user_id_param BIGINT)
RETURNS TABLE (
    from_position VARCHAR,
    from_top_bottom position_type,
    to_position VARCHAR,
    to_top_bottom position_type,
    count BIGINT
)
```

## Full-Text Search

The posts table includes full-text search capabilities through:

1. `search_vector` column of type `tsvector`
2. Automatic indexing triggered by `posts_search_vector_update` function
3. Different weights for different fields:
   - Title (A) - highest priority
   - Starting/ending positions, practitioner, movement type (B) - medium priority
   - Position types (C) - lower priority

### Function: search_posts()

Performs a full-text search on posts with optional filters.

```sql
CREATE FUNCTION search_posts(
    search_term TEXT,
    owner_id_filter BIGINT DEFAULT NULL,
    movement_type_filter VARCHAR DEFAULT NULL,
    gi_nogi_filter VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    title VARCHAR,
    username VARCHAR,
    relevance FLOAT,
    created_at TIMESTAMP
)
```

## Security

Database security is implemented through:

1. Password hashing at application layer (not stored in plaintext)
2. Foreign key constraints to maintain referential integrity
3. Limited access database user (`lambda_user`) for application connections
4. Row-level security implemented at application layer