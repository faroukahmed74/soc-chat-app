#!/bin/bash

# =============================================================================
# SOC Chat App - MongoDB Backup Script
# =============================================================================
# This script creates automated backups of the MongoDB database
# Usage: ./backup_database.sh [options]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_BACKUP_DIR="/backup"
DEFAULT_MONGO_URI="mongodb://admin:SecurePassword123!@localhost:27017/soc_chat_app?authSource=admin"
DEFAULT_RETENTION_DAYS=30
DEFAULT_COMPRESSION=true

# Configuration variables
BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
MONGO_URI="${MONGO_URI:-$DEFAULT_MONGO_URI}"
RETENTION_DAYS="${RETENTION_DAYS:-$DEFAULT_RETENTION_DAYS}"
COMPRESSION="${COMPRESSION:-$DEFAULT_COMPRESSION}"
VERBOSE=false
DRY_RUN=false

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
}

print_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1"
    fi
}

# Function to show help
show_help() {
    print_header "SOC Chat App - MongoDB Backup Script Help"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --dir DIR          Backup directory (default: $DEFAULT_BACKUP_DIR)"
    echo "  -u, --uri URI          MongoDB connection URI"
    echo "  -r, --retention DAYS   Retention period in days (default: $DEFAULT_RETENTION_DAYS)"
    echo "  -c, --compress         Enable compression (default: enabled)"
    echo "  -n, --no-compress      Disable compression"
    echo "  -v, --verbose          Enable verbose output"
    echo "  --dry-run              Show what would be done without executing"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  BACKUP_DIR            Backup directory path"
    echo "  MONGO_URI             MongoDB connection URI"
    echo "  RETENTION_DAYS        Retention period in days"
    echo "  COMPRESSION           Enable/disable compression (true/false)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Default backup"
    echo "  $0 --dir /custom/backup              # Custom backup directory"
    echo "  $0 --retention 7                     # Keep backups for 7 days"
    echo "  $0 --no-compress                     # Disable compression"
    echo "  $0 --verbose --dry-run               # Verbose dry run"
    echo ""
    echo "Cron Example (daily backup at 2 AM):"
    echo "  0 2 * * * /path/to/backup_database.sh"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -u|--uri)
            MONGO_URI="$2"
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESSION=true
            shift
            ;;
        -n|--no-compress)
            COMPRESSION=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if mongodump is available
    if ! command -v mongodump &> /dev/null; then
        print_error "mongodump is not installed or not in PATH"
        echo "Please install MongoDB tools:"
        echo "  - Ubuntu/Debian: sudo apt-get install mongodb-database-tools"
        echo "  - CentOS/RHEL: sudo yum install mongodb-database-tools"
        echo "  - macOS: brew install mongodb-database-tools"
        echo "  - Windows: Download from https://www.mongodb.com/try/download/database-tools"
        exit 1
    fi
    
    print_verbose "mongodump version: $(mongodump --version | head -1)"
    
    # Check if backup directory exists or can be created
    if [ ! -d "$BACKUP_DIR" ]; then
        if [ "$DRY_RUN" = true ]; then
            print_status "Would create backup directory: $BACKUP_DIR"
        else
            print_status "Creating backup directory: $BACKUP_DIR"
            mkdir -p "$BACKUP_DIR"
        fi
    fi
    
    # Check write permissions
    if [ ! -w "$BACKUP_DIR" ]; then
        print_error "No write permission for backup directory: $BACKUP_DIR"
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Function to test MongoDB connection
test_mongo_connection() {
    print_status "Testing MongoDB connection..."
    
    if [ "$DRY_RUN" = true ]; then
        print_status "Would test connection to: $MONGO_URI"
        return 0
    fi
    
    # Test connection with mongosh (if available) or mongo
    if command -v mongosh &> /dev/null; then
        if mongosh "$MONGO_URI" --eval "db.adminCommand('ping')" --quiet &> /dev/null; then
            print_status "MongoDB connection successful"
            return 0
        fi
    elif command -v mongo &> /dev/null; then
        if mongo "$MONGO_URI" --eval "db.adminCommand('ping')" --quiet &> /dev/null; then
            print_status "MongoDB connection successful"
            return 0
        fi
    else
        print_warning "Neither mongosh nor mongo client found, skipping connection test"
        return 0
    fi
    
    print_error "MongoDB connection failed"
    return 1
}

