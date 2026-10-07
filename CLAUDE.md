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
- **Events**: Templates/series belonging to Groups. Can be recurring (recurrence_type: none/daily/weekly/biweekly/monthly, recurrence_rule stores pattern)
- **EventOccurrences**: Specific instances of Events (start_time, end_time, status: scheduled/cancelled/completed, max_attendees). Can override parent Event's location.
- **RSVPs**: Responses scoped to specific EventOccurrences, not Events — enables per-instance attendance tracking (status: attending/declined/maybe, guest_count for +1s)
- **GroupMemberships**: Join table connecting Users to Groups

All core domain tables use UUID primary keys for scalability and security.

### Guest RSVP flow (no account required)
Guests receive a signed token link. The token encodes the EventOccurrence and optionally a phone number. RSVPs from guests are stored with a lightweight guest record that can be claimed/merged if they later create an account. This is the primary interaction path for most people who use the app.

### Organizer auth flow
Organizers sign up (or sign in) via phone number + SMS OTP. The onboarding wizard collects first name, hangout name, date, and cadence — then creates the User, Group, Event, and first EventOccurrence in one step. Returning users sign in through the same phone/verify flow at `/onboarding/phone`. The session cookie (`config/initializers/session_store.rb`) lasts 60 days from the last visit, so organizers rarely need a new code. In development, `config.x.otp_sms` is off and codes are written to the Rails log instead of texted; run with `SEND_OTP_SMS=1` to send real texts.

### Background jobs
One cron entry in `config/recurring.yml` runs `DailyTasksJob` at 8am `America/New_York` (pinned because the Railway server runs in UTC). It runs these two jobs in order, then pings a single Honeybadger check-in:
- `GenerateRecurringOccurrencesJob` generates EventOccurrence records for recurring events up to 30 days out
- `ScheduleNotificationsJob` enqueues SMS reminders: RSVP prompts 2 days before each occurrence (to non-RSVPd members), and day-of confirmations to attending/maybe guests

### Monitoring
Honeybadger (`config/honeybadger.yml`, key from `HONEYBADGER_API_KEY`) catches unhandled exceptions. Errors that are rescued but still matter go through `Rails.error.report(e, handled: true)`. `SmsService#send_message` reports every send failure itself and re-raises, so callers shouldn't report again. Carrier-side delivery failures arrive later on `POST /twilio/status` (the status callback is only requested when `config.x.twilio_status_callbacks` is on, i.e. production). Account-wide Twilio errors arrive on `POST /twilio/debugger`, which must be set as the webhook URL in the Twilio Console (Monitor → Errors → Webhook). Spend alerts come from Twilio Usage Triggers (Console → Usage → Triggers) whose callback URL is `POST /twilio/usage`; these are fingerprinted by usage category. All three are sent with `Honeybadger.notify`, and the first two are fingerprinted by Twilio error code. They forward only codes and SIDs, never the payload, which can contain phone numbers. Use `SmsService.mask` for phone numbers in log lines. `DailyTasksJob` calls `check_in(:daily_tasks)` only after both daily jobs succeed, which pings the Honeybadger check-in whose ID is in `HONEYBADGER_CHECKIN_DAILY_TASKS` (no-op when unset). The Honeybadger plan allows one check-in, so new scheduled work should run inside `DailyTasksJob` rather than get its own check-in. `:phone` is in `filter_parameters`, so phone numbers stay out of logs and error reports.

### Analytics
Ahoy (`config/initializers/ahoy.rb`) records server-side events only, in `ahoy_visits`/`ahoy_events`: an "Onboarding step" event on each onboarding GET step, plus "RSVP page viewed" and "RSVP submitted" in `GuestRsvpsController`. No IPs or geocoding are stored, and `/rsvp/:token` URLs are scrubbed before they're saved. `AnalyticsReport` turns the events into funnels; print them with `bin/rails "analytics:report[DAYS]"`. The analytics cookies are listed on `/privacy`, so update that page when tracking changes.

