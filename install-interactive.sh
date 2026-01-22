#!/bin/bash

###############################################################################
# Church Services App - Interactive Installation Script
# For Ubuntu 22.04 / 24.04 LTS on AWS Lightsail
# Run as root: sudo bash install.sh
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Get the actual user who ran sudo
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║         Church Services Production App Installer             ║
║                                                               ║
║     Integrates: Planning Center + ProPresenter + Teams       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}Welcome! This installer will set up your church services app.${NC}"
echo -e "${YELLOW}Please have the following information ready:${NC}"
echo "  • Your domain name (or use server IP)"
echo "  • Database password"
echo "  • AWS credentials for S3 and SES"
echo "  • Cloudflare account (optional but recommended)"
echo ""
read -p "Press Enter to continue..."

###############################################################################
# STEP 1: Collect Configuration
###############################################################################

clear
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Step 1: Configuration${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

# Church/App Name
echo -e "${BLUE}What is your church or organization name?${NC}"
read -p "Church Name: " CHURCH_NAME
CHURCH_NAME=${CHURCH_NAME:-"My Church"}

# Domain Configuration
echo ""
echo -e "${BLUE}Domain Configuration${NC}"
echo "Enter your domain name (e.g., services.mychurch.com)"
echo "Or press Enter to use server IP (you can change this later)"
read -p "Domain: " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me)
    DOMAIN_NAME=$SERVER_IP
    USE_IP=true
    echo -e "${YELLOW}Using IP address: $SERVER_IP${NC}"
else
    USE_IP=false
    echo -e "${GREEN}Domain configured: $DOMAIN_NAME${NC}"
fi

