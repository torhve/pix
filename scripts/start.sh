service postgresql start
service redis-server start
cd pix
bin/worker.py &
lapis server development
