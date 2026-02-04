/**
 * Fix AI chats - Update AI bot ID in existing chats
 * Run this if AI chats were created with the wrong AI bot ID
 * 
 * Usage: node scripts/fix-ai-chats.js
 */

require('dotenv').config();
const { MongoClient, ObjectId } = require('mongodb');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017';
const DB_NAME = process.env.DB_NAME || 'soc_chat_app';

async function fixAIChats() {
  let client;
  
  try {
    console.log('🔧 Fixing AI chats...');
    console.log(`   MongoDB URI: ${MONGODB_URI}`);
    console.log(`   Database: ${DB_NAME}`);
    
    // Connect to MongoDB
    client = new MongoClient(MONGODB_URI);
    await client.connect();
    console.log('✅ Connected to MongoDB');
    
    const db = client.db(DB_NAME);
    const usersCollection = db.collection('users');
    const chatsCollection = db.collection('chats');
    
    // Get current AI bot ID
    const aiBot = await usersCollection.findOne({ role: 'ai_bot' });
    if (!aiBot) {
      console.log('❌ AI Bot user not found! Run create-ai-bot.js first.');
      return;
    }
    
    const currentAIBotId = aiBot._id.toString();
    console.log(`\n✅ Current AI Bot ID: ${currentAIBotId}`);
    
    // Find all chats that might have AI bot (private chats with 2 members)
    const allChats = await chatsCollection.find({ type: 'private' }).toArray();
    console.log(`\n📊 Found ${allChats.length} private chats`);
    
    let fixedCount = 0;
    let needsFixCount = 0;
    
    for (const chat of allChats) {
      const members = chat.members || [];
      
      // Check if this is an AI chat (has AI bot or has 2 members and one might be AI)
      if (members.length === 2) {
        const memberIds = members.map(m => m.toString());
        const hasCurrentAIBot = memberIds.includes(currentAIBotId);
        
        // Check if any member is an AI bot (old or new)
        const memberUsers = await Promise.all(
          members.map(m => usersCollection.findOne({ _id: m }))
        );
        
        const hasAnyAIBot = memberUsers.some(u => u && u.role === 'ai_bot');
        
        if (hasAnyAIBot && !hasCurrentAIBot) {
          // This chat has an old AI bot, needs to be updated
          needsFixCount++;
          console.log(`\n⚠️  Chat ${chat._id} has old AI bot`);
          console.log(`   Current members: ${memberIds.join(', ')}`);
          
          // Find old AI bot member
          const oldAIBotMember = memberUsers.find(u => u && u.role === 'ai_bot');
          if (oldAIBotMember) {
            const oldAIBotId = oldAIBotMember._id;
            console.log(`   Old AI bot ID: ${oldAIBotId}`);
            
            // Replace old AI bot with current AI bot
            await chatsCollection.updateOne(
              { _id: chat._id },
              { 
                $pull: { members: oldAIBotId },
                $addToSet: { members: new ObjectId(currentAIBotId) }
              }
            );
            
            // Update memberRoles if it exists
            if (chat.memberRoles) {
              const oldAIBotIdStr = oldAIBotId.toString();
              const newMemberRoles = { ...chat.memberRoles };
              if (newMemberRoles[oldAIBotIdStr]) {
                newMemberRoles[currentAIBotId] = newMemberRoles[oldAIBotIdStr];
                delete newMemberRoles[oldAIBotIdStr];
                
                await chatsCollection.updateOne(
                  { _id: chat._id },
                  { $set: { memberRoles: newMemberRoles } }
                );
              }
            }
            
            fixedCount++;
            console.log(`   ✅ Updated to use current AI bot ID: ${currentAIBotId}`);
          }
        } else if (hasCurrentAIBot) {
          console.log(`✅ Chat ${chat._id} already has correct AI bot`);
        }
      }
    }
    
    console.log(`\n📊 Summary:`);
    console.log(`   Chats checked: ${allChats.length}`);
    console.log(`   Chats needing fix: ${needsFixCount}`);
    console.log(`   Chats fixed: ${fixedCount}`);
    
    if (fixedCount > 0) {
      console.log(`\n✅ Fixed ${fixedCount} chat(s)!`);
    } else {
      console.log(`\n✅ All chats are already correct!`);
    }
    
  } catch (error) {
    console.error('❌ Error fixing AI chats:', error);
    process.exit(1);
  } finally {
    if (client) {
      await client.close();
      console.log('\n✅ Database connection closed');
    }
  }
}

// Run the script
fixAIChats().catch(console.error);
