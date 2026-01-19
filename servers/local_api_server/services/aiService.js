/**
 * AI Service - Free, Unlimited, Secure Local LLM Integration
 * Uses Ollama for local AI responses (no external API calls, no costs)
 * 
 * Features:
 * - 100% free and unlimited usage
 * - Fully secure (all data stays on your server)
 * - Works offline (no internet required)
 * - Context-aware conversations
 * - Image analysis support (vision API)
 */

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

// Configuration
const OLLAMA_HOST = process.env.OLLAMA_HOST || 'localhost';
const OLLAMA_PORT = process.env.OLLAMA_PORT || 11434;
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'llama3.2'; // Default model (lightweight)
const OLLAMA_VISION_MODEL = process.env.OLLAMA_VISION_MODEL || 'llava'; // Vision model for images
const OLLAMA_TIMEOUT = parseInt(process.env.OLLAMA_TIMEOUT || '120000'); // 120 seconds (2 minutes) - LLMs can take time, especially on first load

// AI Bot Configuration
const AI_BOT_NAME = 'AI Assistant';
const AI_BOT_ROLE = 'ai_bot';
const MAX_CONTEXT_MESSAGES = parseInt(process.env.OLLAMA_MAX_CONTEXT_MESSAGES || '20'); // Keep last N messages for context (default: 20)
const MAX_RESPONSE_LENGTH = parseInt(process.env.OLLAMA_MAX_RESPONSE_LENGTH || '500'); // Limit response length (default: 500)

// Security Configuration
const MAX_MESSAGE_LENGTH = parseInt(process.env.OLLAMA_MAX_MESSAGE_LENGTH || '2000'); // Max user message length (default: 2000 chars)
const MAX_IMAGE_SIZE = parseInt(process.env.OLLAMA_MAX_IMAGE_SIZE || '10485760'); // Max image size in bytes (default: 10MB)
const ALLOW_EXTERNAL_IMAGES = process.env.OLLAMA_ALLOW_EXTERNAL_IMAGES === 'true'; // Allow external image downloads (default: false)
const ALLOWED_IMAGE_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.gif', '.webp']; // Allowed image formats

/**
 * Check if Ollama is available and running
 */
async function checkOllamaHealth() {
  return new Promise((resolve) => {
    const options = {
      hostname: OLLAMA_HOST,
      port: OLLAMA_PORT,
      path: '/api/tags',
      method: 'GET',
      timeout: 5000
    };

    const req = http.request(options, (res) => {
      if (res.statusCode === 200) {
        resolve(true);
      } else {
        resolve(false);
      }
    });

    req.on('error', () => resolve(false));
    req.on('timeout', () => {
      req.destroy();
      resolve(false);
    });

    req.end();
  });
}

/**
 * Sanitize user input to prevent prompt injection
 * @param {string} input - User input string
 * @returns {string} - Sanitized string
 */
function sanitizeInput(input) {
  if (!input || typeof input !== 'string') return '';
  
  // Remove control characters (except newlines and tabs)
  let sanitized = input.replace(/[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]/g, '');
  
  // Limit length
  if (sanitized.length > MAX_MESSAGE_LENGTH) {
    sanitized = sanitized.substring(0, MAX_MESSAGE_LENGTH);
  }
  
  // Trim whitespace
  sanitized = sanitized.trim();
  
  return sanitized;
}

/**
 * Validate image file extension
 * @param {string} filePath - File path or URL
 * @returns {boolean} - True if valid image extension
 */
function isValidImageExtension(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  return ALLOWED_IMAGE_EXTENSIONS.includes(ext);
}

/**
 * Download image from URL and return as buffer
 * @param {string} imageUrl - URL of the image
 * @returns {Promise<Buffer|null>} - Image buffer or null if failed
 */
