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
-- Name: musicbrainz; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA musicbrainz;


SET search_path = musicbrainz, pg_catalog;

--
-- Name: a_del_album_amazon_asin(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_del_album_amazon_asin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE set_album_asin(OLD.album);
    RETURN OLD;
END;
$$;


--
-- Name: a_del_album_cdtoc(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_del_album_cdtoc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    UPDATE  albummeta
    SET     discids = discids - 1,
            lastupdate = now()
    WHERE   id = OLD.album;
    PERFORM propagate_lastupdate(OLD.album, CAST('album' AS name));

    return NULL;
end;
$$;


--
-- Name: a_del_albumjoin(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_del_albumjoin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    UPDATE  albummeta
    SET     tracks = tracks - 1,
            puids = puids - (SELECT COUNT(*) FROM puidjoin WHERE track = OLD.track)
    WHERE   id = OLD.album;

    return NULL;
end;
$$;


--
-- Name: a_del_puidjoin(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_del_puidjoin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    UPDATE  albummeta
    SET     puids = puids - 1
    WHERE   id IN (SELECT album FROM albumjoin WHERE track = OLD.track);

    return NULL;
end;
$$;


--
-- Name: a_del_release(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_del_release() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE set_album_firstreleasedate(OLD.album);
    RETURN OLD;
END;
$$;


--
-- Name: a_del_tag(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_del_tag() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
    ref_count integer;
begin

    SELECT INTO ref_count refcount FROM tag WHERE id = OLD.tag;
    IF ref_count = 1 THEN
         DELETE FROM tag WHERE id = OLD.tag;
    ELSE
         UPDATE  tag
         SET     refcount = refcount - 1
         WHERE   id = OLD.tag;
    END IF;

    return NULL;
end;
$$;


--
-- Name: a_idu_puid_stat(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_idu_puid_stat() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE')
    THEN
        UPDATE puid SET lookupcount = (SELECT COALESCE(SUM(puid_stat.lookupcount), 0) FROM puid_stat WHERE puid_id = NEW.puid_id) WHERE id = NEW.puid_id;
        IF (TG_OP = 'UPDATE')
        THEN
            IF (NEW.puid_id != OLD.puid_id)
            THEN
                UPDATE puid SET lookupcount = (SELECT COALESCE(SUM(puid_stat.lookupcount), 0) FROM puid_stat WHERE puid_id = OLD.puid_id) WHERE id = OLD.puid_id;
            END IF;
        END IF;
    ELSE
        UPDATE puid SET lookupcount = (SELECT COALESCE(SUM(puid_stat.lookupcount), 0) FROM puid_stat WHERE puid_id = OLD.puid_id) WHERE id = OLD.puid_id;
    END IF;

    RETURN NULL;
END;
$$;


--
-- Name: a_idu_puidjoin_stat(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_idu_puidjoin_stat() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE')
    THEN
        UPDATE puidjoin SET usecount = (SELECT COALESCE(SUM(puidjoin_stat.usecount), 0) FROM puidjoin_stat WHERE puidjoin_id = NEW.puidjoin_id) WHERE id = NEW.puidjoin_id;
        IF (TG_OP = 'UPDATE')
        THEN
            IF (NEW.puidjoin_id != OLD.puidjoin_id)
            THEN
                UPDATE puidjoin SET usecount = (SELECT COALESCE(SUM(puidjoin_stat.usecount), 0) FROM puidjoin_stat WHERE puidjoin_id = OLD.puidjoin_id) WHERE id = OLD.puidjoin_id;
            END IF;
        END IF;
    ELSE
        UPDATE puidjoin SET usecount = (SELECT COALESCE(SUM(puidjoin_stat.usecount), 0) FROM puidjoin_stat WHERE puidjoin_id = OLD.puidjoin_id) WHERE id = OLD.puidjoin_id;
    END IF;

    RETURN NULL;
END;
$$;


--
-- Name: a_ins_album_amazon_asin(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_ins_album_amazon_asin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE set_album_asin(NEW.album);
    RETURN NEW;
END;
$$;


--
-- Name: a_ins_album_cdtoc(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_ins_album_cdtoc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ 
begin
    UPDATE  albummeta
    SET     discids = discids + 1,
            lastupdate = now()
    WHERE   id = NEW.album;
    PERFORM propagate_lastupdate(NEW.album, CAST('album' AS name));

    return NULL;
end;
$$;


--
-- Name: a_ins_albumjoin(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_ins_albumjoin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    UPDATE  albummeta
    SET     tracks = tracks + 1,
            puids = puids + (SELECT COUNT(*) FROM puidjoin WHERE track = NEW.track)
    WHERE   id = NEW.album;
    PERFORM propagate_lastupdate(NEW.track, CAST('track' AS name));

    return NULL;
end;
$$;


--
-- Name: a_ins_puidjoin(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_ins_puidjoin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    UPDATE  albummeta
    SET     puids = puids + 1
    WHERE   id IN (SELECT album FROM albumjoin WHERE track = NEW.track);

    return NULL;
end;
$$;


--
-- Name: a_ins_release(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_ins_release() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE set_album_firstreleasedate(NEW.album);
    PERFORM propagate_lastupdate(NEW.id, CAST('release' AS name));
    RETURN NEW;
END;
$$;


--
-- Name: a_ins_tag(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_ins_tag() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    UPDATE  tag
    SET     refcount = refcount + 1
    WHERE   id = NEW.tag;

    return NULL;
end;
$$;


--
-- Name: a_iu_entity(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_iu_entity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin 
    IF (TG_OP = 'INSERT') 
    THEN
        EXECUTE 'INSERT INTO ' || TG_RELNAME || '_meta (id) VALUES (' || NEW.id || ')';
        PERFORM propagate_lastupdate(NEW.id, TG_RELNAME);
    ELSIF (TG_OP = 'UPDATE')
    THEN
        IF (NEW.modpending = OLD.modpending)
        THEN
            IF (TG_RELNAME != 'track')
            THEN
                EXECUTE 'UPDATE ' || TG_RELNAME || '_meta SET lastupdate = now() WHERE id = ' || NEW.id; 
            END IF;
            PERFORM propagate_lastupdate(NEW.id, TG_RELNAME);
        END IF;             
    END IF;
    RETURN NULL; 
end; 
$$;


--
-- Name: a_upd_album_amazon_asin(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_upd_album_amazon_asin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE set_album_asin(NEW.album);
    IF (OLD.album != NEW.album)
    THEN
        EXECUTE set_album_asin(OLD.album);
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: a_upd_album_cdtoc(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_upd_album_cdtoc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if NEW.album = OLD.album
    then
        return NULL;
    end if;

    UPDATE  albummeta
    SET     discids = discids - 1,
            lastupdate = now()
    WHERE   id = OLD.album;
    PERFORM propagate_lastupdate(OLD.album, CAST('album' AS name));

    UPDATE  albummeta
    SET     discids = discids + 1,
            lastupdate = now()
    WHERE   id = NEW.album;
    PERFORM propagate_lastupdate(NEW.album, CAST('album' AS name));

    return NULL;
end;
$$;


--
-- Name: a_upd_albumjoin(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_upd_albumjoin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if NEW.album = OLD.album AND NEW.track = OLD.track
    then
        -- Sequence has been changed
        IF (NEW.modpending = OLD.modpending) 
        THEN
            PERFORM propagate_lastupdate(OLD.track, CAST('track' AS name));
        END IF;

    elsif NEW.track = OLD.track
    then
        -- A track is moved from an album to another one
        UPDATE  albummeta
        SET     tracks = tracks - 1,
                puids = puids - (SELECT COUNT(*) FROM puidjoin WHERE track = OLD.track),
                lastupdate = now()
        WHERE   id = OLD.album;
        -- For the old album we can't do anything better than propagete lastupdate at the album level
        PERFORM propagate_lastupdate(OLD.album, CAST('album' AS name));

        UPDATE  albummeta
        SET     tracks = tracks + 1,
                puids = puids + (SELECT COUNT(*) FROM puidjoin WHERE track = NEW.track)
        WHERE   id = NEW.album;
        PERFORM propagate_lastupdate(NEW.track, CAST('track' AS name));

    elsif NEW.album = OLD.album
    then
        -- TODO: should not happen yet
    end if;

    return NULL;
end;
$$;


--
-- Name: a_upd_puidjoin(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_upd_puidjoin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if NEW.track = OLD.track
    then
        return NULL;
    end if;

    UPDATE  albummeta
    SET     puids = puids - 1
    WHERE   id IN (SELECT album FROM albumjoin WHERE track = OLD.track);

    UPDATE  albummeta
    SET     puids = puids + 1
    WHERE   id IN (SELECT album FROM albumjoin WHERE track = NEW.track);

    return NULL;
end;
$$;


--
-- Name: a_upd_release(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION a_upd_release() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (OLD.modpending = NEW.modpending)
    THEN
        EXECUTE set_album_firstreleasedate(NEW.album);
        PERFORM propagate_lastupdate(NEW.id, CAST('release' AS name));

        IF (OLD.album != NEW.album)
        THEN
            EXECUTE set_album_firstreleasedate(OLD.album);
            -- propagate_lastupdate not called since OLD.album is probably
            -- being merged in NEW.album
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: after_update_moderation_open(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION after_update_moderation_open() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin

    if (OLD.status IN (1,8) and NEW.status NOT IN (1,8)) -- STATUS_OPEN, STATUS_TOBEDELETED
    then
        -- Create moderation_closed record
        INSERT INTO moderation_closed SELECT * FROM moderation_open WHERE id = NEW.id;
        -- and update the closetime
        UPDATE moderation_closed SET closetime = NOW() WHERE id = NEW.id;

        -- Copy notes
        INSERT INTO moderation_note_closed
            SELECT * FROM moderation_note_open
            WHERE moderation = NEW.id;

        -- Copy votes
        INSERT INTO vote_closed
            SELECT * FROM vote_open
            WHERE moderation = NEW.id;

        -- Delete the _open records
        DELETE FROM vote_open WHERE moderation = NEW.id;
        DELETE FROM moderation_note_open WHERE moderation = NEW.id;
        DELETE FROM moderation_open WHERE id = NEW.id;
    end if;

    return NEW;
end;
$$;


--
-- Name: b_del_albumjoin(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION b_del_albumjoin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin 
    PERFORM propagate_lastupdate(OLD.track, CAST('track' AS name));
    RETURN OLD; 
end;
$$;


--
-- Name: b_del_entity(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION b_del_entity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin 
    IF (TG_RELNAME = 'album')
    THEN
        PERFORM set_release_group_firstreleasedate(OLD.release_group);
        UPDATE release_group_meta SET releasecount = releasecount - 1 WHERE id=OLD.release_group;
    END IF;
    PERFORM propagate_lastupdate(OLD.id, TG_RELNAME);
    RETURN OLD; 
end;
$$;


--
-- Name: before_insertupdate_release(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION before_insertupdate_release() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    y CHAR(4);
    m CHAR(2);
    d CHAR(2);
    teststr VARCHAR(10);
    testdate DATE;
BEGIN
    -- Check that the releasedate looks like this: yyyy-mm-dd
    IF (NOT(NEW.releasedate ~ '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$'))
    THEN
        RAISE EXCEPTION 'Invalid release date specification';
    END IF;

    y := SUBSTR(NEW.releasedate, 1, 4);
    m := SUBSTR(NEW.releasedate, 6, 2);
    d := SUBSTR(NEW.releasedate, 9, 2);

    -- Disallow yyyy-00-dd
    IF (m = '00' AND d != '00')
    THEN
        RAISE EXCEPTION 'Invalid release date specification';
    END IF;

    -- Check that the y/m/d combination is valid (e.g. disallow 2003-02-31)
    IF (m = '00') THEN m:= '01'; END IF;
    IF (d = '00') THEN d:= '01'; END IF;
    teststr := ( y || '-' || m || '-' || d );
    -- TO_DATE allows 2003-08-32 etc (it becomes 2003-09-01)
    -- So we will use the ::date cast, which catches this error
    testdate := teststr;

    RETURN NEW;
END;
$_$;


--
-- Name: fill_album_meta(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION fill_album_meta() RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare

   table_count integer;

begin

   raise notice 'Truncating table albummeta';
   truncate table albummeta;

   raise notice 'Counting tracks';
   create temporary table albummeta_tracks as select album.id, count(albumjoin.album) 
                from album left join albumjoin on album.id = albumjoin.album group by album.id;

   raise notice 'Counting discids';
   create temporary table albummeta_discids as select album.id, count(album_cdtoc.album) 
                from album left join album_cdtoc on album.id = album_cdtoc.album group by album.id;

   raise notice 'Counting puids';
   create temporary table albummeta_puids as select album.id, count(puidjoin.track) 
                from album, albumjoin left join puidjoin on albumjoin.track = puidjoin.track 
                where album.id = albumjoin.album group by album.id;

    raise notice 'Finding first release dates';
    CREATE TEMPORARY TABLE albummeta_firstreleasedate AS
        SELECT  album AS id, MIN(releasedate)::CHAR(10) AS firstreleasedate
        FROM    release
        GROUP BY album;

   raise notice 'Filling albummeta table';
   insert into albummeta (id, tracks, discids, puids, firstreleasedate, asin, coverarturl, dateadded, lastupdate)
   select a.id,
            COALESCE(t.count, 0) AS tracks,
            COALESCE(d.count, 0) AS discids,
            COALESCE(p.count, 0) AS puids,
            r.firstreleasedate,
            aws.asin,
            aws.coverarturl,
            timestamp '1970-01-01 00:00:00-00',
            NULL
    FROM    album a
            LEFT JOIN albummeta_tracks t ON t.id = a.id
            LEFT JOIN albummeta_discids d ON d.id = a.id
            LEFT JOIN albummeta_puids p ON p.id = a.id
            LEFT JOIN albummeta_firstreleasedate r ON r.id = a.id
            LEFT JOIN album_amazon_asin aws on aws.album = a.id
            ;

   drop table albummeta_tracks;
   drop table albummeta_discids;
   drop table albummeta_puids;
   drop table albummeta_firstreleasedate;

   return 1;

end;
$$;


--
-- Name: from_hex(text); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION from_hex(t text) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN EXECUTE 'SELECT x'''||t||'''::integer AS hex' LOOP
        RETURN r.hex;
    END LOOP;
END
$$;


--
-- Name: generate_uuid_v3(character varying, character varying); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION generate_uuid_v3(namespace character varying, name character varying) RETURNS character varying
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    value varchar(36);
    bytes varchar;
BEGIN
    bytes = md5(decode(namespace, 'hex') || decode(name, 'escape'));
    value = substr(bytes, 1+0, 8);
    value = value || '-';
    value = value || substr(bytes, 1+2*4, 4);
    value = value || '-';
    value = value || lpad(to_hex((from_hex(substr(bytes, 1+2*6, 2)) & 15) | 48), 2, '0');
    value = value || substr(bytes, 1+2*7, 2);
    value = value || '-';
    value = value || lpad(to_hex((from_hex(substr(bytes, 1+2*8, 2)) & 63) | 128), 2, '0');
    value = value || substr(bytes, 1+2*9, 2);
    value = value || '-';
    value = value || substr(bytes, 1+2*10, 12);
    return value;
END;
$$;


--
-- Name: generate_uuid_v4(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION generate_uuid_v4() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    value VARCHAR(36);
BEGIN
    value =          lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || '-';
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || '-';
    value = value || lpad((to_hex((ceil(random() * 255)::int & 15) | 64)), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || '-';
    value = value || lpad((to_hex((ceil(random() * 255)::int & 63) | 128)), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || '-';
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    value = value || lpad(to_hex(ceil(random() * 255)::int), 2, '0');
    RETURN value;
END;
$$;


--
-- Name: insert_album_meta(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION insert_album_meta() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin 
    insert into albummeta (id, tracks, discids, puids, lastupdate) values (NEW.id, 0, 0, 0, now()); 
    insert into album_amazon_asin (album, lastupdate) values (NEW.id, '1970-01-01 00:00:00'); 
    PERFORM propagate_lastupdate(NEW.id, CAST('album' AS name));
    UPDATE release_group_meta SET releasecount = releasecount + 1 WHERE id=NEW.release_group;
    
    return NEW; 
end; 
$$;


--
-- Name: join_append(character varying, character varying); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION join_append(character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
    state ALIAS FOR $1;
    value ALIAS FOR $2;
BEGIN
    IF (value IS NULL) THEN RETURN state; END IF;
    IF (state IS NULL) THEN
        RETURN value;
    ELSE
        RETURN(state || ' ' || value);
    END IF;
END;
$_$;


--
-- Name: propagate_lastupdate(integer, name); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION propagate_lastupdate(entity_id integer, relname name) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin 

--- This function caused the entire database to slow to a crawl and has been removed for now.
--- This functionality will have to be carefully re-considered in the future.

end; 
$$;


--
-- Name: set_album_asin(integer); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION set_album_asin(integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    UPDATE albummeta SET coverarturl = (
        SELECT coverarturl FROM album_amazon_asin WHERE album = $1
    ), asin = (
        SELECT asin FROM album_amazon_asin WHERE album = $1
    ) WHERE id = $1
        -- Test if album still exists (sanity check)
        AND EXISTS (SELECT 1 FROM album where id = $1);
    RETURN;
END;
$_$;


--
-- Name: set_album_firstreleasedate(integer); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION set_album_firstreleasedate(integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    release_group_id INTEGER;
BEGIN
    UPDATE albummeta SET firstreleasedate = (
        SELECT MIN(releasedate) FROM release WHERE album = $1
           AND releasedate <> '0000-00-00' AND releasedate IS NOT NULL
    ), lastupdate = now() WHERE id = $1;
    release_group_id := (SELECT release_group FROM album WHERE id = $1);
    EXECUTE set_release_group_firstreleasedate(release_group_id);
    RETURN;
END;
$_$;


--
-- Name: set_release_group_firstreleasedate(integer); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION set_release_group_firstreleasedate(release_group_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE release_group_meta SET firstreleasedate = (
        SELECT MIN(firstreleasedate) FROM albummeta, album WHERE album.id = albummeta.id
           AND release_group = release_group_id AND firstreleasedate <> '0000-00-00' AND firstreleasedate IS NOT NULL
    ) WHERE id = release_group_id;
    RETURN;
END;
$$;


--
-- Name: update_album_meta(); Type: FUNCTION; Schema: musicbrainz; Owner: -
--

CREATE FUNCTION update_album_meta() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    IF (NEW.name != OLD.name) 
    THEN
        UPDATE album_amazon_asin SET lastupdate = '1970-01-01 00:00:00' WHERE album = NEW.id; 
    END IF;
    IF (NEW.release_group != OLD.release_group)
    THEN
        PERFORM set_release_group_firstreleasedate(OLD.release_group);
        PERFORM set_release_group_firstreleasedate(NEW.release_group);
        UPDATE release_group_meta SET releasecount = releasecount - 1 WHERE id=OLD.release_group;
        UPDATE release_group_meta SET releasecount = releasecount + 1 WHERE id=NEW.release_group;
    END IF;
    IF (NEW.modpending = OLD.modpending)
    THEN
        UPDATE albummeta SET lastupdate = now() WHERE id = NEW.id; 
        PERFORM propagate_lastupdate(NEW.id, CAST('album' AS name));
    END IF;
   return NULL;
end;
$$;


--
-- Name: join(character varying); Type: AGGREGATE; Schema: musicbrainz; Owner: -
--

CREATE AGGREGATE "join"(character varying) (
    SFUNC = join_append,
    STYPE = character varying
);


SET default_with_oids = false;

--
-- Name: artist; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE artist (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    gid character(36) NOT NULL,
    modpending integer DEFAULT 0,
    sortname character varying(255) NOT NULL,
    page integer NOT NULL,
    resolution character varying(64),
    begindate character(10),
    enddate character(10),
    type smallint,
    quality smallint DEFAULT (-1),
    modpending_qual integer DEFAULT 0
);


--
-- Name: l_artist_url; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_artist_url (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_artist_url; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_artist_url (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: url; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE url (
    id integer NOT NULL,
    gid character(36) NOT NULL,
    url character varying(255) NOT NULL,
    description text NOT NULL,
    refcount integer DEFAULT 0 NOT NULL,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: l_label_url; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_label_url (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: label; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE label (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    gid character(36) NOT NULL,
    modpending integer DEFAULT 0,
    labelcode integer,
    sortname character varying(255) NOT NULL,
    country integer,
    page integer NOT NULL,
    resolution character varying(64),
    begindate character(10),
    enddate character(10),
    type smallint
);


--
-- Name: lt_label_url; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_label_url (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: album; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE album (
    id integer NOT NULL,
    artist integer NOT NULL,
    name character varying(255) NOT NULL,
    gid character(36) NOT NULL,
    modpending integer DEFAULT 0,
    attributes integer[] DEFAULT '{0}'::integer[],
    page integer NOT NULL,
    language integer,
    script integer,
    modpending_lang integer,
    quality smallint DEFAULT (-1),
    modpending_qual integer DEFAULT 0,
    release_group integer NOT NULL
);


--
-- Name: l_album_url; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_album_url (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_album_url; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_album_url (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: l_artist_artist; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_artist_artist (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_artist_artist; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_artist_artist (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: Pending; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE "Pending" (
    "SeqId" integer NOT NULL,
    "TableName" character varying NOT NULL,
    "Op" character(1),
    "XID" integer NOT NULL
);


--
-- Name: PendingData; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE "PendingData" (
    "SeqId" integer NOT NULL,
    "IsKey" boolean NOT NULL,
    "Data" character varying
);


--
-- Name: Pending_SeqId_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE "Pending_SeqId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: Pending_SeqId_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE "Pending_SeqId_seq" OWNED BY "Pending"."SeqId";


--
-- Name: album_amazon_asin; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE album_amazon_asin (
    album integer NOT NULL,
    asin character(10),
    coverarturl character varying(255),
    lastupdate timestamp with time zone DEFAULT now()
);


--
-- Name: album_cdtoc; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE album_cdtoc (
    id integer NOT NULL,
    album integer NOT NULL,
    cdtoc integer NOT NULL,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: album_cdtoc_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE album_cdtoc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: album_cdtoc_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE album_cdtoc_id_seq OWNED BY album_cdtoc.id;


--
-- Name: album_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE album_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: album_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE album_id_seq OWNED BY album.id;


--
-- Name: albumjoin; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE albumjoin (
    id integer NOT NULL,
    album integer NOT NULL,
    track integer NOT NULL,
    sequence integer NOT NULL,
    modpending integer DEFAULT 0
);


--
-- Name: albumjoin_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE albumjoin_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: albumjoin_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE albumjoin_id_seq OWNED BY albumjoin.id;


--
-- Name: albummeta; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE albummeta (
    id integer NOT NULL,
    tracks integer DEFAULT 0,
    discids integer DEFAULT 0,
    puids integer DEFAULT 0,
    firstreleasedate character(10),
    asin character(10),
    coverarturl character varying(255),
    lastupdate timestamp with time zone DEFAULT now(),
    rating real,
    rating_count integer,
    dateadded timestamp with time zone DEFAULT now()
);


--
-- Name: albumwords; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE albumwords (
    wordid integer NOT NULL,
    albumid integer NOT NULL
);


--
-- Name: annotation; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE annotation (
    id integer NOT NULL,
    moderator integer NOT NULL,
    type smallint NOT NULL,
    rowid integer NOT NULL,
    text text,
    changelog character varying(255),
    created timestamp with time zone DEFAULT now(),
    moderation integer DEFAULT 0 NOT NULL,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: annotation_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE annotation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: annotation_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE annotation_id_seq OWNED BY annotation.id;


--
-- Name: artist_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE artist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: artist_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE artist_id_seq OWNED BY artist.id;


--
-- Name: artist_meta; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE artist_meta (
    id integer NOT NULL,
    lastupdate timestamp with time zone DEFAULT now(),
    rating real,
    rating_count integer
);


--
-- Name: artist_relation; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE artist_relation (
    id integer NOT NULL,
    artist integer NOT NULL,
    ref integer NOT NULL,
    weight integer NOT NULL
);


--
-- Name: artist_relation_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE artist_relation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: artist_relation_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE artist_relation_id_seq OWNED BY artist_relation.id;


--
-- Name: artist_tag; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE artist_tag (
    artist integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL
);


--
-- Name: artistalias; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE artistalias (
    id integer NOT NULL,
    ref integer NOT NULL,
    name character varying(255) NOT NULL,
    timesused integer DEFAULT 0,
    modpending integer DEFAULT 0,
    lastused timestamp with time zone
);


--
-- Name: artistalias_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE artistalias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: artistalias_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE artistalias_id_seq OWNED BY artistalias.id;


--
-- Name: artistwords; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE artistwords (
    wordid integer NOT NULL,
    artistid integer NOT NULL
);


--
-- Name: automod_election; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE automod_election (
    id integer NOT NULL,
    candidate integer NOT NULL,
    proposer integer NOT NULL,
    seconder_1 integer,
    seconder_2 integer,
    status integer DEFAULT 1 NOT NULL,
    yesvotes integer DEFAULT 0 NOT NULL,
    novotes integer DEFAULT 0 NOT NULL,
    proposetime timestamp with time zone DEFAULT now() NOT NULL,
    opentime timestamp with time zone,
    closetime timestamp with time zone,
    CONSTRAINT automod_election_chk1 CHECK ((status = ANY (ARRAY[1, 2, 3, 4, 5, 6])))
);


--
-- Name: automod_election_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE automod_election_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: automod_election_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE automod_election_id_seq OWNED BY automod_election.id;


--
-- Name: automod_election_vote; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE automod_election_vote (
    id integer NOT NULL,
    automod_election integer NOT NULL,
    voter integer NOT NULL,
    vote integer NOT NULL,
    votetime timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT automod_election_vote_chk1 CHECK ((vote = ANY (ARRAY[(-1), 0, 1])))
);


--
-- Name: automod_election_vote_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE automod_election_vote_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: automod_election_vote_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE automod_election_vote_id_seq OWNED BY automod_election_vote.id;


--
-- Name: cdtoc; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE cdtoc (
    id integer NOT NULL,
    discid character(28) NOT NULL,
    freedbid character(8) NOT NULL,
    trackcount integer NOT NULL,
    leadoutoffset integer NOT NULL,
    trackoffset integer[] NOT NULL,
    degraded boolean DEFAULT false NOT NULL
);


--
-- Name: cdtoc_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE cdtoc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: cdtoc_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE cdtoc_id_seq OWNED BY cdtoc.id;


--
-- Name: clientversion; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE clientversion (
    id integer NOT NULL,
    version character varying(64) NOT NULL
);


--
-- Name: clientversion_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE clientversion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: clientversion_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE clientversion_id_seq OWNED BY clientversion.id;


--
-- Name: country; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE country (
    id integer NOT NULL,
    isocode character varying(2) NOT NULL,
    name character varying(100) NOT NULL
);


--
-- Name: country_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE country_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: country_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE country_id_seq OWNED BY country.id;


--
-- Name: currentstat; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE currentstat (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    value integer NOT NULL,
    lastupdated timestamp with time zone
);


--
-- Name: currentstat_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE currentstat_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: currentstat_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE currentstat_id_seq OWNED BY currentstat.id;


--
-- Name: editor_subscribe_editor; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE editor_subscribe_editor (
    id integer NOT NULL,
    editor integer NOT NULL,
    subscribededitor integer NOT NULL,
    lasteditsent integer NOT NULL
);


--
-- Name: editor_subscribe_editor_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE editor_subscribe_editor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: editor_subscribe_editor_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE editor_subscribe_editor_id_seq OWNED BY editor_subscribe_editor.id;


--
-- Name: gid_redirect; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE gid_redirect (
    gid character(36) NOT NULL,
    newid integer NOT NULL,
    tbl smallint NOT NULL
);


--
-- Name: historicalstat; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE historicalstat (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    value integer NOT NULL,
    snapshotdate date NOT NULL
);


--
-- Name: historicalstat_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE historicalstat_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: historicalstat_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE historicalstat_id_seq OWNED BY historicalstat.id;


--
-- Name: isrc; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE isrc (
    id integer NOT NULL,
    track integer NOT NULL,
    isrc character(12) NOT NULL,
    source smallint,
    modpending integer DEFAULT 0
);


--
-- Name: isrc_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE isrc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: isrc_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE isrc_id_seq OWNED BY isrc.id;


--
-- Name: l_album_album; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_album_album (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: l_album_album_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_album_album_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_album_album_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_album_album_id_seq OWNED BY l_album_album.id;


--
-- Name: l_album_artist; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_album_artist (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: l_album_artist_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_album_artist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_album_artist_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_album_artist_id_seq OWNED BY l_album_artist.id;


--
-- Name: l_album_label; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_album_label (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: l_album_label_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_album_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_album_label_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_album_label_id_seq OWNED BY l_album_label.id;


--
-- Name: l_album_track; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_album_track (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: l_album_track_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_album_track_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_album_track_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_album_track_id_seq OWNED BY l_album_track.id;


--
-- Name: l_album_url_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_album_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_album_url_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_album_url_id_seq OWNED BY l_album_url.id;


--
-- Name: l_artist_artist_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_artist_artist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_artist_artist_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_artist_artist_id_seq OWNED BY l_artist_artist.id;


--
-- Name: l_artist_label; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_artist_label (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: l_artist_label_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_artist_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_artist_label_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_artist_label_id_seq OWNED BY l_artist_label.id;


--
-- Name: l_artist_track; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_artist_track (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: l_artist_track_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_artist_track_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_artist_track_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_artist_track_id_seq OWNED BY l_artist_track.id;


--
-- Name: l_artist_url_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_artist_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_artist_url_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_artist_url_id_seq OWNED BY l_artist_url.id;


--
-- Name: l_label_label; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_label_label (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: l_label_label_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_label_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_label_label_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_label_label_id_seq OWNED BY l_label_label.id;


--
-- Name: l_label_track; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_label_track (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: l_label_track_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_label_track_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_label_track_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_label_track_id_seq OWNED BY l_label_track.id;


--
-- Name: l_label_url_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_label_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_label_url_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_label_url_id_seq OWNED BY l_label_url.id;


--
-- Name: l_track_track; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_track_track (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: l_track_track_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_track_track_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_track_track_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_track_track_id_seq OWNED BY l_track_track.id;


--
-- Name: l_track_url; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_track_url (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: l_track_url_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_track_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_track_url_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_track_url_id_seq OWNED BY l_track_url.id;


--
-- Name: l_url_url; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE l_url_url (
    id integer NOT NULL,
    link0 integer DEFAULT 0 NOT NULL,
    link1 integer DEFAULT 0 NOT NULL,
    link_type integer DEFAULT 0 NOT NULL,
    begindate character(10) DEFAULT NULL::bpchar,
    enddate character(10) DEFAULT NULL::bpchar,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: l_url_url_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE l_url_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: l_url_url_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE l_url_url_id_seq OWNED BY l_url_url.id;


--
-- Name: label_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: label_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE label_id_seq OWNED BY label.id;


--
-- Name: label_meta; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE label_meta (
    id integer NOT NULL,
    lastupdate timestamp with time zone DEFAULT now(),
    rating real,
    rating_count integer
);


--
-- Name: label_tag; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE label_tag (
    label integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL
);


--
-- Name: labelalias; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE labelalias (
    id integer NOT NULL,
    ref integer NOT NULL,
    name character varying(255) NOT NULL,
    timesused integer DEFAULT 0,
    modpending integer DEFAULT 0,
    lastused timestamp with time zone
);


--
-- Name: labelalias_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE labelalias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: labelalias_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE labelalias_id_seq OWNED BY labelalias.id;


--
-- Name: labelwords; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE labelwords (
    wordid integer NOT NULL,
    labelid integer NOT NULL
);


--
-- Name: language; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE language (
    id integer NOT NULL,
    isocode_3t character(3) NOT NULL,
    isocode_3b character(3) NOT NULL,
    isocode_2 character(2),
    name character varying(100) NOT NULL,
    frequency integer DEFAULT 0 NOT NULL
);


--
-- Name: language_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: language_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE language_id_seq OWNED BY language.id;


--
-- Name: link_attribute; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE link_attribute (
    id integer NOT NULL,
    attribute_type integer DEFAULT 0 NOT NULL,
    link integer DEFAULT 0 NOT NULL,
    link_type character varying(32) DEFAULT ''::character varying NOT NULL
);


--
-- Name: link_attribute_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE link_attribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: link_attribute_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE link_attribute_id_seq OWNED BY link_attribute.id;


--
-- Name: link_attribute_type; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE link_attribute_type (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    modpending integer DEFAULT 0 NOT NULL
);


--
-- Name: link_attribute_type_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE link_attribute_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: link_attribute_type_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE link_attribute_type_id_seq OWNED BY link_attribute_type.id;


--
-- Name: lt_album_album; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_album_album (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_album_album_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_album_album_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_album_album_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_album_album_id_seq OWNED BY lt_album_album.id;


--
-- Name: lt_album_artist; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_album_artist (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_album_artist_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_album_artist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_album_artist_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_album_artist_id_seq OWNED BY lt_album_artist.id;


--
-- Name: lt_album_label; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_album_label (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_album_label_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_album_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_album_label_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_album_label_id_seq OWNED BY lt_album_label.id;


--
-- Name: lt_album_track; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_album_track (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_album_track_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_album_track_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_album_track_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_album_track_id_seq OWNED BY lt_album_track.id;


--
-- Name: lt_album_url_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_album_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_album_url_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_album_url_id_seq OWNED BY lt_album_url.id;


--
-- Name: lt_artist_artist_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_artist_artist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_artist_artist_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_artist_artist_id_seq OWNED BY lt_artist_artist.id;


--
-- Name: lt_artist_label; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_artist_label (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_artist_label_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_artist_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_artist_label_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_artist_label_id_seq OWNED BY lt_artist_label.id;


--
-- Name: lt_artist_track; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_artist_track (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_artist_track_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_artist_track_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_artist_track_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_artist_track_id_seq OWNED BY lt_artist_track.id;


--
-- Name: lt_artist_url_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_artist_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_artist_url_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_artist_url_id_seq OWNED BY lt_artist_url.id;


--
-- Name: lt_label_label; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_label_label (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_label_label_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_label_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_label_label_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_label_label_id_seq OWNED BY lt_label_label.id;


--
-- Name: lt_label_track; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_label_track (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_label_track_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_label_track_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_label_track_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_label_track_id_seq OWNED BY lt_label_track.id;


--
-- Name: lt_label_url_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_label_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_label_url_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_label_url_id_seq OWNED BY lt_label_url.id;


--
-- Name: lt_track_track; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_track_track (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_track_track_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_track_track_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_track_track_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_track_track_id_seq OWNED BY lt_track_track.id;


--
-- Name: lt_track_url; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_track_url (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_track_url_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_track_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_track_url_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_track_url_id_seq OWNED BY lt_track_url.id;


--
-- Name: lt_url_url; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE lt_url_url (
    id integer NOT NULL,
    parent integer NOT NULL,
    childorder integer DEFAULT 0 NOT NULL,
    mbid character(36) NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    linkphrase character varying(255) NOT NULL,
    rlinkphrase character varying(255) NOT NULL,
    attribute character varying(255) DEFAULT ''::character varying,
    modpending integer DEFAULT 0 NOT NULL,
    shortlinkphrase character varying(255) DEFAULT ''::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL
);


--
-- Name: lt_url_url_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE lt_url_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: lt_url_url_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE lt_url_url_id_seq OWNED BY lt_url_url.id;


--
-- Name: moderation_closed; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE moderation_closed (
    id integer NOT NULL,
    artist integer NOT NULL,
    moderator integer NOT NULL,
    tab character varying(32) NOT NULL,
    col character varying(64) NOT NULL,
    type smallint NOT NULL,
    status smallint NOT NULL,
    rowid integer NOT NULL,
    prevvalue text NOT NULL,
    newvalue text NOT NULL,
    yesvotes integer DEFAULT 0,
    novotes integer DEFAULT 0,
    depmod integer DEFAULT 0,
    automod smallint DEFAULT 0,
    opentime timestamp with time zone DEFAULT now(),
    closetime timestamp with time zone,
    expiretime timestamp with time zone NOT NULL,
    language integer
);


--
-- Name: moderation_open; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE moderation_open (
    id integer NOT NULL,
    artist integer NOT NULL,
    moderator integer NOT NULL,
    tab character varying(32) NOT NULL,
    col character varying(64) NOT NULL,
    type smallint NOT NULL,
    status smallint NOT NULL,
    rowid integer NOT NULL,
    prevvalue text NOT NULL,
    newvalue text NOT NULL,
    yesvotes integer DEFAULT 0,
    novotes integer DEFAULT 0,
    depmod integer DEFAULT 0,
    automod smallint DEFAULT 0,
    opentime timestamp with time zone DEFAULT now(),
    closetime timestamp with time zone,
    expiretime timestamp with time zone NOT NULL,
    language integer
);


--
-- Name: moderation_all; Type: VIEW; Schema: musicbrainz; Owner: -
--

CREATE VIEW moderation_all AS
    SELECT moderation_open.id, moderation_open.artist, moderation_open.moderator, moderation_open.tab, moderation_open.col, moderation_open.type, moderation_open.status, moderation_open.rowid, moderation_open.prevvalue, moderation_open.newvalue, moderation_open.yesvotes, moderation_open.novotes, moderation_open.depmod, moderation_open.automod, moderation_open.opentime, moderation_open.closetime, moderation_open.expiretime, moderation_open.language FROM moderation_open UNION ALL SELECT moderation_closed.id, moderation_closed.artist, moderation_closed.moderator, moderation_closed.tab, moderation_closed.col, moderation_closed.type, moderation_closed.status, moderation_closed.rowid, moderation_closed.prevvalue, moderation_closed.newvalue, moderation_closed.yesvotes, moderation_closed.novotes, moderation_closed.depmod, moderation_closed.automod, moderation_closed.opentime, moderation_closed.closetime, moderation_closed.expiretime, moderation_closed.language FROM moderation_closed;


--
-- Name: moderation_note_closed; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE moderation_note_closed (
    id integer NOT NULL,
    moderation integer NOT NULL,
    moderator integer NOT NULL,
    text text NOT NULL,
    notetime timestamp with time zone DEFAULT now()
);


--
-- Name: moderation_note_open; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE moderation_note_open (
    id integer NOT NULL,
    moderation integer NOT NULL,
    moderator integer NOT NULL,
    text text NOT NULL,
    notetime timestamp with time zone DEFAULT now()
);


--
-- Name: moderation_note_all; Type: VIEW; Schema: musicbrainz; Owner: -
--

CREATE VIEW moderation_note_all AS
    SELECT moderation_note_open.id, moderation_note_open.moderation, moderation_note_open.moderator, moderation_note_open.text, moderation_note_open.notetime FROM moderation_note_open UNION ALL SELECT moderation_note_closed.id, moderation_note_closed.moderation, moderation_note_closed.moderator, moderation_note_closed.text, moderation_note_closed.notetime FROM moderation_note_closed;


--
-- Name: moderation_note_open_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE moderation_note_open_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: moderation_note_open_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE moderation_note_open_id_seq OWNED BY moderation_note_open.id;


--
-- Name: moderation_open_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE moderation_open_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: moderation_open_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE moderation_open_id_seq OWNED BY moderation_open.id;


--
-- Name: moderator; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE moderator (
    id integer NOT NULL,
    name character varying(64) NOT NULL,
    password character varying(64) NOT NULL,
    privs integer DEFAULT 0,
    modsaccepted integer DEFAULT 0,
    modsrejected integer DEFAULT 0,
    email character varying(64) DEFAULT NULL::character varying,
    weburl character varying(255) DEFAULT NULL::character varying,
    bio text,
    membersince timestamp with time zone DEFAULT now(),
    emailconfirmdate timestamp with time zone,
    lastlogindate timestamp with time zone,
    automodsaccepted integer DEFAULT 0,
    modsfailed integer DEFAULT 0
);


--
-- Name: moderator_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE moderator_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: moderator_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE moderator_id_seq OWNED BY moderator.id;


--
-- Name: moderator_preference; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE moderator_preference (
    id integer NOT NULL,
    moderator integer NOT NULL,
    name character varying(50) NOT NULL,
    value character varying(100) NOT NULL
);


--
-- Name: moderator_preference_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE moderator_preference_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: moderator_preference_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE moderator_preference_id_seq OWNED BY moderator_preference.id;


--
-- Name: moderator_subscribe_artist; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE moderator_subscribe_artist (
    id integer NOT NULL,
    moderator integer NOT NULL,
    artist integer NOT NULL,
    lastmodsent integer NOT NULL,
    deletedbymod integer DEFAULT 0 NOT NULL,
    mergedbymod integer DEFAULT 0 NOT NULL
);


--
-- Name: moderator_subscribe_artist_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE moderator_subscribe_artist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: moderator_subscribe_artist_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE moderator_subscribe_artist_id_seq OWNED BY moderator_subscribe_artist.id;


--
-- Name: moderator_subscribe_label; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE moderator_subscribe_label (
    id integer NOT NULL,
    moderator integer NOT NULL,
    label integer NOT NULL,
    lastmodsent integer NOT NULL,
    deletedbymod integer DEFAULT 0 NOT NULL,
    mergedbymod integer DEFAULT 0 NOT NULL
);


--
-- Name: moderator_subscribe_label_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE moderator_subscribe_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: moderator_subscribe_label_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE moderator_subscribe_label_id_seq OWNED BY moderator_subscribe_label.id;


--
-- Name: puid; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE puid (
    id integer NOT NULL,
    puid character(36) NOT NULL,
    lookupcount integer DEFAULT 0 NOT NULL,
    version integer NOT NULL
);


--
-- Name: puid_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE puid_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: puid_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE puid_id_seq OWNED BY puid.id;


--
-- Name: puid_stat; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE puid_stat (
    id integer NOT NULL,
    puid_id integer NOT NULL,
    month_id integer NOT NULL,
    lookupcount integer DEFAULT 0 NOT NULL
);


--
-- Name: puid_stat_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE puid_stat_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: puid_stat_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE puid_stat_id_seq OWNED BY puid_stat.id;


--
-- Name: puidjoin; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE puidjoin (
    id integer NOT NULL,
    puid integer NOT NULL,
    track integer NOT NULL,
    usecount integer DEFAULT 0
);


--
-- Name: puidjoin_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE puidjoin_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: puidjoin_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE puidjoin_id_seq OWNED BY puidjoin.id;


--
-- Name: puidjoin_stat; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE puidjoin_stat (
    id integer NOT NULL,
    puidjoin_id integer NOT NULL,
    month_id integer NOT NULL,
    usecount integer DEFAULT 0 NOT NULL
);


--
-- Name: puidjoin_stat_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE puidjoin_stat_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: puidjoin_stat_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE puidjoin_stat_id_seq OWNED BY puidjoin_stat.id;


--
-- Name: release; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE release (
    id integer NOT NULL,
    album integer NOT NULL,
    country integer NOT NULL,
    releasedate character(10) NOT NULL,
    modpending integer DEFAULT 0,
    label integer,
    catno character varying(255),
    barcode character varying(255),
    format smallint
);


--
-- Name: release_group; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE release_group (
    id integer NOT NULL,
    gid character(36),
    name character varying(255),
    page integer NOT NULL,
    artist integer NOT NULL,
    type integer,
    modpending integer DEFAULT 0
);


--
-- Name: release_group_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE release_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: release_group_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE release_group_id_seq OWNED BY release_group.id;


--
-- Name: release_group_meta; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE release_group_meta (
    id integer NOT NULL,
    lastupdate timestamp with time zone DEFAULT now(),
    firstreleasedate character(10),
    releasecount integer DEFAULT 0
);


--
-- Name: release_groupwords; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE release_groupwords (
    wordid integer NOT NULL,
    release_groupid integer NOT NULL
);


--
-- Name: release_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE release_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: release_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE release_id_seq OWNED BY release.id;


--
-- Name: release_tag; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE release_tag (
    release integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL
);


--
-- Name: replication_control; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE replication_control (
    id integer NOT NULL,
    current_schema_sequence integer NOT NULL,
    current_replication_sequence integer,
    last_replication_date timestamp with time zone
);


--
-- Name: replication_control_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE replication_control_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: replication_control_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE replication_control_id_seq OWNED BY replication_control.id;


--
-- Name: script; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE script (
    id integer NOT NULL,
    isocode character(4) NOT NULL,
    isonumber character(3) NOT NULL,
    name character varying(100) NOT NULL,
    frequency integer DEFAULT 0 NOT NULL
);


--
-- Name: script_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE script_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: script_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE script_id_seq OWNED BY script.id;


--
-- Name: script_language; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE script_language (
    id integer NOT NULL,
    script integer,
    language integer NOT NULL,
    frequency integer DEFAULT 0 NOT NULL
);


--
-- Name: script_language_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE script_language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: script_language_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE script_language_id_seq OWNED BY script_language.id;


--
-- Name: stats; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE stats (
    id integer NOT NULL,
    artists integer NOT NULL,
    albums integer NOT NULL,
    tracks integer NOT NULL,
    discids integer NOT NULL,
    moderations integer NOT NULL,
    votes integer NOT NULL,
    moderators integer NOT NULL,
    "timestamp" date NOT NULL
);


--
-- Name: stats_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stats_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE stats_id_seq OWNED BY stats.id;


--
-- Name: tag; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE tag (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    refcount integer DEFAULT 0 NOT NULL
);


--
-- Name: tag_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE tag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tag_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE tag_id_seq OWNED BY tag.id;


--
-- Name: tag_relation; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE tag_relation (
    tag1 integer NOT NULL,
    tag2 integer NOT NULL,
    weight integer NOT NULL,
    CONSTRAINT tag_relation_check CHECK ((tag1 < tag2))
);


--
-- Name: track; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE track (
    id integer NOT NULL,
    artist integer NOT NULL,
    name text NOT NULL,
    gid character(36) NOT NULL,
    length integer DEFAULT 0,
    year integer DEFAULT 0,
    modpending integer DEFAULT 0
);


--
-- Name: track_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE track_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: track_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE track_id_seq OWNED BY track.id;


--
-- Name: track_meta; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE track_meta (
    id integer NOT NULL,
    rating real,
    rating_count integer
);


--
-- Name: track_tag; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE track_tag (
    track integer NOT NULL,
    tag integer NOT NULL,
    count integer NOT NULL
);


--
-- Name: trackwords; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE trackwords (
    wordid integer NOT NULL,
    trackid integer NOT NULL
);


--
-- Name: url_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: url_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE url_id_seq OWNED BY url.id;


--
-- Name: vote_closed; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE vote_closed (
    id integer NOT NULL,
    moderator integer NOT NULL,
    moderation integer NOT NULL,
    vote smallint NOT NULL,
    votetime timestamp with time zone DEFAULT now(),
    superseded boolean DEFAULT false NOT NULL
);


--
-- Name: vote_open; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE vote_open (
    id integer NOT NULL,
    moderator integer NOT NULL,
    moderation integer NOT NULL,
    vote smallint NOT NULL,
    votetime timestamp with time zone DEFAULT now(),
    superseded boolean DEFAULT false NOT NULL
);


--
-- Name: vote_all; Type: VIEW; Schema: musicbrainz; Owner: -
--

CREATE VIEW vote_all AS
    SELECT vote_open.id, vote_open.moderator, vote_open.moderation, vote_open.vote, vote_open.votetime, vote_open.superseded FROM vote_open UNION ALL SELECT vote_closed.id, vote_closed.moderator, vote_closed.moderation, vote_closed.vote, vote_closed.votetime, vote_closed.superseded FROM vote_closed;


--
-- Name: vote_open_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE vote_open_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: vote_open_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE vote_open_id_seq OWNED BY vote_open.id;


--
-- Name: wordlist; Type: TABLE; Schema: musicbrainz; Owner: -
--

CREATE TABLE wordlist (
    id integer NOT NULL,
    word character varying(255) NOT NULL,
    artistusecount smallint DEFAULT 0 NOT NULL,
    albumusecount smallint DEFAULT 0 NOT NULL,
    trackusecount smallint DEFAULT 0 NOT NULL,
    labelusecount smallint DEFAULT 0 NOT NULL,
    release_groupusecount smallint DEFAULT 0 NOT NULL
);


--
-- Name: wordlist_id_seq; Type: SEQUENCE; Schema: musicbrainz; Owner: -
--

CREATE SEQUENCE wordlist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: wordlist_id_seq; Type: SEQUENCE OWNED BY; Schema: musicbrainz; Owner: -
--

ALTER SEQUENCE wordlist_id_seq OWNED BY wordlist.id;


--
-- Name: SeqId; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE "Pending" ALTER COLUMN "SeqId" SET DEFAULT nextval('"Pending_SeqId_seq"'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE album ALTER COLUMN id SET DEFAULT nextval('album_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE album_cdtoc ALTER COLUMN id SET DEFAULT nextval('album_cdtoc_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE albumjoin ALTER COLUMN id SET DEFAULT nextval('albumjoin_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE annotation ALTER COLUMN id SET DEFAULT nextval('annotation_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE artist ALTER COLUMN id SET DEFAULT nextval('artist_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE artist_relation ALTER COLUMN id SET DEFAULT nextval('artist_relation_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE artistalias ALTER COLUMN id SET DEFAULT nextval('artistalias_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE automod_election ALTER COLUMN id SET DEFAULT nextval('automod_election_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE automod_election_vote ALTER COLUMN id SET DEFAULT nextval('automod_election_vote_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE cdtoc ALTER COLUMN id SET DEFAULT nextval('cdtoc_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE clientversion ALTER COLUMN id SET DEFAULT nextval('clientversion_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE country ALTER COLUMN id SET DEFAULT nextval('country_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE currentstat ALTER COLUMN id SET DEFAULT nextval('currentstat_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE editor_subscribe_editor ALTER COLUMN id SET DEFAULT nextval('editor_subscribe_editor_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE historicalstat ALTER COLUMN id SET DEFAULT nextval('historicalstat_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE isrc ALTER COLUMN id SET DEFAULT nextval('isrc_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_album_album ALTER COLUMN id SET DEFAULT nextval('l_album_album_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_album_artist ALTER COLUMN id SET DEFAULT nextval('l_album_artist_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_album_label ALTER COLUMN id SET DEFAULT nextval('l_album_label_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_album_track ALTER COLUMN id SET DEFAULT nextval('l_album_track_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_album_url ALTER COLUMN id SET DEFAULT nextval('l_album_url_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_artist_artist ALTER COLUMN id SET DEFAULT nextval('l_artist_artist_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_artist_label ALTER COLUMN id SET DEFAULT nextval('l_artist_label_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_artist_track ALTER COLUMN id SET DEFAULT nextval('l_artist_track_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_artist_url ALTER COLUMN id SET DEFAULT nextval('l_artist_url_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_label_label ALTER COLUMN id SET DEFAULT nextval('l_label_label_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_label_track ALTER COLUMN id SET DEFAULT nextval('l_label_track_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_label_url ALTER COLUMN id SET DEFAULT nextval('l_label_url_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_track_track ALTER COLUMN id SET DEFAULT nextval('l_track_track_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_track_url ALTER COLUMN id SET DEFAULT nextval('l_track_url_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE l_url_url ALTER COLUMN id SET DEFAULT nextval('l_url_url_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE label ALTER COLUMN id SET DEFAULT nextval('label_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE labelalias ALTER COLUMN id SET DEFAULT nextval('labelalias_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE language ALTER COLUMN id SET DEFAULT nextval('language_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE link_attribute ALTER COLUMN id SET DEFAULT nextval('link_attribute_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE link_attribute_type ALTER COLUMN id SET DEFAULT nextval('link_attribute_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_album_album ALTER COLUMN id SET DEFAULT nextval('lt_album_album_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_album_artist ALTER COLUMN id SET DEFAULT nextval('lt_album_artist_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_album_label ALTER COLUMN id SET DEFAULT nextval('lt_album_label_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_album_track ALTER COLUMN id SET DEFAULT nextval('lt_album_track_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_album_url ALTER COLUMN id SET DEFAULT nextval('lt_album_url_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_artist_artist ALTER COLUMN id SET DEFAULT nextval('lt_artist_artist_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_artist_label ALTER COLUMN id SET DEFAULT nextval('lt_artist_label_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_artist_track ALTER COLUMN id SET DEFAULT nextval('lt_artist_track_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_artist_url ALTER COLUMN id SET DEFAULT nextval('lt_artist_url_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_label_label ALTER COLUMN id SET DEFAULT nextval('lt_label_label_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_label_track ALTER COLUMN id SET DEFAULT nextval('lt_label_track_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_label_url ALTER COLUMN id SET DEFAULT nextval('lt_label_url_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_track_track ALTER COLUMN id SET DEFAULT nextval('lt_track_track_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_track_url ALTER COLUMN id SET DEFAULT nextval('lt_track_url_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE lt_url_url ALTER COLUMN id SET DEFAULT nextval('lt_url_url_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE moderation_note_open ALTER COLUMN id SET DEFAULT nextval('moderation_note_open_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE moderation_open ALTER COLUMN id SET DEFAULT nextval('moderation_open_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE moderator ALTER COLUMN id SET DEFAULT nextval('moderator_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE moderator_preference ALTER COLUMN id SET DEFAULT nextval('moderator_preference_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE moderator_subscribe_artist ALTER COLUMN id SET DEFAULT nextval('moderator_subscribe_artist_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE moderator_subscribe_label ALTER COLUMN id SET DEFAULT nextval('moderator_subscribe_label_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE puid ALTER COLUMN id SET DEFAULT nextval('puid_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE puid_stat ALTER COLUMN id SET DEFAULT nextval('puid_stat_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE puidjoin ALTER COLUMN id SET DEFAULT nextval('puidjoin_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE puidjoin_stat ALTER COLUMN id SET DEFAULT nextval('puidjoin_stat_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE release ALTER COLUMN id SET DEFAULT nextval('release_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE release_group ALTER COLUMN id SET DEFAULT nextval('release_group_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE replication_control ALTER COLUMN id SET DEFAULT nextval('replication_control_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE script ALTER COLUMN id SET DEFAULT nextval('script_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE script_language ALTER COLUMN id SET DEFAULT nextval('script_language_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE stats ALTER COLUMN id SET DEFAULT nextval('stats_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE tag ALTER COLUMN id SET DEFAULT nextval('tag_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE track ALTER COLUMN id SET DEFAULT nextval('track_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE url ALTER COLUMN id SET DEFAULT nextval('url_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE vote_open ALTER COLUMN id SET DEFAULT nextval('vote_open_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: musicbrainz; Owner: -
--

ALTER TABLE wordlist ALTER COLUMN id SET DEFAULT nextval('wordlist_id_seq'::regclass);


--
-- Name: PendingData_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY "PendingData"
    ADD CONSTRAINT "PendingData_pkey" PRIMARY KEY ("SeqId", "IsKey");


--
-- Name: Pending_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY "Pending"
    ADD CONSTRAINT "Pending_pkey" PRIMARY KEY ("SeqId");


--
-- Name: album_amazon_asin_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY album_amazon_asin
    ADD CONSTRAINT album_amazon_asin_pkey PRIMARY KEY (album);


--
-- Name: album_cdtoc_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY album_cdtoc
    ADD CONSTRAINT album_cdtoc_pkey PRIMARY KEY (id);


--
-- Name: album_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY album
    ADD CONSTRAINT album_pkey PRIMARY KEY (id);


--
-- Name: albumjoin_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY albumjoin
    ADD CONSTRAINT albumjoin_pkey PRIMARY KEY (id);


--
-- Name: albummeta_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY albummeta
    ADD CONSTRAINT albummeta_pkey PRIMARY KEY (id);


--
-- Name: albumwords_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY albumwords
    ADD CONSTRAINT albumwords_pkey PRIMARY KEY (wordid, albumid);


--
-- Name: annotation_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY annotation
    ADD CONSTRAINT annotation_pkey PRIMARY KEY (id);


--
-- Name: artist_meta_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY artist_meta
    ADD CONSTRAINT artist_meta_pkey PRIMARY KEY (id);


--
-- Name: artist_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY artist
    ADD CONSTRAINT artist_pkey PRIMARY KEY (id);


--
-- Name: artist_relation_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY artist_relation
    ADD CONSTRAINT artist_relation_pkey PRIMARY KEY (id);


--
-- Name: artist_tag_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY artist_tag
    ADD CONSTRAINT artist_tag_pkey PRIMARY KEY (artist, tag);


--
-- Name: artistalias_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY artistalias
    ADD CONSTRAINT artistalias_pkey PRIMARY KEY (id);


--
-- Name: artistwords_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY artistwords
    ADD CONSTRAINT artistwords_pkey PRIMARY KEY (wordid, artistid);


--
-- Name: automod_election_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY automod_election
    ADD CONSTRAINT automod_election_pkey PRIMARY KEY (id);


--
-- Name: automod_election_vote_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY automod_election_vote
    ADD CONSTRAINT automod_election_vote_pkey PRIMARY KEY (id);


--
-- Name: cdtoc_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY cdtoc
    ADD CONSTRAINT cdtoc_pkey PRIMARY KEY (id);


--
-- Name: clientversion_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY clientversion
    ADD CONSTRAINT clientversion_pkey PRIMARY KEY (id);


--
-- Name: country_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY country
    ADD CONSTRAINT country_pkey PRIMARY KEY (id);


--
-- Name: currentstat_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY currentstat
    ADD CONSTRAINT currentstat_pkey PRIMARY KEY (id);


--
-- Name: editor_subscribe_editor_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY editor_subscribe_editor
    ADD CONSTRAINT editor_subscribe_editor_pkey PRIMARY KEY (id);


--
-- Name: gid_redirect_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY gid_redirect
    ADD CONSTRAINT gid_redirect_pkey PRIMARY KEY (gid);


--
-- Name: historicalstat_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY historicalstat
    ADD CONSTRAINT historicalstat_pkey PRIMARY KEY (id);


--
-- Name: isrc_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY isrc
    ADD CONSTRAINT isrc_pkey PRIMARY KEY (id);


--
-- Name: l_album_album_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_album_album
    ADD CONSTRAINT l_album_album_pkey PRIMARY KEY (id);


--
-- Name: l_album_artist_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_album_artist
    ADD CONSTRAINT l_album_artist_pkey PRIMARY KEY (id);


--
-- Name: l_album_label_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_album_label
    ADD CONSTRAINT l_album_label_pkey PRIMARY KEY (id);


--
-- Name: l_album_track_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_album_track
    ADD CONSTRAINT l_album_track_pkey PRIMARY KEY (id);


--
-- Name: l_album_url_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_album_url
    ADD CONSTRAINT l_album_url_pkey PRIMARY KEY (id);


--
-- Name: l_artist_artist_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_artist_artist
    ADD CONSTRAINT l_artist_artist_pkey PRIMARY KEY (id);


--
-- Name: l_artist_label_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_artist_label
    ADD CONSTRAINT l_artist_label_pkey PRIMARY KEY (id);


--
-- Name: l_artist_track_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_artist_track
    ADD CONSTRAINT l_artist_track_pkey PRIMARY KEY (id);


--
-- Name: l_artist_url_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_artist_url
    ADD CONSTRAINT l_artist_url_pkey PRIMARY KEY (id);


--
-- Name: l_label_label_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_label_label
    ADD CONSTRAINT l_label_label_pkey PRIMARY KEY (id);


--
-- Name: l_label_track_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_label_track
    ADD CONSTRAINT l_label_track_pkey PRIMARY KEY (id);


--
-- Name: l_label_url_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_label_url
    ADD CONSTRAINT l_label_url_pkey PRIMARY KEY (id);


--
-- Name: l_track_track_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_track_track
    ADD CONSTRAINT l_track_track_pkey PRIMARY KEY (id);


--
-- Name: l_track_url_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_track_url
    ADD CONSTRAINT l_track_url_pkey PRIMARY KEY (id);


--
-- Name: l_url_url_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY l_url_url
    ADD CONSTRAINT l_url_url_pkey PRIMARY KEY (id);


--
-- Name: label_meta_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY label_meta
    ADD CONSTRAINT label_meta_pkey PRIMARY KEY (id);


--
-- Name: label_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY label
    ADD CONSTRAINT label_pkey PRIMARY KEY (id);


--
-- Name: label_tag_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY label_tag
    ADD CONSTRAINT label_tag_pkey PRIMARY KEY (label, tag);


--
-- Name: labelalias_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY labelalias
    ADD CONSTRAINT labelalias_pkey PRIMARY KEY (id);


--
-- Name: labelwords_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY labelwords
    ADD CONSTRAINT labelwords_pkey PRIMARY KEY (wordid, labelid);


--
-- Name: language_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY language
    ADD CONSTRAINT language_pkey PRIMARY KEY (id);


--
-- Name: link_attribute_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY link_attribute
    ADD CONSTRAINT link_attribute_pkey PRIMARY KEY (id);


--
-- Name: link_attribute_type_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY link_attribute_type
    ADD CONSTRAINT link_attribute_type_pkey PRIMARY KEY (id);


--
-- Name: lt_album_album_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_album_album
    ADD CONSTRAINT lt_album_album_pkey PRIMARY KEY (id);


--
-- Name: lt_album_artist_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_album_artist
    ADD CONSTRAINT lt_album_artist_pkey PRIMARY KEY (id);


--
-- Name: lt_album_label_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_album_label
    ADD CONSTRAINT lt_album_label_pkey PRIMARY KEY (id);


--
-- Name: lt_album_track_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_album_track
    ADD CONSTRAINT lt_album_track_pkey PRIMARY KEY (id);


--
-- Name: lt_album_url_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_album_url
    ADD CONSTRAINT lt_album_url_pkey PRIMARY KEY (id);


--
-- Name: lt_artist_artist_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_artist_artist
    ADD CONSTRAINT lt_artist_artist_pkey PRIMARY KEY (id);


--
-- Name: lt_artist_label_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_artist_label
    ADD CONSTRAINT lt_artist_label_pkey PRIMARY KEY (id);


--
-- Name: lt_artist_track_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_artist_track
    ADD CONSTRAINT lt_artist_track_pkey PRIMARY KEY (id);


--
-- Name: lt_artist_url_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_artist_url
    ADD CONSTRAINT lt_artist_url_pkey PRIMARY KEY (id);


--
-- Name: lt_label_label_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_label_label
    ADD CONSTRAINT lt_label_label_pkey PRIMARY KEY (id);


--
-- Name: lt_label_track_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_label_track
    ADD CONSTRAINT lt_label_track_pkey PRIMARY KEY (id);


--
-- Name: lt_label_url_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_label_url
    ADD CONSTRAINT lt_label_url_pkey PRIMARY KEY (id);


--
-- Name: lt_track_track_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_track_track
    ADD CONSTRAINT lt_track_track_pkey PRIMARY KEY (id);


--
-- Name: lt_track_url_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_track_url
    ADD CONSTRAINT lt_track_url_pkey PRIMARY KEY (id);


--
-- Name: lt_url_url_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY lt_url_url
    ADD CONSTRAINT lt_url_url_pkey PRIMARY KEY (id);


--
-- Name: moderation_closed_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY moderation_closed
    ADD CONSTRAINT moderation_closed_pkey PRIMARY KEY (id);


--
-- Name: moderation_note_closed_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY moderation_note_closed
    ADD CONSTRAINT moderation_note_closed_pkey PRIMARY KEY (id);


--
-- Name: moderation_note_open_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY moderation_note_open
    ADD CONSTRAINT moderation_note_open_pkey PRIMARY KEY (id);


--
-- Name: moderation_open_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY moderation_open
    ADD CONSTRAINT moderation_open_pkey PRIMARY KEY (id);


--
-- Name: moderator_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY moderator
    ADD CONSTRAINT moderator_pkey PRIMARY KEY (id);


--
-- Name: moderator_preference_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY moderator_preference
    ADD CONSTRAINT moderator_preference_pkey PRIMARY KEY (id);


--
-- Name: moderator_subscribe_artist_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY moderator_subscribe_artist
    ADD CONSTRAINT moderator_subscribe_artist_pkey PRIMARY KEY (id);


--
-- Name: moderator_subscribe_label_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY moderator_subscribe_label
    ADD CONSTRAINT moderator_subscribe_label_pkey PRIMARY KEY (id);


--
-- Name: puid_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY puid
    ADD CONSTRAINT puid_pkey PRIMARY KEY (id);


--
-- Name: puid_stat_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY puid_stat
    ADD CONSTRAINT puid_stat_pkey PRIMARY KEY (id);


--
-- Name: puidjoin_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY puidjoin
    ADD CONSTRAINT puidjoin_pkey PRIMARY KEY (id);


--
-- Name: puidjoin_stat_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY puidjoin_stat
    ADD CONSTRAINT puidjoin_stat_pkey PRIMARY KEY (id);


--
-- Name: release_group_meta_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY release_group_meta
    ADD CONSTRAINT release_group_meta_pkey PRIMARY KEY (id);


--
-- Name: release_group_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY release_group
    ADD CONSTRAINT release_group_pkey PRIMARY KEY (id);


--
-- Name: release_groupwords_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY release_groupwords
    ADD CONSTRAINT release_groupwords_pkey PRIMARY KEY (wordid, release_groupid);


--
-- Name: release_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY release
    ADD CONSTRAINT release_pkey PRIMARY KEY (id);


--
-- Name: release_tag_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY release_tag
    ADD CONSTRAINT release_tag_pkey PRIMARY KEY (release, tag);


--
-- Name: replication_control_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY replication_control
    ADD CONSTRAINT replication_control_pkey PRIMARY KEY (id);


--
-- Name: script_language_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY script_language
    ADD CONSTRAINT script_language_pkey PRIMARY KEY (id);


--
-- Name: script_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY script
    ADD CONSTRAINT script_pkey PRIMARY KEY (id);


--
-- Name: stats_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY stats
    ADD CONSTRAINT stats_pkey PRIMARY KEY (id);


--
-- Name: tag_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY tag
    ADD CONSTRAINT tag_pkey PRIMARY KEY (id);


--
-- Name: tag_relation_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY tag_relation
    ADD CONSTRAINT tag_relation_pkey PRIMARY KEY (tag1, tag2);


--
-- Name: track_meta_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY track_meta
    ADD CONSTRAINT track_meta_pkey PRIMARY KEY (id);


--
-- Name: track_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY track
    ADD CONSTRAINT track_pkey PRIMARY KEY (id);


--
-- Name: track_tag_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY track_tag
    ADD CONSTRAINT track_tag_pkey PRIMARY KEY (track, tag);


--
-- Name: trackwords_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY trackwords
    ADD CONSTRAINT trackwords_pkey PRIMARY KEY (wordid, trackid);


--
-- Name: url_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY url
    ADD CONSTRAINT url_pkey PRIMARY KEY (id);


--
-- Name: vote_closed_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY vote_closed
    ADD CONSTRAINT vote_closed_pkey PRIMARY KEY (id);


--
-- Name: vote_open_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY vote_open
    ADD CONSTRAINT vote_open_pkey PRIMARY KEY (id);


--
-- Name: wordlist_pkey; Type: CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY wordlist
    ADD CONSTRAINT wordlist_pkey PRIMARY KEY (id);


--
-- Name: Pending_XID_Index; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX "Pending_XID_Index" ON "Pending" USING btree ("XID");


--
-- Name: album_amazon_asin_asin; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX album_amazon_asin_asin ON album_amazon_asin USING btree (asin);


--
-- Name: album_artistindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX album_artistindex ON album USING btree (artist);


--
-- Name: album_cdtoc_albumcdtoc; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX album_cdtoc_albumcdtoc ON album_cdtoc USING btree (album, cdtoc);


--
-- Name: album_gidindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX album_gidindex ON album USING btree (gid);


--
-- Name: album_nameindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX album_nameindex ON album USING btree (name);


--
-- Name: album_pageindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX album_pageindex ON album USING btree (page);


--
-- Name: album_release_groupindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX album_release_groupindex ON album USING btree (release_group);


--
-- Name: albumjoin_albumindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX albumjoin_albumindex ON albumjoin USING btree (album);


--
-- Name: albumjoin_albumtrack; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX albumjoin_albumtrack ON albumjoin USING btree (album, track);


--
-- Name: albumjoin_trackindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX albumjoin_trackindex ON albumjoin USING btree (track);


--
-- Name: albummeta_lastupdate; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX albummeta_lastupdate ON albummeta USING btree (lastupdate);


--
-- Name: albumwords_albumidindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX albumwords_albumidindex ON albumwords USING btree (albumid);


--
-- Name: annotation_moderationindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX annotation_moderationindex ON annotation USING btree (moderation);


--
-- Name: annotation_rowidindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX annotation_rowidindex ON annotation USING btree (rowid);


--
-- Name: artist_gidindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX artist_gidindex ON artist USING btree (gid);


--
-- Name: artist_meta_lastupdate; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX artist_meta_lastupdate ON artist_meta USING btree (lastupdate);


--
-- Name: artist_nameindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX artist_nameindex ON artist USING btree (name);


--
-- Name: artist_pageindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX artist_pageindex ON artist USING btree (page);


--
-- Name: artist_relation_artist; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX artist_relation_artist ON artist_relation USING btree (artist);


--
-- Name: artist_relation_ref; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX artist_relation_ref ON artist_relation USING btree (ref);


--
-- Name: artist_sortnameindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX artist_sortnameindex ON artist USING btree (sortname);


--
-- Name: artist_tag_idx_artist; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX artist_tag_idx_artist ON artist_tag USING btree (artist);


--
-- Name: artist_tag_idx_tag; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX artist_tag_idx_tag ON artist_tag USING btree (tag);


--
-- Name: artistalias_nameindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX artistalias_nameindex ON artistalias USING btree (name);


--
-- Name: artistalias_refindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX artistalias_refindex ON artistalias USING btree (ref);


--
-- Name: artistwords_artistidindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX artistwords_artistidindex ON artistwords USING btree (artistid);


--
-- Name: cdtoc_discid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX cdtoc_discid ON cdtoc USING btree (discid);


--
-- Name: cdtoc_freedbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX cdtoc_freedbid ON cdtoc USING btree (freedbid);


--
-- Name: cdtoc_toc; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX cdtoc_toc ON cdtoc USING btree (trackcount, leadoutoffset, trackoffset);


--
-- Name: cdtoc_trackoffset; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX cdtoc_trackoffset ON cdtoc USING btree (trackoffset);


--
-- Name: clientversion_version; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX clientversion_version ON clientversion USING btree (version);


--
-- Name: country_isocode; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX country_isocode ON country USING btree (isocode);


--
-- Name: country_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX country_name ON country USING btree (name);


--
-- Name: currentstat_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX currentstat_name ON currentstat USING btree (name);


--
-- Name: editor_subscribe_editor_editor_key; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX editor_subscribe_editor_editor_key ON editor_subscribe_editor USING btree (editor, subscribededitor);


--
-- Name: gid_redirect_newid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX gid_redirect_newid ON gid_redirect USING btree (newid);


--
-- Name: historicalstat_date; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX historicalstat_date ON historicalstat USING btree (snapshotdate);


--
-- Name: historicalstat_name_snapshotdate; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX historicalstat_name_snapshotdate ON historicalstat USING btree (name, snapshotdate);


--
-- Name: isrc_isrc; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX isrc_isrc ON isrc USING btree (isrc);


--
-- Name: isrc_isrc_track; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX isrc_isrc_track ON isrc USING btree (isrc, track);


--
-- Name: l_album_album_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_album_album_idx_link1 ON l_album_album USING btree (link1);


--
-- Name: l_album_album_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_album_album_idx_uniq ON l_album_album USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_album_artist_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_album_artist_idx_link1 ON l_album_artist USING btree (link1);


--
-- Name: l_album_artist_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_album_artist_idx_uniq ON l_album_artist USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_album_label_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_album_label_idx_link1 ON l_album_label USING btree (link1);


--
-- Name: l_album_label_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_album_label_idx_uniq ON l_album_label USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_album_track_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_album_track_idx_link1 ON l_album_track USING btree (link1);


--
-- Name: l_album_track_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_album_track_idx_uniq ON l_album_track USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_album_url_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_album_url_idx_link1 ON l_album_url USING btree (link1);


--
-- Name: l_album_url_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_album_url_idx_uniq ON l_album_url USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_artist_artist_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_artist_artist_idx_link1 ON l_artist_artist USING btree (link1);


--
-- Name: l_artist_artist_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_artist_artist_idx_uniq ON l_artist_artist USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_artist_label_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_artist_label_idx_link1 ON l_artist_label USING btree (link1);


--
-- Name: l_artist_label_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_artist_label_idx_uniq ON l_artist_label USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_artist_track_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_artist_track_idx_link1 ON l_artist_track USING btree (link1);


--
-- Name: l_artist_track_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_artist_track_idx_uniq ON l_artist_track USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_artist_url_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_artist_url_idx_link1 ON l_artist_url USING btree (link1);


--
-- Name: l_artist_url_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_artist_url_idx_uniq ON l_artist_url USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_label_label_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_label_label_idx_link1 ON l_label_label USING btree (link1);


--
-- Name: l_label_label_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_label_label_idx_uniq ON l_label_label USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_label_track_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_label_track_idx_link1 ON l_label_track USING btree (link1);


--
-- Name: l_label_track_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_label_track_idx_uniq ON l_label_track USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_label_url_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_label_url_idx_link1 ON l_label_url USING btree (link1);


--
-- Name: l_label_url_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_label_url_idx_uniq ON l_label_url USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_track_track_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_track_track_idx_link1 ON l_track_track USING btree (link1);


--
-- Name: l_track_track_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_track_track_idx_uniq ON l_track_track USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_track_url_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_track_url_idx_link1 ON l_track_url USING btree (link1);


--
-- Name: l_track_url_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_track_url_idx_uniq ON l_track_url USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: l_url_url_idx_link1; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX l_url_url_idx_link1 ON l_url_url USING btree (link1);


--
-- Name: l_url_url_idx_uniq; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX l_url_url_idx_uniq ON l_url_url USING btree (link0, link1, link_type, begindate, enddate);


--
-- Name: label_gidindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX label_gidindex ON label USING btree (gid);


--
-- Name: label_meta_lastupdate; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX label_meta_lastupdate ON label_meta USING btree (lastupdate);


--
-- Name: label_nameindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX label_nameindex ON label USING btree (name);


--
-- Name: label_pageindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX label_pageindex ON label USING btree (page);


--
-- Name: label_tag_idx_label; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX label_tag_idx_label ON label_tag USING btree (label);


--
-- Name: label_tag_idx_tag; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX label_tag_idx_tag ON label_tag USING btree (tag);


--
-- Name: labelalias_nameindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX labelalias_nameindex ON labelalias USING btree (name);


--
-- Name: labelalias_refindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX labelalias_refindex ON labelalias USING btree (ref);


--
-- Name: labelwords_labelidindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX labelwords_labelidindex ON labelwords USING btree (labelid);


--
-- Name: language_isocode_2; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX language_isocode_2 ON language USING btree (isocode_2);


--
-- Name: language_isocode_3b; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX language_isocode_3b ON language USING btree (isocode_3b);


--
-- Name: language_isocode_3t; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX language_isocode_3t ON language USING btree (isocode_3t);


--
-- Name: link_attribute_idx_link_type; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX link_attribute_idx_link_type ON link_attribute USING btree (link, link_type);


--
-- Name: link_attribute_type_idx_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX link_attribute_type_idx_name ON link_attribute_type USING btree (name);


--
-- Name: link_attribute_type_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX link_attribute_type_idx_parent_name ON link_attribute_type USING btree (parent, name);


--
-- Name: lt_album_album_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_album_album_idx_mbid ON lt_album_album USING btree (mbid);


--
-- Name: lt_album_album_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_album_album_idx_parent_name ON lt_album_album USING btree (parent, name);


--
-- Name: lt_album_artist_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_album_artist_idx_mbid ON lt_album_artist USING btree (mbid);


--
-- Name: lt_album_artist_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_album_artist_idx_parent_name ON lt_album_artist USING btree (parent, name);


--
-- Name: lt_album_label_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_album_label_idx_mbid ON lt_album_label USING btree (mbid);


--
-- Name: lt_album_label_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_album_label_idx_parent_name ON lt_album_label USING btree (parent, name);


--
-- Name: lt_album_track_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_album_track_idx_mbid ON lt_album_track USING btree (mbid);


--
-- Name: lt_album_track_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_album_track_idx_parent_name ON lt_album_track USING btree (parent, name);


--
-- Name: lt_album_url_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_album_url_idx_mbid ON lt_album_url USING btree (mbid);


--
-- Name: lt_album_url_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_album_url_idx_parent_name ON lt_album_url USING btree (parent, name);


--
-- Name: lt_artist_artist_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_artist_artist_idx_mbid ON lt_artist_artist USING btree (mbid);


--
-- Name: lt_artist_artist_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_artist_artist_idx_parent_name ON lt_artist_artist USING btree (parent, name);


--
-- Name: lt_artist_label_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_artist_label_idx_mbid ON lt_artist_label USING btree (mbid);


--
-- Name: lt_artist_label_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_artist_label_idx_parent_name ON lt_artist_label USING btree (parent, name);


--
-- Name: lt_artist_track_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_artist_track_idx_mbid ON lt_artist_track USING btree (mbid);


--
-- Name: lt_artist_track_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_artist_track_idx_parent_name ON lt_artist_track USING btree (parent, name);


--
-- Name: lt_artist_url_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_artist_url_idx_mbid ON lt_artist_url USING btree (mbid);


--
-- Name: lt_artist_url_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_artist_url_idx_parent_name ON lt_artist_url USING btree (parent, name);


--
-- Name: lt_label_label_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_label_label_idx_mbid ON lt_label_label USING btree (mbid);


--
-- Name: lt_label_label_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_label_label_idx_parent_name ON lt_label_label USING btree (parent, name);


--
-- Name: lt_label_track_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_label_track_idx_mbid ON lt_label_track USING btree (mbid);


--
-- Name: lt_label_track_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_label_track_idx_parent_name ON lt_label_track USING btree (parent, name);


--
-- Name: lt_label_url_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_label_url_idx_mbid ON lt_label_url USING btree (mbid);


--
-- Name: lt_label_url_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_label_url_idx_parent_name ON lt_label_url USING btree (parent, name);


--
-- Name: lt_track_track_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_track_track_idx_mbid ON lt_track_track USING btree (mbid);


--
-- Name: lt_track_track_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_track_track_idx_parent_name ON lt_track_track USING btree (parent, name);


--
-- Name: lt_track_url_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_track_url_idx_mbid ON lt_track_url USING btree (mbid);


--
-- Name: lt_track_url_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_track_url_idx_parent_name ON lt_track_url USING btree (parent, name);


--
-- Name: lt_url_url_idx_mbid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_url_url_idx_mbid ON lt_url_url USING btree (mbid);


--
-- Name: lt_url_url_idx_parent_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX lt_url_url_idx_parent_name ON lt_url_url USING btree (parent, name);


--
-- Name: moderation_closed_idx_artist; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_closed_idx_artist ON moderation_closed USING btree (artist);


--
-- Name: moderation_closed_idx_closetime; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_closed_idx_closetime ON moderation_closed USING btree (closetime);


--
-- Name: moderation_closed_idx_expiretime; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_closed_idx_expiretime ON moderation_closed USING btree (expiretime);


--
-- Name: moderation_closed_idx_language; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_closed_idx_language ON moderation_closed USING btree (language);


--
-- Name: moderation_closed_idx_moderator; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_closed_idx_moderator ON moderation_closed USING btree (moderator);


--
-- Name: moderation_closed_idx_opentime; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_closed_idx_opentime ON moderation_closed USING btree (opentime);


--
-- Name: moderation_closed_idx_rowid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_closed_idx_rowid ON moderation_closed USING btree (rowid);


--
-- Name: moderation_closed_idx_status; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_closed_idx_status ON moderation_closed USING btree (status);


--
-- Name: moderation_note_closed_idx_moderation; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_note_closed_idx_moderation ON moderation_note_closed USING btree (moderation);


--
-- Name: moderation_note_open_idx_moderation; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_note_open_idx_moderation ON moderation_note_open USING btree (moderation);


--
-- Name: moderation_open_idx_artist; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_open_idx_artist ON moderation_open USING btree (artist);


--
-- Name: moderation_open_idx_expiretime; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_open_idx_expiretime ON moderation_open USING btree (expiretime);


--
-- Name: moderation_open_idx_language; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_open_idx_language ON moderation_open USING btree (language);


--
-- Name: moderation_open_idx_moderator; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_open_idx_moderator ON moderation_open USING btree (moderator);


--
-- Name: moderation_open_idx_rowid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_open_idx_rowid ON moderation_open USING btree (rowid);


--
-- Name: moderation_open_idx_status; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX moderation_open_idx_status ON moderation_open USING btree (status);


--
-- Name: moderator_nameindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX moderator_nameindex ON moderator USING btree (name);


--
-- Name: moderator_preference_moderator_key; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX moderator_preference_moderator_key ON moderator_preference USING btree (moderator, name);


--
-- Name: moderator_subscribe_artist_moderator_key; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX moderator_subscribe_artist_moderator_key ON moderator_subscribe_artist USING btree (moderator, artist);


--
-- Name: moderator_subscribe_label_moderator_key; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX moderator_subscribe_label_moderator_key ON moderator_subscribe_label USING btree (moderator, label);


--
-- Name: puid_puidindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX puid_puidindex ON puid USING btree (puid);


--
-- Name: puid_stat_puid_idindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX puid_stat_puid_idindex ON puid_stat USING btree (puid_id, month_id);


--
-- Name: puidjoin_puidtrack; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX puidjoin_puidtrack ON puidjoin USING btree (puid, track);


--
-- Name: puidjoin_stat_puidjoin_idindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX puidjoin_stat_puidjoin_idindex ON puidjoin_stat USING btree (puidjoin_id, month_id);


--
-- Name: puidjoin_trackindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX puidjoin_trackindex ON puidjoin USING btree (track);


--
-- Name: release_album; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX release_album ON release USING btree (album);


--
-- Name: release_group_artistindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX release_group_artistindex ON release_group USING btree (artist);


--
-- Name: release_group_gidindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX release_group_gidindex ON release_group USING btree (gid);


--
-- Name: release_group_nameindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX release_group_nameindex ON release_group USING btree (name);


--
-- Name: release_group_pageindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX release_group_pageindex ON release_group USING btree (page);


--
-- Name: release_groupwords_release_groupidindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX release_groupwords_release_groupidindex ON release_groupwords USING btree (release_groupid);


--
-- Name: release_label; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX release_label ON release USING btree (label);


--
-- Name: release_releasedate; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX release_releasedate ON release USING btree (releasedate);


--
-- Name: release_tag_idx_release; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX release_tag_idx_release ON release_tag USING btree (release);


--
-- Name: release_tag_idx_tag; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX release_tag_idx_tag ON release_tag USING btree (tag);


--
-- Name: script_isocode; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX script_isocode ON script USING btree (isocode);


--
-- Name: script_isonumber; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX script_isonumber ON script USING btree (isonumber);


--
-- Name: script_language_sl; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX script_language_sl ON script_language USING btree (script, language);


--
-- Name: stats_timestampindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX stats_timestampindex ON stats USING btree ("timestamp");


--
-- Name: tag_idx_name; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX tag_idx_name ON tag USING btree (name);


--
-- Name: track_artistindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX track_artistindex ON track USING btree (artist);


--
-- Name: track_gidindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX track_gidindex ON track USING btree (gid);


--
-- Name: track_nameindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX track_nameindex ON track USING btree (name);


--
-- Name: track_tag_idx_tag; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX track_tag_idx_tag ON track_tag USING btree (tag);


--
-- Name: track_tag_idx_track; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX track_tag_idx_track ON track_tag USING btree (track);


--
-- Name: trackwords_trackidindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX trackwords_trackidindex ON trackwords USING btree (trackid);


--
-- Name: url_idx_gid; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX url_idx_gid ON url USING btree (gid);


--
-- Name: url_idx_url; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX url_idx_url ON url USING btree (url);


--
-- Name: vote_closed_idx_moderation; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX vote_closed_idx_moderation ON vote_closed USING btree (moderation);


--
-- Name: vote_closed_idx_moderator; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX vote_closed_idx_moderator ON vote_closed USING btree (moderator);


--
-- Name: vote_open_idx_moderation; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX vote_open_idx_moderation ON vote_open USING btree (moderation);


--
-- Name: vote_open_idx_moderator; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE INDEX vote_open_idx_moderator ON vote_open USING btree (moderator);


--
-- Name: wordlist_wordindex; Type: INDEX; Schema: musicbrainz; Owner: -
--

CREATE UNIQUE INDEX wordlist_wordindex ON wordlist USING btree (word);


--
-- Name: PendingData_SeqId; Type: FK CONSTRAINT; Schema: musicbrainz; Owner: -
--

ALTER TABLE ONLY "PendingData"
    ADD CONSTRAINT "PendingData_SeqId" FOREIGN KEY ("SeqId") REFERENCES "Pending"("SeqId") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

