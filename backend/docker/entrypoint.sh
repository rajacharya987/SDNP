#!/bin/sh
set -e

cd /var/www

mkdir -p storage/framework/cache/data \
         storage/framework/sessions \
         storage/framework/views \
         storage/logs \
         bootstrap/cache

touch storage/logs/laravel.log 2>/dev/null || true
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
chmod -R ug+rwx storage bootstrap/cache 2>/dev/null || true

if [ ! -f vendor/autoload.php ]; then
  echo "[entrypoint] Installing Composer dependencies..."
  if [ "${APP_ENV:-local}" = "local" ]; then
    composer install --no-interaction --prefer-dist --optimize-autoloader
  else
    composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev --quiet
  fi
else
  composer dump-autoload --optimize --quiet 2>/dev/null || true
fi

if [ "${APP_ENV:-local}" != "local" ] && [ -f artisan ]; then
  php artisan config:cache --quiet 2>/dev/null || true
  php artisan route:cache --quiet 2>/dev/null || true
  php artisan event:cache --quiet 2>/dev/null || true
fi

exec "$@"