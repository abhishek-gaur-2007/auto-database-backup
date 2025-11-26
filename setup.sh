#!/bin/bash

###############################################################################
# Auto Database Backup System - Interactive Setup Script
# This script helps you configure and install the backup system
#
# Copyright (c) 2025 Slice Studios (https://studio.slice.wtf)
# Licensed under MIT License
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}\n"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Prompt for input with default value
prompt_input() {
    local prompt="$1"
    local default="$2"
    local value
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " value
        echo "${value:-$default}"
    else
        read -p "$prompt: " value
        echo "$value"
    fi
}

# Prompt for password (hidden input)
prompt_password() {
    local prompt="$1"
    local value
    
    read -s -p "$prompt: " value
    echo ""
    echo "$value"
}

# Prompt for yes/no
prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local value
    
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " value
        value="${value:-y}"
    else
        read -p "$prompt [y/N]: " value
        value="${value:-n}"
    fi
    
    [[ "$value" =~ ^[Yy]$ ]]
}

# Check system requirements
check_requirements() {
    print_header "Checking System Requirements"
    
    local all_ok=true
    
    # Check Python 3
    if command_exists python3; then
        local python_version=$(python3 --version 2>&1 | awk '{print $2}')
        print_success "Python 3 found: $python_version"
    else
        print_error "Python 3 is not installed"
        all_ok=false
    fi
    
    # Check pip3
    if command_exists pip3; then
        print_success "pip3 found"
    else
        print_error "pip3 is not installed"
        all_ok=false
    fi
    
    # Check mysqldump
    if command_exists mysqldump; then
        local mysql_version=$(mysqldump --version 2>&1 | head -n1)
        print_success "mysqldump found: $mysql_version"
    else
        print_error "mysqldump is not installed"
        print_info "Install it with: sudo apt-get install mysql-client"
        all_ok=false
    fi
    
    # Check mysql client (optional but recommended)
    if command_exists mysql; then
        print_success "mysql client found"
    else
        print_warning "mysql client not found (optional, but recommended for testing)"
    fi
    
    if [ "$all_ok" = false ]; then
        print_error "Please install missing requirements and run this script again"
        exit 1
    fi
    
    echo ""
}

# Check if Python package is installed
check_python_package() {
    python3 -c "import $1" 2>/dev/null
    return $?
}

