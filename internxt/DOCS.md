# Internxt WebDAV Add-on Documentation

## Overview

This Home Assistant add-on provides a WebDAV server interface for your Internxt cloud storage account. It allows you to access your Internxt files using any WebDAV-compatible client.

## What is WebDAV?

WebDAV (Web Distributed Authoring and Versioning) is an extension of HTTP that allows clients to perform remote web content authoring operations. In simpler terms, it lets you mount your cloud storage as a network drive on your computer or access it through various file managers.

## Installation

### Adding the Repository

1. Navigate to **Settings** > **Add-ons** > **Add-on Store** in Home Assistant
2. Click the three dots menu in the top right
3. Select **Repositories**
4. Add the repository URL
5. Click **Add**

### Installing the Add-on

1. Find "Internxt WebDAV" in the add-on store
2. Click on it and press **Install**
3. Wait for the installation to complete

## Configuration

### Configuration Options

#### Internxt Account Settings (Required)

- **inxt_user** (required): Your Internxt account email address
  - This is your actual Internxt login email
  - Example: `user@example.com`

- **inxt_password** (required): Your Internxt account password
  - This is your actual Internxt account password
  - Used to authenticate with Internxt's services

#### Two-Factor Authentication (2FA)

If your Internxt account has 2FA enabled, you must provide one of the following:

- **inxt_twofactorcode** (optional): Temporary 2FA code from your authenticator app
  - Generate this code from Google Authenticator, Authy, or similar apps
  - This code expires quickly (usually 30 seconds)
  - **Limitation**: You must update this code every time the add-on restarts
  - **Use case**: Manual, occasional use only

- **inxt_otptoken** (optional): Your OTP secret key (base32 format)
  - This is the secret key shown when you first set up 2FA
  - The add-on will automatically generate fresh codes at runtime
  - **Recommended**: Best for unattended/automated use
  - **Note**: If both are provided, `inxt_otptoken` takes precedence

##### How to Get Your OTP Token

When setting up 2FA on Internxt:
1. You're shown a QR code and a text key
2. The text key is your `inxt_otptoken` - save it securely
3. It looks like: `JBSWY3DPEHPK3PXP` (base32 encoded)

If you've already set up 2FA and didn't save the key:
- You'll need to disable and re-enable 2FA to get a new token
- Or use `inxt_twofactorcode` instead (requires manual updates)

#### WebDAV Server Settings (Optional)

- **webdav_port** (optional): Port for the WebDAV server
  - Default: `3005`
  - Change if port 3005 conflicts with another service

- **webdav_protocol** (optional): Protocol for the WebDAV server
  - Options: `http` or `https`
  - Default: `https`
  - **Recommended**: Use `https` for security

- **log_level** (optional): Controls log verbosity
  - Options: `quiet`, `normal`, `verbose`
  - Default: `normal`
  - `quiet`: Only errors and warnings (recommended for normal use)
  - `normal`: Important messages, filters out verbose WebDAV operations
  - `verbose`: All logs including every WebDAV request (useful for debugging)

### Example Configurations

#### Without 2FA

```yaml
inxt_user: myemail@example.com
inxt_password: my-internxt-password
webdav_port: 3005
webdav_protocol: https
```

#### With 2FA (Using OTP Token - Recommended)

```yaml
inxt_user: myemail@example.com
inxt_password: my-internxt-password
inxt_otptoken: JBSWY3DPEHPK3PXP
webdav_port: 3005
webdav_protocol: https
log_level: normal
```

#### With 2FA (Using Temporary Code)

```yaml
inxt_user: myemail@example.com
inxt_password: my-internxt-password
inxt_twofactorcode: 123456
webdav_port: 3005
webdav_protocol: https
```

**Note**: When using `inxt_twofactorcode`, you must update it in the configuration and restart the add-on whenever the code expires or the add-on restarts.

## Usage

### Starting the Add-on

1. Configure the add-on with your credentials
2. Click **Save**
3. Go to the **Info** tab
4. Click **Start**
5. Check the **Log** tab to ensure it started successfully
6. The log will display the WebDAV server URL and IP address for easy access

### Connecting to the WebDAV Server

After starting the add-on, check the **Log** tab to find your WebDAV server URL. The log will display:
- The complete WebDAV server URL (e.g., `https://homeassistant.local:3005`)
- The internal IP address of the add-on
- An alternative URL using the IP address

You can also access the WebDAV server using these standard addresses:

**Using hostname:**
```
https://homeassistant.local:3005
```

**Using IP address:**
```
https://YOUR_HA_IP:3005
```

If you configured `webdav_protocol: http`, use `http://` instead of `https://`.

**Important**: No additional username/password is required when connecting to the WebDAV server. The authentication is handled by your Internxt credentials configured in the add-on.

#### Automatic Discovery

This add-on supports Home Assistant's service discovery feature. When the add-on starts:
1. It automatically sends discovery information to Home Assistant
2. Compatible integrations (like WebDAV or file sharing integrations) may detect the service
3. You might see a notification in Home Assistant suggesting to set up the WebDAV connection

**Note**: Not all WebDAV integrations support automatic discovery. If you don't see a discovery notification, you can still connect manually using the URLs above.

### Connecting from Different Clients

