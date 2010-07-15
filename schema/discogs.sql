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

--
-- Name: find_edits_discogs_trackrole(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION find_edits_discogs_trackrole() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table discogs.tmp_discogs_trackrole_step_06_ready
(
link0gid char(36) not null,
link0type varchar (10) not null,
link1gid char(36) not null,
link1type varchar (10) not null,
linktype integer not null,
"release" integer not null,
source varchar (30) not null,
sourceurl varchar(100) not null
);

insert into discogs.tmp_discogs_trackrole_step_06_ready
select 
distinct
a.gid link0gid, 'artist'::varchar(10),
t.gid link1gid, 'track'::varchar(10),
link_type linktype, mb_release, 
'discogs-trackrole'::varchar(30) source,
'http://www.discogs.com/release/' || d_release sourceurl
from discogs.tmp_discogs_trackrole_step_05_new tar,
musicbrainz.artist a, musicbrainz.track t
where a.id = mb_artist and t.id = mb_track;

drop table discogs.tmp_discogs_trackrole_step_05_new;

DELETE FROM mbot.edits_relationship_track edits
WHERE (error IS NOT NULL OR date_processed IS NULL)
AND NOT EXISTS 
	(SELECT 1 FROM discogs.tmp_discogs_trackrole_step_06_ready newedits
		WHERE newedits.link0gid = edits.link0gid
		AND newedits.link1gid = edits.link1gid
		AND newedits.link0type = edits.link0type
		AND newedits.link1type = edits.link1type
		AND newedits.linktype = edits.linktype
		AND newedits.source = edits.source);

INSERT INTO mbot.edits_relationship_track 
(link0gid, link0type, link1gid, link1type, linktype, "release", source, sourceurl)
SELECT * FROM discogs.tmp_discogs_trackrole_step_06_ready newedits
WHERE NOT EXISTS
	(SELECT 1 FROM mbot.edits_relationship_track edits
		WHERE newedits.link0gid = edits.link0gid
		AND newedits.link1gid = edits.link1gid
		AND newedits.link0type = edits.link0type
		AND newedits.link1type = edits.link1type
		AND newedits.linktype = edits.linktype
		AND newedits.source = edits.source);

drop table discogs.tmp_discogs_trackrole_step_06_ready;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='find_edits_discogs_trackrole';

END;
$$;


--
-- Name: gen_tquery(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION gen_tquery() RETURNS trigger
    LANGUAGE plpgsql STABLE
    AS $$BEGIN
	NEW.role_query = plainto_tsquery('mbot.english_nostop', NEW.role_name);
	RETURN NEW;
END$$;


--
-- Name: tmp_discogs_trackmap_step_01(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION tmp_discogs_trackmap_step_01() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table discogs.tmp_discogs_trackmap_step_01
(
d_track uuid not null,
d_release integer not null,
mb_release integer not null,
title text not null,
d_length text not null,
dpos integer not null
);

insert into discogs.tmp_discogs_trackmap_step_01
select t.track_id d_track, t.discogs_id d_release, a.id mb_release, title, duration d_length, trackseq
from discogs.track t, discogs.dmap_release dr, musicbrainz.album a
where dr.d_release = t.discogs_id and a.gid = dr.mb_release;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackmap_step_01';

END;
$$;


--
-- Name: tmp_discogs_trackmap_step_02_mbtrack(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION tmp_discogs_trackmap_step_02_mbtrack() RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN

create table discogs.tmp_discogs_trackmap_step_02_mbtrack
(
d_track uuid not null,
d_title text not null,
d_length integer,
mb_track integer not null,
mb_title text not null,
mb_length integer not null
);

insert into discogs.tmp_discogs_trackmap_step_02_mbtrack
select d_track, title d_title, 
(CAST(replace(substring(d_length from '^[0-9]+:'), ':', '') AS integer) * 60 +
CAST(substring(d_length from '[0-9]+$')  AS integer)) d_length, aj.track mb_track, t.name mb_title, (t.length / 1000) mb_length
from discogs.tmp_discogs_trackmap_step_01 tmap, musicbrainz.albumjoin aj, musicbrainz.track t
where
tmap.mb_release = aj.album and aj."sequence" = dpos and aj.track = t.id;

drop table discogs.tmp_discogs_trackmap_step_01;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackmap_step_02_mbtrack';

END;
$_$;


--
-- Name: tmp_discogs_trackmap_step_03_samepos(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION tmp_discogs_trackmap_step_03_samepos() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table discogs.tmp_discogs_trackmap_step_03_samepos
(
d_track uuid not null,
d_title text not null,
d_title_full text not null,
mb_track integer not null,
mb_title text not null,
mb_title_full text not null
);

insert into discogs.tmp_discogs_trackmap_step_03_samepos
select d_track,
regexp_replace(lower(regexp_replace(d_title, E' \\([^)]+\\)','', 'g')), '[^a-z0-9]', '', 'g'),
regexp_replace(lower(d_title), '[^a-z0-9]', '', 'g'),
mb_track, 
regexp_replace(lower(regexp_replace(mb_title, E' \\([^)]+\\)','', 'g')), '[^a-z0-9]', '', 'g'),
regexp_replace(lower(mb_title), '[^a-z0-9]', '', 'g')
from discogs.tmp_discogs_trackmap_step_02_mbtrack tmap
where
d_length = 0 or mb_length = 0 or abs(d_length - mb_length) < 10;

drop table discogs.tmp_discogs_trackmap_step_02_mbtrack;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackmap_step_03_samepos';

END;
$$;


--
-- Name: tmp_discogs_trackrole_step_01(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION tmp_discogs_trackrole_step_01() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

CREATE TABLE discogs.tmp_discogs_trackrole_step_01
(
mb_artist integer NOT NULL,
role_name TEXT NOT NULL,
d_track uuid NOT NULL
);

INSERT INTO discogs.tmp_discogs_trackrole_step_01
select a.id mb_artist, role_name, track_id
from discogs.tracks_extraartists_roles x, discogs.dmap_artist da, musicbrainz.artist a
where artist_name = d_artist and COALESCE(artist_alias,'') = COALESCE(d_alias,'') and gid = mb_artist;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackrole_step_01';

END;
$$;


--
-- Name: tmp_discogs_trackrole_step_02_id(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION tmp_discogs_trackrole_step_02_id() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table discogs.tmp_discogs_trackrole_step_02_id
(
mb_artist integer not null,
link_type integer not null,
d_track uuid not null
);

insert into discogs.tmp_discogs_trackrole_step_02_id
select mb_artist, lt.id link_type, d_track
from discogs.tmp_discogs_trackrole_step_01 tar, discogs.dmap_role dr, musicbrainz.lt_artist_track lt
where tar.role_name = dr.role_name and lt.name = dr.link_name;

drop table discogs.tmp_discogs_trackrole_step_01;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackrole_step_02_id';

END;
$$;


--
-- Name: tmp_discogs_trackrole_step_03_mbtrack(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION tmp_discogs_trackrole_step_03_mbtrack() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table discogs.tmp_discogs_trackrole_step_03_mbtrack
(
mb_artist integer not null,
link_type integer not null,
d_release integer not null,
d_track uuid not null,
mb_release integer not null,
mb_track integer not null,
releaseeditcount integer not null
);

insert into discogs.tmp_discogs_trackrole_step_03_mbtrack
select tar.mb_artist, tar.link_type, d_t.discogs_id d_release, tar.d_track, aj.album mb_release, mb_t.id mb_track,
COUNT(1) OVER (PARTITION BY d_t.discogs_id, tar.link_type) as releaseeditcount
from discogs.tmp_discogs_trackrole_step_02_id tar, discogs.dmap_track dt, discogs.track d_t,
musicbrainz.albumjoin aj, musicbrainz.track mb_t
where
tar.d_track = dt.d_track and d_t.track_id = tar.d_track
and aj.track = mb_t.id and mb_t.gid = dt.mb_track;

drop table discogs.tmp_discogs_trackrole_step_02_id;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackrole_step_03_mbtrack';

END;
$$;


--
-- Name: tmp_discogs_trackrole_step_04_allartists(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION tmp_discogs_trackrole_step_04_allartists() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table discogs.tmp_discogs_trackrole_step_04_allartists
(
mb_artist integer not null,
link_type integer not null,
d_release integer not null,
mb_release integer not null,
mb_track integer not null
);

insert into discogs.tmp_discogs_trackrole_step_04_allartists
select tar.mb_artist, tar.link_type, tar.d_release, tar.mb_release, tar.mb_track
from discogs.tmp_discogs_trackrole_step_03_mbtrack tar
where
(select count(1) from discogs.track dt, discogs.tracks_extraartists_roles txr, discogs.dmap_role role, 
musicbrainz.lt_artist_track lt
where txr.role_name = role.role_name and role.link_name = lt.name 
and lt.id = tar.link_type and txr.track_id = dt.track_id and dt.discogs_id = tar.d_release) 
= releaseeditcount;

drop table discogs.tmp_discogs_trackrole_step_03_mbtrack;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackrole_step_04_allartists';

END;
$$;


--
-- Name: tmp_discogs_trackrole_step_05_new(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION tmp_discogs_trackrole_step_05_new() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table discogs.tmp_discogs_trackrole_step_05_new
(
mb_artist integer not null,
link_type integer not null,
d_release integer not null,
mb_release integer not null,
mb_track integer not null
);

insert into discogs.tmp_discogs_trackrole_step_05_new
select 
mb_artist, link_type, d_release, mb_release, mb_track
from discogs.tmp_discogs_trackrole_step_04_allartists tar
where 
not exists
(select 1 from 
musicbrainz.l_artist_track lat,
musicbrainz.artist a1, musicbrainz.artist a2, mbot.mbmap_artist_equiv equiv
where
a1.id = mb_artist
and a1.gid = equiv.artist and a2.gid = equiv.equiv
and lat.link0 = a2.id and lat.link1 = mb_track and lat.link_type in ((select desc_type 
	from mbot.mb_link_type_descs linkmap where linkmap.link_type = tar.link_type) union (select tar.link_type)));

drop table discogs.tmp_discogs_trackrole_step_04_allartists;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackrole_step_05_new';

END;
$$;


--
-- Name: upd_discogs_artist_url(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION upd_discogs_artist_url() RETURNS void
    LANGUAGE sql
    AS $$

DROP INDEX discogs.discogs_artist_url_idx_url;

TRUNCATE discogs.discogs_artist_url;

INSERT INTO discogs.discogs_artist_url
SELECT * FROM discogs.discogs_artist_url_v;

CREATE INDEX discogs_artist_url_idx_url
  ON discogs.discogs_artist_url
  USING btree
  (url);

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_discogs_artist_url';


$$;


--
-- Name: upd_discogs_label_url(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION upd_discogs_label_url() RETURNS void
    LANGUAGE sql
    AS $$

DROP INDEX discogs.discogs_label_url_idx_url;

TRUNCATE discogs.discogs_label_url;

INSERT INTO discogs.discogs_label_url
SELECT * FROM discogs.discogs_label_url_v;

CREATE INDEX discogs_label_url_idx_url
  ON discogs.discogs_label_url
  USING btree
  (url);

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_discogs_label_url';


$$;


--
-- Name: upd_discogs_release_url(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION upd_discogs_release_url() RETURNS void
    LANGUAGE sql
    AS $$

DROP INDEX IF EXISTS discogs.discogs_release_url_idx_url;

TRUNCATE discogs.discogs_release_url;

INSERT INTO discogs.discogs_release_url
SELECT * FROM discogs.discogs_release_url_v;

CREATE INDEX discogs_release_url_idx_url
  ON discogs.discogs_release_url
  USING btree
  (url);

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_discogs_release_url';


$$;


--
-- Name: upd_dmap_artist(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION upd_dmap_artist() RETURNS void
    LANGUAGE sql
    AS $$

TRUNCATE discogs.dmap_artist;

INSERT INTO discogs.dmap_artist
(mb_artist, d_artist)
SELECT * FROM discogs.dmap_artist_v;

INSERT INTO discogs.dmap_artist
(mb_artist, d_artist, d_alias)
SELECT DISTINCT dmap.mb_artist, dmap.d_artist, tx.artist_alias
FROM discogs.dmap_artist_v dmap, discogs.tracks_extraartists_roles tx
WHERE tx.artist_name = dmap.d_artist
AND tx.artist_alias IS NOT NULL;

DELETE FROM discogs.dmap_artist map_out
WHERE EXISTS (select 1 FROM discogs.dmap_artist map_in 
		WHERE map_out.d_artist = map_in.d_artist 
		AND COALESCE(map_out.d_alias,'') = COALESCE(map_in.d_alias,'') 
		HAVING count(1) > 1)
AND mb_artist != 
	(select mb_artist from discogs.dmap_artist map_in, musicbrainz.artist 
		where gid=map_in.mb_artist and map_in.d_artist=map_out.d_artist 
		and map_in.d_alias=map_out.d_alias 
		order by least(
			levenshtein(COALESCE(map_in.d_alias, map_in.d_artist), name, 1, 10, 10),
			(select 
				min(levenshtein(COALESCE(map_in.d_alias, map_in.d_artist), alias.name, 1, 10, 10))
			 from musicbrainz.artistalias alias where alias.id = artist.id))
	 asc limit 1);

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_dmap_artist';

$$;


--
-- Name: upd_dmap_label(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION upd_dmap_label() RETURNS void
    LANGUAGE sql
    AS $$

TRUNCATE discogs.dmap_label;

INSERT INTO discogs.dmap_label
SELECT * FROM discogs.dmap_label_v;

DELETE FROM discogs.dmap_label map_out
WHERE d_label in (select d_label from discogs.dmap_label group by d_label having count(1) > 1)
AND mb_label != (select mb_label from discogs.dmap_label map_in, musicbrainz.label where gid=map_in.mb_label and map_in.d_label=map_out.d_label order by levenshtein(name, map_in.d_label) asc limit 1);

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_dmap_label';

$$;


--
-- Name: upd_dmap_release(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION upd_dmap_release() RETURNS void
    LANGUAGE sql
    AS $$

TRUNCATE discogs.dmap_release;

INSERT INTO discogs.dmap_release
SELECT * FROM discogs.dmap_release_v;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_dmap_release';

$$;


--
-- Name: upd_dmap_track(); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION upd_dmap_track() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

truncate discogs.dmap_track;

insert into discogs.dmap_track
select t.gid mb_track, d_track
from discogs.tmp_discogs_trackmap_step_03_samepos tmap, musicbrainz.track t
where
tmap.mb_track = t.id AND
(
d_title = mb_title OR
d_title_full = mb_title_full OR
levenshtein(substring(d_title for 255), mb_title) < 4 OR
levenshtein(substring(d_title_full for 255), mb_title_full) < 4
);

drop table discogs.tmp_discogs_trackmap_step_03_samepos;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_dmap_track';

END;
$$;


--
-- Name: urlencode(text); Type: FUNCTION; Schema: discogs; Owner: -
--

CREATE FUNCTION urlencode(INOUT string text) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
	charsmatch RECORD;
	forbiddenchars text;
BEGIN
forbiddenchars := '[^-_.()a-zA-Z0-9]+';
IF (string ~ forbiddenchars) THEN
	FOR charsmatch IN select m[1] charmatch, upper(regexp_replace(encode(replace(m[1], E'\\', E'\\\\')::bytea,'hex'),'(.{2})',E'%\\1', 'g')) charreplace from regexp_matches(string, forbiddenchars, 'g') m LOOP
		string := replace(string, charsmatch.charmatch, charsmatch.charreplace);
	END LOOP;
END IF;
END;$$;


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
-- Name: country; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE country (
    name text NOT NULL
);


--
-- Name: discogs_artist_url; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE discogs_artist_url (
    name text NOT NULL,
    url character varying(255) NOT NULL
);


--
-- Name: discogs_artist_url_v; Type: VIEW; Schema: discogs; Owner: -
--

CREATE VIEW discogs_artist_url_v AS
    SELECT artist.name, (substr(('http://www.discogs.com/artist/'::text || replace(urlencode(artist.name), '%20'::text, '+'::text)), 0, 255))::character varying(255) AS url FROM artist;


--
-- Name: dmap_artist; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE dmap_artist (
    mb_artist character(36) NOT NULL,
    d_artist text NOT NULL,
    d_alias text
);


--
-- Name: dmap_role; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE dmap_role (
    role_name text NOT NULL,
    link_name character varying(50) NOT NULL,
    role_query tsquery,
    attr_name character varying(255)
);


--
-- Name: tracks_extraartists_roles; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE tracks_extraartists_roles (
    artist_name text,
    role_name text,
    role_details text,
    track_id uuid NOT NULL,
    artist_alias text
);


--
-- Name: discogs_credits_for_track; Type: VIEW; Schema: discogs; Owner: -
--

CREATE VIEW discogs_credits_for_track AS
    SELECT txr.artist_name, artist.name, artist.resolution, COALESCE(txr.artist_alias, ''::text) AS artist_alias, COALESCE(txr.artist_alias, txr.artist_name) AS nametext, txr.track_id, lt.id AS link_type FROM tracks_extraartists_roles txr, dmap_artist, dmap_role, musicbrainz.artist, musicbrainz.lt_artist_track lt WHERE (((((txr.artist_name = dmap_artist.d_artist) AND (COALESCE(txr.artist_alias, ''::text) = COALESCE(dmap_artist.d_alias, ''::text))) AND ((dmap_role.link_name)::text = (lt.name)::text)) AND (dmap_role.role_name = txr.role_name)) AND (artist.gid = dmap_artist.mb_artist));


--
-- Name: discogs_label_url; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE discogs_label_url (
    name text NOT NULL,
    url character varying(255) NOT NULL
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
-- Name: discogs_label_url_v; Type: VIEW; Schema: discogs; Owner: -
--

CREATE VIEW discogs_label_url_v AS
    SELECT label.name, (substr(('http://www.discogs.com/label/'::text || replace(urlencode(label.name), '%20'::text, '+'::text)), 0, 255))::character varying(255) AS url FROM label;


--
-- Name: discogs_release_url; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE discogs_release_url (
    discogs_id integer NOT NULL,
    url character varying(255) NOT NULL
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
-- Name: discogs_release_url_v; Type: VIEW; Schema: discogs; Owner: -
--

CREATE VIEW discogs_release_url_v AS
    SELECT release.discogs_id, (substr(('http://www.discogs.com/release/'::text || replace(replace((release.discogs_id)::text, ' '::text, '+'::text), '&'::text, '%26'::text)), 0, 255))::character varying(255) AS url FROM release;


--
-- Name: dmap_artist_v; Type: VIEW; Schema: discogs; Owner: -
--

CREATE VIEW dmap_artist_v AS
    SELECT a.gid AS mb_artist, l.name AS d_artist FROM discogs_artist_url l, musicbrainz.l_artist_url lu, musicbrainz.url u, musicbrainz.artist a, musicbrainz.lt_artist_url lt WHERE (((((lu.link0 = a.id) AND (lu.link_type = lt.id)) AND ((lt.name)::text = 'discogs'::text)) AND (lu.link1 = u.id)) AND ((u.url)::text = (l.url)::text));


--
-- Name: dmap_label; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE dmap_label (
    mb_label character(36) NOT NULL,
    d_label text NOT NULL
);


--
-- Name: dmap_label_v; Type: VIEW; Schema: discogs; Owner: -
--

CREATE VIEW dmap_label_v AS
    SELECT a.gid AS mb_label, l.name AS d_label FROM discogs_label_url l, musicbrainz.l_label_url lu, musicbrainz.url u, musicbrainz.label a, musicbrainz.lt_label_url lt WHERE (((((lu.link0 = a.id) AND (lu.link_type = lt.id)) AND ((lt.name)::text = 'discogs'::text)) AND (lu.link1 = u.id)) AND ((l.url)::text = (u.url)::text));


--
-- Name: dmap_release; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE dmap_release (
    mb_release character(36) NOT NULL,
    d_release integer NOT NULL
);


--
-- Name: dmap_release_v; Type: VIEW; Schema: discogs; Owner: -
--

CREATE VIEW dmap_release_v AS
    SELECT a.gid AS mb_album, l.discogs_id AS d_album FROM discogs_release_url l, musicbrainz.l_album_url lu, musicbrainz.url u, musicbrainz.album a, musicbrainz.lt_album_url lt WHERE (((((lu.link0 = a.id) AND (lu.link_type = lt.id)) AND ((lt.name)::text = 'discogs'::text)) AND (lu.link1 = u.id)) AND ((l.url)::text = (u.url)::text));


--
-- Name: dmap_track; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE dmap_track (
    mb_track character(36) NOT NULL,
    d_track uuid NOT NULL
);


--
-- Name: edits_discogs_memberlist_v; Type: VIEW; Schema: discogs; Owner: -
--

CREATE VIEW edits_discogs_memberlist_v AS
    SELECT a_member.gid AS link0gid, 'artist'::character varying(10) AS link0type, a_group.gid AS link1gid, 'artist'::character varying(10) AS link1type, 111 AS linktype, 'discogs-memberlist'::character varying(30) AS source FROM artist d_group, dmap_artist mb_group, dmap_artist mb_member, musicbrainz.artist a_group, musicbrainz.artist a_member WHERE ((((((((a_member.gid = mb_member.mb_artist) AND (a_group.gid = mb_group.mb_artist)) AND (array_length(d_group.members, 1) > 1)) AND (d_group.name = mb_group.d_artist)) AND (mb_member.d_artist = ANY (d_group.members))) AND (NOT (EXISTS (SELECT 1 FROM musicbrainz.l_artist_artist link WHERE ((link.link0 = a_member.id) AND (link.link1 = a_group.id)))))) AND (array_length(d_group.members, 1) > (SELECT count(*) AS count FROM musicbrainz.l_artist_artist la, musicbrainz.lt_artist_artist lt WHERE (((la.link1 = a_group.id) AND (la.link_type = lt.id)) AND ((lt.name)::text = 'member of band'::text))))) AND (NOT (EXISTS (SELECT 1 FROM mbot.edits_relationship er WHERE ((((er.link0gid = mb_member.mb_artist) AND (er.link1gid = mb_group.mb_artist)) AND ((er.link0type)::text = 'artist'::text)) AND ((er.link1type)::text = 'artist'::text))))));


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
-- Name: mb_track_credits_for_discogs_artist; Type: VIEW; Schema: discogs; Owner: -
--

CREATE VIEW mb_track_credits_for_discogs_artist AS
    SELECT artist.name, artist.resolution, track.gid AS track_gid, dmap_artist.d_artist, COALESCE(dmap_artist.d_alias, ''::text) AS d_alias, l.link_type FROM musicbrainz.l_artist_track l, musicbrainz.track, mbot.mbmap_artist_equiv equiv, musicbrainz.artist, dmap_artist WHERE ((((l.link1 = track.id) AND (l.link0 = artist.id)) AND (artist.gid = equiv.equiv)) AND (equiv.artist = dmap_artist.mb_artist));


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
-- Name: releases_extraartists_roles; Type: TABLE; Schema: discogs; Owner: -
--

CREATE TABLE releases_extraartists_roles (
    discogs_id integer,
    artist_name text,
    role_name text,
    role_details text,
    artist_alias text
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
    trackseq integer,
    durationms integer
);


--
-- Name: track_info; Type: VIEW; Schema: discogs; Owner: -
--

CREATE VIEW track_info AS
    SELECT d_t.track_id, d_t.title AS tracktitle, d_t."position", txr.artist_name, txr.role_name, txr.role_details, release.title AS reltitle, COALESCE(txr.artist_alias, txr.artist_name) AS nametext, dmap_artist.mb_artist, dmap_track.mb_track, rel_url.url, lt.id AS link_type FROM track d_t, dmap_track, discogs_release_url rel_url, tracks_extraartists_roles txr, dmap_artist, dmap_role, musicbrainz.lt_artist_track lt, release WHERE ((((((((dmap_track.d_track = d_t.track_id) AND (rel_url.discogs_id = d_t.discogs_id)) AND (release.discogs_id = d_t.discogs_id)) AND (txr.track_id = d_t.track_id)) AND (txr.artist_name = dmap_artist.d_artist)) AND (COALESCE(txr.artist_alias, ''::text) = COALESCE(dmap_artist.d_alias, ''::text))) AND ((dmap_role.link_name)::text = (lt.name)::text)) AND (dmap_role.role_name = txr.role_name));


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
-- Name: discogs_artist_url_pk; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY discogs_artist_url
    ADD CONSTRAINT discogs_artist_url_pk PRIMARY KEY (name);


--
-- Name: discogs_label_url_pk; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY discogs_label_url
    ADD CONSTRAINT discogs_label_url_pk PRIMARY KEY (name);


--
-- Name: discogs_release_url_pk; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY discogs_release_url
    ADD CONSTRAINT discogs_release_url_pk PRIMARY KEY (discogs_id);


--
-- Name: dmap_role_pk; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY dmap_role
    ADD CONSTRAINT dmap_role_pk PRIMARY KEY (role_name);


--
-- Name: dmap_track_pkey; Type: CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY dmap_track
    ADD CONSTRAINT dmap_track_pkey PRIMARY KEY (mb_track, d_track);


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
-- Name: discogs_artist_url_idx_url; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX discogs_artist_url_idx_url ON discogs_artist_url USING btree (url);


--
-- Name: discogs_label_url_idx_url; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX discogs_label_url_idx_url ON discogs_label_url USING btree (url);


--
-- Name: discogs_release_url_idx_url; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX discogs_release_url_idx_url ON discogs_release_url USING btree (url);


--
-- Name: dmap_artist_mv_dname; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX dmap_artist_mv_dname ON dmap_artist USING btree (d_artist, d_alias);


--
-- Name: dmap_track_idx_d_track; Type: INDEX; Schema: discogs; Owner: -
--

CREATE INDEX dmap_track_idx_d_track ON dmap_track USING btree (d_track);


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
-- Name: dmap_role_gen_tquery; Type: TRIGGER; Schema: discogs; Owner: -
--

CREATE TRIGGER dmap_role_gen_tquery
    BEFORE INSERT OR UPDATE ON dmap_role
    FOR EACH ROW
    EXECUTE PROCEDURE gen_tquery();


--
-- Name: discogs_release_url_fk_discogs_id; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY discogs_release_url
    ADD CONSTRAINT discogs_release_url_fk_discogs_id FOREIGN KEY (discogs_id) REFERENCES release(discogs_id) ON DELETE CASCADE;


--
-- Name: foreign_did; Type: FK CONSTRAINT; Schema: discogs; Owner: -
--

ALTER TABLE ONLY releases_labels
    ADD CONSTRAINT foreign_did FOREIGN KEY (discogs_id) REFERENCES release(discogs_id) ON DELETE CASCADE;


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

