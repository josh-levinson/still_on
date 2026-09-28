# StillOn — To Do

## Launch readiness (before marketing)

Target first niche: tabletop game groups (D&D campaigns, board game nights) — recurring, one organizer, quorum-dependent.

### Must fix before launch
- [x] **Rate limit SMS-sending endpoints** — `SmsThrottling` concern: 20 sends/hour per IP and 5/hour per phone, shared across onboarding, sign-in, account claim, and RSVP-resend endpoints.
- [x] **OTP brute-force protection** — `OtpVerification` concern: the code stops working after 5 wrong guesses (counted server-side in the cache, not in the cookie), verify endpoints are limited to 30/10 min per IP, and codes come from `SecureRandom`.
- [x] **Enable SSL + host authorization in production** — `assume_ssl`/`force_ssl` are on, and hosts are `stillon.app` and its subdomains plus any hosts listed in the `APP_HOSTS` env var. `/up` is exempt from both.
- [x] **Error monitoring** — Honeybadger reports exceptions (API key via `HONEYBADGER_API_KEY`). Failed SMS in `notify` are reported as handled errors, requests are tagged with `user_id`, and the two daily cron jobs ping check-ins (`HONEYBADGER_CHECKIN_GENERATE_RECURRING_OCCURRENCES`, `HONEYBADGER_CHECKIN_SCHEDULE_NOTIFICATIONS`). Phone params are filtered.
- [ ] **Confirm 10DLC campaign approval** — verify the Twilio A2P campaign is approved before sending real traffic; enable Twilio Fraud Guard / SMS geo-permissions (US only). *Status (2026-09-27): brand registration submitted, under review. Campaign registration comes after brand approval.*

### Should fix
- [x] **Biweekly cadence** — "Every other week" option in both wizards and the event forms (`recurrence_type: "biweekly"`, IceCube `weekly(2)`).
- [x] **Share to Discord** — Discord button in `shared/_share_buttons` copies a ready-to-paste invite message (Discord has no share URL). (Later: Discord bot/webhook for reminders.)
- [x] **Account enumeration on sign-in** — `sessions#submit_phone` always goes to the verify step with neutral copy; unknown numbers just get no text.
- [x] **Product analytics** — self-hosted Ahoy (server-side events only, no IPs, RSVP tokens scrubbed from URLs). `bin/rails "analytics:report[30]"` prints the onboarding funnel and guest RSVP conversion.

### Go-to-market
- [ ] Game-group landing page copy variant (e.g. "Know by Wednesday if Friday's session is happening")
- [ ] Soft launch with 3–5 real game groups; watch onboarding drop-off and guest RSVP rates
- [ ] Then post to r/DnD, r/lfg, r/boardgames, Discord servers, local game stores

## High priority

- [x] **Timezone support** — `start_time`/`end_time` stored in server timezone with no per-group or per-user timezone. Ambiguous times will confuse real users immediately. Store a timezone on Group (or Event), display and accept times in that zone, and include timezone in SMS/email notifications.
- [x] **Manual "Still on?" trigger** — Organizers can't manually send a reminder outside the automated 2-day-before schedule. Add a "Send reminder" button on the occurrence show page that fires `SendRsvpReminderJob` on demand.
- [x] **Guest RSVP re-access** — If a guest loses the SMS link and wants to change their response, they have no way to retrieve it. Add a "resend my link" flow (enter phone → receive new SMS with token) or a "look up RSVP by phone" page.
- [x] **Max attendees enforcement** — `EventOccurrence#full?` exists but the RSVP controllers don't check it. A 10-person cap currently does nothing.

