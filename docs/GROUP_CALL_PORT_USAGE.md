# Group Call Port Usage Analysis

## Topology: Mesh (Peer-to-Peer)

The app uses a **mesh topology** for group calls, meaning:
- Each participant creates a **direct peer connection** to every other participant
- No central server (SFU/MCU) - all media flows directly between peers
- Each peer connection uses TURN relay ports when needed

## Port Usage Calculation

### Formula
For **N participants** in a group call:
- Each participant creates **(N-1) peer connections**
- Each peer connection uses **2 TURN relay ports** (one for each participant)
- **Total ports needed = N × (N-1) = N² - N**

### Examples

| Participants | Peer Connections per User | Total Relay Ports | Status |
|-------------|---------------------------|-------------------|--------|
| 2 (1-on-1) | 1 | 2 | ✅ OK |
| 3 | 2 | 6 | ✅ OK |
| 4 | 3 | 12 | ✅ OK |
| 5 | 4 | 20 | ✅ OK |
| 6 | 5 | 30 | ✅ OK |
| 7 | 6 | 42 | ✅ OK |
| 8 | 7 | 56 | ✅ OK |
| 9 | 8 | 72 | ✅ OK |
| 10 | 9 | 90 | ✅ OK |
| 11 | 10 | 110 | ❌ **EXCEEDS LIMIT** |

### Current Port Range: 50000-50100 (101 ports)

**Maximum Group Size: 10 participants**
- Uses 90 ports
- Leaves 11 ports buffer for other calls

## Multiple Group Calls

With 101 ports available, you can have:

| Scenario | Ports Used | Remaining |
|----------|-----------|-----------|
| 1 group of 10 | 90 | 11 |
| 2 groups of 5 | 40 (20×2) | 61 |
| 3 groups of 4 | 36 (12×3) | 65 |
| 5 groups of 3 | 30 (6×5) | 71 |
| 10 groups of 2 | 20 (2×10) | 81 |

## Port Exhaustion Scenarios

### ⚠️ What Happens When Ports Run Out?

1. **New calls fail to establish media**
   - Signaling may work (call connects)
   - But no audio/video (no relay ports available)
   - Error: "ICE connection failed" or "No relay candidates"

2. **Existing calls may be affected**
   - If a participant joins mid-call, they need ports
   - If ports are exhausted, new participant can't join

3. **Reconnection issues**
   - If connection drops and needs to reconnect
   - May fail if no ports available

## Solutions for Larger Groups

### Option 1: Increase Port Range
```yaml
# scripts/coturn-docker-compose.yml
ports:
  - "50000-50200:50000-50200/udp"  # 201 ports = 14 participants max
```

**Security Trade-off:**
- More ports = larger attack surface
- But still manageable (201 vs 16,384)

### Option 2: Use SFU (Selective Forwarding Unit)
**Recommended for large groups (10+ participants)**

Instead of mesh, use a central server:
- Each participant connects to SFU (1 connection)
- SFU forwards media to all participants
- **Port usage: N connections** (much less than N²-N)

**Example:**
- 20 participants in mesh: 380 ports needed
- 20 participants with SFU: 20 ports needed

**Implementation:**
- Use services like Janus, Kurento, or Mediasoup
- Or cloud services (Twilio, Agora)

### Option 3: Hybrid Approach
- Small groups (≤5): Use mesh (current)
- Large groups (>5): Use SFU

## Recommendations

### For Current Setup (101 ports):
1. **Limit group calls to 10 participants max**
   - Add UI warning if more participants try to join
   - Suggest splitting into multiple calls

2. **Monitor port usage**
   - Log when ports are running low
   - Alert administrators

3. **Implement port cleanup**
   - Ensure ports are released when calls end
   - Clean up stale connections

### For Production:
1. **Use SFU for groups >5 participants**
2. **Or increase port range to 50000-50200** (201 ports)
3. **Or use cloud TURN service** (unlimited ports)

## Code Reference

The mesh implementation is in:
- `lib/services/webrtc_call_service.dart`
- Line 1503: Creates peer connection for each participant
- Line 32: `Map<String, RTCPeerConnection> _peerConnections` stores all connections

## Port Release

Ports are released when:
- Call ends
- Participant leaves
- Peer connection closes
- Connection timeout

**Important:** Ensure proper cleanup to prevent port leaks!

