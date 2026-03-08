SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: event_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_occurrences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid NOT NULL,
    start_time timestamp(6) without time zone NOT NULL,
    end_time timestamp(6) without time zone NOT NULL,
    location character varying,
    status character varying DEFAULT 'scheduled'::character varying NOT NULL,
    max_attendees integer,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    group_id uuid NOT NULL,
    title character varying NOT NULL,
    description text,
    location character varying,
    default_duration_minutes integer,
    recurrence_rule character varying,
    recurrence_type character varying DEFAULT 'none'::character varying NOT NULL,
    created_by_id uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    quorum integer
);


--
-- Name: group_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    group_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    joined_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    description text,
    slug character varying NOT NULL,
    avatar_url character varying,
    is_private boolean DEFAULT false NOT NULL,
    created_by_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: rsvps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rsvps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_occurrence_id uuid NOT NULL,
    user_id uuid,
    status character varying NOT NULL,
    guest_count integer DEFAULT 0 NOT NULL,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    guest_name character varying,
    guest_phone character varying
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    first_name character varying,
    last_name character varying,
    avatar_url character varying,
    username character varying,
    phone_number character varying,
    phone_verified_at timestamp(6) without time zone
);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: event_occurrences event_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_occurrences
    ADD CONSTRAINT event_occurrences_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: group_memberships group_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT group_memberships_pkey PRIMARY KEY (id);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: rsvps rsvps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rsvps
    ADD CONSTRAINT rsvps_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_event_occurrences_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_event_occurrences_on_event_id ON public.event_occurrences USING btree (event_id);


--
-- Name: index_event_occurrences_on_event_id_and_start_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_event_occurrences_on_event_id_and_start_time ON public.event_occurrences USING btree (event_id, start_time);


--
-- Name: index_event_occurrences_on_start_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_event_occurrences_on_start_time ON public.event_occurrences USING btree (start_time);


--
-- Name: index_event_occurrences_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_event_occurrences_on_status ON public.event_occurrences USING btree (status);


--
-- Name: index_events_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_created_by_id ON public.events USING btree (created_by_id);


--
-- Name: index_events_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_group_id ON public.events USING btree (group_id);


--
-- Name: index_events_on_recurrence_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_recurrence_type ON public.events USING btree (recurrence_type);


--
-- Name: index_group_memberships_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_memberships_on_group_id ON public.group_memberships USING btree (group_id);


--
-- Name: index_group_memberships_on_group_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_group_memberships_on_group_id_and_user_id ON public.group_memberships USING btree (group_id, user_id);


--
-- Name: index_group_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_memberships_on_user_id ON public.group_memberships USING btree (user_id);


--
-- Name: index_groups_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_groups_on_created_by_id ON public.groups USING btree (created_by_id);


--
-- Name: index_groups_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_groups_on_slug ON public.groups USING btree (slug);


--
-- Name: index_rsvps_on_event_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rsvps_on_event_occurrence_id ON public.rsvps USING btree (event_occurrence_id);


--
-- Name: index_rsvps_on_occurrence_and_guest_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rsvps_on_occurrence_and_guest_phone ON public.rsvps USING btree (event_occurrence_id, guest_phone) WHERE (guest_phone IS NOT NULL);


--
-- Name: index_rsvps_on_occurrence_and_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rsvps_on_occurrence_and_user ON public.rsvps USING btree (event_occurrence_id, user_id) WHERE (user_id IS NOT NULL);


--
-- Name: index_rsvps_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rsvps_on_status ON public.rsvps USING btree (status);


--
-- Name: index_rsvps_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rsvps_on_user_id ON public.rsvps USING btree (user_id);


--
-- Name: index_users_on_username; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_username ON public.users USING btree (username);


--
-- Name: group_memberships fk_rails_14271168a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT fk_rails_14271168a1 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: events fk_rails_1f2fddcdaa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_rails_1f2fddcdaa FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: rsvps fk_rails_3960e5b383; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rsvps
    ADD CONSTRAINT fk_rails_3960e5b383 FOREIGN KEY (event_occurrence_id) REFERENCES public.event_occurrences(id);


--
-- Name: rsvps fk_rails_4ab9d5c589; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rsvps
    ADD CONSTRAINT fk_rails_4ab9d5c589 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: events fk_rails_61fbf6ca48; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_rails_61fbf6ca48 FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- Name: groups fk_rails_7bec5aff4f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT fk_rails_7bec5aff4f FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: event_occurrences fk_rails_b34bce2c40; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_occurrences
    ADD CONSTRAINT fk_rails_b34bce2c40 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: group_memberships fk_rails_d05778f88b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT fk_rails_d05778f88b FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

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
('20260118181219'),
('20260118181218');

