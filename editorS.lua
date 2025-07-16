------------------------------------------------------------------------------------------------
--
--  PROJECT:         Trident Sky Company
--  VERSION:         2.0
--  FILE:            editorS.lua
--  PURPOSE:         Lua Code Editor Server-side
--  DEVELOPERS:      [BranD] - Lead Developer
--  CONTACT:         tridentskycompany@gmail.com | Discord: BrandSilva
--  COPYRIGHT:       © 2025 Brando Silva All rights reserved.
--                   This software is protected by copyright laws.
--                   Unauthorized distribution or modification is strictly prohibited.
--
------------------------------------------------------------------------------------------------

local permissionACL = "Admin" --[[You Admin ACL Here]]
local enableBlackList = false --[[Activate it if you want to allow all scripts except those you add to this list.]]
local enableWhiteList = false --[[Activate if you want to allow only the scripts you select.]]

local whiteList = {
    "ScriptName",
}

local blackList = {
    "ScriptName",
}

function globToPattern(glob)
    local pattern = glob

    pattern = pattern:gsub("([%.%+%-%^%$%(%)%%])", "%%%1")
    pattern = pattern:gsub("%*%*/%*", ".*")      -- **/*
    pattern = pattern:gsub("%*%*", ".*")         -- **
    pattern = pattern:gsub("%*", "[^/]*")        -- *

    return "^" .. pattern .. "$"
end

function recursiveListFiles(path, useDot)
    local entries = pathListDir(path .. (useDot and "." or ""))
    if not entries then
        return {}
    end

    local files = {}
    for _, entry in ipairs(entries) do
        local fullPath = (path:sub(-1) == "/" and path:sub(1, -2) or path) .. "/" .. entry

        if pathIsDirectory(fullPath) then
            local subFiles = recursiveListFiles(fullPath)
            for _, f in ipairs(subFiles) do
                table.insert(files, f)
            end
        elseif pathIsFile(fullPath) then
            table.insert(files, fullPath)
        end
    end

    return files
end

function resolveGlob(resourceName, glob)
    local base = ":" .. resourceName .. "/"
    local result = {}

    local allFiles = recursiveListFiles(base, true)
    local pattern = globToPattern(glob)

    for _, file in ipairs(allFiles) do
        local relativePath = file:sub(#base + 1)
        if relativePath:match(pattern) then
            table.insert(result, relativePath)
        end
    end

    return result
end

local globCache = {}
local function resolveGlobCached(resourceName, glob)
    local key = resourceName .. ":" .. glob
    if not globCache[key] then
        globCache[key] = resolveGlob(resourceName, glob)
    end
    return globCache[key]
end


function isScriptAllowed(scriptName)
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
        for i,acl in ipairs(acl) do
            if (isObjectInACLGroup("user."..getAccountName(account), aclGetGroup(acl))) then
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

function getAllResourcesData()
    local resourcesData = {}
    for i, resource in ipairs(getResources()) do
        local resourceName = getResourceName(resource)
        if (resourceName and resourceName ~= getResourceName(getThisResource())) then
            if (isScriptAllowed(resourceName)) then
                local scriptData = getResourceFiles(resourceName)
                if (scriptData and (#scriptData.clientFiles > 0 or #scriptData.serverFiles > 0)) then
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

    local files = { clientFiles = {}, serverFiles = {} }
    local metaFile = xmlLoadFile(":" .. resourceName .. "/meta.xml")
    if (not metaFile) then return files end

    for i, node in ipairs(xmlNodeGetChildren(metaFile)) do
        if (xmlNodeGetName(node) == "script") then
            local scriptPath = xmlNodeGetAttribute(node, "src")
            local scriptType = xmlNodeGetAttribute(node, "type") or "server"

            if (scriptPath) then
                if scriptPath:find("*") then
                    local matchedFiles = resolveGlobCached(resourceName, scriptPath)
                    for _, path in ipairs(matchedFiles) do
                        if scriptType == "client" then
                            table.insert(files.clientFiles, path)
                        elseif scriptType == "server" then
                            table.insert(files.serverFiles, path)
                        end
                    end
                else
                    if scriptType == "client" then
                        table.insert(files.clientFiles, scriptPath)
                    elseif scriptType == "server" then
                        table.insert(files.serverFiles, scriptPath)
                    end
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
        if (xmlNodeGetName(node) == "script") then
            local scriptPath = xmlNodeGetAttribute(node, "src")
            local scriptType = xmlNodeGetAttribute(node, "type") or "server"

            if (scriptPath) then
                if scriptPath:find("*") then
                    local matchedFiles = resolveGlobCached(resourceName, scriptPath)
                    for _, path in ipairs(matchedFiles) do
                        table.insert(files, {
                            path = path,
                            type = scriptType
                        })
                    end
                else
                    table.insert(files, {
                        path = scriptPath,
                        type = scriptType
                    })
                end
            end
        end
    end

    xmlUnloadFile(metaFile)
    return files
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
    outputServerLog("LUA_EDITOR: " .. playerName .. " (" .. accountName .. ") modified file: " .. scriptName .. "/" .. filePath)
end
addEvent("luaEditor.saveFileContent", true)
addEventHandler("luaEditor.saveFileContent", root, saveFileContent)