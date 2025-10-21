#!/bin/bash

###############################################################################
# Comprehensive Control Panel Fix - All Tools, All Databases
# Maps each tool to correct database and validates configuration
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================================"
echo "Comprehensive OpenSIPs Control Panel Fix"
echo "========================================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Run as root: sudo bash fix_all_control_panel.sh${NC}"
    exit 1
fi

CP_CONFIG="/var/www/html/opensips-cp/config"

if [ ! -d "$CP_CONFIG" ]; then
    echo -e "${RED}Control Panel config not found: $CP_CONFIG${NC}"
    exit 1
fi

echo -e "${BLUE}=== Database Mapping ===${NC}"
echo "Wholesale tools → General database"
echo "System/Admin/Users/Reports → opensips database"
echo ""

# Function to update tool config
update_tool_config() {
    local tool_path=$1
    local db_name=$2
    local module_name=$(basename "$tool_path")
    
    if [ -f "$tool_path/db.inc.php" ]; then
        # Backup
        cp "$tool_path/db.inc.php" "$tool_path/db.inc.php.backup_$(date +%s)"
        
        # Create new config
        cat > "$tool_path/db.inc.php" <<PHPCODE
<?php
/*
 * Database configuration for $module_name
 * Auto-configured for $db_name database
 */

\$module_id = "$module_name";

// Configuration for all submenu items (0-20 to cover all cases)
for (\$i = 0; \$i <= 20; \$i++) {
    \$custom_config[\$module_id][\$i]['db_driver'] = "mysql";
    \$custom_config[\$module_id][\$i]['db_host'] = "localhost";
    \$custom_config[\$module_id][\$i]['db_user'] = "opensips";
    \$custom_config[\$module_id][\$i]['db_name'] = "$db_name";
    \$custom_config[\$module_id][\$i]['db_pass'] = "opensipsrw";
    \$custom_config[\$module_id][\$i]['db_port'] = "";
}

?>
PHPCODE
        echo "  ✓ $module_name → $db_name"
        return 0
    fi
    return 1
}

echo -e "${GREEN}Step 1: Configure Wholesale Tools (General database)${NC}"
WHOLESALE_TOOLS="carriers clients numbers ranges codes ivrs ivrs_old tviewer"
for tool in $WHOLESALE_TOOLS; do
    update_tool_config "$CP_CONFIG/tools/wholesale/$tool" "General"
done

echo ""
echo -e "${GREEN}Step 2: Configure System Tools (opensips database)${NC}"
SYSTEM_TOOLS="dialplan dispatcher domains drouting loadbalancer permissions rtpproxy rtpengine siptrace callcenter cdrviewer missedcalls smonitor smpp clusterer tls_mgm uac_registrant tviewer"
for tool in $SYSTEM_TOOLS; do
    update_tool_config "$CP_CONFIG/tools/system/$tool" "opensips"
done

echo ""
echo -e "${GREEN}Step 3: Configure Admin Tools (opensips database)${NC}"
if [ -d "$CP_CONFIG/tools/admin" ]; then
    find "$CP_CONFIG/tools/admin" -mindepth 1 -maxdepth 1 -type d | while read tool_path; do
        update_tool_config "$tool_path" "opensips"
    done
fi

echo ""
echo -e "${GREEN}Step 4: Configure User Tools (opensips database)${NC}"
if [ -d "$CP_CONFIG/tools/users" ]; then
    find "$CP_CONFIG/tools/users" -mindepth 1 -maxdepth 1 -type d | while read tool_path; do
        update_tool_config "$tool_path" "opensips"
    done
fi

echo ""
echo -e "${GREEN}Step 5: Configure Report Tools (opensips database)${NC}"
if [ -d "$CP_CONFIG/tools/reports" ]; then
    find "$CP_CONFIG/tools/reports" -mindepth 1 -maxdepth 1 -type d | while read tool_path; do
        update_tool_config "$tool_path" "opensips"
    done
fi

