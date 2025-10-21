# OpenSIPs Migration Package

This repository contains a complete export of an OpenSIPs installation, including all configurations, database dumps, and custom files.

## Contents

- `database_dump.sql.part*` - Complete database export (split into parts due to GitHub file size limits)
- `REASSEMBLE_DB.sh` - Script to reassemble database parts
- `opensips_files.tar.gz` - Configuration files and custom scripts
- `audit_results.json` - Server audit information
- `install.sh` - Automated installation script

## Source Server Information

- **OpenSIPs Version**: version: opensips 3.0.3 (x86_64/linux)
- **Database Type**: mysql
- **Database Name**: opensips
- **Configuration Directory**: /etc/opensips
- **OS**: CentOS Linux

## Installation Instructions

### Prerequisites

- Fresh Ubuntu/Debian VPS
- Root access
- Internet connection

### Installation Steps

1. **Clone this repository:**
   ```bash
   git clone https://github.com/MyThirdRome/iprn.git
   cd iprn
   ```

2. **Reassemble the database dump (the database was split for GitHub):**
   ```bash
   chmod +x REASSEMBLE_DB.sh
   ./REASSEMBLE_DB.sh
   ```

3. **Run the installation script:**
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```

4. **Follow the prompts** to set up MySQL/PostgreSQL passwords

5. **Verify installation:**
   ```bash
   systemctl status opensips
   ```

### Post-Installation

- Update database credentials in configuration files if needed
- Review and adjust firewall rules for SIP ports (typically 5060/UDP)
- Configure your domain/IP addresses in OpenSIPs config
- Test SIP connectivity

## Troubleshooting

### Check OpenSIPs logs
```bash
journalctl -u opensips -f
```

### Restart OpenSIPs
```bash
systemctl restart opensips
```

### Verify database connection
```bash
mysql -u opensips -p
```

## Support

For issues or questions, please refer to the OpenSIPs documentation:
- https://www.opensips.org/Documentation/

## Migration Details

This migration package was created using an automated migration tool that:
1. Connected to the source server via SSH
2. Exported all OpenSIPs configurations
3. Dumped the complete database
4. Packaged custom files and scripts
5. Generated automated installation scripts

Generated on: 2025-10-21 15:23:38