### Dashboard
`/dashboard` (`DashboardController#show`) shows one card per hangout (group), split by the user's role. **You organize** covers groups they created or co-organize. Each card shows the next occurrence, an RSVP tally (`EventOccurrence#awaiting_reply_count` counts members plus SMS subscribers who haven't replied), a Nudge button (sends an RSVP reminder), the invite link, and pause/quorum warnings. **You're in** covers groups they're a member of, subscribed to as a guest (by phone), or have RSVP'd to, so guests who claimed an account see their hangouts, with one-tap Going/Maybe/Can't buttons. The Nudge and RSVP actions `redirect_back_or_to` the occurrence page, so they return to the dashboard. Full management (events, members, pausing) lives on the group page.

### Pausing a group
Organizers can pause a group (`Group#pause!`, optional `paused_until` resume date; `GroupPausesController`). While paused, `GenerateRecurringOccurrencesJob` skips occurrences inside the pause window and `ScheduleNotificationsJob` sends no automated reminders for them. Nothing is deleted, and the pause lifts on its own at the start of `paused_until` in the group's time zone. Existing occurrences are left as they are. Manual reminder buttons still work.

### SMS compliance
Legal pages live in `PagesController`: `/terms`, `/privacy`, `/sms` (SMS Program page, used for carrier campaign review). Keep the consent copy quoted on `/sms` in sync with the actual copy on `onboarding/phone` and `guest_rsvps/show`. `SmsService` prefixes every text with "StillOn: ". Opt-in checkboxes must default to unchecked unless the phone is already subscribed. STOP-type replies create an `SmsOptOut`; START/YES/UNSTOP remove it.

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
- **Resend**: email fallback when an SMS fails or a guest gave only an email. Production sends through its HTTPS API (`delivery_method = :resend`, key in `RESEND_API_KEY`) because Railway blocks outbound SMTP. The from address is `noreply@stillon.app`, so the domain must be verified in Resend.
- **Kamal**: Deployment via Docker
- **Thruster**: HTTP caching/compression for Puma

### Testing

- Uses standard Rails minitest
- Tests run in parallel (`:number_of_processors`)
- System tests available via Capybara + Selenium
- To find uncovered lines/branches after a test run, read `coverage/.resultset.json` — do not try to parse `coverage/index.html`
- **All new feature work must ship with complete test coverage.** After implementing a feature, run the test suite and check `coverage/.resultset.json` for any uncovered lines or branches introduced by the change. Do not consider a feature complete until coverage is at 100% for the new code.

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

Follows **rubocop-rails-omakase** conventions.

Styling lives in `app/assets/stylesheets/application.css` and uses the theme tokens at the top of `:root` (`--bg`, `--surface`, `--text`, `--text-muted`, `--text-subtle`, `--border`, `--border-strong`, `--accent`, `--focus-ring`). Don't hardcode greys: `--text-subtle` is the dimmest text that meets WCAG AA (4.5:1), and input/control borders use `--border-strong` (3:1). Font sizes are in `rem`, with 13px (`0.8125rem`) as the minimum. The look is "Group chat": warm cream background, Bricolage Grotesque everywhere, 2px ink outlines (`--border-strong`) on controls and cards, and a hard offset shadow (`--ink-shadow`) on primary buttons and selected choices. Labels are sentence case, not uppercase. Status colours have tokens too (`--going`, `--maybe`, and `--success-*`, `--danger-*`, `--warning-*`, `--info-*` bg/text/border sets); use those instead of new hex values. Don't dim text with `opacity`, and don't remove focus outlines without replacing them. There's a dark theme (deep navy, cream ink outlines and shadows, navy text on bright fills) right after `:root`. Visitors pick Auto/Light/Dark with the footer switch (`shared/_theme_switcher`, `theme_controller.js`, `ThemesController`). The choice is stored in a `theme` cookie and rendered as `data-theme` on `<html>`, and Auto follows the OS. The dark token set appears twice, once under `:root[data-theme="dark"]` and once in the `prefers-color-scheme` media query, and the two must stay identical. Any new colour needs a token with a value in the light and dark sets. Text on `--accent`/`--going` uses `--on-accent`, and text on `--maybe` uses `--on-maybe`. The `.rubocop.yml` inherits from the omakase gem with minimal overrides.

---

## Known Issues

### UUID type detection with PostgreSQL
Migrations use `type: :uuid` for foreign keys, but `db/schema.rb` shows "Unknown type 'uuid'" warnings. The tables and constraints are correct in the database — this is a schema dumper rendering issue only.
