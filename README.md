# Auto Database Backup System

A robust, automated Python-based backup solution for MySQL/MariaDB databases with compression, webhook notifications, and intelligent error handling.

**Developed by [Slice Studios](https://studio.slice.wtf)**

---

## 🚀 Features

- **Multi-Database Support** - Backup multiple databases in a single run
- **Automatic Compression** - Compresses SQL dumps to `.tar.gz` format (configurable level 1-9)
- **Auto-Cleanup** - Automatically delete old backups after X files (default: 25)
- **File Size Limits** - Prevent saving oversized backups (default: 1000MB max)
- **Database Size Tracking** - Display database size in webhook notifications
- **Remote Backups** - Backup local or remote databases (configurable host/port)
- **Discord Webhooks** - Beautiful notifications with file uploads
- **Timezone Support** - Configure backup timestamps in any timezone
- **Smart Error Handling** - Intelligent directory creation and comprehensive error reporting
- **Flexible MySQL Options** - Configurable transactions, table locks, and more
- **Detailed Logging** - Both file and console with configurable log levels
- **Cron-Friendly** - Designed for automated scheduling

## 📸 Webhook Notifications Preview

![Webhook Example](https://cdn.discordapp.com/attachments/1431197138301354017/1443317084883779674/image.png?ex=6928a148&is=69274fc8&hm=297e259ed4c545e9d0c40432a2dafe90e5987cd9a17b8817ab2b3254ec109518&)

Beautiful Discord notifications showing:
- ✅ Backup completion status
- 💾 Database and file sizes
- 📦 Compressed backup uploads (if < 10MB)
- ⏰ Timestamp with timezone
- 🎨 Slice Studios branding

---

## 📁 Project Structure

```
auto-database-backup/
├── backup.py              # Main backup script
├── utils.py               # Helper functions
├── config.json            # Your configuration
├── sample_config.json     # Example configuration
├── requirements.txt       # Python dependencies
├── setup.sh              # Interactive setup script
└── webhooks/             # Webhook templates
    ├── success.json
    ├── error.json
    └── upload.json
```

## 🚀 Quick Start

### Automated Setup (Recommended)

```bash
chmod +x setup.sh
./setup.sh
```

The setup script handles everything: dependencies, configuration, database user creation guidance, and cron job setup.

### Manual Setup

```bash
# 1. Install dependencies (Ubuntu/Debian)
sudo apt-get install mysql-client python3-requests python3-tz

# 2. Configure
cp sample_config.json config.json
nano config.json

# 3. Run
python3 backup.py
```

---

## ⚙️ Configuration

### Essential Settings

```json
{
  "db_username": "backup_user",
  "db_password": "your_password",
  "db_host": "localhost",
  "db_port": 3306,
  
  "databases": ["db1", "db2"],
  "backup_directory": "/var/backups/mysql",
  "timezone": "UTC",
  
  "auto_clean_after_x_files": 25,
  "max_file_size_in_mb": 1000,
  "compression_level": 6,
  
  "enable_webhook": true,
  "webhook_url": "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/TOKEN"
}
```

### Configuration Reference

| Setting | Default | Description |
|---------|---------|-------------|
| `db_host` | `localhost` | Database server (IP or hostname) |
| `db_port` | `3306` | Database port |
| `auto_clean_after_x_files` | `25` | Max backups per DB (0=disabled) |
| `max_file_size_in_mb` | `1000` | Max backup size (0=unlimited) |
| `compression_level` | `6` | Gzip level (1-9) |
| `single_transaction` | `true` | Consistent InnoDB backups |
| `lock_tables` | `false` | Lock during backup |
| `log_level` | `INFO` | DEBUG/INFO/WARNING/ERROR |

---

## 🔐 Database User Setup

Create a dedicated backup user for security:

```sql
-- Local backups
CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'secure_password';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER, RELOAD ON *.* TO 'backup_user'@'localhost';
FLUSH PRIVILEGES;

-- Remote backups (replace IP)
CREATE USER 'backup_user'@'192.168.1.100' IDENTIFIED BY 'secure_password';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER, RELOAD ON *.* TO 'backup_user'@'192.168.1.100';
FLUSH PRIVILEGES;
```

---

## 🌐 Remote Backups

Backup databases from anywhere:

```json
{
  "db_host": "192.168.1.50",        // Remote server
  "db_host": "db.example.com",       // Domain name
  "db_host": "mydb.rds.amazonaws.com" // Cloud database
}
```

Works with: AWS RDS, DigitalOcean, Azure, Google Cloud SQL, or any remote MySQL/MariaDB server.

---

## 🔔 Webhook Setup

1. Discord Server → Settings → Integrations → Webhooks
2. Create webhook, copy URL
3. Add to `config.json`

**Webhook Placeholders:**
- `{{database}}` - Database name
- `{{db_size}}` - Database size (1.45 GB)
- `{{file_size}}` - Backup size (456 MB)
- `{{filepath}}` - Full path to backup
- `{{timestamp}}` - Human-readable time
- `{{error_message}}` - Error details

**File Upload Limit:** 10MB (Discord limit). Files >10MB: notification sent without attachment, file saved locally.

---

## 🎯 Key Features Explained

### Auto-Cleanup
When creating backup #26, oldest is deleted automatically. Always keeps last 25 (or your configured number).

### Max File Size
Backups exceeding `max_file_size_in_mb` are deleted with error notification. Prevents disk space issues.

### Database Size Tracking
Shows original DB size and compressed file size in webhooks. Monitor growth over time.

---

## ⏰ Cron Scheduling

```bash
crontab -e
```

**Examples:**
```bash
0 2 * * * /usr/bin/python3 /path/to/backup.py              # Daily 2AM
0 */12 * * * /usr/bin/python3 /path/to/backup.py           # Every 12 hours
0 3 * * 0 /usr/bin/python3 /path/to/backup.py              # Weekly Sunday 3AM
```

---

## 📊 Usage

```bash
# Run backup
python3 backup.py

# Custom config
python3 backup.py /path/to/config.json

# Check logs
cat backup.log

# View backups
ls -lh /var/backups/mysql/
```

**Backup file format:** `database-dd-mm-yyyy-hh-mm-ss.sql.tar.gz`

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| `mysqldump not found` | `sudo apt-get install mysql-client` |
| `externally-managed-environment` | `sudo apt-get install python3-requests python3-tz` |
| `Permission denied` | `chmod 700 /var/backups/mysql` or use sudo |
| `Access denied` | Verify credentials, check user permissions |
| `Webhook not working` | Check URL, enable in config, verify network |

---

## 📦 Requirements

- Python 3.6+
- MySQL/MariaDB client (`mysql`, `mysqldump`)
- Python packages: `requests`, `pytz`
- Network access (for remote databases)
- Sufficient disk space

---

## 🔒 Security

```bash
# Protect config
chmod 600 config.json

# Secure backups
chmod 700 /var/backups/mysql

# Use dedicated backup user (not root)
# Keep webhook URLs private
```

---

## 🏢 Credits

**Developed by [Slice Studios](https://studio.slice.wtf)**

Visit us: **[studio.slice.wtf](https://studio.slice.wtf)**

---

## 📄 License

Open-source under MIT License. Free for personal and commercial use.

---

**Made with ❤️ for reliable database backups**
