#!/bin/bash

###############################################################################
# Church Services App - Application Setup Script
# Run after install-interactive.sh, as regular user (not root)
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

APP_DIR="/var/www/church-services"
CONFIG_FILE="$HOME/.church-services-config"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Configuration file not found!${NC}"
    echo "Please run install-interactive.sh first."
    exit 1
fi

# Load configuration
source "$CONFIG_FILE"

clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║            Church Services App - Setup                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

###############################################################################
# STEP 1: Create Laravel Project
###############################################################################

echo -e "${CYAN}Step 1: Creating Laravel Project${NC}"
echo ""

cd /var/www
composer create-project laravel/laravel church-services

cd $APP_DIR

echo -e "${GREEN}✓ Laravel project created${NC}"
echo ""

###############################################################################
# STEP 2: Install PHP Dependencies
###############################################################################

echo -e "${CYAN}Step 2: Installing PHP Packages${NC}"
echo ""

# Core packages
composer require inertiajs/inertia-laravel
composer require beyondcode/laravel-websockets
composer require laravel/sanctum
composer require intervention/image-laravel
composer require maatwebsite/excel
composer require barryvdh/laravel-debugbar --dev

# AWS SDK if S3 enabled
if [[ "$ENABLE_S3" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}→ Installing AWS S3 support...${NC}"
    composer require --with-all-dependencies league/flysystem-aws-s3-v3 "^3.0"
fi

echo -e "${GREEN}✓ PHP packages installed${NC}"
echo ""

###############################################################################
# STEP 3: Install Frontend Dependencies
###############################################################################

echo -e "${CYAN}Step 3: Installing Frontend Packages${NC}"
echo ""

npm install

# Vue 3 + Inertia
npm install @inertiajs/vue3 @vitejs/plugin-vue vue

# Tailwind CSS
npm install -D tailwindcss postcss autoprefixer @tailwindcss/forms
npx tailwindcss init -p

# Additional packages
npm install @headlessui/vue @heroicons/vue
npm install laravel-echo pusher-js
npm install sortablejs vue-sortable
npm install chart.js vue-chartjs

echo -e "${GREEN}✓ Frontend packages installed${NC}"
echo ""

###############################################################################
# STEP 4: Configure Files
###############################################################################

echo -e "${CYAN}Step 4: Configuring Application${NC}"
echo ""

# Tailwind config
cat > tailwind.config.js << 'EOF'
export default {
  content: [
    "./resources/**/*.blade.php",
    "./resources/**/*.js",
    "./resources/**/*.vue",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f0f9ff',
          100: '#e0f2fe',
          200: '#bae6fd',
          300: '#7dd3fc',
          400: '#38bdf8',
          500: '#0ea5e9',
          600: '#0284c7',
          700: '#0369a1',
          800: '#075985',
          900: '#0c4a6e',
        },
      },
    },
  },
  plugins: [require('@tailwindcss/forms')],
}
EOF

# Vite config
cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
        vue({
            template: {
                transformAssetUrls: {
                    base: null,
                    includeAbsolute: false,
                },
            },
        }),
    ],
    resolve: {
        alias: {
            '@': '/resources/js',
        },
    },
});
EOF

# App CSS
cat > resources/css/app.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer components {
    .btn-primary {
        @apply bg-primary-600 hover:bg-primary-700 text-white font-semibold py-2 px-4 rounded-lg transition duration-150 ease-in-out;
    }
    
    .btn-secondary {
        @apply bg-gray-600 hover:bg-gray-700 text-white font-semibold py-2 px-4 rounded-lg transition duration-150 ease-in-out;
    }
    
    .card {
        @apply bg-white shadow-md rounded-lg p-6;
    }
    
    .input-field {
        @apply mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500;
    }
}
EOF

# Create directories
mkdir -p resources/js/Components
mkdir -p resources/js/Pages
mkdir -p resources/js/Layouts

# App.js
cat > resources/js/app.js << 'EOF'
import './bootstrap';
import '../css/app.css';

import { createApp, h } from 'vue';
import { createInertiaApp } from '@inertiajs/vue3';
import { resolvePageComponent } from 'laravel-vite-plugin/inertia-helpers';
import { ZiggyVue } from '../../vendor/tightenco/ziggy/dist/vue.m';

const appName = import.meta.env.VITE_APP_NAME || 'Church Services';

createInertiaApp({
    title: (title) => `${title} - ${appName}`,
    resolve: (name) => resolvePageComponent(`./Pages/${name}.vue`, import.meta.glob('./Pages/**/*.vue')),
    setup({ el, App, props, plugin }) {
        return createApp({ render: () => h(App, props) })
            .use(plugin)
            .use(ZiggyVue)
            .mount(el);
    },
    progress: {
        color: '#0ea5e9',
    },
});
EOF

