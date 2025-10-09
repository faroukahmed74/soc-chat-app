// =============================================================================
// SOC Chat App - PM2 Ecosystem Configuration
// =============================================================================
// This configuration file defines PM2 processes for production deployment
// 
// Usage:
//   pm2 start ecosystem.config.js          # Start all processes
//   pm2 start ecosystem.config.js --env production  # Start with production env
//   pm2 stop all                           # Stop all processes
//   pm2 restart all                        # Restart all processes
//   pm2 logs                               # View logs
//   pm2 monit                              # Monitor processes

module.exports = {
  apps: [
    // =============================================================================
    // API Server Process
    // =============================================================================
    {
      name: 'soc-chat-api',
      script: 'server.js',
      cwd: './servers/local_api_server',
      instances: 'max', // Use all available CPU cores
      exec_mode: 'cluster', // Enable clustering for better performance
      
      // Environment configuration
      env: {
        NODE_ENV: 'development',
        PORT: 3003,
        HOST: '0.0.0.0',
        LOG_LEVEL: 'info'
      },
      
      env_production: {
        NODE_ENV: 'production',
        PORT: 3003,
        HOST: '0.0.0.0',
        LOG_LEVEL: 'warn',
        DETAILED_ERRORS: 'false'
      },
      
      env_staging: {
        NODE_ENV: 'staging',
        PORT: 3003,
        HOST: '0.0.0.0',
        LOG_LEVEL: 'info',
        DETAILED_ERRORS: 'true'
      },
      
      // Process management
      autorestart: true,
      watch: false, // Disable file watching in production
      max_memory_restart: '1G', // Restart if memory usage exceeds 1GB
      
      // Logging configuration
      log_file: './logs/api-combined.log',
      out_file: './logs/api-out.log',
      error_file: './logs/api-error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      
      // Advanced process management
      min_uptime: '10s', // Minimum uptime before considering process stable
      max_restarts: 10, // Maximum restarts in 1 minute
      restart_delay: 4000, // Delay between restarts
      
      // Health monitoring
      health_check_grace_period: 3000, // Grace period for health checks
      health_check_fatal_exceptions: true,
      
      // Source map support
      source_map_support: true,
      
      // Instance variables
      instance_var: 'INSTANCE_ID',
      
      // Process title
      process_title: 'soc-chat-api',
      
      // Kill timeout
      kill_timeout: 5000,
      
      // Listen timeout
      listen_timeout: 10000,
      
      // Merge logs
      merge_logs: true,
      
      // Time format
      time: true
    },
    
    // =============================================================================
    // FCM Notification Server Process (Optional)
    // =============================================================================
    {
      name: 'soc-chat-fcm',
      script: 'fcm_server_production.js',
      cwd: './servers',
      instances: 1, // Single instance for FCM server
      exec_mode: 'fork', // Use fork mode for FCM server
      
      // Environment configuration
      env: {
        NODE_ENV: 'development',
        PORT: 3000,
        LOG_LEVEL: 'info'
      },
      
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
        LOG_LEVEL: 'warn'
      },
      
      // Process management
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      
      // Logging configuration
      log_file: './logs/fcm-combined.log',
      out_file: './logs/fcm-out.log',
      error_file: './logs/fcm-error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      
      // Advanced process management
      min_uptime: '10s',
      max_restarts: 5,
      restart_delay: 4000,
      
      // Health monitoring
      health_check_grace_period: 3000,
      health_check_fatal_exceptions: true,
      
      // Source map support
      source_map_support: true,
      
      // Process title
      process_title: 'soc-chat-fcm',
      
      // Kill timeout
      kill_timeout: 5000,
      
      // Listen timeout
      listen_timeout: 10000,
      
      // Merge logs
      merge_logs: true,
      
      // Time format
      time: true
    }
  ],
  
  // =============================================================================
  // Deployment Configuration
  // =============================================================================
  deploy: {
    production: {
      user: 'deploy',
      host: ['your-server.com'],
      ref: 'origin/main',
      repo: 'https://github.com/your-username/soc-chat-app.git',
      path: '/var/www/soc-chat-app',
      'pre-deploy-local': '',
      'post-deploy': 'npm install && pm2 reload ecosystem.config.js --env production',
      'pre-setup': '',
      'ssh_options': 'ForwardAgent=yes'
    },
    
    staging: {
      user: 'deploy',
      host: ['staging-server.com'],
      ref: 'origin/develop',
      repo: 'https://github.com/your-username/soc-chat-app.git',
      path: '/var/www/soc-chat-app-staging',
      'pre-deploy-local': '',
      'post-deploy': 'npm install && pm2 reload ecosystem.config.js --env staging',
      'pre-setup': '',
      'ssh_options': 'ForwardAgent=yes'
    }
  }
};

// =============================================================================
// PM2 Configuration Notes
// =============================================================================
// 
// 1. INSTALLATION:
//    npm install -g pm2
// 
// 2. BASIC COMMANDS:
//    pm2 start ecosystem.config.js
//    pm2 stop ecosystem.config.js
//    pm2 restart ecosystem.config.js
//    pm2 reload ecosystem.config.js
//    pm2 delete ecosystem.config.js
//    pm2 logs
//    pm2 monit
//    pm2 status
// 
// 3. ENVIRONMENT SPECIFIC:
//    pm2 start ecosystem.config.js --env production
//    pm2 start ecosystem.config.js --env staging
// 
// 4. LOG MANAGEMENT:
//    pm2 logs --lines 100
//    pm2 flush
//    pm2 reloadLogs
// 
// 5. MONITORING:
//    pm2 monit
//    pm2 show soc-chat-api
//    pm2 describe soc-chat-api
// 
// 6. UPDATES:
//    pm2 reload ecosystem.config.js
//    pm2 gracefulReload ecosystem.config.js
// 
// 7. STARTUP:
//    pm2 startup
//    pm2 save
// 
// 8. BACKUP:
//    pm2 save
//    pm2 resurrect
// 
// 9. CLUSTERING:
//    - Uses all available CPU cores
//    - Automatic load balancing
//    - Zero-downtime reloads
// 
// 10. HEALTH CHECKS:
//     - Automatic restart on failures
//     - Memory limit monitoring
//     - Graceful shutdown handling
