#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPER_SCRIPTS_DIR="$SCRIPT_DIR"  # Helper scripts are in the same directory

# /website_backups/
# ├── wordpress/
# │   ├── domain.com_backup_*.tar.gz
# │   └── subdomain.domain.com_backup_*.tar.gz
# └── html_system/
#     ├── domain.com_html_*.tar.gz
#     ├── products_db_*.dump
#     └── manifest.txt


# Configuration Variables
DEST_SERVER_IP="157.180.40.177"
MAIN_DOMAIN="silkroademart.com"                      # e.g., silkroademart.com
SUBDOMAIN="wholesale"                                # e.g., wholesale
ADMIN_EMAIL="silkroademart@gmail.com"                # WordPress admin email
MYSQL_ROOT_PASSWORD="Karimpadam2@"                   # MySQL root password
BACKUP_PATH="/website_backups"                       # Path where backups are stored

# Status tracking file
STATUS_FILE="$SCRIPT_DIR/.migrate_status"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages with timestamps
log_message() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${1}"
}

# Function to log success messages
log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}${1}${NC}"
}

# Function to log warning messages
log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}WARNING: ${1}${NC}"
}

# Function to handle errors
error_exit() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR: ${1}${NC}" >&2
    exit 1
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate domain name
validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate email
validate_email() {
    local email=$1
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a step was completed
is_step_completed() {
    local step=$1
    [ -f "$STATUS_FILE" ] && grep -q "^$step:completed$" "$STATUS_FILE"
}

# Function to mark a step as completed
mark_step_completed() {
    local step=$1
    echo "$step:completed" >> "$STATUS_FILE"
}

# Function to ask user for step execution
ask_step() {
    local step=$1
    local description=$2
    
    if is_step_completed "$step"; then
        echo -e "\n${YELLOW}$description was previously completed.${NC}"
        read -p "Do you want to run it again? (y/N): " choice
        choice=${choice:-N}
    else
        echo -e "\n${GREEN}Preparing to execute: $description${NC}"
        read -p "Do you want to proceed? (Y/n): " choice
        choice=${choice:-Y}
    fi
    
    case "$choice" in
        [Yy]*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to get and validate configuration
get_config() {
    log_message "Loading configuration..."
    
    # Validate configuration
    if ! validate_ip "$DEST_SERVER_IP"; then
        error_exit "Invalid DEST_SERVER_IP in config file"
    fi
    
    if ! validate_domain "$MAIN_DOMAIN"; then
        error_exit "Invalid MAIN_DOMAIN in config file"
    fi
    
    if [ -n "$SUBDOMAIN" ] && ! [[ $SUBDOMAIN =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ ]]; then
        error_exit "Invalid SUBDOMAIN in config file"
    fi
    
    if ! validate_email "$ADMIN_EMAIL"; then
        error_exit "Invalid ADMIN_EMAIL in config file"
    fi
    
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        error_exit "MYSQL_ROOT_PASSWORD not set in config file"
    fi
    
    if [ -z "$BACKUP_PATH" ]; then
        BACKUP_PATH="/website_backups"
        log_warning "BACKUP_PATH not set in config file, using default: $BACKUP_PATH"
    fi
    
    # Display loaded configuration
    log_success "Configuration loaded successfully:"
    echo "Destination Server: $DEST_SERVER_IP"
    echo "Main Domain: $MAIN_DOMAIN"
    [ -n "$SUBDOMAIN" ] && echo "Subdomain: $SUBDOMAIN"
    echo "Admin Email: $ADMIN_EMAIL"
    echo "Backup Path: $BACKUP_PATH"
    
    mark_step_completed "config"
}

# Function to backup main domain WordPress
backup_main_domain() {
    if ask_step "backup_main" "Create Main Domain Backup"; then
        log_message "Starting main domain backup process..."
        
        # Create backup directory structure
        mkdir -p "$BACKUP_PATH/wordpress" || \
            error_exit "Failed to create backup directory structure"
        chmod 755 "$BACKUP_PATH" "$BACKUP_PATH/wordpress" || \
            error_exit "Failed to set backup directory permissions"
        
        # Export WordPress database and create backup
        cd "/var/www" && \
            wp db export "${MAIN_DOMAIN}_db.sql" --allow-root --path="${MAIN_DOMAIN}" && \
            tar czf "$BACKUP_PATH/wordpress/${MAIN_DOMAIN}_backup_$(date +%Y-%m-%d_%H-%M-%S).tar.gz" \
                --exclude='*/wp-content/cache' \
                --exclude='*/wp-content/wpo-cache' \
                --exclude='*/wp-content/uploads/cache' \
                --exclude='*/wp-content/plugins/*/cache' \
                -C "/var/www" "${MAIN_DOMAIN}" || \
            error_exit "Failed to backup WordPress main site"
            
        log_success "Main domain backup completed successfully"
        mark_step_completed "backup_main"
    else
        log_message "Skipping main domain backup"
    fi
}

# Function to backup subdomain WordPress
backup_subdomain() {
    if [ -n "$SUBDOMAIN" ] && ask_step "backup_subdomain" "Create Subdomain Backup"; then
        log_message "Starting subdomain backup process..."
        
        # Create backup directory if not exists
        mkdir -p "$BACKUP_PATH/wordpress" || \
            error_exit "Failed to create backup directory structure"
        chmod 755 "$BACKUP_PATH" "$BACKUP_PATH/wordpress" || \
            error_exit "Failed to set backup directory permissions"
        
        local subdomain_full="${SUBDOMAIN}.${MAIN_DOMAIN}"
        cd "/var/www" && \
            wp db export "${subdomain_full}_db.sql" --allow-root --path="${subdomain_full}" && \
            tar czf "$BACKUP_PATH/wordpress/${subdomain_full}_backup_$(date +%Y-%m-%d_%H-%M-%S).tar.gz" \
                --exclude='*/wp-content/cache' \
                --exclude='*/wp-content/wpo-cache' \
                --exclude='*/wp-content/uploads/cache' \
                --exclude='*/wp-content/plugins/*/cache' \
                -C "/var/www" "${subdomain_full}" || \
            error_exit "Failed to backup WordPress subdomain"
            
        log_success "Subdomain backup completed successfully"
        mark_step_completed "backup_subdomain"
    else
        log_message "Skipping subdomain backup"
    fi
}

# Function to backup HTML system
backup_html_system() {
    if ask_step "backup_html" "Create HTML System Backup"; then
        log_message "Starting HTML system backup process..."
        
        # Create backup directory
        mkdir -p "$BACKUP_PATH/html_system" || \
            error_exit "Failed to create backup directory structure"
        chmod 755 "$BACKUP_PATH/html_system" || \
            error_exit "Failed to set backup directory permissions"
        
        # Backup PostgreSQL database
        local pg_backup_file="$BACKUP_PATH/html_system/products_db_$(date +%Y-%m-%d_%H-%M-%S).dump"
        sudo -u postgres pg_dump -F c products_db -f "/var/lib/postgresql/products_db_temp.dump" || \
            error_exit "Failed to create PostgreSQL backup"
        sudo mv "/var/lib/postgresql/products_db_temp.dump" "$pg_backup_file" || \
            error_exit "Failed to move PostgreSQL backup"
        sudo chown root:root "$pg_backup_file" || \
            error_exit "Failed to set PostgreSQL backup permissions"
        
        # Backup HTML files
        cd "/var/www/${MAIN_DOMAIN}" && \
            tar czf "$BACKUP_PATH/html_system/${MAIN_DOMAIN}_html_$(date +%Y-%m-%d_%H-%M-%S).tar.gz" \
                -C "/var/www/${MAIN_DOMAIN}" public data || \
            error_exit "Failed to backup HTML files"
            
        # Create manifest
        cat > "$BACKUP_PATH/html_system/manifest.txt" << EOL
HTML System Backup
=================
Created: $(date '+%Y-%m-%d %H:%M:%S')

Components:
1. HTML Files
   - /var/www/${MAIN_DOMAIN}/public
   - /var/www/${MAIN_DOMAIN}/data

2. PostgreSQL Database
   - Database: products_db
   - Backup format: Custom (pg_dump -F c)
EOL
        
        log_success "HTML system backup completed successfully"
        mark_step_completed "backup_html"
    else
        log_message "Skipping HTML system backup"
    fi
}

# Function to create all backups
create_backups() {
    if ask_step "create_backups" "Create All Backups"; then
        log_message "Starting backup processes..."
        
        backup_main_domain
        backup_subdomain
        backup_html_system
        
        # Create backup summary
        cat > "$BACKUP_PATH/backup_summary.txt" << EOL
Backup Summary
=============
Created: $(date '+%Y-%m-%d %H:%M:%S')

1. WordPress System:
$(ls -l "$BACKUP_PATH/wordpress/")

2. HTML System with PostgreSQL:
$(ls -l "$BACKUP_PATH/html_system/")
EOL
        
        # Show backup summary
        log_success "All backups completed. Summary:"
        cat "$BACKUP_PATH/backup_summary.txt"
        
        mark_step_completed "create_backups"
    else
        log_message "Skipping all backups"
    fi
}

# Function to setup SSH keys
setup_ssh() {
    if ask_step "setup_ssh" "Setup SSH Keys"; then
        log_message "Setting up SSH access to destination server..."
        
        # Remove old host key if exists
        ssh-keygen -f '/root/.ssh/known_hosts' -R "$DEST_SERVER_IP" 2>/dev/null || true
        
        # Generate key pair if not exists
        if [ ! -f ~/.ssh/id_rsa ]; then
            ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N '' || \
                error_exit "Failed to generate SSH key"
        fi
        
        # Copy public key to destination server
        ssh-copy-id -i ~/.ssh/id_rsa.pub "root@$DEST_SERVER_IP" || \
            error_exit "Failed to copy SSH key to destination server"
        
        # Test connection
        if ssh -o BatchMode=yes "root@$DEST_SERVER_IP" 'echo test' >/dev/null 2>&1; then
            log_success "SSH key-based authentication configured successfully"
            mark_step_completed "setup_ssh"
        else
            error_exit "SSH key setup failed. Please check server connectivity"
        fi
    else
        log_message "Skipping SSH setup"
    fi
}

# Function to transfer main domain backup
transfer_main_domain() {
    if ask_step "transfer_main" "Transfer Main Domain Backup"; then
        log_message "Transferring main domain backup files..."
        
        # Create backup directory on destination
        ssh "root@$DEST_SERVER_IP" "mkdir -p $BACKUP_PATH/wordpress" || \
            error_exit "Failed to create backup directory on destination server"
        
        # Transfer main domain files
        rsync -avz --progress "$BACKUP_PATH/wordpress/${MAIN_DOMAIN}_backup_"* "root@$DEST_SERVER_IP:$BACKUP_PATH/wordpress/" || \
            error_exit "Failed to transfer main domain backup files"
        
        log_success "Main domain backup files transferred successfully"
        mark_step_completed "transfer_main"
    else
        log_message "Skipping main domain backup transfer"
    fi
}

# Function to transfer subdomain backup
transfer_subdomain() {
    if [ -n "$SUBDOMAIN" ] && ask_step "transfer_subdomain" "Transfer Subdomain Backup"; then
        log_message "Transferring subdomain backup files..."
        
        local subdomain_full="${SUBDOMAIN}.${MAIN_DOMAIN}"
        
        # Create backup directory on destination
        ssh "root@$DEST_SERVER_IP" "mkdir -p $BACKUP_PATH/wordpress" || \
            error_exit "Failed to create backup directory on destination server"
        
        # Transfer subdomain files
        rsync -avz --progress "$BACKUP_PATH/wordpress/${subdomain_full}_backup_"* "root@$DEST_SERVER_IP:$BACKUP_PATH/wordpress/" || \
            error_exit "Failed to transfer subdomain backup files"
        
        log_success "Subdomain backup files transferred successfully"
        mark_step_completed "transfer_subdomain"
    else
        log_message "Skipping subdomain backup transfer"
    fi
}

# Function to transfer HTML system backup
transfer_html_system() {
    if ask_step "transfer_html" "Transfer HTML System Backup"; then
        log_message "Transferring HTML system backup files..."
        
        # Create backup directory on destination
        ssh "root@$DEST_SERVER_IP" "mkdir -p $BACKUP_PATH/html_system" || \
            error_exit "Failed to create backup directory on destination server"
        
        # Transfer HTML system files
        rsync -avz --progress "$BACKUP_PATH/html_system/" "root@$DEST_SERVER_IP:$BACKUP_PATH/html_system/" || \
            error_exit "Failed to transfer HTML system backup files"
        
        log_success "HTML system backup files transferred successfully"
        mark_step_completed "transfer_html"
    else
        log_message "Skipping HTML system backup transfer"
    fi
}

# Function to transfer all backups
transfer_backups() {
    if ask_step "transfer_backups" "Transfer All Backup Files"; then
        log_message "Starting backup file transfers..."
        
        transfer_main_domain
        transfer_subdomain
        transfer_html_system
        
        # Verify transfer
        local source_files=$(find "$BACKUP_PATH" -type f | sort)
        local dest_files=$(ssh "root@$DEST_SERVER_IP" "find $BACKUP_PATH -type f | sort")
        
        if [ "$source_files" = "$dest_files" ]; then
            log_success "All backup files transferred successfully"
            mark_step_completed "transfer_backups"
        else
            error_exit "Backup file transfer verification failed"
        fi
    else
        log_message "Skipping backup transfers"
    fi
}

# Function to transfer helper scripts
transfer_helper_scripts() {
    if ask_step "transfer_scripts" "Transfer Helper Scripts"; then
        log_message "Transferring helper scripts to destination server..."
        
        # List of helper scripts to transfer
        local scripts=(
            "install_lamp.sh"
            "setup_wordpress_main_domain.sh"
            "setup_wordpress_subdomain.sh"
            "create_postgres.sh"
        )
        
        # Create scripts directory on destination
        ssh "root@$DEST_SERVER_IP" "mkdir -p /root/scripts" || \
            error_exit "Failed to create scripts directory on destination server"
        
        # Transfer each script
        for script in "${scripts[@]}"; do
            log_message "Transferring $script..."
            scp "${HELPER_SCRIPTS_DIR}/$script" "root@$DEST_SERVER_IP:/root/scripts/" || \
                error_exit "Failed to transfer $script"
        done
        
        # Make scripts executable
        ssh "root@$DEST_SERVER_IP" "chmod +x /root/scripts/*.sh" || \
            error_exit "Failed to make scripts executable"
        
        log_success "Helper scripts transferred successfully"
        mark_step_completed "transfer_scripts"
    else
        log_message "Skipping helper scripts transfer"
    fi
}

# Function to setup destination server
setup_destination() {
    if ask_step "setup_destination" "Setup Destination Server"; then
        log_message "Setting up destination server..."
        
        # Install LAMP stack
        ssh "root@$DEST_SERVER_IP" "bash /root/scripts/install_lamp.sh" || \
            error_exit "Failed to install LAMP stack"
        
        # Install WP-CLI
        ssh "root@$DEST_SERVER_IP" "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
            chmod +x wp-cli.phar && \
            mv wp-cli.phar /usr/local/bin/wp" || \
            error_exit "Failed to install WP-CLI"
        
        # Setup WordPress
        ssh "root@$DEST_SERVER_IP" "echo -e '$MAIN_DOMAIN\n$ADMIN_EMAIL\n$MYSQL_ROOT_PASSWORD' | bash /root/scripts/setup_wordpress_main_domain.sh" || \
            error_exit "Failed to setup main domain WordPress"
        
        if [ -n "$SUBDOMAIN" ]; then
            ssh "root@$DEST_SERVER_IP" "echo -e '$MAIN_DOMAIN\n$SUBDOMAIN\n$ADMIN_EMAIL\n$MYSQL_ROOT_PASSWORD' | bash /root/scripts/setup_wordpress_subdomain.sh" || \
                error_exit "Failed to setup subdomain WordPress"
        fi
        
        # Setup PostgreSQL
        ssh "root@$DEST_SERVER_IP" "bash /root/scripts/create_postgres.sh" || \
            error_exit "Failed to setup PostgreSQL"
        
        log_success "Destination server setup completed"
        mark_step_completed "setup_destination"
    else
        log_message "Skipping destination server setup"
    fi
}

# Function to handle WordPress post-restore tasks
handle_wp_post_restore() {
    local wp_path=$1
    log_message "Handling post-restore tasks for $wp_path..."
    
    # Set correct permissions
    log_message "Setting correct permissions for wp-content..."
    ssh "root@$DEST_SERVER_IP" "chown -R www-data:www-data $wp_path/wp-content" || \
        error_exit "Failed to set permissions for wp-content in $wp_path"
    
    # Handle Redis plugin issue
    local redis_cache_file="$wp_path/wp-content/object-cache.php"
    ssh "root@$DEST_SERVER_IP" "if [ -f '$redis_cache_file' ]; then \
        echo 'Redis object-cache.php file detected. Deleting to disable Redis...'; \
        rm -f '$redis_cache_file' || exit 1; \
        echo 'Redis object-cache.php file deleted successfully.'; \
    else \
        echo 'No Redis object-cache.php file found. Skipping Redis handling.'; \
    fi" || error_exit "Failed to handle Redis cache file in $wp_path"
    
    log_success "Post-restore tasks completed for $wp_path"
}

# Function to restore main domain WordPress
restore_main_domain() {
    log_message "Restoring main WordPress site..."
    
    # Find latest WordPress backup
    local main_wp_backup=$(ssh "root@$DEST_SERVER_IP" "ls -t $BACKUP_PATH/wordpress/${MAIN_DOMAIN}_backup_*.tar.gz | head -1")
    if [ -z "$main_wp_backup" ]; then
        error_exit "No WordPress backup found for main domain"
    fi
    
    # Show backup file
    echo -e "\nWill use the following backup file:"
    echo "Main domain backup: $(basename "$main_wp_backup")"
    read -p "Continue with this file? (Y/n): " choice
    choice=${choice:-Y}
    [[ $choice =~ ^[Yy] ]] || return
    
    # Extract and restore main WordPress site
    ssh "root@$DEST_SERVER_IP" "cd /var/www && \
        rm -rf ${MAIN_DOMAIN} && \
        tar xzf $main_wp_backup && \
        if [ -f ${MAIN_DOMAIN}/${MAIN_DOMAIN}_db.sql ]; then \
            wp db reset --yes --allow-root --path=/var/www/${MAIN_DOMAIN} && \
            wp db import ${MAIN_DOMAIN}/${MAIN_DOMAIN}_db.sql --allow-root --path=/var/www/${MAIN_DOMAIN} && \
            rm ${MAIN_DOMAIN}/${MAIN_DOMAIN}_db.sql; \
        else \
            echo 'SQL file not found for main domain'; \
            exit 1; \
        fi" || error_exit "Failed to restore main WordPress site"
    
    # Handle permissions and Redis
    handle_wp_post_restore "/var/www/${MAIN_DOMAIN}"
    
    log_success "Main domain WordPress restored successfully"
}

# Function to fix WordPress configuration
fix_wp_config() {
    local wp_path=$1
    local site_url=$2
    log_message "Fixing WordPress configuration for $site_url..."
    
    ssh "root@$DEST_SERVER_IP" "cd $wp_path && \
        # Update site and home URLs
        wp option update home 'https://$site_url' --allow-root && \
        wp option update siteurl 'https://$site_url' --allow-root && \
        
        # Disable debug mode and enable error logging
        wp config set WP_DEBUG false --allow-root && \
        wp config set WP_DEBUG_LOG true --allow-root && \
        wp config set WP_DEBUG_DISPLAY false --allow-root && \
        
        # Reset permalinks
        wp rewrite flush --allow-root && \
        
        # Clear all caches
        wp cache flush --allow-root && \
        
        # Deactivate and reactivate all plugins
        wp plugin deactivate --all --allow-root && \
        wp plugin activate --all --allow-root" || \
        error_exit "Failed to fix WordPress configuration for $site_url"
    
    log_success "WordPress configuration fixed for $site_url"
}

# Function to restore subdomain WordPress
restore_subdomain() {
    if [ -n "$SUBDOMAIN" ]; then
        local subdomain_full="${SUBDOMAIN}.${MAIN_DOMAIN}"
        local subdomain_backup=$(ssh "root@$DEST_SERVER_IP" "ls -t $BACKUP_PATH/wordpress/${subdomain_full}_backup_*.tar.gz | head -1")
        
        if [ -n "$subdomain_backup" ]; then
            log_message "Restoring WordPress subdomain..."
            
            # Show backup file
            echo -e "\nWill use the following backup file:"
            echo "Subdomain backup: $(basename "$subdomain_backup")"
            read -p "Continue with this file? (Y/n): " choice
            choice=${choice:-Y}
            [[ $choice =~ ^[Yy] ]] || return
            
            # Extract and restore subdomain
            ssh "root@$DEST_SERVER_IP" "cd /var/www && \
                echo 'Removing old subdomain directory...' && \
                rm -rf ${subdomain_full} && \
                echo 'Extracting backup...' && \
                tar xzf $subdomain_backup && \
                echo 'Checking extracted files...' && \
                ls -la ${subdomain_full}/ && \
                if [ -f ${subdomain_full}/${subdomain_full}_db.sql ]; then \
                    echo 'Resetting database...' && \
                    wp db reset --yes --allow-root --path=/var/www/${subdomain_full} && \
                    echo 'Importing database...' && \
                    wp db import ${subdomain_full}/${subdomain_full}_db.sql --allow-root --path=/var/www/${subdomain_full} && \
                    rm ${subdomain_full}/${subdomain_full}_db.sql; \
                else \
                    echo 'SQL file not found for subdomain'; \
                    exit 1; \
                fi && \
                
                # Verify WordPress files
                echo 'Verifying WordPress files...' && \
                test -f ${subdomain_full}/wp-config.php || exit 1 && \
                test -d ${subdomain_full}/wp-content || exit 1" || error_exit "Failed to restore WordPress subdomain"
            
            # Handle permissions and Redis
            handle_wp_post_restore "/var/www/${subdomain_full}"
            
            # Fix WordPress configuration
            fix_wp_config "/var/www/${subdomain_full}" "${subdomain_full}"
            
            # Verify the site is working
            log_message "Verifying subdomain WordPress installation..."
            ssh "root@$DEST_SERVER_IP" "cd /var/www/${subdomain_full} && \
                wp core verify-checksums --allow-root && \
                wp db check --allow-root && \
                wp core is-installed --allow-root" || \
                error_exit "WordPress verification failed for subdomain"
            
            log_success "Subdomain WordPress restored successfully"
        else
            log_warning "No backup found for subdomain"
        fi
    fi
}

# Function to restore backups
restore_backups() {
    if ask_step "restore_backups" "Restore Backups"; then
        log_message "Starting backup restoration..."
        
        # 1. Restore WordPress Systems
        if ask_step "restore_main" "Restore Main Domain WordPress"; then
            restore_main_domain
            mark_step_completed "restore_main"
        else
            log_message "Skipping main domain restoration"
        fi
        
        if [ -n "$SUBDOMAIN" ] && ask_step "restore_subdomain" "Restore Subdomain WordPress"; then
            restore_subdomain
            mark_step_completed "restore_subdomain"
        fi
        
        # 2. Restore HTML System with PostgreSQL
        if ask_step "restore_html" "Restore HTML System"; then
            log_message "Restoring HTML system with PostgreSQL..."
            
            # Find latest HTML and PostgreSQL backups
            local html_backup=$(ssh "root@$DEST_SERVER_IP" "ls -t $BACKUP_PATH/html_system/${MAIN_DOMAIN}_html_*.tar.gz | head -1")
            local postgres_backup=$(ssh "root@$DEST_SERVER_IP" "ls -t $BACKUP_PATH/html_system/products_db_*.dump | head -1")
            
            # Show backup files
            [ -n "$html_backup" ] && echo "HTML backup: $(basename "$html_backup")"
            [ -n "$postgres_backup" ] && echo "PostgreSQL backup: $(basename "$postgres_backup")"
            read -p "Continue with these files? (Y/n): " choice
            choice=${choice:-Y}
            [[ $choice =~ ^[Yy] ]] || return
            
            # Restore HTML files
            if [ -n "$html_backup" ]; then
                log_message "Restoring HTML files..."
                ssh "root@$DEST_SERVER_IP" "cd /var/www/${MAIN_DOMAIN} && \
                    rm -rf public data && \
                    tar xzf $html_backup" || \
                    error_exit "Failed to restore HTML files"
            else
                log_warning "No HTML backup found"
            fi
            
            # Restore PostgreSQL database
            if [ -n "$postgres_backup" ]; then
                log_message "Restoring PostgreSQL database..."
                ssh "root@$DEST_SERVER_IP" "systemctl start postgresql && \
                    sudo -u postgres psql -c 'DROP DATABASE IF EXISTS products_db;' && \
                    sudo -u postgres psql -c 'CREATE DATABASE products_db;' && \
                    sudo -u postgres pg_restore -d products_db $postgres_backup" || \
                    error_exit "Failed to restore PostgreSQL database"
            else
                log_warning "No PostgreSQL backup found"
            fi
            
            mark_step_completed "restore_html"
        else
            log_message "Skipping HTML system restoration"
        fi
        
        # Set proper permissions
        log_message "Setting proper permissions..."
        ssh "root@$DEST_SERVER_IP" "chown -R www-data:www-data /var/www/${MAIN_DOMAIN} && \
            [ -n \"$SUBDOMAIN\" ] && chown -R www-data:www-data /var/www/${SUBDOMAIN}.${MAIN_DOMAIN}" || \
            error_exit "Failed to set permissions"
        
        log_success "Backup restoration completed"
        mark_step_completed "restore_backups"
    else
        log_message "Skipping backup restoration"
    fi
}

# Function to verify migration
verify_migration() {
    if ask_step "verify_migration" "Verify Migration"; then
        log_message "Verifying migration..."
        
        # Check Apache status
        log_message "Checking Apache status..."
        ssh "root@$DEST_SERVER_IP" "systemctl is-active apache2" || \
            error_exit "Apache is not running"
        
        # Check PostgreSQL status
        log_message "Checking PostgreSQL status..."
        ssh "root@$DEST_SERVER_IP" "systemctl is-active postgresql" || \
            error_exit "PostgreSQL is not running"
        
        # Check WordPress files
        log_message "Checking WordPress files..."
        ssh "root@$DEST_SERVER_IP" "test -f /var/www/${MAIN_DOMAIN}/wp-config.php" || \
            error_exit "WordPress files not found"
        
        # Check database connectivity
        log_message "Checking database connectivity..."
        ssh "root@$DEST_SERVER_IP" "cd /var/www/${MAIN_DOMAIN} && wp db check --allow-root" || \
            error_exit "WordPress database check failed"
        
        # Check HTML system files
        log_message "Checking HTML system files..."
        ssh "root@$DEST_SERVER_IP" "test -d /var/www/${MAIN_DOMAIN}/public && \
            test -d /var/www/${MAIN_DOMAIN}/data" || \
            error_exit "HTML system files not found"
        
        # Check PostgreSQL database
        log_message "Checking PostgreSQL database..."
        ssh "root@$DEST_SERVER_IP" "sudo -u postgres psql -l | grep products_db" || \
            error_exit "PostgreSQL database not found"
        
        log_success "Migration verification completed"
        mark_step_completed "verify_migration"
    else
        log_message "Skipping migration verification"
    fi
}

# Main execution
main() {
    log_message "Starting migration process"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then 
        error_exit "Please run as root"
    fi
    
    # Execute steps in sequence
    get_config
    
    # Backup steps
    backup_main_domain
    backup_subdomain
    backup_html_system
    
    # SSH and transfer steps
    setup_ssh
    transfer_helper_scripts
    transfer_main_domain
    transfer_subdomain
    transfer_html_system
    
    # Setup and restore steps
    setup_destination
    restore_backups
    verify_migration
    
    log_success "Migration completed successfully!"
    
    # Print important information
    echo -e "\n${GREEN}Migration Summary:${NC}"
    echo "Destination Server: $DEST_SERVER_IP"
    echo "Main Domain: $MAIN_DOMAIN"
    [ -n "$SUBDOMAIN" ] && echo "Subdomain: $SUBDOMAIN"
    echo -e "\nPlease verify the following manually:"
    echo "1. WordPress site functionality"
    echo "2. HTML system functionality"
    echo "3. PostgreSQL database content"
    echo "4. File permissions"
    echo "5. Service status"
}

# Execute main function
main