# Database Password
echo ""
echo -e "${BLUE}Database Configuration${NC}"
while true; do
    echo "Enter a secure password for PostgreSQL (min 12 characters)"
    read -sp "Database Password: " DB_PASSWORD
    echo ""
    if [ ${#DB_PASSWORD} -lt 12 ]; then
        echo -e "${RED}Password must be at least 12 characters${NC}"
        continue
    fi
    read -sp "Confirm Password: " DB_PASSWORD_CONFIRM
    echo ""
    if [ "$DB_PASSWORD" = "$DB_PASSWORD_CONFIRM" ]; then
        echo -e "${GREEN}✓ Password set${NC}"
        break
    else
        echo -e "${RED}Passwords don't match. Try again.${NC}"
    fi
done

# Admin User
echo ""
echo -e "${BLUE}Admin Account${NC}"
echo "Create the first admin user account"
read -p "Admin Name: " ADMIN_NAME
ADMIN_NAME=${ADMIN_NAME:-"Admin User"}

while true; do
    read -p "Admin Email: " ADMIN_EMAIL
    if [[ "$ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        break
    else
        echo -e "${RED}Invalid email format${NC}"
    fi
done

while true; do
    read -sp "Admin Password: " ADMIN_PASSWORD
    echo ""
    if [ ${#ADMIN_PASSWORD} -lt 8 ]; then
        echo -e "${RED}Password must be at least 8 characters${NC}"
        continue
    fi
    read -sp "Confirm Password: " ADMIN_PASSWORD_CONFIRM
    echo ""
    if [ "$ADMIN_PASSWORD" = "$ADMIN_PASSWORD_CONFIRM" ]; then
        break
    else
        echo -e "${RED}Passwords don't match${NC}"
    fi
done

# AWS S3 Configuration
echo ""
echo -e "${BLUE}AWS S3 Configuration (for file storage)${NC}"
echo "You'll need an AWS account with S3 access"
echo "Create an IAM user with S3 permissions first"
read -p "Enable S3 storage? (y/n) [y]: " ENABLE_S3
ENABLE_S3=${ENABLE_S3:-y}

if [[ "$ENABLE_S3" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Enter your AWS credentials (from IAM user)"
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY
    read -sp "AWS Secret Access Key: " AWS_SECRET_KEY
    echo ""
    read -p "AWS Region (e.g., us-east-1): " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    read -p "S3 Bucket Name: " S3_BUCKET
    echo -e "${GREEN}✓ S3 configured${NC}"
else
    echo -e "${YELLOW}S3 disabled - files will be stored locally${NC}"
fi

# AWS SES Configuration
echo ""
echo -e "${BLUE}AWS SES Configuration (for email)${NC}"
echo "You can use SES for reliable email delivery"
read -p "Enable AWS SES for email? (y/n) [y]: " ENABLE_SES
ENABLE_SES=${ENABLE_SES:-y}

if [[ "$ENABLE_SES" =~ ^[Yy]$ ]]; then
    if [[ "$ENABLE_S3" =~ ^[Yy]$ ]]; then
        echo "Use the same AWS credentials? (y/n) [y]: "
        read -p "" SAME_AWS
        SAME_AWS=${SAME_AWS:-y}
        if [[ "$SAME_AWS" =~ ^[Yy]$ ]]; then
            SES_ACCESS_KEY=$AWS_ACCESS_KEY
            SES_SECRET_KEY=$AWS_SECRET_KEY
            SES_REGION=$AWS_REGION
        else
            read -p "SES Access Key ID: " SES_ACCESS_KEY
            read -sp "SES Secret Access Key: " SES_SECRET_KEY
            echo ""
            read -p "SES Region: " SES_REGION
        fi
    else
        read -p "AWS Access Key ID: " SES_ACCESS_KEY
        read -sp "AWS Secret Access Key: " SES_SECRET_KEY
        echo ""
        read -p "AWS Region (e.g., us-east-1): " SES_REGION
        SES_REGION=${SES_REGION:-us-east-1}
    fi
    read -p "From Email Address: " SES_FROM_EMAIL
    SES_FROM_NAME="${CHURCH_NAME}"
    echo -e "${GREEN}✓ SES configured${NC}"
else
    echo "Configure SMTP instead? (y/n) [n]: "
    read -p "" ENABLE_SMTP
    if [[ "$ENABLE_SMTP" =~ ^[Yy]$ ]]; then
        read -p "SMTP Host: " SMTP_HOST
        read -p "SMTP Port [587]: " SMTP_PORT
        SMTP_PORT=${SMTP_PORT:-587}
        read -p "SMTP Username: " SMTP_USER
        read -sp "SMTP Password: " SMTP_PASS
        echo ""
        read -p "From Email: " SMTP_FROM
        echo -e "${GREEN}✓ SMTP configured${NC}"
    else
        echo -e "${YELLOW}Email disabled - you'll need to configure this later${NC}"
    fi
fi

# Cloudflare Configuration
echo ""
echo -e "${BLUE}Cloudflare Configuration${NC}"
echo "Cloudflare provides CDN, SSL, DDoS protection, and more"
if [ "$USE_IP" = true ]; then
    echo -e "${YELLOW}Note: You'll need a domain name to use Cloudflare${NC}"
    ENABLE_CLOUDFLARE=false
else
    read -p "Configure Cloudflare? (y/n) [y]: " ENABLE_CF
    ENABLE_CF=${ENABLE_CF:-y}
    if [[ "$ENABLE_CF" =~ ^[Yy]$ ]]; then
        ENABLE_CLOUDFLARE=true
        echo ""
        echo "You'll need to:"
        echo "  1. Add your domain to Cloudflare"
        echo "  2. Point your domain's nameservers to Cloudflare"
        echo "  3. Create an A record pointing to: $SERVER_IP"
        echo ""
        read -p "Have you done this already? (y/n): " CF_READY
        if [[ ! "$CF_READY" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}We'll configure SSL with Let's Encrypt instead${NC}"
            ENABLE_CLOUDFLARE=false
            USE_LETSENCRYPT=true
        fi
    else
        ENABLE_CLOUDFLARE=false
        read -p "Use Let's Encrypt for SSL? (y/n) [y]: " USE_LE
        USE_LE=${USE_LE:-y}
        USE_LETSENCRYPT=[[ "$USE_LE" =~ ^[Yy]$ ]]
    fi
fi

# Configuration Summary
clear
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Configuration Summary${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Church Name:${NC} $CHURCH_NAME"
echo -e "${GREEN}Domain:${NC} $DOMAIN_NAME"
echo -e "${GREEN}Admin Email:${NC} $ADMIN_EMAIL"
echo ""
echo -e "${GREEN}Services Enabled:${NC}"
[[ "$ENABLE_S3" =~ ^[Yy]$ ]] && echo "  ✓ AWS S3 Storage" || echo "  ✗ Local Storage"
[[ "$ENABLE_SES" =~ ^[Yy]$ ]] && echo "  ✓ AWS SES Email" || echo "  ✗ Email disabled"
[ "$ENABLE_CLOUDFLARE" = true ] && echo "  ✓ Cloudflare CDN" || echo "  ✗ Direct connection"
[ "$USE_LETSENCRYPT" = true ] && echo "  ✓ Let's Encrypt SSL" || echo "  ✗ No SSL"
echo ""
read -p "Continue with installation? (y/n) [y]: " CONFIRM
CONFIRM=${CONFIRM:-y}

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation cancelled${NC}"
    exit 1
fi

# Save configuration
CONFIG_FILE="$ACTUAL_HOME/.church-services-config"
cat > "$CONFIG_FILE" << EOF
CHURCH_NAME="$CHURCH_NAME"
DOMAIN_NAME="$DOMAIN_NAME"
DB_PASSWORD="$DB_PASSWORD"
ADMIN_NAME="$ADMIN_NAME"
ADMIN_EMAIL="$ADMIN_EMAIL"
ADMIN_PASSWORD="$ADMIN_PASSWORD"
ENABLE_S3="$ENABLE_S3"
AWS_ACCESS_KEY="$AWS_ACCESS_KEY"
AWS_SECRET_KEY="$AWS_SECRET_KEY"
AWS_REGION="$AWS_REGION"
S3_BUCKET="$S3_BUCKET"
ENABLE_SES="$ENABLE_SES"
SES_ACCESS_KEY="$SES_ACCESS_KEY"
SES_SECRET_KEY="$SES_SECRET_KEY"
SES_REGION="$SES_REGION"
SES_FROM_EMAIL="$SES_FROM_EMAIL"
SES_FROM_NAME="$SES_FROM_NAME"
SMTP_HOST="$SMTP_HOST"
SMTP_PORT="$SMTP_PORT"
SMTP_USER="$SMTP_USER"
SMTP_PASS="$SMTP_PASS"
SMTP_FROM="$SMTP_FROM"
ENABLE_CLOUDFLARE="$ENABLE_CLOUDFLARE"
USE_LETSENCRYPT="$USE_LETSENCRYPT"
EOF
chmod 600 "$CONFIG_FILE"
chown $ACTUAL_USER:$ACTUAL_USER "$CONFIG_FILE"

###############################################################################
# STEP 2: System Installation
###############################################################################

clear
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Step 2: Installing System Packages${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

# Update system
echo -e "${YELLOW}→ Updating system packages...${NC}"
apt update && apt upgrade -y

# Install essential packages
echo -e "${YELLOW}→ Installing essential packages...${NC}"
apt install -y software-properties-common curl wget git unzip supervisor

# Add PHP repository
echo -e "${YELLOW}→ Adding PHP 8.3 repository...${NC}"
add-apt-repository ppa:ondrej/php -y
apt update

# Install PHP 8.3 and extensions
echo -e "${YELLOW}→ Installing PHP 8.3 and extensions...${NC}"
apt install -y php8.3-fpm php8.3-cli php8.3-common php8.3-mysql php8.3-pgsql \
    php8.3-zip php8.3-gd php8.3-mbstring php8.3-curl php8.3-xml php8.3-bcmath \
    php8.3-redis php8.3-intl php8.3-soap php8.3-imagick

# Install Composer
echo -e "${YELLOW}→ Installing Composer...${NC}"
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Install Node.js 20.x LTS
echo -e "${YELLOW}→ Installing Node.js 20.x LTS...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Install PostgreSQL
echo -e "${YELLOW}→ Installing PostgreSQL...${NC}"
apt install -y postgresql postgresql-contrib

# Install Redis
echo -e "${YELLOW}→ Installing Redis...${NC}"
apt install -y redis-server

# Install Nginx
echo -e "${YELLOW}→ Installing Nginx...${NC}"
apt install -y nginx

# Install Certbot if needed
if [ "$USE_LETSENCRYPT" = true ] && [ "$USE_IP" = false ]; then
    echo -e "${YELLOW}→ Installing Certbot...${NC}"
    apt install -y certbot python3-certbot-nginx
fi

echo -e "${GREEN}✓ System packages installed${NC}"

###############################################################################
# STEP 3: Configure Services
###############################################################################

clear
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Step 3: Configuring Services${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

# Configure PostgreSQL
echo -e "${YELLOW}→ Configuring PostgreSQL...${NC}"
sudo -u postgres psql -c "CREATE DATABASE church_services;" 2>/dev/null || echo "Database already exists"
sudo -u postgres psql -c "CREATE USER church_app WITH PASSWORD '$DB_PASSWORD';" 2>/dev/null || echo "User already exists"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE church_services TO church_app;"
sudo -u postgres psql -c "ALTER DATABASE church_services OWNER TO church_app;"

# Configure Redis
echo -e "${YELLOW}→ Configuring Redis...${NC}"
sed -i 's/supervised no/supervised systemd/' /etc/redis/redis.conf
systemctl enable redis-server
systemctl restart redis-server

# Configure PHP-FPM
echo -e "${YELLOW}→ Configuring PHP-FPM...${NC}"
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/8.3/fpm/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 100M/' /etc/php/8.3/fpm/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 100M/' /etc/php/8.3/fpm/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 512M/' /etc/php/8.3/fpm/php.ini

# Create application directory
APP_DIR="/var/www/church-services"
echo -e "${YELLOW}→ Creating application directory...${NC}"
mkdir -p $APP_DIR
chown -R $ACTUAL_USER:www-data $APP_DIR

# Create Nginx configuration
echo -e "${YELLOW}→ Creating Nginx configuration...${NC}"
cat > /etc/nginx/sites-available/church-services << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME;
    root /var/www/church-services/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    client_max_body_size 100M;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    # WebSocket proxy
    location /ws {
        proxy_pass http://127.0.0.1:6001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/church-services /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Configure Cloudflare settings if enabled
if [ "$ENABLE_CLOUDFLARE" = true ]; then
    echo -e "${YELLOW}→ Configuring for Cloudflare...${NC}"
    # Add Cloudflare real IP settings
    cat > /etc/nginx/conf.d/cloudflare.conf << 'EOF'
# Cloudflare IP ranges
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 104.16.0.0/13;
set_real_ip_from 104.24.0.0/14;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 131.0.72.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2c0f:f248::/32;
set_real_ip_from 2a06:98c0::/29;

real_ip_header CF-Connecting-IP;
EOF
fi

# Test and restart Nginx
nginx -t
systemctl enable nginx
systemctl restart nginx

# Restart PHP-FPM
systemctl enable php8.3-fpm
systemctl restart php8.3-fpm

# Create logs directory
mkdir -p /var/log/church-services
chown -R $ACTUAL_USER:www-data /var/log/church-services

# Configure firewall
if command -v ufw &> /dev/null; then
    echo -e "${YELLOW}→ Configuring firewall...${NC}"
    ufw allow 'Nginx Full'
    ufw allow OpenSSH
    echo "y" | ufw enable || true
fi

# Create supervisor configurations
cat > /etc/supervisor/conf.d/church-services-worker.conf << EOF
[program:church-services-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/church-services/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=$ACTUAL_USER
numprocs=2
redirect_stderr=true
stdout_logfile=/var/log/church-services/worker.log
stopwaitsecs=3600
EOF

cat > /etc/supervisor/conf.d/church-services-websocket.conf << EOF
[program:church-services-websocket]
process_name=%(program_name)s
command=php /var/www/church-services/artisan websockets:serve
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=$ACTUAL_USER
redirect_stderr=true
stdout_logfile=/var/log/church-services/websocket.log
EOF

systemctl enable supervisor

echo -e "${GREEN}✓ Services configured${NC}"

###############################################################################
# Final Instructions
###############################################################################

clear
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              System Installation Complete!                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo ""
echo "1. Run the application setup script:"
echo -e "   ${YELLOW}cd /var/www/church-services${NC}"
echo -e "   ${YELLOW}bash ~/setup-app.sh${NC}"
echo ""
echo "2. Configuration saved to: ${GREEN}$CONFIG_FILE${NC}"
echo ""

if [ "$ENABLE_CLOUDFLARE" = true ]; then
    echo -e "${CYAN}Cloudflare Setup:${NC}"
    echo "1. Log in to Cloudflare dashboard"
    echo "2. Add site: $DOMAIN_NAME"
    echo "3. Create A record: @ -> $SERVER_IP (proxied)"
    echo "4. SSL/TLS mode: Full (strict) recommended"
    echo "5. Enable 'Always Use HTTPS'"
    echo ""
fi

if [ "$USE_LETSENCRYPT" = true ]; then
    echo -e "${CYAN}SSL Setup (Let's Encrypt):${NC}"
    echo "After app setup, run:"
    echo -e "   ${YELLOW}sudo certbot --nginx -d $DOMAIN_NAME${NC}"
    echo ""
fi

echo -e "${YELLOW}Your server IP: $(curl -s ifconfig.me)${NC}"
echo ""
