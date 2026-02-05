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
// IMPORTANT: On Windows, "localhost" may resolve to IPv6 (::1) first.
// Many local services (including Ollama) may only listen on 127.0.0.1, causing intermittent "not available".
const OLLAMA_HOST = process.env.OLLAMA_HOST || '127.0.0.1';
const OLLAMA_PORT = process.env.OLLAMA_PORT || 11434;
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'llama3.2'; // Default model (lightweight)
const OLLAMA_VISION_MODEL = process.env.OLLAMA_VISION_MODEL || 'llava'; // Vision model for images
const OLLAMA_TIMEOUT = parseInt(process.env.OLLAMA_TIMEOUT || '120000'); // 120 seconds (2 minutes) - LLMs can take time, especially on first load
// Limit CPU usage so the whole PC/server doesn't freeze under load (especially on Windows)
const OLLAMA_NUM_THREAD = Math.max(1, parseInt(process.env.OLLAMA_NUM_THREAD || '2', 10) || 2);
const OLLAMA_TEXT_CTX = Math.max(256, parseInt(process.env.OLLAMA_TEXT_CTX || '1024', 10) || 1024);
const OLLAMA_VISION_CTX = Math.max(512, parseInt(process.env.OLLAMA_VISION_CTX || '2048', 10) || 2048);
// Caps generation length (tokens). Smaller = faster, less chance of timeouts.
const OLLAMA_NUM_PREDICT = Math.max(16, parseInt(process.env.OLLAMA_NUM_PREDICT || '64', 10) || 64);
// Prefer non-streaming by default (simpler + more reliable). Enable only if you need token streaming.
const OLLAMA_STREAM = process.env.OLLAMA_STREAM === 'true';

// Quality tuning (defaults favor accuracy over creativity).
function clampNumber(n, min, max) {
  if (typeof n !== 'number' || Number.isNaN(n)) return min;
  return Math.min(max, Math.max(min, n));
}

const OLLAMA_TEMPERATURE = clampNumber(parseFloat(process.env.OLLAMA_TEMPERATURE ?? '0.2'), 0, 2);
const OLLAMA_TOP_P = clampNumber(parseFloat(process.env.OLLAMA_TOP_P ?? '0.9'), 0, 1);
const OLLAMA_TOP_K = Math.max(0, parseInt(process.env.OLLAMA_TOP_K ?? '40', 10) || 40);
const OLLAMA_REPEAT_PENALTY = clampNumber(parseFloat(process.env.OLLAMA_REPEAT_PENALTY ?? '1.1'), 0.8, 2.0);
const OLLAMA_REPEAT_LAST_N = Math.max(0, parseInt(process.env.OLLAMA_REPEAT_LAST_N ?? '64', 10) || 64);

// Reliability / Performance
// Keep the API server responsive even if Ollama is slow by limiting concurrency and deduping per chat.
const AI_DEBUG_LOGS = process.env.AI_DEBUG_LOGS === 'true';
const AI_MAX_CONCURRENT_JOBS = Math.max(1, parseInt(process.env.AI_MAX_CONCURRENT_JOBS || '1', 10) || 1);
const AI_MAX_QUEUE = Math.max(1, parseInt(process.env.AI_MAX_QUEUE || '100', 10) || 100);
const AI_DEDUP_PER_CHAT = process.env.AI_DEDUP_PER_CHAT !== 'false'; // default true

function logDebug(...args) {
  if (AI_DEBUG_LOGS) console.log(...args);
}

function createSemaphore(max) {
  let active = 0;
  const waiters = [];
  return {
    get active() { return active; },
    get queued() { return waiters.length; },
    async acquire() {
      if (active < max) {
        active += 1;
        return () => {
          active -= 1;
          const next = waiters.shift();
          if (next) next();
        };
      }
      if (waiters.length >= AI_MAX_QUEUE) {
        throw new Error(`AI queue is full (${AI_MAX_QUEUE}).`);
      }
      await new Promise(resolve => waiters.push(resolve));
      active += 1;
      return () => {
        active -= 1;
        const next = waiters.shift();
        if (next) next();
      };
    }
  };
}