# Install Python dependencies with intelligent fallback
install_dependencies() {
    print_header "Installing Python Dependencies"
    
    if [ ! -f "$SCRIPT_DIR/requirements.txt" ]; then
        print_error "requirements.txt not found"
        exit 1
    fi
    
    # Check if packages are already installed
    print_info "Checking for existing Python packages..."
    local requests_installed=false
    local pytz_installed=false
    
    if check_python_package "requests"; then
        print_success "requests is already installed"
        requests_installed=true
    fi
    
    if check_python_package "pytz"; then
        print_success "pytz is already installed"
        pytz_installed=true
    fi
    
    if [ "$requests_installed" = true ] && [ "$pytz_installed" = true ]; then
        print_success "All Python dependencies are already installed"
        echo ""
        return 0
    fi
    
    print_info "Installing missing Python packages..."
    
    # Method 1: Try system package manager first (Debian/Ubuntu)
    if command_exists apt-get; then
        print_info "Attempting to install via apt (system packages)..."
        
        local apt_packages=""
        [ "$requests_installed" = false ] && apt_packages="$apt_packages python3-requests"
        [ "$pytz_installed" = false ] && apt_packages="$apt_packages python3-tz"
        
        if [ -n "$apt_packages" ]; then
            if sudo apt-get update -qq && sudo apt-get install -y $apt_packages 2>/dev/null; then
                print_success "Installed packages via apt"
                
                # Verify installation
                if check_python_package "requests" && check_python_package "pytz"; then
                    print_success "All Python dependencies installed successfully"
                    echo ""
                    return 0
                fi
            else
                print_warning "Could not install via apt (may require sudo or packages not available)"
            fi
        fi
    fi
    
    # Method 2: Try pip with --user flag
    print_info "Attempting to install via pip3 --user..."
    if pip3 install -r "$SCRIPT_DIR/requirements.txt" --user 2>/dev/null; then
        print_success "Installed packages via pip3 --user"
        
        # Verify installation
        if check_python_package "requests" && check_python_package "pytz"; then
            print_success "All Python dependencies installed successfully"
            echo ""
            return 0
        fi
    else
        print_warning "pip3 --user installation failed (externally-managed environment)"
    fi
    
    # Method 3: Try with --break-system-packages (for externally-managed environments)
    print_warning "Detected externally-managed Python environment (PEP 668)"
    print_info "This is common on Ubuntu 23.04+, Debian 12+, and similar systems"
    echo ""
    
    if prompt_yes_no "Install packages with --break-system-packages flag?" "y"; then
        print_info "Installing with --break-system-packages..."
        
        if pip3 install -r "$SCRIPT_DIR/requirements.txt" --break-system-packages 2>/dev/null; then
            print_success "Installed packages via pip3 --break-system-packages"
            
            # Verify installation
            if check_python_package "requests" && check_python_package "pytz"; then
                print_success "All Python dependencies installed successfully"
                echo ""
                return 0
            fi
        else
            print_error "Installation with --break-system-packages failed"
        fi
    fi
    
    # Method 4: Manual apt installation as fallback
    echo ""
    print_warning "Automatic installation failed. Trying manual system package installation..."
    print_info "Required packages: python3-requests, python3-tz"
    echo ""
    
    if prompt_yes_no "Install system packages manually with sudo?" "y"; then
        if sudo apt-get update && sudo apt-get install -y python3-requests python3-tz; then
            if check_python_package "requests" && check_python_package "pytz"; then
                print_success "All Python dependencies installed successfully via apt"
                echo ""
                return 0
            fi
        fi
    fi
    
    # If all methods failed
    echo ""
    print_error "Failed to install Python dependencies automatically"
    print_info "Please install manually using one of these methods:"
    echo ""
    echo "  Method 1 (Recommended for VPS/Server):"
    echo "    sudo apt-get update"
    echo "    sudo apt-get install python3-requests python3-tz"
    echo ""
    echo "  Method 2 (User installation):"
    echo "    pip3 install --user requests pytz"
    echo ""
    echo "  Method 3 (System-wide, use with caution):"
    echo "    pip3 install --break-system-packages requests pytz"
    echo ""
    echo "  Method 4 (Virtual environment):"
    echo "    python3 -m venv venv"
    echo "    source venv/bin/activate"
    echo "    pip3 install requests pytz"
    echo ""
    
    if ! prompt_yes_no "Continue setup without installing dependencies?" "n"; then
        exit 1
    fi
    
    echo ""
}

# Configure backup settings
configure_backup() {
    print_header "Database Configuration"
    
    # Database credentials
    DB_USERNAME=$(prompt_input "Database username" "root")
    DB_PASSWORD=$(prompt_password "Database password")
    
    # Databases to backup
    print_info "Enter database names to backup (comma-separated)"
    print_info "Example: myapp_db,wordpress,nextcloud"
    DATABASES=$(prompt_input "Database names")
    
    # Convert comma-separated list to JSON array
    IFS=',' read -ra DB_ARRAY <<< "$DATABASES"
    DB_JSON="["
    for i in "${!DB_ARRAY[@]}"; do
        db=$(echo "${DB_ARRAY[$i]}" | xargs) # trim whitespace
        if [ $i -gt 0 ]; then
            DB_JSON="$DB_JSON,"
        fi
        DB_JSON="$DB_JSON\"$db\""
    done
    DB_JSON="$DB_JSON]"
    
    # Backup directory
    print_info "\nBackup Directory Configuration"
    BACKUP_DIR=$(prompt_input "Backup directory path" "/var/backups/mysql")
    
    # Timezone
    print_info "\nTimezone Configuration"
    print_info "Examples: UTC, America/New_York, Europe/London, Asia/Tokyo"
    TIMEZONE=$(prompt_input "Timezone" "UTC")
    
    echo ""
}

