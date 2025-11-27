------------------------------------------------------------------------------------------------
--
--  PROJECT:         Lua Editor MTA:SA
--  VERSION:         3.0
--  FILE:            editorC.lua
--  PURPOSE:         Lua Code Editor Client-side Enhanced with Advanced Features
--  DEVELOPERS:      [BranD] - Lead Developer
--  CONTACT:         tridentskycompany@gmail.com | Discord: BrandSilva
--  COPYRIGHT:       © 2025 Brando Silva All rights reserved.
--                   This software is protected by copyright laws.
--                   Unauthorized distribution or modification is strictly prohibited.
--
------------------------------------------------------------------------------------------------

local editorBrowser = nil
local editorGui = nil
local isMinimized = false
local defaultLanguage = "en"

function createEditorPanel()
    if (editorGui) then
        destroyElement(editorGui)
        editorGui = nil
        editorBrowser = nil
    end

    local screenW, screenH = guiGetScreenSize()
    editorGui = guiCreateBrowser(0, 0, screenW, screenH, true, true, false)

    if (editorGui) then
        editorBrowser = guiGetBrowser(editorGui)
        addEventHandler("onClientBrowserCreated", editorGui, onBrowserCreated)
        guiSetVisible(editorGui, true)
        guiBringToFront(editorGui)
        showCursor(true)
        return true
    end

    return false
end

function onBrowserCreated()
    if (editorBrowser) then
        loadBrowserURL(editorBrowser, "http://mta/local/index.html")
        focusBrowser(editorBrowser)

        setTimer(function()
            if (editorBrowser and guiGetVisible(editorGui)) then
                executeBrowserJavascript(editorBrowser, 'setDefaultLanguage("' .. defaultLanguage .. '");')
            end
        end, 500, 1)
    end
end

function openEditorPanel(scripts)
    if (not editorGui) then
        if (createEditorPanel()) then
            setTimer(function()
                if (editorBrowser) then
                    loadScriptsList(scripts)
                end
            end, 2000, 1)
        end
    else
        if (not guiGetVisible(editorGui)) then
            guiSetVisible(editorGui, true)
            guiBringToFront(editorGui)
            showCursor(true)
            focusBrowser(editorBrowser)
            isMinimized = false
        end
        loadScriptsList(scripts)
    end
end

