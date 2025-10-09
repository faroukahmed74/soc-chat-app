// =============================================================================
// SOC Chat App - Database Indexes Configuration
// =============================================================================
// This file defines MongoDB indexes for optimal query performance
// Run this script to create all necessary indexes for the SOC Chat App

const { MongoClient } = require('mongodb');

// MongoDB connection URI
const MONGO_URI = process.env.MONGO_URI || 'mongodb://admin:SecurePassword123!@localhost:27017/soc_chat_app?authSource=admin';

// Index definitions
const INDEXES = {
  // =============================================================================
  // USERS COLLECTION INDEXES
  // =============================================================================
  users: [
    // Email index (unique for user authentication)
    {
      key: { email: 1 },
      unique: true,
      name: 'email_unique'
    },
    
    // Status index (for online/offline queries)
    {
      key: { status: 1 },
      name: 'status_index'
    },
    
    // Created date index (for user registration queries)
    {
      key: { createdAt: -1 },
      name: 'created_at_index'
    },
    
    // Last seen index (for activity tracking)
    {
      key: { lastSeen: -1 },
      name: 'last_seen_index'
    },
    
    // Compound index for user search
    {
      key: { 
        name: 'text',
        email: 'text'
      },
      name: 'user_search_text',
      default_language: 'english'
    }
  ],
  
  // =============================================================================
  // CHATS COLLECTION INDEXES
  // =============================================================================
  chats: [
    // Members array index (for finding user's chats)
    {
      key: { members: 1 },
      name: 'members_index'
    },
    
    // Created by index (for admin queries)
    {
      key: { createdBy: 1 },
      name: 'created_by_index'
    },
    
    // Updated date index (for chat list ordering)
    {
      key: { updatedAt: -1 },
      name: 'updated_at_index'
    },
    
    // Type index (for filtering group vs private chats)
    {
      key: { type: 1 },
      name: 'type_index'
    },
    
    // Compound index for member + updated date (most common query)
    {
      key: { 
        members: 1,
        updatedAt: -1
      },
      name: 'member_updated_compound'
    },
    
    // Compound index for created by + type
    {
      key: { 
        createdBy: 1,
        type: 1
      },
      name: 'creator_type_compound'
    }
  ],
  
  // =============================================================================
  // MESSAGES COLLECTION INDEXES
  // =============================================================================
  messages: [
    // Chat ID index (for message retrieval)
    {
      key: { chatId: 1 },
      name: 'chat_id_index'
    },
    
    // Sender ID index (for user message queries)
    {
      key: { senderId: 1 },
      name: 'sender_id_index'
    },
    
    // Created date index (for message ordering)
    {
      key: { createdAt: -1 },
      name: 'created_at_index'
    },
    
    // Message type index (for filtering media vs text)
    {
      key: { type: 1 },
      name: 'type_index'
    },
    
    // Compound index for chat + created date (most common query)
    {
      key: { 
        chatId: 1,
        createdAt: -1
      },
      name: 'chat_created_compound'
    },
    
    // Compound index for sender + created date
    {
      key: { 
        senderId: 1,
        createdAt: -1
      },
      name: 'sender_created_compound'
    },
    
    // Compound index for chat + sender + created date
    {
      key: { 
        chatId: 1,
        senderId: 1,
        createdAt: -1
      },
      name: 'chat_sender_created_compound'
    },
    
    // Text search index for message content
    {
      key: { content: 'text' },
      name: 'content_text_search',
      default_language: 'english'
    }
  ],
  
  // =============================================================================
  // NOTIFICATIONS COLLECTION INDEXES
  // =============================================================================
  notifications: [
    // User ID index (for user notifications)
    {
      key: { userId: 1 },
      name: 'user_id_index'
    },
    
    // Read status index (for unread notifications)
    {
      key: { read: 1 },
      name: 'read_index'
    },
    
    // Created date index (for notification ordering)
    {
      key: { createdAt: -1 },
      name: 'created_at_index'
    },
    
    // Type index (for notification filtering)
    {
      key: { type: 1 },
      name: 'type_index'
    },
    
    // Compound index for user + read status + created date
    {
      key: { 
        userId: 1,
        read: 1,
        createdAt: -1
      },
      name: 'user_read_created_compound'
    }
  ],
  
  // =============================================================================
  // GROUPS COLLECTION INDEXES (if using separate groups collection)
  // =============================================================================
  groups: [
    // Admin IDs index (for admin queries)
    {
      key: { adminIds: 1 },
      name: 'admin_ids_index'
    },
    
    // Member IDs index (for member queries)
    {
      key: { memberIds: 1 },
      name: 'member_ids_index'
    },
    
    // Created date index
    {
      key: { createdAt: -1 },
      name: 'created_at_index'
    },
    
    // Name index for group search
    {
      key: { name: 'text' },
      name: 'name_text_search',
      default_language: 'english'
    }
  ]
};

