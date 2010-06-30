--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: discogs; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA discogs;


SET search_path = discogs, pg_catalog;

SET default_with_oids = false;

--
-- Name: artist; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE artist (
    name text NOT NULL,
    realname text,
    urls text[],
    namevariations text[],
    aliases text[],
    releases integer[],
    profile text,
    members text[],
    groups text[]
);


--
-- Name: artists_images; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE artists_images (
    image_uri text,
    artist_name text
);


--
-- Name: country; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE country (
    name text NOT NULL
);


--
-- Name: format; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE format (
    name text NOT NULL
);


--
-- Name: genre; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE genre (
    id integer NOT NULL,
    name text,
    parent_genre integer,
    sub_genre integer
);


--
-- Name: image; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE image (
    height integer,
    width integer,
    type text,
    uri text NOT NULL,
    uri150 text
);


--
-- Name: label; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE label (
    name text NOT NULL,
    contactinfo text,
    profile text,
    parent_label text,
    sublabels text[],
    urls text[]
);


--
-- Name: labels_images; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE labels_images (
    image_uri text,
    label_name text
);


--
-- Name: release; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE release (
    discogs_id integer NOT NULL,
    status text,
    title text,
    country text,
    released text,
    notes text,
    genres text,
    styles text
);


--
-- Name: releases_artists; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE releases_artists (
    artist_name text NOT NULL,
    discogs_id integer NOT NULL
);


--
-- Name: releases_artists_joins; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE releases_artists_joins (
    artist1 text,
    artist2 text,
    join_relation text,
    discogs_id integer
);


--
-- Name: releases_extraartists; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE releases_extraartists (
    discogs_id integer,
    artist_name text,
    roles text[]
);


--
-- Name: releases_extraartists_roles; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE releases_extraartists_roles (
    discogs_id integer,
    artist_name text,
    role_name text
);


--
-- Name: releases_formats; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE releases_formats (
    discogs_id integer,
    format_name text,
    qty integer,
    descriptions text[]
);


--
-- Name: releases_images; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE releases_images (
    image_uri text,
    discogs_id integer
);


--
-- Name: releases_labels; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE releases_labels (
    label text,
    discogs_id integer,
    catno text
);


--
-- Name: role; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE role (
    role_name text
);


--
-- Name: track; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE track (
    discogs_id integer,
    title text,
    duration text,
    "position" text,
    track_id uuid NOT NULL,
    albumseq integer DEFAULT 1 NOT NULL,
    trackseq integer
);


--
-- Name: tracks_artists; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE tracks_artists (
    artist_name text NOT NULL,
    track_id uuid NOT NULL
);


--
-- Name: tracks_artists_joins; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE tracks_artists_joins (
    artist1 text,
    artist2 text,
    join_relation text,
    track_id uuid NOT NULL
);


--
-- Name: tracks_extraartists_roles; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE tracks_extraartists_roles (
    artist_name text,
    role_name text,
    role_details text,
    track_id uuid NOT NULL
);


--
-- Name: artist_pkey; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY artist
    ADD CONSTRAINT artist_pkey PRIMARY KEY (name);


--
-- Name: country_pkey; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY country
    ADD CONSTRAINT country_pkey PRIMARY KEY (name);


--
-- Name: format_pkey; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY format
    ADD CONSTRAINT format_pkey PRIMARY KEY (name);


--
-- Name: genre_pkey; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY genre
    ADD CONSTRAINT genre_pkey PRIMARY KEY (id);


--
-- Name: image_pkey; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY image
    ADD CONSTRAINT image_pkey PRIMARY KEY (uri);


--
-- Name: label_pkey; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY label
    ADD CONSTRAINT label_pkey PRIMARY KEY (name);


--
-- Name: release_pkey; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY release
    ADD CONSTRAINT release_pkey PRIMARY KEY (discogs_id);


