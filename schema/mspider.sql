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
-- Name: mspider; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA mspider;


SET search_path = mspider, pg_catalog;

--
-- Name: i_tasks(); Type: FUNCTION; Schema: mspider; Owner: -
--

CREATE FUNCTION i_tasks() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.type = TG_RELNAME;
	RETURN NEW;
END$$;


SET default_with_oids = false;

--
-- Name: tasks; Type: TABLE; Schema: mspider; Owner: -
--

CREATE TABLE tasks (
    id integer NOT NULL,
    type character varying(30) NOT NULL,
    date_added timestamp with time zone DEFAULT now() NOT NULL,
    date_processed timestamp with time zone,
    error text
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: mspider; Owner: -
--

CREATE SEQUENCE tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: mspider; Owner: -
--

ALTER SEQUENCE tasks_id_seq OWNED BY tasks.id;


--
-- Name: tasks_discogs_release; Type: TABLE; Schema: mspider; Owner: -
--

CREATE TABLE tasks_discogs_release (
    discogs_id integer NOT NULL
)
INHERITS (tasks);


--
-- Name: tasks_url; Type: TABLE; Schema: mspider; Owner: -
--

CREATE TABLE tasks_url (
    url character varying(255) NOT NULL
)
INHERITS (tasks);


--
-- Name: id; Type: DEFAULT; Schema: mspider; Owner: -
--

ALTER TABLE tasks ALTER COLUMN id SET DEFAULT nextval('tasks_id_seq'::regclass);


--
-- Name: flies_pkey; Type: CONSTRAINT; Schema: mspider; Owner: -
--

ALTER TABLE ONLY tasks
    ADD CONSTRAINT flies_pkey PRIMARY KEY (id);


--
-- Name: tasks_discogs_release_pkey; Type: CONSTRAINT; Schema: mspider; Owner: -
--

ALTER TABLE ONLY tasks_discogs_release
    ADD CONSTRAINT tasks_discogs_release_pkey PRIMARY KEY (id);


--
-- Name: tasks_url_pkey; Type: CONSTRAINT; Schema: mspider; Owner: -
--

ALTER TABLE ONLY tasks_url
    ADD CONSTRAINT tasks_url_pkey PRIMARY KEY (id);


--
-- Name: tasks_idx_type; Type: INDEX; Schema: mspider; Owner: -
--

CREATE INDEX tasks_idx_type ON tasks USING btree (type);


--
-- Name: tasks_discogs_release_trigger; Type: TRIGGER; Schema: mspider; Owner: -
--

CREATE TRIGGER tasks_discogs_release_trigger
    BEFORE INSERT ON tasks_discogs_release
    FOR EACH ROW
    EXECUTE PROCEDURE i_tasks();


--
-- Name: tasks_url_trigger; Type: TRIGGER; Schema: mspider; Owner: -
--

CREATE TRIGGER tasks_url_trigger
    BEFORE INSERT ON tasks_url
    FOR EACH ROW
    EXECUTE PROCEDURE i_tasks();


--
-- PostgreSQL database dump complete
--