echo ""
echo -e "${GREEN}Step 6: Update main database config${NC}"
MAIN_CONFIG="$CP_CONFIG/db.inc.php"
if [ -f "$MAIN_CONFIG" ]; then
    cp "$MAIN_CONFIG" "${MAIN_CONFIG}.backup_$(date +%s)"
    
    sed -i 's/\$config->db_driver\s*=.*/\$config->db_driver = "mysql";/' "$MAIN_CONFIG"
    sed -i 's/\$config->db_host\s*=.*/\$config->db_host = "localhost";/' "$MAIN_CONFIG"
    sed -i 's/\$config->db_port\s*=.*/\$config->db_port = "";/' "$MAIN_CONFIG"
    sed -i 's/\$config->db_user\s*=.*/\$config->db_user = "opensips";/' "$MAIN_CONFIG"
    sed -i 's/\$config->db_pass\s*=.*/\$config->db_pass = "opensipsrw";/' "$MAIN_CONFIG"
    sed -i 's/\$config->db_name\s*=.*/\$config->db_name = "opensips";/' "$MAIN_CONFIG"
    
    echo "  ✓ Main config updated (default: opensips)"
fi

echo ""
echo -e "${GREEN}Step 7: Validate database tables${NC}"
echo ""
echo "General database tables:"
mysql -u opensips -p'opensipsrw' General -e "SHOW TABLES;" 2>/dev/null | tail -n +2 | wc -l | xargs echo "  Tables:"

echo ""
echo "opensips database tables:"
mysql -u opensips -p'opensipsrw' opensips -e "SHOW TABLES;" 2>/dev/null | tail -n +2 | wc -l | xargs echo "  Tables:"

echo ""
echo "Data counts in General:"
mysql -u opensips -p'opensipsrw' General -e "
SELECT 'carriers' as item, COUNT(*) as count FROM carriers UNION ALL
SELECT 'clients', COUNT(*) FROM clients UNION ALL
SELECT 'numbers', COUNT(*) FROM numbers UNION ALL
SELECT 'ranges', COUNT(*) FROM ranges UNION ALL
SELECT 'ivrs', COUNT(*) FROM ivrs;
" 2>/dev/null

echo ""
echo -e "${GREEN}Step 8: Set permissions${NC}"
chown -R www-data:www-data /var/www/html/opensips-cp
chmod -R 755 /var/www/html/opensips-cp
find /var/www/html/opensips-cp -name "*.php" -exec chmod 644 {} \;
echo "  ✓ Permissions set"

echo ""
echo -e "${GREEN}Step 9: Clear all caches${NC}"
rm -rf /var/lib/php/sessions/* 2>/dev/null
rm -rf /var/lib/php/mod_php/sessions/* 2>/dev/null
rm -rf /tmp/sess_* 2>/dev/null
echo "  ✓ PHP sessions cleared"

echo ""
echo -e "${GREEN}Step 10: Restart Apache${NC}"
systemctl restart apache2
sleep 3
if systemctl is-active --quiet apache2; then
    echo "  ✓ Apache running"
else
    echo "  ✗ Apache failed to start"
    systemctl status apache2 --no-pager | head -10
fi

echo ""
echo "========================================================"
echo -e "${GREEN}Configuration Complete!${NC}"
echo "========================================================"
echo ""
echo "Database assignments:"
echo "  • Wholesale (carriers, clients, numbers, etc.) → General"
echo "  • System tools (dialplan, dispatcher, etc.) → opensips"
echo "  • Admin/Users/Reports → opensips"
echo ""
echo -e "${YELLOW}CRITICAL: Test in fresh browser session${NC}"
echo ""
echo "1. Close ALL browser windows"
echo "2. Open Private/Incognito window"
echo "3. Go to: http://$(hostname -I | awk '{print $1}')/"
echo "4. Login: rezguitarek / kingsm"
echo ""
echo "Test each section:"
echo "  ✓ Carriers (should show 4)"
echo "  ✓ Clients (should show 5)"
echo "  ✓ Numbers"
echo "  ✓ Ranges"
echo "  ✓ IVRs"
echo "  ✓ System tools (dialplan, dispatcher, etc.)"
echo ""
echo "If any section shows errors, run:"
echo "  tail -50 /var/log/apache2/error.log | grep -i error"
echo ""
echo "And send me the output."
echo ""