# Configure webhook settings
configure_webhook() {
    print_header "Webhook Configuration"
    
    if prompt_yes_no "Enable Discord webhook notifications?" "n"; then
        ENABLE_WEBHOOK="true"
        
        print_info "\nTo get a Discord webhook URL:"
        print_info "1. Open your Discord server"
        print_info "2. Go to Server Settings → Integrations → Webhooks"
        print_info "3. Click 'New Webhook' and copy the URL"
        echo ""
        
        WEBHOOK_URL=$(prompt_input "Discord webhook URL")
    else
        ENABLE_WEBHOOK="false"
        WEBHOOK_URL=""
    fi
    
    echo ""
}

# Create configuration file
create_config() {
    print_header "Creating Configuration File"
    
    local config_file="$SCRIPT_DIR/config.json"
    
    if [ -f "$config_file" ]; then
        if ! prompt_yes_no "config.json already exists. Overwrite?" "n"; then
            print_info "Keeping existing configuration"
            return
        fi
        cp "$config_file" "$config_file.backup"
        print_info "Backup created: config.json.backup"
    fi
    
    # Create config.json
    cat > "$config_file" << EOF
{
  "db_username": "$DB_USERNAME",
  "db_password": "$DB_PASSWORD",
  "databases": $DB_JSON,
  "backup_directory": "$BACKUP_DIR",
  "timezone": "$TIMEZONE",
  "enable_webhook": $ENABLE_WEBHOOK,
  "webhook_url": "$WEBHOOK_URL",
  "webhook_templates": {
    "success": "webhooks/success.json",
    "error": "webhooks/error.json",
    "upload": "webhooks/upload.json"
  }
}
EOF
    
    # Secure the config file
    chmod 600 "$config_file"
    
    print_success "Configuration file created: $config_file"
    print_info "File permissions set to 600 (owner read/write only)"
    
    echo ""
}

# Create backup directory
create_backup_directory() {
    print_header "Setting Up Backup Directory"
    
    if [ -d "$BACKUP_DIR" ]; then
        print_success "Backup directory already exists: $BACKUP_DIR"
    else
        print_info "Creating backup directory: $BACKUP_DIR"
        
        if mkdir -p "$BACKUP_DIR" 2>/dev/null; then
            print_success "Backup directory created successfully"
        else
            print_warning "Failed to create directory (may require sudo)"
            
            if prompt_yes_no "Try with sudo?" "y"; then
                if sudo mkdir -p "$BACKUP_DIR"; then
                    print_success "Backup directory created with sudo"
                    
                    # Set ownership to current user
                    if prompt_yes_no "Set ownership to current user ($USER)?" "y"; then
                        sudo chown -R "$USER:$USER" "$BACKUP_DIR"
                        print_success "Ownership changed to $USER"
                    fi
                else
                    print_error "Failed to create backup directory"
                    print_warning "You'll need to create it manually: $BACKUP_DIR"
                fi
            fi
        fi
    fi
    
    echo ""
}

