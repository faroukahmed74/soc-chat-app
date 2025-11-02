// =============================================================================
// SERVICE WORKER FOR SOC CHAT APP
// =============================================================================
// This service worker handles offline functionality and caching
// Firebase messaging removed - using MongoDB with local notifications

// Service worker version
const CACHE_NAME = 'soc-chat-app-v1.0.4';
const urlsToCache = [
  '/',
  '/index.html',
  '/responsive_config.js',
  '/responsive.css',
  '/icons/favicon.png',
  '/icons/favicon.svg',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
  '/manifest.json',
  '/main.dart.js',
  '/flutter.js',
  '/canvaskit/canvaskit.js',
  '/canvaskit/canvaskit.wasm',
  '/canvaskit/skwasm.js',
  '/canvaskit/skwasm.wasm',
  '/canvaskit/skwasm_heavy.js',
  '/canvaskit/skwasm_heavy.wasm',
  // --- add more assets as needed, for example:
  // '/assets/logo/logo.png',
  // '/assets/notification_sounds/notification.mp3',
  // '/version_info.json',
];

// Install event - cache resources
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('Service worker: caching files');
        return cache.addAll(urlsToCache);
      })
      .catch((error) => {
        console.error('Service worker: cache failed', error);
      })
  );
});

// Fetch event - serve from cache when offline
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // Return cached version or fetch from network
        return response || fetch(event.request);
      })
      .catch((error) => {
        console.error('Service worker: fetch failed', error);
        // Return offline page if available
        return caches.match('/index.html');
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('Service worker: deleting old cache', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
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