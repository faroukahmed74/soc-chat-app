import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const broadcastToAllUsers = functions.https.onCall(async (data, context) => {
  const { title, body } = data;
  // Example: send to all users subscribed to a topic
  await admin.messaging().sendToTopic('all', {
    notification: { title, body }
  });
  return { success: true };
}); 