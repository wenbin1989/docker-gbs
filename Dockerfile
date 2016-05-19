FROM wenbin1989/php-nginx:5.6
MAINTAINER Wenbin Wang <wenbin1989@gmail.com>

# install persistent / runtime deps
RUN apt-get update && apt-get install -y \
        imagemagick \
        xpdf \
        libfreetype6 \
        libgif4 \
        libicu52 \
        libjpeg62-turbo \
        libmcrypt4 \
        libpng12-0 \
        libpq5 \
    --no-install-recommends && rm -r /var/lib/apt/lists/*

# install PHP extensions and swftools
ENV SWFTOOLS_FILENAME swftools-0.9.2.tar.gz
ENV XPDF_FILENAME xpdf-3.04.tar.gz

RUN set -xe \
    && buildDeps=" \
        libbz2-dev \
        libfreetype6-dev \
        libgif-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libmagickwand-dev \
        libmcrypt-dev \
        libpng12-dev \
        libpq-dev \
    " \
    && apt-get update && apt-get install -y $buildDeps --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
        --with-png-dir=/usr/include --enable-gd-native-ttf \
    && docker-php-ext-install -j$(nproc) bz2 gd intl mbstring mcrypt mysqli opcache pdo_mysql pcntl zip \
    && echo '' | pecl install imagick \
    && pecl install rar \
    && pecl install redis \
    && pecl install xdebug \
    # Note that we only need xdebug in development environment, so we did not enable it here.
    && docker-php-ext-enable imagick rar redis \
    && curl -fSL "http://www.swftools.org/$SWFTOOLS_FILENAME" -o "$SWFTOOLS_FILENAME" \
    && mkdir -p /usr/src/swftools \
    && tar -xf "$SWFTOOLS_FILENAME" -C /usr/src/swftools --strip-components=1 \
    && rm "$SWFTOOLS_FILENAME" \
    && curl -fSL "ftp://ftp.foolabs.com/pub/xpdf/$XPDF_FILENAME" \
        -o "/usr/src/swftools/lib/pdf/$XPDF_FILENAME" \
    && sed -i "s/ -o -L.*//" /usr/src/swftools/swfs/Makefile.in \
    && cd /usr/src/swftools \
    && ./configure \
    && make -C /usr/src/swftools -j"$(nproc)" \
    && make -C /usr/src/swftools install \
    && make -C /usr/src/swftools clean \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $buildDeps

# install ionCube Loader extention
# Note that ionCube Loader will impact on performance, so we do not enable it here.
# When we need it in the production environment, we can enable it through .ini file.
RUN curl -fSL "http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz" \
        -o "ioncube_loaders_lin_x86-64.tar.gz" \
    && mkdir -p /usr/src/ioncube \
    && tar -xf "ioncube_loaders_lin_x86-64.tar.gz" -C /usr/src/ioncube --strip-components=1 \
    && cp -f /usr/src/ioncube/ioncube_loader_lin_"$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')".so "$(php -r 'echo ini_get("extension_dir");')" \
    && rm -rf ioncube_loaders_lin_x86-64.tar.gz /usr/src/ioncube

# install composer
RUN set -x \
    && curl -fSL "https://getcomposer.org/installer" -o composer-setup.php \
    && php composer-setup.php \
    && mv composer.phar /usr/local/bin/composer \
    && rm -f composer-setup.php \
    && composer self-update
# global install composer asset plugin, needed for yii2.
RUN composer global require "fxp/composer-asset-plugin:~1.1.1"

# copy entrypoint scripts
COPY entrypoint /entrypoint
# copy configurations
COPY etc/nginx-default.conf /etc/nginx/conf.d/default.conf
COPY etc/php.ini-Production /usr/local/etc/php/php.ini

VOLUME ["/var/www/html/server/uploads"]

