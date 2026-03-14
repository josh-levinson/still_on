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
