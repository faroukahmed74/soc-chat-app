const express = require('express');
const path = require('path');
const app = express();
const PORT = 8080;

// Serve static files from the web build directory
app.use(express.static(path.join(__dirname, 'build', 'web')));

// Handle all routes by serving index.html (for SPA)
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'build', 'web', 'index.html'));
});

// Start the server
app.listen(PORT, '0.0.0.0', () => {
    console.log('========================================');
    console.log('  SOC Chat App - Portable Server');
    console.log('========================================');
    console.log('');
    console.log(`🚀 App is running at:`);
    console.log(`   Local: http://localhost:${PORT}`);
    console.log(`   Network: http://0.0.0.0:${PORT}`);
    console.log('');
    console.log('Press Ctrl+C to stop the server');
    console.log('');
    
    // Auto-open browser
    const { exec } = require('child_process');
    exec(`start http://localhost:${PORT}`, (error) => {
        if (error) {
            console.log('Please open your browser and navigate to:');
            console.log(`http://localhost:${PORT}`);
        }
    });
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down SOC Chat App...');
    process.exit(0);
});
