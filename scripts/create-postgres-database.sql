CREATE EXTENSION hstore;
UPDATE pg_database SET datistemplate = FALSE WHERE datname = 'template1';
DROP DATABASE template1;
CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING = 'UTF-8';
UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template1';
UPDATE pg_database SET datallowconn = FALSE WHERE datname = 'template1';

CREATE USER pix WITH PASSWORD 'pixplzpixplzpixplz';

DROP DATABASE IF EXISTS pix;
CREATE DATABASE pix WITH ENCODING 'UTF8';

GRANT ALL PRIVILEGES ON DATABASE pix to pix;