function loadScriptsList(scripts)
    if (not editorBrowser) then return end

    if (scripts and #scripts > 0) then
        local jsArray = "["
        for i, script in ipairs(scripts) do
            if (i > 1) then jsArray = jsArray .. "," end

            local clientFiles = "["
            if (script.clientFiles) then
                for j, file in ipairs(script.clientFiles) do
                    if (j > 1) then clientFiles = clientFiles .. "," end
                    clientFiles = clientFiles .. '"' .. file .. '"'
                end
            end
            clientFiles = clientFiles .. "]"

            local serverFiles = "["
            if (script.serverFiles) then
                for j, file in ipairs(script.serverFiles) do
                    if (j > 1) then serverFiles = serverFiles .. "," end
                    serverFiles = serverFiles .. '"' .. file .. '"'
                end
            end
            serverFiles = serverFiles .. "]"

            local sharedFiles = "["
            if (script.sharedFiles) then
                for j, file in ipairs(script.sharedFiles) do
                    if (j > 1) then sharedFiles = sharedFiles .. "," end
                    sharedFiles = sharedFiles .. '"' .. file .. '"'
                end
            end
            sharedFiles = sharedFiles .. "]"

            jsArray = jsArray .. '{'
            jsArray = jsArray .. 'name:"' .. script.name .. '",'
            jsArray = jsArray .. 'clientFiles:' .. clientFiles .. ','
            jsArray = jsArray .. 'serverFiles:' .. serverFiles .. ','
            jsArray = jsArray .. 'sharedFiles:' .. sharedFiles
            jsArray = jsArray .. '}'
        end
        jsArray = jsArray .. "]"

        executeBrowserJavascript(editorBrowser, "loadScriptsList(" .. jsArray .. ");")
    end
end

function loadScriptFiles(scriptName, files)
    if (not editorBrowser or not guiGetVisible(editorGui)) then return end

    if (not files or #files == 0) then
        executeBrowserJavascript(editorBrowser, "loadScriptFiles('" .. scriptName .. "', []);")
        return
    end

    local jsArray = "["
    for i, file in ipairs(files) do
        if (i > 1) then jsArray = jsArray .. "," end

        local isCompiled = string.find(file.path, "%.luac$") ~= nil

        jsArray = jsArray .. '{'
        jsArray = jsArray .. 'path:"' .. file.path .. '",'
        jsArray = jsArray .. 'type:"' .. file.type .. '",'
        jsArray = jsArray .. 'compiled:' .. (isCompiled and "true" or "false")
        jsArray = jsArray .. '}'
    end
    jsArray = jsArray .. "]"

    executeBrowserJavascript(editorBrowser, "loadScriptFiles('" .. scriptName .. "', " .. jsArray .. ");")
end

function sendFileContent(content)
    if (not editorBrowser or not guiGetVisible(editorGui)) then return end

    local escapedContent = content:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\r", ""):gsub("<", "\\x3C"):gsub(">", "\\x3E")
    executeBrowserJavascript(editorBrowser, 'receiveFileContent("' .. escapedContent .. '");')
end

function sendLogsData(logs)
    if (not editorBrowser or not guiGetVisible(editorGui)) then return end

    if (not logs or #logs == 0) then
        executeBrowserJavascript(editorBrowser, "receiveLogsData([]);")
        return
    end

    local jsArray = "["
    for i, log in ipairs(logs) do
        if (i > 1) then jsArray = jsArray .. "," end

        local player = log.player or "Unknown"
        local account = log.account or "Unknown"
        local action = log.action or "Unknown"
        local resource = log.resource or "N/A"
        local file = log.file or "N/A"
        local details = log.details or ""
        local date = log.date or "N/A"
        local time = log.time or "N/A"

        player = player:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("&", "&amp;")
        account = account:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("&", "&amp;")
        action = action:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("&", "&amp;")
        resource = resource:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("&", "&amp;")
        file = file:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("&", "&amp;")
        details = details:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("&", "&amp;")

        jsArray = jsArray .. '{'
        jsArray = jsArray .. 'player:"' .. player .. '",'
        jsArray = jsArray .. 'account:"' .. account .. '",'
        jsArray = jsArray .. 'action:"' .. action .. '",'
        jsArray = jsArray .. 'resource:"' .. resource .. '",'
        jsArray = jsArray .. 'file:"' .. file .. '",'
        jsArray = jsArray .. 'details:"' .. details .. '",'
        jsArray = jsArray .. 'date:"' .. date .. '",'
        jsArray = jsArray .. 'time:"' .. time .. '"'
        jsArray = jsArray .. '}'
    end
    jsArray = jsArray .. "]"

    executeBrowserJavascript(editorBrowser, "receiveLogsData(" .. jsArray .. ");")
end

function closePanel()
    if (editorGui) then
        removeEventHandler("onClientBrowserCreated", editorGui, onBrowserCreated)
        destroyElement(editorGui)
        editorGui = nil
        editorBrowser = nil
        showCursor(false)
        isMinimized = false
    end
end
addEvent("luaEditor.closePanel", true)
addEventHandler("luaEditor.closePanel", root, closePanel)

function minimizePanel()
    if (editorGui and guiGetVisible(editorGui)) then
        guiSetVisible(editorGui, false)
        showCursor(false)
        isMinimized = true
    end
end
addEvent("luaEditor.minimizePanel", true)
addEventHandler("luaEditor.minimizePanel", root, minimizePanel)

function restoreEditorPanel()
    if (editorGui and isMinimized) then
        guiSetVisible(editorGui, true)
        guiBringToFront(editorGui)
        showCursor(true)
        focusBrowser(editorBrowser)
        isMinimized = false
    end
end

function requestScriptsList()
    triggerServerEvent("luaEditor.requestScriptsList", localPlayer)
end
addEvent("luaEditor.requestScriptsList", true)
addEventHandler("luaEditor.requestScriptsList", root, requestScriptsList)

function requestScriptFiles(scriptName)
    if (scriptName and scriptName ~= "") then
        triggerServerEvent("luaEditor.requestScriptFiles", localPlayer, scriptName)
    end
end
addEvent("luaEditor.requestScriptFiles", true)
addEventHandler("luaEditor.requestScriptFiles", root, requestScriptFiles)

function requestFileContent(scriptName, filePath)
    if (scriptName and filePath and scriptName ~= "" and filePath ~= "") then
        triggerServerEvent("luaEditor.requestFileContent", localPlayer, scriptName, filePath)
    end
end
addEvent("luaEditor.requestFileContent", true)
addEventHandler("luaEditor.requestFileContent", root, requestFileContent)

function saveFileContent(scriptName, filePath, content)
    if (scriptName and filePath and content and scriptName ~= "" and filePath ~= "") then
        triggerServerEvent("luaEditor.saveFileContent", localPlayer, scriptName, filePath, content)
    end
end
addEvent("luaEditor.saveFileContent", true)
addEventHandler("luaEditor.saveFileContent", root, saveFileContent)

function deleteFile(scriptName, filePath)
    if (scriptName and filePath and scriptName ~= "" and filePath ~= "") then
        triggerServerEvent("luaEditor.deleteFile", localPlayer, scriptName, filePath)
    end
end
addEvent("luaEditor.deleteFile", true)
addEventHandler("luaEditor.deleteFile", root, deleteFile)

function createFile(scriptName, fileName, fileType)
    if (scriptName and fileName and fileType and scriptName ~= "" and fileName ~= "") then
        triggerServerEvent("luaEditor.createFile", localPlayer, scriptName, fileName, fileType)
    end
end
addEvent("luaEditor.createFile", true)
addEventHandler("luaEditor.createFile", root, createFile)

function createResource(resourceName, organizationalDir)
    if (resourceName and resourceName ~= "") then
        triggerServerEvent("luaEditor.createResource", localPlayer, resourceName, organizationalDir)
    end
end
addEvent("luaEditor.createResource", true)
addEventHandler("luaEditor.createResource", root, createResource)

function renameResource(oldResourceName, newResourceName, organizationalPath)
    if (oldResourceName and newResourceName and oldResourceName ~= "" and newResourceName ~= "") then
        triggerServerEvent("luaEditor.renameResource", localPlayer, oldResourceName, newResourceName, organizationalPath)
    end
end
addEvent("luaEditor.renameResource", true)
addEventHandler("luaEditor.renameResource", root, renameResource)

function requestLogs()
    triggerServerEvent("luaEditor.requestLogs", localPlayer)
end
addEvent("luaEditor.requestLogs", true)
addEventHandler("luaEditor.requestLogs", root, requestLogs)

function deleteResource(resourceName)
    if (resourceName and resourceName ~= "") then
        triggerServerEvent("luaEditor.deleteResource", localPlayer, resourceName)
    end
end
addEvent("luaEditor.deleteResource", true)
addEventHandler("luaEditor.deleteResource", root, deleteResource)

function onScriptsListReceived(scripts)
    openEditorPanel(scripts)
end
addEvent("luaEditor.onScriptsListReceived", true)
addEventHandler("luaEditor.onScriptsListReceived", localPlayer, onScriptsListReceived)

function onScriptFilesReceived(scriptName, files)
    loadScriptFiles(scriptName, files)
end
addEvent("luaEditor.onScriptFilesReceived", true)
addEventHandler("luaEditor.onScriptFilesReceived", localPlayer, onScriptFilesReceived)

function onFileContentReceived(content)
    sendFileContent(content)
end
addEvent("luaEditor.onFileContentReceived", true)
addEventHandler("luaEditor.onFileContentReceived", localPlayer, onFileContentReceived)

function onFileSaved(success, message)
    if (editorBrowser and guiGetVisible(editorGui)) then
        local jsMessage = message:gsub("\\", "\\\\"):gsub("\"", "\\\"")
        executeBrowserJavascript(editorBrowser, 'onFileSaved(' .. (success and "true" or "false") .. ', "' .. jsMessage .. '");')
    end
end
addEvent("luaEditor.onFileSaved", true)
addEventHandler("luaEditor.onFileSaved", localPlayer, onFileSaved)

function onFileDeleted(success, message)
    if (editorBrowser and guiGetVisible(editorGui)) then
        local jsMessage = message:gsub("\\", "\\\\"):gsub("\"", "\\\"")
        executeBrowserJavascript(editorBrowser, 'onFileDeleted(' .. (success and "true" or "false") .. ', "' .. jsMessage .. '");')
    end
end
addEvent("luaEditor.onFileDeleted", true)
addEventHandler("luaEditor.onFileDeleted", localPlayer, onFileDeleted)

function onFileCreated(success, message)
    if (editorBrowser and guiGetVisible(editorGui)) then
        local jsMessage = message:gsub("\\", "\\\\"):gsub("\"", "\\\"")
        executeBrowserJavascript(editorBrowser, 'onFileCreated(' .. (success and "true" or "false") .. ', "' .. jsMessage .. '");')
    end
end
addEvent("luaEditor.onFileCreated", true)
addEventHandler("luaEditor.onFileCreated", localPlayer, onFileCreated)

function onResourceCreated(success, message)
    if (editorBrowser and guiGetVisible(editorGui)) then
        local jsMessage = message:gsub("\\", "\\\\"):gsub("\"", "\\\"")
        executeBrowserJavascript(editorBrowser, 'onResourceCreated(' .. (success and "true" or "false") .. ', "' .. jsMessage .. '");')
    end
end
addEvent("luaEditor.onResourceCreated", true)
addEventHandler("luaEditor.onResourceCreated", localPlayer, onResourceCreated)

function onResourceRenamed(success, message)
    if (editorBrowser and guiGetVisible(editorGui)) then
        local jsMessage = message:gsub("\\", "\\\\"):gsub("\"", "\\\"")
        executeBrowserJavascript(editorBrowser, 'onResourceRenamed(' .. (success and "true" or "false") .. ', "' .. jsMessage .. '");')
    end
end
addEvent("luaEditor.onResourceRenamed", true)
addEventHandler("luaEditor.onResourceRenamed", localPlayer, onResourceRenamed)

function onResourceDeleted(success, message)
    if (editorBrowser and guiGetVisible(editorGui)) then
        local jsMessage = message:gsub("\\", "\\\\"):gsub("\"", "\\\"")
        executeBrowserJavascript(editorBrowser, 'onResourceDeleted(' .. (success and "true" or "false") .. ', "' .. jsMessage .. '");')
    end
end
addEvent("luaEditor.onResourceDeleted", true)
addEventHandler("luaEditor.onResourceDeleted", localPlayer, onResourceDeleted)

function onLogsReceived(logs)
    sendLogsData(logs)
end
addEvent("luaEditor.onLogsReceived", true)
addEventHandler("luaEditor.onLogsReceived", localPlayer, onLogsReceived)