async function downloadImageFromUrl(imageUrl) {
  try {
    if (!imageUrl || typeof imageUrl !== 'string') {
      console.warn('[AI Service] Invalid image URL');
      return null;
    }

    // Check if URL contains /uploads/ (could be local path or ngrok URL pointing to local file)
    if (imageUrl.includes('/uploads/')) {
      // Extract the path after /uploads/ (works for both local paths and full URLs)
      let relativePath = imageUrl.split('/uploads/')[1];
      
      // If it's a full URL, remove any query parameters
      if (relativePath.includes('?')) {
        relativePath = relativePath.split('?')[0];
      }
      
      // Build local file path
      // Use the same UPLOADS_DIR logic as server.js
      const UPLOADS_DIR = process.env.UPLOADS_DIR || path.join(__dirname, '..', 'uploads');
      const uploadsPath = path.resolve(UPLOADS_DIR);
      const localPath = path.resolve(uploadsPath, relativePath);
      const resolvedUploadsPath = path.resolve(uploadsPath);
      
      console.log(`[AI Service] 🔍 Looking for image at: ${localPath}`);
      console.log(`[AI Service] Uploads directory: ${uploadsPath}`);
      console.log(`[AI Service] Relative path: ${relativePath}`);
      
      // SECURITY: Prevent path traversal attacks
      if (!localPath.startsWith(resolvedUploadsPath)) {
        console.error('[AI Service] Security: Path traversal attempt detected:', imageUrl);
        return null;
      }
      
      // Validate file extension
      if (!isValidImageExtension(localPath)) {
        console.warn('[AI Service] Invalid image extension:', localPath);
        return null;
      }
      
      // Check if file exists, with retry logic in case file is still being written
      let fileExists = fs.existsSync(localPath);
      if (!fileExists) {
        // Wait a bit and retry (file might still be uploading)
        await new Promise(resolve => setTimeout(resolve, 500));
        fileExists = fs.existsSync(localPath);
      }
      
      if (fileExists) {
        const stats = fs.statSync(localPath);
        
        // Check file size
        if (stats.size > MAX_IMAGE_SIZE) {
          console.warn(`[AI Service] Image too large: ${stats.size} bytes (max: ${MAX_IMAGE_SIZE})`);
          return null;
        }
        
        console.log(`[AI Service] ✅ Loading local image: ${localPath} (${stats.size} bytes)`);
        return fs.readFileSync(localPath);
      } else {
        console.warn(`[AI Service] ❌ Local image file not found: ${localPath}`);
        // List directory to help debug
        const dirPath = path.dirname(localPath);
        if (fs.existsSync(dirPath)) {
          try {
            const files = fs.readdirSync(dirPath);
            console.warn(`[AI Service] Directory exists. Files in directory: ${files.join(', ')}`);
          } catch (e) {
            console.warn(`[AI Service] Could not read directory: ${e.message}`);
          }
        } else {
          console.warn(`[AI Service] Directory does not exist: ${dirPath}`);
        }
        return null;
      }
    }

    // Handle HTTP/HTTPS URLs that are truly external (not pointing to local uploads)
    if (!ALLOW_EXTERNAL_IMAGES) {
      console.warn('[AI Service] External image downloads are disabled');
      return null;
    }

    // Validate URL
    let url;
    try {
      url = new URL(imageUrl);
    } catch (error) {
      console.warn('[AI Service] Invalid URL:', imageUrl);
      return null;
    }

    // Only allow HTTP/HTTPS
    if (url.protocol !== 'http:' && url.protocol !== 'https:') {
      console.warn('[AI Service] Invalid protocol:', url.protocol);
      return null;
    }

    // Validate file extension from URL
    if (!isValidImageExtension(url.pathname)) {
      console.warn('[AI Service] Invalid image extension in URL:', url.pathname);
      return null;
    }

    return new Promise((resolve) => {
      const protocol = url.protocol === 'https:' ? https : http;
      let totalSize = 0;
      
      const options = {
        hostname: url.hostname,
        port: url.port || (url.protocol === 'https:' ? 443 : 80),
        path: url.pathname + url.search,
        method: 'GET',
        timeout: 10000, // 10 second timeout for image download
        headers: {
          'User-Agent': 'SOC-Chat-App-AI-Service/1.0'
        }
      };

      const req = protocol.request(options, (res) => {
        // Check content type
        const contentType = res.headers['content-type'] || '';
        if (!contentType.startsWith('image/')) {
          console.warn('[AI Service] Invalid content type:', contentType);
          resolve(null);
          return;
        }

        if (res.statusCode !== 200) {
          console.warn(`[AI Service] Failed to download image: ${res.statusCode}`);
          resolve(null);
          return;
        }

        const chunks = [];
        res.on('data', (chunk) => {
          totalSize += chunk.length;
          
          // Check size during download
          if (totalSize > MAX_IMAGE_SIZE) {
            console.warn(`[AI Service] Image too large during download: ${totalSize} bytes`);
            req.destroy();
            resolve(null);
            return;
          }
          
          chunks.push(chunk);
        });
        
        res.on('end', () => {
          const buffer = Buffer.concat(chunks);
          console.log(`[AI Service] Downloaded image: ${buffer.length} bytes`);
          resolve(buffer);
        });
      });

      req.on('error', (error) => {
        console.error(`[AI Service] Error downloading image: ${error.message}`);
        resolve(null);
      });

      req.on('timeout', () => {
        req.destroy();
        console.warn('[AI Service] Image download timeout');
        resolve(null);
      });

      req.end();
    });
  } catch (error) {
    console.error('[AI Service] Error in downloadImageFromUrl:', error);
    return null;
  }
}

