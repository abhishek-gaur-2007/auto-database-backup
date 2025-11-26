# Quick Start Guide

Get your database backup system running in 5 minutes!

## 🚀 Fast Setup

### Option 1: Automated Setup (Recommended)

Run the interactive setup script:

```bash
cd /home/mcu/Developing/github/auto-database-backup
./setup.sh
```

The script will guide you through:
- Installing Python dependencies
- Configuring database credentials
- Setting up webhook notifications (optional)
- Creating cron jobs for automation
- Running a test backup

### Option 2: Manual Setup

1. **Install dependencies:**
   
   For Ubuntu 23.04+, Debian 12+ (externally-managed Python):
   ```bash
   sudo apt-get update
   sudo apt-get install python3-requests python3-tz
   ```
   
   For other systems:
   ```bash
   pip3 install -r requirements.txt --user
   ```

2. **Create a dedicated MySQL backup user (recommended):**
   ```bash
   mysql -u root -p
   ```
   ```sql
   CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'secure_password';
   GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER, RELOAD ON *.* TO 'backup_user'@'localhost';
   FLUSH PRIVILEGES;
   EXIT;
   ```
   
   See [README.md](README.md#-creating-a-dedicated-backup-user-recommended) for detailed instructions.

3. **Configure:**
   ```bash
   cp sample_config.json config.json
   nano config.json
   ```

4. **Edit config.json with your settings:**
   - Database username and password (use backup_user created above)
   - List of databases to backup
   - Backup directory path
   - Timezone (e.g., UTC, America/New_York)
   - Discord webhook URL (optional)

5. **Run a test backup:**
   ```bash
   python3 backup.py
   ```

## 📋 Minimal Configuration Example

```json
{
  "db_username": "backup_user",
  "db_password": "your_secure_password",
  "databases": ["myapp_db", "wordpress"],
  "backup_directory": "/var/backups/mysql",
  "timezone": "UTC",
  "enable_webhook": false,
  "webhook_url": "",
  "webhook_templates": {
    "success": "webhooks/success.json",
    "error": "webhooks/error.json",
    "upload": "webhooks/upload.json"
  }
}
```

## ⏰ Set Up Automatic Backups

Add to crontab (`crontab -e`):

```bash
# Daily backup at 2 AM
0 2 * * * /usr/bin/python3 /home/mcu/Developing/github/auto-database-backup/backup.py

# Every 12 hours
0 */12 * * * /usr/bin/python3 /home/mcu/Developing/github/auto-database-backup/backup.py
```

## ✅ Verify Everything Works

1. **Check backup was created:**
   ```bash
   ls -lh /var/backups/mysql/
   ```

2. **Check the log:**
   ```bash
   cat backup.log
   ```

3. **Test extraction:**
   ```bash
   tar -tzf /var/backups/mysql/*.tar.gz
   ```

## 🔐 Security Tips

```bash
# Protect your config file
chmod 600 config.json

# Protect backup directory
chmod 700 /var/backups/mysql
```

## 📚 Need More Details?

See the full [README.md](README.md) for:
- Detailed configuration options
- Webhook setup guide
- Troubleshooting tips
- Advanced usage examples

## 🆘 Quick Troubleshooting

**mysqldump not found?**
```bash
sudo apt-get install mysql-client
```

**Permission denied on backup directory?**
```bash
sudo mkdir -p /var/backups/mysql
sudo chown $USER:$USER /var/backups/mysql
```

**Database connection failed?**
```bash
# Test connection manually
mysql -u your_username -p
```

**Python package installation error (externally-managed-environment)?**
```bash
# Use system packages instead
sudo apt-get install python3-requests python3-tz

# OR use --user flag
pip3 install --user requests pytz
```

---

**That's it! Your backups are now automated! 🎉**

