#!/bin/bash

###############################################################################
# OpenSIPs Web Interface Installation Script
# For servers that already have OpenSIPs and database installed
# This script ONLY installs the web interface (Control Panel)
###############################################################################

set -e

echo "========================================================"
echo "OpenSIPs Control Panel - Web Interface Installation"
echo "========================================================"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root: sudo ./install_web_interface_only.sh${NC}"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${GREEN}Step 1: Checking Prerequisites${NC}"
if ! systemctl is-active --quiet opensips; then
    echo -e "${YELLOW}Warning: OpenSIPs is not running. This script assumes OpenSIPs is already installed.${NC}"
fi

if ! systemctl is-active --quiet mariadb && ! systemctl is-active --quiet mysql; then
    echo -e "${RED}Error: MySQL/MariaDB is not running. Database must be installed first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"

echo -e "${GREEN}Step 2: Installing Apache and PHP${NC}"
apt-get update
apt-get install -y \
    apache2 \
    php \
    php-mysql \
    php-gd \
    php-curl \
    php-xml \
    php-mbstring \
    libapache2-mod-php

echo -e "${GREEN}✓ Apache and PHP installed${NC}"

echo -e "${GREEN}Step 3: Restoring Apache Configuration${NC}"
if [ -f "$SCRIPT_DIR/apache_config.tar.gz" ]; then
    echo "Extracting Apache configuration..."
    cd /
    tar -xzf "$SCRIPT_DIR/apache_config.tar.gz"
    
    # Convert CentOS Apache config paths to Ubuntu/Debian if needed
    if [ -d /etc/httpd ] && [ ! -d /etc/apache2/conf.d ]; then
        echo "Converting CentOS config to Ubuntu/Debian format..."
        mkdir -p /etc/apache2/sites-available
        mkdir -p /etc/apache2/conf-available
    fi
    
    echo -e "${GREEN}✓ Apache configuration restored${NC}"
else
    echo -e "${YELLOW}Warning: apache_config.tar.gz not found, using default Apache config${NC}"
fi

echo -e "${GREEN}Step 4: Restoring Web Interface Files${NC}"
if [ ! -f "$SCRIPT_DIR/web_interface.tar.gz" ]; then
    echo -e "${RED}ERROR: web_interface.tar.gz not found in $SCRIPT_DIR${NC}"
    echo "Please ensure the file is in the same directory as this script"
    exit 1
fi

echo "Extracting web interface files (5.4 MB)..."
cd /
tar -xzf "$SCRIPT_DIR/web_interface.tar.gz"

echo -e "${GREEN}✓ Web interface files extracted${NC}"

echo -e "${GREEN}Step 5: Setting Permissions${NC}"
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Set specific permissions for web writable directories
if [ -d /var/www/html/opensips-cp ]; then
    chmod -R 775 /var/www/html/opensips-cp/config
    find /var/www/html -type f -name "*.php" -exec chmod 644 {} \;
fi

echo -e "${GREEN}✓ Permissions set${NC}"

echo -e "${GREEN}Step 6: Configuring Apache${NC}"

# Enable mod_rewrite if needed
a2enmod rewrite 2>/dev/null || true

# Create a simple Apache config for OpenSIPs CP if default doesn't exist
if [ ! -f /etc/apache2/sites-available/000-default.conf ]; then
    cat > /etc/apache2/sites-available/000-default.conf <<'VHOST'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
VHOST
fi

# Enable the site
a2ensite 000-default 2>/dev/null || true

echo -e "${GREEN}✓ Apache configured${NC}"

echo -e "${GREEN}Step 7: Configuring PHP${NC}"

# Ensure PHP is properly configured
PHP_INI=$(php -i | grep "Loaded Configuration File" | awk '{print $5}')
if [ -n "$PHP_INI" ] && [ -f "$PHP_INI" ]; then
    echo "PHP configuration: $PHP_INI"
    # Increase PHP limits for Control Panel
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 20M/' "$PHP_INI" 2>/dev/null || true
    sed -i 's/post_max_size = .*/post_max_size = 25M/' "$PHP_INI" 2>/dev/null || true
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI" 2>/dev/null || true
fi

