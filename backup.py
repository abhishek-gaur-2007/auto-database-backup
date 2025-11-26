#!/usr/bin/env python3
"""
Automated MySQL/MariaDB Database Backup Script
Supports multiple databases, compression, and webhook notifications.

Copyright (c) 2025 Slice Studios (https://studio.slice.wtf)
Licensed under MIT License
"""

import os
import sys
import subprocess
import logging
from typing import List, Dict, Any, Optional

# Import utility functions
from utils import (
    setup_logging,
    load_config,
    get_timestamp,
    get_readable_timestamp,
    get_iso_timestamp,
    ensure_directory_exists,
    compress_to_targz,
    send_webhook,
    cleanup_file,
    format_size,
    get_file_size_mb,
    get_database_size,
    cleanup_old_backups,
    get_backup_count
)


class DatabaseBackup:
    """Main class for handling database backups."""
    
    def __init__(self, config_path: str = "config.json"):
        """
        Initialize the backup system.
        
        Args:
            config_path: Path to the configuration file
        """
        self.config_path = config_path
        self.config = None
        self.timezone = "UTC"
        
    def load_configuration(self) -> bool:
        """
        Load and validate configuration.
        
        Returns:
            True if configuration loaded successfully, False otherwise
        """
        try:
            self.config = load_config(self.config_path)
            self.timezone = self.config.get('timezone', 'UTC')
            logging.info("Configuration loaded successfully")
            return True
        except Exception as e:
            logging.error(f"Failed to load configuration: {str(e)}")
            return False
    
    def check_mysqldump(self) -> bool:
        """
        Check if mysqldump is available in the system.
        
        Returns:
            True if mysqldump is available, False otherwise
        """
        try:
            subprocess.run(
                ['mysqldump', '--version'],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True
            )
            logging.info("mysqldump is available")
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            logging.error("mysqldump is not available. Please install MySQL/MariaDB client.")
            return False
    
    def backup_database(self, database: str) -> Optional[str]:
        """
        Backup a single database using mysqldump.
        
        Args:
            database: Name of the database to backup
            
        Returns:
            Path to the backup file if successful, None otherwise
        """
        try:
            # Generate filename with timestamp
            timestamp = get_timestamp(self.timezone)
            filename = f"{database}-{timestamp}.sql"
            filepath = os.path.join(self.config['backup_directory'], filename)
            
            # Build mysqldump command with config options
            db_host = self.config.get('db_host', 'localhost')
            db_port = self.config.get('db_port', 3306)
            single_transaction = self.config.get('single_transaction', True)
            lock_tables = self.config.get('lock_tables', False)
            add_drop_database = self.config.get('add_drop_database', False)
            add_drop_table = self.config.get('add_drop_table', False)
            
            cmd = [
                'mysqldump',
                '-h', db_host,
                '-P', str(db_port),
                '-u', self.config['db_username'],
                f"-p{self.config['db_password']}",
                '--quick'
            ]
            
            if single_transaction:
                cmd.append('--single-transaction')
            
            if lock_tables:
                cmd.append('--lock-tables')
            else:
                cmd.append('--lock-tables=false')
            
            if add_drop_database:
                cmd.append('--add-drop-database')
            
            if add_drop_table:
                cmd.append('--add-drop-table')
            
            cmd.append(database)
            
            logging.info(f"Starting backup for database: {database}")
            
            # Execute mysqldump
            with open(filepath, 'w') as f:
                result = subprocess.run(
                    cmd,
                    stdout=f,
                    stderr=subprocess.PIPE,
                    text=True
                )
            
            if result.returncode != 0:
                error_msg = result.stderr
                logging.error(f"mysqldump failed for {database}: {error_msg}")
                cleanup_file(filepath)
                return None
            
            # Verify the backup file was created and has content
            if os.path.exists(filepath) and os.path.getsize(filepath) > 0:
                logging.info(f"Backup created successfully: {filepath}")
                return filepath
            else:
                logging.error(f"Backup file is empty or was not created: {filepath}")
                cleanup_file(filepath)
                return None
                
        except Exception as e:
            logging.error(f"Exception during backup of {database}: {str(e)}")
            return None
    
    def compress_backup(self, sql_file: str, database: str) -> Optional[str]:
        """
        Compress SQL backup to .tar.gz format and check size limits.
        
        Args:
            sql_file: Path to the SQL backup file
            database: Database name
            
        Returns:
            Path to the compressed file if successful, None otherwise
        """
        try:
            targz_file = f"{sql_file}.tar.gz"
            compression_level = self.config.get('compression_level', 6)
            
            # Compress with specified compression level
            if not compress_to_targz(sql_file, targz_file):
                return None
            
            # Check file size limit
            max_size_mb = self.config.get('max_file_size_in_mb', 1000)
            file_size_mb = get_file_size_mb(targz_file)
            
            if max_size_mb > 0 and file_size_mb > max_size_mb:
                # File exceeds maximum size
                formatted_size = format_size(int(file_size_mb * 1024 * 1024))
                error_msg = f"Backup file size ({formatted_size}) exceeds maximum allowed size ({max_size_mb}MB)"
                logging.error(error_msg)
                
                # Send error notification
                self.send_notification(
                    'error',
                    database,
                    filepath=targz_file,
                    error_message=error_msg
                )
                
                # Remove the oversized file
                cleanup_file(targz_file)
                cleanup_file(sql_file)
                return None
            
            # Remove original SQL file after successful compression
            cleanup_file(sql_file)
            
            logging.info(f"Compressed backup: {format_size(int(file_size_mb * 1024 * 1024))}")
            return targz_file
                
        except Exception as e:
            logging.error(f"Failed to compress {sql_file}: {str(e)}")
            return None
    
    def send_notification(self, notification_type: str, database: str, 
                         filepath: str = "N/A", error_message: str = "",
                         db_size: str = "N/A", file_size: str = "N/A") -> None:
        """
        Send webhook notification.
        
        Args:
            notification_type: Type of notification ('success', 'error', 'upload')
            database: Database name
            filepath: Path to the backup file
            error_message: Error message (for error notifications)
            db_size: Database size (formatted string)
            file_size: Backup file size (formatted string)
        """
        if not self.config.get('enable_webhook', False):
            logging.info("Webhook notifications are disabled")
            return
        
        webhook_url = self.config.get('webhook_url')
        if not webhook_url:
            logging.warning("Webhook URL not configured")
            return
        
        # Get template path
        template_paths = self.config.get('webhook_templates', {})
        template_path = template_paths.get(notification_type)
        
        if not template_path:
            logging.warning(f"No template configured for notification type: {notification_type}")
            return
        
        # Prepare replacements
        replacements = {
            'database': database,
            'filepath': filepath,
            'timestamp': get_readable_timestamp(self.timezone),
            'iso_timestamp': get_iso_timestamp(self.timezone),
            'status': notification_type.upper(),
            'error_message': error_message if error_message else "N/A",
            'db_size': db_size,
            'file_size': file_size
        }
        
        # Send webhook with or without file attachment
        file_to_upload = None
        if notification_type == 'upload' and os.path.exists(filepath):
            file_to_upload = filepath
        
        send_webhook(webhook_url, template_path, replacements, file_to_upload)
    
    def backup_all_databases(self) -> Dict[str, bool]:
        """
        Backup all configured databases.
        
        Returns:
            Dictionary mapping database names to success status
        """
        results = {}
        
        databases = self.config.get('databases', [])
        if not databases:
            logging.warning("No databases configured for backup")
            return results
        
        logging.info(f"Starting backup for {len(databases)} database(s)")
        
        for database in databases:
            logging.info(f"Processing database: {database}")
            
            try:
                # Get database size
                db_host = self.config.get('db_host', 'localhost')
                db_port = self.config.get('db_port', 3306)
                db_size_mb, db_size_formatted = get_database_size(
                    self.config['db_username'],
                    self.config['db_password'],
                    database,
                    db_host,
                    db_port
                )
                logging.info(f"Database size: {db_size_formatted}")
                
                # Backup the database
                sql_file = self.backup_database(database)
                
                if not sql_file:
                    # Backup failed
                    results[database] = False
                    self.send_notification(
                        'error',
                        database,
                        filepath=self.config['backup_directory'],
                        error_message="mysqldump failed or produced empty backup",
                        db_size=db_size_formatted
                    )
                    continue
                
                # Send success notification
                sql_size = format_size(os.path.getsize(sql_file))
                self.send_notification('success', database, sql_file, 
                                     db_size=db_size_formatted, file_size=sql_size)
                
                # Compress the backup
                targz_file = self.compress_backup(sql_file, database)
                
                if not targz_file:
                    # Compression failed or file too large (already handled in compress_backup)
                    results[database] = False
                    continue
                
                # Get compressed file size
                targz_size = format_size(os.path.getsize(targz_file))
                
                # Auto cleanup old backups
                auto_clean_after = self.config.get('auto_clean_after_x_files', 0)
                if auto_clean_after > 0:
                    current_count = get_backup_count(self.config['backup_directory'], database)
                    if current_count >= auto_clean_after:
                        deleted = cleanup_old_backups(
                            self.config['backup_directory'],
                            database,
                            auto_clean_after
                        )
                        if deleted > 0:
                            logging.info(f"Cleaned up {deleted} old backup(s) for {database}")
                
                # Send upload notification with the compressed file
                self.send_notification('upload', database, targz_file,
                                     db_size=db_size_formatted, file_size=targz_size)
                
                results[database] = True
                logging.info(f"Successfully backed up and compressed: {database}")
                
            except Exception as e:
                logging.error(f"Unexpected error backing up {database}: {str(e)}")
                results[database] = False
                self.send_notification(
                    'error',
                    database,
                    filepath=self.config.get('backup_directory', 'N/A'),
                    error_message=str(e)
                )
        
        return results
    
    def run(self) -> int:
        """
        Main execution method.
        
        Returns:
            Exit code (0 for success, 1 for failure)
        """
        # Setup logging
        setup_logging()
        
        logging.info("=" * 60)
        logging.info("Database Backup System Starting")
        logging.info("=" * 60)
        
        # Load configuration
        if not self.load_configuration():
            logging.error("Failed to load configuration. Exiting.")
            return 1
        
        # Check if mysqldump is available
        if not self.check_mysqldump():
            logging.error("mysqldump not found. Exiting.")
            return 1
        
        # Check and create backup directory
        backup_dir = self.config.get('backup_directory')
        if not ensure_directory_exists(backup_dir):
            error_msg = f"Cannot create or access backup directory: {backup_dir}"
            logging.error(error_msg)
            
            # Send error notification about directory issue
            self.send_notification(
                'error',
                'ALL',
                filepath=backup_dir,
                error_message=error_msg
            )
            
            logging.error("Backup process aborted due to directory error.")
            return 1
        
        # Perform backups
        results = self.backup_all_databases()
        
        # Summary
        successful = sum(1 for success in results.values() if success)
        total = len(results)
        
        logging.info("=" * 60)
        logging.info(f"Backup Summary: {successful}/{total} successful")
        logging.info("=" * 60)
        
        for database, success in results.items():
            status = "✓ SUCCESS" if success else "✗ FAILED"
            logging.info(f"  {database}: {status}")
        
        logging.info("=" * 60)
        logging.info("Database Backup System Finished")
        logging.info("=" * 60)
        
        return 0 if successful == total else 1


def main():
    """Entry point for the backup script."""
    config_file = "config.json"
    
    # Allow custom config file path as command line argument
    if len(sys.argv) > 1:
        config_file = sys.argv[1]
    
    backup_system = DatabaseBackup(config_file)
    exit_code = backup_system.run()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()

