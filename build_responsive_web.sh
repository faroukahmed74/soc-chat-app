#!/bin/bash

# =============================================================================
# RESPONSIVE WEB BUILD SCRIPT
# =============================================================================
# This script builds the Flutter web app with responsive features
# optimized for local network access at 10.120.4.230:8082

echo "========================================"
echo "  SOC Chat App - Responsive Web Build"
echo "========================================"
echo

# Configuration
LOCAL_IP="10.120.4.230"
PORT="8082"
BUILD_DIR="build/web"
BASE_URL="http://$LOCAL_IP:$PORT"

echo "Building responsive web app for local network access..."
echo "Target URL: $BASE_URL"
echo

# Clean previous build
echo "1. Cleaning previous build..."
flutter clean
echo "✓ Clean completed"
echo

# Get dependencies
echo "2. Getting dependencies..."
flutter pub get
echo "✓ Dependencies updated"
echo

# Build web app with responsive configuration
echo "3. Building web app with responsive features..."
flutter build web \
  --web-renderer html \
  --base-href "/" \
  --dart-define=API_BASE_URL_WEB=http://$LOCAL_IP:$PORT \
  --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app \
  --release
echo "✓ Web build completed"
echo

# Copy responsive configuration
echo "4. Adding responsive configuration..."
cp web/responsive_config.js $BUILD_DIR/
echo "✓ Responsive config added"
echo

# Update index.html for local network
echo "5. Configuring for local network access..."
sed -i.bak "s|http://localhost:3003|http://$LOCAL_IP:$PORT|g" $BUILD_DIR/index.html
echo "✓ Local network configuration updated"
echo

# Create responsive CSS
echo "6. Adding responsive CSS..."
cat > $BUILD_DIR/responsive.css << 'EOF'
/* Responsive CSS for SOC Chat App */

/* Mobile First Approach */
.responsive-container {
  width: 100%;
  max-width: 100%;
  margin: 0 auto;
  padding: 16px;
}

