#!/bin/bash

###############################################################################
# Check Wholesale Data - Diagnose missing carriers/clients/numbers
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================================"
echo "Wholesale Data Diagnostic"
echo "========================================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Run as root: sudo bash check_wholesale_data.sh${NC}"
    exit 1
fi

echo -e "${GREEN}Step 1: Check what databases exist${NC}"
mysql -u opensips -p'opensipsrw' -e "SHOW DATABASES;" 2>/dev/null | grep -v "information_schema\|performance_schema\|mysql\|sys"

echo ""
echo -e "${GREEN}Step 2: Check tables in 'opensips' database${NC}"
echo "Looking for wholesale-related tables:"
mysql -u opensips -p'opensipsrw' opensips -e "SHOW TABLES;" 2>/dev/null | grep -iE "carrier|client|number|range|gateway|route"

echo ""
echo -e "${GREEN}Step 3: Check if wholesale tables exist and have data${NC}"

# Check dr_carriers (dynamic routing carriers)
echo "--- dr_carriers table ---"
if mysql -u opensips -p'opensipsrw' opensips -e "SELECT COUNT(*) as total_carriers FROM dr_carriers;" 2>/dev/null; then
    echo -e "${GREEN}✓ dr_carriers table exists${NC}"
    mysql -u opensips -p'opensipsrw' opensips -e "SELECT * FROM dr_carriers LIMIT 3;" 2>/dev/null
else
    echo -e "${RED}✗ dr_carriers table missing or inaccessible${NC}"
fi

echo ""
echo "--- dr_gateways table ---"
if mysql -u opensips -p'opensipsrw' opensips -e "SELECT COUNT(*) as total_gateways FROM dr_gateways;" 2>/dev/null; then
    echo -e "${GREEN}✓ dr_gateways table exists${NC}"
    mysql -u opensips -p'opensipsrw' opensips -e "SELECT * FROM dr_gateways LIMIT 3;" 2>/dev/null
else
    echo -e "${RED}✗ dr_gateways table missing or inaccessible${NC}"
fi

echo ""
echo "--- dr_rules table ---"
if mysql -u opensips -p'opensipsrw' opensips -e "SELECT COUNT(*) as total_rules FROM dr_rules;" 2>/dev/null; then
    echo -e "${GREEN}✓ dr_rules table exists${NC}"
    mysql -u opensips -p'opensipsrw' opensips -e "SELECT * FROM dr_rules LIMIT 3;" 2>/dev/null
else
    echo -e "${RED}✗ dr_rules table missing or inaccessible${NC}"
fi

echo ""
echo -e "${GREEN}Step 4: List ALL tables in opensips database${NC}"
mysql -u opensips -p'opensipsrw' opensips -e "SHOW TABLES;" 2>/dev/null

echo ""
echo -e "${GREEN}Step 5: Check table row counts${NC}"
mysql -u opensips -p'opensipsrw' opensips <<'EOSQL' 2>/dev/null
SELECT 
    TABLE_NAME as 'Table',
    TABLE_ROWS as 'Rows'
FROM 
    information_schema.TABLES
WHERE 
    TABLE_SCHEMA = 'opensips'
    AND TABLE_ROWS > 0
ORDER BY 
    TABLE_ROWS DESC
LIMIT 20;
EOSQL

echo ""
echo "========================================================"
echo -e "${YELLOW}Analysis${NC}"
echo "========================================================"
echo ""
echo "If you see tables with 0 rows, the database structure exists"
echo "but the data was not imported."
echo ""
echo "Possible causes:"
echo "  1. Old server had wholesale data in 'General' database"
echo "  2. Data was in a different database we didn't export"
echo "  3. Tables need to be populated from scratch"
echo ""
echo "Next steps:"
echo "  • Check if old server had separate 'General' database"
echo "  • If yes, we need to export and import it"
echo "  • If no, check what data exists in original database dump"
echo ""