const aiSemaphore = createSemaphore(AI_MAX_CONCURRENT_JOBS);
const perChatState = new Map(); // chatId(string) -> { running: boolean, pending: object|null }

function chatKey(chatId) {
  try { return String(chatId); } catch (_) { return 'unknown'; }
}

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

function getOllamaHostCandidates() {
  const h = String(OLLAMA_HOST || '').trim();
  if (!h) return ['127.0.0.1'];
  // Prefer IPv4 loopback if user configured "localhost" to avoid ::1 issues.
  if (h.toLowerCase() === 'localhost') return ['127.0.0.1', 'localhost'];
  return [h];
}

/**
 * Check if Ollama is available and running
 */
let cachedOllamaHealth = { ok: false, ts: 0 };
const HEALTH_CACHE_MS_OK = 3000;   // Cache success for 3s
const HEALTH_CACHE_MS_FAIL = 1000; // Cache failure for 1s (retry sooner)
async function checkOllamaHealth() {
  const candidates = getOllamaHostCandidates();
  return new Promise((resolve) => {
    const now = Date.now();
    const cacheMs = cachedOllamaHealth.ok ? HEALTH_CACHE_MS_OK : HEALTH_CACHE_MS_FAIL;
    if (now - cachedOllamaHealth.ts < cacheMs) {
      resolve(!!cachedOllamaHealth.ok);
      return;
    }
    let idx = 0;
    const tryNext = () => {
      const host = candidates[idx++];
      if (!host) {
        cachedOllamaHealth = { ok: false, ts: Date.now() };
        resolve(false);
        return;
      }

      const options = {
        hostname: host,
        port: OLLAMA_PORT,
        path: '/api/tags',
        method: 'GET',
        timeout: 4000
      };

      const req = http.request(options, (res) => {
        if (res.statusCode === 200) {
          cachedOllamaHealth = { ok: true, ts: Date.now() };
          resolve(true);
        } else {
          // Try other candidates before failing.
          req.destroy();
          tryNext();
        }
      });

      req.on('error', () => {
        tryNext();
      });
      req.on('timeout', () => {
        req.destroy();
        tryNext();
      });

      req.end();
    };

    tryNext();
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
      
      logDebug(`[AI Service] 🔍 Looking for image at: ${localPath}`);
      logDebug(`[AI Service] Uploads directory: ${uploadsPath}`);
      logDebug(`[AI Service] Relative path: ${relativePath}`);
      
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
      let fileExists = false;
      try {
        await fs.promises.access(localPath, fs.constants.R_OK);
        fileExists = true;
      } catch (_) {
        // Wait a bit and retry (file might still be uploading)
        await new Promise(resolve => setTimeout(resolve, 500));
        try {
          await fs.promises.access(localPath, fs.constants.R_OK);
          fileExists = true;
        } catch (_) {
          fileExists = false;
        }
      }
      
      if (fileExists) {
        const stats = await fs.promises.stat(localPath);
        
        // Check file size
        if (stats.size > MAX_IMAGE_SIZE) {
          console.warn(`[AI Service] Image too large: ${stats.size} bytes (max: ${MAX_IMAGE_SIZE})`);
          return null;
        }
        
        logDebug(`[AI Service] ✅ Loading local image: ${localPath} (${stats.size} bytes)`);
        return await fs.promises.readFile(localPath);
      } else {
        console.warn(`[AI Service] ❌ Local image file not found: ${localPath}`);
        // List directory to help debug
        const dirPath = path.dirname(localPath);
        try {
          await fs.promises.access(dirPath, fs.constants.R_OK);
          try {
            const files = await fs.promises.readdir(dirPath);
            console.warn(`[AI Service] Directory exists. Files in directory: ${files.join(', ')}`);
          } catch (e) {
            console.warn(`[AI Service] Could not read directory: ${e.message}`);
          }
        } catch (_) {
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
          logDebug(`[AI Service] Downloaded image: ${buffer.length} bytes`);
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
      logDebug(`[AI Service] 📷 Processing image: ${imageUrl}`);
      try {
        const imageBuffer = await downloadImageFromUrl(imageUrl);
        if (imageBuffer) {
          logDebug(`[AI Service] Image downloaded: ${imageBuffer.length} bytes`);
          base64Image = imageToBase64(imageBuffer);
          if (!base64Image) {
            console.error('[AI Service] ❌ Failed to convert image to base64');
            return null;
          }
          logDebug(`[AI Service] ✅ Image converted to base64: ${base64Image.length} characters`);
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
        logDebug(`[AI Service] Cleaned base64. New length: ${imageData.length}`);
      }
      currentMessage.images = [imageData];
      logDebug(`[AI Service] ✅ Image added to message. Base64 length: ${imageData.length}, Model: ${modelToUse}, First chars: ${imageData.substring(0, 20)}...`);
    } else {
      logDebug(`[AI Service] ⚠️ No base64Image available. imageUrl was: ${imageUrl ? imageUrl.substring(0, 80) : 'null'}...`);
    }

    contextMessages.push(currentMessage);

    // Build prompt with system instructions
    const systemPrompt = base64Image
      ? `You are a helpful AI assistant in a chat application with vision capabilities.
Be accurate and practical. If you are unsure, say so and ask a clarifying question.
Be concise, but do not omit important steps. Prefer staying under ${MAX_RESPONSE_LENGTH} characters unless the user asks for more detail.
You are chatting with ${userName}. Analyze the image and respond naturally.`
      : `You are a helpful AI assistant in a chat application.
Be accurate and practical. If you are unsure, say so and ask a clarifying question.
Be concise, but do not omit important steps. Prefer staying under ${MAX_RESPONSE_LENGTH} characters unless the user asks for more detail.
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
      stream: OLLAMA_STREAM,
      keep_alive: isVisionRequest ? '5m' : '2m', // Keep vision model loaded for 5 minutes, text model for 2 minutes
      options: {
        temperature: OLLAMA_TEMPERATURE,
        top_p: OLLAMA_TOP_P,
        top_k: OLLAMA_TOP_K,
        repeat_penalty: OLLAMA_REPEAT_PENALTY,
        repeat_last_n: OLLAMA_REPEAT_LAST_N,
        num_predict: OLLAMA_NUM_PREDICT, // Use num_predict instead of max_tokens for Ollama
        // Keep context smaller to reduce RAM + CPU spikes
        num_ctx: isVisionRequest ? OLLAMA_VISION_CTX : OLLAMA_TEXT_CTX,
        // Keep CPU usage bounded so the host machine stays responsive
        num_thread: OLLAMA_NUM_THREAD
      }
    });

    logDebug(`[AI Service] Sending request to Ollama: ${OLLAMA_HOST}:${OLLAMA_PORT}, model: ${modelToUse}, timeout: ${requestTimeout}ms`);
    logDebug(`[AI Service] Request details: hasImage=${!!base64Image}, messageCount=${messages.length}, useVisionModel=${useVisionModel}, keepAlive=${isVisionRequest ? '5m' : '2m'}`);
    if (base64Image) {
      logDebug(`[AI Service] Image will be sent with message. Base64 preview: ${base64Image.substring(0, 50)}...`);
      logDebug(`[AI Service] ⏳ Vision models can take 30-120 seconds. Please wait...`);
    }

    return new Promise((resolve, reject) => {
      const hostCandidates = getOllamaHostCandidates();
      const primaryHost = hostCandidates[0] || '127.0.0.1';
      const options = {
        hostname: primaryHost,
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
        let buffer = '';
        let content = '';
        logDebug(`[AI Service] Ollama response status: ${res.statusCode}`);

        res.on('data', (chunk) => {
          const s = chunk.toString('utf8');
          data += s;
          if (!OLLAMA_STREAM) return;

          buffer += s;

          // Ollama stream format: newline-delimited JSON objects (NDJSON)
          while (true) {
            const nl = buffer.indexOf('\n');
            if (nl === -1) break;
            const line = buffer.slice(0, nl).trim();
            buffer = buffer.slice(nl + 1);
            if (!line) continue;

            let obj;
            try { obj = JSON.parse(line); } catch (_) { continue; }

            const piece = obj?.message?.content;
            if (typeof piece === 'string' && piece.length > 0) {
              content += piece;
              if (content.length >= MAX_RESPONSE_LENGTH) {
                if (!resolved) {
                  resolved = true;
                  clearTimeout(globalTimeout);
                  try { req.destroy(); } catch (_) {}
                  resolve(content.slice(0, MAX_RESPONSE_LENGTH).trim());
                }
                return;
              }
            }

            if (obj?.done === true) {
              if (!resolved) {
                resolved = true;
                clearTimeout(globalTimeout);
                resolve((content || '').trim() || null);
              }
              return;
            }
          }
        });

        res.on('end', () => {
          if (resolved) return;
          const elapsed = Date.now() - startTime;
          logDebug(`[AI Service] Ollama response received in ${elapsed}ms, data length: ${data.length}`);
          
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

            if (OLLAMA_STREAM) {
              // Flush any final JSON object that might not end with a newline.
              const remaining = buffer.trim();
              if (remaining) {
                const lines = remaining.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
                for (const line of lines) {
                  try {
                    const obj = JSON.parse(line);
                    const piece = obj?.message?.content;
                    if (typeof piece === 'string' && piece.length > 0) content += piece;
                  } catch (_) {}
                }
              }
              const cleaned = String(content || '').trim();
              if (!resolved) {
                resolved = true;
                clearTimeout(globalTimeout);
                resolve(cleaned || null);
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
            const cleanedResponse = String(aiResponse).trim();
            logDebug(`[AI Service] ✅ Generated response (${cleanedResponse.length} chars): "${cleanedResponse.substring(0, 100)}..."`);
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
        const canFallback =
          hostCandidates.length > 1 &&
          (error.code === 'ECONNREFUSED' || error.code === 'EHOSTUNREACH' || error.code === 'ENETUNREACH');

        if (canFallback) {
          const fallbackHost = hostCandidates[1];
          logDebug(`[AI Service] Retrying Ollama on fallback host: ${fallbackHost}:${OLLAMA_PORT}`);
          try {
            const retryReq = http.request({ ...options, hostname: fallbackHost }, (res) => {
              let data = '';
              res.on('data', (chunk) => { data += chunk; });
              res.on('end', () => {
                if (resolved) return;
                try {
                  if (res.statusCode !== 200) return resolve(null);
                  const response = JSON.parse(data);
                  const aiResponse = response.message?.content || '';
                  const cleanedResponse = String(aiResponse || '').trim();
                  resolve(cleanedResponse || null);
                } catch (_) {
                  resolve(null);
                }
              });
            });
            retryReq.on('error', () => resolve(null));
            retryReq.on('timeout', () => { retryReq.destroy(); resolve(null); });
            retryReq.write(requestData);
            retryReq.end();
            return;
          } catch (_) {
            // fall through to resolve(null)
          }
        }

        if (error.code === 'ECONNREFUSED') {
          console.error(`[AI Service] ❌ Cannot connect to Ollama at ${primaryHost}:${OLLAMA_PORT}`);
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

      logDebug(`[AI Service] Writing request data (${Buffer.byteLength(requestData)} bytes)...`);
      req.write(requestData);
      req.end();
      logDebug(`[AI Service] Request sent, waiting for response (timeout: ${requestTimeout}ms)...`);
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
    const { ObjectId } = require('mongodb');
    const chatIdFilter = typeof chatId === 'string' && ObjectId.isValid(chatId)
      ? new ObjectId(chatId)
      : chatId;
    const messages = await db.collection('messages')
      .find({ chatId: chatIdFilter })
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
  const key = chatKey(messageData?.chatId);
  const state = perChatState.get(key) || { running: false, pending: null };

  // Always keep the latest pending message for this chat; if already running, return immediately.
  if (state.running) {
    state.pending = { messageData, chat, db, io };
    perChatState.set(key, state);
    logDebug(`[AI Service] Chat ${key} is already generating; queued latest pending message (dedup=${AI_DEDUP_PER_CHAT}).`);
    return;
  }

  state.running = true;
  state.pending = null;
  perChatState.set(key, state);

  const firstJob = { messageData, chat, db, io };
  setImmediate(() => {
    runPerChatLoop(key, firstJob).catch(err => {
      console.error('[AI Service] Per-chat AI loop error:', err);
    });
  });
}

async function runPerChatLoop(key, firstJob) {
  let job = firstJob;
  while (job) {
    // Acquire global concurrency slot (prevents server-wide overload)
    let release = null;
    try {
      release = await aiSemaphore.acquire();
    } catch (e) {
      console.error(`[AI Service] Dropping AI job for chat ${key}: ${e?.message || e}`);
      release = null;
    }

    try {
      await processMessageForAIInternal(job.messageData, job.chat, job.db, job.io);
    } finally {
      try { if (release) release(); } catch (_) {}
    }

    const state = perChatState.get(key);
    if (!state) break;
    if (state.pending && AI_DEDUP_PER_CHAT) {
      job = state.pending;
      state.pending = null;
      perChatState.set(key, state);
    } else if (state.pending) {
      // Even with dedup disabled, we still only store one pending job.
      job = state.pending;
      state.pending = null;
      perChatState.set(key, state);
    } else {
      job = null;
    }
  }

  const state = perChatState.get(key);
  if (state) {
    state.running = false;
    state.pending = null;
    perChatState.set(key, state);
  }
}

async function processMessageForAIInternal(messageData, chat, db, io) {
  try {
    // Handle both 'type' and 'messageType' fields (messages can use either)
    const messageType = messageData.messageType || messageData.type || 'text';
    const mediaUrl = messageData.mediaUrl || messageData.media_url || null;

    logDebug(`[AI Service] Processing message: chatId=${messageData.chatId}, senderId=${messageData.senderId}, type=${messageType}`);
    logDebug(`[AI Service] Message details: content=${messageData.content ? 'yes' : 'no'}, mediaUrl=${mediaUrl ? mediaUrl : 'no'}`);

    // Process text messages OR image messages
    const isImageMessage = !!(messageType === 'image' && mediaUrl);
    const contentStr = messageData.content ? String(messageData.content).trim() : '';
    const hasContent = contentStr.length > 0;
    const isTextType = messageType === 'text' || messageType === undefined || messageType === null || messageType === '';
    const isTextMessage = !isImageMessage && isTextType && hasContent;

    logDebug(`[AI Service] Message type check: isTextMessage=${isTextMessage}, isImageMessage=${isImageMessage}`);
    logDebug(`[AI Service] Details: messageType="${messageType}", hasContent=${hasContent}, hasMediaUrl=${!!mediaUrl}, mediaUrl="${mediaUrl ? mediaUrl.substring(0, 80) : 'none'}...", contentLength=${contentStr.length}`);

    if (!isTextMessage && !isImageMessage) {
      logDebug(`[AI Service] Skipping message - not text or image (type=${messageType}, hasContent=${hasContent}, hasMediaUrl=${!!mediaUrl})`);
      return;
    }

    const aiBotId = await getAIBotUserId(db);
    if (!aiBotId) {
      logDebug('[AI Service] AI bot not found in database');
      return;
    }
    logDebug(`[AI Service] AI bot ID: ${aiBotId}`);

    const isFromAI = await isAIMessage(messageData.senderId, db);
    if (isFromAI) {
      logDebug('[AI Service] Skipping - message is from AI bot itself');
      return;
    }

    const chatMembers = chat.members || [];
    const hasAIBot = chatMembers.some(m => m.toString() === aiBotId.toString());
    if (!hasAIBot) {
      logDebug(`[AI Service] AI bot not in chat. Chat ID: ${messageData.chatId}, AI Bot ID: ${aiBotId}, Chat Members: ${chatMembers.map(m => m.toString()).join(', ')}`);
      return;
    }

    const history = await getConversationHistory(messageData.chatId, db);

    const sender = await db.collection('users').findOne({
      _id: new (require('mongodb').ObjectId)(messageData.senderId)
    });
    const senderName = sender?.displayName || sender?.username || 'User';

    logDebug(`[AI Service] AI bot is in chat. Processing message from ${senderName}...`);

    const responseType = isImageMessage ? 'image' : 'text';
    const rawUserMessage = messageData.content || (isImageMessage ? 'What is in this image?' : '');
    const userMessage = sanitizeInput(rawUserMessage);
    const imageUrl = isImageMessage ? mediaUrl : null;

    logDebug(`[AI Service] Generating ${responseType} response for message from ${senderName}...`);
    if (isImageMessage) {
      logDebug(`[AI Service] 📷 Processing image: ${imageUrl}`);
    }

    const aiResponse = await generateAIResponse(
      userMessage,
      history,
      senderName,
      imageUrl,
      null,
      aiBotId
    );

    if (!aiResponse) {
      console.warn('[AI Service] Failed to generate response (check Ollama at http://' + (process.env.OLLAMA_HOST || '127.0.0.1') + ':' + (process.env.OLLAMA_PORT || '11434') + ', model: ' + (process.env.OLLAMA_MODEL || 'llama3.2:1b') + ')');
      // Don't stay silent; users interpret this as "server hung".
      const fallbackText =
        'AI is temporarily unavailable (Ollama not responding). Please try again in a minute.';

      // Create a visible bot message so the client gets feedback.
      const chatIdObjectId = typeof messageData.chatId === 'string'
        ? new (require('mongodb').ObjectId)(messageData.chatId)
        : messageData.chatId;
      const senderIdObjectId = new (require('mongodb').ObjectId)(aiBotId);

      const aiMessage = {
        chatId: chatIdObjectId,
        senderId: senderIdObjectId,
        content: fallbackText,
        messageType: 'text',
        mediaUrl: null,
        createdAt: new Date(),
        readBy: [],
        status: 'failed',
        replies: [],
        reactions: {}
      };

      const result = await db.collection('messages').insertOne(aiMessage);

      if (io) {
        const createdAtIso = aiMessage.createdAt instanceof Date
          ? aiMessage.createdAt.toISOString()
          : new Date().toISOString();

        const chatIdStr = messageData.chatId.toString();
        const chatRoom = `chat:${chatIdStr}`;

        io.to(chatRoom).emit('new_message', {
          id: result.insertedId.toString(),
          _id: result.insertedId.toString(),
          senderName: AI_BOT_NAME,
          chatId: chatIdStr,
          senderId: aiBotId.toString(),
          content: fallbackText,
          messageType: 'text',
          mediaUrl: null,
          createdAt: createdAtIso,
          timestamp: createdAtIso,
          readBy: [],
          status: 'failed'
        });
      }

      return;
    }

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

    const result = await db.collection('messages').insertOne(aiMessage);

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

    const otherMembers = chatMembers
      .filter(m => m.toString() !== aiBotId.toString())
      .map(m => m.toString());

    for (const memberId of otherMembers) {
      await db.collection('chats').updateOne(
        { _id: new (require('mongodb').ObjectId)(messageData.chatId) },
        { $inc: { [`unreadCount.${memberId}`]: 1 } }
      );
    }

    if (io) {
      const createdAtIso = aiMessage.createdAt instanceof Date
        ? aiMessage.createdAt.toISOString()
        : new Date().toISOString();

      const chatIdStr = messageData.chatId.toString();
      const chatRoom = `chat:${chatIdStr}`;

      logDebug(`[AI Service] Emitting new_message to room: ${chatRoom}`);

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

    logDebug(`[AI Service] ✅ AI response sent: "${aiResponse.substring(0, 50)}..."`);
  } catch (error) {
    console.error('[AI Service] Error processing message for AI:', error);
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
