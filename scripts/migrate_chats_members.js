// Migration: Normalize chat documents to use `members: ObjectId[]`
// - Converts legacy `memberIds` (string[]) to `members`
// - Converts any string IDs in `members` to `ObjectId`
// - Removes `memberIds` after migration
// Usage: node scripts/migrate_chats_members.js

const { MongoClient, ObjectId } = require('mongodb');

async function connectWithFallback() {
  const primaryUri = process.env.MONGO_URI || 'mongodb://admin:SecurePassword123!@localhost:27017/soc_chat_app?authSource=admin';
  const fallbackUri = 'mongodb://localhost:27017/soc_chat_app';
  let client;
  try {
    client = new MongoClient(primaryUri, {
      maxPoolSize: 5,
      serverSelectionTimeoutMS: 5000,
    });
    await client.connect();
    console.log('Connected to MongoDB (primary)');
    return { client, db: client.db('soc_chat_app') };
  } catch (err) {
    console.warn('Primary connection failed, attempting fallback:', err.message);
    client = new MongoClient(fallbackUri, {
      maxPoolSize: 5,
      serverSelectionTimeoutMS: 5000,
    });
    await client.connect();
    console.log('Connected to MongoDB (fallback no-auth)');
    return { client, db: client.db('soc_chat_app') };
  }
}

function toObjectIdArray(input) {
  const result = [];
  if (!Array.isArray(input)) return result;
  for (const v of input) {
    // Already an ObjectId
    if (v && typeof v === 'object' && v._bsontype === 'ObjectID') {
      result.push(v);
      continue;
    }
    // String that looks like an ObjectId
    const s = String(v);
    if (ObjectId.isValid(s)) {
      try { result.push(new ObjectId(s)); } catch (e) { /* ignore */ }
    } else {
      // Skip invalid entries
      console.warn('Skipping invalid member id:', v);
    }
  }
  return result;
}

async function migrateChats(db) {
  const chatsCol = db.collection('chats');
  const cursor = chatsCol.find({});
  let scanned = 0;
  let updated = 0;
  let skipped = 0;

  while (await cursor.hasNext()) {
    const chat = await cursor.next();
    scanned++;

    const hasMemberIds = Array.isArray(chat.memberIds) && chat.memberIds.length > 0;
    const hasMembers = Array.isArray(chat.members) && chat.members.length > 0;

    // Build new members array from existing fields
    let newMembers = [];
    if (hasMembers) {
      newMembers = toObjectIdArray(chat.members);
    }
    if ((!hasMembers || newMembers.length === 0) && hasMemberIds) {
      // Use legacy field if members is missing or empty
      newMembers = toObjectIdArray(chat.memberIds);
    }

    // If nothing valid to migrate, skip
    if (!newMembers || newMembers.length === 0) {
      skipped++;
      continue;
    }

    // Determine if an update is needed
    const needsUpdate = (!hasMembers) || (chat.members.length !== newMembers.length);
    if (needsUpdate || hasMemberIds) {
      const update = {
        $set: { members: newMembers },
        $unset: { memberIds: '' }
      };
      await chatsCol.updateOne({ _id: chat._id }, update);
      updated++;
    } else {
      skipped++;
    }
  }

  return { scanned, updated, skipped };
}

async function main() {
  let client;
  try {
    const conn = await connectWithFallback();
    client = conn.client;
    const { scanned, updated, skipped } = await migrateChats(conn.db);
    console.log('Migration complete:', { scanned, updated, skipped });
    await client.close();
    process.exit(0);
  } catch (err) {
    console.error('Migration failed:', err);
    if (client) { try { await client.close(); } catch (_) {} }
    process.exit(1);
  }
}

main();