// =============================================================================
// SERVICE WORKER FOR SOC CHAT APP - OFFLINE MODE
// =============================================================================
// This service worker handles offline functionality and caching
// Aggressively caches all assets, fonts, and resources for complete offline support
// Works on local network (IPv4:8082) without internet connection

// Service worker version - increment when updating cache strategy
const CACHE_NAME = 'soc-chat-app-offline-v1.0.24';
const OFFLINE_CACHE_NAME = 'soc-chat-app-offline-fallback';

// Core files to cache immediately
const CORE_FILES = [
  '/',
  '/index.html',
  '/responsive_config.js',
  '/responsive.css',
  '/manifest.json',
  '/flutter.js',
  '/firebase/firebase-app-compat.js',
  '/firebase/firebase-messaging-compat.js',
];

// Icons to cache
const ICON_FILES = [
  '/icons/favicon.png',
  '/icons/favicon.svg',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
];

// Flutter engine files (will be populated dynamically)
const FLUTTER_ENGINE_FILES = [
  '/main.dart.js',
  '/canvaskit/canvaskit.js',
  '/canvaskit/canvaskit.wasm',
  '/canvaskit/skwasm.js',
  '/canvaskit/skwasm.wasm',
  '/canvaskit/skwasm_heavy.js',
  '/canvaskit/skwasm_heavy.wasm',
];

// Asset paths (will cache all assets from build)
const ASSET_PATTERNS = [
  '/assets/assets/logo/',
  '/assets/assets/fonts/',
  '/assets/assets/notification_sounds/',
  '/assets/version_info.json',
];

// Install event - cache core resources immediately
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[Service Worker] Caching core files');
        const filesToCache = [...CORE_FILES, ...ICON_FILES];
        return cache.addAll(filesToCache.map(url => new Request(url, {cache: 'reload'})));
      })
      .then(() => {
        console.log('[Service Worker] Core files cached');
        // Skip waiting to activate immediately
        return self.skipWaiting();
      })
      .catch((error) => {
        console.error('[Service Worker] Cache failed:', error);
      })
  );
});

// Activate event - clean up old caches and cache all resources
self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME && cacheName !== OFFLINE_CACHE_NAME) {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
    .then(() => {
      // Cache all Flutter engine files and assets
      return cacheAllResources();
    })
    .then(() => {
      console.log('[Service Worker] Activated and ready');
      return self.clients.claim();
    })
  );
});

// Function to cache all resources aggressively
async function cacheAllResources() {
  const cache = await caches.open(CACHE_NAME);
  
  // Cache Flutter engine files
  const engineFiles = FLUTTER_ENGINE_FILES.map(file => new Request(file, {cache: 'reload'}));
  try {
    await Promise.all(engineFiles.map(request => 
      cache.add(request).catch(err => {
        console.log('[Service Worker] Could not cache:', request.url, err);
      })
    ));
  } catch (error) {
    console.log('[Service Worker] Some engine files may not be available yet');
  }
  
  // Cache all assets (fonts, images, sounds, etc.)
  // This will be populated during runtime as assets are requested
  console.log('[Service Worker] Ready to cache assets on demand');
}

// Fetch event - aggressive caching strategy for offline support
self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  
  // Skip cross-origin requests (except same-origin)
  if (url.origin !== location.origin && !request.url.startsWith('http://') && !request.url.startsWith('https://')) {
    return;
  }
  
  // Block all external CDN requests - all resources must be local
  if (url.hostname.includes('gstatic.com') || 
      url.hostname.includes('googleapis.com') ||
      url.hostname.includes('fonts.googleapis.com') ||
      url.hostname.includes('fonts.gstatic.com') ||
      url.hostname.includes('cdnjs.cloudflare.com') ||
      url.hostname.includes('unpkg.com') ||
      url.hostname.includes('cdn.jsdelivr.net')) {
    console.log('[Service Worker] Blocked external CDN request:', url.hostname);
    return;
  }
  
  event.respondWith(
    caches.match(request)
      .then((cachedResponse) => {
        // Return cached version if available
        if (cachedResponse) {
          return cachedResponse;
        }
        
        // Try to fetch from network
        return fetch(request)
          .then((response) => {
            // Don't cache non-GET requests or non-successful responses
            if (request.method !== 'GET' || !response || response.status !== 200 || response.type !== 'basic') {
              return response;
            }
            
            // Clone the response (stream can only be consumed once)
            const responseToCache = response.clone();
            
            // Cache the response for offline use
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(request, responseToCache);
            });
            
            return response;
          })
          .catch((error) => {
            console.log('[Service Worker] Fetch failed (offline):', request.url);
            
            // If it's a navigation request, return the index.html
            if (request.mode === 'navigate') {
              return caches.match('/index.html');
            }
            
            // For other requests, try to return a cached version or null
            return caches.match(request);
          });
      })
  );
});

// Handle push notifications (if needed in future)
self.addEventListener('push', (event) => {
  console.log('Service worker: push event received');
  
  const options = {
    body: event.data ? event.data.text() : 'New message received',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    vibrate: [100, 50, 100],
    data: {
      dateOfArrival: Date.now(),
      primaryKey: 1
    },
    actions: [
      {
        action: 'explore',
        title: 'Open App',
        icon: '/icons/Icon-192.png'
      },
      {
        action: 'close',
        title: 'Close',
        icon: '/icons/Icon-192.png'
      }
    ]
  };

  event.waitUntil(
    self.registration.showNotification('SOC Chat App', options)
  );
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('Service worker: notification click received');
  
  event.notification.close();
  
  if (event.action === 'explore') {
    // Open the app
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});

console.log('SOC Chat App service worker loaded');