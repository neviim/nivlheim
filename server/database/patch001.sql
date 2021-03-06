SET client_min_messages TO WARNING;

DROP TABLE IF EXISTS waiting_for_approval;
DROP TABLE IF EXISTS support;
DROP TABLE IF EXISTS ipranges;
DROP TABLE IF EXISTS hostinfo;
DROP TABLE IF EXISTS files;
DROP TABLE IF EXISTS certificates;
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS db;

CREATE TABLE waiting_for_approval(
	approvalid serial PRIMARY KEY NOT NULL,
	ipaddr inet,
	hostname text,
	received timestamp with time zone,
	approved boolean
);

CREATE TABLE certificates(
	certid serial PRIMARY KEY NOT NULL,
	issued timestamp with time zone NOT NULL,
	fingerprint text NOT NULL,
	commonname text NOT NULL,
	previous int,
	first int,
	revoked boolean not null default false,
	nonce int,
	cert text NOT NULL
);

CREATE INDEX cert_fingerprint ON certificates(fingerprint);

CREATE TABLE files(
	fileid bigserial PRIMARY KEY NOT NULL,
	ipaddr inet,
	os_hostname text,
	certcn text,
	certfp text,
	filename text,
	received timestamp with time zone,
	mtime timestamp with time zone,
	content text,
	tsvec tsvector,
	crc32 int4,
	is_command boolean not null default false,
	clientversion text,
	parsed boolean not null default false,
	originalcertid int REFERENCES certificates(certid)
);

CREATE INDEX files_parsed ON files(parsed);
CREATE INDEX files_certfp_fname ON files(certfp,filename);
CREATE INDEX files_tsvec ON files USING gist(tsvec);

--start_of_procedures
CREATE OR REPLACE FUNCTION upd_tsvec() RETURNS TRIGGER AS $upd_tsvec$
	BEGIN
		IF (TG_OP = 'INSERT') THEN
			UPDATE files SET tsvec = to_tsvector('english', left(NEW.content,1024*1024))
				WHERE fileid=NEW.fileid;
			RETURN NEW;
		END IF;
	END;
$upd_tsvec$ LANGUAGE plpgsql;

CREATE TRIGGER files_update_tsvec
AFTER INSERT ON files
	FOR EACH ROW EXECUTE PROCEDURE upd_tsvec();
--end_of_procedures

CREATE TABLE tasks(
	taskid serial PRIMARY KEY NOT NULL,
	url text not null unique,
	lasttry timestamp with time zone,
	status int not null default 0,
	delay int not null default 0,
	delay2 int not null default 0
);

CREATE TABLE hostinfo(
	hostname text UNIQUE,
	os_hostname text,
	ipaddr inet,
	certfp text PRIMARY KEY NOT NULL,
	lastseen timestamp with time zone,
	os text,
	os_edition text,
	kernel text,
	vendor text,
	model text,
	serialno text,
	clientversion text,
	dnsttl timestamp with time zone
);

CREATE INDEX hostinfo_hostname ON hostinfo(hostname);
CREATE INDEX hostinfo_dnsttl ON hostinfo(dnsttl);

CREATE TABLE support(
	supportid serial PRIMARY KEY NOT NULL,
	serialno text NOT NULL,
	description text,
	start timestamp with time zone,
	expires timestamp with time zone,
	lastupdated timestamp with time zone
);

CREATE INDEX support_serial ON support(serialno);

CREATE TABLE ipranges(
	iprangeid serial PRIMARY KEY NOT NULL,
	iprange cidr NOT NULL,
	comment text,
	use_dns boolean not null default false
);

CREATE TABLE db(
	patchlevel int NOT NULL
);
INSERT INTO db(patchlevel) VALUES(1);