- [x] **Returning user sign-in** — `/sign_in` flow in `SessionsController`: phone → OTP → `find_by(phone_number:)` → groups dashboard. Splash and navbar links updated.
- [x] **Fewer OTP texts** — session cookie lasts 60 days (sliding); development logs sign-in codes instead of texting them (`SEND_OTP_SMS=1` to send).
- [x] **Dashboard route** — `PostsController#index` has a working query for upcoming activity across groups but no route. Wire up `/dashboard` or `/` (for signed-in users) to this view.
- [x] **Group membership** — No join/leave actions for non-organizer users. Need a way for people to become members of a group (separate from RSVPing to a specific event).
- [x] **SMS opt-out handling** — No Twilio webhook endpoint or model field to record STOP replies. The app will keep sending SMS to opted-out users, which is a legal/compliance risk.
- [x] **SMS terms & carrier compliance** — `/terms` page with SMS terms; opt-in copy links Terms + Privacy and states frequency/HELP/STOP; future-reminders checkbox no longer pre-checked; all texts prefixed "StillOn: "; START/YES/UNSTOP clears `SmsOptOut`.

## Medium priority

- [x] **Quorum enforcement** — `quorum` field is stored but nothing acts on it. Add logic: if quorum isn't met N hours before an occurrence, either cancel the event or send an alert to the organizer and attendees.
- [x] **Event cancellation flow** — `EventOccurrence` has a `cancelled` status but there's no UI action to trigger it and no job to notify attendees.
- [x] **Organizer RSVP summary** — The occurrence show page has the full RSVP list, but there's no at-a-glance summary across upcoming occurrences for a group (e.g., "8 in, 2 maybe, 3 no response").
- [x] **Guest account claim UI** — The `claim_guest_rsvps` hook is wired up on User, but guests have no prompt to create an account after RSVPing. Add a soft nudge on the RSVP confirmation.
- [x] **Event change notifications** — If an organizer edits the time or location of an occurrence, attending/maybe guests should receive an SMS update.

## Lower priority

- [x] **Time selection in onboarding/new-hangout wizard** — both wizards hardcode 7pm. Organizers who create morning or afternoon hangouts get the wrong time and must manually edit the occurrence after the fact with no prompt to do so.
- [x] **"Add to calendar" on guest RSVP page** — after a guest confirms attendance, there's no way to get the event into their calendar. An ICS download or Google Calendar link would reduce no-shows.
- [x] **Profile/settings page** — no route or UI exists for organizers to edit their name once signed in.
- [x] **Guest account claim merge** — the post-RSVP nudge links to `/onboarding/phone`, which creates a new user rather than associating the account with prior guest RSVPs. Existing RSVPs stay orphaned.
- [ ] **Avatar/photo upload** — `avatar_url` fields exist on User and Group but there's no upload mechanism. Currently the field is unused.

- [x] Co-organizer support — promote/demote members to co-organizer via group members section
- [x] Email fallback — if SMS fails to deliver there's no backup contact method
- [x] **Pause a group** — organizers can temporarily stop occurrence generation and automated reminders (indefinitely or until a date) instead of deleting the group
- [x] Occurrence notes in SMS reminders — `notes` field on EventOccurrence isn't included in reminder messages

---

## Test coverage

### Controllers (high priority)

- [x] `OnboardingController` — multi-step wizard: phone → OTP → hangout details → invite. Critical path, 0 tests.
- [x] `SessionsController` — phone OTP sign-in/sign-out flow
- [x] `EventsController` — CRUD, authorization checks
- [x] `GroupsController` — CRUD, public/private authorization, discover page
- [x] `EventOccurrencesController` — CRUD, status changes
- [x] `GroupMembershipsController` — join/leave
- [x] `RsvpsController` — organizer-facing RSVP management
- [x] `TwilioWebhooksController` — SMS opt-out and status callbacks
- [x] `PagesController` / `DashboardController` — dashboard and static pages

### Jobs (medium priority)

- [x] `SendCancellationNotificationJob`
- [x] `SendQuorumAlertJob`
- [x] `SendEventChangeNotificationJob`

### Models (lower priority)

- [x] `GroupMembership`
- [x] `GuestGroupSubscription`
- [x] `SmsOptOut`

### Services (lower priority)

- [x] `SmsService` — unit test directly instead of always stubbing
