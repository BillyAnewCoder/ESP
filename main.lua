-- ESP Preview System - Executor Optimized
-- Usage: loadstring(game:HttpGet("your-url"))()

local ESPPreview = {}
ESPPreview.__index = ESPPreview

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

-- Get LocalPlayer with executor-safe method
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    repeat task.wait() until Players.LocalPlayer
    LocalPlayer = Players.LocalPlayer
end

-- Configuration
local PREVIEW_CONFIG = {
    Size = Vector2.new(250, 350),
    Position = Vector2.new(50, 50),
    BackgroundColor = Color3.fromRGB(25, 25, 25),
    BorderColor = Color3.fromRGB(60, 60, 60),
    TitleColor = Color3.fromRGB(255, 255, 255),
    BoxColor = Color3.fromRGB(255, 255, 255),
    BoxOutlineColor = Color3.fromRGB(0, 0, 0),
    HealthBarBackgroundColor = Color3.fromRGB(0, 0, 0),
    HealthBarGoodColor = Color3.fromRGB(0, 255, 0),
    HealthBarBadColor = Color3.fromRGB(255, 0, 0),
    ChamColor1 = Color3.fromRGB(93, 62, 152),
    ChamColor2 = Color3.fromRGB(255, 255, 255),
    SkeletonOutlineColor = Color3.fromRGB(0, 0, 0),
    SkeletonColor = Color3.fromRGB(255, 255, 255),
}

-- Cleanup existing instances
local function CleanupExisting()
    -- Check multiple possible locations
    for _, parent in ipairs({CoreGui, LocalPlayer.PlayerGui, game.Workspace}) do
        if parent then
            local existing = parent:FindFirstChild("ESPPreview")
            if existing then
                existing:Destroy()
            end
        end
    end
end

function ESPPreview.new(customParent)
    CleanupExisting()
    
    local instance = setmetatable({}, ESPPreview)
    
    -- Determine parent with executor-friendly approach
    local targetParent = customParent
    if not targetParent then
        -- Try different parents based on executor capabilities
        if gethui then
            targetParent = gethui()
        elseif syn and syn.protect_gui then
            local gui = Instance.new("ScreenGui")
            syn.protect_gui(gui)
            gui.Parent = CoreGui
            targetParent = gui
        elseif LocalPlayer.PlayerGui then
            targetParent = LocalPlayer.PlayerGui
        else
            targetParent = CoreGui
        end
    end
    
    instance.Parent = targetParent
    instance.Visible = true
    instance.HealthValue = 1.0
    instance.HealthAnimation = 0
    instance.Components = {}
    instance.Connections = {}
    
    -- Create with immediate verification
    local success = pcall(function()
        instance:CreatePreviewWindow()
        -- Verify window exists before continuing
        if not instance.MainFrame or not instance.MainFrame.Parent then
            error("MainFrame failed to parent")
        end
        
        instance:CreateESPComponents()
        instance:StartAnimations()
    end)
    
    if not success then
        warn("ESPPreview creation failed")
        if instance.MainFrame then instance.MainFrame:Destroy() end
        return nil
    end
    
    -- Force update to ensure visibility
    task.spawn(function()
        task.wait(0.1)
        if instance.MainFrame then
            instance.MainFrame.Visible = true
            print("ESP Preview now visible at position:", instance.MainFrame.AbsolutePosition)
        end
    end)
    
    return instance
end

function ESPPreview:CreatePreviewWindow()
    -- Create container first (some executors need this)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ESPPreview"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 100
    
    -- Protect GUI if possible
    if syn and syn.protect_gui then
        syn.protect_gui(screenGui)
    end
    
    screenGui.Parent = self.Parent
    
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, PREVIEW_CONFIG.Size.X, 0, PREVIEW_CONFIG.Size.Y)
    frame.Position = UDim2.new(0, PREVIEW_CONFIG.Position.X, 0, PREVIEW_CONFIG.Position.Y)
    frame.BackgroundColor3 = PREVIEW_CONFIG.BackgroundColor
    frame.BorderSizePixel = 1
    frame.BorderColor3 = PREVIEW_CONFIG.BorderColor
    frame.Active = true
    frame.Draggable = true
    frame.ZIndex = 10
    frame.Parent = screenGui
    
    self.ScreenGui = screenGui
    self.MainFrame = frame

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = PREVIEW_CONFIG.BorderColor
    titleBar.BorderSizePixel = 0
    titleBar.ZIndex = 11
    titleBar.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -30, 1, 0)
    title.Position = UDim2.new(0, 5, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "ESP Preview"
    title.TextColor3 = PREVIEW_CONFIG.TitleColor
    title.TextSize = 14
    title.Font = Enum.Font.Code
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 12
    title.Parent = titleBar

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -27, 0, 2)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.Code
    closeBtn.ZIndex = 12
    closeBtn.Parent = titleBar
    
    self.Connections.CloseButton = closeBtn.MouseButton1Click:Connect(function()
        self:Destroy()
    end)

    -- Preview area
    local preview = Instance.new("Frame")
    preview.Name = "PreviewArea"
    preview.Size = UDim2.new(1, -10, 1, -40)
    preview.Position = UDim2.new(0, 5, 0, 35)
    preview.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    preview.BorderSizePixel = 1
    preview.BorderColor3 = PREVIEW_CONFIG.BorderColor
    preview.ZIndex = 10
    preview.Parent = frame
    self.PreviewArea = preview
    
    print("ESP Preview window created successfully")
