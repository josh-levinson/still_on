CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "groups" ("id" uuid NOT NULL PRIMARY KEY, "name" varchar NOT NULL, "description" text, "slug" varchar NOT NULL, "avatar_url" varchar, "is_private" boolean DEFAULT FALSE NOT NULL, "created_by_id" uuid NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_7bec5aff4f"
FOREIGN KEY ("created_by_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_groups_on_created_by_id" ON "groups" ("created_by_id") /*application='StillOn'*/;
CREATE UNIQUE INDEX "index_groups_on_slug" ON "groups" ("slug") /*application='StillOn'*/;
CREATE TABLE IF NOT EXISTS "group_memberships" ("id" uuid NOT NULL PRIMARY KEY, "group_id" uuid NOT NULL, "user_id" uuid NOT NULL, "role" varchar DEFAULT 'member' NOT NULL, "joined_at" datetime(6) DEFAULT CURRENT_TIMESTAMP NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_d05778f88b"
FOREIGN KEY ("group_id")
  REFERENCES "groups" ("id")
, CONSTRAINT "fk_rails_14271168a1"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_group_memberships_on_group_id" ON "group_memberships" ("group_id") /*application='StillOn'*/;
CREATE INDEX "index_group_memberships_on_user_id" ON "group_memberships" ("user_id") /*application='StillOn'*/;
CREATE UNIQUE INDEX "index_group_memberships_on_group_id_and_user_id" ON "group_memberships" ("group_id", "user_id") /*application='StillOn'*/;
CREATE TABLE IF NOT EXISTS "events" ("id" uuid NOT NULL PRIMARY KEY, "group_id" uuid NOT NULL, "title" varchar NOT NULL, "description" text, "location" varchar, "default_duration_minutes" integer, "recurrence_rule" varchar, "recurrence_type" varchar DEFAULT 'none' NOT NULL, "created_by_id" uuid NOT NULL, "is_active" boolean DEFAULT TRUE NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "quorum" integer /*application='StillOn'*/, CONSTRAINT "fk_rails_61fbf6ca48"
FOREIGN KEY ("group_id")
  REFERENCES "groups" ("id")
, CONSTRAINT "fk_rails_1f2fddcdaa"
FOREIGN KEY ("created_by_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_events_on_group_id" ON "events" ("group_id") /*application='StillOn'*/;
CREATE INDEX "index_events_on_created_by_id" ON "events" ("created_by_id") /*application='StillOn'*/;
CREATE INDEX "index_events_on_recurrence_type" ON "events" ("recurrence_type") /*application='StillOn'*/;
CREATE TABLE IF NOT EXISTS "event_occurrences" ("id" uuid NOT NULL PRIMARY KEY, "event_id" uuid NOT NULL, "start_time" datetime(6) NOT NULL, "end_time" datetime(6) NOT NULL, "location" varchar, "status" varchar DEFAULT 'scheduled' NOT NULL, "max_attendees" integer, "notes" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_b34bce2c40"
FOREIGN KEY ("event_id")
  REFERENCES "events" ("id")
);
CREATE INDEX "index_event_occurrences_on_event_id" ON "event_occurrences" ("event_id") /*application='StillOn'*/;
CREATE INDEX "index_event_occurrences_on_event_id_and_start_time" ON "event_occurrences" ("event_id", "start_time") /*application='StillOn'*/;
CREATE INDEX "index_event_occurrences_on_start_time" ON "event_occurrences" ("start_time") /*application='StillOn'*/;
CREATE INDEX "index_event_occurrences_on_status" ON "event_occurrences" ("status") /*application='StillOn'*/;
CREATE TABLE IF NOT EXISTS "users" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "first_name" varchar, "last_name" varchar, "avatar_url" varchar, "username" varchar, "phone_number" varchar, "phone_verified_at" datetime(6) /*application='StillOn'*/);
CREATE UNIQUE INDEX "index_users_on_username" ON "users" ("username") /*application='StillOn'*/;
CREATE TABLE IF NOT EXISTS "rsvps" ("id"  NOT NULL PRIMARY KEY, "event_occurrence_id"  NOT NULL, "user_id" , "status" varchar NOT NULL, "guest_count" integer DEFAULT 0 NOT NULL, "notes" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "guest_name" varchar /*application='StillOn'*/, "guest_phone" varchar /*application='StillOn'*/, CONSTRAINT "fk_rails_4ab9d5c589"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_3960e5b383"
FOREIGN KEY ("event_occurrence_id")
  REFERENCES "event_occurrences" ("id")
);
CREATE INDEX "index_rsvps_on_event_occurrence_id" ON "rsvps" ("event_occurrence_id") /*application='StillOn'*/;
CREATE INDEX "index_rsvps_on_user_id" ON "rsvps" ("user_id") /*application='StillOn'*/;
CREATE INDEX "index_rsvps_on_status" ON "rsvps" ("status") /*application='StillOn'*/;
CREATE UNIQUE INDEX "index_rsvps_on_occurrence_and_user" ON "rsvps" ("event_occurrence_id", "user_id") WHERE user_id IS NOT NULL /*application='StillOn'*/;
CREATE UNIQUE INDEX "index_rsvps_on_occurrence_and_guest_phone" ON "rsvps" ("event_occurrence_id", "guest_phone") WHERE guest_phone IS NOT NULL /*application='StillOn'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20260308010626'),
('20260307234840'),
('20260307045353'),
('20260306153350'),
('20260305202352'),
('20260118184453'),
('20260118184452'),
('20260118184451'),
('20260118184450'),
('20260118184449'),
('20260118183614'),
('20260118181219');