// =============================================================================
// INDEX CREATION FUNCTIONS
// =============================================================================

/**
 * Create all indexes for a collection
 * @param {MongoClient} client - MongoDB client
 * @param {string} collectionName - Name of the collection
 * @param {Array} indexes - Array of index definitions
 */
async function createCollectionIndexes(client, collectionName, indexes) {
  const db = client.db('soc_chat_app');
  const collection = db.collection(collectionName);
  
  console.log(`📊 Creating indexes for collection: ${collectionName}`);
  
  for (const index of indexes) {
    try {
      await collection.createIndex(index.key, {
        unique: index.unique || false,
        name: index.name,
        default_language: index.default_language || 'english',
        background: true // Create indexes in background
      });
      console.log(`  ✅ Created index: ${index.name}`);
    } catch (error) {
      if (error.code === 85) {
        console.log(`  ⚠️  Index already exists: ${index.name}`);
      } else {
        console.error(`  ❌ Failed to create index ${index.name}:`, error.message);
      }
    }
  }
}

/**
 * Create all indexes for all collections
 */
async function createAllIndexes() {
  const client = new MongoClient(MONGO_URI);
  
  try {
    console.log('🔗 Connecting to MongoDB...');
    await client.connect();
    console.log('✅ Connected to MongoDB');
    
    // Create indexes for each collection
    for (const [collectionName, indexes] of Object.entries(INDEXES)) {
      await createCollectionIndexes(client, collectionName, indexes);
    }
    
    console.log('🎉 All indexes created successfully!');
    
  } catch (error) {
    console.error('❌ Error creating indexes:', error);
    process.exit(1);
  } finally {
    await client.close();
    console.log('🔌 Disconnected from MongoDB');
  }
}

/**
 * List all existing indexes
 */
async function listAllIndexes() {
  const client = new MongoClient(MONGO_URI);
  
  try {
    console.log('🔗 Connecting to MongoDB...');
    await client.connect();
    console.log('✅ Connected to MongoDB');
    
    const db = client.db('soc_chat_app');
    
    for (const collectionName of Object.keys(INDEXES)) {
      console.log(`\n📊 Indexes for collection: ${collectionName}`);
      const collection = db.collection(collectionName);
      const indexes = await collection.listIndexes().toArray();
      
      if (indexes.length === 0) {
        console.log('  No indexes found');
      } else {
        for (const index of indexes) {
          console.log(`  - ${index.name}: ${JSON.stringify(index.key)}`);
        }
      }
    }
    
  } catch (error) {
    console.error('❌ Error listing indexes:', error);
  } finally {
    await client.close();
    console.log('\n🔌 Disconnected from MongoDB');
  }
}

/**
 * Drop all custom indexes (keep only _id index)
 */
async function dropAllIndexes() {
  const client = new MongoClient(MONGO_URI);
  
  try {
    console.log('🔗 Connecting to MongoDB...');
    await client.connect();
    console.log('✅ Connected to MongoDB');
    
    const db = client.db('soc_chat_app');
    
    for (const collectionName of Object.keys(INDEXES)) {
      console.log(`\n🗑️  Dropping indexes for collection: ${collectionName}`);
      const collection = db.collection(collectionName);
      const indexes = await collection.listIndexes().toArray();
      
      for (const index of indexes) {
        if (index.name !== '_id_') { // Keep the default _id index
          try {
            await collection.dropIndex(index.name);
            console.log(`  ✅ Dropped index: ${index.name}`);
          } catch (error) {
            console.error(`  ❌ Failed to drop index ${index.name}:`, error.message);
          }
        }
      }
    }
    
    console.log('🎉 All custom indexes dropped successfully!');
    
  } catch (error) {
    console.error('❌ Error dropping indexes:', error);
  } finally {
    await client.close();
    console.log('🔌 Disconnected from MongoDB');
  }
}

// =============================================================================
// COMMAND LINE INTERFACE
// =============================================================================

async function main() {
  const command = process.argv[2];
  
  switch (command) {
    case 'create':
      await createAllIndexes();
      break;
    case 'list':
      await listAllIndexes();
      break;
    case 'drop':
      await dropAllIndexes();
      break;
    case 'help':
    case '--help':
    case '-h':
      console.log(`
📊 SOC Chat App - Database Index Manager

Usage: node database_indexes.js [command]

Commands:
  create    Create all indexes for optimal performance
  list      List all existing indexes
  drop      Drop all custom indexes (keep _id index)
  help      Show this help message

Examples:
  node database_indexes.js create
  node database_indexes.js list
  node database_indexes.js drop

Environment Variables:
  MONGO_URI    MongoDB connection URI (default: local connection)
      `);
      break;
    default:
      console.log('❌ Unknown command. Use "help" for usage information.');
      process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}

module.exports = {
  createAllIndexes,
  listAllIndexes,
  dropAllIndexes,
  INDEXES
};