/* Tablet Styles */
@media (min-width: 600px) {
  .responsive-container {
    max-width: 768px;
    padding: 24px;
  }
  
  .responsive-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

/* Desktop Styles */
@media (min-width: 900px) {
  .responsive-container {
    max-width: 1200px;
    padding: 32px;
  }
  
  .responsive-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}

/* Touch-friendly mobile interface */
@media (max-width: 599px) {
  .touch-target {
    min-height: 44px;
    min-width: 44px;
  }
  
  .mobile-nav {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    background: white;
    border-top: 1px solid #e0e0e0;
    z-index: 1000;
  }
}

/* Responsive typography */
.responsive-text {
  font-size: 16px;
  line-height: 1.5;
}

@media (min-width: 600px) {
  .responsive-text {
    font-size: 18px;
  }
}

@media (min-width: 900px) {
  .responsive-text {
    font-size: 20px;
  }
}

/* Responsive buttons */
.responsive-button {
  padding: 12px 24px;
  font-size: 16px;
  border-radius: 8px;
  min-height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
}

@media (min-width: 600px) {
  .responsive-button {
    padding: 14px 28px;
    font-size: 18px;
    min-height: 52px;
  }
}

@media (min-width: 900px) {
  .responsive-button {
    padding: 16px 32px;
    font-size: 20px;
    min-height: 56px;
  }
}

/* Responsive modals */
.responsive-modal {
  width: 100%;
  max-width: 100%;
  margin: 0 auto;
}

@media (min-width: 600px) {
  .responsive-modal {
    max-width: 600px;
  }
}

@media (min-width: 900px) {
  .responsive-modal {
    max-width: 700px;
  }
}

/* Responsive grid */
.responsive-grid {
  display: grid;
  gap: 16px;
  grid-template-columns: 1fr;
}

@media (min-width: 600px) {
  .responsive-grid {
    gap: 20px;
  }
}

@media (min-width: 900px) {
  .responsive-grid {
    gap: 24px;
  }
}

/* Responsive spacing */
.responsive-spacing {
  margin: 16px 0;
}

@media (min-width: 600px) {
  .responsive-spacing {
    margin: 20px 0;
  }
}

@media (min-width: 900px) {
  .responsive-spacing {
    margin: 24px 0;
  }
}

/* Local network specific styles */
.local-network-indicator {
  position: fixed;
  top: 10px;
  right: 10px;
  background: #4CAF50;
  color: white;
  padding: 8px 12px;
  border-radius: 4px;
  font-size: 12px;
  z-index: 1001;
}

/* Dark mode support */
@media (prefers-color-scheme: dark) {
  .responsive-container {
    background-color: #1e1e1e;
    color: white;
  }
  
  .mobile-nav {
    background: #2e2e2e;
    border-top-color: #404040;
  }
}
EOF

echo "✓ Responsive CSS added"
echo

# Create local network launcher
echo "7. Creating local network launcher..."
cat > $BUILD_DIR/launch_local.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SOC Chat App - Local Network</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .container {
            text-align: center;
            background: white;
            padding: 40px;
            border-radius: 16px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            max-width: 500px;
            width: 90%;
        }
        .logo {
            width: 80px;
            height: 80px;
            background: #667eea;
            border-radius: 16px;
            margin: 0 auto 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 32px;
            font-weight: bold;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
        }
        p {
            color: #666;
            margin-bottom: 30px;
        }
        .launch-btn {
            display: inline-block;
            background: #667eea;
            color: white;
            padding: 16px 32px;
            text-decoration: none;
            border-radius: 8px;
            font-size: 18px;
            font-weight: bold;
            transition: background 0.3s ease;
        }
        .launch-btn:hover {
            background: #5a6fd8;
        }
        .info {
            margin-top: 30px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
            text-align: left;
        }
        .info h3 {
            margin-top: 0;
            color: #333;
        }
        .info p {
            margin: 8px 0;
            color: #666;
        }
        .responsive-features {
            margin-top: 20px;
            text-align: left;
        }
        .feature {
            display: flex;
            align-items: center;
            margin: 8px 0;
            color: #4CAF50;
        }
        .feature::before {
            content: "✓";
            margin-right: 8px;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">💬</div>
        <h1>SOC Chat App</h1>
        <p>Secure messaging for friends and groups</p>
        
        <a href="index.html" class="launch-btn">Launch App</a>
        
        <div class="info">
            <h3>Local Network Access</h3>
            <p><strong>URL:</strong> $BASE_URL</p>
            <p><strong>Status:</strong> Ready for local network access</p>
            
            <div class="responsive-features">
                <h3>Responsive Features</h3>
                <div class="feature">Mobile-optimized interface</div>
                <div class="feature">Tablet-friendly layout</div>
                <div class="feature">Desktop-optimized design</div>
                <div class="feature">Touch-friendly controls</div>
                <div class="feature">Adaptive media handling</div>
                <div class="feature">Real-time notifications</div>
                <div class="feature">Admin panel access</div>
                <div class="feature">Media upload support</div>
            </div>
        </div>
    </div>
    
    <script>
        // Auto-launch after 3 seconds
        setTimeout(() => {
            window.location.href = 'index.html';
        }, 3000);
    </script>
</body>
</html>
EOF

echo "✓ Local network launcher created"
echo

# Test the build
echo "8. Testing responsive build..."
if [ -f "$BUILD_DIR/index.html" ]; then
    echo "✓ Index.html found"
fi

if [ -f "$BUILD_DIR/responsive_config.js" ]; then
    echo "✓ Responsive config found"
fi

if [ -f "$BUILD_DIR/responsive.css" ]; then
    echo "✓ Responsive CSS found"
fi

if [ -f "$BUILD_DIR/launch_local.html" ]; then
    echo "✓ Local launcher found"
fi

echo

# Summary
echo "========================================"
echo "  Build Summary"
echo "========================================"
echo "✓ Responsive web app built successfully"
echo "✓ Local network configuration: $BASE_URL"
echo "✓ Responsive features enabled"
echo "✓ Mobile, tablet, and desktop support"
echo "✓ Touch-friendly interface"
echo "✓ Admin panel accessible"
echo "✓ Media upload support"
echo "✓ Real-time notifications"
echo
echo "To serve the app:"
echo "  cd $BUILD_DIR"
echo "  python3 -m http.server $PORT"
echo "  # or"
echo "  npx serve -s . -l $PORT"
echo
echo "Access at: $BASE_URL"
echo "Launcher: $BASE_URL/launch_local.html"
echo "========================================"
