/* eslint-disable no-undef */
// Firebase Messaging SW (Compat for simplicity)
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');

// Firebase configuration for SOC Chat App
firebase.initializeApp({
  apiKey: "AIzaSyCRCvKNo5n7KT9jPd5gRDJYMlElYQUgYCg",
  authDomain: "soc-chat-app-ca57e.firebaseapp.com",
  projectId: "soc-chat-app-ca57e",
  messagingSenderId: "889400273440",
  appId: "1:889400273440:web:319b144169e0312713aa45",
  databaseURL: "https://soc-chat-app-ca57e-default-rtdb.firebaseio.com",
  storageBucket: "soc-chat-app-ca57e.firebasestorage.app",
  measurementId: "G-4RPEDKQMS7",
});

const messaging = firebase.messaging();

// Optional: background message handler to show notifications
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || payload.data?.title || 'New message';
  const options = {
    body: payload.notification?.body || payload.data?.body || '',
    data: payload.data || {},
    // icon: '/icons/Icon-192.png', // optional
  };
  self.registration.showNotification(title, options);
});
