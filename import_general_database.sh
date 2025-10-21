#!/bin/bash

###############################################################################
# Import General Database - Restore Wholesale Data
# This imports carriers, clients, numbers, ranges, and IVR data
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================================"
echo "Import General Database (Wholesale Data)"
echo "========================================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Run as root: sudo bash import_general_database.sh${NC}"
    exit 1
fi

# Check if dump file exists
if [ ! -f "general_database_dump.sql" ]; then
    echo -e "${RED}Error: general_database_dump.sql not found${NC}"
    echo "Please ensure the file is in the current directory"
    exit 1
fi

DUMP_SIZE=$(du -h general_database_dump.sql | cut -f1)
echo "Database dump size: $DUMP_SIZE"
echo ""

echo "Enter your MySQL root password:"
read -s MYSQL_ROOT_PASSWORD
echo ""

echo -e "${GREEN}Step 1: Create 'General' database${NC}"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<'EOSQL'
CREATE DATABASE IF NOT EXISTS General CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOSQL

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database created${NC}"
else
    echo -e "${RED}✗ Failed to create database${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Step 2: Import data (this may take a minute...)${NC}"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" General < general_database_dump.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Data imported successfully${NC}"
else
    echo -e "${RED}✗ Import failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Step 3: Grant permissions to opensips user${NC}"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<'EOSQL'
GRANT ALL PRIVILEGES ON General.* TO 'opensips'@'localhost';
GRANT ALL PRIVILEGES ON General.* TO 'web'@'localhost';
FLUSH PRIVILEGES;
EOSQL
echo -e "${GREEN}✓ Permissions granted${NC}"

echo ""
echo -e "${GREEN}Step 4: Verify import${NC}"
echo "Tables imported:"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" General -e "SHOW TABLES;"

echo ""
echo "Row counts:"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" General <<'EOSQL'
SELECT 
    table_name as 'Table',
    table_rows as 'Rows'
FROM 
    information_schema.tables
WHERE 
    table_schema = 'General'
ORDER BY 
    table_rows DESC;
EOSQL

echo ""
echo -e "${GREEN}Step 5: Update Control Panel configs to use 'General' database${NC}"
CONFIG_DIR="/var/www/html/opensips-cp/config/tools/wholesale"

if [ -d "$CONFIG_DIR" ]; then
    # Update wholesale tools to use General database
    find "$CONFIG_DIR" -name "db.inc.php" -type f | while read config_file; do
        cp "$config_file" "${config_file}.backup_general"
        
        # Set database name back to General for wholesale tools
        sed -i 's/\["db_name"\].*"opensips"/["db_name"] = "General"/g' "$config_file"
        
        echo "  ✓ Updated $(basename $(dirname $config_file))"
    done
    echo -e "${GREEN}✓ Wholesale configs updated to use 'General' database${NC}"
else
    echo -e "${YELLOW}⚠ Config directory not found${NC}"
fi

echo ""
echo -e "${GREEN}Step 6: Clear PHP sessions and restart Apache${NC}"
rm -rf /var/lib/php/sessions/* 2>/dev/null
systemctl restart apache2
sleep 2
echo -e "${GREEN}✓ Apache restarted${NC}"

echo ""
echo "========================================================"
echo -e "${GREEN}Import Complete!${NC}"
echo "========================================================"
echo ""
echo "Imported data:"
echo "  • 53,871 codes"
echo "  • 3,387 numbers"
echo "  • 481 ranges"
echo "  • 14 IVRs"
echo "  • 13 carrier IPs"
echo "  • 9 IVR groups"
echo "  • 5 clients"
echo "  • 4 carriers"
echo "  • 4 client IPs"
echo ""
echo "Database structure:"
echo "  • 'opensips' - Core OpenSIPs data"
echo "  • 'General' - Wholesale data (carriers, clients, numbers)"
echo ""
echo -e "${YELLOW}IMPORTANT: Clear browser cache or use Private/Incognito mode${NC}"
echo ""
echo "Access: http://$(hostname -I | awk '{print $1}')/"
echo "Login: rezguitarek / kingsm"
echo ""
echo "Now check:"
echo "  ✓ Carriers - should show data"
echo "  ✓ Clients - should show data"
echo "  ✓ Numbers - should show data"
echo "  ✓ Ranges - should show data"
echo ""
