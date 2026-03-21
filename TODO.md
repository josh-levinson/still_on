# StillOn — To Do

## High priority

- [x] **Returning user sign-in** — `/sign_in` flow in `SessionsController`: phone → OTP → `find_by(phone_number:)` → groups dashboard. Splash and navbar links updated.
- [x] **Dashboard route** — `PostsController#index` has a working query for upcoming activity across groups but no route. Wire up `/dashboard` or `/` (for signed-in users) to this view.
- [x] **Group membership** — No join/leave actions for non-organizer users. Need a way for people to become members of a group (separate from RSVPing to a specific event).
- [x] **SMS opt-out handling** — No Twilio webhook endpoint or model field to record STOP replies. The app will keep sending SMS to opted-out users, which is a legal/compliance risk.

## Medium priority

- [ ] **Quorum enforcement** — `quorum` field is stored but nothing acts on it. Add logic: if quorum isn't met N hours before an occurrence, either cancel the event or send an alert to the organizer and attendees.
- [ ] **Event cancellation flow** — `EventOccurrence` has a `cancelled` status but there's no UI action to trigger it and no job to notify attendees.
- [ ] **Organizer RSVP summary** — The occurrence show page has the full RSVP list, but there's no at-a-glance summary across upcoming occurrences for a group (e.g., "8 in, 2 maybe, 3 no response").
- [ ] **Guest account claim UI** — The `claim_guest_rsvps` hook is wired up on User, but guests have no prompt to create an account after RSVPing. Add a soft nudge on the RSVP confirmation.
- [ ] **Event change notifications** — If an organizer edits the time or location of an occurrence, attending/maybe guests should receive an SMS update.

## Lower priority

- [ ] Co-organizer support — no way to add other organizers or transfer group ownership
- [ ] Email fallback — if SMS fails to deliver there's no backup contact method
- [ ] Occurrence notes in SMS reminders — `notes` field on EventOccurrence isn't included in reminder messages

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
- [x] `PagesController` / `PostsController` — dashboard and static pages

### Jobs (medium priority)

- [x] `SendCancellationNotificationJob`
- [x] `SendQuorumAlertJob`
- [x] `SendEventChangeNotificationJob`

### Models (lower priority)

- [x] `GroupMembership`
- [x] `GuestGroupSubscription`
- [x] `SmsOptOut`

### Services (lower priority)

- [ ] `SmsService` — unit test directly instead of always stubbing
