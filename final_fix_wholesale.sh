#!/bin/bash

###############################################################################
# Final Fix - Point Wholesale Tools to General Database
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================================"
echo "Final Fix - Wholesale Tools → General Database"
echo "========================================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Run as root: sudo bash final_fix_wholesale.sh${NC}"
    exit 1
fi

echo -e "${GREEN}Step 1: Backup and update wholesale tool configs${NC}"

# List of wholesale tools
WHOLESALE_TOOLS="carriers clients numbers ranges codes ivrs tviewer"

for tool in $WHOLESALE_TOOLS; do
    CONFIG_FILE="/var/www/html/opensips-cp/config/tools/wholesale/${tool}/db.inc.php"
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "  Fixing: $tool"
        
        # Backup
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup_final"
        
        # Completely rewrite the config to use General database
        cat > "$CONFIG_FILE" <<'PHPCODE'
<?php
/*
 * Database configuration - Updated for General database
 */

$module_id = "MODULENAME";

// Configuration for all submenu items
for ($i = 0; $i <= 10; $i++) {
    $custom_config[$module_id][$i]['db_driver'] = "mysql";
    $custom_config[$module_id][$i]['db_host'] = "localhost";
    $custom_config[$module_id][$i]['db_user'] = "opensips";
    $custom_config[$module_id][$i]['db_name'] = "General";
    $custom_config[$module_id][$i]['db_pass'] = "opensipsrw";
    $custom_config[$module_id][$i]['db_port'] = "";
}

?>
PHPCODE
        
        # Replace MODULENAME with actual tool name
        sed -i "s/MODULENAME/${tool}/g" "$CONFIG_FILE"
        
        echo "    ✓ Updated to use General database"
    else
        echo "    ⚠ Not found: $tool"
    fi
done

echo -e "${GREEN}✓ All wholesale configs updated${NC}"

echo ""
echo -e "${GREEN}Step 2: Verify database access${NC}"
mysql -u opensips -p'opensipsrw' General -e "
SELECT 
    'carriers' as table_name, COUNT(*) as count FROM carriers UNION ALL
    SELECT 'clients', COUNT(*) FROM clients UNION ALL
    SELECT 'numbers', COUNT(*) FROM numbers UNION ALL
    SELECT 'ranges', COUNT(*) FROM ranges;
" 2>/dev/null

echo ""
echo -e "${GREEN}Step 3: Set correct permissions${NC}"
chown -R www-data:www-data /var/www/html/opensips-cp/config
chmod -R 755 /var/www/html/opensips-cp/config
find /var/www/html/opensips-cp/config -name "*.php" -exec chmod 644 {} \;
echo -e "${GREEN}✓ Permissions set${NC}"

echo ""
echo -e "${GREEN}Step 4: Clear all PHP sessions${NC}"
rm -rf /var/lib/php/sessions/* 2>/dev/null
rm -rf /var/lib/php/mod_php/sessions/* 2>/dev/null
rm -rf /tmp/sess_* 2>/dev/null
echo -e "${GREEN}✓ Sessions cleared${NC}"

echo ""
echo -e "${GREEN}Step 5: Restart Apache${NC}"
systemctl restart apache2
sleep 3
systemctl status apache2 --no-pager | head -3
echo -e "${GREEN}✓ Apache restarted${NC}"

echo ""
echo -e "${GREEN}Step 6: Show sample data${NC}"
echo "Sample carriers:"
mysql -u opensips -p'opensipsrw' General -e "SELECT * FROM carriers LIMIT 2;" 2>/dev/null

echo ""
echo "Sample clients:"
mysql -u opensips -p'opensipsrw' General -e "SELECT * FROM clients LIMIT 2;" 2>/dev/null

echo ""
echo "========================================================"
echo -e "${GREEN}Fix Complete!${NC}"
echo "========================================================"
echo ""
echo "All wholesale tools now configured to use:"
echo "  Database: General"
echo "  User: opensips"
echo "  Password: opensipsrw"
echo ""
echo "Tools updated: carriers, clients, numbers, ranges, codes, ivrs"
echo ""
echo -e "${YELLOW}CRITICAL STEPS:${NC}"
echo "1. Close ALL browser windows completely"
echo "2. Open a NEW Private/Incognito window"
echo "3. Go to: http://$(hostname -I | awk '{print $1}')/"
echo "4. Login: rezguitarek / kingsm"
echo "5. Click 'Carriers' - should show 4 carriers"
echo "6. Click 'Clients' - should show 5 clients"
echo ""
echo "If still empty, run this and send output:"
echo "  tail -50 /var/log/apache2/error.log"
echo ""
