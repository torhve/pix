CREATE EXTENSION hstore;
CREATE USER pix WITH PASSWORD 'my secret super password';

--DROP DATABASE IF EXISTS pix;
CREATE DATABASE pix WITH ENCODING 'UTF8';

GRANT ALL PRIVILEGES ON DATABASE pix to pix;