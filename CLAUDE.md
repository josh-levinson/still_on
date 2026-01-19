# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"Still On" is a Rails 8.1 application for managing recurring group events with RSVP functionality. The application uses Devise for authentication and follows Rails Omakase conventions.

## Development Commands

### Setup
```bash
bin/setup                    # Initial setup
bin/setup --skip-server      # Setup without starting server (used in CI)
```

### Running the Application
```bash
bin/dev                      # Start development server with all services
bin/rails server             # Start Rails server only
```

### Testing
```bash
bin/rails test               # Run all tests
bin/rails test test/models/user_test.rb  # Run single test file
bin/ci                       # Run full CI suite locally
```

### Code Quality
```bash
bin/rubocop                  # Run RuboCop linter
bin/rubocop -a               # Auto-correct RuboCop violations
bin/brakeman                 # Run security analysis
bin/bundler-audit            # Check for vulnerable gems
bin/importmap audit          # Check importmap for vulnerabilities
```

### Database
```bash
bin/rails db:migrate         # Run migrations
bin/rails db:rollback        # Rollback last migration
bin/rails db:seed            # Seed database
bin/rails db:seed:replant    # Drop, create, migrate, and seed
```

## Architecture

### Data Model

The application is built around a hierarchical event management system:

**Groups → Events → Event Occurrences → RSVPs**

- **Users**: Authenticated via Devise with username, email, first_name, last_name, avatar_url
- **Groups**: Collections of members (id: uuid, slug: unique, is_private flag, created_by references Users)
- **Events**: Belong to Groups, can be recurring (recurrence_type: none/daily/weekly/monthly, recurrence_rule stores pattern)
- **EventOccurrences**: Specific instances of Events (start_time, end_time, status: scheduled/cancelled/completed, max_attendees)
- **RSVPs**: User responses to EventOccurrences (status: attending/declined/maybe, guest_count)
- **GroupMemberships**: Join table connecting Users to Groups

All core domain tables (Groups, Events, EventOccurrences, RSVPs) use UUID primary keys for scalability and security.

### Key Relationships

- Events have a `recurrence_type` that determines if they repeat, and a `recurrence_rule` for storing the pattern
- EventOccurrences can override the parent Event's location
- RSVPs are scoped to specific EventOccurrences, not Events (allowing per-instance attendance tracking)
- Users can have guest_count in RSVPs for "+1" functionality

### Rails Stack

- **Rails 8.1** with modern defaults
- **Solid Cache**: Database-backed caching (instead of Redis)
- **Solid Queue**: Database-backed job processing (instead of Sidekiq)
- **Solid Cable**: Database-backed Action Cable (instead of Redis)
- **SQLite3**: Database (2.1+)
- **Hotwire**: Turbo + Stimulus for frontend interactivity
- **Propshaft**: Asset pipeline
- **Devise**: Authentication
- **Kamal**: Deployment via Docker
- **Thruster**: HTTP caching/compression for Puma

### Testing

- Uses standard Rails minitest
- Tests run in parallel (`:number_of_processors`)
- System tests available via Capybara + Selenium

## CI Pipeline

The CI pipeline (`bin/ci`) runs:
1. Setup (without server)
2. RuboCop style checks
3. Bundler audit (gem security)
4. Importmap audit (JS security)
5. Brakeman (static security analysis)
6. Rails tests
7. Seed replanting test

All steps must pass for CI to succeed.

## Code Style

Follows **rubocop-rails-omakase** conventions. The `.rubocop.yml` inherits from the omakase gem with minimal overrides.

## Database Schema Issue

The schema currently has UUID type detection issues with SQLite3. The migrations use `type: :uuid` for foreign keys, but `db/schema.rb` shows "Unknown type 'uuid'" errors. This is a known SQLite UUID configuration issue that needs resolution for proper schema dumping.
