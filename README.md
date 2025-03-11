# Website Backup Script

This script automates the backup process for websites, supporting both WordPress and custom HTML sites. It includes special handling for PostgreSQL database backup and specific website directories.

## Features

- Automated backup of WordPress sites including database
- Backup of static HTML sites
- PostgreSQL database backup
- Specific directory backup (data and public folders)
- Automatic cleanup of old backups (older than 7 days)
- Comprehensive error handling and logging
- Creates compressed archives (tar.gz for general backups, zip for specific website backup)

## Prerequisites

- Bash shell
- PostgreSQL client (pg_dump)
- WP-CLI (for WordPress sites)
- zip utility
- Sufficient disk space in backup location

## Configuration

Edit the following variables at the top of the script to match your environment:

### General Configuration
```bash
WWW_PATH="/var/www"              # Path to websites directory
BACKUP_DIR="/website_backups"    # Where backups will be stored
```

### Website Specific Configuration
```bash
WEBSITE_DOMAIN="example.com"     # Domain name of the website
WEBSITE_PATH="${WWW_PATH}/${WEBSITE_DOMAIN}"
TEMP_BACKUP_PREFIX="temp_backup"
```

### Database Configuration
```bash
DB_NAME="your_database"
DB_USER="your_user"
DB_PASSWORD="your_password"
```

## Usage

1. Make the script executable:
```bash
chmod +x setup_create_backup_01.sh
```

2. Run the script:
```bash
sudo ./setup_create_backup_01.sh
```

## Backup Types

### WordPress Sites
- Creates a full backup of WordPress files
- Exports WordPress database
- Excludes cache directories
- Creates compressed tar.gz archive

### HTML Sites
- Creates a full backup of site files
- Excludes cache directory
- Creates compressed tar.gz archive

### Specific Website Backup
- Creates PostgreSQL database dump
- Backs up specific directories (data and public)
- Combines everything into a single zip file

## Backup Location and Naming

- General backups: `/website_backups/[site_name]_backup_[timestamp].tar.gz`
- Website specific backup: `/website_backups/[domain]_full_backup_[timestamp].zip`
- Database dumps are temporarily stored and included in the final archive

## Automatic Cleanup

The script automatically:
- Removes backup files older than 7 days
- Cleans up temporary files after backup
- Removes temporary database dumps after they're archived

## Error Handling

- Comprehensive error checking for all critical operations
- Detailed logging with timestamps
- Script exits with helpful error messages if any operation fails

## Logs

The script logs all operations with timestamps in the following format:
```
[YYYY-MM-DD HH:MM:SS] Operation description
```

## Security Considerations

- Keep the script secure as it contains database credentials
- Run with appropriate permissions (usually root or web server user)
- Ensure backup directory is properly secured
- Consider encrypting sensitive backups

## Customization

To use for different websites:
1. Modify the WEBSITE_DOMAIN variable
2. Update database credentials as needed
3. Adjust backup paths if required
4. Modify retention period (currently 7 days) if needed
