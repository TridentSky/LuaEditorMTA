------------------------------------------------------------------------------------------------
--
--  PROJECT:         Lua Editor MTA:SA
--  VERSION:         3.0
--  FILE:            editorS.lua
--  PURPOSE:         Lua Code Editor Server-side Enhanced with Advanced Features
--  DEVELOPERS:      [BranD] - Lead Developer
--  CONTACT:         tridentskycompany@gmail.com | Discord: BrandSilva
--  COPYRIGHT:       © 2025 Brando Silva All rights reserved.
--                   This software is protected by copyright laws.
--                   Unauthorized distribution or modification is strictly prohibited.
--
------------------------------------------------------------------------------------------------

local permissionACL = "Admin"               -- ACL group required to use the editor (Admin = Admin level)
local enableBlackList = false               -- Block specific resources from being edited
local enableWhiteList = false               -- Allow only specific resources to be edited
local enableDeleteFiles = true              -- Allow deletion of individual script files
local enableDeleteResources = true          -- Allow deletion of entire resources
local enableSelfEdit = false                -- Allow editing the Lua Editor resource itself
local enableLogs = true                     -- Enable activity logging to database
local enableFunctionBlacklist = false       -- Block dangerous Lua functions in code
local maxLogEntries = 400                   -- Maximum number of log entries to store
local resourceBasePath = ""                 -- Restrict editing to specific folder (e.g., "[ADMIN]" or "" for all)

local whiteList = {
    "ScriptName",
}

local blackList = {
    "ScriptName",
}

local functionBlacklist = { -- example dangerous functions
    "loadstring",
    "setAccountPassword",
    "removeAccount",
    "deleteResource",
    "executeSQLQuery",
    "load",
    "dofile",
    "loadfile",
}

local logsDatabase = nil

function checkResourcePermissions()
    local thisResource = getThisResource()
    if (not thisResource) then
        return false
    end

    local resourceName = getResourceName(thisResource)
    local testFilePath = ":" .. resourceName .. "/test_acl.tmp"
    local testFile = fileCreate(testFilePath)

    if (not testFile) then
        outputDebugString("LUA_EDITOR: Missing ACL permissions - Add resource." .. resourceName .. " to ACL", 1)
        return false
    end

    fileClose(testFile)
    fileDelete(testFilePath)
    return true
end

function initializeLogsSystem()
    if (not enableLogs) then
        return
    end

    logsDatabase = dbConnect("sqlite", ":" .. getResourceName(getThisResource()) .. "/logs.db")
    if (not logsDatabase) then
        outputDebugString("LUA_EDITOR: Failed to connect to logs database", 1)
        return
    end

    local createTableQuery = [[
        CREATE TABLE IF NOT EXISTS activity_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player TEXT NOT NULL,
            account TEXT NOT NULL,
            action TEXT NOT NULL,
            resource TEXT NOT NULL,
            file TEXT NOT NULL,
            details TEXT,
            date TEXT NOT NULL,
            time TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        )
    ]]

    dbExec(logsDatabase, createTableQuery)

    dbExec(logsDatabase, "DELETE FROM activity_logs WHERE id NOT IN (SELECT id FROM activity_logs ORDER BY timestamp DESC LIMIT ?)", maxLogEntries)
end

