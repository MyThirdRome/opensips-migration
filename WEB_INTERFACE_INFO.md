# OpenSIPs Control Panel - Web Interface

## 🌐 Access Your Web Interface

After installation, your OpenSIPs Control Panel will be available at:

```
http://YOUR_SERVER_IP/
```

Replace `YOUR_SERVER_IP` with your actual server IP address (e.g., http://212.162.155.183/)

## 📦 What's Included

The migration includes:
- **OpenSIPs Control Panel (CP)** - Full web administration interface
- **OpenSIPs CP Client** - Client interface for managing users
- **Apache HTTP Server** - Web server (automatically installed)
- **PHP** - Required for Control Panel (automatically installed)

## 🔐 Default Login

The Control Panel login credentials are stored in your database. Use the same admin credentials you had on your source server (161.97.103.13).

## 📂 File Locations

After installation:
- **Web files**: `/var/www/html/`
- **Control Panel**: `/var/www/html/opensips-cp/`
- **CP Client**: `/var/www/html/opensips-cp-client/`
- **Apache config**: `/etc/apache2/` (on Ubuntu/Debian) or `/etc/httpd/` (on CentOS)

## ⚙️ Control Panel Features

Your migrated Control Panel includes tools for:
- **User Management** - Manage SIP subscribers, aliases, ACLs
- **System Monitoring** - View active dialogs, calls, CDRs
- **Routing Configuration** - Manage dial plans, load balancers, dispatchers
- **Wholesale Tools** - Manage carriers, clients, ranges, numbers
- **Reports** - Call statistics, ACL reports, missed calls
- **System Tools** - RTPProxy, dialplan, permissions, SIP trace

## 🔧 Troubleshooting

### Web Interface Not Loading?

1. **Check Apache is running:**
   ```bash
   systemctl status apache2
   ```

2. **Check firewall allows HTTP:**
   ```bash
   ufw allow 80/tcp
   # or
   firewall-cmd --add-service=http --permanent
   firewall-cmd --reload
   ```

3. **View Apache logs:**
   ```bash
   tail -f /var/log/apache2/error.log
   ```

4. **Check permissions:**
   ```bash
   ls -la /var/www/html/
   ```
   Files should be owned by `www-data:www-data`

### Can't Login to Control Panel?

1. **Check database connection** in Control Panel config
2. **Verify admin user exists** in database:
   ```bash
   mysql -u opensips -p opensips -e "SELECT * FROM ocp_admin_privileges;"
   ```

### PHP Errors?

1. **Check PHP is installed:**
   ```bash
   php -v
   ```

2. **Check Apache PHP module:**
   ```bash
   apache2ctl -M | grep php
   ```

## 🔄 Updating Control Panel Settings

If you need to update database connection settings:

Edit the Control Panel config:
```bash
nano /var/www/html/opensips-cp/config/db.inc.php
```

Update database credentials to match your new server settings.

## 📊 Database Tables

The Control Panel uses these database tables (already imported):
- `ocp_admin_privileges` - Admin users
- `subscriber` - SIP accounts
- `dialplan` - Routing rules
- `dialog` - Active calls
- `acc` - CDR records
- And many more...

## ✅ Verification

To verify your web interface is working:

1. Open browser: `http://YOUR_SERVER_IP/`
2. You should see the OpenSIPs Control Panel login page
3. Login with your admin credentials
4. Check all features are accessible

## 🔗 Useful Links

- OpenSIPs Documentation: https://www.opensips.org/Documentation
- Control Panel Docs: https://opensips.org/docs/modules/3.0.x/ocp.html

---

**Your complete OpenSIPs environment is now running with full web interface!** 🎉
