# Fix 403 Forbidden Error for /api/chats

## Problem
When making GET request to `/api/chats`, server returns **403 Forbidden**.

## What 403 Forbidden Means

1. **401 Unauthorized** = Missing token or no authentication
2. **403 Forbidden** = Token is provided but **invalid or expired**

## Common Causes

### 1. Token Expired
JWT tokens expire after a certain time. User needs to re-login.

### 2. Wrong JWT Secret
Server is using a different `JWT_SECRET` than what was used to sign the token.

### 3. Token Missing Required Fields
Token doesn't have `id` or `uid` field that the server expects.

## How to Fix

### Check Server Logs
Look at the server terminal for:
```
403 Forbidden - Invalid token
```

### Solution 1: Re-login
1. Logout from the app
2. Login again with email/password
3. This will generate a fresh token

### Solution 2: Check JWT_SECRET
On the server, verify the `JWT_SECRET` in `.env` file:
```
JWT_SECRET=your_secure_jwt_secret_key_change_this_in_production
```

Make sure the same secret is used consistently.

### Solution 3: Verify Token Payload
The token should have these fields:
```json
{
  "id": "user_id_here",
  "email": "user@example.com",
  "displayName": "User Name"
}
```

## Debugging Steps

1. **Check browser console (F12)**
   - Look for error message
   - Check if token is being sent

2. **Check network tab**
   - See request headers
   - Look for `Authorization: Bearer <token>`

3. **Check server logs**
   - Look for "Invalid token" or "Authentication error"

## Quick Test

Try accessing from a different browser or device:
- If it works → Token expired on first device
- If it fails → Server configuration issue