# Bootstrap.js
cat > resources/js/bootstrap.js << 'EOF'
import axios from 'axios';
window.axios = axios;

window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';

import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

window.Pusher = Pusher;

window.Echo = new Echo({
    broadcaster: 'pusher',
    key: import.meta.env.VITE_PUSHER_APP_KEY,
    wsHost: import.meta.env.VITE_PUSHER_HOST ?? window.location.hostname,
    wsPort: import.meta.env.VITE_PUSHER_PORT ?? 6001,
    wssPort: import.meta.env.VITE_PUSHER_PORT ?? 6001,
    forceTLS: (import.meta.env.VITE_PUSHER_SCHEME ?? 'https') === 'https',
    enabledTransports: ['ws', 'wss'],
    disableStats: true,
});
EOF

echo -e "${GREEN}✓ Frontend configured${NC}"
echo ""

###############################################################################
# STEP 5: Environment Configuration
###############################################################################

echo -e "${CYAN}Step 5: Configuring Environment${NC}"
echo ""

cp .env.example .env

# Generate application key
php artisan key:generate

# Determine mail configuration
if [[ "$ENABLE_SES" =~ ^[Yy]$ ]]; then
    MAIL_DRIVER="ses"
    MAIL_CONFIG="
AWS_ACCESS_KEY_ID=$SES_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=$SES_SECRET_KEY
AWS_DEFAULT_REGION=$SES_REGION
"
elif [ -n "$SMTP_HOST" ]; then
    MAIL_DRIVER="smtp"
    MAIL_CONFIG="
MAIL_HOST=$SMTP_HOST
MAIL_PORT=$SMTP_PORT
MAIL_USERNAME=$SMTP_USER
MAIL_PASSWORD=$SMTP_PASS
MAIL_FROM_ADDRESS=$SMTP_FROM
"
else
    MAIL_DRIVER="log"
    MAIL_CONFIG=""
fi

# Determine filesystem configuration
if [[ "$ENABLE_S3" =~ ^[Yy]$ ]]; then
    FILESYSTEM_DISK="s3"
    S3_CONFIG="
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
AWS_DEFAULT_REGION=$AWS_REGION
AWS_BUCKET=$S3_BUCKET
"
else
    FILESYSTEM_DISK="local"
    S3_CONFIG=""
fi

# Determine protocol
if [ "$ENABLE_CLOUDFLARE" = true ] || [ "$USE_LETSENCRYPT" = true ]; then
    APP_URL="https://$DOMAIN_NAME"
else
    APP_URL="http://$DOMAIN_NAME"
fi

# Update .env
cat > .env << EOF
APP_NAME="$CHURCH_NAME"
APP_ENV=production
APP_KEY=$(grep APP_KEY .env | cut -d '=' -f2)
APP_DEBUG=false
APP_URL=$APP_URL

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=church_services
DB_USERNAME=church_app
DB_PASSWORD=$DB_PASSWORD

SESSION_DRIVER=redis
SESSION_LIFETIME=120

BROADCAST_CONNECTION=pusher
FILESYSTEM_DISK=$FILESYSTEM_DISK
QUEUE_CONNECTION=redis

CACHE_STORE=redis

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=$MAIL_DRIVER
MAIL_FROM_ADDRESS="${SES_FROM_EMAIL:-noreply@$DOMAIN_NAME}"
MAIL_FROM_NAME="$CHURCH_NAME"
$MAIL_CONFIG

$S3_CONFIG

PUSHER_APP_ID=local
PUSHER_APP_KEY=local
PUSHER_APP_SECRET=local
PUSHER_HOST=127.0.0.1
PUSHER_PORT=6001
PUSHER_SCHEME=http

VITE_APP_NAME="\${APP_NAME}"
VITE_PUSHER_APP_KEY="\${PUSHER_APP_KEY}"
VITE_PUSHER_HOST="\${PUSHER_HOST}"
VITE_PUSHER_PORT="\${PUSHER_PORT}"
VITE_PUSHER_SCHEME="\${PUSHER_SCHEME}"
EOF

# Configure S3 filesystem if enabled
if [[ "$ENABLE_S3" =~ ^[Yy]$ ]]; then
    cat > config/filesystems.php << 'EOF'
