# StillOn

A social coordination app that keeps recurring friend group hangouts alive. StillOn automates "Still on?" reminders, tracks RSVPs, and reduces the friction on whoever's organizing.

## How it works

1. An organizer creates a hangout (name, date, cadence)
2. They share an invite link with their friend group
3. StillOn sends an SMS reminder 2 days before each occurrence
4. Friends RSVP via the link — no account required
5. The organizer sees who's in

## Tech Stack

- **Ruby 3.4.2** / **Rails 8.1**
- **PostgreSQL**
- **Hotwire** (Turbo + Stimulus)
- **Solid Cache / Queue / Cable** — database-backed caching, jobs, and WebSockets (no Redis)
- **Twilio** — SMS for auth OTP and event reminders
- **IceCube** — recurrence scheduling
- **Propshaft** — asset pipeline
- **Thruster** — HTTP caching/compression for Puma

## Prerequisites

- Ruby 3.4.2+
- PostgreSQL

## Getting Started

```bash
# Clone the repository
git clone <repository-url>
cd still_on

# Run the setup script
bin/setup
```

Then visit http://localhost:3000.

## Development

### Running the app

```bash
bin/dev              # Start server with all services
bin/rails server     # Rails only
```

### Database

```bash
bin/rails db:migrate         # Run pending migrations
bin/rails db:rollback        # Rollback last migration
bin/rails db:seed            # Seed database
bin/rails db:seed:replant    # Drop, create, migrate, and seed
```

### Tests

```bash
bin/rails test                              # Run all tests
bin/rails test test/models/user_test.rb     # Run specific file
bin/ci                                      # Full CI suite
```

Tests run in parallel using all available processors. To find uncovered lines after a run, read `coverage/.resultset.json`.

### Code Quality

```bash
bin/rubocop           # Run RuboCop linter
bin/rubocop -a        # Auto-correct violations
bin/brakeman          # Security analysis
bin/bundler-audit     # Check for vulnerable gems
bin/importmap audit   # Check JavaScript dependencies
```

### CI Pipeline

`bin/ci` runs:
1. Setup (without server)
2. RuboCop
3. Bundler audit
4. Importmap audit
5. Brakeman
6. Rails test suite
7. Seed replanting test

## Architecture

### Data Model

**Groups → Events → EventOccurrences → RSVPs**

- **Users** — organizers only; authenticated via phone number + SMS OTP (no password). Fields: first_name, last_name, username, avatar_url, phone_number, phone_verified_at
- **Groups** — collections of members (UUID pk, unique slug, is_private flag)
- **Events** — templates/series belonging to groups; store recurrence pattern (none/daily/weekly/monthly)
- **EventOccurrences** — specific instances of events (start_time, end_time, status: scheduled/cancelled/completed, max_attendees)
- **RSVPs** — scoped to occurrences, not events (status: attending/declined/maybe, guest_count)
- **GroupMemberships** — join table connecting users to groups

All core domain tables use UUID primary keys.

### Auth

Organizers sign up and sign in via phone number + SMS OTP — no password. Onboarding collects name, hangout name, date, and cadence, then creates the User, Group, Event, and first EventOccurrence in one step.

### Guest RSVP flow

Guests receive a signed token link encoding the EventOccurrence and optionally their phone number. They RSVP without an account. Guest records can be claimed/merged if they later create an account. This is the primary interaction path for most people.

### Background Jobs

Two jobs run on a daily cron schedule (`config/recurring.yml`):
- `GenerateRecurringOccurrencesJob` — 6am, generates occurrences up to 30 days out
- `ScheduleNotificationsJob` — 8am, enqueues RSVP prompts 2 days before each occurrence and day-of confirmations to attending/maybe guests

## Known Issues

- **UUID schema dumping**: `db/schema.rb` shows "Unknown type 'uuid'" warnings for UUID foreign keys. The tables and constraints are correct in the database — this is a schema dumper rendering issue only.

## License

[Specify your license here]
