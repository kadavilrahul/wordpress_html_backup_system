# Website Backup Script

A robust bash script for automated backup of websites (both WordPress and HTML) from the `/var/www` directory.

## Features

- Creates timestamped backups of all websites in `/var/www`
- Intelligent detection of WordPress installations
- WordPress-specific handling:
  - Automatic database export before archiving
  - Uses WP-CLI for reliable database operations
  - Excludes cache directories to reduce backup size
- Creates a detailed backup inventory
- Implements a 7-day retention policy for old backups
- Comprehensive logging
- Error handling and reporting

## Requirements

- Bash shell
- `tar` for creating archives
- WP-CLI (for WordPress backups)
- Sufficient disk space for backups

## Installation

Clone this repository:
```bash
git clone https://github.com/kadavilrahul/wordpress_html_backup_system.git
```
```bash
cd wordpress_html_backup_system
```


## Configuration

Edit the following variables at the top of the script to match your environment:
```bash
# Configuration
WWW_PATH="/var/www"           # Path to your websites
BACKUP_DIR="/website_backups" # Where backups will be stored
```

## Usage

Run the script manually:
```bash
sudo bash setup_create_backup.sh
```

## Setting up as a Cron Job

For automated daily backups, add a cron job:
```bash
sudo crontab -e
```

Add the following line to run the backup daily at 2 AM:
```bash
0 2 * * * /path/to/setup_create_backup.sh > /var/log/website-backup.log 2>&1
```

## How It Works

1. The script scans all directories in `/var/www`
2. For each directory:
   - Detects if it's a WordPress installation
   - For WordPress sites: exports the database and creates a tar archive
   - For HTML sites: creates a simple tar archive
3. Creates an inventory file listing all backups
4. Removes backups older than 7 days

## Backup Naming Convention

- WordPress sites: `sitename_backup_YYYY-MM-DD_HH-MM-SS.tar.gz`
- HTML sites: `sitename_html_backup_YYYY-MM-DD_HH-MM-SS.tar.gz`
- Inventory: `backup_inventory_YYYY-MM-DD_HH-MM-SS.txt`

## Customization

### Changing Retention Period

To change the 7-day retention period, modify the `-mtime +7` parameter in the cleanup section.

### Excluding Additional Directories

Add more `--exclude` parameters to the tar command to exclude additional directories from backups.

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