# Function to create backup
create_backup() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_name="soc_chat_app_backup_$timestamp"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    print_header "Creating MongoDB Backup"
    print_status "Backup name: $backup_name"
    print_status "Backup path: $backup_path"
    print_status "MongoDB URI: $MONGO_URI"
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would create backup at $backup_path"
        if [ "$COMPRESSION" = true ]; then
            print_status "DRY RUN: Would compress backup"
        fi
        return 0
    fi
    
    # Create backup
    print_status "Starting backup..."
    local start_time=$(date +%s)
    
    if mongodump --uri="$MONGO_URI" --out="$backup_path" --quiet; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_status "✅ Backup completed successfully in ${duration}s"
        
        # Get backup size
        local backup_size=$(du -sh "$backup_path" | cut -f1)
        print_status "Backup size: $backup_size"
        
        # Compress if enabled
        if [ "$COMPRESSION" = true ]; then
            compress_backup "$backup_path"
        fi
        
        # Create backup info file
        create_backup_info "$backup_path" "$backup_size" "$duration"
        
        return 0
    else
        print_error "❌ Backup failed"
        return 1
    fi
}

# Function to compress backup
compress_backup() {
    local backup_path="$1"
    
    print_status "Compressing backup..."
    local start_time=$(date +%s)
    
    if tar -czf "${backup_path}.tar.gz" -C "$(dirname "$backup_path")" "$(basename "$backup_path")"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Remove uncompressed backup
        rm -rf "$backup_path"
        
        # Get compressed size
        local compressed_size=$(du -sh "${backup_path}.tar.gz" | cut -f1)
        print_status "✅ Compression completed in ${duration}s"
        print_status "Compressed size: $compressed_size"
    else
        print_error "❌ Compression failed"
        return 1
    fi
}

# Function to create backup info file
create_backup_info() {
    local backup_path="$1"
    local backup_size="$2"
    local duration="$3"
    local info_file="${backup_path}.info"
    
    cat > "$info_file" << EOF
# SOC Chat App - Backup Information
# Generated on: $(date)
# Backup path: $backup_path
# Backup size: $backup_size
# Duration: ${duration}s
# MongoDB URI: $MONGO_URI
# Compression: $COMPRESSION
# Retention: $RETENTION_DAYS days

BACKUP_DATE=$(date)
BACKUP_PATH=$backup_path
BACKUP_SIZE=$backup_size
BACKUP_DURATION=${duration}s
MONGO_URI=$MONGO_URI
COMPRESSION=$COMPRESSION
RETENTION_DAYS=$RETENTION_DAYS
EOF
    
    print_verbose "Backup info file created: $info_file"
}

# Function to clean old backups
clean_old_backups() {
    print_status "Cleaning old backups (retention: $RETENTION_DAYS days)..."
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would clean backups older than $RETENTION_DAYS days"
        return 0
    fi
    
    local deleted_count=0
    local cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y%m%d 2>/dev/null || date -v-${RETENTION_DAYS}d +%Y%m%d 2>/dev/null || echo "")
    
    if [ -z "$cutoff_date" ]; then
        print_warning "Could not calculate cutoff date, skipping cleanup"
        return 0
    fi
    
    # Find and delete old backups
    for backup in "$BACKUP_DIR"/soc_chat_app_backup_*; do
        if [ -f "$backup" ] || [ -d "$backup" ]; then
            local backup_name=$(basename "$backup")
            local backup_date=$(echo "$backup_name" | grep -o '[0-9]\{8\}' | head -1)
            
            if [ -n "$backup_date" ] && [ "$backup_date" -lt "$cutoff_date" ]; then
                print_verbose "Deleting old backup: $backup_name"
                rm -rf "$backup" "${backup}.tar.gz" "${backup}.info"
                deleted_count=$((deleted_count + 1))
            fi
        fi
    done
    
    if [ $deleted_count -gt 0 ]; then
        print_status "✅ Cleaned up $deleted_count old backup(s)"
    else
        print_status "No old backups to clean up"
    fi
}

# Function to list backups
list_backups() {
    print_status "Available backups:"
    
    local backup_count=0
    for backup in "$BACKUP_DIR"/soc_chat_app_backup_*; do
        if [ -f "$backup" ] || [ -d "$backup" ]; then
            local backup_name=$(basename "$backup")
            local backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1 || echo "Unknown")
            local backup_date=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1 || echo "Unknown")
            
            echo "  - $backup_name ($backup_size, $backup_date)"
            backup_count=$((backup_count + 1))
        fi
    done
    
    if [ $backup_count -eq 0 ]; then
        print_warning "No backups found"
    else
        print_status "Total backups: $backup_count"
    fi
}

# Main execution
main() {
    print_header "SOC Chat App - MongoDB Backup"
    
    # Check prerequisites
    check_prerequisites
    
    # Test MongoDB connection
    if ! test_mongo_connection; then
        exit 1
    fi
    
    # Create backup
    if ! create_backup; then
        exit 1
    fi
    
    # Clean old backups
    clean_old_backups
    
    # List current backups
    list_backups
    
    print_header "Backup Process Completed Successfully! 🎉"
}

# Run main function
main "$@"
