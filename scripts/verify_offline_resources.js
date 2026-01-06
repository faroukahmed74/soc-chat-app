#!/usr/bin/env node
/**
 * Verify that all web resources are local (no external CDN dependencies)
 * This script checks build/web/ directory for any external URLs
 */

const fs = require('fs');
const path = require('path');

const buildWebDir = path.join(__dirname, '..', 'build', 'web');
const webDir = path.join(__dirname, '..', 'web');

// External CDN patterns to detect
const EXTERNAL_PATTERNS = [
  /https?:\/\/(www\.)?gstatic\.com/,
  /https?:\/\/(www\.)?googleapis\.com/,
  /https?:\/\/fonts\.googleapis\.com/,
  /https?:\/\/fonts\.gstatic\.com/,
  /https?:\/\/cdnjs\.cloudflare\.com/,
  /https?:\/\/unpkg\.com/,
  /https?:\/\/cdn\.jsdelivr\.net/,
];

// Required local files
const REQUIRED_FILES = [
  'firebase/firebase-app-compat.js',
  'firebase/firebase-messaging-compat.js',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'index.html',
  'flutter.js',
  'main.dart.js',
];

function checkFile(filePath, relativePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const issues = [];
  
  // Check for external URLs
  EXTERNAL_PATTERNS.forEach((pattern, index) => {
    if (pattern.test(content)) {
      const matches = content.match(pattern);
      issues.push(`External CDN detected: ${matches[0]}`);
    }
  });
  
  return issues;
}

function verifyOfflineResources() {
  console.log('🔍 Verifying offline resources...\n');
  
  if (!fs.existsSync(buildWebDir)) {
    console.error('❌ build/web directory does not exist. Run "flutter build web" first.');
    process.exit(1);
  }
  
  let hasIssues = false;
  
  // Check required files
  console.log('📦 Checking required local files...');
  REQUIRED_FILES.forEach(file => {
    const filePath = path.join(buildWebDir, file);
    if (fs.existsSync(filePath)) {
      console.log(`  ✅ ${file}`);
    } else {
      console.log(`  ❌ ${file} - MISSING`);
      hasIssues = true;
    }
  });
  
  // Check HTML files for external URLs
  console.log('\n🔍 Checking HTML files for external URLs...');
  const htmlFiles = ['index.html'];
  htmlFiles.forEach(file => {
    const filePath = path.join(buildWebDir, file);
    if (fs.existsSync(filePath)) {
      const issues = checkFile(filePath, file);
      if (issues.length > 0) {
        console.log(`  ❌ ${file}:`);
        issues.forEach(issue => console.log(`     - ${issue}`));
        hasIssues = true;
      } else {
        console.log(`  ✅ ${file} - No external URLs detected`);
      }
    }
  });
  
  // Check JavaScript files
  console.log('\n🔍 Checking JavaScript files for external URLs...');
  const jsFiles = ['firebase-messaging-sw.js', 'responsive_config.js'];
  jsFiles.forEach(file => {
    const filePath = path.join(buildWebDir, file);
    if (fs.existsSync(filePath)) {
      const issues = checkFile(filePath, file);
      if (issues.length > 0) {
        console.log(`  ❌ ${file}:`);
        issues.forEach(issue => console.log(`     - ${issue}`));
        hasIssues = true;
      } else {
        console.log(`  ✅ ${file} - No external URLs detected`);
      }
    }
  });
  
  console.log('\n' + '='.repeat(50));
  if (hasIssues) {
    console.log('❌ Issues found. Please fix them before deploying.');
    process.exit(1);
  } else {
    console.log('✅ All resources are local. App is ready for offline deployment.');
  }
}

verifyOfflineResources();
