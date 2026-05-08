# Laravel Multi-App Docker Stack

A reusable Docker setup that hosts **multiple Laravel applications** behind a single nginx, sharing one PHP-FPM container, one MySQL server and one Redis server.

```
project-root/
├── apps/                  # your Laravel apps live here, one folder each
│   ├── app1/
│   └── app2/
└── docker/                # this folder
    ├── docker-compose.yml
    ├── .env.example
    ├── Makefile
    ├── nginx/
    │   ├── Dockerfile
    │   ├── nginx.conf
    │   ├── sites/         # one .conf per app — drop it in, restart nginx
    │   │   ├── app1.conf
    │   │   ├── app2.conf
    │   │   └── _template.conf.example
    │   └── ssl/
    ├── php/
    │   ├── Dockerfile     # PHP-FPM 8.3 (configurable) + extensions + composer
    │   ├── php.ini
    │   └── www.conf
    ├── mysql/
    │   ├── my.cnf
    │   └── init/
    │       └── 01-create-databases.sh
    ├── redis/
    │   └── redis.conf
    └── logs/              # bind-mounted runtime logs
```

## Quick start

```bash
cd docker
cp .env.example .env
# edit .env if you want different ports / passwords / app list

# (optional) put your Laravel apps in ../apps/<name>/
# or scaffold a fresh one once the stack is up:
make up
make new-app APP=app1
```

Then add the example hostnames to your `/etc/hosts`:

```
127.0.0.1 app1.localhost app2.localhost
```

Visit:

- `http://app1.localhost` → `apps/app1/public`
- `http://localhost:8081` → `apps/app2/public` (port-based example — also expose `8081` from the nginx service in `docker-compose.yml` if you want this to work)

## Adding a new Laravel app

1. **Drop the code in.** Place the Laravel project at `../apps/<name>/`. Either copy an existing project or run `make new-app APP=<name>` to scaffold one with composer.
2. **Create the database.** Add `<name>` to `MYSQL_MULTIPLE_DATABASES` in `.env` and re-create the mysql volume (`make down-volumes && make up`), or just `CREATE DATABASE` manually inside `make mysql-shell`.
3. **Add an nginx server block.** Copy `nginx/sites/_template.conf.example` to `nginx/sites/<name>.conf` and replace `APP_NAME`, `APP_HOST`, `APP_PORT`. If you used a new hostname, also add it to `/etc/hosts`. If you used a new port, expose it from the `nginx` service in `docker-compose.yml`.
4. **Wire the app's `.env`.** Inside `apps/<name>/.env`:

   ```env
   APP_URL=http://<name>.localhost

   DB_CONNECTION=mysql
   DB_HOST=mysql
   DB_PORT=3306
   DB_DATABASE=<name>
   DB_USERNAME=laravel
   DB_PASSWORD=secret

   REDIS_HOST=redis
   REDIS_PORT=6379
   REDIS_DB=0           # use a unique index per app to avoid collisions
   REDIS_CACHE_DB=1

   CACHE_STORE=redis
   SESSION_DRIVER=redis
   QUEUE_CONNECTION=redis
   ```

5. **Reload nginx.** `make restart` (or `docker compose exec nginx nginx -s reload`).

## Common commands

```bash
make up                            # start nginx + php + mysql + redis
make up-workers                    # also start queue worker + scheduler
make up-tools                      # also start phpMyAdmin on :8080
make down                          # stop everything
make logs                          # tail all logs

make php-shell                     # bash inside the php container
make mysql-shell                   # mysql client
make redis-shell                   # redis-cli

make artisan APP=app1 ARGS="migrate --seed"
make composer APP=app1 ARGS="require laravel/horizon"
make test APP=app1
```

## Queue workers and scheduler

The `queue` and `scheduler` services live behind the `workers` profile so they don't start by default. Pick which app they target via `.env`:

```env
QUEUE_APP_DIR=app1
SCHEDULER_APP_DIR=app1
```

To run workers for **multiple apps**, duplicate the `queue` block in `docker-compose.yml` and give each copy a unique `container_name` and `working_dir`. Same for the scheduler. Or run Horizon inside each app's PHP-FPM via `make artisan APP=<name> ARGS="horizon"` in a separate terminal.

## How the routing works

- `nginx` mounts `../apps` at `/var/www/apps` and reads every `.conf` file in `/etc/nginx/conf.d/`.
- Each server block points its `root` at `/var/www/apps/<name>/public` and forwards PHP requests to `php:9000`.
- The `php` service mounts the same `../apps` directory at the same path, so file paths line up between nginx (which resolves the script) and PHP-FPM (which runs it).

This means: **one PHP-FPM process pool serves every app**. That's efficient for development and small deployments, but if one app needs different PHP extensions or wildly different `php.ini` settings, give it its own PHP-FPM service (copy the `php` block, change the build args, point its nginx site config at the new upstream).

## Production notes

This stack is tuned for development. Before shipping to production:

- Set `opcache.validate_timestamps=0` in `php/php.ini`.
- Switch `display_errors` and Laravel's `APP_DEBUG` off.
- Generate proper TLS certs and reference them from each `nginx/sites/*.conf` (`listen 443 ssl;` + `ssl_certificate` / `ssl_certificate_key`).
- Tighten `pm.max_children` in `php/www.conf` to match the host's RAM.
- Move secrets out of `.env` into your secrets manager — don't bake them into images.
- Replace the published mysql/redis ports with internal-only access.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `502 Bad Gateway` from nginx | PHP-FPM container not running or app folder missing. `make logs` to confirm. |
| `Permission denied` writing storage/ logs | Host UID/GID mismatch. Set `UID` / `GID` in `.env` to your host user (`id -u`, `id -g`) and rebuild. |
| `SQLSTATE[HY000] [2002] Connection refused` | App `.env` uses `DB_HOST=127.0.0.1` instead of `DB_HOST=mysql`. |
| Database doesn't exist | `MYSQL_MULTIPLE_DATABASES` is only honored on first boot. Either `make down-volumes` (destroys data) or create the DB manually via `make mysql-shell`. |
| Site change not picked up | Nginx caches its config. `make restart` or `docker compose exec nginx nginx -s reload`. |