end

function ESPPreview:CreateESPComponents()
    local previewSize = Vector2.new(PREVIEW_CONFIG.Size.X - 20, PREVIEW_CONFIG.Size.Y - 50)
    local centerX = previewSize.X / 2
    local centerY = previewSize.Y / 2

    local charWidth = 60
    local charHeight = 120
    local boxPadding = 15

    self:CreateBox(centerX - (charWidth / 2 + boxPadding), centerY - (charHeight / 2 + boxPadding),
                   charWidth + boxPadding * 2, charHeight + boxPadding * 2)

    self:CreateHealthBar(centerX - (charWidth / 2 + boxPadding) - 8, centerY - (charHeight / 2 + boxPadding),
                         4, charHeight + boxPadding * 2)

    self:CreateCharacter(centerX - charWidth / 2, centerY - charHeight / 2, charWidth, charHeight)
    self:CreateTextElements(centerX, centerY - (charHeight / 2 + boxPadding))
end

function ESPPreview:CreateBox(x, y, width, height)
    -- Box outline
    local boxOutline = Instance.new("Frame")
    boxOutline.Name = "BoxOutline"
    boxOutline.Size = UDim2.new(0, width + 4, 0, height + 4)
    boxOutline.Position = UDim2.new(0, x - 2, 0, y - 2)
    boxOutline.BackgroundColor3 = PREVIEW_CONFIG.BoxOutlineColor
    boxOutline.BorderSizePixel = 0
    boxOutline.ZIndex = 11
    boxOutline.Parent = self.PreviewArea

    -- Main box
    local box = Instance.new("Frame")
    box.Name = "Box"
    box.Size = UDim2.new(0, width, 0, height)
    box.Position = UDim2.new(0, x, 0, y)
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 2
    box.BorderColor3 = PREVIEW_CONFIG.BoxColor
    box.ZIndex = 12
    box.Parent = self.PreviewArea

    -- Box fill
    local boxFill = Instance.new("Frame")
    boxFill.Name = "BoxFill"
    boxFill.Size = UDim2.new(1, -4, 1, -4)
    boxFill.Position = UDim2.new(0, 2, 0, 2)
    boxFill.BackgroundColor3 = PREVIEW_CONFIG.BoxColor
    boxFill.BackgroundTransparency = 0.9
    boxFill.BorderSizePixel = 0
    boxFill.ZIndex = 11
    boxFill.Parent = box

    self.Components.Box = {Outline = boxOutline, Main = box, Fill = boxFill}
end

function ESPPreview:CreateHealthBar(x, y, width, height)
    local healthBg = Instance.new("Frame")
    healthBg.Name = "HealthBarBackground"
    healthBg.Size = UDim2.new(0, width, 0, height)
    healthBg.Position = UDim2.new(0, x, 0, y)
    healthBg.BackgroundColor3 = PREVIEW_CONFIG.HealthBarBackgroundColor
    healthBg.BorderSizePixel = 0
    healthBg.ZIndex = 11
    healthBg.Parent = self.PreviewArea

    local healthBar = Instance.new("Frame")
    healthBar.Name = "HealthBar"
    healthBar.Size = UDim2.new(1, -2, self.HealthValue, -2)
    healthBar.Position = UDim2.new(0, 1, 1 - self.HealthValue, 1)
    healthBar.BackgroundColor3 = PREVIEW_CONFIG.HealthBarGoodColor
    healthBar.BorderSizePixel = 0
    healthBar.ZIndex = 12
    healthBar.Parent = healthBg

    local healthText = Instance.new("TextLabel")
    healthText.Name = "HealthText"
    healthText.Size = UDim2.new(0, 40, 0, 20)
    healthText.Position = UDim2.new(0, x + width + 5, 0, y + height / 2 - 10)
    healthText.BackgroundTransparency = 1
    healthText.Text = "100"
    healthText.TextColor3 = PREVIEW_CONFIG.HealthBarGoodColor
    healthText.TextSize = 12
    healthText.Font = Enum.Font.Code
    healthText.TextStrokeTransparency = 0
    healthText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    healthText.ZIndex = 13
    healthText.Parent = self.PreviewArea

    self.Components.HealthBar = {Background = healthBg, Bar = healthBar, Text = healthText}
