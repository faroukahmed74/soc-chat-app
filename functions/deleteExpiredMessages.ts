import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const deleteExpiredMessages = functions.pubsub.schedule('every 10 minutes').onRun(async (context) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  const chatsSnap = await db.collection('chats').get();
  for (const chatDoc of chatsSnap.docs) {
    const chatId = chatDoc.id;
    const members: string[] = chatDoc.data().members || [];
    const messagesSnap = await db.collection('chats').doc(chatId).collection('messages').get();

    for (const msgDoc of messagesSnap.docs) {
      const data = msgDoc.data();
      const readBy: string[] = data.readBy || [];
      const expiresAt = data.expiresAt;
      const mediaUrl = data.mediaUrl;

      // Delete if all members have read or expired
      if (
        (members.every(uid => readBy.includes(uid)) && members.length > 0) ||
        (expiresAt && expiresAt.toMillis() < now.toMillis())
      ) {
        await msgDoc.ref.delete();
        // Delete media from storage if present
        if (mediaUrl && mediaUrl.startsWith('https://')) {
          try {
            const bucket = admin.storage().bucket();
            // Extract path after /o/
            const match = decodeURIComponent(mediaUrl).match(/\/o\/(.+)\?/);
            if (match && match[1]) {
              await bucket.file(match[1]).delete();
            }
          } catch (e) {
            console.error('Failed to delete media:', e);
          }
        }
      }
    }
  }
  return null;
}); 