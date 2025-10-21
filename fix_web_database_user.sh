#!/bin/bash

###############################################################################
# Fix OpenSIPs Control Panel Database Access
# Creates the 'web' database user that the Control Panel expects
###############################################################################

set -e

echo "========================================================"
echo "OpenSIPs Control Panel - Database User Fix"
echo "========================================================"
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root: sudo bash fix_web_database_user.sh${NC}"
    exit 1
fi

echo -e "${GREEN}This script will create the 'web' database user for Control Panel${NC}"
echo ""
echo "Please enter your MySQL root password:"
read -s MYSQL_ROOT_PASSWORD
echo ""

echo -e "${GREEN}Step 1: Creating 'web' database user...${NC}"

# Create web user with full privileges on opensips database
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
-- Create web user if it doesn't exist
CREATE USER IF NOT EXISTS 'web'@'localhost' IDENTIFIED BY 'opensipsrw';

-- Grant all privileges on opensips database
GRANT ALL PRIVILEGES ON opensips.* TO 'web'@'localhost';

-- Also grant on provisioning database if it exists
GRANT ALL PRIVILEGES ON provisioning.* TO 'web'@'localhost';

-- Flush privileges
FLUSH PRIVILEGES;

-- Show created user
SELECT User, Host FROM mysql.user WHERE User='web';
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database user 'web' created successfully${NC}"
else
    echo -e "${RED}✗ Failed to create user. Check your MySQL root password.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Step 2: Updating Control Panel configuration...${NC}"

# Update Control Panel config files to use 'web' user
if [ -f /var/www/html/opensips-cp/config/db.inc.php ]; then
    # Backup original
    cp /var/www/html/opensips-cp/config/db.inc.php /var/www/html/opensips-cp/config/db.inc.php.backup2
    
    # Update to use 'web' user
    sed -i "s/\$config->db_user = .*/\$config->db_user = 'web';/" /var/www/html/opensips-cp/config/db.inc.php 2>/dev/null || true
    sed -i "s/\$config->db_pass = .*/\$config->db_pass = 'opensipsrw';/" /var/www/html/opensips-cp/config/db.inc.php 2>/dev/null || true
    
    echo -e "${GREEN}✓ Control Panel config updated${NC}"
else
    echo -e "${YELLOW}Warning: Control Panel config not found${NC}"
fi

# Also update client config if it exists
if [ -f /var/www/html/opensips-cp-client/config/db.inc.php ]; then
    cp /var/www/html/opensips-cp-client/config/db.inc.php /var/www/html/opensips-cp-client/config/db.inc.php.backup2
    
    sed -i "s/\$config->db_user = .*/\$config->db_user = 'web';/" /var/www/html/opensips-cp-client/config/db.inc.php 2>/dev/null || true
    sed -i "s/\$config->db_pass = .*/\$config->db_pass = 'opensipsrw';/" /var/www/html/opensips-cp-client/config/db.inc.php 2>/dev/null || true
    
    echo -e "${GREEN}✓ CP Client config updated${NC}"
fi

echo ""
echo -e "${GREEN}Step 3: Testing database connection...${NC}"

# Test the connection
mysql -u web -p'opensipsrw' opensips -e "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='opensips';" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database connection successful!${NC}"
else
    echo -e "${RED}✗ Connection test failed${NC}"
    exit 1
fi

echo ""
echo "========================================================"
echo -e "${GREEN}Database User Fix Complete!${NC}"
echo "========================================================"
echo ""
echo "Database credentials for Control Panel:"
echo "  User: web"
echo "  Password: opensipsrw"
echo "  Database: opensips"
echo ""
echo -e "${GREEN}✅ Your Control Panel should now work fully!${NC}"
echo ""
echo "Please refresh your browser and try again:"
echo "  http://$(hostname -I | awk '{print $1}')/"
echo ""
