# Enhanced Database Admin Tool Guide

## Overview

The Enhanced Database Admin Tool provides comprehensive database management capabilities for the SOC Chat App, including advanced user management, statistics, analytics, and maintenance features.

## Features

### 🔧 Basic Operations
- **Database Statistics**: View database size, collections, and document counts
- **List Collections**: Display all database collections
- **View Users**: Browse all users with detailed information
- **View Chats**: Display all chat conversations
- **View Messages**: Show recent messages with pagination
- **View Admin Users**: List all administrator accounts
- **Search Users**: Find users by email, name, or ID
- **System Health Check**: Monitor database and system status

### 👥 User Management (Advanced)
- **View User with Password**: Display user details including password hash (ADMIN ONLY)
- **Delete User**: Remove user account and all associated data
- **Update User Role**: Change user role (user/admin)
- **Reset User Password**: Set new password for any user
- **Create Admin User**: Add new administrator account

### 📊 Statistics & Analytics
- **User Statistics**: 
  - Total users, admin users, regular users
  - Active/inactive user counts
  - Recent registrations (7 days)
- **Chat Statistics**:
  - Total chats, group chats, private chats
  - Recent chat activity (7 days)
- **Message Statistics**:
  - Total messages by type (text, image, video, audio)
  - Recent message activity (7 days)

### 🛠️ Maintenance
- **Cleanup Old Data**: Remove messages and chats older than specified days
- **Export Database**: Create full database backup using mongodump

## Usage

### Interactive Mode
```bash
# Run the enhanced admin tool
view_database.bat

# Or directly
node database_admin_tool.js
```

### Command Line Mode
```bash
# Quick commands
view_database.bat stats
view_database.bat users
view_database.bat chats
view_database.bat messages
view_database.bat admins
view_database.bat health
```

## Menu Options

### Basic Operations (1-8)
1. **Database Statistics** - Overview of database size and collections
2. **List Collections** - Show all database collections
3. **View Users** - Display all users with basic information
4. **View Chats** - Show all chat conversations
5. **View Messages** - Display recent messages (configurable limit)
6. **View Admin Users** - List administrator accounts
7. **Search Users** - Find users by search query
8. **System Health Check** - Monitor system status

### User Management (9-13)
9. **View User with Password** - Show user details including password hash
10. **Delete User** - Remove user and all associated data
11. **Update User Role** - Change user role (user/admin)
12. **Reset User Password** - Set new password for user
13. **Create Admin User** - Add new administrator

### Statistics & Analytics (14-16)
14. **User Statistics** - Comprehensive user analytics
15. **Chat Statistics** - Chat activity and type analysis
16. **Message Statistics** - Message type and activity analysis

### Maintenance (17-18)
17. **Cleanup Old Data** - Remove old messages and chats
18. **Export Database** - Create database backup

## Security Features

### Password Viewing
- **Admin Only**: Password hashes are only visible to administrators
- **Secure Display**: Passwords are shown as bcrypt hashes, not plain text
- **Audit Trail**: All password operations are logged

### User Deletion
- **Cascade Delete**: Removes user messages and chat memberships
- **Confirmation Required**: Double confirmation before deletion
- **Safe Operation**: Preserves chat integrity for remaining members

### Role Management
- **Validation**: Only valid roles (user/admin) are accepted
- **Immediate Effect**: Role changes take effect immediately
- **Audit Logging**: All role changes are tracked

## Data Management

### Cleanup Operations
- **Configurable Age**: Set custom cleanup period (default 30 days)
- **Safe Cleanup**: Only removes data older than specified period
- **Chat Preservation**: Keeps chats with recent activity
- **Confirmation Required**: Prevents accidental data loss

### Export Features
- **Full Backup**: Complete database export using mongodump
- **Timestamped**: Exports include timestamp for organization
- **Compressed**: Efficient storage of backup data
- **Recovery Ready**: Exports can be restored with mongorestore

## Statistics & Analytics

### User Analytics
- **Registration Trends**: Track new user signups
- **Activity Status**: Monitor active vs inactive users
- **Role Distribution**: View admin vs regular user ratios
- **Growth Metrics**: 7-day registration trends

### Chat Analytics
- **Chat Types**: Group vs private chat distribution
- **Activity Levels**: Recent chat creation trends
- **Engagement Metrics**: Chat participation analysis

### Message Analytics
- **Content Types**: Text, image, video, audio message distribution
- **Volume Trends**: Message sending patterns
- **Media Usage**: File sharing statistics

## Best Practices

### Security
- **Regular Audits**: Use statistics to monitor user activity
- **Password Management**: Regularly review and reset passwords
- **Role Verification**: Ensure proper admin/user role distribution
- **Data Cleanup**: Regular cleanup of old data to maintain performance

### Maintenance
- **Regular Exports**: Create database backups before major operations
- **Health Monitoring**: Use system health checks regularly
- **Performance Optimization**: Clean up old data to improve performance
- **User Management**: Regular review of user accounts and roles

### Monitoring
- **Growth Tracking**: Monitor user registration trends
- **Activity Analysis**: Track chat and message activity
- **System Health**: Regular health checks for database and system
- **Error Monitoring**: Watch for connection and operation errors

## Troubleshooting

### Common Issues
1. **Connection Errors**: Ensure MongoDB and API server are running
2. **Authentication Issues**: Check MongoDB credentials in .env file
3. **Permission Errors**: Verify admin privileges for sensitive operations
4. **Export Failures**: Ensure mongodump is installed and accessible

### Error Messages
- **"User not found"**: Verify user ID is correct
- **"Invalid role"**: Use only 'user' or 'admin' roles
- **"Authentication failed"**: Check MongoDB credentials
- **"Export failed"**: Verify mongodump installation

## Dependencies

### Required Packages
- `mongodb`: MongoDB driver
- `bcryptjs`: Password hashing
- `dotenv`: Environment variable management
- `readline`: Interactive input handling

### System Requirements
- Node.js 14+
- MongoDB 4.4+
- mongodump (for exports)
- Windows/Linux/macOS compatibility

## Support

For issues or questions about the Enhanced Database Admin Tool:
1. Check the troubleshooting section
2. Verify all dependencies are installed
3. Ensure MongoDB and API server are running
4. Review error messages for specific guidance

## Version History

### v2.0 (Enhanced)
- Added advanced user management features
- Implemented statistics and analytics
- Added maintenance and cleanup tools
- Enhanced security and audit features
- Improved user interface and navigation

### v1.0 (Basic)
- Basic database viewing capabilities
- Simple user and chat management
- Basic health monitoring
- Command-line interface