end

function ESPPreview:CreateCharacter(x, y, width, height)
    local headSize = width * 0.25
    local torsoWidth = width * 0.4
    local torsoHeight = height * 0.35
    local limbWidth = width * 0.2
    local limbHeight = height * 0.3

    self.Components.Character = {}

    -- Create character layers (chams effect)
    for layer = 1, 2 do
        local transparency = layer == 1 and 0.3 or 0.6
        local color = layer == 1 and PREVIEW_CONFIG.ChamColor1 or PREVIEW_CONFIG.ChamColor2
        local offset = layer == 1 and 2 or 0
        local zIndex = layer == 1 and 11 or 12

        local parts = {}
        
        -- Head
        local head = Instance.new("Frame")
        head.Size = UDim2.new(0, headSize + offset, 0, headSize + offset)
        head.Position = UDim2.new(0, x + width / 2 - headSize / 2 - offset / 2, 0, y - offset / 2)
        head.BackgroundColor3 = color
        head.BackgroundTransparency = transparency
        head.BorderSizePixel = 0
        head.ZIndex = zIndex
        head.Parent = self.PreviewArea
        parts.Head = head

        -- Torso
        local torso = Instance.new("Frame")
        torso.Size = UDim2.new(0, torsoWidth + offset, 0, torsoHeight + offset)
        torso.Position = UDim2.new(0, x + width / 2 - torsoWidth / 2 - offset / 2, 0, y + headSize - offset / 2)
        torso.BackgroundColor3 = color
        torso.BackgroundTransparency = transparency
        torso.BorderSizePixel = 0
        torso.ZIndex = zIndex
        torso.Parent = self.PreviewArea
        parts.Torso = torso

        -- Arms and legs
        for _, limb in ipairs({
            {"LeftArm", x - offset / 2, y + headSize - offset / 2},
            {"RightArm", x + width - limbWidth - offset / 2, y + headSize - offset / 2},
            {"LeftLeg", x + width / 2 - limbWidth - offset / 2, y + headSize + torsoHeight - offset / 2},
            {"RightLeg", x + width / 2 + offset / 2, y + headSize + torsoHeight - offset / 2}
        }) do
            local part = Instance.new("Frame")
            part.Size = UDim2.new(0, limbWidth + offset, 0, limbHeight + offset)
            part.Position = UDim2.new(0, limb[2], 0, limb[3])
            part.BackgroundColor3 = color
            part.BackgroundTransparency = transparency
            part.BorderSizePixel = 0
            part.ZIndex = zIndex
            part.Parent = self.PreviewArea
            parts[limb[1]] = part
        end

        self.Components.Character["Layer" .. layer] = parts
    end

    self:CreateSkeleton(x, y, width, height)
end

function ESPPreview:CreateSkeleton(x, y, width, height)
    local headSize = width * 0.25
    local torsoHeight = height * 0.35
    
    for layer = 1, 2 do
        local thickness = layer == 1 and 3 or 1
        local color = layer == 1 and PREVIEW_CONFIG.SkeletonOutlineColor or PREVIEW_CONFIG.SkeletonColor
        local zIndex = layer == 1 and 13 or 14

        local lines = {
            {"HeadTorso", thickness, 5, x + width/2 - thickness/2, y + headSize},
            {"Shoulder", width * 0.6, thickness, x + width/2 - (width * 0.6)/2, y + headSize + 10},
            {"TorsoVertical", thickness, torsoHeight - 20, x + width/2 - thickness/2, y + headSize + 10},
            {"LeftArm", thickness, height * 0.25, x + width * 0.2 - thickness/2, y + headSize + 10},
            {"RightArm", thickness, height * 0.25, x + width * 0.8 - thickness/2, y + headSize + 10},
            {"Hip", width * 0.4, thickness, x + width/2 - (width * 0.4)/2, y + headSize + torsoHeight},
            {"LeftLeg", thickness, height * 0.3, x + width * 0.3 - thickness/2, y + headSize + torsoHeight},
            {"RightLeg", thickness, height * 0.3, x + width * 0.7 - thickness/2, y + headSize + torsoHeight}
        }
        
        for _, lineData in ipairs(lines) do
            local line = Instance.new("Frame")
            line.Size = UDim2.new(0, lineData[2], 0, lineData[3])
            line.Position = UDim2.new(0, lineData[4], 0, lineData[5])
            line.BackgroundColor3 = color
            line.BorderSizePixel = 0
            line.ZIndex = zIndex
            line.Parent = self.PreviewArea
        end
    end
