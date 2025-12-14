# Twilio Auth Token Rotation - Security Fix Guide

## 🚨 Critical Security Issue

Twilio detected that your Auth Token was exposed in a public GitHub repository and has **automatically rotated** it for security.

**The current token in your code is now INVALID and must be replaced.**

## 📍 Exposed Location

The token was found in:
- `docs/TWILIO_TURN_TRACING_AND_FIXES.md` (commit: 7655c3d87f81b09c814e3c844ff137e6ff562522)

## ✅ Immediate Actions Required

### Step 1: Get New Auth Token from Twilio

1. **Go to Twilio Console:**
   - Visit: https://www.twilio.com/console
   - Log in to your account

2. **Find Your Auth Token:**
   - Navigate to: **Account** → **Auth Tokens**
   - You'll see your new Auth Token (it's different from the old one)
   - **Copy the new token** - you'll need it in the next steps

### Step 2: Update Local Configuration

1. **Update the setup script with your new token:**
   ```powershell
   cd servers/local_api_server
   # Edit SET_TWILIO_CREDENTIALS.ps1
   # Replace line 8 with your NEW auth token:
   $newAuthToken = "YOUR_NEW_AUTH_TOKEN_HERE"
   ```

2. **Run the update script:**
   ```powershell
   .\SET_TWILIO_CREDENTIALS.ps1
   ```

   This will update your `.env` file with the new credentials.

### Step 3: Verify Configuration

Check that your `.env` file has been updated:
```powershell
# The .env file should now have:
TWILIO_ACCOUNT_SID=ACbd7662379a26ed6cde62bfbc8a9a998e
TWILIO_AUTH_TOKEN=YOUR_NEW_AUTH_TOKEN_HERE
CLOUD_TURN_USERNAME=ACbd7662379a26ed6cde62bfbc8a9a998e:YOUR_NEW_AUTH_TOKEN_HERE
CLOUD_TURN_PASSWORD=YOUR_NEW_AUTH_TOKEN_HERE
```

### Step 4: Restart API Server

**CRITICAL:** The API server must be restarted to load the new token:

1. Stop the current server (Ctrl+C)
2. Start it again:
   ```powershell
   cd servers/local_api_server
   node server.js
   ```

3. Verify the new token is working:
   - Check server logs for: `✅ [TURN_CONFIG] Twilio Token API: Generated TURN credentials successfully`
   - If you see errors, verify the token is correct

### Step 5: Clean Up Git History (Important!)

The old token is still in your git history. To fully secure your repository:

1. **Option A: Use git-filter-repo (Recommended)**
   ```bash
   # Install git-filter-repo if needed
   pip install git-filter-repo
   
   # Remove the old token from all commits
   git filter-repo --replace-text <(echo "452e23b1ce6dcae1b9eaf4cb92ae3b4a==>REDACTED")
   ```

2. **Option B: Make Repository Private**
   - Go to GitHub repository settings
   - Change visibility to **Private**
   - This prevents public access to the exposed token

3. **Option C: Contact GitHub Support**
   - If the repository must remain public, contact GitHub support
   - They can help remove sensitive data from git history

## 🔒 Security Best Practices

### ✅ DO:
- ✅ Keep `.env` files in `.gitignore` (already done)
- ✅ Use environment variables for secrets
- ✅ Use placeholders in documentation (e.g., `YOUR_AUTH_TOKEN_HERE`)
- ✅ Rotate tokens regularly
- ✅ Use Twilio Token API instead of static credentials when possible

### ❌ DON'T:
- ❌ Commit `.env` files to git
- ❌ Hardcode credentials in source code
- ❌ Include real credentials in documentation
- ❌ Share credentials in public repositories
- ❌ Use the same token across multiple projects

## 📋 Verification Checklist

After completing the steps above:

- [ ] New auth token obtained from Twilio Console
- [ ] `.env` file updated with new token
- [ ] API server restarted
- [ ] Server logs show successful Twilio Token API calls
- [ ] Documentation files updated (credentials removed)
- [ ] Git history cleaned (or repository made private)
- [ ] Test call works between devices

## 🆘 Troubleshooting

### If Token API Still Fails After Update:

1. **Verify Token Format:**
   - Token should be 32 characters
   - No spaces or extra characters
   - Copy directly from Twilio Console

2. **Check Server Logs:**
   - Look for: `❌ [TURN_CONFIG] Twilio Token API request failed`
   - Error message will indicate the issue

3. **Test Token Manually:**
   ```powershell
   cd servers/local_api_server
   node TEST_TWILIO_CREDENTIALS.js
   ```

4. **Fallback to Static Credentials:**
   - If Token API fails, server will use static credentials
   - Ensure `CLOUD_TURN_USERNAME` and `CLOUD_TURN_PASSWORD` are set correctly

## 📞 Support

If you need help:
- **Twilio Support:** https://support.twilio.com/
- **GitHub Security:** https://docs.github.com/en/code-security/secret-scanning

---

**Remember:** Never commit secrets to version control. Always use environment variables and `.gitignore` files.

