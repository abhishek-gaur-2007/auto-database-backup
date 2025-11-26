#!/usr/bin/env python3
"""
Utility functions for the database backup system.

Copyright (c) 2025 Slice Studios (https://studio.slice.wtf)
Licensed under MIT License
"""

import os
import json
import logging
import tarfile
import requests
from datetime import datetime
from typing import Dict, Any, Optional
import pytz

# Discord webhook file size limit (10MB)
MAX_WEBHOOK_FILE_SIZE = 10 * 1024 * 1024  # 10MB in bytes


def setup_logging(log_file: str = "backup.log") -> None:
    """
    Configure logging for the backup system.
    
    Args:
        log_file: Path to the log file
    """
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )


def load_config(config_path: str = "config.json") -> Dict[str, Any]:
    """
    Load configuration from JSON file.
    
    Args:
        config_path: Path to the configuration file
        
    Returns:
        Dictionary containing configuration settings
        
    Raises:
        FileNotFoundError: If config file doesn't exist
        json.JSONDecodeError: If config file is invalid JSON
    """
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"Configuration file not found: {config_path}")
    
    with open(config_path, 'r') as f:
        config = json.load(f)
    
    # Validate required fields
    required_fields = ['db_username', 'db_password', 'databases', 'backup_directory', 'timezone']
    missing_fields = [field for field in required_fields if field not in config]
    
    if missing_fields:
        raise ValueError(f"Missing required configuration fields: {', '.join(missing_fields)}")
    
    return config


def get_timestamp(timezone: str = "UTC") -> str:
    """
    Get current timestamp formatted for backup filename.
    
    Args:
        timezone: Timezone string (e.g., 'UTC', 'America/New_York')
        
    Returns:
        Formatted timestamp string (dd-mm-yyyy-hh-mm-ss)
    """
    try:
        tz = pytz.timezone(timezone)
    except pytz.exceptions.UnknownTimeZoneError:
        logging.warning(f"Unknown timezone '{timezone}', defaulting to UTC")
        tz = pytz.UTC
    
    now = datetime.now(tz)
    return now.strftime("%d-%m-%Y-%H-%M-%S")


def get_readable_timestamp(timezone: str = "UTC") -> str:
    """
    Get current timestamp in human-readable format.
    
    Args:
        timezone: Timezone string
        
    Returns:
        Formatted timestamp string for webhook messages
    """
    try:
        tz = pytz.timezone(timezone)
    except pytz.exceptions.UnknownTimeZoneError:
        tz = pytz.UTC
    
    now = datetime.now(tz)
    return now.strftime("%Y-%m-%d %H:%M:%S %Z")


def ensure_directory_exists(directory: str) -> bool:
    """
    Check if directory exists and create it if it doesn't.
    
    Args:
        directory: Path to the directory
        
    Returns:
        True if directory exists or was created successfully, False otherwise
    """
    if os.path.exists(directory):
        if not os.path.isdir(directory):
            logging.error(f"Path exists but is not a directory: {directory}")
            return False
        logging.info(f"Backup directory exists: {directory}")
        return True
    
    try:
        os.makedirs(directory, exist_ok=True)
        logging.info(f"Created backup directory: {directory}")
        return True
    except PermissionError:
        logging.error(f"Permission denied: Cannot create directory {directory}")
        return False
    except Exception as e:
        logging.error(f"Failed to create directory {directory}: {str(e)}")
        return False


def compress_to_targz(source_file: str, output_file: str) -> bool:
    """
    Compress a file to .tar.gz format.
    
    Args:
        source_file: Path to the source file
        output_file: Path to the output .tar.gz file
        
    Returns:
        True if compression was successful, False otherwise
    """
    try:
        with tarfile.open(output_file, "w:gz") as tar:
            tar.add(source_file, arcname=os.path.basename(source_file))
        logging.info(f"Compressed {source_file} to {output_file}")
        return True
    except Exception as e:
        logging.error(f"Failed to compress {source_file}: {str(e)}")
        return False