--
-- Name: releases_artists_pkey; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY releases_artists
    ADD CONSTRAINT releases_artists_pkey PRIMARY KEY (discogs_id, artist_name);


--
-- Name: track_pk; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY track
    ADD CONSTRAINT track_pk PRIMARY KEY (track_id);


--
-- Name: tracks_artists_pkey; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY tracks_artists
    ADD CONSTRAINT tracks_artists_pkey PRIMARY KEY (track_id, artist_name);


--
-- Name: artists_images_idx_artist_name; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX artists_images_idx_artist_name ON artists_images USING btree (artist_name);


--
-- Name: labels_images_label_name; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX labels_images_label_name ON labels_images USING btree (label_name);


--
-- Name: releases_artists_idx_artist_name; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX releases_artists_idx_artist_name ON releases_artists USING btree (artist_name);


--
-- Name: releases_artists_join_idx_artist1; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX releases_artists_join_idx_artist1 ON releases_artists_joins USING btree (artist1);


--
-- Name: releases_artists_join_idx_artist2; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX releases_artists_join_idx_artist2 ON releases_artists_joins USING btree (artist2);


--
-- Name: releases_extraartists_idx_artist_name; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX releases_extraartists_idx_artist_name ON releases_extraartists USING btree (artist_name);


--
-- Name: releases_extraartists_roles_idx_artist_name; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX releases_extraartists_roles_idx_artist_name ON releases_extraartists_roles USING btree (artist_name);


--
-- Name: releases_labels_idx_label_name; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX releases_labels_idx_label_name ON releases_labels USING btree (label);


--
-- Name: track_idx_albumseq; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX track_idx_albumseq ON track USING btree (albumseq);


--
-- Name: track_idx_release; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX track_idx_release ON track USING btree (discogs_id);

ALTER TABLE track CLUSTER ON track_idx_release;


--
-- Name: track_idx_trackseq; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX track_idx_trackseq ON track USING btree (trackseq NULLS FIRST);


--
-- Name: tracks_artists_idx_artist_name; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX tracks_artists_idx_artist_name ON tracks_artists USING btree (artist_name);


--
-- Name: tracks_artists_idx_track_id; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX tracks_artists_idx_track_id ON tracks_artists USING btree (track_id);

ALTER TABLE tracks_artists CLUSTER ON tracks_artists_idx_track_id;


--
-- Name: tracks_artists_joins_idx_artist1; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX tracks_artists_joins_idx_artist1 ON tracks_artists_joins USING btree (artist1);


--
-- Name: tracks_artists_joins_idx_artist2; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX tracks_artists_joins_idx_artist2 ON tracks_artists_joins USING btree (artist2);


--
-- Name: tracks_artists_joins_idx_track_id; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX tracks_artists_joins_idx_track_id ON tracks_artists_joins USING btree (track_id);

ALTER TABLE tracks_artists_joins CLUSTER ON tracks_artists_joins_idx_track_id;


--
-- Name: tracks_extraartists_roles_idx_artist; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX tracks_extraartists_roles_idx_artist ON tracks_extraartists_roles USING btree (artist_name);


--
-- Name: tracks_extraartists_roles_idx_role; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX tracks_extraartists_roles_idx_role ON tracks_extraartists_roles USING btree (role_name);


--
-- Name: tracks_extraartists_roles_idx_role_details; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX tracks_extraartists_roles_idx_role_details ON tracks_extraartists_roles USING btree (role_details);


--
-- Name: tracks_extraartists_roles_idx_textsearch; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX tracks_extraartists_roles_idx_textsearch ON tracks_extraartists_roles USING gin (to_tsvector('mbot.english_nostop'::regconfig, role_details));


--
-- Name: tracks_xa_roles_idx_track_id; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX tracks_xa_roles_idx_track_id ON tracks_extraartists_roles USING btree (track_id);

ALTER TABLE tracks_extraartists_roles CLUSTER ON tracks_xa_roles_idx_track_id;


