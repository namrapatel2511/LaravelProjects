# Use official PHP image with required extensions
FROM php:8.2-fpm

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    curl \
    zip \
    unzip \
    git \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libzip-dev \
    nodejs \
    npm \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd mbstring zip pdo pdo_mysql

# Set working directory
WORKDIR /var/www

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy Laravel project files
COPY . .

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader

# Install Node.js dependencies and build assets
RUN npm install && npm run build

# Set permissions
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache /var/www/public/build

# Copy Nginx configuration
COPY nginx/default.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Create startup script
RUN echo '#!/bin/bash\n\
if [ ! -f /var/www/.env ]; then\n\
    echo ".env file not found. Copying from .env.example..."\n\
    cp /var/www/.env.example /var/www/.env\n\
    php /var/www/artisan key:generate\n\
    php /var/www/artisan config:clear\n\
    php /var/www/artisan cache:clear\n\
    php /var/www/artisan config:cache\n\
fi\n\
echo "Waiting for database..."\n\
until php /var/www/artisan migrate --force; do\n\
    echo "Database is not ready. Retrying in 5 seconds..."\n\
    sleep 5\n\
done\n\
echo "Database migration completed!"\n\
npm run build\n\
nginx -g "daemon off;" & php-fpm -F' > /start.sh \
    && chmod +x /start.sh

# Expose port 80
EXPOSE 80

# Start services
CMD ["/bin/bash", "/start.sh"]
