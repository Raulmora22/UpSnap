#!/bin/sh

cd /app/backend/ || exit

# wait for db and redis
if [ "${DB_TYPE}" != "sqlite" ]; then
    /usr/bin/env bash ./wait-for-it.sh "${DB_HOST}":"${DB_PORT}" -t 300 -s
    echo "sleeping 20"
    sleep 20
fi
/usr/bin/env bash ./wait-for-it.sh "${REDIS_HOST}":"${REDIS_PORT}" -t 300 -s

# set ping interval
if [ -z "$PING_INTERVAL" ]; then
    PING_INTERVAL=5
elif [ "$PING_INTERVAL" -lt 5 ]; then
    echo ""
    echo "Ping interval lower than 5 seconds is not recommended. Please use an interval of 5 seconds or higher. Automatically set to 5 seconds."
    echo ""
    PING_INTERVAL=5
fi

# create django secret key
if [ -z "$DJANGO_SECRET_KEY" ]; then
    DJANGO_SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
    export DJANGO_SECRET_KEY
fi

# init django
python3 manage.py makemigrations
python3 manage.py migrate
python3 manage.py collectstatic --noinput
python3 manage.py shell < setup.py
python3 -m celery -A backend worker &
python3 -m celery -A backend beat &
python3 -m gunicorn --bind 0.0.0.0:"${BACKEND_PORT}" --workers 4 backend.asgi:application -k uvicorn.workers.UvicornWorker &

# start frontend
cd /app/frontend/ || exit
npm install
npm run build
PORT=$FRONTEND_PORT npm start