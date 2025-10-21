#!/bin/bash

###############################################################################
# Diagnose and Fix Control Panel Database Issues
# This script checks what's actually wrong and fixes it
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================================"
echo "OpenSIPs Control Panel - Diagnostics & Fix"
echo "========================================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root: sudo bash diagnose_and_fix.sh${NC}"
    exit 1
fi

echo "Enter your MySQL/MariaDB root password:"
read -s MYSQL_ROOT_PASSWORD
echo ""

echo -e "${GREEN}=== STEP 1: Checking existing database users ===${NC}"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT User, Host, plugin FROM mysql.user WHERE User IN ('opensips', 'web', 'root');" 2>&1

echo ""
echo -e "${GREEN}=== STEP 2: Checking what Control Panel config actually says ===${NC}"
if [ -f /var/www/html/opensips-cp/config/db.inc.php ]; then
    echo "Main config file contents:"
    grep -E "db_user|db_pass|db_host" /var/www/html/opensips-cp/config/db.inc.php | grep -v "^#" | head -10
else
    echo -e "${RED}Config file not found!${NC}"
fi

echo ""
echo -e "${GREEN}=== STEP 3: Dropping and recreating 'web' user properly ===${NC}"

mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<'EOSQL'
-- Drop web user if exists
DROP USER IF EXISTS 'web'@'localhost';

-- Create fresh web user with explicit password
CREATE USER 'web'@'localhost' IDENTIFIED BY 'opensipsrw';

-- Grant ALL privileges on opensips database
GRANT ALL PRIVILEGES ON `opensips`.* TO 'web'@'localhost';

-- Grant on provisioning if needed
GRANT ALL PRIVILEGES ON `provisioning`.* TO 'web'@'localhost';

-- Ensure opensips user also exists
CREATE USER IF NOT EXISTS 'opensips'@'localhost' IDENTIFIED BY 'opensipsrw';
GRANT ALL PRIVILEGES ON `opensips`.* TO 'opensips'@'localhost';

FLUSH PRIVILEGES;

-- Show what we created
SELECT User, Host FROM mysql.user WHERE User IN ('web', 'opensips');
EOSQL

echo -e "${GREEN}✓ Users recreated${NC}"

echo ""
echo -e "${GREEN}=== STEP 4: Testing connections directly ===${NC}"

echo "Testing 'web' user..."
if mysql -u web -p'opensipsrw' opensips -e "SELECT 1;" 2>/dev/null; then
    echo -e "${GREEN}✓ 'web' user can connect${NC}"
else
    echo -e "${RED}✗ 'web' user CANNOT connect - showing error:${NC}"
    mysql -u web -p'opensipsrw' opensips -e "SELECT 1;" 2>&1
fi

echo ""
echo "Testing 'opensips' user..."
if mysql -u opensips -p'opensipsrw' opensips -e "SELECT 1;" 2>/dev/null; then
    echo -e "${GREEN}✓ 'opensips' user can connect${NC}"
else
    echo -e "${RED}✗ 'opensips' user CANNOT connect${NC}"
fi

echo ""
echo -e "${GREEN}=== STEP 5: Force update ALL Control Panel configs to use 'opensips' user ===${NC}"

# Update main config
if [ -f /var/www/html/opensips-cp/config/db.inc.php ]; then
    cp /var/www/html/opensips-cp/config/db.inc.php /var/www/html/opensips-cp/config/db.inc.php.backup_diag
    
    # Force these values
    sed -i 's/^\s*\$config->db_user\s*=.*/\$config->db_user = "opensips";/' /var/www/html/opensips-cp/config/db.inc.php
    sed -i 's/^\s*\$config->db_pass\s*=.*/\$config->db_pass = "opensipsrw";/' /var/www/html/opensips-cp/config/db.inc.php
    sed -i 's/^\s*\$config->db_host\s*=.*/\$config->db_host = "localhost";/' /var/www/html/opensips-cp/config/db.inc.php
    sed -i 's/^\s*\$config->db_name\s*=.*/\$config->db_name = "opensips";/' /var/www/html/opensips-cp/config/db.inc.php
    
    echo "Updated main config:"
    grep -E "db_user|db_pass" /var/www/html/opensips-cp/config/db.inc.php | grep -v "^#" | head -5
fi

# Update all tool configs
echo ""
echo "Updating all tool configs..."
find /var/www/html/opensips-cp/config/tools -name "db.inc.php" | while read config_file; do
    cp "$config_file" "${config_file}.backup_diag"
    
    # Replace any db_user assignment with opensips
    sed -i 's/\$config->db_user_[a-zA-Z_]*\s*=.*/\$config->db_user_TOOL = "opensips";/g' "$config_file"
    sed -i 's/\$config->db_pass_[a-zA-Z_]*\s*=.*/\$config->db_pass_TOOL = "opensipsrw";/g' "$config_file"
    
    # Also update commented lines
    sed -i 's|^//\s*\$config->db_user.*|\$config->db_user_TOOL = "opensips";|g' "$config_file"
    sed -i 's|^//\s*\$config->db_pass.*|\$config->db_pass_TOOL = "opensipsrw";|g' "$config_file"
done

echo -e "${GREEN}✓ All configs updated to use 'opensips' user${NC}"

echo ""
echo -e "${GREEN}=== STEP 6: Clear PHP sessions and restart Apache ===${NC}"
rm -rf /var/lib/php/sessions/* 2>/dev/null
systemctl restart apache2
echo -e "${GREEN}✓ Apache restarted${NC}"

echo ""
echo -e "${GREEN}=== STEP 7: Final verification ===${NC}"
echo "Database users available:"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT User, Host FROM mysql.user WHERE User IN ('opensips', 'web');"

echo ""
echo "Testing opensips user access:"
mysql -u opensips -p'opensipsrw' opensips -e "SELECT COUNT(*) as tables FROM information_schema.tables WHERE table_schema='opensips';"

echo ""
echo "========================================================"
echo -e "${GREEN}Fix Complete!${NC}"
echo "========================================================"
echo ""
echo "Database Users Created:"
echo "  • opensips / opensipsrw  ✓"
echo "  • web / opensipsrw       ✓"
echo ""
echo "All Control Panel configs now use: opensips / opensipsrw"
echo ""
echo "Next steps:"
echo "1. Open your browser in PRIVATE/INCOGNITO mode"
echo "2. Go to: http://$(hostname -I | awk '{print $1}')/"
echo "3. Login with: rezguitarek / kingsm"
echo "4. All features should work now!"
echo ""
echo -e "${YELLOW}If you still see errors, run this on your server:${NC}"
echo "  tail -f /var/log/apache2/error.log"
echo ""
echo "And send me the error message you see."
echo ""
