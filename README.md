# In-Game Lua Editor for MTA:SA v4.0

[![MTA:SA](https://img.shields.io/badge/MTA%3ASA-Compatible-blue)](https://multitheftauto.com/)
[![Version](https://img.shields.io/badge/version-4.0-green)](https://github.com/BrandSilva/LuaEditorMTA)
[![License](https://img.shields.io/badge/license-Free-brightgreen)](https://github.com/BrandSilva/LuaEditorMTA)

**FORUM:** [In-Game Lua Editor - MTA:SA](https://forum.multitheftauto.com/topic/146355-professional-in-game-lua-editor-free-release/)

**VIDEO DEMO:** [[Watch on YouTube]](https://youtu.be/mc87jbFDJIk)

**DISCORD:** [Join the community](https://discord.gg/mjWuv7Zbyh)

---

## 🎯 Overview

A complete professional Lua code editor that runs directly inside MTA:SA. Edit your server scripts in real-time without leaving the game or dealing with FTP uploads. Full development environment with advanced resource management, a draggable floating panel, `.map` editing and a modern Catppuccin-inspired UI.

Version 4.0 is a major rewrite focused on **stability** (no more CEF crashes), **flexibility** (movable panel + map editing) and a **fresh modern look**.

---

## 🚀 What's New in v4.0

### 🗺️ Map Editing (NEW)
- **Create `.map` files** directly from the editor (File → Map type)
- **Edit `.map` and `.xml`** with full XML syntax highlighting
- **Auto meta.xml** registration of new maps with `<map src="..." dimension="0" />`
- Map files get their own **color tab** (gold) for instant recognition

### 🪟 Movable Floating Panel (NEW)
- The whole editor is now a **draggable window** — grab the header and move it anywhere
- Stays clamped inside the screen (never lost off-viewport)
- Auto-centers on open, dragging ignores buttons so controls keep working

### 🛡️ CEF Crash Fixes (NEW)
The biggest reason for v4.0. MTA's CEF (Chromium) browser was prone to crashing when the panel opened/closed quickly or received data before it was ready. Fixed with:
- **Asynchronous load guard** — JS only runs after the browser is fully initialized
- **Double validation** (`browser exists` + `panel visible`) before every `executeBrowserJavascript` call
- **Hardened string escaping** for file content sent to the browser (backslash, quotes, newlines, `<` / `>`), eliminating broken-injection crashes
- Result: **stable open/close, no more random client freezes or crashes**

### 🎨 New Theme (NEW)
- Modern **Catppuccin Mocha** dark palette across the whole interface
- **Color-coded file types**: client (green), server (orange), shared (blue), html (pink), **map (gold)**, meta (purple)
- Cleaner CodeMirror Material Darker editor area with refined gutters and line numbers

### 💾 Safety Improvements (NEW)
- **Automatic `.backup`** of every file before it is overwritten on save
- **Companion detection** — compiled `.luac` scripts now show their `.lua` source when available
- Compiled files are flagged read-only in the UI to prevent corrupting bytecode

---

## ✨ Key Features

### 🔥 Advanced Resource Management
- **Create Resources** - Choose organizational folder on creation (`[ADMIN]`, `[GAMEMODES]`, etc.)
- **Rename & Relocate** - Rename resources AND move them to different folders in one action
- **Delete Resources** - Configurable resource deletion with confirmation dialogs
- **Base Path System** - Restrict developers to specific folders (e.g., each dev has their own `[ADMIN]` folder)
- **Auto Meta.xml** - Automatic meta.xml generation and synchronization

### 💻 Development Tools
- **CodeMirror Integration** - Professional syntax highlighting for Lua, XML and HTML
- **Real-time Editing** - Save and update scripts instantly, optional auto-restart on save
- **File Management** - Create, edit, delete Client / Server / Shared / HTML / **Map** files
- **Subdirectory Support** - Create files in subdirectories (e.g., `routes/myfile.lua`)
- **Live Counters** - Real-time line and character count
- **Multi-Language** - English, Spanish, Portuguese, Turkish, Arabic

### 🔒 Security & Control
- **ACL Permission System** - Admin-only access with configurable ACL groups
- **Base Path Restrictions** - Lock developers to specific organizational folders
- **Resource Filtering** - Whitelist / Blacklist system for resource access
- **Function Guardrail** - Optional blacklist for risky Lua functions (`loadstring`, etc.)
- **Activity Logging** - SQLite database with full audit trail
- **Path Protection** - Directory traversal and XSS prevention

### 🎨 Professional Interface
- **Draggable Panel** - Move the editor anywhere on screen
- **Smart Search** - Persistent filtering during all operations
- **Intelligent Updates** - No UI flickering or jumps when the list refreshes
- **File Tabs** - Color-coded by type with sync status indicator
- **In-panel Notifications** - Real-time operation feedback
- **Dark Theme** - Modern Catppuccin + Material Darker editor

---

## 🔧 Quick Installation

### 1. Add Resource
Extract to your server `resources` folder.

### 2. Configure ACL
Add to `acl.xml`:
```xml
<group name="Admin">
    <acl name="Admin"></acl>
    <object name="resource.luaeditor"></object>
</group>
```

**IMPORTANT:** The resource requires `Admin` ACL permissions to function.

### 3. Configure Settings
Edit `editorS.lua` (line 15):
```lua
local permissionACL = "Admin"  -- Change to your ACL group
```

### 4. Start & Use
```
start luaeditor
```
In-game command: `/editor`

---

## ⚙️ Configuration

All settings live at the top of `editorS.lua` (lines 15-24):

```lua
local permissionACL = "Admin"               -- ACL group required (e.g., "Admin", "Moderator")
local enableBlackList = false               -- Block specific resources from editing
local enableWhiteList = false               -- Allow ONLY whitelisted resources (opt-in lockdown)
local enableDeleteFiles = true              -- Allow file deletion
local enableDeleteResources = true          -- Allow resource deletion
local enableSelfEdit = false                -- Allow editing this resource itself
local enableLogs = true                     -- Enable SQLite activity logging
local enableFunctionBlacklist = false       -- Block risky functions (guardrail, not a security boundary)
local maxLogEntries = 400                   -- Maximum log entries before rotation
local resourceBasePath = ""                 -- Restrict to folder (e.g., "[ADMIN]" or "" for all)
```

### Base Path System Example
Restrict developer "John" to only edit resources in a `[JOHN]` folder:
```lua
local resourceBasePath = "[JOHN]"
```
John can now only see/edit resources inside the `[JOHN]` folder. Perfect for team organization — it works like an SFTP chroot jail.

> ⚠️ **Security note:** Anyone with the editor's ACL permission can run arbitrary server-side Lua through any editable resource. Keep the whitelist minimal and only grant access to trusted developers. `enableFunctionBlacklist` is a substring guardrail, not a real sandbox.

---

## 📖 Usage Guide

### Opening the Editor
Command: `/editor` (requires ACL permissions). Drag the panel header to reposition it.

### Creating Resources
1. Click **"Create Resource"**
2. Enter a resource name
3. *(Optional)* Enter an organizational folder (e.g., `[ADMIN]`, `myScripts`)
4. Folder structure and `meta.xml` are generated automatically

### Renaming & Relocating Resources
1. Hover over a resource → click the **"R"** button
2. Enter the new name
3. *(Optional)* Enter a new path to move it
4. The resource is renamed AND relocated in one action

### Creating Files
1. Select a resource
2. Click **"Create File"**
3. Choose type: **Client, Server, Shared, HTML or Map**
4. Enter a filename (subdirectories supported: `routes/myfile.lua`)

### Editing Files
1. Click a file in the list
2. Edit with syntax highlighting (Lua / XML / HTML)
3. Click **"Save"** or press `Ctrl+S` — a `.backup` is written automatically before overwriting
4. *(Optional)* Tick **"Restart on save"** to reload the resource instantly

### Deleting
- **Resources:** hover → click **"×"** → confirm (if `enableDeleteResources = true`)
- **Files:** hover → click delete → confirm — `meta.xml` is auto-updated

---

## 🛡️ Security Features

- **ACL validation** on every server-side action; guest accounts blocked automatically
- **Base Path restrictions** for multi-developer isolation
- **Whitelist / Blacklist** resource control + **self-edit protection**
- **Running-resource protection** (can't rename a running resource)
- **Path traversal protection** (`..` blocked) and **HTML-entity / escaped** dynamic content
- **File size limit** (1 MB max per file) and **automatic backups**
- **Audit logging** (SQLite) of create / edit / delete / rename / restart with player, account, timestamp and details — auto-rotated at `maxLogEntries`, viewable in-editor

---

## 🌍 Supported Languages

🇬🇧 English | 🇪🇸 Spanish | 🇧🇷 Portuguese | 🇹🇷 Turkish | 🇸🇦 Arabic

Switch language with the buttons in the editor header.

---

## 💡 Why Use This

**Before:**
- ❌ Alt-tab to external editors
- ❌ FTP upload/download cycles
- ❌ Server restarts for every script change
- ❌ Manual meta.xml and map editing
- ❌ Command-line resource management

**After:**
- ✅ Edit directly in-game from a movable panel
- ✅ Instant script + map updates
- ✅ Visual resource management
- ✅ Auto meta.xml sync
- ✅ A complete, crash-free development environment

---

## 🔄 Version History

**v4.0 (2026)** — Map (`.map`) creation & editing, draggable floating panel, CEF crash fixes, new Catppuccin theme, automatic backups, companion (`.luac` → `.lua`) detection, hardened browser escaping

**v3.0 (2025)** — Resource creation with folder selection, rename & relocate, base path system, activity logging, security features, multi-language, intelligent DOM updates

**v2.0 (2025)** — CodeMirror integration, resource browser, ACL system

**v1.0 (2025)** — Initial release

---

## 📞 Contact & Support

**Developer:** BranD - Trident Sky Company
**Email:** tridentskycompany@gmail.com
**Discord:** [discord.gg/mjWuv7Zbyh](https://discord.gg/mjWuv7Zbyh) (BrandSilva)
**Forum:** [MTA:SA Forum Topic](https://forum.multitheftauto.com/topic/146355-professional-in-game-lua-editor-free-release/)

---

## 📜 License

© 2026 Brando Silva. All rights reserved.

**Free for the MTA:SA Community**

✅ Free to use on any server | ✅ Free to modify for personal use
❌ Do not redistribute as your own | ❌ Do not sell or commercialize

---

## 🙏 Credits

- **BranD** — Author, core architecture and all base code
- **CodeMirror** — Syntax highlighting engine
- **MTA:SA Team** — Platform support
- **Community** — Feedback and testing
- **Claude (Anthropic)** — AI assistant that helped polish and refine the code

---

⭐ **If you find this useful, star the repository and share it with the MTA community!**

---

*Developed with ❤️ for the MTA:SA community*
