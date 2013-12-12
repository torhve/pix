su postgres -c "/usr/lib/postgresql/9.3/bin/postgres -D /var/lib/postgresql/9.3/main -c config_file=/etc/postgresql/9.3/main/postgresql.conf" &
sleep 1
su postgres -c "psql < /pix/scripts/create-postgres-database.sql"
su postgres -c 'echo "create extension hstore;" | psql pix'
cd pix
lapis server development &
sleep 3
wget -O/dev/stdout http://127.0.0.1:8080/db/make
