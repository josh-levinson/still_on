# Still On

A Rails 8.1 application for managing recurring group events with RSVP functionality. Built with modern Rails conventions and the Hotwire stack.

## Features

- **Group Management**: Create private or public groups with unique slugs
- **Recurring Events**: Support for daily, weekly, monthly, and one-time events
- **Event Occurrences**: Individual instances of recurring events with independent management
- **RSVP System**: Per-occurrence attendance tracking with guest counts
- **User Authentication**: Powered by Devise with username and profile support

## Tech Stack

- **Ruby 3.4.2**
- **Rails 8.1.2**
- **SQLite3** (2.1+)
- **Hotwire** (Turbo + Stimulus)
- **Solid Cache** - Database-backed caching
- **Solid Queue** - Database-backed job processing
- **Solid Cable** - Database-backed Action Cable
- **Devise** - User authentication
- **Propshaft** - Asset pipeline
- **Kamal** - Docker-based deployment
- **Thruster** - HTTP caching/compression for Puma

## Prerequisites

- Ruby 3.4.2+
- SQLite3 2.1+
- Node.js (for JavaScript bundling)

## Getting Started

### Initial Setup

```bash
# Clone the repository
git clone <repository-url>
cd still_on

# Run the setup script
bin/setup
```

The setup script will:
- Install dependencies
- Create and migrate the database
- Seed initial data

### Running the Application

```bash
# Start the development server with all services
bin/dev

# Or start just the Rails server
bin/rails server
```

Visit http://localhost:3000 to see the application.

## Development

### Database Commands

```bash
bin/rails db:migrate         # Run pending migrations
bin/rails db:rollback        # Rollback last migration
bin/rails db:seed            # Seed database with sample data
bin/rails db:seed:replant    # Drop, create, migrate, and seed
```

### Running Tests

```bash
bin/rails test                              # Run all tests
bin/rails test test/models/user_test.rb     # Run specific test file
bin/ci                                      # Run full CI suite locally
```

Tests run in parallel using all available processors.

### Code Quality

The project follows **rubocop-rails-omakase** conventions.

```bash
bin/rubocop           # Run RuboCop linter
bin/rubocop -a        # Auto-correct violations
bin/brakeman          # Security analysis
bin/bundler-audit     # Check for vulnerable gems
bin/importmap audit   # Check JavaScript dependencies
```

### CI Pipeline

The `bin/ci` command runs the complete CI pipeline:
1. Setup (without starting server)
2. RuboCop style checks
3. Bundler audit (gem security)
4. Importmap audit (JavaScript security)
5. Brakeman (static security analysis)
6. Rails test suite
7. Database seed replanting test

## Architecture

### Data Model

The application uses a hierarchical event management system:

**Groups → Events → Event Occurrences → RSVPs**

#### Core Models

- **Users**: Authenticated users with username, email, name, and avatar
- **Groups**: Collections of members with unique slugs and privacy settings
- **Events**: Belong to groups, can be recurring (none/daily/weekly/monthly)
- **EventOccurrences**: Specific instances of events with start/end times, status tracking, and capacity limits
- **RSVPs**: User responses to specific event occurrences (attending/declined/maybe) with guest counts
- **GroupMemberships**: Join table connecting users to groups

All core domain tables use UUID primary keys for improved scalability and security.

#### Key Features

- **Recurring Events**: Events store recurrence patterns allowing automatic generation of future occurrences
- **Location Overrides**: Individual event occurrences can override the parent event's location
- **Per-Occurrence RSVPs**: Users RSVP to specific occurrences, not events, enabling granular attendance tracking
- **Guest Support**: RSVPs support guest counts for "+1" functionality
- **Capacity Management**: Event occurrences can set maximum attendee limits

### Rails Omakase Stack

This application uses Rails 8's modern, batteries-included approach:

- **No Redis Required**: Solid Cache, Solid Queue, and Solid Cable provide database-backed alternatives
- **SQLite in Production**: Leverages SQLite3 2.1+ for simplified deployment
- **Hotwire**: Turbo and Stimulus provide SPA-like interactivity without complex JavaScript frameworks
- **Importmap**: Manage JavaScript dependencies without Node.js build tools

## Deployment

The application is configured for deployment using Kamal (Docker-based) with Thruster for HTTP caching and compression.

```bash
kamal setup    # Initial deployment setup
kamal deploy   # Deploy to production
```

See `config/deploy.yml` for deployment configuration.

## Known Issues

- **UUID Schema Dumping**: The schema currently has UUID type detection issues with SQLite3. Migrations use `type: :uuid` for foreign keys, but `db/schema.rb` shows "Unknown type 'uuid'" errors. This is a known SQLite UUID configuration issue that needs resolution.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests and code quality checks (`bin/ci`)
4. Commit your changes
5. Push to the branch
6. Open a Pull Request

## License

[Specify your license here]
