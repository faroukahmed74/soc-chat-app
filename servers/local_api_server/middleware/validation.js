// =============================================================================
// SOC Chat App - Input Validation Middleware
// =============================================================================
// Comprehensive input validation and sanitization middleware

const { body, param, query, validationResult } = require('express-validator');
const { ObjectId } = require('mongodb');

// =============================================================================
// VALIDATION RULES
// =============================================================================

/**
 * User registration validation rules
 */
const validateUserRegistration = [
  body('name')
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Name must be between 2 and 50 characters')
    .matches(/^[a-zA-Z0-9\s\-'\.]+$/)
    .withMessage('Name can only contain letters, numbers, spaces, hyphens, apostrophes, and periods'),
  
  body('email')
    .trim()
    .isEmail()
    .withMessage('Please provide a valid email address')
    .normalizeEmail()
    .isLength({ max: 100 })
    .withMessage('Email must be less than 100 characters'),
  
  body('password')
    .isLength({ min: 6, max: 128 })
    .withMessage('Password must be between 6 and 128 characters')
];

/**
 * User login validation rules
 */
const validateUserLogin = [
  body('email')
    .trim()
    .isEmail()
    .withMessage('Please provide a valid email address')
    .normalizeEmail(),
  
  body('password')
    .notEmpty()
    .withMessage('Password is required')
    .isLength({ min: 1, max: 128 })
    .withMessage('Password must be less than 128 characters')
];

/**
 * Chat creation validation rules
 */
const validateChatCreation = [
  body('name')
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Chat name must be between 1 and 100 characters')
    .escape(),
  
  body('members')
    .isArray({ min: 1, max: 100 })
    .withMessage('Members must be an array with 1-100 items')
    .custom((members) => {
      for (const memberId of members) {
        if (!ObjectId.isValid(memberId)) {
          throw new Error('All member IDs must be valid MongoDB ObjectIds');
        }
      }
      return true;
    }),
  
  body('type')
    .optional()
    .isIn(['private', 'group'])
    .withMessage('Chat type must be either "private" or "group"')
];

/**
 * Message sending validation rules
 */
const validateMessageSending = [
  body('content')
    .trim()
    .isLength({ min: 1, max: 2000 })
    .withMessage('Message content must be between 1 and 2000 characters')
    .escape(),
  
  body('type')
    .optional()
    .isIn(['text', 'image', 'video', 'audio', 'document', 'location'])
    .withMessage('Message type must be one of: text, image, video, audio, document, location'),
  
  body('mediaUrl')
    .optional()
    .isURL()
    .withMessage('Media URL must be a valid URL')
];

/**
 * Chat ID parameter validation
 */
const validateChatId = [
  param('chatId')
    .isMongoId()
    .withMessage('Chat ID must be a valid MongoDB ObjectId')
];

/**
 * Message ID parameter validation
 */
const validateMessageId = [
  param('messageId')
    .isMongoId()
    .withMessage('Message ID must be a valid MongoDB ObjectId')
];

/**
 * User ID parameter validation
 */
const validateUserId = [
  param('userId')
    .isMongoId()
    .withMessage('User ID must be a valid MongoDB ObjectId')
];

/**
 * Pagination query validation
 */
const validatePagination = [
  query('page')
    .optional()
    .isInt({ min: 1, max: 1000 })
    .withMessage('Page must be a positive integer between 1 and 1000'),
  
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be a positive integer between 1 and 100')
];

/**
 * Search query validation
 */
const validateSearch = [
  query('q')
    .optional()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Search query must be between 1 and 100 characters')
    .escape()
];

// =============================================================================
// CUSTOM VALIDATION FUNCTIONS
// =============================================================================

/**
 * Validate MongoDB ObjectId
 */
const isValidObjectId = (value) => {
  return ObjectId.isValid(value);
};

/**
 * Validate file upload
 */
const validateFileUpload = (req, res, next) => {
  if (!req.file) {
    return res.status(400).json({
      error: 'No file uploaded',
      message: 'Please select a file to upload'
    });
  }
  
  // Check file size (50MB limit)
  const maxSize = 50 * 1024 * 1024; // 50MB
  if (req.file.size > maxSize) {
    return res.status(413).json({
      error: 'File too large',
      message: 'File size must be less than 50MB'
    });
  }
  
  // Check file type
  const allowedTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
    'audio/mpeg',
    'audio/wav',
    'audio/ogg',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain'
  ];
  
  if (!allowedTypes.includes(req.file.mimetype)) {
    return res.status(400).json({
      error: 'Invalid file type',
      message: 'File type not allowed. Allowed types: images, videos, audio, documents, text files'
    });
  }
  
  next();
};

/**
 * Sanitize input data
 */
const sanitizeInput = (req, res, next) => {
  // Sanitize string fields
  const sanitizeString = (str) => {
    if (typeof str !== 'string') return str;
    return str
      .trim()
      .replace(/[<>]/g, '') // Remove potential HTML tags
      .replace(/javascript:/gi, '') // Remove javascript: protocol
      .replace(/on\w+=/gi, ''); // Remove event handlers
  };
  
  // Recursively sanitize object
  const sanitizeObject = (obj) => {
    if (typeof obj === 'string') {
      return sanitizeString(obj);
    }
    if (Array.isArray(obj)) {
      return obj.map(sanitizeObject);
    }
    if (obj && typeof obj === 'object') {
      const sanitized = {};
      for (const [key, value] of Object.entries(obj)) {
        sanitized[key] = sanitizeObject(value);
      }
      return sanitized;
    }
    return obj;
  };
  
  // Sanitize request body
  if (req.body) {
    req.body = sanitizeObject(req.body);
  }
  
  // Sanitize query parameters
  if (req.query) {
    req.query = sanitizeObject(req.query);
  }
  
  next();
};

// =============================================================================
// VALIDATION RESULT HANDLER
// =============================================================================

/**
 * Handle validation results
 */
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    const errorMessages = errors.array().map(error => ({
      field: error.path || error.param,
      message: error.msg,
      value: error.value
    }));
    
    return res.status(400).json({
      error: 'Validation failed',
      message: 'Please check your input and try again',
      details: errorMessages
    });
  }
  
  next();
};