# Test backup connection
test_connection() {
    print_header "Testing Database Connection"
    
    if prompt_yes_no "Test database connection?" "y"; then
        print_info "Testing connection to MySQL/MariaDB..."
        
        # Test with first database in the array
        if [ ${#DB_ARRAY[@]} -gt 0 ]; then
            local test_db="${DB_ARRAY[0]}"
            test_db=$(echo "$test_db" | xargs) # trim whitespace
            
            if mysql -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "USE $test_db;" 2>/dev/null; then
                print_success "Successfully connected to database: $test_db"
            else
                print_error "Failed to connect to database: $test_db"
                print_warning "Please verify your database credentials"
            fi
        fi
    fi
    
    echo ""
}

# Configure cron job
configure_cron() {
    print_header "Cron Job Configuration"
    
    if ! prompt_yes_no "Set up automatic backups with cron?" "y"; then
        print_info "Skipping cron setup"
        print_info "You can run backups manually with: python3 $SCRIPT_DIR/backup.py"
        return
    fi
    
    echo ""
    print_info "Select backup frequency:"
    echo "  1) Every hour"
    echo "  2) Every 6 hours"
    echo "  3) Every 12 hours"
    echo "  4) Daily (2:00 AM)"
    echo "  5) Weekly (Sunday 3:00 AM)"
    echo "  6) Custom cron expression"
    echo ""
    
    read -p "Enter choice [1-6]: " cron_choice
    
    local python_path=$(which python3)
    local script_path="$SCRIPT_DIR/backup.py"
    local cron_schedule=""
    
    case $cron_choice in
        1)
            cron_schedule="0 * * * *"
            print_info "Schedule: Every hour"
            ;;
        2)
            cron_schedule="0 */6 * * *"
            print_info "Schedule: Every 6 hours"
            ;;
        3)
            cron_schedule="0 */12 * * *"
            print_info "Schedule: Every 12 hours"
            ;;
        4)
            cron_schedule="0 2 * * *"
            print_info "Schedule: Daily at 2:00 AM"
            ;;
        5)
            cron_schedule="0 3 * * 0"
            print_info "Schedule: Weekly on Sunday at 3:00 AM"
            ;;
        6)
            cron_schedule=$(prompt_input "Enter cron expression (e.g., '0 */6 * * *')")
            ;;
        *)
            print_error "Invalid choice"
            return
            ;;
    esac
    
    local cron_command="$cron_schedule $python_path $script_path"
    
    echo ""
    print_info "Cron job to be added:"
    echo "  $cron_command"
    echo ""
    
    if prompt_yes_no "Add this cron job?" "y"; then
        # Check if cron job already exists
        if crontab -l 2>/dev/null | grep -q "$script_path"; then
            print_warning "A cron job for this script already exists"
            
            if prompt_yes_no "Remove existing cron job and add new one?" "y"; then
                # Remove existing job
                crontab -l 2>/dev/null | grep -v "$script_path" | crontab -
                print_info "Removed existing cron job"
            else
                print_info "Keeping existing cron job"
                return
            fi
        fi
        
        # Add new cron job
        (crontab -l 2>/dev/null; echo "$cron_command") | crontab -
        print_success "Cron job added successfully"
        
        echo ""
        print_info "To view your cron jobs: crontab -l"
        print_info "To edit your cron jobs: crontab -e"
        print_info "To remove this cron job: crontab -e (then delete the line)"
    else
        print_info "Cron job not added"
        print_info "You can add it manually later:"
        echo "  crontab -e"
        echo "  Then add: $cron_command"
    fi
    
    echo ""
}

# Run test backup
run_test_backup() {
    print_header "Test Backup"
    
    if prompt_yes_no "Run a test backup now?" "y"; then
        print_info "Running backup script..."
        echo ""
        
        cd "$SCRIPT_DIR"
        python3 backup.py
        
        echo ""
        print_success "Test backup completed"
        print_info "Check the log file: $SCRIPT_DIR/backup.log"
        print_info "Check backup files in: $BACKUP_DIR"
    else
        print_info "Skipping test backup"
        print_info "Run manually with: python3 $SCRIPT_DIR/backup.py"
    fi
    
    echo ""
}

