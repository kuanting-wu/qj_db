# QuantifyJiuJitsu Database Changelog

## 2025-03-14: Game Plan Feature Implementation

### Added
- Game plan functionality for organizing BJJ techniques
  - `game_plans` table for storing user-created training plans
  - `nodes` table for representing BJJ positions
  - `edges` table for representing transitions between positions
  - `game_plan_posts` junction table linking posts to game plans
- Automatic position graph generation from post data
  - Trigger to create nodes and edges when posts are created/updated
- Helper functions for querying position data
  - `get_available_positions` for finding all available positions
  - `get_position_transitions` for finding all transitions between positions
- Initial data for common BJJ positions (closed guard, mount, etc.)
- Backend Lambda handlers for all game plan operations
- Comprehensive API for managing game plans

### Changed
- Updated schema reference documentation to include game plan tables
- Enhanced database scripts with additional indexes for game plan queries
- Expanded API routes to support game plan operations

## 2025-03-13: Full-Text Search Implementation & Database Reorganization

### Added
- Full-text search capabilities for posts table
- Search vector column with weighted indexing (title, positions, practitioner)
- GIN index for efficient search querying
- Automatic vector updates via database triggers
- Advanced search functions with relevance ranking
- Similar posts functionality based on content

### Changed
- Reorganized database scripts into logical directories
- Added comprehensive documentation
- Created setup scripts for easier initialization
- Added test database reset script for development
- Enhanced schema with better comments and constraints

### Fixed
- Added better error handling in database scripts
- Improved SQL syntax for compatibility

## 2025-02-20: Owner Name to ID Migration

### Changed
- Migrated posts from using owner_name to owner_id
- Added foreign key constraint to users table
- Created compatibility view for backward compatibility
- Added proper indexes for performance

### Fixed
- Fixed referential integrity issue with username changes
- Improved query performance with integer join keys