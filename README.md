# In-Game Lua Editor for MTA:SA v3.0

[![MTA:SA](https://img.shields.io/badge/MTA%3ASA-Compatible-blue)](https://multitheftauto.com/)
[![Version](https://img.shields.io/badge/version-3.0-green)](https://github.com)
[![License](https://img.shields.io/badge/license-Free-brightgreen)](https://github.com)

**FORUM:** [In-Game Lua Editor - MTA:SA](https://forum.multitheftauto.com/topic/146355-professional-in-game-lua-editor-free-release/)

**VIDEO DEMO:** [[Watch on YouTube]](https://youtu.be/qqVed1QIco8)

---

## 🎯 Overview

A complete professional Lua code editor that runs directly inside MTA:SA. Edit your server scripts in real-time without leaving the game or dealing with FTP uploads. Full development environment with advanced resource management and professional UI.

---

## ✨ Key Features

### 🔥 Advanced Resource Management (NEW)
- **Create Resources** - Choose organizational folder on creation (`[ADMIN]`, `[GAMEMODES]`, etc.)
- **Rename & Relocate** - Rename resources AND move them to different folders in one action
- **Delete Resources** - Configurable resource deletion with confirmation dialogs
- **Base Path System** - Restrict developers to specific folders (e.g., each dev has their own `[ADMIN]` folder)
- **Auto Meta.xml** - Automatic meta.xml generation and synchronization

### 💻 Development Tools
- **CodeMirror Integration** - Professional syntax highlighting and editing
- **Real-time Editing** - Save and update scripts instantly without server restart
- **File Management** - Create, edit, delete Lua files (client/server/shared/html)
- **Subdirectory Support** - Create files in subdirectories (e.g., `routes/myfile.lua`)
- **Multi-Language** - English, Spanish, Portuguese, Turkish, Arabic

### 🔒 Security & Control
- **ACL Permission System** - Admin-only access with configurable ACL groups
- **Base Path Restrictions** - Lock developers to specific organizational folders
- **Resource Filtering** - Whitelist/Blacklist system for resource access
- **Function Blacklist** - Block dangerous Lua functions (`loadstring`, etc.)
- **Activity Logging** - SQLite database with full audit trail
- **Path Protection** - XSS and directory traversal prevention

### 🎨 Professional Interface
- **Smart Search** - Persistent filtering during all operations
- **Intelligent Updates** - No UI flickering or jumps
- **Color-coded Files** - Visual type indicators (client/server/shared/meta)
- **In-panel Notifications** - Real-time operation feedback
- **Dark Theme** - Professional CodeMirror Material Darker theme

---

## 🚀 What's New in v3.0

### Resource Management Features
- ✅ **Create with Folder Selection** - Choose organizational directory when creating resources
- ✅ **Rename & Relocate** - Change resource name AND move to different folder simultaneously
- ✅ **Configurable Deletion** - Enable/disable resource deletion via config
- ✅ **Base Path System** - Restrict editing to specific folders for team organization

### Performance & UX
- ✅ **Intelligent DOM Updates** - No UI flickering during list updates
- ✅ **Persistent Search** - Search term maintained during operations
- ✅ **Improved State Management** - Editor clears only when deleting/renaming active resource
- ✅ **Fixed Refresh Button** - Properly triggers resource list reload

---

## 🔧 Quick Installation

### 1. Add Resource
Extract to `resources` folder

### 2. Configure ACL
Add to `acl.xml`:
```xml
<group name="Admin">
    <acl name="Admin"></acl>
    <object name="resource.luaeditor"></object>
</group>
```

**IMPORTANT:** Resource requires `Admin` ACL permissions to function.

### 3. Configure Settings
Edit `editorS.lua` line 15:
```lua
local permissionACL = "Admin"  -- Change to your ACL group
```

### 4. Start & Use
```
start luaeditor
```
In-game: `/editor`

---

## ⚙️ Configuration

All settings in `editorS.lua` (lines 15-24):

```lua
local permissionACL = "Admin"               -- ACL group required (e.g., "Admin", "Moderator")
local enableBlackList = false               -- Block specific resources from editing
local enableWhiteList = false               -- Allow only specific resources
local enableDeleteFiles = true              -- Allow file deletion
local enableDeleteResources = true          -- Allow resource deletion
local enableSelfEdit = false                -- Allow editing this resource itself
local enableLogs = true                     -- Enable SQLite activity logging
local enableFunctionBlacklist = true        -- Block dangerous functions
local maxLogEntries = 400                   -- Maximum log entries before rotation
local resourceBasePath = ""                 -- Restrict to folder (e.g., "[ADMIN]" or "" for all)
```

### Base Path System Example
Restrict developer "John" to only edit resources in `[JOHN]` folder:
```lua
local resourceBasePath = "[JOHN]"
```
John can now only see/edit resources inside `[JOHN]` folder. Perfect for team organization!

### Function Blacklist
When `enableFunctionBlacklist = true`, these functions are blocked:
- `loadstring`, `setAccountPassword`, `removeAccount`, `deleteResource`
- `executeSQLQuery`, `load`, `dofile`, `loadfile`

---

## 📖 Usage Guide

### Opening Editor
Command: `/editor` (requires ACL permissions)

### Creating Resources
1. Click **"Create Resource"**
2. Enter resource name
3. **(Optional)** Enter organizational folder (e.g., `[ADMIN]`, `myScripts`)
4. Auto-generates folder structure and meta.xml

### Renaming & Relocating Resources
1. Hover over resource → Click **"R"** button
2. Enter new name
3. **(Optional)** Enter new organizational path to move it
4. Resource is renamed AND relocated in one action

### Creating Files
1. Select resource
2. Click **"Create File"**
3. Choose type: Client, Server, Shared, or HTML
4. Enter filename (supports subdirectories: `routes/myfile.lua`)

### Editing Files
1. Click file in list
2. Edit with syntax highlighting
3. Click **"Save"** or press `Ctrl+S`

### Deleting Resources
1. Hover over resource → Click **"×"** button
2. Confirm deletion
3. Entire resource folder removed (if `enableDeleteResources = true`)

### Deleting Files
1. Hover over file → Click delete button
2. Confirm deletion
3. Meta.xml auto-updated

---

## 🛡️ Security Features

### ACL Permission System
- All operations require ACL validation
- Configurable via `permissionACL` variable
- Server-side validation on every action
- Guest accounts blocked automatically

### Base Path Restrictions
Powerful feature for multi-developer environments:
```lua
local resourceBasePath = "[ADMIN]"
```
- Developers see ONLY resources in specified folder
- Cannot access/edit resources outside their folder
- Perfect for isolating developer workspaces
- Works like an SFTP chroot jail

### Resource Controls
- **Whitelist Mode:** Allow only specific resources
- **Blacklist Mode:** Block specific resources
- **Self-Edit Protection:** Prevent editing the editor itself
- **Running Resource Protection:** Can't rename running resources

### Code Safety
- Function blacklist for dangerous operations
- Path traversal protection (`..` attacks blocked)
- XSS protection with HTML entity encoding
- File size limits (1MB max per file)

### Audit Logging
When `enableLogs = true`:
- Tracks all create/edit/delete/rename operations
- Stores player name, account, timestamp, and details
- SQLite database with auto-rotation at `maxLogEntries`
- View logs in-editor via "View Logs" button

---

## 🌍 Supported Languages

🇬🇧 English | 🇪🇸 Spanish | 🇧🇷 Portuguese | 🇹🇷 Turkish | 🇸🇦 Arabic

Switch language in editor interface.

---

## 💡 Why Use This

**Before:**
- ❌ Alt-tab to external editors
- ❌ FTP upload/download cycles
- ❌ Server restarts for script changes
- ❌ Manual meta.xml editing
- ❌ Command-line resource management

**After:**
- ✅ Edit directly in-game
- ✅ Instant script updates
- ✅ Visual resource management
- ✅ Auto meta.xml sync
- ✅ Complete development environment

---

## 🔄 Version History

**v3.0 (2025)** - Resource creation with folder selection, rename & relocate, base path system, activity logging, security features, multi-language, intelligent DOM updates

**v2.0 (2025)** - CodeMirror integration, resource browser, ACL system

**v1.0 (2025)** - Initial release

---

## 📞 Contact & Support

**Developer:** BranD - Trident Sky Company
**Email:** tridentskycompany@gmail.com
**Discord:** BrandSilva
**Forum:** [MTA:SA Forum Topic](https://forum.multitheftauto.com/topic/146355-professional-in-game-lua-editor-free-release/)

---

## 📜 License

© 2025 Brando Silva. All rights reserved.

**Free for MTA:SA Community**

✅ Free to use on any server | ✅ Free to modify for personal use
❌ Do not redistribute as your own | ❌ Do not sell or commercialize

---

## 🙏 Credits

- **BranD** - Core development and architecture
- **Claude Code** - Frontend interface and code logic assistance
- **CodeMirror** - Syntax highlighting engine
- **MTA:SA Team** - Platform support
- **Community** - Feedback and testing

---

⭐ **If you find this useful, star the repository and share with the MTA community!**

---

*Developed with ❤️ for the MTA:SA community*