echo -e "${GREEN}✓ PHP configured${NC}"

echo -e "${GREEN}Step 8: Updating Control Panel Database Configuration${NC}"

# Update OpenSIPs Control Panel config to match current database
if [ -f /var/www/html/opensips-cp/config/db.inc.php ]; then
    echo "Updating Control Panel database configuration..."
    
    # Backup original config
    cp /var/www/html/opensips-cp/config/db.inc.php /var/www/html/opensips-cp/config/db.inc.php.backup
    
    # Update database password (default from install.sh is 'opensipsrw')
    sed -i "s/\$config->db_pass = .*/\$config->db_pass = 'opensipsrw';/" /var/www/html/opensips-cp/config/db.inc.php 2>/dev/null || true
    
    echo -e "${GREEN}✓ Database configuration updated${NC}"
    echo -e "${YELLOW}Note: If your database password is different, edit: /var/www/html/opensips-cp/config/db.inc.php${NC}"
else
    echo -e "${YELLOW}Warning: Control Panel config not found, may need manual configuration${NC}"
fi

echo -e "${GREEN}Step 9: Starting Apache Web Server${NC}"

# Enable and start Apache
systemctl enable apache2
systemctl restart apache2

sleep 2

# Check if Apache is running
if systemctl is-active --quiet apache2; then
    echo -e "${GREEN}✓ Apache is running successfully!${NC}"
else
    echo -e "${RED}✗ Apache failed to start. Check logs: journalctl -u apache2 -xe${NC}"
    exit 1
fi

echo -e "${GREEN}Step 10: Configuring Firewall${NC}"

# Try to open port 80 (HTTP) in firewall if ufw or firewalld is active
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "Status: active"; then
        echo "Opening port 80 in UFW firewall..."
        ufw allow 80/tcp
        echo -e "${GREEN}✓ Port 80 opened in firewall${NC}"
    fi
elif command -v firewall-cmd >/dev/null 2>&1; then
    if firewall-cmd --state 2>/dev/null | grep -q running; then
        echo "Opening port 80 in firewalld..."
        firewall-cmd --add-service=http --permanent
        firewall-cmd --reload
        echo -e "${GREEN}✓ Port 80 opened in firewall${NC}"
    fi
else
    echo -e "${YELLOW}No firewall detected or already configured${NC}"
fi

echo ""
echo "========================================================"
echo -e "${GREEN}Web Interface Installation Complete!${NC}"
echo "========================================================"
echo ""

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="YOUR_SERVER_IP"
fi

echo -e "${GREEN}🌐 Access your OpenSIPs Control Panel at:${NC}"
echo -e "   ${YELLOW}http://$SERVER_IP/${NC}"
echo ""
echo "Web Interface Locations:"
echo "  • Control Panel: http://$SERVER_IP/opensips-cp/"
echo "  • CP Client: http://$SERVER_IP/opensips-cp-client/"
echo ""
echo "Service Status:"
systemctl status apache2 --no-pager | head -5
echo ""
echo "Useful Commands:"
echo "  • Apache logs: tail -f /var/log/apache2/error.log"
echo "  • Apache status: systemctl status apache2"
echo "  • Restart Apache: systemctl restart apache2"
echo "  • Test config: apache2ctl configtest"
echo ""
echo -e "${YELLOW}Database Configuration:${NC}"
echo "  Default database: opensips"
echo "  Default user: opensips"
echo "  Default password: opensipsrw"
echo ""
echo "  If different, edit: /var/www/html/opensips-cp/config/db.inc.php"
echo ""
echo -e "${GREEN}✅ Your OpenSIPs server now has a complete web interface!${NC}"
echo ""
