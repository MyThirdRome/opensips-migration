#!/bin/bash
# Reassemble the database dump
echo "Reassembling database dump..."
cat database_dump.sql.part* > database_dump.sql
echo "✓ Database reassembled: database_dump.sql"
echo "File size: $(du -h database_dump.sql | cut -f1)"
