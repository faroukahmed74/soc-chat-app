#!/bin/bash
# Quick test script to check if ffmpeg is installed and working

echo "Checking if ffmpeg is installed..."
if command -v ffmpeg &> /dev/null; then
    echo "✓ FFmpeg is installed"
    echo ""
    echo "Version:"
    ffmpeg -version | head -n 1
    echo ""
    echo "FFmpeg location:"
    which ffmpeg
else
    echo "✗ FFmpeg is NOT installed"
    echo ""
    echo "To install on Ubuntu/Debian:"
    echo "  sudo apt-get update && sudo apt-get install -y ffmpeg"
    echo ""
    echo "To install on CentOS/RHEL:"
    echo "  sudo yum install -y ffmpeg"
fi

