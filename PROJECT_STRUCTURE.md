# Project Structure

## 📂 Complete File Tree

```
auto-database-backup/
├── backup.py                 # Main backup script
├── utils.py                  # Helper functions and utilities
├── config.json              # Your active configuration (edit this)
├── sample_config.json       # Example configuration template
├── requirements.txt         # Python dependencies
├── setup.sh                 # Interactive setup script
├── README.md               # Complete documentation
├── QUICKSTART.md           # Fast setup guide
├── PROJECT_STRUCTURE.md    # This file
├── .gitignore              # Git ignore patterns
├── backup.log              # Log file (created on first run)
└── webhooks/               # Webhook notification templates
    ├── success.json        # Success notification
    ├── error.json          # Error notification
    └── upload.json         # File upload notification
```

## 📄 File Descriptions

### Core Scripts

- **backup.py** (356 lines)
  - Main backup script
  - Handles database dumps, compression, and notifications
  - Command-line interface
  - Automatic directory creation with error handling
  - Supports multiple databases

- **utils.py** (278 lines)
  - Logging setup
  - Configuration loading and validation
  - Timestamp formatting with timezone support
  - Directory management
  - Tar.gz compression
  - Webhook template loading and placeholder replacement
  - HTTP webhook sending with file attachments
  - File cleanup utilities

### Configuration Files

- **config.json**
  - Your active configuration (initially empty)
  - Contains database credentials
  - Should be secured with `chmod 600`
  - Not tracked by git (in .gitignore)

- **sample_config.json**
  - Template configuration with examples
  - Safe to commit to version control
  - Copy and customize for your setup

### Webhook Templates

- **webhooks/success.json**
  - Discord embed for successful backups
  - Green color (3066993)
  - Shows database, status, filepath, timestamp

- **webhooks/error.json**
  - Discord embed for backup failures
  - Red color (15158332)
  - Shows database, status, error message, filepath, timestamp
  - Includes directory creation errors

- **webhooks/upload.json**
  - Discord embed for file uploads
  - Blue color (3447003)
  - Attaches the .tar.gz file
  - Shows database, status, filepath, timestamp

### Setup & Documentation

- **setup.sh** (496 lines)
  - Interactive setup wizard
  - Checks system requirements
  - Installs Python dependencies
  - Configures database settings
  - Sets up webhook notifications
  - Creates backup directories
  - Tests database connection
  - Configures cron jobs with multiple schedule options
  - Runs test backup

- **README.md**
  - Comprehensive documentation
  - Installation instructions
  - Configuration guide
  - Webhook setup tutorial
  - Error handling explanation
  - Cron job examples
  - Troubleshooting guide
  - Security best practices

- **QUICKSTART.md**
  - 5-minute setup guide
  - Fast track to getting started
  - Minimal configuration examples
  - Quick troubleshooting tips

### Dependencies

- **requirements.txt**
  - `requests>=2.31.0` - HTTP library for webhooks
  - `pytz>=2024.1` - Timezone support

### Other Files

- **.gitignore**
  - Protects sensitive files (config.json, backups, logs)
  - Excludes Python cache and virtual environments
  - Prevents backup files from being committed

## 🎯 Key Features by File

| Feature | Implemented In |
|---------|---------------|
| Database backup | backup.py |
| File compression | utils.py, backup.py |
| Webhook notifications | utils.py, backup.py |
| Directory creation | utils.py |
| Error handling | backup.py, utils.py |
| Timezone support | utils.py |
| Logging | utils.py, backup.py |
| Configuration | config.json, utils.py |
| Interactive setup | setup.sh |
| Cron automation | setup.sh, README.md |

## 🔧 Executable Scripts

The following scripts are marked as executable:

- `backup.py` - Can be run directly: `./backup.py`
- `setup.sh` - Can be run directly: `./setup.sh`

## 📊 Code Statistics

- **Total Python lines**: ~634 lines
- **Total Shell lines**: ~496 lines
- **Total Documentation**: ~800+ lines
- **Webhook Templates**: 3 JSON files
- **Configuration Files**: 2 JSON files

## 🔄 Workflow

```
1. Run setup.sh
   ↓
2. Configure database credentials
   ↓
3. Set backup directory
   ↓
4. (Optional) Configure webhooks
   ↓
5. Set up cron job
   ↓
6. Test backup runs
   ↓
7. Automated backups begin
```

## 📝 Configuration Flow

```
sample_config.json → Copy → config.json → Used by → backup.py
                                                     ↓
                                                  utils.py
```

## 🔔 Webhook Flow

```
Event occurs in backup.py
    ↓
load_webhook_template() in utils.py
    ↓
Load JSON from webhooks/
    ↓
replace_placeholders() in utils.py
    ↓
send_webhook() in utils.py
    ↓
POST to Discord
```

## 🗄️ Backup Process Flow

```
backup.py starts
    ↓
Load config.json
    ↓
Check mysqldump availability
    ↓
Ensure backup directory exists
    ↓
For each database:
    ↓
    Run mysqldump → .sql file
    ↓
    Send success webhook
    ↓
    Compress to .tar.gz
    ↓
    Send upload webhook with file
    ↓
    Delete original .sql file
    ↓
Log summary and exit
```

## 🛡️ Security Considerations

### Protected Files
- `config.json` - Contains credentials (chmod 600)
- Backup directory - Contains sensitive data (chmod 700)

### Not in Git
- `config.json` - Actual configuration
- `backup.log` - May contain sensitive info
- `*.sql` - Database dumps
- `*.tar.gz` - Compressed backups

### Safe to Share
- All `.py` files
- `sample_config.json`
- `webhooks/*.json`
- Documentation files
- `setup.sh`

## 🎓 Learning Resources

If you want to understand the code better:

1. **Start with**: `utils.py` - Core utilities
2. **Then read**: `backup.py` - Main logic
3. **Customize**: `webhooks/*.json` - Notification templates
4. **Automate**: `setup.sh` - Deployment automation

## 🤝 Contributing

To extend this project:

1. **Add new features**: Extend `utils.py` or `backup.py`
2. **New webhook types**: Create templates in `webhooks/`
3. **Different databases**: Modify mysqldump commands
4. **Cloud uploads**: Add S3/GDrive functions to `utils.py`
5. **Retention policy**: Add cleanup logic to `backup.py`

---

**Built with Python 3, MySQL/MariaDB, and Discord Webhooks**