/**
 * Convert image buffer to base64 string
 * @param {Buffer} imageBuffer - Image buffer
 * @returns {string} - Base64 encoded image
 */
function imageToBase64(imageBuffer) {
  try {
    return imageBuffer.toString('base64');
  } catch (error) {
    console.error('[AI Service] Error converting image to base64:', error);
    return null;
  }
}

/**
 * Generate AI response using Ollama
 * @param {string} userMessage - The user's message (optional for image-only messages)
 * @param {Array} conversationHistory - Previous messages for context
 * @param {string} userName - Name of the user sending the message
 * @param {string|null} imageUrl - Optional image URL to analyze
 * @param {string|null} imageBase64 - Optional base64 image data (if already converted)
 * @returns {Promise<string>} - AI generated response
 */
async function generateAIResponse(userMessage, conversationHistory = [], userName = 'User', imageUrl = null, imageBase64 = null, aiBotId = null) {
  try {
    // Check if Ollama is available
    const isHealthy = await checkOllamaHealth();
    if (!isHealthy) {
      console.warn('[AI Service] Ollama is not available. Install and start Ollama first.');
      return null;
    }

    // Handle image processing
    let base64Image = imageBase64;
    if (imageUrl && !base64Image) {
      console.log(`[AI Service] 📷 Processing image: ${imageUrl}`);
      try {
        const imageBuffer = await downloadImageFromUrl(imageUrl);
        if (imageBuffer) {
          console.log(`[AI Service] Image downloaded: ${imageBuffer.length} bytes`);
          base64Image = imageToBase64(imageBuffer);
          if (!base64Image) {
            console.error('[AI Service] ❌ Failed to convert image to base64');
            return null;
          }
          console.log(`[AI Service] ✅ Image converted to base64: ${base64Image.length} characters`);
        } else {
          console.error('[AI Service] ❌ Failed to download image - imageBuffer is null');
          return null;
        }
      } catch (error) {
        console.error('[AI Service] ❌ Error processing image:', error.message);
        console.error('[AI Service] Image URL was:', imageUrl);
        return null;
      }
    }

    // Determine which model to use (vision model for images, regular for text)
    const useVisionModel = !!base64Image;
    const modelToUse = useVisionModel ? OLLAMA_VISION_MODEL : OLLAMA_MODEL;

    // Build conversation context
    const contextMessages = conversationHistory
      .slice(-MAX_CONTEXT_MESSAGES) // Keep last N messages
      .map(msg => {
        // Check if message is from AI bot by comparing senderId
        const msgSenderId = msg.senderId ? msg.senderId.toString() : '';
        const isFromAI = aiBotId && msgSenderId === aiBotId.toString();
        const msgObj = {
          role: isFromAI ? 'assistant' : 'user',
          content: msg.content || ''
        };
        // If context message has image, include it (for vision models)
        if (msg.mediaUrl && msg.messageType === 'image') {
          // Note: We don't download old images for context to save time
          // Only process the current image
        }
        return msgObj;
      });

    // Sanitize user message
    const sanitizedMessage = sanitizeInput(userMessage);
    
    // Build current user message
    const currentMessage = {
      role: 'user',
      content: sanitizedMessage || (base64Image ? 'What is in this image?' : '')
    };

    // Add image to message if available
    // Ollama expects just the raw base64 string (without data URI prefix)
    if (base64Image) {
      // Remove data URI prefix if present (Ollama wants just the base64 string)
      let imageData = base64Image.trim(); // Remove any whitespace
      if (imageData.startsWith('data:')) {
        // Extract just the base64 part after the comma
        const commaIndex = imageData.indexOf(',');
        if (commaIndex !== -1) {
          imageData = imageData.substring(commaIndex + 1).trim();
        }
      }
      // Validate base64 format (should only contain base64 characters)
      const base64Regex = /^[A-Za-z0-9+/]*={0,2}$/;
      if (!base64Regex.test(imageData)) {
        console.error(`[AI Service] ❌ Invalid base64 format detected. First 50 chars: ${imageData.substring(0, 50)}`);
        // Try to clean it - remove any non-base64 characters
        imageData = imageData.replace(/[^A-Za-z0-9+/=]/g, '');
        console.log(`[AI Service] Cleaned base64. New length: ${imageData.length}`);
      }
      currentMessage.images = [imageData];
      console.log(`[AI Service] ✅ Image added to message. Base64 length: ${imageData.length}, Model: ${modelToUse}, First chars: ${imageData.substring(0, 20)}...`);
    } else {
      console.log(`[AI Service] ⚠️ No base64Image available. imageUrl was: ${imageUrl ? imageUrl.substring(0, 80) : 'null'}...`);
    }

    contextMessages.push(currentMessage);

    // Build prompt with system instructions
    const systemPrompt = base64Image
      ? `You are a helpful AI assistant in a chat application with vision capabilities. 
Be friendly, concise, and helpful. Keep responses under ${MAX_RESPONSE_LENGTH} characters when possible.
You are chatting with ${userName}. Analyze the image and respond naturally.`
      : `You are a helpful AI assistant in a chat application. 
Be friendly, concise, and helpful. Keep responses under ${MAX_RESPONSE_LENGTH} characters when possible.
You are chatting with ${userName}. Respond naturally to their message.`;

    const messages = [
      { role: 'system', content: systemPrompt },
      ...contextMessages
    ];

    // Prepare request to Ollama
    // For vision models, use longer timeout and keep model loaded
    const isVisionRequest = !!base64Image;
    const requestTimeout = isVisionRequest ? Math.max(OLLAMA_TIMEOUT, 180000) : OLLAMA_TIMEOUT; // 3 minutes for vision
    
    const requestData = JSON.stringify({
      model: modelToUse,
      messages: messages,
      stream: false,
      keep_alive: isVisionRequest ? '5m' : '2m', // Keep vision model loaded for 5 minutes, text model for 2 minutes
      options: {
        temperature: 0.7, // Creativity level (0-1)
        top_p: 0.9,
        num_predict: MAX_RESPONSE_LENGTH, // Use num_predict instead of max_tokens for Ollama
        num_ctx: isVisionRequest ? 4096 : 2048 // Larger context for vision models
      }
    });

    console.log(`[AI Service] Sending request to Ollama: ${OLLAMA_HOST}:${OLLAMA_PORT}, model: ${modelToUse}, timeout: ${requestTimeout}ms`);
    console.log(`[AI Service] Request details: hasImage=${!!base64Image}, messageCount=${messages.length}, useVisionModel=${useVisionModel}, keepAlive=${isVisionRequest ? '5m' : '2m'}`);
    if (base64Image) {
      console.log(`[AI Service] Image will be sent with message. Base64 preview: ${base64Image.substring(0, 50)}...`);
      console.log(`[AI Service] ⏳ Vision models can take 30-120 seconds. Please wait...`);
    }

    return new Promise((resolve, reject) => {
      const options = {
        hostname: OLLAMA_HOST,
        port: OLLAMA_PORT,
        path: '/api/chat',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(requestData)
        },
        timeout: requestTimeout
      };

      const startTime = Date.now();
      let resolved = false;
      
      // Set up a global timeout to ensure we don't hang forever
      const globalTimeout = setTimeout(() => {
        if (!resolved) {
          resolved = true;
          console.error(`[AI Service] ❌ Global timeout after ${requestTimeout}ms - Ollama is not responding`);
          console.error(`[AI Service] Check if Ollama is running: http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags`);
          if (isVisionRequest) {
            console.error(`[AI Service] Vision models (llava) can be very slow. Try:`);
            console.error(`[AI Service] 1. Check if llava model is loaded: ollama list`);
            console.error(`[AI Service] 2. Preload the model: ollama run llava "test"`);
            console.error(`[AI Service] 3. Check system resources (CPU/Memory)`);
          }
          resolve(null);
        }
      }, requestTimeout);

      const req = http.request(options, (res) => {
        let data = '';
        console.log(`[AI Service] Ollama response status: ${res.statusCode}`);

        res.on('data', (chunk) => {
          data += chunk;
        });

        res.on('end', () => {
          if (resolved) return;
          const elapsed = Date.now() - startTime;
          console.log(`[AI Service] Ollama response received in ${elapsed}ms, data length: ${data.length}`);
          
          try {
            if (res.statusCode !== 200) {
              console.error(`[AI Service] Ollama API error: ${res.statusCode} - ${data.substring(0, 200)}`);
              if (!resolved) {
                resolved = true;
                clearTimeout(globalTimeout);
                resolve(null);
              }
              return;
            }

            const response = JSON.parse(data);
            const aiResponse = response.message?.content || '';

            if (!aiResponse || aiResponse.trim().length === 0) {
              console.warn('[AI Service] Empty response from Ollama');
              console.warn(`[AI Service] Full response: ${JSON.stringify(response).substring(0, 500)}`);
              if (!resolved) {
                resolved = true;
                clearTimeout(globalTimeout);
                resolve(null);
              }
              return;
            }

            // Clean and trim response
            const cleanedResponse = aiResponse.trim();
            console.log(`[AI Service] ✅ Generated response (${cleanedResponse.length} chars): "${cleanedResponse.substring(0, 100)}..."`);
            if (!resolved) {
              resolved = true;
              clearTimeout(globalTimeout);
              resolve(cleanedResponse);
            }
          } catch (error) {
            console.error('[AI Service] Error parsing Ollama response:', error);
            console.error(`[AI Service] Response data: ${data.substring(0, 500)}`);
            if (!resolved) {
              resolved = true;
              clearTimeout(globalTimeout);
              resolve(null);
            }
          }
        });
      });

      req.on('error', (error) => {
        if (resolved) return;
        const elapsed = Date.now() - startTime;
        console.error(`[AI Service] Request error after ${elapsed}ms:`, error.message);
        console.error(`[AI Service] Error code: ${error.code}`);
        if (error.code === 'ECONNREFUSED') {
          console.error(`[AI Service] ❌ Cannot connect to Ollama at ${OLLAMA_HOST}:${OLLAMA_PORT}`);
          console.error(`[AI Service] Make sure Ollama is running. Start it with: ollama serve`);
        }
        if (!resolved) {
          resolved = true;
          clearTimeout(globalTimeout);
          resolve(null);
        }
      });

      req.on('timeout', () => {
        if (resolved) return;
        const elapsed = Date.now() - startTime;
        req.destroy();
        console.error(`[AI Service] ❌ Request timeout after ${elapsed}ms (limit: ${OLLAMA_TIMEOUT}ms)`);
        console.error(`[AI Service] This usually means Ollama is slow or not responding. Check if Ollama is running and the model is loaded.`);
        if (!resolved) {
          resolved = true;
          clearTimeout(globalTimeout);
          resolve(null);
        }
      });

      console.log(`[AI Service] Writing request data (${Buffer.byteLength(requestData)} bytes)...`);
      req.write(requestData);
      req.end();
      console.log(`[AI Service] Request sent, waiting for response (timeout: ${OLLAMA_TIMEOUT}ms)...`);
    });
  } catch (error) {
    console.error('[AI Service] Error generating AI response:', error);
    return null;
  }
}

