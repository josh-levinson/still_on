# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Product Overview

**StillOn** is a social coordination app that solves adult friend group entropy — the slow death of recurring hangouts due to coordination friction. The app keeps plans alive by automating "Still on?" reminders, tracking RSVPs, and reducing the organizational burden on whoever is running the group.

### Core loop
1. An organizer creates a hangout (name, date, cadence)
2. They share an invite link with their friend group
3. StillOn sends an SMS reminder before each occurrence ("Still on for Friday?")
4. Friends RSVP via the link — no account required
5. The organizer sees who's in

### Who the users are
- **Organizers** are the only people who need an account. There's roughly one per friend group.
- **Guests** are the majority of people who touch the app. They receive a text, tap a link, and RSVP. They never sign up. Optimize heavily for this experience — it must be fast, mobile-friendly, and require zero friction.

### Key product decisions
- Phone number + SMS verification for organizer signup (no password)
- Guest RSVPs via signed token links — no account required
- Guests can optionally claim a full account later
- The RSVP page is the most important surface in the app — most people only ever see this
- Reminder timing: 2 days before each occurrence via SMS

---

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

---

## Architecture

### Data Model

The application is built around a hierarchical event management system:

**Groups → Events → EventOccurrences → RSVPs**

- **Users**: Authenticated via phone number + SMS OTP (Devise was removed). Fields: first_name, last_name, username, avatar_url, phone_number, phone_verified_at. Only organizers have accounts.
- **Groups**: Collections of members (id: uuid, slug: unique, is_private flag, created_by references Users)
- **Events**: Templates/series belonging to Groups. Can be recurring (recurrence_type: none/daily/weekly/monthly, recurrence_rule stores pattern)
- **EventOccurrences**: Specific instances of Events (start_time, end_time, status: scheduled/cancelled/completed, max_attendees). Can override parent Event's location.
- **RSVPs**: Responses scoped to specific EventOccurrences, not Events — enables per-instance attendance tracking (status: attending/declined/maybe, guest_count for +1s)
- **GroupMemberships**: Join table connecting Users to Groups

All core domain tables use UUID primary keys for scalability and security.

### Guest RSVP flow (no account required)
Guests receive a signed token link. The token encodes the EventOccurrence and optionally a phone number. RSVPs from guests are stored with a lightweight guest record that can be claimed/merged if they later create an account. This is the primary interaction path for most people who use the app.

### Organizer auth flow
Organizers sign up (or sign in) via phone number + SMS OTP. The onboarding wizard collects first name, hangout name, date, and cadence — then creates the User, Group, Event, and first EventOccurrence in one step. Returning users sign in through the same phone/verify flow at `/onboarding/phone`.

### Background jobs
Two jobs run on a daily cron schedule (configured in `config/recurring.yml`):
- `GenerateRecurringOccurrencesJob` — runs at 6am, generates EventOccurrence records for recurring events up to 30 days out
- `ScheduleNotificationsJob` — runs at 8am, enqueues SMS reminders: RSVP prompts 2 days before each occurrence (to non-RSVPd members), and day-of confirmations to attending/maybe guests

### Public vs. private groups
Groups have an `is_private` flag. Public groups are browsable via `/groups/discover`. Private group show pages are restricted to members.

### Rails Stack

- **Rails 8.1** with modern defaults
- **Solid Cache**: Database-backed caching (instead of Redis)
- **Solid Queue**: Database-backed job processing (instead of Sidekiq)
- **Solid Cable**: Database-backed Action Cable (instead of Redis)
- **PostgreSQL**: Database
- **Hotwire**: Turbo + Stimulus for frontend interactivity
- **Propshaft**: Asset pipeline
- **IceCube**: Recurrence scheduling for recurring events
- **Twilio**: SMS delivery for OTP auth and event reminders
- **Kamal**: Deployment via Docker
- **Thruster**: HTTP caching/compression for Puma

### Testing

- Uses standard Rails minitest
- Tests run in parallel (`:number_of_processors`)
- System tests available via Capybara + Selenium

---

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

---

## Code Style

Follows **rubocop-rails-omakase** conventions. The `.rubocop.yml` inherits from the omakase gem with minimal overrides.

---

## Known Issues

### UUID type detection with PostgreSQL
Migrations use `type: :uuid` for foreign keys, but `db/schema.rb` shows "Unknown type 'uuid'" warnings. The tables and constraints are correct in the database — this is a schema dumper rendering issue only.