end

function ESPPreview:CreateTextElements(centerX, topY)
    local textElements = {
        {"Username", "PlayerName", UDim2.new(0, centerX - 50, 0, topY - 20), 12, Color3.fromRGB(255, 255, 255)},
        {"Distance", "25m", UDim2.new(0, centerX - 30, 0, topY + 135), 11, Color3.fromRGB(255, 255, 255)},
        {"Tool", "AK-47", UDim2.new(0, centerX - 40, 0, topY + 150), 11, Color3.fromRGB(255, 255, 255)}
    }
    
    self.Components.Text = {}
    
    for _, data in ipairs(textElements) do
        local label = Instance.new("TextLabel")
        label.Name = data[1]
        label.Size = UDim2.new(0, 100, 0, 15)
        label.Position = data[3]
        label.BackgroundTransparency = 1
        label.Text = data[2]
        label.TextColor3 = data[5]
        label.TextSize = data[4]
        label.Font = Enum.Font.Code
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.ZIndex = 13
        label.Parent = self.PreviewArea
        self.Components.Text[data[1]] = label
    end

    -- Flags (special handling)
    local flags = Instance.new("TextLabel")
    flags.Name = "Flags"
    flags.Size = UDim2.new(0, 60, 0, 60)
    flags.Position = UDim2.new(0, centerX + 45, 0, topY + 20)
    flags.BackgroundTransparency = 1
    flags.Text = "VISIBLE\nMOVING\nJUMPING"
    flags.TextColor3 = Color3.fromRGB(255, 255, 255)
    flags.TextSize = 10
    flags.Font = Enum.Font.Code
    flags.TextStrokeTransparency = 0
    flags.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    flags.TextXAlignment = Enum.TextXAlignment.Left
    flags.TextYAlignment = Enum.TextYAlignment.Top
    flags.ZIndex = 13
    flags.Parent = self.PreviewArea
    self.Components.Text.Flags = flags
end

function ESPPreview:StartAnimations()
    self.Connections.HealthAnimation = RunService.Heartbeat:Connect(function()
        self.HealthAnimation = self.HealthAnimation + 0.02
        local smoothValue = (math.cos(self.HealthAnimation) + 1) / 2
        self.HealthValue = smoothValue

        if self.Components.HealthBar then
            local healthBar = self.Components.HealthBar.Bar
            local healthText = self.Components.HealthBar.Text

            healthBar.Size = UDim2.new(1, -2, smoothValue, -2)
            healthBar.Position = UDim2.new(0, 1, 1 - smoothValue, 1)

            local color = PREVIEW_CONFIG.HealthBarGoodColor:Lerp(PREVIEW_CONFIG.HealthBarBadColor, 1 - smoothValue)
            healthBar.BackgroundColor3 = color
            healthText.Text = tostring(math.floor(smoothValue * 100))
            healthText.TextColor3 = color
        end
    end)
end

function ESPPreview:SetVisible(visible)
    self.Visible = visible
    if self.ScreenGui then
        self.ScreenGui.Enabled = visible
    end
end

function ESPPreview:Cleanup()
    for _, connection in pairs(self.Connections or {}) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    self.Connections = {}
    
    if self.ScreenGui then
        self.ScreenGui:Destroy()
    end
end

function ESPPreview:Destroy()
    self:Cleanup()
end

-- Safe initialization for executors
local function Initialize()
    if not LocalPlayer then
        error("LocalPlayer not available")
    end
    
    local preview = ESPPreview.new()
    if not preview then
        error("Failed to create ESP Preview")
    end
    
    return preview
end

-- Execute with proper error handling
local success, result = pcall(Initialize)

if success and result then
    print("ESP Preview loaded successfully!")
    
    -- Global access for external control
    if getgenv then
        getgenv().ESPPreview = ESPPreview
        getgenv().ESPPreviewInstance = result
    else
        _G.ESPPreview = ESPPreview
        _G.ESPPreviewInstance = result
    end
    
    -- Cleanup on player leave
    Players.PlayerRemoving:Connect(function(player)
        if player == LocalPlayer and result then
            result:Destroy()
        end
    end)
    
    return ESPPreview, result
else
    warn("ESP Preview failed to load:", result or "Unknown error")
    return nil
end
