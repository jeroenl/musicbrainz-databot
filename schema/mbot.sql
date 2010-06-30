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
-- Name: mbot; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA mbot;


SET search_path = mbot, pg_catalog;

--
-- Name: find_edits_discogs_trackrole(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION find_edits_discogs_trackrole() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table mbot.tmp_discogs_trackrole_step_06_ready
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

insert into mbot.tmp_discogs_trackrole_step_06_ready
select 
distinct
a.gid link0gid, 'artist'::varchar(10),
t.gid link1gid, 'track'::varchar(10),
link_type linktype, mb_release, 
'discogs-trackrole'::varchar(30) source,
'http://www.discogs.com/release/' || d_release sourceurl
from mbot.tmp_discogs_trackrole_step_05_new tar,
musicbrainz.artist a, musicbrainz.track t
where a.id = mb_artist and t.id = mb_track;

drop table mbot.tmp_discogs_trackrole_step_05_new;

DELETE FROM mbot.edits_relationship_track edits
WHERE (error IS NOT NULL OR date_processed IS NULL)
AND NOT EXISTS 
	(SELECT 1 FROM mbot.tmp_discogs_trackrole_step_06_ready newedits
		WHERE newedits.link0gid = edits.link0gid
		AND newedits.link1gid = edits.link1gid
		AND newedits.link0type = edits.link0type
		AND newedits.link1type = edits.link1type
		AND newedits.linktype = edits.linktype
		AND newedits.source = edits.source);

INSERT INTO mbot.edits_relationship_track 
(link0gid, link0type, link1gid, link1type, linktype, "release", source, sourceurl)
SELECT * FROM mbot.tmp_discogs_trackrole_step_06_ready newedits
WHERE NOT EXISTS
	(SELECT 1 FROM mbot.edits_relationship_track edits
		WHERE newedits.link0gid = edits.link0gid
		AND newedits.link1gid = edits.link1gid
		AND newedits.link0type = edits.link0type
		AND newedits.link1type = edits.link1type
		AND newedits.linktype = edits.linktype
		AND newedits.source = edits.source);

drop table mbot.tmp_discogs_trackrole_step_06_ready;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='find_edits_discogs_trackrole';

END;
$$;


--
-- Name: find_edits_mb_type_from_relations(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION find_edits_mb_type_from_relations() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

CREATE TABLE mbot.tmp_edits_mb_type_from_relations
(
  source character varying(30) NOT NULL,
  artistgid character(36) NOT NULL,
  newtype smallint
)
WITH (
  OIDS=FALSE
);

INSERT INTO mbot.tmp_edits_mb_type_from_relations
SELECT * FROM mbot.edits_mb_type_from_relations_v;

DELETE FROM mbot.edits_artist_typechange edits
WHERE (error IS NOT NULL OR date_processed IS NULL)
AND NOT EXISTS 
	(SELECT 1 FROM mbot.tmp_edits_mb_type_from_relations newedits
		WHERE newedits.artistgid = edits.artistgid);

INSERT INTO mbot.edits_artist_typechange (source, artistgid, newtype)
SELECT * FROM mbot.tmp_edits_mb_type_from_relations newedits
WHERE NOT EXISTS
	(SELECT 1 FROM mbot.edits_artist_typechange edits
		WHERE newedits.artistgid = edits.artistgid);

DROP TABLE mbot.tmp_edits_mb_type_from_relations;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='find_edits_mb_type_from_relations';

END;
$$;


--
-- Name: gen_tquery(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION gen_tquery() RETURNS trigger
    LANGUAGE plpgsql STABLE
    AS $$BEGIN
	NEW.role_query = plainto_tsquery('mbot.english_nostop', NEW.role_name);
	RETURN NEW;
END$$;


--
-- Name: i_edits(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION i_edits() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.edit_type = TG_RELNAME;
	RETURN NEW;
END$$;


--
-- Name: replseq(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION replseq() RETURNS integer
    LANGUAGE sql STABLE
    AS $$SELECT current_replication_sequence FROM musicbrainz.replication_control;$$;


--
-- Name: tmp_discogs_trackmap_step_01(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION tmp_discogs_trackmap_step_01() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table mbot.tmp_discogs_trackmap_step_01
(
d_track uuid not null,
d_release integer not null,
mb_release integer not null,
title text not null,
d_length text not null,
dpos integer not null
);

insert into mbot.tmp_discogs_trackmap_step_01
select t.track_id d_track, t.discogs_id d_release, a.id mb_release, title, duration d_length, trackseq
from discogs.track t, mbot.dmap_release dr, musicbrainz.album a
where dr.d_release = t.discogs_id and a.gid = dr.mb_release;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackmap_step_01';

END;
$$;


--
-- Name: tmp_discogs_trackmap_step_02_mbtrack(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION tmp_discogs_trackmap_step_02_mbtrack() RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN

create table mbot.tmp_discogs_trackmap_step_02_mbtrack
(
d_track uuid not null,
d_title text not null,
d_length integer,
mb_track integer not null,
mb_title text not null,
mb_length integer not null
);

insert into mbot.tmp_discogs_trackmap_step_02_mbtrack
select d_track, title d_title, 
(CAST(replace(substring(d_length from '^[0-9]+:'), ':', '') AS integer) * 60 +
CAST(substring(d_length from '[0-9]+$')  AS integer)) d_length, aj.track mb_track, t.name mb_title, (t.length / 1000) mb_length
from mbot.tmp_discogs_trackmap_step_01 tmap, musicbrainz.albumjoin aj, musicbrainz.track t
where
tmap.mb_release = aj.album and aj."sequence" = dpos and aj.track = t.id;

drop table mbot.tmp_discogs_trackmap_step_01;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackmap_step_02_mbtrack';

END;
$_$;


--
-- Name: tmp_discogs_trackmap_step_03_samepos(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION tmp_discogs_trackmap_step_03_samepos() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table mbot.tmp_discogs_trackmap_step_03_samepos
(
d_track uuid not null,
d_title text not null,
d_title_full text not null,
mb_track integer not null,
mb_title text not null,
mb_title_full text not null
);

insert into mbot.tmp_discogs_trackmap_step_03_samepos
select d_track,
regexp_replace(lower(regexp_replace(d_title, E' \\([^)]+\\)','', 'g')), '[^a-z0-9]', '', 'g'),
regexp_replace(lower(d_title), '[^a-z0-9]', '', 'g'),
mb_track, 
regexp_replace(lower(regexp_replace(mb_title, E' \\([^)]+\\)','', 'g')), '[^a-z0-9]', '', 'g'),
regexp_replace(lower(mb_title), '[^a-z0-9]', '', 'g')
from mbot.tmp_discogs_trackmap_step_02_mbtrack tmap
where
d_length = 0 or mb_length = 0 or abs(d_length - mb_length) < 10;

drop table mbot.tmp_discogs_trackmap_step_02_mbtrack;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackmap_step_03_samepos';

END;
$$;


--
-- Name: tmp_discogs_trackrole_step_01(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION tmp_discogs_trackrole_step_01() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

CREATE TABLE mbot.tmp_discogs_trackrole_step_01
(
mb_artist integer NOT NULL,
role_name TEXT NOT NULL,
d_track uuid NOT NULL
);

INSERT INTO mbot.tmp_discogs_trackrole_step_01
select a.id mb_artist, role_name, track_id
from discogs.tracks_extraartists_roles x, mbot.dmap_artist da, musicbrainz.artist a
where artist_name = d_artist and gid = mb_artist;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackrole_step_01';

END;
$$;


--
-- Name: tmp_discogs_trackrole_step_02_id(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION tmp_discogs_trackrole_step_02_id() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table mbot.tmp_discogs_trackrole_step_02_id
(
mb_artist integer not null,
link_type integer not null,
d_track uuid not null
);

insert into mbot.tmp_discogs_trackrole_step_02_id
select mb_artist, lt.id link_type, d_track
from mbot.tmp_discogs_trackrole_step_01 tar, mbot.dmap_role dr, musicbrainz.lt_artist_track lt
where tar.role_name = dr.role_name and lt.name = dr.link_name;

drop table mbot.tmp_discogs_trackrole_step_01;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackrole_step_02_id';

END;
$$;


--
-- Name: tmp_discogs_trackrole_step_03_mbtrack(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION tmp_discogs_trackrole_step_03_mbtrack() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table mbot.tmp_discogs_trackrole_step_03_mbtrack
(
mb_artist integer not null,
link_type integer not null,
d_release integer not null,
d_track uuid not null,
mb_release integer not null,
mb_track integer not null,
releaseeditcount integer not null
);

insert into mbot.tmp_discogs_trackrole_step_03_mbtrack
select tar.mb_artist, tar.link_type, d_t.discogs_id d_release, tar.d_track, aj.album mb_release, mb_t.id mb_track,
COUNT(1) OVER (PARTITION BY d_t.discogs_id, tar.link_type) as releaseeditcount
from mbot.tmp_discogs_trackrole_step_02_id tar, mbot.dmap_track dt, discogs.track d_t,
musicbrainz.albumjoin aj, musicbrainz.track mb_t
where
tar.d_track = dt.d_track and d_t.track_id = tar.d_track
and aj.track = mb_t.id and mb_t.gid = dt.mb_track;

drop table mbot.tmp_discogs_trackrole_step_02_id;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackrole_step_03_mbtrack';

END;
$$;


--
-- Name: tmp_discogs_trackrole_step_04_allartists(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION tmp_discogs_trackrole_step_04_allartists() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table mbot.tmp_discogs_trackrole_step_04_allartists
(
mb_artist integer not null,
link_type integer not null,
d_release integer not null,
mb_release integer not null,
mb_track integer not null
);

insert into mbot.tmp_discogs_trackrole_step_04_allartists
select tar.mb_artist, tar.link_type, tar.d_release, tar.mb_release, tar.mb_track
from mbot.tmp_discogs_trackrole_step_03_mbtrack tar
where
(select count(1) from discogs.track dt, discogs.tracks_extraartists_roles txr, mbot.dmap_role role, 
musicbrainz.lt_artist_track lt
where txr.role_name = role.role_name and role.link_name = lt.name 
and lt.id = tar.link_type and txr.track_id = dt.track_id and dt.discogs_id = tar.d_release) 
= releaseeditcount;

drop table mbot.tmp_discogs_trackrole_step_03_mbtrack;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackrole_step_04_allartists';

END;
$$;


--
-- Name: tmp_discogs_trackrole_step_05_new(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION tmp_discogs_trackrole_step_05_new() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

create table mbot.tmp_discogs_trackrole_step_05_new
(
mb_artist integer not null,
link_type integer not null,
d_release integer not null,
mb_release integer not null,
mb_track integer not null
);

insert into mbot.tmp_discogs_trackrole_step_05_new
select 
mb_artist, link_type, d_release, mb_release, mb_track
from mbot.tmp_discogs_trackrole_step_04_allartists tar
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

drop table mbot.tmp_discogs_trackrole_step_04_allartists;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='tmp_discogs_trackrole_step_05_new';

END;
$$;


--
-- Name: upd_discogs_artist_url(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION upd_discogs_artist_url() RETURNS void
    LANGUAGE sql
    AS $$

DROP INDEX mbot.discogs_artist_url_idx_url;

TRUNCATE mbot.discogs_artist_url;

INSERT INTO mbot.discogs_artist_url
SELECT * FROM mbot.discogs_artist_url_v;

CREATE INDEX discogs_artist_url_idx_url
  ON mbot.discogs_artist_url
  USING btree
  (url);

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_discogs_artist_url';


$$;


--
-- Name: upd_discogs_label_url(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION upd_discogs_label_url() RETURNS void
    LANGUAGE sql
    AS $$

DROP INDEX mbot.discogs_label_url_idx_url;

TRUNCATE mbot.discogs_label_url;

INSERT INTO mbot.discogs_label_url
SELECT * FROM mbot.discogs_label_url_v;

CREATE INDEX discogs_label_url_idx_url
  ON mbot.discogs_label_url
  USING btree
  (url);

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_discogs_label_url';


$$;


--
-- Name: upd_discogs_release_url(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION upd_discogs_release_url() RETURNS void
    LANGUAGE sql
    AS $$

DROP INDEX IF EXISTS mbot.discogs_release_url_idx_url;

TRUNCATE mbot.discogs_release_url;

INSERT INTO mbot.discogs_release_url
SELECT * FROM mbot.discogs_release_url_v;

CREATE INDEX discogs_release_url_idx_url
  ON mbot.discogs_release_url
  USING btree
  (url);

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_discogs_release_url';


$$;


--
-- Name: upd_dmap_artist(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION upd_dmap_artist() RETURNS void
    LANGUAGE sql
    AS $$

TRUNCATE mbot.dmap_artist;

INSERT INTO mbot.dmap_artist
SELECT * FROM mbot.dmap_artist_v;

DELETE FROM mbot.dmap_artist map_out
WHERE d_artist in (select d_artist from mbot.dmap_artist group by d_artist having count(1) > 1)
AND mb_artist != (select mb_artist from mbot.dmap_artist map_in, musicbrainz.artist where gid=map_in.mb_artist and map_in.d_artist=map_out.d_artist order by levenshtein(name, map_in.d_artist) asc limit 1);

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_dmap_artist';

$$;


--
-- Name: upd_dmap_label(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION upd_dmap_label() RETURNS void
    LANGUAGE sql
    AS $$

TRUNCATE mbot.dmap_label;

INSERT INTO mbot.dmap_label
SELECT * FROM mbot.dmap_label_v;

DELETE FROM mbot.dmap_label map_out
WHERE d_label in (select d_label from mbot.dmap_label group by d_label having count(1) > 1)
AND mb_label != (select mb_label from mbot.dmap_label map_in, musicbrainz.label where gid=map_in.mb_label and map_in.d_label=map_out.d_label order by levenshtein(name, map_in.d_label) asc limit 1);

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_dmap_label';

$$;


--
-- Name: upd_dmap_release(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION upd_dmap_release() RETURNS void
    LANGUAGE sql
    AS $$

TRUNCATE mbot.dmap_release;

INSERT INTO mbot.dmap_release
SELECT * FROM mbot.dmap_release_v;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_dmap_release';

$$;


--
-- Name: upd_dmap_track(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION upd_dmap_track() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

truncate mbot.dmap_track;

insert into mbot.dmap_track
select t.gid mb_track, d_track
from mbot.tmp_discogs_trackmap_step_03_samepos tmap, musicbrainz.track t
where
tmap.mb_track = t.id AND
(
d_title = mb_title OR
d_title_full = mb_title_full OR
levenshtein(substring(d_title for 255), mb_title) < 4 OR
levenshtein(substring(d_title_full for 255), mb_title_full) < 4
);

drop table mbot.tmp_discogs_trackmap_step_03_samepos;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_dmap_track';

END;
$$;


--
-- Name: upd_mb_link_type_descs(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION upd_mb_link_type_descs() RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec RECORD;
	lastcount int;
BEGIN

truncate mbot.mb_link_type_descs;

FOR rec IN SELECT regexp_matches(table_name, '^lt_(.*)_(.*)$') mtch from information_schema.tables where table_schema = 'musicbrainz' and table_name ~ 'lt_' LOOP
	EXECUTE 'insert into mbot.mb_link_type_descs (link_type, desc_type, link0type, link1type)
		select parent, id, ' || quote_literal(rec.mtch[1]) || ', ' || quote_literal(rec.mtch[2]) || ' from musicbrainz.lt_' || rec.mtch[1] || '_' || rec.mtch[2] || '
		where parent != id';
END LOOP;

INSERT INTO mbot.mb_link_type_descs (link_type, desc_type, link0type, link1type)
SELECT desc_type, desc_type, link0type, link1type FROM mbot.mb_link_type_descs;

SELECT INTO rec COUNT(*) count FROM mbot.mb_link_type_descs;
lastcount := -1;
WHILE lastcount < rec.count LOOP
	lastcount := rec.count;
	
	insert into mbot.mb_link_type_descs (link_type, desc_type, link0type, link1type)
	select l1.link_type, l2.desc_type, l1.link0type, l1.link1type
	from mbot.mb_link_type_descs l1, mbot.mb_link_type_descs l2
	where l1.desc_type = l2.link_type 
	and l1.link0type = l2.link0type and l1.link1type = l2.link1type
	and not exists (select 1 from mbot.mb_link_type_descs l3 where l3.link_type = l1.link_type and l3.desc_type = l2.desc_type and l3.link0type = l1.link0type and l3.link1type = l1.link1type);

	SELECT INTO rec COUNT(*) count FROM mbot.mb_link_type_descs;
	RAISE NOTICE 'Last count: %>%', rec.count, lastcount;
END LOOP;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_mb_link_type_descs';

END;
$_$;


--
-- Name: upd_mbmap_artist_equiv(); Type: FUNCTION; Schema: mbot; Owner: -
--

CREATE FUNCTION upd_mbmap_artist_equiv() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	rec RECORD;
	lastcount int;
BEGIN

truncate mbot.mbmap_artist_equiv;

insert into mbot.mbmap_artist_equiv
select a1.gid, a2.gid
from musicbrainz.artist a1, musicbrainz.artist a2,
musicbrainz.l_artist_artist laa, musicbrainz.lt_artist_artist lt
where
laa.link0 = a1.id and laa.link1 = a2.id
and laa.link_type = lt.id and lt.name in ('member of band', 'is person');

SELECT INTO rec COUNT(*) count FROM mbot.mbmap_artist_equiv;
lastcount := -1;
WHILE lastcount < rec.count LOOP
	lastcount := rec.count;
	
	insert into mbot.mbmap_artist_equiv
	select map.artist, a2.gid
	from 
	mbot.mbmap_artist_equiv map,
	musicbrainz.artist a1, musicbrainz.artist a2,
	musicbrainz.l_artist_artist laa, musicbrainz.lt_artist_artist lt
	where
	a1.gid = map.equiv and
	laa.link0 = a1.id and laa.link1 = a2.id
	and laa.link_type = lt.id and lt.name in ('member of band', 'is person')
	and not exists
	(select 1 from mbot.mbmap_artist_equiv map2 where map2.artist = map.artist and map2.equiv = a2.gid);

	SELECT INTO rec COUNT(*) count FROM mbot.mbmap_artist_equiv;
	RAISE NOTICE 'Last count: %>%', rec.count, lastcount;
END LOOP;

insert into mbot.mbmap_artist_equiv
select map1.equiv, map2.equiv
from 
mbot.mbmap_artist_equiv map1,
mbot.mbmap_artist_equiv map2
where
map1.artist = map2.artist
and map1.equiv != map2.equiv
and not exists
(select 1 from mbot.mbmap_artist_equiv map3 where map3.artist = map1.artist and map3.equiv = map2.artist);

INSERT INTO mbot.mbmap_artist_equiv
SELECT DISTINCT map.equiv, map.artist
from mbot.mbmap_artist_equiv map
where map.equiv != map.artist
and not exists
(select 1 from mbot.mbmap_artist_equiv map2 where map2.artist = map.equiv and map2.equiv = map.artist);

INSERT INTO mbot.mbmap_artist_equiv
SELECT artist.gid, artist.gid
from musicbrainz.artist;

UPDATE mbot.tasks SET last_replication=mbot.replseq() WHERE task='upd_mbmap_artist_equiv';

END;
$$;


--
-- Name: urlencode(text); Type: FUNCTION; Schema: mbot; Owner: -
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


--
-- Name: english_nostop; Type: TEXT SEARCH DICTIONARY; Schema: mbot; Owner: -
--

CREATE TEXT SEARCH DICTIONARY english_nostop (
    TEMPLATE = pg_catalog.snowball,
    language = 'english' );


--
-- Name: english_nostop; Type: TEXT SEARCH CONFIGURATION; Schema: mbot; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION english_nostop (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR asciiword WITH english_nostop;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR word WITH english_nostop;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR hword_part WITH english_nostop;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR hword_asciipart WITH english_nostop;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR asciihword WITH english_nostop;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR hword WITH english_nostop;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION english_nostop
    ADD MAPPING FOR uint WITH simple;


SET default_with_oids = false;

--
-- Name: discogs_artist_url; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE discogs_artist_url (
    name text NOT NULL,
    url character varying(255) NOT NULL
);


--
-- Name: discogs_artist_url_v; Type: VIEW; Schema: mbot; Owner: -
--

CREATE VIEW discogs_artist_url_v AS
    SELECT artist.name, (substr(('http://www.discogs.com/artist/'::text || replace(urlencode(artist.name), '%20'::text, '+'::text)), 0, 255))::character varying(255) AS url FROM discogs.artist;


--
-- Name: discogs_label_url; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE discogs_label_url (
    name text NOT NULL,
    url character varying(255) NOT NULL
);


--
-- Name: discogs_label_url_v; Type: VIEW; Schema: mbot; Owner: -
--

CREATE VIEW discogs_label_url_v AS
    SELECT label.name, (substr(('http://www.discogs.com/label/'::text || replace(urlencode(label.name), '%20'::text, '+'::text)), 0, 255))::character varying(255) AS url FROM discogs.label;


--
-- Name: discogs_release_url; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE discogs_release_url (
    discogs_id integer NOT NULL,
    url character varying(255) NOT NULL
);


--
-- Name: discogs_release_url_v; Type: VIEW; Schema: mbot; Owner: -
--

CREATE VIEW discogs_release_url_v AS
    SELECT release.discogs_id, (substr(('http://www.discogs.com/release/'::text || replace(replace((release.discogs_id)::text, ' '::text, '+'::text), '&'::text, '%26'::text)), 0, 255))::character varying(255) AS url FROM discogs.release;


--
-- Name: dmap_artist; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE dmap_artist (
    mb_artist character(36) NOT NULL,
    d_artist text NOT NULL
);


--
-- Name: dmap_artist_v; Type: VIEW; Schema: mbot; Owner: -
--

CREATE VIEW dmap_artist_v AS
    SELECT a.gid AS mb_artist, l.name AS d_artist FROM discogs_artist_url l, musicbrainz.l_artist_url lu, musicbrainz.url u, musicbrainz.artist a, musicbrainz.lt_artist_url lt WHERE (((((lu.link0 = a.id) AND (lu.link_type = lt.id)) AND ((lt.name)::text = 'discogs'::text)) AND (lu.link1 = u.id)) AND ((u.url)::text = (l.url)::text));


--
-- Name: dmap_label; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE dmap_label (
    mb_label character(36) NOT NULL,
    d_label text NOT NULL
);


--
-- Name: dmap_label_v; Type: VIEW; Schema: mbot; Owner: -
--

CREATE VIEW dmap_label_v AS
    SELECT a.gid AS mb_label, l.name AS d_label FROM discogs_label_url l, musicbrainz.l_label_url lu, musicbrainz.url u, musicbrainz.label a, musicbrainz.lt_label_url lt WHERE (((((lu.link0 = a.id) AND (lu.link_type = lt.id)) AND ((lt.name)::text = 'discogs'::text)) AND (lu.link1 = u.id)) AND ((l.url)::text = (u.url)::text));


--
-- Name: dmap_release; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE dmap_release (
    mb_release character(36) NOT NULL,
    d_release integer NOT NULL
);


--
-- Name: dmap_release_v; Type: VIEW; Schema: mbot; Owner: -
--

CREATE VIEW dmap_release_v AS
    SELECT a.gid AS mb_album, l.discogs_id AS d_album FROM discogs_release_url l, musicbrainz.l_album_url lu, musicbrainz.url u, musicbrainz.album a, musicbrainz.lt_album_url lt WHERE (((((lu.link0 = a.id) AND (lu.link_type = lt.id)) AND ((lt.name)::text = 'discogs'::text)) AND (lu.link1 = u.id)) AND ((l.url)::text = (u.url)::text));


--
-- Name: dmap_role; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE dmap_role (
    role_name text NOT NULL,
    link_name character varying(50) NOT NULL,
    role_query tsquery,
    attr_name character varying(255)
);


--
-- Name: dmap_role_full; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE dmap_role_full (
    query tsquery,
    attr integer
);


--
-- Name: dmap_track; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE dmap_track (
    mb_track character(36) NOT NULL,
    d_track uuid NOT NULL
);


--
-- Name: edits; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE edits (
    id integer NOT NULL,
    edit_type character varying(30) NOT NULL,
    source character varying(30) NOT NULL,
    date_added timestamp with time zone DEFAULT now() NOT NULL,
    date_processed timestamp with time zone,
    error text
);


--
-- Name: edits_id_seq; Type: SEQUENCE; Schema: mbot; Owner: -
--

CREATE SEQUENCE edits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: edits_id_seq; Type: SEQUENCE OWNED BY; Schema: mbot; Owner: -
--

ALTER SEQUENCE edits_id_seq OWNED BY edits.id;


--
-- Name: edits_artist_typechange; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE edits_artist_typechange (
    newtype smallint,
    artistgid character(36) NOT NULL
)
INHERITS (edits);


--
-- Name: edits_relationship; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE edits_relationship (
    link0type character varying(10) NOT NULL,
    link1type character varying(10) NOT NULL,
    linktype integer NOT NULL,
    link0gid character(36) NOT NULL,
    link1gid character(36) NOT NULL
)
INHERITS (edits);


--
-- Name: edits_discogs_memberlist_v; Type: VIEW; Schema: mbot; Owner: -
--

CREATE VIEW edits_discogs_memberlist_v AS
    SELECT a_member.gid AS link0gid, 'artist'::character varying(10) AS link0type, a_group.gid AS link1gid, 'artist'::character varying(10) AS link1type, 111 AS linktype, 'discogs-memberlist'::character varying(30) AS source FROM discogs.artist d_group, dmap_artist mb_group, dmap_artist mb_member, musicbrainz.artist a_group, musicbrainz.artist a_member WHERE ((((((((a_member.gid = mb_member.mb_artist) AND (a_group.gid = mb_group.mb_artist)) AND (array_length(d_group.members, 1) > 1)) AND (d_group.name = mb_group.d_artist)) AND (mb_member.d_artist = ANY (d_group.members))) AND (NOT (EXISTS (SELECT 1 FROM musicbrainz.l_artist_artist link WHERE ((link.link0 = a_member.id) AND (link.link1 = a_group.id)))))) AND (array_length(d_group.members, 1) > (SELECT count(*) AS count FROM musicbrainz.l_artist_artist la, musicbrainz.lt_artist_artist lt WHERE (((la.link1 = a_group.id) AND (la.link_type = lt.id)) AND ((lt.name)::text = 'member of band'::text))))) AND (NOT (EXISTS (SELECT 1 FROM edits_relationship er WHERE ((((er.link0gid = mb_member.mb_artist) AND (er.link1gid = mb_group.mb_artist)) AND ((er.link0type)::text = 'artist'::text)) AND ((er.link1type)::text = 'artist'::text))))));


--
-- Name: edits_mb_type_from_relations_v; Type: VIEW; Schema: mbot; Owner: -
--

CREATE VIEW edits_mb_type_from_relations_v AS
    SELECT 'mb_type_from_relations'::character varying(30) AS source, q.gid AS artistgid, sum(q.type) AS newtype FROM (SELECT a.gid, 2 AS type FROM musicbrainz.artist a, musicbrainz.l_artist_artist la, musicbrainz.lt_artist_artist lt WHERE ((((a.type IS NULL) AND (la.link1 = a.id)) AND (la.link_type = lt.id)) AND ((lt.name)::text = ANY (ARRAY['member of band'::text, 'collaboration'::text]))) UNION SELECT a.gid, 1 AS type FROM musicbrainz.artist a, musicbrainz.l_artist_artist la, musicbrainz.lt_artist_artist lt WHERE ((((a.type IS NULL) AND ((la.link0 = a.id) OR (la.link1 = a.id))) AND (la.link_type = lt.id)) AND ((lt.name)::text = ANY (ARRAY['parent'::text, 'sibling'::text, 'married'::text, 'involved with'::text, 'is person'::text])))) q GROUP BY q.gid HAVING (count(*) = 1);


--
-- Name: edits_relationship_track; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE edits_relationship_track (
    release integer NOT NULL,
    sourceurl character varying(100)
)
INHERITS (edits_relationship);


--
-- Name: mb_link_type_descs; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE mb_link_type_descs (
    link_type integer NOT NULL,
    desc_type integer NOT NULL,
    link0type character varying(10),
    link1type character varying(10)
);


--
-- Name: mbmap_artist_equiv; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE mbmap_artist_equiv (
    artist character(36) NOT NULL,
    equiv character(36) NOT NULL
);


--
-- Name: mbmap_official_id; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE mbmap_official_id (
    gid uuid NOT NULL,
    type character varying(10) NOT NULL,
    official_id integer NOT NULL
);


--
-- Name: tasks; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE tasks (
    task character varying(40) NOT NULL,
    last_replication integer DEFAULT 0 NOT NULL,
    frequency integer DEFAULT 1 NOT NULL,
    priority integer DEFAULT 100 NOT NULL
);


--
-- Name: id; Type: DEFAULT; Schema: mbot; Owner: -
--

ALTER TABLE edits ALTER COLUMN id SET DEFAULT nextval('edits_id_seq'::regclass);


--
-- Name: discogs_artist_url_pk; Type: CONSTRAINT; Schema: mbot; Owner: -
--

ALTER TABLE ONLY discogs_artist_url
    ADD CONSTRAINT discogs_artist_url_pk PRIMARY KEY (name);


--
-- Name: discogs_label_url_pk; Type: CONSTRAINT; Schema: mbot; Owner: -
--

ALTER TABLE ONLY discogs_label_url
    ADD CONSTRAINT discogs_label_url_pk PRIMARY KEY (name);


--
-- Name: discogs_release_url_pk; Type: CONSTRAINT; Schema: mbot; Owner: -
--

ALTER TABLE ONLY discogs_release_url
    ADD CONSTRAINT discogs_release_url_pk PRIMARY KEY (discogs_id);


--
-- Name: dmap_role_pk; Type: CONSTRAINT; Schema: mbot; Owner: -
--

ALTER TABLE ONLY dmap_role
    ADD CONSTRAINT dmap_role_pk PRIMARY KEY (role_name);


--
-- Name: dmap_track_pkey; Type: CONSTRAINT; Schema: mbot; Owner: -
--

ALTER TABLE ONLY dmap_track
    ADD CONSTRAINT dmap_track_pkey PRIMARY KEY (mb_track, d_track);


--
-- Name: edits_artist_typechange_pk; Type: CONSTRAINT; Schema: mbot; Owner: -
--

ALTER TABLE ONLY edits_artist_typechange
    ADD CONSTRAINT edits_artist_typechange_pk PRIMARY KEY (id);


--
-- Name: edits_pk; Type: CONSTRAINT; Schema: mbot; Owner: -
--

ALTER TABLE ONLY edits
    ADD CONSTRAINT edits_pk PRIMARY KEY (id);


--
-- Name: mbmap_official_id_pk; Type: CONSTRAINT; Schema: mbot; Owner: -
--

ALTER TABLE ONLY mbmap_official_id
    ADD CONSTRAINT mbmap_official_id_pk PRIMARY KEY (type, gid);


--
-- Name: tasks_pk; Type: CONSTRAINT; Schema: mbot; Owner: -
--

ALTER TABLE ONLY tasks
    ADD CONSTRAINT tasks_pk PRIMARY KEY (task);


--
-- Name: discogs_artist_url_idx_url; Type: INDEX; Schema: mbot; Owner: -
--

CREATE INDEX discogs_artist_url_idx_url ON discogs_artist_url USING btree (url);


--
-- Name: discogs_label_url_idx_url; Type: INDEX; Schema: mbot; Owner: -
--

CREATE INDEX discogs_label_url_idx_url ON discogs_label_url USING btree (url);


--
-- Name: discogs_release_url_idx_url; Type: INDEX; Schema: mbot; Owner: -
--

CREATE INDEX discogs_release_url_idx_url ON discogs_release_url USING btree (url);


--
-- Name: dmap_artist_mv_dname; Type: INDEX; Schema: mbot; Owner: -
--

CREATE INDEX dmap_artist_mv_dname ON dmap_artist USING btree (d_artist);


--
-- Name: dmap_track_idx_d_track; Type: INDEX; Schema: mbot; Owner: -
--

CREATE INDEX dmap_track_idx_d_track ON dmap_track USING btree (d_track);


--
-- Name: edit_relationship_track_idx_release; Type: INDEX; Schema: mbot; Owner: -
--

CREATE INDEX edit_relationship_track_idx_release ON edits_relationship_track USING btree (release);

ALTER TABLE edits_relationship_track CLUSTER ON edit_relationship_track_idx_release;


--
-- Name: mb_link_type_descs_idx_link_type; Type: INDEX; Schema: mbot; Owner: -
--

CREATE INDEX mb_link_type_descs_idx_link_type ON mb_link_type_descs USING btree (link_type);


--
-- Name: mbmap_artist_equiv_idx_artist; Type: INDEX; Schema: mbot; Owner: -
--

CREATE INDEX mbmap_artist_equiv_idx_artist ON mbmap_artist_equiv USING btree (artist);


--
-- Name: dmap_role_gen_tquery; Type: TRIGGER; Schema: mbot; Owner: -
--

CREATE TRIGGER dmap_role_gen_tquery
    BEFORE INSERT OR UPDATE ON dmap_role
    FOR EACH ROW
    EXECUTE PROCEDURE gen_tquery();


--
-- Name: fill_edittype; Type: TRIGGER; Schema: mbot; Owner: -
--

CREATE TRIGGER fill_edittype
    BEFORE INSERT ON edits_artist_typechange
    FOR EACH ROW
    EXECUTE PROCEDURE i_edits();


--
-- Name: fill_edittype; Type: TRIGGER; Schema: mbot; Owner: -
--

CREATE TRIGGER fill_edittype
    BEFORE INSERT ON edits_relationship
    FOR EACH ROW
    EXECUTE PROCEDURE i_edits();


--
-- Name: fill_edittype; Type: TRIGGER; Schema: mbot; Owner: -
--

CREATE TRIGGER fill_edittype
    BEFORE INSERT ON edits_relationship_track
    FOR EACH ROW
    EXECUTE PROCEDURE i_edits();


--
-- PostgreSQL database dump complete
--

