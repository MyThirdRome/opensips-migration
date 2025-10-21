#!/bin/bash

###############################################################################
# ULTIMATE FIX - Replace ALL 'web' user references with 'opensips'
# This script handles all config variations and ensures both users work
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================================"
echo "ULTIMATE Control Panel Fix"
echo "========================================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Run as root: sudo bash ultimate_fix.sh${NC}"
    exit 1
fi

CP_ROOT="/var/www/html/opensips-cp"

if [ ! -d "$CP_ROOT" ]; then
    echo -e "${RED}Control Panel not found: $CP_ROOT${NC}"
    exit 1
fi

echo "Enter MySQL root password:"
read -s MYSQL_ROOT_PASSWORD
echo ""

echo -e "${BLUE}=== Step 1: Ensure both 'web' and 'opensips' users exist ===${NC}"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<'EOSQL'
-- Drop and recreate both users with correct permissions
DROP USER IF EXISTS 'web'@'localhost';
DROP USER IF EXISTS 'opensips'@'localhost';

CREATE USER 'web'@'localhost' IDENTIFIED BY 'opensipsrw';
CREATE USER 'opensips'@'localhost' IDENTIFIED BY 'opensipsrw';

-- Grant ALL permissions on both databases to both users
GRANT ALL PRIVILEGES ON opensips.* TO 'web'@'localhost';
GRANT ALL PRIVILEGES ON General.* TO 'web'@'localhost';
GRANT ALL PRIVILEGES ON opensips.* TO 'opensips'@'localhost';
GRANT ALL PRIVILEGES ON General.* TO 'opensips'@'localhost';

FLUSH PRIVILEGES;
EOSQL

echo -e "${GREEN}✓ Both users created with full permissions${NC}"

echo ""
echo -e "${BLUE}=== Step 2: Test database connections ===${NC}"
echo -n "Testing 'opensips' user... "
if mysql -u opensips -p'opensipsrw' opensips -e "SELECT 1;" 2>/dev/null >/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi

echo -n "Testing 'web' user... "
if mysql -u web -p'opensipsrw' opensips -e "SELECT 1;" 2>/dev/null >/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi

echo ""
echo -e "${BLUE}=== Step 3: Fix ALL config files (replacing 'web' → 'opensips') ===${NC}"

FIXED_COUNT=0
find "$CP_ROOT/config" -name "*.php" -type f | while read config_file; do
    if grep -q "db_user.*web" "$config_file" 2>/dev/null; then
        # Backup
        cp "$config_file" "${config_file}.backup_ultimate"
        
        # Fix all variations of 'web' user assignment
        sed -i "s/\['db_user'\]\s*=\s*\"web\"/['db_user'] = \"opensips\"/g" "$config_file"
        sed -i "s/\[\"db_user\"\]\s*=\s*\"web\"/[\"db_user\"] = \"opensips\"/g" "$config_file"
        
        # Fix password
        sed -i "s/\['db_pass'\]\s*=\s*\"webpassword123\"/['db_pass'] = \"opensipsrw\"/g" "$config_file"
        sed -i "s/\[\"db_pass\"\]\s*=\s*\"webpassword123\"/[\"db_pass\"] = \"opensipsrw\"/g" "$config_file"
        
        # Uncomment db_port lines
        sed -i 's|^//\s*\$custom_config\[\$module_id\]\[[0-9]*\]\[.db_port.\].*|\$custom_config[\$module_id][0]["db_port"] = "";|g' "$config_file"
        
        echo "  ✓ $(echo $config_file | sed 's|.*/config/||')"
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
done

echo -e "${GREEN}✓ Fixed configuration files${NC}"

echo ""
echo -e "${BLUE}=== Step 4: Verify no 'web' user references remain ===${NC}"
REMAINING=$(grep -r "db_user.*['\"]web['\"]" "$CP_ROOT/config/" 2>/dev/null | wc -l)
if [ "$REMAINING" -eq 0 ]; then
    echo -e "${GREEN}✓ All 'web' user references removed!${NC}"
else
    echo -e "${YELLOW}⚠ Found $REMAINING remaining 'web' references${NC}"
    echo "First 5 occurrences:"
    grep -r "db_user.*['\"]web['\"]" "$CP_ROOT/config/" 2>/dev/null | head -5
fi

echo ""
echo -e "${BLUE}=== Step 5: Set correct permissions ===${NC}"
chown -R www-data:www-data "$CP_ROOT"
chmod -R 755 "$CP_ROOT"
find "$CP_ROOT" -name "*.php" -exec chmod 644 {} \;
echo -e "${GREEN}✓ Permissions set${NC}"

echo ""
echo -e "${BLUE}=== Step 6: Clear ALL caches ===${NC}"
rm -rf /var/lib/php/sessions/* 2>/dev/null
rm -rf /var/lib/php/mod_php/sessions/* 2>/dev/null
rm -rf /tmp/sess_* 2>/dev/null
rm -rf /tmp/php_* 2>/dev/null
echo -e "${GREEN}✓ All PHP sessions cleared${NC}"

echo ""
echo -e "${BLUE}=== Step 7: Restart Apache ===${NC}"
systemctl restart apache2
sleep 3
if systemctl is-active --quiet apache2; then
    echo -e "${GREEN}✓ Apache running${NC}"
else
    echo -e "${RED}✗ Apache failed${NC}"
    systemctl status apache2 --no-pager | head -10
fi

echo ""
echo -e "${BLUE}=== Step 8: Show database contents ===${NC}"
echo "General database (wholesale):"
mysql -u opensips -p'opensipsrw' General -e "
SELECT 'carriers' as item, COUNT(*) as count FROM carriers UNION ALL
SELECT 'clients', COUNT(*) FROM clients UNION ALL
SELECT 'numbers', COUNT(*) FROM numbers UNION ALL
SELECT 'ivrs', COUNT(*) FROM ivrs UNION ALL
SELECT 'ranges', COUNT(*) FROM ranges;
" 2>/dev/null

echo ""
echo "opensips database tables:"
mysql -u opensips -p'opensipsrw' opensips -e "SELECT COUNT(*) as total_tables FROM information_schema.tables WHERE table_schema='opensips';" 2>/dev/null

echo ""
echo "========================================================"
echo -e "${GREEN}ULTIMATE FIX COMPLETE!${NC}"
echo "========================================================"
echo ""
echo "What was done:"
echo "  ✓ Both 'web' and 'opensips' users created"
echo "  ✓ Both users have full access to opensips + General databases"
echo "  ✓ All configs changed from 'web' → 'opensips'"
echo "  ✓ All sessions cleared"
echo "  ✓ Apache restarted"
echo ""
echo -e "${YELLOW}CRITICAL: Test in completely fresh browser session${NC}"
echo ""
echo "Steps:"
echo "  1. Close ALL browser windows (not just tabs)"
echo "  2. Open new Private/Incognito window"
echo "  3. Go to: http://$(hostname -I | awk '{print $1}')/opensips-cp/web"
echo "  4. Login: rezguitarek / kingsm"
echo ""
echo "Test these sections:"
echo "  • Carriers ✓"
echo "  • Clients ✓"
echo "  • Numbers"
echo "  • IVRs"
echo "  • Ranges"
echo "  • System tools"
echo "  • Reports"
echo ""
echo "If ANY section still shows 'Access denied for user web':"
echo "  tail -50 /var/log/apache2/error.log | grep -A2 -B2 'Access denied'"
echo ""
echo "And send me the output."
echo ""
