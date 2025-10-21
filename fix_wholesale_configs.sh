#!/bin/bash

###############################################################################
# Fix Wholesale Tool Configs - Replace "General" database with "opensips"
# Updates all config files that reference the old "General" database
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================================"
echo "Fix Control Panel Wholesale Tool Configs"
echo "========================================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Run as root: sudo bash fix_wholesale_configs.sh${NC}"
    exit 1
fi

echo -e "${GREEN}Step 1: Finding all tool config files with 'General' database${NC}"
CONFIG_DIR="/var/www/html/opensips-cp/config/tools"

if [ ! -d "$CONFIG_DIR" ]; then
    echo -e "${RED}Config directory not found: $CONFIG_DIR${NC}"
    exit 1
fi

# Find all db.inc.php files
find "$CONFIG_DIR" -name "db.inc.php" -type f > /tmp/tool_configs.txt
TOTAL=$(wc -l < /tmp/tool_configs.txt)
echo "Found $TOTAL config files"

echo ""
echo -e "${GREEN}Step 2: Replacing old database settings in each file${NC}"

FIXED=0
while read config_file; do
    # Check if file contains "General" database
    if grep -q "db_name.*General" "$config_file"; then
        echo "  Fixing: $config_file"
        
        # Backup
        cp "$config_file" "${config_file}.backup_$(date +%s)"
        
        # Replace database name "General" with "opensips"
        sed -i "s/'db_name'.*'General'/'db_name'] = \"opensips\"/g" "$config_file"
        sed -i 's/\["db_name"\].*"General"/["db_name"] = "opensips"/g' "$config_file"
        
        # Replace user "web" with "opensips"
        sed -i "s/'db_user'.*'web'/'db_user'] = \"opensips\"/g" "$config_file"
        sed -i 's/\["db_user"\].*"web"/["db_user"] = "opensips"/g' "$config_file"
        
        # Replace password "webpassword123" with "opensipsrw"
        sed -i "s/'db_pass'.*'webpassword123'/'db_pass'] = \"opensipsrw\"/g" "$config_file"
        sed -i 's/\["db_pass"\].*"webpassword123"/["db_pass"] = "opensipsrw"/g' "$config_file"
        
        # Uncomment and set db_port
        sed -i 's|^//\s*\$custom_config\[\$module_id\]\[[0-9]*\]\[.db_port.\].*|$custom_config[$module_id][0]["db_port"] = "";|g' "$config_file"
        
        # Also handle any other variations
        sed -i 's/db_name.*=.*"General"/db_name"] = "opensips"/g' "$config_file"
        sed -i 's/db_user.*=.*"web"/db_user"] = "opensips"/g' "$config_file"
        
        FIXED=$((FIXED + 1))
    fi
done < /tmp/tool_configs.txt

echo -e "${GREEN}✓ Fixed $FIXED config files${NC}"

echo ""
echo -e "${GREEN}Step 3: Update main config file${NC}"
MAIN_CONFIG="/var/www/html/opensips-cp/config/db.inc.php"
if [ -f "$MAIN_CONFIG" ]; then
    cp "$MAIN_CONFIG" "${MAIN_CONFIG}.backup_$(date +%s)"
    
    # Ensure main config uses opensips
    sed -i 's/\$config->db_user\s*=.*/\$config->db_user = "opensips";/' "$MAIN_CONFIG"
    sed -i 's/\$config->db_pass\s*=.*/\$config->db_pass = "opensipsrw";/' "$MAIN_CONFIG"
    sed -i 's/\$config->db_name\s*=.*/\$config->db_name = "opensips";/' "$MAIN_CONFIG"
    sed -i 's/\$config->db_host\s*=.*/\$config->db_host = "localhost";/' "$MAIN_CONFIG"
    sed -i 's/\$config->db_port\s*=.*/\$config->db_port = "";/' "$MAIN_CONFIG"
    
    echo -e "${GREEN}✓ Main config updated${NC}"
fi

echo ""
echo -e "${GREEN}Step 4: Verify changes${NC}"
echo "Checking for any remaining 'General' references:"
REMAINING=$(grep -r "db_name.*General" "$CONFIG_DIR" 2>/dev/null | wc -l)
if [ "$REMAINING" -eq 0 ]; then
    echo -e "${GREEN}✓ All 'General' references removed!${NC}"
else
    echo -e "${YELLOW}⚠ Found $REMAINING remaining 'General' references${NC}"
    grep -r "db_name.*General" "$CONFIG_DIR" 2>/dev/null | head -5
fi

echo ""
echo -e "${GREEN}Step 5: Set permissions${NC}"
chown -R www-data:www-data /var/www/html/opensips-cp
chmod -R 755 /var/www/html/opensips-cp
echo -e "${GREEN}✓ Permissions set${NC}"

echo ""
echo -e "${GREEN}Step 6: Clear PHP sessions and restart Apache${NC}"
rm -rf /var/lib/php/sessions/* 2>/dev/null
rm -rf /var/lib/php/mod_php/sessions/* 2>/dev/null
systemctl restart apache2
sleep 2
echo -e "${GREEN}✓ Apache restarted${NC}"

echo ""
echo -e "${GREEN}Step 7: Test database connection${NC}"
if mysql -u opensips -p'opensipsrw' opensips -e "SELECT 'Connection OK' as status;" 2>/dev/null; then
    echo -e "${GREEN}✓ Database connection works!${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    echo "Checking if database exists:"
    mysql -u root -e "SHOW DATABASES LIKE 'opensips';"
fi

echo ""
echo "========================================================"
echo -e "${GREEN}Fix Complete!${NC}"
echo "========================================================"
echo ""
echo "Changes made:"
echo "  • Database name: General → opensips"
echo "  • Database user: web → opensips"
echo "  • Database password: webpassword123 → opensipsrw"
echo "  • Fixed db_port configuration"
echo ""
echo "Files updated: $FIXED config files"
echo ""
echo -e "${YELLOW}CRITICAL: Clear your browser completely!${NC}"
echo "  1. Close ALL browser windows"
echo "  2. Open in PRIVATE/INCOGNITO mode"
echo "  3. Go to: http://$(hostname -I | awk '{print $1}')/"
echo "  4. Login: rezguitarek / kingsm"
echo "  5. Test: Carriers, Clients, Ranges, Numbers"
echo ""
echo "Everything should work now! ✅"
echo ""
