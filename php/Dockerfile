ARG PHP_VERSION=8.3

FROM php:${PHP_VERSION}-fpm-alpine

ARG UID=1000
ARG GID=1000

# System dependencies + PHP extensions Laravel typically needs.
RUN set -eux; \
    apk add --no-cache \
        bash \
        curl \
        git \
        unzip \
        icu-dev \
        libzip-dev \
        oniguruma-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        libwebp-dev \
        postgresql-dev \
        $PHPIZE_DEPS \
        linux-headers; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-install -j"$(nproc)" \
        bcmath \
        exif \
        gd \
        intl \
        mbstring \
        opcache \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        zip; \
    pecl install redis; \
    docker-php-ext-enable redis; \
    apk del $PHPIZE_DEPS linux-headers; \
    rm -rf /tmp/* /var/cache/apk/*

# Composer 2
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Recreate the www-data user to match the host UID/GID so volume-mounted files
# stay editable from both sides.
RUN set -eux; \
    deluser --remove-home www-data 2>/dev/null || true; \
    addgroup -g "${GID}" -S www-data; \
    adduser -u "${UID}" -S -G www-data -h /home/www-data -s /bin/bash www-data; \
    mkdir -p /var/www/apps /var/log/php; \
    chown -R www-data:www-data /var/www/apps /var/log/php

USER www-data
WORKDIR /var/www/apps

EXPOSE 9000
CMD ["php-fpm"]
