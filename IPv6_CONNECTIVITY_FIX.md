# IPv6 Connectivity Issue & Fix

## Problem

If you experience timeouts when running the setup script or BigQuery commands, it may be due to **IPv6 connectivity issues with Google Cloud APIs**.

**Symptoms:**
- Setup script hangs/stalls for 5+ minutes
- `bq query` commands timeout
- `gcloud` commands timeout
- Other operations timeout when accessing Google Cloud
- IPv4 connectivity to Google Cloud works fine

**Root Cause:**
Some networks have IPv6 enabled but with unreliable connectivity to Google Cloud's IPv6 endpoints. When the DNS resolver tries IPv6 first and it times out, operations hang before falling back to IPv4.

---

## Solution: Use Native DNS Resolver

Set the `GRPC_DNS_RESOLVER` environment variable to `native`:

```bash
export GRPC_DNS_RESOLVER=native
```

This tells gRPC (used by Google Cloud client libraries) to:
- Use the native system DNS resolver
- Avoid IPv6 timeout issues
- Fall back to IPv4 immediately

---

## How to Apply the Fix

### Option 1: Automatic (Recommended)

The improved setup scripts now include this fix automatically:

```bash
# These scripts now include the fix
bash SETUP_PIPELINE.sh
bash DIAGNOSE.sh
```

### Option 2: Manual (For Other Commands)

Set the environment variable before running commands:

```bash
# Set for current session
export GRPC_DNS_RESOLVER=native

# Now run your commands
bq ls
gcloud ...
python python/orchestrator/pipeline_runner.py
```

### Option 3: Permanent (Add to ~/.bashrc)

```bash
# Edit your shell profile
echo 'export GRPC_DNS_RESOLVER=native' >> ~/.bashrc
source ~/.bashrc

# Or for zsh
echo 'export GRPC_DNS_RESOLVER=native' >> ~/.zshrc
source ~/.zshrc
```

### Option 4: Set in Python Scripts

If using Python directly:

```python
import os
os.environ['GRPC_DNS_RESOLVER'] = 'native'

# Now import and use Google Cloud libraries
from google.cloud import bigquery
client = bigquery.Client(project='durango-deflock')
```

---

## Verification

Test the fix:

```bash
# Without fix (may timeout)
# bq ls --project_id=durango-deflock

# With fix (should work immediately)
export GRPC_DNS_RESOLVER=native
bq ls --project_id=durango-deflock
```

If the command returns results quickly, the fix is working.

---

## Updated Setup Process

With the IPv6 fix included, the updated process is:

```bash
# 1. Run diagnostics (includes IPv6 fix)
bash DIAGNOSE.sh

# 2. Dry run (includes IPv6 fix)
bash SETUP_PIPELINE.sh --dry-run

# 3. Setup (includes IPv6 fix)
bash SETUP_PIPELINE.sh

# 4. Verify
bq ls --project_id=durango-deflock FlockML
```

---

## Environment Details

### Where the Fix is Applied

The fix is now automatically included in:
- ✅ `SETUP_PIPELINE.sh` - Setup script
- ✅ `DIAGNOSE.sh` - Diagnostic script

### Manual Application

For other commands, set before execution:

```bash
# Single command
GRPC_DNS_RESOLVER=native bash SETUP_PIPELINE.sh

# Session-wide
export GRPC_DNS_RESOLVER=native
bash SETUP_PIPELINE.sh
python python/orchestrator/pipeline_runner.py
bq ls
```

---

## Alternative Solutions

If the GRPC_DNS_RESOLVER fix doesn't work:

### 1. Disable IPv6 (Network Level)
Contact your network administrator to disable IPv6 or fix IPv6 routing.

### 2. Use IPv4 Only
Force IPv4-only DNS:
```bash
export GRPC_DNS_RESOLVER=ares
export GRPC_VERBOSITY=debug
```

### 3. Check Network Configuration
```bash
# Test IPv6 connectivity
ping6 google.com

# Test IPv4 connectivity
ping 8.8.8.8

# Check DNS
nslookup bigquery.googleapis.com
```

### 4. Network Proxy/VPN
If behind a proxy or VPN, configure credentials:
```bash
gcloud auth login
gcloud config set project durango-deflock
```

---

## Technical Details

### What GRPC_DNS_RESOLVER Does

- **native**: Uses the system's native DNS resolver (recommended)
- **ares**: Uses c-ares DNS resolver (default, tries IPv6 first)
- **apple**: Uses Apple's DNS resolution (macOS only)

### Why This Helps

The default gRPC DNS resolver (c-ares) tries to resolve IPv6 addresses first. If IPv6 is enabled but has connectivity issues, this causes timeouts before IPv4 is attempted.

The native resolver uses your system's DNS configuration, which typically handles IPv6 fallback better.

---

## References

- [Google Cloud Python Client Libraries](https://cloud.google.com/docs/authentication/getting-started)
- [gRPC DNS Resolution](https://grpc.io/docs/guides/performance-tuning/#dns-resolution)
- [BigQuery Command Line Tool](https://cloud.google.com/bigquery/docs/bq-command-line-tool)

---

## Summary

✅ **Issue**: IPv6 timeout causes setup to stall
✅ **Fix**: `export GRPC_DNS_RESOLVER=native`
✅ **Applied**: Automatically in updated scripts
✅ **Verified**: Scripts now include this fix

If you still experience timeouts, the fix is already applied in `SETUP_PIPELINE.sh` and `DIAGNOSE.sh`.