function addLogEntry(playerName, accountName, action, targetResource, targetFile, details)
    if (not enableLogs or not logsDatabase) then
        return
    end

    local timestamp = getRealTime()
    local dateStr = string.format("%04d-%02d-%02d", timestamp.year + 1900, timestamp.month + 1, timestamp.monthday)
    local timeStr = string.format("%02d:%02d:%02d", timestamp.hour, timestamp.minute, timestamp.second)
    local timestampNum = os.time()

    local insertQuery = [[
        INSERT INTO activity_logs (player, account, action, resource, file, details, date, time, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]

    dbExec(logsDatabase, insertQuery,
        playerName or "Unknown",
        accountName or "Unknown",
        action or "Unknown",
        targetResource or "N/A",
        targetFile or "N/A",
        details or "",
        dateStr,
        timeStr,
        timestampNum
    )

    dbExec(logsDatabase, "DELETE FROM activity_logs WHERE id NOT IN (SELECT id FROM activity_logs ORDER BY timestamp DESC LIMIT ?)", maxLogEntries)
end

function getLogsData()
    if (not enableLogs or not logsDatabase) then
        return {}
    end

    local query = "SELECT player, account, action, resource, file, details, date, time FROM activity_logs ORDER BY timestamp DESC LIMIT ?"
    local queryHandle = dbQuery(logsDatabase, query, maxLogEntries)
    if (not queryHandle) then
        return {}
    end

    local result = dbPoll(queryHandle, -1)
    if (not result) then
        return {}
    end

    return result
end

function validateFunctionBlacklist(content)
    if (not enableFunctionBlacklist) then
        return true, ""
    end

    for i, funcName in ipairs(functionBlacklist) do
        if (string.find(content, funcName)) then
            return false, funcName
        end
    end

    return true, ""
end

function isResourcePathAllowed(resourceName)
    if (not resourceBasePath or resourceBasePath == "" or resourceBasePath == "main") then
        return true
    end

    local resourcePath = getResourceName(getResourceFromName(resourceName))
    if (not resourcePath) then
        return false
    end

    local basePath = resourceBasePath:gsub("%[", ""):gsub("%]", "")

    if (string.find(resourcePath, basePath)) then
        return true
    end

    return false
end

function isPlayerInACLGroup(player, ...)
    if (not player or not ...) then
        return false
    end
    if (not isElement(player) or getElementType(player) ~= "player") then
        return false
    end
    local account = getPlayerAccount(player)
    if (isGuestAccount(account)) then return false end

    local acl = {...}
    if (#acl == 1) then
        return isObjectInACLGroup("user."..getAccountName(account), aclGetGroup(acl[1])) or false
    else
        for i, aclName in ipairs(acl) do
            if (isObjectInACLGroup("user."..getAccountName(account), aclGetGroup(aclName))) then
                return true
            end
        end
        return false
    end
end

function hasPermission(player)
    if (not player or not isElement(player)) then
        return false
    end
    return isPlayerInACLGroup(player, permissionACL)
end

function isPlayerOnline(player)
    return player and isElement(player) and getElementType(player) == "player"
end

function isResourcePathAllowed(scriptName)
    if (not resourceBasePath or resourceBasePath == "") then
        return true
    end

    local resource = getResourceFromName(scriptName)
    if (not resource) then
        return false
    end

    local orgPath = getResourceOrganizationalPath(resource)
    if (not orgPath) then
        return false
    end

    return string.find(orgPath, resourceBasePath, 1, true) ~= nil
end

function isScriptAllowed(scriptName)
    if (not enableSelfEdit and scriptName == getResourceName(getThisResource())) then
        return false
    end

    if (not isResourcePathAllowed(scriptName)) then
        return false
    end

    if (enableWhiteList) then
        for i, allowedScript in ipairs(whiteList) do
            if (allowedScript == scriptName) then
                return true
            end
        end
        return false
    end

    if (enableBlackList) then
        for i, blockedScript in ipairs(blackList) do
            if (blockedScript == scriptName) then
                return false
            end
        end
    end

    return true
end

function getAllResourcesData()
    local resourcesData = {}
    for i, resource in ipairs(getResources()) do
        local resourceName = getResourceName(resource)
        if (resourceName and resourceName ~= getResourceName(getThisResource())) then
            local shouldInclude = true

            if (resourceBasePath and resourceBasePath ~= "") then
                local orgPath = getResourceOrganizationalPath(resource)
                shouldInclude = (orgPath and string.find(orgPath, resourceBasePath, 1, true) ~= nil)
            end

            if (shouldInclude and isScriptAllowed(resourceName)) then
                local scriptData = getResourceFiles(resourceName)
                if (scriptData and (#scriptData.clientFiles > 0 or #scriptData.serverFiles > 0 or #scriptData.sharedFiles > 0)) then
                    scriptData.name = resourceName
                    table.insert(resourcesData, scriptData)
                end
            end
        end
    end
    return resourcesData
end

function getResourceFiles(resourceName)
    local resource = getResourceFromName(resourceName)
    if (not resource) then return nil end

    local files = { clientFiles = {}, serverFiles = {}, sharedFiles = {} }
    local metaFile = xmlLoadFile(":" .. resourceName .. "/meta.xml")
    if (not metaFile) then return files end

    for i, node in ipairs(xmlNodeGetChildren(metaFile)) do
        if (xmlNodeGetName(node) == "script") then
            local scriptPath = xmlNodeGetAttribute(node, "src")
            local scriptType = xmlNodeGetAttribute(node, "type") or "server"

            if (scriptPath) then
                if (scriptType == "client") then
                    table.insert(files.clientFiles, scriptPath)
                elseif (scriptType == "server") then
                    table.insert(files.serverFiles, scriptPath)
                elseif (scriptType == "shared") then
                    table.insert(files.sharedFiles, scriptPath)
                end
            end
        end
    end

    xmlUnloadFile(metaFile)
    return files
end

function getDetailedResourceFiles(resourceName)
    local resource = getResourceFromName(resourceName)
    if (not resource) then return {} end

    local files = {}
    local metaFile = xmlLoadFile(":" .. resourceName .. "/meta.xml")
    if (not metaFile) then return files end

    for i, node in ipairs(xmlNodeGetChildren(metaFile)) do
        local nodeName = xmlNodeGetName(node)

        if (nodeName == "script") then
            local scriptPath = xmlNodeGetAttribute(node, "src")
            local scriptType = xmlNodeGetAttribute(node, "type") or "server"

            if (scriptPath) then
                table.insert(files, {
                    path = scriptPath,
                    type = scriptType
                })
            end
        elseif (nodeName == "file") then
            local filePath = xmlNodeGetAttribute(node, "src")

            if (filePath) then
                local fileExt = string.match(filePath, "%.([^%.]+)$")
                if (fileExt and string.lower(fileExt) == "html") then
                    table.insert(files, {
                        path = filePath,
                        type = "html"
                    })
                end
            end
        end
    end

    table.insert(files, {
        path = "meta.xml",
        type = "meta"
    })

    xmlUnloadFile(metaFile)
    return files
end

function updateMetaXmlFile(resourceName, filePath, actionType)
    if (not resourceName or not filePath) then return false end

    local metaPath = ":" .. resourceName .. "/meta.xml"
    if (not fileExists(metaPath)) then return false end

    local metaFile = xmlLoadFile(metaPath)
    if (not metaFile) then return false end

    if (actionType == "delete") then
        for i, node in ipairs(xmlNodeGetChildren(metaFile)) do
            local nodeName = xmlNodeGetName(node)
            if (nodeName == "script" or nodeName == "file") then
                local scriptPath = xmlNodeGetAttribute(node, "src")
                if (scriptPath == filePath) then
                    xmlDestroyNode(node)
                    break
                end
            end
        end
    elseif (actionType == "create") then
        local fileType = filePath.type
        local fileName = filePath.name

        local metaHandle = fileOpen(metaPath, true)
        if (not metaHandle) then
            xmlUnloadFile(metaFile)
            return false
        end

        local metaContent = fileRead(metaHandle, fileGetSize(metaHandle))
        fileClose(metaHandle)

        local newScriptLine = ""
        if (fileType == "html") then
            newScriptLine = '    <file src="' .. fileName .. '" />'
        else
            newScriptLine = '    <script src="' .. fileName .. '" type="' .. fileType .. '" />'
        end

        local insertPos = string.find(metaContent, "</meta>")

        if (insertPos) then
            local newContent = string.sub(metaContent, 1, insertPos - 1) .. newScriptLine .. "\n" .. string.sub(metaContent, insertPos)

            if (fileExists(metaPath)) then
                fileDelete(metaPath)
            end

            local newFile = fileCreate(metaPath)
            if (newFile) then
                fileWrite(newFile, newContent)
                fileClose(newFile)
                xmlUnloadFile(metaFile)
                return true
            end
        end
    end

    local success = xmlSaveFile(metaFile)
    xmlUnloadFile(metaFile)
    return success
end

function openEditorForPlayer(player)
    if (not hasPermission(player)) then
        outputChatBox("Access denied: Insufficient permissions", player, 255, 0, 0)
        return
    end

    local scriptsData = getAllResourcesData()
    triggerClientEvent(player, "luaEditor.onScriptsListReceived", player, scriptsData)
end
addCommandHandler("editor", openEditorForPlayer)

function requestScriptsList()
    if (not client) then
        return
    end
    if (not hasPermission(client)) then
        outputChatBox("Access denied: Insufficient permissions", client, 255, 0, 0)
        return
    end

    local scriptsData = getAllResourcesData()
    triggerClientEvent(client, "luaEditor.onScriptsListReceived", client, scriptsData)
end
addEvent("luaEditor.requestScriptsList", true)
addEventHandler("luaEditor.requestScriptsList", root, requestScriptsList)

function requestScriptFiles(scriptName)
    if (not client) then
        return
    end
    if (not hasPermission(client)) then
        outputChatBox("Access denied: Insufficient permissions", client, 255, 0, 0)
        return
    end

    if (not scriptName or scriptName == "") then
        outputChatBox("Error: Invalid script name", client, 255, 0, 0)
        return
    end

    if (not isScriptAllowed(scriptName)) then
        outputChatBox("Error: Script is not allowed for editing", client, 255, 0, 0)
        return
    end

    local files = getDetailedResourceFiles(scriptName)
    outputChatBox("Loading files for: " .. scriptName .. " (" .. #files .. " files)", client, 0, 255, 255)
    triggerClientEvent(client, "luaEditor.onScriptFilesReceived", client, scriptName, files)
end
addEvent("luaEditor.requestScriptFiles", true)
addEventHandler("luaEditor.requestScriptFiles", root, requestScriptFiles)

function requestFileContent(scriptName, filePath)
    if (not client) then
        return
    end
    if (not hasPermission(client)) then
        outputChatBox("Access denied: Insufficient permissions", client, 255, 0, 0)
        return
    end

    if (not scriptName or not filePath or scriptName == "" or filePath == "") then
        outputChatBox("Error: Invalid parameters", client, 255, 0, 0)
        return
    end

    if (not isPlayerOnline(client)) then
        return
    end

    if (not isScriptAllowed(scriptName)) then
        outputChatBox("Error: Script is not allowed for editing", client, 255, 0, 0)
        return
    end

    scriptName = scriptName:gsub("[^%w%-%_]", "")
    filePath = filePath:gsub("%.%.", ""):gsub("//", "/")

    if (string.find(scriptName, "%.%.") or string.find(filePath, "%.%.")) then
        outputChatBox("Error: Invalid path traversal detected", client, 255, 0, 0)
        return
    end

    local fullPath = ":" .. scriptName .. "/" .. filePath

    if (not fileExists(fullPath)) then
        outputChatBox("Error: File does not exist - " .. filePath, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileContentReceived", client, "")
        return
    end

    if (string.find(filePath, "%.luac$")) then
        outputChatBox("Error: Cannot edit compiled files", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileContentReceived", client, "-- This file is compiled and cannot be edited")
        return
    end

    local fileHandle = fileOpen(fullPath, true)
    if (not fileHandle) then
        outputChatBox("Error: Cannot open file - " .. filePath, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileContentReceived", client, "")
        return
    end

    local fileContent = fileRead(fileHandle, fileGetSize(fileHandle))
    fileClose(fileHandle)

    if (string.byte(fileContent, 1) == 28) then
        outputChatBox("Error: File is compiled and cannot be edited", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileContentReceived", client, "-- This file is compiled and cannot be edited")
        return
    end

    triggerClientEvent(client, "luaEditor.onFileContentReceived", client, fileContent)
    outputChatBox("File loaded: " .. scriptName .. "/" .. filePath, client, 0, 255, 0)
end
addEvent("luaEditor.requestFileContent", true)
addEventHandler("luaEditor.requestFileContent", root, requestFileContent)

function saveFileContent(scriptName, filePath, content)
    if (not client) then
        return
    end
    if (not hasPermission(client)) then
        outputChatBox("Access denied: Insufficient permissions", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileSaved", client, false, "Access denied")
        return
    end

    if (not scriptName or not filePath or not content or scriptName == "" or filePath == "") then
        outputChatBox("Error: Invalid parameters", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileSaved", client, false, "Invalid parameters")
        return
    end

    if (not isPlayerOnline(client)) then
        return
    end

    if (not isScriptAllowed(scriptName)) then
        outputChatBox("Error: Script is not allowed for editing", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileSaved", client, false, "Script not allowed")
        return
    end

    local isValid, blockedFunction = validateFunctionBlacklist(content)
    if (not isValid) then
        outputChatBox("Error: Blocked function detected: " .. blockedFunction, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileSaved", client, false, "Blocked function: " .. blockedFunction)

        local playerName = getPlayerName(client)
        local accountName = getAccountName(getPlayerAccount(client))
        addLogEntry(playerName, accountName, "BLOCKED_FUNCTION", scriptName, filePath, "Attempted to use: " .. blockedFunction)

        return
    end

    scriptName = scriptName:gsub("[^%w%-%_]", "")
    filePath = filePath:gsub("%.%.", ""):gsub("//", "/")

    if (string.find(scriptName, "%.%.") or string.find(filePath, "%.%.")) then
        outputChatBox("Error: Invalid path traversal detected", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileSaved", client, false, "Invalid path")
        return
    end

    if (string.len(content) > 1048576) then
        outputChatBox("Error: File too large (max 1MB)", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileSaved", client, false, "File too large")
        return
    end

    local fullPath = ":" .. scriptName .. "/" .. filePath

    if (not fileExists(fullPath)) then
        outputChatBox("Error: File does not exist - " .. filePath, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileSaved", client, false, "File does not exist")
        return
    end

    if (string.find(filePath, "%.luac$")) then
        outputChatBox("Error: Cannot modify compiled files", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileSaved", client, false, "Cannot modify compiled files")
        return
    end

    local backupPath = fullPath .. ".backup"
    if (fileExists(backupPath)) then
        fileDelete(backupPath)
    end

    local originalFile = fileOpen(fullPath, true)
    if (originalFile) then
        local originalContent = fileRead(originalFile, fileGetSize(originalFile))
        fileClose(originalFile)

        local backupFile = fileCreate(backupPath)
        if (backupFile) then
            fileWrite(backupFile, originalContent)
            fileClose(backupFile)
        end
    end

    if (fileExists(fullPath)) then
        fileDelete(fullPath)
    end

    local newFile = fileCreate(fullPath)
    if (not newFile) then
        outputChatBox("Error: Cannot create file - " .. filePath, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileSaved", client, false, "Cannot create file")
        return
    end

    fileWrite(newFile, content)
    fileClose(newFile)

    if (fileExists(backupPath)) then
        fileDelete(backupPath)
    end

    outputChatBox("File saved successfully: " .. scriptName .. "/" .. filePath, client, 0, 255, 0)
    triggerClientEvent(client, "luaEditor.onFileSaved", client, true, "File saved successfully")

    local playerName = getPlayerName(client)
    local accountName = getAccountName(getPlayerAccount(client))
    addLogEntry(playerName, accountName, "EDIT", scriptName, filePath, "File modified")
end
addEvent("luaEditor.saveFileContent", true)
addEventHandler("luaEditor.saveFileContent", root, saveFileContent)

function deleteFileFromResource(scriptName, filePath)
    if (not client) then
        return
    end
    if (not hasPermission(client)) then
        outputChatBox("Access denied: Insufficient permissions", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileDeleted", client, false, "Access denied")
        return
    end

    if (not enableDeleteFiles) then
        outputChatBox("Error: File deletion is disabled by administrator", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileDeleted", client, false, "File deletion disabled")
        return
    end

    if (not scriptName or not filePath or scriptName == "" or filePath == "") then
        outputChatBox("Error: Invalid parameters", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileDeleted", client, false, "Invalid parameters")
        return
    end

    if (not isPlayerOnline(client)) then
        return
    end

    if (not isScriptAllowed(scriptName)) then
        outputChatBox("Error: Script is not allowed for editing", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileDeleted", client, false, "Script not allowed")
        return
    end

    if (filePath == "meta.xml") then
        outputChatBox("Error: Cannot delete meta.xml file", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileDeleted", client, false, "Cannot delete meta.xml")
        return
    end

    scriptName = scriptName:gsub("[^%w%-%_]", "")
    filePath = filePath:gsub("%.%.", ""):gsub("//", "/")

    if (string.find(scriptName, "%.%.") or string.find(filePath, "%.%.")) then
        outputChatBox("Error: Invalid path traversal detected", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileDeleted", client, false, "Invalid path")
        return
    end

    local fullPath = ":" .. scriptName .. "/" .. filePath

    if (not fileExists(fullPath)) then
        outputChatBox("Error: File does not exist - " .. filePath, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileDeleted", client, false, "File does not exist")
        return
    end

    if (updateMetaXmlFile(scriptName, filePath, "delete")) then
        if (fileDelete(fullPath)) then
            outputChatBox("File deleted successfully: " .. scriptName .. "/" .. filePath, client, 0, 255, 0)
            triggerClientEvent(client, "luaEditor.onFileDeleted", client, true, "File deleted successfully")

            local playerName = getPlayerName(client)
            local accountName = getAccountName(getPlayerAccount(client))
            addLogEntry(playerName, accountName, "DELETE", scriptName, filePath, "File deleted")
        else
            outputChatBox("Error: Failed to delete file - " .. filePath, client, 255, 0, 0)
            triggerClientEvent(client, "luaEditor.onFileDeleted", client, false, "Failed to delete file")
        end
    else
        outputChatBox("Error: Failed to update meta.xml", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileDeleted", client, false, "Failed to update meta.xml")
    end
end
addEvent("luaEditor.deleteFile", true)
addEventHandler("luaEditor.deleteFile", root, deleteFileFromResource)

function createNewFile(scriptName, fileName, fileType)
    if (not client) then
        return
    end
    if (not hasPermission(client)) then
        outputChatBox("Access denied: Insufficient permissions", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileCreated", client, false, "Access denied")
        return
    end

    if (not scriptName or not fileName or not fileType or scriptName == "" or fileName == "") then
        outputChatBox("Error: Invalid parameters", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileCreated", client, false, "Invalid parameters")
        return
    end

    if (not isPlayerOnline(client)) then
        return
    end

    if (not isScriptAllowed(scriptName)) then
        outputChatBox("Error: Script is not allowed for editing", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileCreated", client, false, "Script not allowed")
        return
    end

    if (fileType ~= "client" and fileType ~= "server" and fileType ~= "shared" and fileType ~= "html") then
        outputChatBox("Error: Invalid file type", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileCreated", client, false, "Invalid file type")
        return
    end

    scriptName = scriptName:gsub("[^%w%-%_]", "")
    fileName = fileName:gsub("[^%w%-%_%.%/]", "")

    if (string.find(scriptName, "%.%.") or string.find(fileName, "%.%.")) then
        outputChatBox("Error: Invalid path traversal detected", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileCreated", client, false, "Invalid path")
        return
    end

    if (fileType == "html") then
        if (not string.find(fileName, "%.html$")) then
            fileName = fileName .. ".html"
        end
    else
        if (not string.find(fileName, "%.lua$")) then
            fileName = fileName .. ".lua"
        end
    end

    local fullPath = ":" .. scriptName .. "/" .. fileName

    if (fileExists(fullPath)) then
        outputChatBox("Error: File already exists - " .. fileName, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileCreated", client, false, "File already exists")
        return
    end

    local fileTemplate = ""
    if (fileType == "client") then
        fileTemplate = "-- Client-side script\n-- File: " .. fileName .. "\n\n"
    elseif (fileType == "server") then
        fileTemplate = "-- Server-side script\n-- File: " .. fileName .. "\n\n"
    elseif (fileType == "shared") then
        fileTemplate = "-- Shared script (client & server)\n-- File: " .. fileName .. "\n\n"
    elseif (fileType == "html") then
        fileTemplate = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>]] .. fileName .. [[</title>
</head>
<body>

</body>
</html>]]
    end

    local newFile = fileCreate(fullPath)
    if (not newFile) then
        outputChatBox("Error: Cannot create file - " .. fileName, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileCreated", client, false, "Cannot create file")
        return
    end

    fileWrite(newFile, fileTemplate)
    fileClose(newFile)

    if (updateMetaXmlFile(scriptName, {name = fileName, type = fileType}, "create")) then
        outputChatBox("File created successfully: " .. scriptName .. "/" .. fileName, client, 0, 255, 0)
        triggerClientEvent(client, "luaEditor.onFileCreated", client, true, "File created successfully")

        local playerName = getPlayerName(client)
        local accountName = getAccountName(getPlayerAccount(client))
        addLogEntry(playerName, accountName, "CREATE", scriptName, fileName, "File type: " .. fileType)
    else
        fileDelete(fullPath)
        outputChatBox("Error: Failed to update meta.xml", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onFileCreated", client, false, "Failed to update meta.xml")
    end
end
addEvent("luaEditor.createFile", true)
addEventHandler("luaEditor.createFile", root, createNewFile)

function createNewResource(resourceName, organizationalDir)
    if (not client) then
        return
    end
    if (not hasPermission(client)) then
        outputChatBox("Access denied: Insufficient permissions", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceCreated", client, false, "Access denied")
        return
    end

    if (not resourceName or resourceName == "") then
        outputChatBox("Error: Invalid resource name", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceCreated", client, false, "Invalid resource name")
        return
    end

    resourceName = resourceName:gsub("[^%w%-%_]", "")

    local existingResource = getResourceFromName(resourceName)
    if (existingResource) then
        outputChatBox("Error: Resource already exists - " .. resourceName, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceCreated", client, false, "Resource already exists")
        return
    end

    if (resourceBasePath and resourceBasePath ~= "") then
        organizationalDir = resourceBasePath
    elseif (organizationalDir and organizationalDir ~= "") then
        organizationalDir = organizationalDir:gsub("[^%w%-%_%/%[%]]", "")
    else
        organizationalDir = nil
    end

    local newResource = createResource(resourceName, organizationalDir)
    if (not newResource) then
        outputChatBox("Error: Failed to create resource - " .. resourceName, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceCreated", client, false, "Failed to create resource")
        return
    end

    local clientContent = "-- Client-side script\n-- File: client.lua\n\n"
    local clientPath = ":" .. resourceName .. "/client.lua"
    local clientFile = fileCreate(clientPath)
    if (clientFile) then
        fileWrite(clientFile, clientContent)
        fileClose(clientFile)
    end

    local serverContent = "-- Server-side script\n-- File: server.lua\n\n"
    local serverPath = ":" .. resourceName .. "/server.lua"
    local serverFile = fileCreate(serverPath)
    if (serverFile) then
        fileWrite(serverFile, serverContent)
        fileClose(serverFile)
    end

    local metaContent = [[<meta>
    <info author="" name="]] .. resourceName .. [[" type="script" version="1.0" />
    <min_mta_version server="1.6" client="1.5.9" />

    <script src="server.lua" type="server" />
    <script src="client.lua" type="client" />
</meta>]]

    local metaPath = ":" .. resourceName .. "/meta.xml"
    local metaFile = fileCreate(metaPath)
    if (metaFile) then
        fileWrite(metaFile, metaContent)
        fileClose(metaFile)
    end

    refreshResources(false)

    outputChatBox("Resource created successfully: " .. resourceName, client, 0, 255, 0)
    triggerClientEvent(client, "luaEditor.onResourceCreated", client, true, "Resource created successfully", resourceName)

    local playerName = getPlayerName(client)
    local accountName = getAccountName(getPlayerAccount(client))
    addLogEntry(playerName, accountName, "CREATE_RESOURCE", resourceName, "N/A", "Organizational dir: " .. (organizationalDir or "none"))

    setTimer(function()
        if (isPlayerOnline(client)) then
            local updatedScripts = getAllResourcesData()
            triggerClientEvent(client, "luaEditor.onScriptsListReceived", client, updatedScripts)
        end
    end, 800, 1)
end
addEvent("luaEditor.createResource", true)
addEventHandler("luaEditor.createResource", root, createNewResource)

function renameResourceName(oldResourceName, newResourceName, organizationalPath)
    if (not client) then
        return
    end
    if (not hasPermission(client)) then
        outputChatBox("Access denied: Insufficient permissions", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceRenamed", client, false, "Access denied")
        return
    end

    if (not oldResourceName or not newResourceName or oldResourceName == "" or newResourceName == "") then
        outputChatBox("Error: Invalid resource names", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceRenamed", client, false, "Invalid resource names")
        return
    end

    oldResourceName = oldResourceName:gsub("[^%w%-%_]", "")
    newResourceName = newResourceName:gsub("[^%w%-%_]", "")

    local resource = getResourceFromName(oldResourceName)
    if (not resource) then
        outputChatBox("Error: Resource not found - " .. oldResourceName, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceRenamed", client, false, "Resource not found")
        return
    end

    local resourceState = getResourceState(resource)
    if (resourceState == "running") then
        outputChatBox("Error: Cannot rename a running resource. Please stop it first.", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceRenamed", client, false, "Cannot rename a running resource. Please stop it first.")
        return
    end

    if (resourceBasePath and resourceBasePath ~= "") then
        local currentOrgPath = getResourceOrganizationalPath(resource)
        if (not currentOrgPath or not string.find(currentOrgPath, resourceBasePath, 1, true)) then
            outputChatBox("Error: Resource is not in allowed base path", client, 255, 0, 0)
            triggerClientEvent(client, "luaEditor.onResourceRenamed", client, false, "Resource not in allowed base path")
            return
        end
        organizationalPath = resourceBasePath
    elseif (organizationalPath and organizationalPath ~= "") then
        organizationalPath = organizationalPath:gsub("[^%w%-%_%/%[%]]", "")
    else
        organizationalPath = nil
    end

    local success = renameResource(oldResourceName, newResourceName, organizationalPath)
    if (not success) then
        outputChatBox("Error: Failed to rename resource", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceRenamed", client, false, "Failed to rename resource")
        return
    end

    refreshResources(false)

    outputChatBox("Resource renamed successfully: " .. oldResourceName .. " -> " .. newResourceName, client, 0, 255, 0)
    triggerClientEvent(client, "luaEditor.onResourceRenamed", client, true, "Resource renamed successfully")

    local playerName = getPlayerName(client)
    local accountName = getAccountName(getPlayerAccount(client))
    addLogEntry(playerName, accountName, "RENAME_RESOURCE", oldResourceName, newResourceName, "New name: " .. newResourceName)

    setTimer(function()
        if (isPlayerOnline(client)) then
            local updatedScripts = getAllResourcesData()
            triggerClientEvent(client, "luaEditor.onScriptsListReceived", client, updatedScripts)
        end
    end, 800, 1)
end
addEvent("luaEditor.renameResource", true)
addEventHandler("luaEditor.renameResource", root, renameResourceName)

function deleteResourceCompletely(resourceName)
    if (not client) then
        return
    end

    if (not hasPermission(client)) then
        outputChatBox("Access denied: Insufficient permissions", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceDeleted", client, false, "Access denied")
        return
    end

    if (not enableDeleteResources) then
        outputChatBox("Error: Resource deletion is disabled", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceDeleted", client, false, "Resource deletion is disabled")
        return
    end

    if (not resourceName or resourceName == "") then
        outputChatBox("Error: Invalid resource name", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceDeleted", client, false, "Invalid resource name")
        return
    end

    resourceName = resourceName:gsub("[^%w%-%_]", "")

    local resource = getResourceFromName(resourceName)
    if (not resource) then
        outputChatBox("Error: Resource not found - " .. resourceName, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceDeleted", client, false, "Resource not found")
        return
    end

    if (getResourceName(getThisResource()) == resourceName) then
        outputChatBox("Error: Cannot delete the editor itself", client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceDeleted", client, false, "Cannot delete the editor itself")
        return
    end

    local resourceState = getResourceState(resource)
    if (resourceState == "running") then
        outputChatBox("Stopping resource: " .. resourceName, client, 255, 255, 0)
        local stopped = stopResource(resource)
        if (not stopped) then
            outputChatBox("Error: Could not stop running resource", client, 255, 0, 0)
            triggerClientEvent(client, "luaEditor.onResourceDeleted", client, false, "Could not stop running resource")
            return
        end

        setTimer(function()
            local success = deleteResource(resourceName)
            if (not success) then
                outputChatBox("Error: Failed to delete resource - " .. resourceName, client, 255, 0, 0)
                triggerClientEvent(client, "luaEditor.onResourceDeleted", client, false, "Failed to delete resource")
                return
            end

            refreshResources(false)

            outputChatBox("Resource deleted successfully: " .. resourceName, client, 0, 255, 0)
            triggerClientEvent(client, "luaEditor.onResourceDeleted", client, true, "Resource deleted successfully")

            local playerName = getPlayerName(client)
            local accountName = getAccountName(getPlayerAccount(client))
            addLogEntry(playerName, accountName, "DELETE_RESOURCE", resourceName, "N/A", "Resource completely removed")

            setTimer(function()
                if (isPlayerOnline(client)) then
                    local updatedScripts = getAllResourcesData()
                    triggerClientEvent(client, "luaEditor.onScriptsListReceived", client, updatedScripts)
                end
            end, 500, 1)
        end, 300, 1)
        return
    end

    local success = deleteResource(resourceName)
    if (not success) then
        outputChatBox("Error: Failed to delete resource - " .. resourceName, client, 255, 0, 0)
        triggerClientEvent(client, "luaEditor.onResourceDeleted", client, false, "Failed to delete resource")
        return
    end

    refreshResources(false)

    outputChatBox("Resource deleted successfully: " .. resourceName, client, 0, 255, 0)
    triggerClientEvent(client, "luaEditor.onResourceDeleted", client, true, "Resource deleted successfully")

    local playerName = getPlayerName(client)
    local accountName = getAccountName(getPlayerAccount(client))
    addLogEntry(playerName, accountName, "DELETE_RESOURCE", resourceName, "N/A", "Resource completely removed")

    setTimer(function()
        if (isPlayerOnline(client)) then
            local updatedScripts = getAllResourcesData()
            triggerClientEvent(client, "luaEditor.onScriptsListReceived", client, updatedScripts)
        end
    end, 800, 1)
end
addEvent("luaEditor.deleteResource", true)
addEventHandler("luaEditor.deleteResource", root, deleteResourceCompletely)

function requestLogs()
    if (not client) then
        return
    end
    if (not hasPermission(client)) then
        outputChatBox("Access denied: Insufficient permissions", client, 255, 0, 0)
        return
    end

    if (not enableLogs) then
        triggerClientEvent(client, "luaEditor.onLogsReceived", client, {})
        return
    end

    local logsData = getLogsData()
    triggerClientEvent(client, "luaEditor.onLogsReceived", client, logsData)
end
addEvent("luaEditor.requestLogs", true)
addEventHandler("luaEditor.requestLogs", root, requestLogs)

function onResourceStart()
    local aclGroupObject = aclGetGroup(permissionACL)
    if (not aclGroupObject) then
        outputDebugString("LUA_EDITOR: ACL group '" .. permissionACL .. "' does not exist. Please create it or change the permissionACL variable.", 1)
        return
    end

    if (not checkResourcePermissions()) then
        outputDebugString("LUA_EDITOR: Failed to start - Missing ACL permissions", 1)
        return
    end

    initializeLogsSystem()
end
addEventHandler("onResourceStart", resourceRoot, onResourceStart)
