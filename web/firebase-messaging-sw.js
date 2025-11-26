// Firebase Messaging Service Worker for Web Push Notifications
// Import Firebase scripts
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Initialize Firebase in service worker
firebase.initializeApp({
  apiKey: "AIzaSyBoFrLWpQTUrHw-wjOb3_lp5PTyDsxb7nw",
  authDomain: "vevij-16299.firebaseapp.com",
  projectId: "vevij-16299",
  storageBucket: "vevij-16299.firebasestorage.app",
  messagingSenderId: "566517432772",
  appId: "1:566517432772:web:57838836a81599ed206491"
});

const messaging = firebase.messaging();

// Handle background messages (when browser is open but app is not in focus)
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);
  
  const notificationTitle = payload.notification?.title || 'New Notification';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
    requireInteraction: false,
    tag: payload.data?.taskId || payload.data?.teamId || 'default',
    vibrate: [200, 100, 200]
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification clicked:', event.notification);
  event.notification.close();
  
  // Get the task or team ID from the notification data
  const data = event.notification.data;
  let url = '/';
  
  if (data?.taskId) {
    url = `/#/task/${data.taskId}`;
  } else if (data?.teamId) {
    url = `/#/team/${data.teamId}`;
  }
  
  // Navigate to the app or bring it to focus
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Check if there's already a window open
        for (let client of clientList) {
          if (client.url === url && 'focus' in client) {
            return client.focus();
          }
        }
        // If no window is open, open a new one
        if (clients.openWindow) {
          return clients.openWindow(url);
        }
      })
  );
});
