# Add-on Images

Home Assistant add-ons can include optional images for better visual presentation in the add-on store.

## Required Images

### icon.png
- **Size**: 256x256 pixels (recommended)
- **Format**: PNG with transparency
- **Purpose**: Small icon shown in the add-on list
- **Location**: Place in the addon directory root

### logo.png
- **Size**: 1280x640 pixels (recommended, 2:1 aspect ratio)
- **Format**: PNG
- **Purpose**: Large banner shown on the add-on details page
- **Location**: Place in the addon directory root

## Creating Images

You can create these images using:
- Online tools like [Canva](https://www.canva.com/)
- Image editors like GIMP or Photoshop
- The Internxt logo (with appropriate permissions/license)

## Quick Setup

1. Create or download suitable images for the Internxt WebDAV add-on
2. Resize them to the recommended dimensions
3. Save them as `icon.png` and `logo.png`
4. Place them in `/home/christian/Nextcloud/workspace/HASS/AddOns/internxt/`

## Optional

These images are optional. The add-on will work fine without them, but they improve the user experience in the Home Assistant add-on store.