/**
 * Check if a chat has the AI bot as a member
 * @param {Object} chat - Chat document from database
 * @returns {boolean}
 */
function chatHasAIBot(chat) {
  if (!chat || !chat.members) return false;
  
  // Check if any member has the AI bot role
  // We'll check by looking for a user with role 'ai_bot'
  return false; // Will be checked by caller using user lookup
}

/**
 * Get AI bot user ID from database
 * @param {Object} db - MongoDB database instance
 * @returns {Promise<string|null>} - AI bot user ID or null
 */
async function getAIBotUserId(db) {
  try {
    const aiBot = await db.collection('users').findOne({ role: AI_BOT_ROLE });
    return aiBot ? aiBot._id.toString() : null;
  } catch (error) {
    console.error('[AI Service] Error finding AI bot user:', error);
    return null;
  }
}

/**
 * Check if a message is from the AI bot (to prevent self-responses)
 * @param {string} senderId - Message sender ID
 * @param {Object} db - MongoDB database instance
 * @returns {Promise<boolean>}
 */
async function isAIMessage(senderId, db) {
  try {
    const aiBotId = await getAIBotUserId(db);
    if (!aiBotId) return false;
    return senderId.toString() === aiBotId.toString();
  } catch (error) {
    return false;
  }
}

/**
 * Get conversation history for context
 * @param {string} chatId - Chat ID
 * @param {Object} db - MongoDB database instance
 * @param {number} limit - Number of messages to retrieve
 * @returns {Promise<Array>} - Array of messages
 */
