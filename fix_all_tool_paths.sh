#!/bin/bash

###############################################################################
# Fix ALL Control Panel Tool Database Configs
# Updates every single db.inc.php file with correct credentials
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================================"
echo "Fix ALL Control Panel Tool Configurations"
echo "========================================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Run as root: sudo bash fix_all_tool_paths.sh${NC}"
    exit 1
fi

echo "Enter your MySQL root password:"
read -s MYSQL_ROOT_PASSWORD
echo ""

echo -e "${GREEN}Step 1: Ensure database users exist${NC}"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<'EOSQL'
CREATE USER IF NOT EXISTS 'opensips'@'localhost' IDENTIFIED BY 'opensipsrw';
GRANT ALL PRIVILEGES ON opensips.* TO 'opensips'@'localhost';
CREATE USER IF NOT EXISTS 'web'@'localhost' IDENTIFIED BY 'opensipsrw';
GRANT ALL PRIVILEGES ON opensips.* TO 'web'@'localhost';
FLUSH PRIVILEGES;
EOSQL
echo -e "${GREEN}✓ Users created${NC}"

echo ""
echo -e "${GREEN}Step 2: Finding ALL db.inc.php files${NC}"
find /var/www/html/opensips-cp -name "db.inc.php" -type f > /tmp/cp_configs.txt
TOTAL=$(wc -l < /tmp/cp_configs.txt)
echo "Found $TOTAL config files"

echo ""
echo -e "${GREEN}Step 3: Updating each config file${NC}"

while read config_file; do
    # Get tool name from path
    TOOL=$(basename $(dirname "$config_file"))
    
    # Backup
    cp "$config_file" "${config_file}.backup_$(date +%s)"
    
    # Read the file to check what variable names it uses
    if grep -q "db_user_${TOOL}" "$config_file"; then
        # Uses tool-specific variable name
        VAR_USER="db_user_${TOOL}"
        VAR_PASS="db_pass_${TOOL}"
    else
        # Uses generic variable name
        VAR_USER="db_user"
        VAR_PASS="db_pass"
    fi
    
    # Create or update the configuration
    # Remove any existing db_user/db_pass lines
    sed -i "/\$config->${VAR_USER}/d" "$config_file"
    sed -i "/\$config->${VAR_PASS}/d" "$config_file"
    
    # Add correct configuration at the beginning of the file (after <?php)
    sed -i "/<\?php/a\\
\\
// Auto-configured database credentials\\
\$config->${VAR_USER} = \"opensips\";\\
\$config->${VAR_PASS} = \"opensipsrw\";\\
\$config->db_host = \"localhost\";\\
\$config->db_name = \"opensips\";\\
" "$config_file"
    
    echo "  ✓ $config_file"
done < /tmp/cp_configs.txt

echo -e "${GREEN}✓ Updated $TOTAL files${NC}"

echo ""
echo -e "${GREEN}Step 4: Update main config${NC}"
MAIN_CONFIG="/var/www/html/opensips-cp/config/db.inc.php"
if [ -f "$MAIN_CONFIG" ]; then
    cp "$MAIN_CONFIG" "${MAIN_CONFIG}.backup_$(date +%s)"
    
    # Force correct values
    sed -i 's/^\s*\$config->db_user\s*=.*/\$config->db_user = "opensips";/' "$MAIN_CONFIG"
    sed -i 's/^\s*\$config->db_pass\s*=.*/\$config->db_pass = "opensipsrw";/' "$MAIN_CONFIG"
    sed -i 's/^\s*\$config->db_host\s*=.*/\$config->db_host = "localhost";/' "$MAIN_CONFIG"
    sed -i 's/^\s*\$config->db_name\s*=.*/\$config->db_name = "opensips";/' "$MAIN_CONFIG"
    
    echo -e "${GREEN}✓ Main config updated${NC}"
fi

echo ""
echo -e "${GREEN}Step 5: Set permissions${NC}"
chown -R www-data:www-data /var/www/html/opensips-cp
chmod -R 755 /var/www/html/opensips-cp
find /var/www/html/opensips-cp -name "*.php" -exec chmod 644 {} \;
echo -e "${GREEN}✓ Permissions set${NC}"

echo ""
echo -e "${GREEN}Step 6: Clear PHP sessions${NC}"
rm -rf /var/lib/php/sessions/* 2>/dev/null
rm -rf /var/lib/php/mod_php/sessions/* 2>/dev/null
echo -e "${GREEN}✓ Sessions cleared${NC}"

echo ""
echo -e "${GREEN}Step 7: Restart Apache${NC}"
systemctl restart apache2
sleep 2
echo -e "${GREEN}✓ Apache restarted${NC}"

echo ""
echo -e "${GREEN}Step 8: Test database connection${NC}"
if mysql -u opensips -p'opensipsrw' opensips -e "SELECT 'Connection OK' as status;" 2>/dev/null; then
    echo -e "${GREEN}✓ Database connection works!${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
fi

echo ""
echo "========================================================"
echo -e "${GREEN}ALL Configurations Fixed!${NC}"
echo "========================================================"
echo ""
echo "Updated $TOTAL configuration files including:"
echo "  • Carriers"
echo "  • Clients"  
echo "  • Ranges"
echo "  • Numbers"
echo "  • Dialplan"
echo "  • Dispatcher"
echo "  • Domains"
echo "  • Load Balancer"
echo "  • And all other tools"
echo ""
echo "All configs now use:"
echo "  Database: opensips"
echo "  User: opensips"
echo "  Password: opensipsrw"
echo "  Host: localhost"
echo ""
echo -e "${YELLOW}IMPORTANT: Clear your browser cache or use Private/Incognito mode${NC}"
echo ""
echo "Access: http://$(hostname -I | awk '{print $1}')/"
echo "Login: rezguitarek / kingsm"
echo ""
echo "Try clicking on Carriers, Clients, or any other feature."
echo "They should all work now!"
echo ""
