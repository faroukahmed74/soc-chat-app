# Twilio TURN Setup - Step by Step Guide

## 🎯 Goal
Set up Twilio Network Traversal Service (TURN) for WebRTC calls using free $15.50 credit.

## 📋 Prerequisites
- Email address
- Phone number (for verification)
- Credit card (for account verification - won't be charged until credit runs out)

## 🚀 Step-by-Step Setup

### Step 1: Sign Up for Twilio

1. **Go to Twilio Sign Up:**
   - Visit: https://www.twilio.com/try-twilio
   - Click "Start Free Trial"

2. **Create Account:**
   - Enter your email address
   - Create a password
   - Click "Start your free trial"

3. **Verify Email:**
   - Check your email
   - Click verification link

4. **Verify Phone:**
   - Enter your phone number
   - Enter verification code sent via SMS

5. **Account Setup:**
   - Choose a project name (e.g., "SOC Chat App")
   - Select your country
   - Click "Get Started"

### Step 2: Get Your Account Credentials

1. **Navigate to Console Dashboard:**
   - After signup, you'll be in the Twilio Console
   - Note your **Account SID** (starts with `AC...`)
   - Note your **Auth Token** (click "View" to reveal)

2. **Save Credentials Securely:**
   ```
   Account SID: ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   Auth Token: your_auth_token_here
   ```
   ⚠️ **Keep these secure - don't commit to git!**

### Step 3: Enable Network Traversal Service

1. **Navigate to Network Traversal:**
   - In Twilio Console, go to: **Products** → **Network Traversal**
   - Or visit: https://console.twilio.com/us1/develop/runtime/network-traversal

2. **Create TURN Service:**
   - Click "Create TURN Service" or "Get Started"
   - Service will be created automatically

3. **Get TURN Credentials:**
   - You'll see your TURN credentials:
     - **Username**: Format: `your-account-sid:your-auth-token`
     - **Password**: Your auth token
     - **TURN URLs**: 
       - `turn:global.turn.twilio.com:3478?transport=udp`
       - `turn:global.turn.twilio.com:3478?transport=tcp`
       - `turns:global.turn.twilio.com:5349?transport=tcp`

### Step 4: Configure Environment Variables

1. **Navigate to API Server Directory:**
   ```powershell
   cd servers/local_api_server
   ```

2. **Create/Update `.env` File:**
   - If `.env` doesn't exist, create it
   - Add these lines:

   ```env
   # Cloud TURN Service Configuration (Twilio)
   CLOUD_TURN_ENABLED=true
   CLOUD_TURN_USERNAME=your-account-sid:your-auth-token
   CLOUD_TURN_PASSWORD=your-auth-token
   CLOUD_TURN_URLS=turn:global.turn.twilio.com:3478?transport=udp,turn:global.turn.twilio.com:3478?transport=tcp,turns:global.turn.twilio.com:5349?transport=tcp
   ```

3. **Replace Placeholders:**
   - Replace `your-account-sid` with your actual Account SID
   - Replace `your-auth-token` with your actual Auth Token

### Step 5: Restart API Server

1. **Stop Current Server:**
   - If running, press `Ctrl+C` to stop

2. **Start Server:**
   ```powershell
   node server.js
   ```

3. **Verify Configuration:**
   - Look for log message:
     ```
     ✅ [TURN_CONFIG] Using CLOUD TURN service (no router config needed!)
     ```

### Step 6: Test the Setup

1. **Check TURN Configuration Endpoint:**
   ```powershell
   curl https://soc-chat-app.ngrok-free.app/api/webrtc/turn-config
   ```
   - Should return TURN servers with Twilio URLs

2. **Test Call:**
   - Make call between two devices on different networks
   - Should see audio/video working!

3. **Check Logs:**
   - Look for RELAY candidates in device logs
   - Should see Twilio TURN servers being used

## ✅ Verification Checklist

- [ ] Twilio account created
- [ ] Account SID and Auth Token saved
- [ ] Network Traversal Service enabled
- [ ] TURN credentials obtained
- [ ] `.env` file configured
- [ ] API server restarted
- [ ] TURN config endpoint returns Twilio servers
- [ ] Test call works between different networks

## 🔍 Troubleshooting

### Issue: "Authentication failed"
- **Solution**: Check that Account SID and Auth Token are correct
- Format: `CLOUD_TURN_USERNAME=ACxxxxx:your-auth-token`

### Issue: "TURN servers not configured"
- **Solution**: Verify `CLOUD_TURN_ENABLED=true` in `.env`
- Restart API server after changing `.env`

### Issue: "No RELAY candidates"
- **Solution**: 
  - Check TURN credentials are correct
  - Verify API server is returning Twilio TURN servers
  - Check device logs for TURN configuration

### Issue: "Call connects but no audio/video"
- **Solution**:
  - Verify Twilio TURN URLs are correct
  - Check that devices are on different networks
  - Look for RELAY candidates in logs

## 💰 Cost Monitoring

1. **Check Usage:**
   - Go to Twilio Console → **Monitor** → **Usage**
   - Track Network Traversal usage

2. **Set Alerts:**
   - Go to **Monitor** → **Alerts**
   - Set alert when credit reaches $5 remaining

3. **Estimate Costs:**
   - 1 hour video call ≈ 500MB = $0.20
   - $15.50 credit ≈ 77 hours of video calls

## 📝 Next Steps

After testing:
1. Monitor usage and costs
2. Optimize call quality settings
3. Set up usage alerts
4. Consider hybrid approach (local TURN for same-network, Twilio for cross-network)

## 🎯 Success Criteria

✅ Calls work between devices on different networks
✅ Audio and video streams are clear
✅ RELAY candidates appear in logs
✅ Twilio usage is being tracked

**You're all set! Start testing!** 🚀

