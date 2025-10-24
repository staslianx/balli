# Configuration Files

## Setup Instructions

### For New Developers

1. Copy the template file:
   ```bash
   cp Secrets.xcconfig.template Secrets.xcconfig
   ```

2. Edit `Secrets.xcconfig` and add your actual API keys:
   - `PICOVOICE_ACCESS_KEY`: Get from https://console.picovoice.ai/

3. The `Secrets.xcconfig` file is git-ignored and will NOT be committed.

### For Xcode Project Configuration

The project uses xcconfig files for build configuration:
- `Debug.xcconfig` - Development builds
- `Release.xcconfig` - Production builds
- `Secrets.xcconfig` - API keys (git-ignored)

These files are automatically included by the Xcode project settings.

## Security Notes

⚠️ **NEVER commit `Secrets.xcconfig` to git**
⚠️ **NEVER hardcode API keys in source code**
⚠️ **Rotate keys immediately if accidentally exposed**

## Current Keys

- **PICOVOICE_ACCESS_KEY**: Used for "hey balli" wake word detection
  - Required for voice command features
  - Free tier: 1000 requests/month

## For CI/CD

In your CI environment, create `Secrets.xcconfig` with appropriate keys:
```bash
echo "PICOVOICE_ACCESS_KEY = $PICOVOICE_KEY" > balli/Configuration/Secrets.xcconfig
```
