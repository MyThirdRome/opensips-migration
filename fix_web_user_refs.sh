#!/bin/bash

###############################################################################
# Fix ALL 'web' user references - Replace with 'opensips'
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================================"
echo "Fix ALL 'web' User References"
echo "========================================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Run as root: sudo bash fix_web_user_refs.sh${NC}"
    exit 1
fi

echo -e "${GREEN}Step 1: Find all configs with 'web' user${NC}"
WEB_CONFIGS=$(grep -r "db_user.*web" /var/www/html/opensips-cp/config/ 2>/dev/null | grep "\.php:" | cut -d: -f1 | sort -u)

if [ -z "$WEB_CONFIGS" ]; then
    echo "  No 'web' user references found"
else
    echo "$WEB_CONFIGS" | wc -l | xargs echo "  Found files with 'web' user:"
    echo "$WEB_CONFIGS"
fi

echo ""
echo -e "${GREEN}Step 2: Replace 'web' with 'opensips' in all config files${NC}"

find /var/www/html/opensips-cp/config -name "*.php" -type f | while read config_file; do
    if grep -q "db_user.*web" "$config_file" 2>/dev/null; then
        cp "$config_file" "${config_file}.backup_webfix"
        
        # Replace all variations of web user
        sed -i "s/\['db_user'\].*=.*'web'/['db_user'] = 'opensips'/g" "$config_file"
        sed -i 's/\["db_user"\].*=.*"web"/["db_user"] = "opensips"/g' "$config_file"
        sed -i "s/\\\$config->db_user.*=.*'web'/\\\$config->db_user = 'opensips'/g" "$config_file"
        sed -i 's/\$config->db_user.*=.*"web"/\$config->db_user = "opensips"/g' "$config_file"
        sed -i "s/'db_user'\s*=>\s*'web'/'db_user' => 'opensips'/g" "$config_file"
        sed -i 's/"db_user"\s*=>\s*"web"/"db_user" => "opensips"/g' "$config_file"
        
        # Also fix any hardcoded passwords
        sed -i "s/webpassword123/opensipsrw/g" "$config_file"
        
        echo "  ✓ Fixed: $config_file"
    fi
done

echo ""
echo -e "${GREEN}Step 3: Ensure 'web' user exists with correct permissions${NC}"
echo "Enter MySQL root password:"
read -s MYSQL_ROOT_PASSWORD
echo ""

mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<'EOSQL'
-- Drop and recreate web user
DROP USER IF EXISTS 'web'@'localhost';
CREATE USER 'web'@'localhost' IDENTIFIED BY 'opensipsrw';

-- Grant permissions on both databases
GRANT ALL PRIVILEGES ON opensips.* TO 'web'@'localhost';
GRANT ALL PRIVILEGES ON General.* TO 'web'@'localhost';

-- Ensure opensips user also has full access
GRANT ALL PRIVILEGES ON opensips.* TO 'opensips'@'localhost';
GRANT ALL PRIVILEGES ON General.* TO 'opensips'@'localhost';

FLUSH PRIVILEGES;

-- Show users
SELECT User, Host FROM mysql.user WHERE User IN ('web', 'opensips');
EOSQL

echo -e "${GREEN}✓ Database users configured${NC}"

echo ""
echo -e "${GREEN}Step 4: Test connections${NC}"
echo "Testing 'opensips' user:"
if mysql -u opensips -p'opensipsrw' opensips -e "SELECT 1;" 2>/dev/null; then
    echo "  ✓ opensips user can connect"
else
    echo "  ✗ opensips user CANNOT connect"
fi

echo "Testing 'web' user:"
if mysql -u web -p'opensipsrw' opensips -e "SELECT 1;" 2>/dev/null; then
    echo "  ✓ web user can connect"
else
    echo "  ✗ web user CANNOT connect"
fi

echo ""
echo -e "${GREEN}Step 5: Verify no 'web' references remain${NC}"
REMAINING=$(grep -r "db_user.*['\"]web['\"]" /var/www/html/opensips-cp/config/ 2>/dev/null | wc -l)
if [ "$REMAINING" -eq 0 ]; then
    echo "  ✓ All 'web' user references fixed!"
else
    echo "  ⚠ Still found $REMAINING references:"
    grep -r "db_user.*['\"]web['\"]" /var/www/html/opensips-cp/config/ 2>/dev/null | head -5
fi

echo ""
echo -e "${GREEN}Step 6: Clear sessions and restart${NC}"
rm -rf /var/lib/php/sessions/* 2>/dev/null
rm -rf /tmp/sess_* 2>/dev/null
systemctl restart apache2
sleep 2
echo -e "${GREEN}✓ Apache restarted${NC}"

echo ""
echo "========================================================"
echo -e "${GREEN}Fix Complete!${NC}"
echo "========================================================"
echo ""
echo "Changes made:"
echo "  • Replaced all 'web' user with 'opensips' in configs"
echo "  • Ensured 'web' user exists with correct password"
echo "  • Both users can access opensips and General databases"
echo ""
echo -e "${YELLOW}Test in fresh browser (Private/Incognito):${NC}"
echo "  http://$(hostname -I | awk '{print $1}')/"
echo ""
echo "If errors persist, send output of:"
echo "  tail -30 /var/log/apache2/error.log"
echo ""