def load_webhook_template(template_path: str) -> Optional[Dict[str, Any]]:
    """
    Load webhook template from JSON file.
    
    Args:
        template_path: Path to the webhook template file
        
    Returns:
        Dictionary containing webhook template or None if loading fails
    """
    try:
        if not os.path.exists(template_path):
            logging.error(f"Webhook template not found: {template_path}")
            return None
        
        with open(template_path, 'r') as f:
            template = json.load(f)
        return template
    except Exception as e:
        logging.error(f"Failed to load webhook template {template_path}: {str(e)}")
        return None


def replace_placeholders(template: Dict[str, Any], replacements: Dict[str, str]) -> Dict[str, Any]:
    """
    Replace placeholders in webhook template with actual values.
    
    Args:
        template: Webhook template dictionary
        replacements: Dictionary of placeholder replacements
        
    Returns:
        Updated template with placeholders replaced
    """
    import copy
    
    def replace_in_value(value):
        if isinstance(value, str):
            for placeholder, replacement in replacements.items():
                value = value.replace(f"{{{{{placeholder}}}}}", str(replacement))
            return value
        elif isinstance(value, dict):
            return {k: replace_in_value(v) for k, v in value.items()}
        elif isinstance(value, list):
            return [replace_in_value(item) for item in value]
        else:
            return value
    
    return replace_in_value(copy.deepcopy(template))


def send_webhook(webhook_url: str, template_path: str, replacements: Dict[str, str], 
                 file_path: Optional[str] = None) -> bool:
    """
    Send a webhook notification with optional file attachment.
    Discord has a 10MB file size limit for webhooks.
    
    Args:
        webhook_url: Discord webhook URL
        template_path: Path to the webhook template JSON file
        replacements: Dictionary of placeholder replacements
        file_path: Optional path to file to attach
        
    Returns:
        True if webhook was sent successfully, False otherwise
    """
    try:
        template = load_webhook_template(template_path)
        if not template:
            return False
        
        payload = replace_placeholders(template, replacements)
        
        if file_path and os.path.exists(file_path):
            # Check file size before attempting upload
            file_size = os.path.getsize(file_path)
            file_size_mb = file_size / (1024 * 1024)
            
            if file_size > MAX_WEBHOOK_FILE_SIZE:
                # File is too large for Discord webhook
                logging.warning(f"File size ({file_size_mb:.2f}MB) exceeds Discord webhook limit (10MB): {file_path}")
                logging.info("Sending notification without file attachment")
                
                # Send notification without file, but include file size info
                size_warning = f" (File size: {file_size_mb:.2f}MB - Too large to upload via webhook, max 10MB)"
                payload = replace_placeholders(template, {
                    **replacements,
                    'filepath': replacements.get('filepath', 'N/A') + size_warning
                })
                
                response = requests.post(
                    webhook_url,
                    json=payload,
                    headers={'Content-Type': 'application/json'}
                )
                
                if response.status_code in [200, 204]:
                    logging.info("Webhook sent successfully (without file attachment due to size)")
                    logging.error(f"Cannot upload file to webhook: File size ({file_size_mb:.2f}MB) exceeds 10MB limit")
                    return True
                else:
                    logging.error(f"Webhook failed with status {response.status_code}: {response.text}")
                    return False
            else:
                # File size is acceptable, send with attachment
                logging.info(f"Uploading file via webhook ({file_size_mb:.2f}MB)")
                with open(file_path, 'rb') as f:
                    files = {
                        'file': (os.path.basename(file_path), f),
                        'payload_json': (None, json.dumps(payload))
                    }
                    response = requests.post(webhook_url, files=files)
        else:
            # Send without file attachment
            response = requests.post(
                webhook_url,
                json=payload,
                headers={'Content-Type': 'application/json'}
            )
        
        if response.status_code in [200, 204]:
            logging.info(f"Webhook sent successfully to {webhook_url}")
            return True
        else:
            logging.error(f"Webhook failed with status {response.status_code}: {response.text}")
            return False
            
    except Exception as e:
        logging.error(f"Failed to send webhook: {str(e)}")
        return False


def cleanup_file(file_path: str) -> None:
    """
    Delete a file if it exists.
    
    Args:
        file_path: Path to the file to delete
    """
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
            logging.info(f"Cleaned up temporary file: {file_path}")
    except Exception as e:
        logging.warning(f"Failed to cleanup file {file_path}: {str(e)}")

