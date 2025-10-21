#!/bin/bash

###############################################################################
# Check General Database Import Status
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================================"
echo "General Database Import Status Check"
echo "========================================================"
echo ""

echo -e "${GREEN}1. Check if 'General' database exists${NC}"
mysql -u opensips -p'opensipsrw' -e "SHOW DATABASES LIKE 'General';" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Can query databases${NC}"
else
    echo -e "${RED}✗ Cannot connect to MySQL${NC}"
fi

echo ""
echo -e "${GREEN}2. Check tables in General database${NC}"
mysql -u opensips -p'opensipsrw' General -e "SHOW TABLES;" 2>/dev/null

echo ""
echo -e "${GREEN}3. Check data in General database${NC}"
echo "Row counts:"
mysql -u opensips -p'opensipsrw' General -e "
SELECT 'carriers' as table_name, COUNT(*) as rows FROM carriers UNION ALL
SELECT 'clients', COUNT(*) FROM clients UNION ALL
SELECT 'numbers', COUNT(*) FROM numbers UNION ALL
SELECT 'ranges', COUNT(*) FROM ranges UNION ALL
SELECT 'codes', COUNT(*) FROM codes UNION ALL
SELECT 'ivrs', COUNT(*) FROM ivrs;
" 2>/dev/null

echo ""
echo -e "${GREEN}4. Check Control Panel config for carriers${NC}"
if [ -f /var/www/html/opensips-cp/config/tools/wholesale/carriers/db.inc.php ]; then
    echo "Carriers config:"
    grep -E "db_name|db_user" /var/www/html/opensips-cp/config/tools/wholesale/carriers/db.inc.php | grep -v "^#" | head -10
else
    echo -e "${RED}Config file not found${NC}"
fi

echo ""
echo -e "${GREEN}5. Sample data from carriers table${NC}"
mysql -u opensips -p'opensipsrw' General -e "SELECT * FROM carriers LIMIT 3;" 2>/dev/null

echo ""
echo -e "${GREEN}6. Sample data from clients table${NC}"
mysql -u opensips -p'opensipsrw' General -e "SELECT * FROM clients LIMIT 3;" 2>/dev/null

echo ""
echo -e "${GREEN}7. Sample data from numbers table${NC}"
mysql -u opensips -p'opensipsrw' General -e "SELECT * FROM numbers LIMIT 3;" 2>/dev/null

echo ""
echo "========================================================"
echo "Diagnostic Complete"
echo "========================================================"