// =============================================================================
// RATE LIMITING VALIDATION
// =============================================================================

/**
 * Validate rate limiting headers
 */
const validateRateLimit = (req, res, next) => {
  // Check if request is being rate limited
  const rateLimitInfo = {
    limit: res.get('X-RateLimit-Limit'),
    remaining: res.get('X-RateLimit-Remaining'),
    reset: res.get('X-RateLimit-Reset')
  };
  
  // Add rate limit info to response
  res.set('X-RateLimit-Limit', rateLimitInfo.limit || '100');
  res.set('X-RateLimit-Remaining', rateLimitInfo.remaining || '99');
  res.set('X-RateLimit-Reset', rateLimitInfo.reset || Date.now() + 900000);
  
  next();
};

// =============================================================================
// SECURITY VALIDATION
// =============================================================================

/**
 * Validate request headers for security
 */
const validateSecurityHeaders = (req, res, next) => {
  // Check for suspicious headers
  const suspiciousHeaders = [
    'x-forwarded-for',
    'x-real-ip',
    'x-originating-ip',
    'x-remote-ip',
    'x-remote-addr'
  ];
  
  for (const header of suspiciousHeaders) {
    if (req.headers[header]) {
      console.warn(`Suspicious header detected: ${header} = ${req.headers[header]}`);
    }
  }
  
  // Validate content type for POST requests
  if (req.method === 'POST' && req.headers['content-type']) {
    const contentType = req.headers['content-type'].toLowerCase();
    const allowedTypes = [
      'application/json',
      'application/x-www-form-urlencoded',
      'multipart/form-data'
    ];
    
    if (!allowedTypes.some(type => contentType.includes(type))) {
      return res.status(400).json({
        error: 'Invalid content type',
        message: 'Content type not allowed'
      });
    }
  }
  
  next();
};

// =============================================================================
// EXPORTS
// =============================================================================

module.exports = {
  // Validation rules
  validateUserRegistration,
  validateUserLogin,
  validateChatCreation,
  validateMessageSending,
  validateChatId,
  validateMessageId,
  validateUserId,
  validatePagination,
  validateSearch,
  
  // Custom validators
  isValidObjectId,
  validateFileUpload,
  sanitizeInput,
  handleValidationErrors,
  validateRateLimit,
  validateSecurityHeaders
};