--
-- Name: artists_images_artist_name_fkey; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY artists_images
    ADD CONSTRAINT artists_images_artist_name_fkey FOREIGN KEY (artist_name) REFERENCES artist(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: artists_images_image_uri_fkey; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY artists_images
    ADD CONSTRAINT artists_images_image_uri_fkey FOREIGN KEY (image_uri) REFERENCES image(uri) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: foreign_did; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY releases_labels
    ADD CONSTRAINT foreign_did FOREIGN KEY (discogs_id) REFERENCES release(discogs_id);


--
-- Name: labels_images_image_uri_fkey; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY labels_images
    ADD CONSTRAINT labels_images_image_uri_fkey FOREIGN KEY (image_uri) REFERENCES image(uri) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: labels_images_label_name_fkey; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY labels_images
    ADD CONSTRAINT labels_images_label_name_fkey FOREIGN KEY (label_name) REFERENCES label(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: releases_artists_fkey_discogs_id; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY releases_artists
    ADD CONSTRAINT releases_artists_fkey_discogs_id FOREIGN KEY (discogs_id) REFERENCES release(discogs_id) ON DELETE CASCADE;


--
-- Name: releases_artists_joins_fkey_discogs_id; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY releases_artists_joins
    ADD CONSTRAINT releases_artists_joins_fkey_discogs_id FOREIGN KEY (discogs_id) REFERENCES release(discogs_id) ON DELETE CASCADE;


--
-- Name: releases_extraartists_fkey_discogs_id; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY releases_extraartists
    ADD CONSTRAINT releases_extraartists_fkey_discogs_id FOREIGN KEY (discogs_id) REFERENCES release(discogs_id) ON DELETE CASCADE;


--
-- Name: releases_extraartists_roles_fkey_discogs_id; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY releases_extraartists_roles
    ADD CONSTRAINT releases_extraartists_roles_fkey_discogs_id FOREIGN KEY (discogs_id) REFERENCES release(discogs_id) ON DELETE CASCADE;


--
-- Name: releases_formats_fkey_discogs_id; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY releases_formats
    ADD CONSTRAINT releases_formats_fkey_discogs_id FOREIGN KEY (discogs_id) REFERENCES release(discogs_id) ON DELETE CASCADE;


--
-- Name: releases_formats_format_name_fkey; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY releases_formats
    ADD CONSTRAINT releases_formats_format_name_fkey FOREIGN KEY (format_name) REFERENCES format(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: releases_images_fkey_discogs_id; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY releases_images
    ADD CONSTRAINT releases_images_fkey_discogs_id FOREIGN KEY (discogs_id) REFERENCES release(discogs_id) ON DELETE CASCADE;


--
-- Name: releases_images_image_uri_fkey; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY releases_images
    ADD CONSTRAINT releases_images_image_uri_fkey FOREIGN KEY (image_uri) REFERENCES image(uri) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: track_fkey_discogs_id; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY track
    ADD CONSTRAINT track_fkey_discogs_id FOREIGN KEY (discogs_id) REFERENCES release(discogs_id) ON DELETE CASCADE;


--
-- Name: tracks_artists_fkey_track_id; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY tracks_artists
    ADD CONSTRAINT tracks_artists_fkey_track_id FOREIGN KEY (track_id) REFERENCES track(track_id) ON DELETE CASCADE;


--
-- Name: tracks_artists_joins_fkey_track_id; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY tracks_artists_joins
    ADD CONSTRAINT tracks_artists_joins_fkey_track_id FOREIGN KEY (track_id) REFERENCES track(track_id) ON DELETE CASCADE;


--
-- Name: tracks_extraartists_roles_fkey_track_id; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY tracks_extraartists_roles
    ADD CONSTRAINT tracks_extraartists_roles_fkey_track_id FOREIGN KEY (track_id) REFERENCES track(track_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

