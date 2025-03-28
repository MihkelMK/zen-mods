# Zen Mods

Collection of custom CSS mods for the [Zen Browser](https://zen-browser.app/).

## Sideloading

**What?**\
Script that you can use to install these mods into your browser.

**Why?**\
My friends wanted to use my setup and the official mod page workflow is (understandably) slow.

**How?**\
It edits `zen-themes.json` in your browser profile, making the browser think a new mod was downloaded.\
It then creates symbolic links from this repo to `chrome/zen-themes/` in your browser profile as if the browser downloaded the mod.

You can now see the newly installed mod inside the browsers Mods settings page.

**Usage**

1. Create a backup of your current Zen profile directory\
   (Look into the comments at the start of the script for instructions on how to find your Zen profile directory)
2. Clone the repo and run `./zen_sideload.sh <zen_profile_directory>`
3. Choose what mods you want it to install

## Mods

### Icon Only Pins

Change pinned tabs to a horizontal list of icons.

![Screenshot of customized tabs](https://raw.githubusercontent.com/MihkelMK/zen-mods/refs/heads/main/icon_only_pins/image.png)

### Container Tab Tweaks

Customize when and where the tab container indicator is displayed.

![Screenshot of customized tabs](https://raw.githubusercontent.com/MihkelMK/zen-mods/refs/heads/main/container_tab_tweaks/image.png)

### Sidebar Tweaks

Toggleable tweaks for the sidebar

![Screenshot of customized workspace indicators](https://raw.githubusercontent.com/MihkelMK/zen-mods/refs/heads/main/sidebar_tweaks/image.png)

### Thin Settings Sidebar

Collapse settings sidebar into icons only with a floating search box on smaller screens.

![Screenshot of collapsed settings sidebar](https://raw.githubusercontent.com/MihkelMK/zen-mods/refs/heads/main/thin_settings_sidebar/image.png)

### Cleaner Downloads

Change spacing and remove borders in the recent downloads menu.

Inspired by [Cleaner Extension Menu - Zen Mods](https://zen-browser.app/mods/1e86cf37-a127-4f24-b919-d265b5ce29a0/) by [KiKaraage](https://github.com/KiKaraage).

![Screenshot of customized downloads menu](https://raw.githubusercontent.com/MihkelMK/zen-mods/refs/heads/main/cleaner_downloads/image.png)

## Top Bar Tweaks

Small fixes for the top Nav Bar.

![Screenshot of modified topbar](https://raw.githubusercontent.com/MihkelMK/zen-mods/refs/heads/main/topbar_tweaks/image.png)
