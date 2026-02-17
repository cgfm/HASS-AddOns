# Internxt WebDAV Home Assistant Add-on

This add-on provides a WebDAV server for Internxt cloud storage, allowing you to access your Internxt files through the WebDAV protocol.

## About

Internxt is a privacy-focused cloud storage service. This add-on runs the Internxt WebDAV server, which bridges your Internxt account to any WebDAV-compatible client.

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the "Internxt WebDAV" add-on
3. Configure the add-on (see Configuration section)
4. Start the add-on

## Configuration

### Required Configuration

- `inxt_user`: Your Internxt account email
- `inxt_password`: Your Internxt account password

### Optional Configuration

- `inxt_twofactorcode`: Temporary 2FA code from your authenticator app (must be updated on each restart)
- `inxt_otptoken`: OTP secret key (base32) for automatic 2FA code generation (recommended for unattended use)
- `webdav_port`: Port for the WebDAV server (default: 3005)
- `webdav_protocol`: Protocol for the WebDAV server - `http` or `https` (default: https)
- `log_level`: Log verbosity - `quiet`, `normal`, or `verbose` (default: normal)

### Example Configuration

**Without 2FA:**
```yaml
inxt_user: your-email@example.com
inxt_password: your-internxt-password
webdav_port: 3005
webdav_protocol: https
```

**With 2FA (using OTP token - recommended):**
```yaml
inxt_user: your-email@example.com
inxt_password: your-internxt-password
inxt_otptoken: YOUR_BASE32_OTP_SECRET
webdav_port: 3005
webdav_protocol: https
```

## Usage

After starting the add-on:

1. Check the **Log** tab to find your WebDAV server URL and IP address
2. The add-on will automatically send discovery information to Home Assistant
3. Connect to the WebDAV server at:

```
https://homeassistant.local:3005
```

Or use the IP address shown in the logs:

```
https://YOUR_HA_IP:3005
```

No additional authentication is required - the server authenticates with your Internxt credentials.

### Automatic Discovery

The add-on supports Home Assistant's service discovery feature. Compatible integrations may automatically detect and suggest setting up the WebDAV connection.

## Support

For issues and questions, please open an issue on GitHub.
