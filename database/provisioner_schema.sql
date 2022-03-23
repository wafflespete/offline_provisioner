--
-- PostgreSQL database dump
--

-- Dumped from database version 12.9 (Ubuntu 12.9-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.9 (Ubuntu 12.9-0ubuntu0.20.04.1)

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
-- Name: plpython3u; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpython3u WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpython3u; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpython3u IS 'PL/Python3U untrusted procedural language';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: add_ip(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_ip(hostname text) RETURNS character varying
    LANGUAGE plpython3u
    AS $$ 
    import socket
    if hostname is None: 
        return None  
    try:  
        ipv4 = socket.gethostbyname(hostname)
    except Exception as e:   
        ipv4 = 'ERROR'
    return ipv4  
$$;


ALTER FUNCTION public.add_ip(hostname text) OWNER TO postgres;

--
-- Name: add_state(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_state(hostname text) RETURNS character varying
    LANGUAGE plpython3u
    AS $$ 
    if hostname is None: 
        return None
    try:  
        state = hostname[:2]
    except Exception as e:  
        state = 'ERROR'
    if state == 'of':
        state = 'wi'
    return state 
$$;


ALTER FUNCTION public.add_state(hostname text) OWNER TO postgres;

--
-- Name: last_seen_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.last_seen_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
IF NEW.avail = 'Offline' THEN
        IF OLD.last_seen IS NULL THEN
            NEW.last_seen = NULL;
        ELSE 
            NULL;
        END IF;
    ELSIF NEW.avail = 'Retired' THEN
        NUll;
    ELSE
        New.last_seen = now();
END IF;
RETURN NEW;
END;
$$;


ALTER FUNCTION public.last_seen_update() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: client_init; Type: TABLE; Schema: public; Owner: postgres
--


CREATE TABLE public.clients (
    hostname text NOT NULL,
    state text,
    os text,
    supervisor boolean,
    ipv4 text,
    avail text,
    last_seen date,
    change_queue text[],
    test_group boolean,
    mac character varying NOT NULL
);


ALTER TABLE public.clients OWNER TO postgres;

--
-- Name: failure; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.failure (
    hostname character varying[],
    date character varying NOT NULL,
    failure text,
    job character varying
);


ALTER TABLE public.failure OWNER TO postgres;

--
-- Name: jobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.jobs (
    job text NOT NULL,
    variables character varying[]
);


ALTER TABLE public.jobs OWNER TO postgres;

--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (mac);

--
-- Name: failure failure_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.failure
    ADD CONSTRAINT failure_pkey PRIMARY KEY (date);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (job);


--
-- Name: clients last_seen_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER last_seen_trigger BEFORE UPDATE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.last_seen_update();


--
-- PostgreSQL database dump complete
--