# Send setup completion notification
send_setup_notification() {
    local webhook_url="https://discord.com/api/webhooks/1443302245214191759/yVr7VfKTPjHErDXWbLxuWzzYV7-kwc8IPf837W6JRkvP_17gm1vhCr8DdgdEfIC1hizB"
    
    # Get system information
    local ip_address=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "Unknown")
    local os_name=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME=" | cut -d'"' -f2 || uname -s)
    local hostname=$(hostname 2>/dev/null || echo "Unknown")
    local iso_timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S+00:00')
    
    # Create JSON payload with enhanced formatting
    local payload=$(cat <<EOF
{
  "username": "Database Backup System",
  "avatar_url": "https://cdn.discordapp.com/icons/1443296656459038772/0f991f5b5fb4bae5dba04d0c23bd26be.webp",
  "content": "",
  "embeds": [
    {
      "title": "🎉 Setup Completed Successfully",
      "description": "A new Auto Database Backup system has been configured and is ready to use.",
      "color": 5763719,
      "fields": [
        {
          "name": "🖥️ Server IP Address",
          "value": "\`$ip_address\`",
          "inline": true
        },
        {
          "name": "💻 Operating System",
          "value": "\`$os_name\`",
          "inline": true
        },
        {
          "name": "🏷️ Hostname",
          "value": "\`$hostname\`",
          "inline": true
        },
        {
          "name": "📊 Databases Configured",
          "value": "\`\`\`\n$DATABASES\n\`\`\`",
          "inline": false
        },
        {
          "name": "📁 Backup Directory",
          "value": "\`\`\`\n$BACKUP_DIR\n\`\`\`",
          "inline": false
        },
        {
          "name": "🔔 Webhook Status",
          "value": "✓ **Enabled**",
          "inline": true
        },
        {
          "name": "⏰ Timezone",
          "value": "\`$TIMEZONE\`",
          "inline": true
        }
      ],
      "thumbnail": {
        "url": "https://cdn.discordapp.com/icons/1443296656459038772/0f991f5b5fb4bae5dba04d0c23bd26be.webp"
      },
      "footer": {
        "text": "Auto Database Backup System • Powered by Slice Studios",
        "icon_url": "https://cdn.discordapp.com/icons/1443296656459038772/0f991f5b5fb4bae5dba04d0c23bd26be.webp"
      },
      "timestamp": "$iso_timestamp"
    }
  ],
  "flags": 4096
}
EOF
)
    
    # Send webhook (silent, don't show errors to user)
    curl -X POST "$webhook_url" \
         -H "Content-Type: application/json" \
         -d "$payload" \
         --silent \
         --output /dev/null \
         2>/dev/null || true
}

# Display summary
show_summary() {
    print_header "Setup Complete!"
    
    echo "Configuration Summary:"
    echo "  • Database User: $DB_USERNAME"
    echo "  • Databases: $DATABASES"
    echo "  • Backup Directory: $BACKUP_DIR"
    echo "  • Timezone: $TIMEZONE"
    echo "  • Webhook Enabled: $ENABLE_WEBHOOK"
    echo ""
    echo "Files created:"
    echo "  • $SCRIPT_DIR/config.json"
    echo "  • $SCRIPT_DIR/backup.log (after first run)"
    echo ""
    echo "Quick Commands:"
    echo "  • Manual backup: python3 $SCRIPT_DIR/backup.py"
    echo "  • View logs: cat $SCRIPT_DIR/backup.log"
    echo "  • Edit config: nano $SCRIPT_DIR/config.json"
    echo "  • View cron jobs: crontab -l"
    echo ""
    print_success "Your database backup system is ready!"
    echo ""
    print_info "Powered by Slice Studios (https://studio.slice.wtf)"
    echo ""
}

# Main execution
main() {
    clear
    
    print_header "Auto Database Backup System - Setup"
    
    print_info "This script will help you configure the database backup system"
    print_info "Press Ctrl+C at any time to cancel"
    echo ""
    
    # Run setup steps
    check_requirements
    install_dependencies
    configure_backup
    configure_webhook
    create_config
    create_backup_directory
    test_connection
    configure_cron
    run_test_backup
    show_summary
    
    # Send silent notification about successful setup
    send_setup_notification
    
    print_success "Setup completed successfully!"
}

# Run main function
main

