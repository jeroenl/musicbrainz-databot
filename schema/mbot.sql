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
-- Name: edits_artist_typechange; Type: TABLE; Schema: mbot; Owner: -
--

CREATE TABLE edits_artist_typechange (
    newtype smallint,
    artistgid character(36) NOT NULL
)
INHERITS (edits);


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
    priority integer DEFAULT 100 NOT NULL,
    schema character varying(40) DEFAULT 'mbot'::character varying NOT NULL
);


--
-- Name: id; Type: DEFAULT; Schema: mbot; Owner: -
--

ALTER TABLE edits ALTER COLUMN id SET DEFAULT nextval('edits_id_seq'::regclass);


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