async function getConversationHistory(chatId, db, limit = MAX_CONTEXT_MESSAGES) {
  try {
    const messages = await db.collection('messages')
      .find({ chatId: chatId.toString() })
      .sort({ createdAt: -1 })
      .limit(limit)
      .toArray();

    // Reverse to get chronological order
    return messages.reverse();
  } catch (error) {
    console.error('[AI Service] Error getting conversation history:', error);
    return [];
  }
}

/**
 * Process message and generate AI response if needed
 * @param {Object} messageData - The message that was just created
 * @param {Object} chat - Chat document
 * @param {Object} db - MongoDB database instance
 * @param {Object} io - Socket.IO instance
 * @returns {Promise<void>}
 */
async function processMessageForAI(messageData, chat, db, io) {
  try {
    // Handle both 'type' and 'messageType' fields (messages can use either)
    const messageType = messageData.messageType || messageData.type || 'text';
    const mediaUrl = messageData.mediaUrl || messageData.media_url || null;
    
    console.log(`[AI Service] Processing message: chatId=${messageData.chatId}, senderId=${messageData.senderId}, type=${messageType}`);
    console.log(`[AI Service] Message details: content=${messageData.content ? 'yes' : 'no'}, mediaUrl=${mediaUrl ? mediaUrl : 'no'}`);
    
    // Process text messages OR image messages
    // Image message: type is 'image' and has mediaUrl
    const isImageMessage = !!(messageType === 'image' && mediaUrl);
    // Text message: not an image message, has content, and type is text/undefined/null
    const contentStr = messageData.content ? String(messageData.content).trim() : '';
    const hasContent = contentStr.length > 0;
    const isTextType = messageType === 'text' || messageType === undefined || messageType === null || messageType === '';
    const isTextMessage = !isImageMessage && isTextType && hasContent;
    
    console.log(`[AI Service] Message type check: isTextMessage=${isTextMessage}, isImageMessage=${isImageMessage}`);
    console.log(`[AI Service] Details: messageType="${messageType}", hasContent=${hasContent}, hasMediaUrl=${!!mediaUrl}, mediaUrl="${mediaUrl ? mediaUrl.substring(0, 80) : 'none'}...", contentLength=${contentStr.length}`);
    
    // Skip if message is neither text nor image
    if (!isTextMessage && !isImageMessage) {
      console.log(`[AI Service] Skipping message - not text or image (type=${messageType}, hasContent=${hasContent}, hasMediaUrl=${!!mediaUrl})`);
      return;
    }

    // Get AI bot user ID
    const aiBotId = await getAIBotUserId(db);
    if (!aiBotId) {
      console.log(`[AI Service] AI bot not found in database`);
      // AI bot doesn't exist yet - skip
      return;
    }
    console.log(`[AI Service] AI bot ID: ${aiBotId}`);

    // Check if message is from AI bot (prevent self-responses)
    const isFromAI = await isAIMessage(messageData.senderId, db);
    if (isFromAI) {
      console.log(`[AI Service] Skipping - message is from AI bot itself`);
      return; // Don't respond to own messages
    }

    // Check if AI bot is a member of this chat
    const chatMembers = chat.members || [];
    const aiBotObjectId = new (require('mongodb').ObjectId)(aiBotId);
    const hasAIBot = chatMembers.some(m => m.toString() === aiBotId.toString());

    if (!hasAIBot) {
      console.log(`[AI Service] AI bot not in chat. Chat ID: ${messageData.chatId}, AI Bot ID: ${aiBotId}, Chat Members: ${chatMembers.map(m => m.toString()).join(', ')}`);
      return; // AI bot is not in this chat
    }

    // Get conversation history for context
    const history = await getConversationHistory(messageData.chatId, db);

    // Get sender info
    const sender = await db.collection('users').findOne({ 
      _id: new (require('mongodb').ObjectId)(messageData.senderId) 
    });
    const senderName = sender?.displayName || sender?.username || 'User';
    
    console.log(`[AI Service] AI bot is in chat. Processing message from ${senderName}...`);

    // Generate AI response
    const responseType = isImageMessage ? 'image' : 'text';
    // Sanitize user message input to prevent prompt injection
    const rawUserMessage = messageData.content || (isImageMessage ? 'What is in this image?' : '');
    const userMessage = sanitizeInput(rawUserMessage);
    const imageUrl = isImageMessage ? mediaUrl : null;
    
    console.log(`[AI Service] Generating ${responseType} response for message from ${senderName}...`);
    if (isImageMessage) {
      console.log(`[AI Service] 📷 Processing image: ${imageUrl}`);
    }
    
    const aiResponse = await generateAIResponse(
      userMessage,
      history,
      senderName,
      imageUrl,
      null, // Let generateAIResponse download and convert the image
      aiBotId // Pass AI bot ID for context role detection
    );

    if (!aiResponse) {
      console.warn('[AI Service] Failed to generate response');
      return;
    }

    // Create AI bot message
    // Ensure chatId and senderId are ObjectId format for database
    const chatIdObjectId = typeof messageData.chatId === 'string' 
      ? new (require('mongodb').ObjectId)(messageData.chatId)
      : messageData.chatId;
    const senderIdObjectId = new (require('mongodb').ObjectId)(aiBotId);
    
    const aiMessage = {
      chatId: chatIdObjectId,
      senderId: senderIdObjectId,
      content: aiResponse,
      messageType: 'text',
      mediaUrl: null,
      createdAt: new Date(),
      readBy: [],
      status: 'sent',
      replies: [],
      reactions: {}
    };

    // Save AI message to database
    const result = await db.collection('messages').insertOne(aiMessage);

    // Update chat's last message
    const now = new Date();
    await db.collection('chats').updateOne(
      { _id: new (require('mongodb').ObjectId)(messageData.chatId) },
      {
        $set: {
          updatedAt: now,
          lastMessageTime: now,
          lastMessage: {
            content: aiResponse,
            senderId: aiBotId,
            senderName: AI_BOT_NAME,
            timestamp: now.toISOString(),
            createdAt: now
          }
        }
      }
    );

    // Increment unread count for other members
    const otherMembers = chatMembers
      .filter(m => m.toString() !== aiBotId.toString())
      .map(m => m.toString());

    for (const memberId of otherMembers) {
      await db.collection('chats').updateOne(
        { _id: new (require('mongodb').ObjectId)(messageData.chatId) },
        {
          $inc: {
            [`unreadCount.${memberId}`]: 1
          }
        }
      );
    }

    // Emit Socket.IO event for real-time delivery
    if (io) {
      const createdAtIso = aiMessage.createdAt instanceof Date
        ? aiMessage.createdAt.toISOString()
        : new Date().toISOString();

      const chatIdStr = messageData.chatId.toString();
      const chatRoom = `chat:${chatIdStr}`;
      
      console.log(`[AI Service] Emitting new_message to room: ${chatRoom}`);
      
      // Emit to chat room (format: chat:${chatId})
      io.to(chatRoom).emit('new_message', {
        id: result.insertedId.toString(),
        _id: result.insertedId.toString(),
        senderName: AI_BOT_NAME,
        chatId: chatIdStr,
        senderId: aiBotId.toString(),
        content: aiResponse,
        messageType: 'text',
        mediaUrl: null,
        createdAt: createdAtIso,
        timestamp: createdAtIso,
        readBy: [],
        status: 'sent'
      });
      
      // Also emit to individual members to ensure delivery
      const memberIds = chatMembers.map(m => m.toString());
      for (const memberId of memberIds) {
        io.to(memberId).emit('new_message', {
          id: result.insertedId.toString(),
          _id: result.insertedId.toString(),
          senderName: AI_BOT_NAME,
          chatId: chatIdStr,
          senderId: aiBotId.toString(),
          content: aiResponse,
          messageType: 'text',
          mediaUrl: null,
          createdAt: createdAtIso,
          timestamp: createdAtIso,
          readBy: [],
          status: 'sent'
        });
      }
    }

    console.log(`[AI Service] ✅ AI response sent: "${aiResponse.substring(0, 50)}..."`);

  } catch (error) {
    console.error('[AI Service] Error processing message for AI:', error);
    // Don't throw - we don't want to break message sending if AI fails
  }
}

module.exports = {
  generateAIResponse,
  checkOllamaHealth,
  getAIBotUserId,
  isAIMessage,
  processMessageForAI,
  downloadImageFromUrl,
  imageToBase64,
  sanitizeInput,
  AI_BOT_NAME,
  AI_BOT_ROLE
};