<?php
return [
    'default' => env('FILESYSTEM_DISK', 's3'),
    'disks' => [
        'local' => [
            'driver' => 'local',
            'root' => storage_path('app'),
            'throw' => false,
        ],
        'public' => [
            'driver' => 'local',
            'root' => storage_path('app/public'),
            'url' => env('APP_URL').'/storage',
            'visibility' => 'public',
            'throw' => false,
        ],
        's3' => [
            'driver' => 's3',
            'key' => env('AWS_ACCESS_KEY_ID'),
            'secret' => env('AWS_SECRET_ACCESS_KEY'),
            'region' => env('AWS_DEFAULT_REGION'),
            'bucket' => env('AWS_BUCKET'),
            'url' => env('AWS_URL'),
            'endpoint' => env('AWS_ENDPOINT'),
            'use_path_style_endpoint' => env('AWS_USE_PATH_STYLE_ENDPOINT', false),
            'throw' => false,
        ],
    ],
    'links' => [
        public_path('storage') => storage_path('app/public'),
    ],
];
EOF
fi

echo -e "${GREEN}✓ Environment configured${NC}"
echo ""

###############################################################################
# STEP 6: Set Permissions
###############################################################################

echo -e "${CYAN}Step 6: Setting Permissions${NC}"
echo ""

sudo chown -R $USER:www-data $APP_DIR
sudo chmod -R 775 $APP_DIR/storage
sudo chmod -R 775 $APP_DIR/bootstrap/cache

echo -e "${GREEN}✓ Permissions set${NC}"
echo ""

###############################################################################
# STEP 7: Publish Configurations
###############################################################################

echo -e "${CYAN}Step 7: Publishing Vendor Assets${NC}"
echo ""

php artisan vendor:publish --provider="BeyondCode\LaravelWebSockets\WebSocketsServiceProvider" --tag="migrations"
php artisan vendor:publish --provider="BeyondCode\LaravelWebSockets\WebSocketsServiceProvider" --tag="config"

composer require tightenco/ziggy

echo -e "${GREEN}✓ Vendor assets published${NC}"
echo ""

###############################################################################
# STEP 8: Create Admin User
###############################################################################

echo -e "${CYAN}Step 8: Creating Admin User${NC}"
echo ""

# Create a simple PHP script to create admin user
cat > create-admin.php << 'PHPSCRIPT'
<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

$user = new App\Models\User();
$user->name = getenv('ADMIN_NAME');
$user->email = getenv('ADMIN_EMAIL');
$user->password = bcrypt(getenv('ADMIN_PASSWORD'));
$user->email_verified_at = now();
$user->save();

echo "Admin user created: " . $user->email . "\n";
PHPSCRIPT

# Export variables and run script
export ADMIN_NAME="$ADMIN_NAME"
export ADMIN_EMAIL="$ADMIN_EMAIL"
export ADMIN_PASSWORD="$ADMIN_PASSWORD"

# We'll create this after migrations
echo -e "${YELLOW}Admin user will be created after database setup${NC}"
echo ""

###############################################################################
# Final Instructions
###############################################################################

clear
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           Application Setup Complete!                         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo ""
echo "1. Copy migration files:"
echo -e "   ${YELLOW}cp ~/migrations/*.php database/migrations/${NC}"
echo ""
echo "2. Copy database seeder:"
echo -e "   ${YELLOW}cp ~/DatabaseSeeder.php database/seeders/${NC}"
echo ""
echo "3. Run database migrations:"
echo -e "   ${YELLOW}php artisan migrate${NC}"
echo ""
echo "4. Create admin user:"
echo -e "   ${YELLOW}ADMIN_NAME='$ADMIN_NAME' ADMIN_EMAIL='$ADMIN_EMAIL' ADMIN_PASSWORD='$ADMIN_PASSWORD' php create-admin.php${NC}"
echo ""
echo "5. Build frontend assets:"
echo -e "   ${YELLOW}npm run build${NC}"
echo ""
echo "6. Start background services:"
echo -e "   ${YELLOW}sudo supervisorctl reread${NC}"
echo -e "   ${YELLOW}sudo supervisorctl update${NC}"
echo -e "   ${YELLOW}sudo supervisorctl start all${NC}"
echo ""
echo "7. Visit your application:"
echo -e "   ${GREEN}$APP_URL${NC}"
echo ""

if [[ "$ENABLE_S3" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}AWS S3 Storage:${NC}"
    echo "  ✓ Files will be stored in: s3://$S3_BUCKET"
    echo ""
fi

if [[ "$ENABLE_SES" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}AWS SES Email:${NC}"
    echo "  ✓ Emails will be sent from: $SES_FROM_EMAIL"
    echo "  ⚠ Make sure to verify this email in AWS SES console"
    echo ""
fi

if [ "$ENABLE_CLOUDFLARE" = true ]; then
    echo -e "${CYAN}Cloudflare:${NC}"
    echo "  ✓ Configure SSL/TLS mode to 'Full (strict)' in Cloudflare"
    echo "  ✓ Enable 'Always Use HTTPS'"
    echo ""
fi

echo -e "${YELLOW}Login Credentials:${NC}"
echo "  Email: $ADMIN_EMAIL"
echo "  Password: [as configured during setup]"
echo ""
