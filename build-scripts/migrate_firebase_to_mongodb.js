// Firebase to MongoDB Migration Script
// This script migrates data from Firebase to a local MongoDB instance

const admin = require('firebase-admin');
const { MongoClient } = require('mongodb');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

// Configuration
const config = {
  mongoUri: 'mongodb://localhost:27017/soc_chat_app',
  batchSize: 500,
  collections: ['users', 'chats', 'messages', 'notifications', 'settings'],
  serviceAccountPath: path.join(__dirname, '..', 'config', 'service-account.json')
};

// Check if service account file exists
if (!fs.existsSync(config.serviceAccountPath)) {
  console.error(`Service account file not found at ${config.serviceAccountPath}`);
  console.log('Please place your Firebase service account JSON file at this location.');
  process.exit(1);
}

// Initialize Firebase Admin SDK
try {
  const serviceAccount = require(config.serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log('Firebase Admin SDK initialized successfully');
} catch (error) {
  console.error('Failed to initialize Firebase Admin SDK:', error);
  process.exit(1);
}

// MongoDB client
let mongoClient;
let db;

// Connect to MongoDB
async function connectToMongo() {
  try {
    mongoClient = new MongoClient(config.mongoUri);
    await mongoClient.connect();
    db = mongoClient.db();
    console.log('Connected to MongoDB');
    return true;
  } catch (error) {
    console.error('MongoDB connection error:', error);
    return false;
  }
}

// Disconnect from MongoDB
async function disconnectFromMongo() {
  if (mongoClient) {
    await mongoClient.close();
    console.log('Disconnected from MongoDB');
  }
}

// Helper function to convert Firebase Timestamp to Date
function convertTimestamps(obj) {
  if (!obj) return obj;
  
  const newObj = { ...obj };
  
  Object.keys(newObj).forEach(key => {
    const value = newObj[key];
    
    // Convert Firebase Timestamp to Date
    if (value && typeof value === 'object' && value._seconds !== undefined && value._nanoseconds !== undefined) {
      newObj[key] = new Date(value._seconds * 1000 + value._nanoseconds / 1000000);
    } 
    // Handle nested objects
    else if (value && typeof value === 'object' && !Array.isArray(value)) {
      newObj[key] = convertTimestamps(value);
    } 
    // Handle arrays
    else if (Array.isArray(value)) {
      newObj[key] = value.map(item => {
        if (item && typeof item === 'object') {
          return convertTimestamps(item);
        }
        return item;
      });
    }
  });
  
  return newObj;
}

// Migrate a single collection
async function migrateCollection(collectionName) {
  console.log(`\nMigrating collection: ${collectionName}`);
  
  try {
    const firestore = admin.firestore();
    const mongoCollection = db.collection(collectionName);
    
    // Check if MongoDB collection already has data
    const count = await mongoCollection.countDocuments();
    if (count > 0) {
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
      });
      
      const answer = await new Promise(resolve => {
        rl.question(`Collection ${collectionName} already has ${count} documents. Do you want to replace them? (y/n): `, resolve);
      });
      
      rl.close();
      
      if (answer.toLowerCase() !== 'y') {
        console.log(`Skipping collection: ${collectionName}`);
        return;
      }
      
      // Clear existing data
      await mongoCollection.deleteMany({});
      console.log(`Cleared existing data from ${collectionName}`);
    }
    
    // Get all documents from Firebase
    const snapshot = await firestore.collection(collectionName).get();
    const totalDocs = snapshot.size;
    
    if (totalDocs === 0) {
      console.log(`No documents found in ${collectionName}`);
      return;
    }
    
    console.log(`Found ${totalDocs} documents in ${collectionName}`);
    
    // Process documents in batches
    const documents = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      // Convert Firebase document to MongoDB document
      const mongoDoc = {
        _id: doc.id,
        ...convertTimestamps(data)
      };
      documents.push(mongoDoc);
    });
    
    // Insert documents in batches
    for (let i = 0; i < documents.length; i += config.batchSize) {
      const batch = documents.slice(i, i + config.batchSize);
      await mongoCollection.insertMany(batch, { ordered: false }).catch(err => {
        console.error(`Error inserting batch in ${collectionName}:`, err.message);
      });
      console.log(`Migrated ${Math.min(i + config.batchSize, documents.length)} / ${documents.length} documents`);
    }
    
    console.log(`Successfully migrated ${documents.length} documents to ${collectionName}`);
  } catch (error) {
    console.error(`Error migrating collection ${collectionName}:`, error);
  }
}

// Main migration function
async function migrateData() {
  console.log('Starting Firebase to MongoDB migration...');
  
  const connected = await connectToMongo();
  if (!connected) {
    console.error('Failed to connect to MongoDB. Exiting...');
    process.exit(1);
  }
  
  // Migrate each collection
  for (const collection of config.collections) {
    await migrateCollection(collection);
  }
  
  // Disconnect from MongoDB
  await disconnectFromMongo();
  
  console.log('\nMigration completed!');
}

// Run migration
migrateData().catch(error => {
  console.error('Migration failed:', error);
  disconnectFromMongo().then(() => process.exit(1));
});