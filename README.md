# Auto Database Backup System

A robust, automated Python-based backup solution for MySQL/MariaDB databases with compression, webhook notifications, and intelligent error handling.

**Developed by [Slice Studios](https://studio.slice.wtf)**

---

## 🚀 Features

- **Multi-Database Support**: Backup multiple databases in a single run
- **Automatic Compression**: Compresses SQL dumps to `.tar.gz` format
- **Webhook Notifications**: Discord webhook support with customizable templates
- **Timezone Support**: Configure backup timestamps in any timezone
- **Error Handling**: Intelligent directory creation and comprehensive error reporting
- **Logging**: Detailed logging to both file and console
- **Cron-Friendly**: Designed for automated scheduling

## 📁 Project Structure

```
auto-database-backup/
├── backup.py              # Main backup script
├── utils.py               # Helper functions
├── config.json            # Your configuration (create from sample)
├── sample_config.json     # Example configuration
├── requirements.txt       # Python dependencies
├── setup.sh              # Interactive setup script
├── backup.log            # Log file (created on first run)
└── webhooks/             # Webhook templates
    ├── success.json      # Success notification template
    ├── error.json        # Error notification template
    └── upload.json       # Upload notification template
```

## 🛠️ Installation

### Quick Setup (Recommended)

Run the interactive setup script:

```bash
chmod +x setup.sh
./setup.sh
```

The setup script will:
- Check for required dependencies
- Install Python packages
- Guide you through configuration
- Optionally set up a cron job

### Manual Setup

1. **Clone or download this repository**

2. **Install Python dependencies:**

   **For Ubuntu 23.04+, Debian 12+, and systems with externally-managed Python environments:**
   ```bash
   # Recommended: Use system packages
   sudo apt-get update
   sudo apt-get install python3-requests python3-tz
   ```
   
   **For older systems or other distributions:**
   ```bash
   # User-local installation
   pip3 install -r requirements.txt --user
   
   # OR if externally-managed environment:
   pip3 install -r requirements.txt --break-system-packages
   ```
   
   **Alternative: Virtual environment (optional):**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip3 install -r requirements.txt
   # Note: You'll need to activate the venv before running backups
   ```

3. **Install MySQL/MariaDB client tools:**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install mysql-client
   
   # CentOS/RHEL
   sudo yum install mysql
   
   # Verify installation
   mysqldump --version
   ```

4. **Configure the backup system:**
   ```bash
   cp sample_config.json config.json
   nano config.json  # or use your preferred editor
   ```

## 👤 Creating a Dedicated Backup User (Recommended)

For security best practices, it's highly recommended to create a dedicated MySQL/MariaDB user specifically for backups instead of using the root account.

### Create Backup User with Proper Permissions

Connect to MySQL/MariaDB as root or admin user:

```bash
mysql -u root -p
```

Then execute the following SQL commands:

#### Option 1: Backup User for ALL Databases

This user can backup all databases on the server:

```sql
-- Create the backup user
CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'your_secure_password_here';

-- Grant necessary permissions for mysqldump
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER, RELOAD ON *.* TO 'backup_user'@'localhost';

-- Apply the changes
FLUSH PRIVILEGES;

-- Verify the user was created
SELECT User, Host FROM mysql.user WHERE User = 'backup_user';
```

#### Option 2: Backup User for Specific Databases

If you want to limit the user to only specific databases:

```sql
-- Create the backup user
CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'your_secure_password_here';

-- Grant permissions for each database (repeat for each database)
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON database1.* TO 'backup_user'@'localhost';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON database2.* TO 'backup_user'@'localhost';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON database3.* TO 'backup_user'@'localhost';

-- Apply the changes
FLUSH PRIVILEGES;
```

#### Option 3: Remote Backup User (if backing up from another server)

If you're running backups from a different server:

```sql
-- Create the backup user (replace 'backup_server_ip' with actual IP)
CREATE USER 'backup_user'@'backup_server_ip' IDENTIFIED BY 'your_secure_password_here';

-- Grant necessary permissions
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER, RELOAD ON *.* TO 'backup_user'@'backup_server_ip';

-- Apply the changes
FLUSH PRIVILEGES;
```

### Required Permissions Explained

| Permission | Purpose |
|------------|---------|
| `SELECT` | Read data from tables (required for mysqldump) |
| `LOCK TABLES` | Lock tables during backup for consistency |
| `SHOW VIEW` | Backup view definitions |
| `EVENT` | Backup scheduled events |
| `TRIGGER` | Backup trigger definitions |
| `RELOAD` | Flush tables (optional but recommended) |

### Test the Backup User

Before using the new user in your configuration, test that it can access the databases:

```bash
# Test connection
mysql -u backup_user -p

# Test mysqldump with the new user
mysqldump -u backup_user -p database_name > /tmp/test_backup.sql

# If successful, clean up the test file
rm /tmp/test_backup.sql
```

### Update Configuration

After creating the backup user, update your `config.json`:

```json
{
  "db_username": "backup_user",
  "db_password": "your_secure_password_here",
  "databases": ["database1", "database2", "database3"],
  ...
}
```

### Security Notes

- **Strong Password**: Use a strong, unique password for the backup user
- **Least Privilege**: Only grant permissions needed for backups
- **Local Access**: Prefer `'user'@'localhost'` over `'user'@'%'` when possible
- **Regular Audits**: Periodically review database users and their permissions

```sql
-- View all users and their hosts
SELECT User, Host FROM mysql.user;

-- View permissions for backup user
SHOW GRANTS FOR 'backup_user'@'localhost';
```

## ⚙️ Configuration

### config.json

Edit `config.json` with your database and backup settings:

```json
{
  "db_username": "your_mysql_username",
  "db_password": "your_mysql_password",
  "databases": [
    "database1",
    "database2",
    "database3"
  ],
  "backup_directory": "/var/backups/mysql",
  "timezone": "UTC",
  "enable_webhook": true,
  "webhook_url": "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_TOKEN",
  "webhook_templates": {
    "success": "webhooks/success.json",
    "error": "webhooks/error.json",
    "upload": "webhooks/upload.json"
  }
}
```

### Configuration Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `db_username` | string | Yes | MySQL/MariaDB username |
| `db_password` | string | Yes | MySQL/MariaDB password |
| `databases` | array | Yes | List of database names to backup |
| `backup_directory` | string | Yes | Directory to store backups |
| `timezone` | string | Yes | Timezone for timestamps (e.g., "UTC", "America/New_York") |
| `enable_webhook` | boolean | No | Enable Discord webhook notifications |
| `webhook_url` | string | No | Discord webhook URL |
| `webhook_templates` | object | No | Paths to webhook template files |

### Timezone Examples

- `UTC` - Coordinated Universal Time
- `America/New_York` - Eastern Time
- `Europe/London` - British Time
- `Asia/Tokyo` - Japan Time
- `Australia/Sydney` - Australian Eastern Time

See [pytz documentation](https://pypi.org/project/pytz/) for all available timezones.

## 📝 Backup Naming Format

All backup files follow this naming convention:

```
databasename-dd-mm-yyyy-hh-mm-ss.sql.tar.gz
```

**Examples:**
- `myapp_db-26-11-2025-14-30-45.sql.tar.gz`
- `wordpress-01-01-2025-00-00-00.sql.tar.gz`

The timestamp is based on the timezone configured in `config.json`.

## 🔔 Webhook Configuration

### Discord Webhook Setup

1. Open your Discord server
2. Go to Server Settings → Integrations → Webhooks
3. Click "New Webhook"
4. Copy the Webhook URL
5. Paste it into `webhook_url` in `config.json`

### 📏 File Size Limit

**Important:** Discord webhooks have a **10MB maximum file size limit** for attachments.

**How it works:**
- ✅ Files **under 10MB**: Uploaded automatically with the webhook notification
- ⚠️ Files **over 10MB**: Notification sent WITHOUT file attachment
  - The webhook message will include the file size and a warning
  - An error is logged: "Cannot upload file to webhook: File size exceeds 10MB limit"
  - The backup file is still saved locally in your backup directory

**Recommendation:** For large databases:
- Consider more frequent incremental backups
- Use file rotation/cleanup to manage old backups
- Access backup files directly from the server instead of webhook uploads

### Webhook Templates

The system uses three customizable webhook templates in the `webhooks/` directory:

#### success.json
Sent after successful database backup (before compression).

#### error.json
Sent when an error occurs during:
- Configuration loading
- Directory creation/access
- Database backup process
- Compression

#### upload.json
Sent after successful compression with the `.tar.gz` file attached.

### Template Placeholders

All webhook templates support these placeholders:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{database}}` | Database name | `myapp_db` |
| `{{filepath}}` | Full path to backup file | `/var/backups/mysql/myapp_db-26-11-2025.sql.tar.gz` |
| `{{timestamp}}` | Human-readable timestamp | `2025-11-26 14:30:45 UTC` |
| `{{status}}` | Status message | `SUCCESS`, `ERROR`, `UPLOAD` |
| `{{error_message}}` | Error details (error template only) | `Permission denied: Cannot create directory` |

### Customizing Webhook Templates

You can fully customize the webhook JSON files. Here's an example:

```json
{
  "username": "Database Backup Bot",
  "avatar_url": "https://i.imgur.com/4M34hi2.png",
  "embeds": [
    {
      "title": "✅ Backup Successful",
      "description": "Database backup completed successfully.",
      "color": 3066993,
      "fields": [
        {
          "name": "Database",
          "value": "{{database}}",
          "inline": true
        },
        {
          "name": "Timestamp",
          "value": "{{timestamp}}",
          "inline": false
        }
      ]
    }
  ]
}
```

Placeholders like `{{database}}` will be automatically replaced with actual values.

## 🚨 Error Handling

### Directory Creation

The backup system intelligently handles the backup directory:

1. **Directory Exists**: Proceeds with backup
2. **Directory Missing**: Attempts to create it automatically
3. **Creation Fails**: 
   - Logs the error
   - Sends error webhook (if enabled)
   - Stops the backup process

**Common directory errors:**
- **Permission Denied**: Run with appropriate permissions or use sudo
- **Invalid Path**: Ensure parent directories exist
- **Read-Only Filesystem**: Choose a writable location

### Error Webhook Notifications

When directory creation fails, the error webhook includes:
- Directory path that failed
- Detailed error message
- Timestamp of the failure

**Example error scenarios:**
- `/root/backups` without root permissions
- `/mnt/external/backups` when drive is not mounted
- `/invalid/path/with/missing/parents`

## 🔧 Usage

### Manual Execution

Run the backup script manually:

```bash
python3 backup.py
```

Or with a custom config file:

```bash
python3 backup.py /path/to/custom_config.json
```

### Output Example

```
2025-11-26 14:30:45,123 - INFO - ============================================================
2025-11-26 14:30:45,124 - INFO - Database Backup System Starting
2025-11-26 14:30:45,125 - INFO - ============================================================
2025-11-26 14:30:45,126 - INFO - Configuration loaded successfully
2025-11-26 14:30:45,127 - INFO - mysqldump is available
2025-11-26 14:30:45,128 - INFO - Backup directory exists: /var/backups/mysql
2025-11-26 14:30:45,129 - INFO - Starting backup for 2 database(s)
2025-11-26 14:30:45,130 - INFO - Processing database: myapp_db
2025-11-26 14:30:47,456 - INFO - Backup created successfully: /var/backups/mysql/myapp_db-26-11-2025-14-30-45.sql
2025-11-26 14:30:48,789 - INFO - Compressed /var/backups/mysql/myapp_db-26-11-2025-14-30-45.sql
2025-11-26 14:30:49,012 - INFO - Successfully backed up and compressed: myapp_db
2025-11-26 14:30:49,013 - INFO - ============================================================
2025-11-26 14:30:49,014 - INFO - Backup Summary: 2/2 successful
2025-11-26 14:30:49,015 - INFO - ============================================================
```

## ⏰ Automated Scheduling with Cron

### Setting Up Cron Jobs

1. **Open crontab editor:**
   ```bash
   crontab -e
   ```

2. **Add your desired schedule:**

### Cron Schedule Examples

```bash
# Every hour at minute 0
0 * * * * /usr/bin/python3 /home/user/auto-database-backup/backup.py

# Every 12 hours (midnight and noon)
0 */12 * * * /usr/bin/python3 /home/user/auto-database-backup/backup.py

# Daily at 2:00 AM
0 2 * * * /usr/bin/python3 /home/user/auto-database-backup/backup.py

# Weekly on Sunday at 3:00 AM
0 3 * * 0 /usr/bin/python3 /home/user/auto-database-backup/backup.py

# Monthly on the 1st at 4:00 AM
0 4 1 * * /usr/bin/python3 /home/user/auto-database-backup/backup.py

# Every 6 hours
0 */6 * * * /usr/bin/python3 /home/user/auto-database-backup/backup.py

# Twice daily (6 AM and 6 PM)
0 6,18 * * * /usr/bin/python3 /home/user/auto-database-backup/backup.py
```

### Cron Format Reference

```
* * * * * command
│ │ │ │ │
│ │ │ │ └─── Day of week (0-7, Sunday = 0 or 7)
│ │ │ └───── Month (1-12)
│ │ └─────── Day of month (1-31)
│ └───────── Hour (0-23)
└─────────── Minute (0-59)
```

### Cron Best Practices

1. **Use absolute paths** for both Python and the script
2. **Test the command** manually first
3. **Redirect output** for debugging:
   ```bash
   0 2 * * * /usr/bin/python3 /path/to/backup.py >> /path/to/cron.log 2>&1
   ```
4. **Set appropriate permissions**:
   ```bash
   chmod +x backup.py
   ```

### Finding Python Path

```bash
which python3
# Output: /usr/bin/python3
```

## 📊 Log Files

The system creates a `backup.log` file in the script directory with detailed information:

- Configuration loading
- Directory creation attempts
- Backup process for each database
- Compression operations
- Webhook notifications
- Errors and warnings
- Summary statistics

**Log file location:** Same directory as `backup.py`

## 🔒 Security Considerations

1. **Protect config.json**: Contains database credentials
   ```bash
   chmod 600 config.json
   ```

2. **Secure backup directory**: Limit access to backup files
   ```bash
   chmod 700 /var/backups/mysql
   ```

3. **Use dedicated MySQL user**: Create a backup-only user with minimal privileges (see [Creating a Dedicated Backup User](#-creating-a-dedicated-backup-user-recommended) section above for detailed instructions)

4. **Webhook URL security**: Keep your Discord webhook URL private

## 🧪 Testing

Test the backup system before scheduling:

```bash
# Test with a single database
python3 backup.py

# Check the log file
cat backup.log

# Verify backup files
ls -lh /var/backups/mysql/

# Test extraction
tar -tzf /var/backups/mysql/database-26-11-2025-14-30-45.sql.tar.gz
```

## 🐛 Troubleshooting

### mysqldump: command not found

**Solution:** Install MySQL client tools
```bash
sudo apt-get install mysql-client
```

### error: externally-managed-environment (PEP 668)

This error occurs on modern Linux systems (Ubuntu 23.04+, Debian 12+) that prevent pip from installing packages system-wide to avoid conflicts.

**Solution 1 (Recommended for VPS):** Install system packages
```bash
sudo apt-get update
sudo apt-get install python3-requests python3-tz
```

**Solution 2:** Install for user only
```bash
pip3 install -r requirements.txt --user
```

**Solution 3:** Override the restriction (use with caution)
```bash
pip3 install -r requirements.txt --break-system-packages
```

**Solution 4:** Use virtual environment
```bash
python3 -m venv venv
source venv/bin/activate
pip3 install -r requirements.txt
# Remember to activate venv before running backups
```

**Note:** The `setup.sh` script automatically detects and handles this situation by trying multiple installation methods.

### Permission denied: Cannot create directory

**Solutions:**
- Change `backup_directory` to a writable location
- Create the directory manually with appropriate permissions
- Run the script with elevated privileges (not recommended)

### Access denied for user

**Solutions:**
- Verify database credentials in `config.json`
- Ensure the MySQL user has necessary privileges
- Test connection: `mysql -u username -p`

### Webhook not receiving notifications

**Solutions:**
- Verify `enable_webhook` is `true`
- Check webhook URL is correct
- Ensure network connectivity
- Check Discord server permissions
- Review `backup.log` for webhook errors

### Timezone not working

**Solutions:**
- Verify timezone name (see pytz documentation)
- Install/update pytz: `pip3 install --upgrade pytz`
- Default to "UTC" if timezone is invalid

## 📦 Requirements

- **Python**: 3.6 or higher
- **MySQL/MariaDB Client**: mysqldump utility
- **Python Packages**: 
  - requests >= 2.31.0
  - pytz >= 2024.1
- **Permissions**: Read/write access to backup directory
- **Disk Space**: Sufficient space for compressed backups

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

This project is open-source and available for personal and commercial use under the MIT License.

## 📧 Support

For issues, questions, or suggestions, please open an issue on the repository.

---

## 🏢 Credits

**Developed by [Slice Studios](https://studio.slice.wtf)**

This Auto Database Backup System is proudly created and maintained by Slice Studios.

Visit us: **[studio.slice.wtf](https://studio.slice.wtf)**

---

**Made with ❤️ for reliable database backups**