#### Windows

1. Open **File Explorer**
2. Right-click on **This PC**
3. Select **Add a network location**
4. Follow the wizard and enter the WebDAV URL: `https://homeassistant.local:3005`
5. If prompted for credentials, try leaving them blank or using any dummy credentials

**Note**: Windows may have issues with self-signed HTTPS certificates. Consider using `http` protocol or installing proper certificates.

#### macOS

1. Open **Finder**
2. Press **Cmd+K** or go to **Go** > **Connect to Server**
3. Enter the WebDAV URL: `https://homeassistant.local:3005`
4. Click **Connect**
5. If prompted for credentials, try leaving them blank or using guest access

#### Linux

##### Using File Manager (GNOME Files/Nautilus)

1. Open Files
2. Click **Other Locations**
3. Enter the WebDAV URL in **Connect to Server**: `davs://homeassistant.local:3005`
4. If prompted for credentials, try anonymous/guest access

**Note**: Use `davs://` for HTTPS or `dav://` for HTTP.

##### Using Command Line

```bash
# Install davfs2
sudo apt-get install davfs2

# Create mount point
sudo mkdir /mnt/internxt

# Mount the WebDAV share (use http if you configured http protocol)
sudo mount -t davfs https://homeassistant.local:3005 /mnt/internxt
```

#### Mobile Devices

Use WebDAV-compatible file manager apps:
- **iOS**: Documents by Readdle, FE File Explorer
- **Android**: Total Commander with WebDAV plugin, Solid Explorer

Enter the server URL (`https://homeassistant.local:3005`) in your chosen app.

## Security Considerations

1. **Password Security**: Use a strong, unique password for your Internxt account
2. **Two-Factor Authentication**: Enable 2FA on your Internxt account for additional security
3. **OTP Token Security**: If using `inxt_otptoken`, keep it secure:
   - This token can generate authentication codes for your account
   - Store it as securely as you would store your password
   - Never share it with others
4. **Network Security**:
   - The server defaults to HTTPS, which is recommended
   - If using HTTP, only use on trusted local networks
   - Consider using a reverse proxy with proper SSL/TLS certificates if exposing externally
5. **Credential Storage**: Your Internxt credentials (including 2FA tokens) are stored in the add-on configuration
   - Home Assistant encrypts sensitive configuration data
   - Ensure your Home Assistant instance is properly secured
   - Use strong passwords for Home Assistant access

## Troubleshooting

### Add-on Won't Start

1. Check the logs in the **Log** tab for specific error messages
2. Verify all required configuration fields are filled:
   - `inxt_user` (your Internxt email)
   - `inxt_password` (your Internxt password)
3. Ensure your Internxt credentials are correct
4. If you have 2FA enabled, ensure you've provided either:
   - `inxt_otptoken` (recommended), or
   - `inxt_twofactorcode` (temporary code)
5. Check that port 3005 is not in use by another service

### Cannot Connect to WebDAV Server

1. Verify the add-on is running (check the **Info** tab)
2. Check your Home Assistant hostname/IP address
3. Ensure port 3005 is accessible from your client device
4. Try using the IP address instead of hostname
5. Verify you're using the correct protocol (`http://` or `https://`)
6. If using HTTPS, your client may reject self-signed certificates:
   - Try using `http` protocol instead, or
   - Accept/trust the certificate in your client

### Authentication Failures

- The Internxt WebDAV server doesn't require separate WebDAV credentials
- Authentication is handled by the Internxt account configured in the add-on
- If authentication fails:
  - Verify your Internxt credentials in the add-on configuration
  - Check if your Internxt account has 2FA enabled
  - If using 2FA, ensure you've configured the OTP token or temporary code correctly
  - Check the add-on logs for specific error messages
  - Try logging into Internxt's web interface to verify your credentials work

### 2FA Issues

**Using temporary codes (`inxt_twofactorcode`)**:
- Codes expire after 30 seconds
- You must restart the add-on with a fresh code
- Not suitable for long-running/unattended use

**Using OTP token (`inxt_otptoken`)**:
- Verify you have the correct base32 secret key
- The key should be from your Internxt 2FA setup (not Google, not another service)
- If lost, disable and re-enable 2FA on Internxt to get a new token

### Slow Performance

1. Check your internet connection speed
2. Verify your Internxt account is active and not rate-limited
3. Set `log_level: verbose` in the configuration to see detailed operation logs
4. Consider the limitations of WebDAV protocol for large files

### Too Many Logs

If the logs are too verbose:
1. Set `log_level: quiet` to see only errors and warnings
2. Set `log_level: normal` (default) for a balance between information and verbosity
3. The add-on automatically filters out verbose WebDAV operation logs in normal and quiet modes

## Limitations

- Performance depends on your internet connection and Internxt's service
- WebDAV protocol may not be optimal for very large files
- Real-time sync is not supported (changes are on-demand)

## Support

For issues specific to this add-on, please check:
- Add-on logs for error messages
- Home Assistant community forums
- GitHub repository issues

For Internxt-specific issues:
- Visit [Internxt Support](https://internxt.com/support)

## Credits

This add-on packages the [Internxt WebDAV](https://hub.docker.com/r/internxt/webdav) Docker container for Home Assistant.
