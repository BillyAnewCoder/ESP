-- ESP Preview System - Optimized for loadstring execution
-- Usage: loadstring(game:HttpGet("your-url"))()

local ESPPreview = {}
ESPPreview.__index = ESPPreview

-- Services (cached for performance)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

-- Wait for LocalPlayer if not available
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

-- Configuration
local PREVIEW_CONFIG = {
    Size = Vector2.new(250, 350),
    Position = Vector2.new(50, 50),
    BackgroundColor = Color3.fromRGB(25, 25, 25),
    BorderColor = Color3.fromRGB(60, 60, 60),
    TitleColor = Color3.fromRGB(255, 255, 255),

    -- ESP Components
    BoxColor = Color3.fromRGB(255, 255, 255),
    BoxOutlineColor = Color3.fromRGB(0, 0, 0),
    HealthBarBackgroundColor = Color3.fromRGB(0, 0, 0),
    HealthBarGoodColor = Color3.fromRGB(0, 255, 0),
    HealthBarBadColor = Color3.fromRGB(255, 0, 0),

    -- Character colors
    ChamColor1 = Color3.fromRGB(93, 62, 152),
    ChamColor2 = Color3.fromRGB(255, 255, 255),
    SkeletonOutlineColor = Color3.fromRGB(0, 0, 0),
    SkeletonColor = Color3.fromRGB(255, 255, 255),
}

-- Cleanup existing instances
local function CleanupExisting()
    local existing = CoreGui:FindFirstChild("ESPPreview")
    if existing then
        existing:Destroy()
    end
    
    if LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") then
        existing = LocalPlayer.PlayerGui:FindFirstChild("ESPPreview")
        if existing then
            existing:Destroy()
        end
    end
end

function ESPPreview.new(parent)
    -- Clean up any existing instances first
    CleanupExisting()
    
    local instance = setmetatable({}, ESPPreview)
    
    -- Determine parent with loadstring-friendly approach
    local targetParent = parent
    if not targetParent then
        -- Try PlayerGui first, fallback to CoreGui
        if LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") then
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
    
    -- Protected creation with detailed error handling
    local success, errorMsg = pcall(function()
        instance:CreatePreviewWindow()
        instance:CreateESPComponents()
        instance:StartAnimations()
    end)
    
    if not success then
        warn("ESPPreview creation failed:", errorMsg)
        instance:Cleanup()
        return nil
    end
    
    return instance
end

function ESPPreview:CreatePreviewWindow()
    local frame = Instance.new("Frame")
    frame.Name = "ESPPreview"
    frame.Size = UDim2.new(0, PREVIEW_CONFIG.Size.X, 0, PREVIEW_CONFIG.Size.Y)
    frame.Position = UDim2.new(0, PREVIEW_CONFIG.Position.X, 0, PREVIEW_CONFIG.Position.Y)
    frame.BackgroundColor3 = PREVIEW_CONFIG.BackgroundColor
    frame.BorderSizePixel = 1
    frame.BorderColor3 = PREVIEW_CONFIG.BorderColor
    frame.Active = true
    frame.Draggable = true
    frame.ZIndex = 10
    frame.Parent = self.Parent
    self.MainFrame = frame

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -40, 0, 25)
    title.Position = UDim2.new(0, 5, 0, 2)
    title.BackgroundTransparency = 1
    title.Text = "ESP Preview"
    title.TextColor3 = PREVIEW_CONFIG.TitleColor
    title.TextSize = 14
    title.Font = Enum.Font.Code
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 11
    title.Parent = frame

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -25, 0, 2)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.Code
    closeBtn.ZIndex = 11
    closeBtn.Parent = frame
    
    self.Connections.CloseButton = closeBtn.MouseButton1Click:Connect(function()
        self:SetVisible(false)
    end)

    -- Preview area
    local preview = Instance.new("Frame")
    preview.Name = "PreviewArea"
    preview.Size = UDim2.new(1, -20, 1, -40)
    preview.Position = UDim2.new(0, 10, 0, 30)
    preview.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    preview.BorderSizePixel = 1
    preview.BorderColor3 = PREVIEW_CONFIG.BorderColor
    preview.ZIndex = 10
    preview.Parent = frame
    self.PreviewArea = preview
end

function ESPPreview:CreateESPComponents()
    local previewSize = self.PreviewArea.AbsoluteSize
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
    local boxOutline = Instance.new("Frame")
    boxOutline.Name = "BoxOutline"
    boxOutline.Size = UDim2.new(0, width + 4, 0, height + 4)
    boxOutline.Position = UDim2.new(0, x - 2, 0, y - 2)
    boxOutline.BackgroundColor3 = PREVIEW_CONFIG.BoxOutlineColor
    boxOutline.BorderSizePixel = 0
    boxOutline.ZIndex = 11
    boxOutline.Parent = self.PreviewArea

    local box = Instance.new("Frame")
    box.Name = "Box"
    box.Size = UDim2.new(0, width, 0, height)
    box.Position = UDim2.new(0, x, 0, y)
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 2
    box.BorderColor3 = PREVIEW_CONFIG.BoxColor
    box.ZIndex = 12
    box.Parent = self.PreviewArea

    local boxFill = Instance.new("Frame")
    boxFill.Name = "BoxFill"
    boxFill.Size = UDim2.new(1, -4, 1, -4)
    boxFill.Position = UDim2.new(0, 2, 0, 2)
    boxFill.BackgroundColor3 = PREVIEW_CONFIG.BoxColor
    boxFill.BackgroundTransparency = 0.9
    boxFill.BorderSizePixel = 0
    boxFill.ZIndex = 11
    boxFill.Parent = box

    self.Components.Box = {
        Outline = boxOutline,
        Main = box,
        Fill = boxFill
    }
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

    self.Components.HealthBar = {
        Background = healthBg,
        Bar = healthBar,
        Text = healthText
    }
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

        -- Head
        local head = Instance.new("Frame")
        head.Size = UDim2.new(0, headSize + offset, 0, headSize + offset)
        head.Position = UDim2.new(0, x + width / 2 - headSize / 2 - offset / 2, 0, y - offset / 2)
        head.BackgroundColor3 = color
        head.BackgroundTransparency = transparency
        head.BorderSizePixel = 0
        head.ZIndex = zIndex
        head.Parent = self.PreviewArea

        -- Torso
        local torso = Instance.new("Frame")
        torso.Size = UDim2.new(0, torsoWidth + offset, 0, torsoHeight + offset)
        torso.Position = UDim2.new(0, x + width / 2 - torsoWidth / 2 - offset / 2, 0, y + headSize - offset / 2)
        torso.BackgroundColor3 = color
        torso.BackgroundTransparency = transparency
        torso.BorderSizePixel = 0
        torso.ZIndex = zIndex
        torso.Parent = self.PreviewArea

        -- Left Arm
        local leftArm = Instance.new("Frame")
        leftArm.Size = UDim2.new(0, limbWidth + offset, 0, limbHeight + offset)
        leftArm.Position = UDim2.new(0, x - offset / 2, 0, y + headSize - offset / 2)
        leftArm.BackgroundColor3 = color
        leftArm.BackgroundTransparency = transparency
        leftArm.BorderSizePixel = 0
        leftArm.ZIndex = zIndex
        leftArm.Parent = self.PreviewArea

        -- Right Arm
        local rightArm = Instance.new("Frame")
        rightArm.Size = UDim2.new(0, limbWidth + offset, 0, limbHeight + offset)
        rightArm.Position = UDim2.new(0, x + width - limbWidth - offset / 2, 0, y + headSize - offset / 2)
        rightArm.BackgroundColor3 = color
        rightArm.BackgroundTransparency = transparency
        rightArm.BorderSizePixel = 0
        rightArm.ZIndex = zIndex
        rightArm.Parent = self.PreviewArea

        -- Left Leg
        local leftLeg = Instance.new("Frame")
        leftLeg.Size = UDim2.new(0, limbWidth + offset, 0, limbHeight + offset)
        leftLeg.Position = UDim2.new(0, x + width / 2 - limbWidth - offset / 2, 0, y + headSize + torsoHeight - offset / 2)
        leftLeg.BackgroundColor3 = color
        leftLeg.BackgroundTransparency = transparency
        leftLeg.BorderSizePixel = 0
        leftLeg.ZIndex = zIndex
        leftLeg.Parent = self.PreviewArea

        -- Right Leg
        local rightLeg = Instance.new("Frame")
        rightLeg.Size = UDim2.new(0, limbWidth + offset, 0, limbHeight + offset)
        rightLeg.Position = UDim2.new(0, x + width / 2 + offset / 2, 0, y + headSize + torsoHeight - offset / 2)
        rightLeg.BackgroundColor3 = color
        rightLeg.BackgroundTransparency = transparency
        rightLeg.BorderSizePixel = 0
        rightLeg.ZIndex = zIndex
        rightLeg.Parent = self.PreviewArea

        self.Components.Character["Layer" .. layer] = {
            Head = head,
            Torso = torso,
            LeftArm = leftArm,
            RightArm = rightArm,
            LeftLeg = leftLeg,
            RightLeg = rightLeg
        }
    end

    self:CreateSkeleton(x, y, width, height)
end

function ESPPreview:CreateSkeleton(x, y, width, height)
    local headSize = width * 0.25
    local torsoHeight = height * 0.35

    -- Create skeleton lines with outline
    for layer = 1, 2 do
        local thickness = layer == 1 and 3 or 1
        local color = layer == 1 and PREVIEW_CONFIG.SkeletonOutlineColor or PREVIEW_CONFIG.SkeletonColor
        local zIndex = layer == 1 and 13 or 14

        -- Head to torso connection
        local headTorso = Instance.new("Frame")
        headTorso.Size = UDim2.new(0, thickness, 0, 5)
        headTorso.Position = UDim2.new(0, x + width/2 - thickness/2, 0, y + headSize)
        headTorso.BackgroundColor3 = color
        headTorso.BorderSizePixel = 0
        headTorso.ZIndex = zIndex
        headTorso.Parent = self.PreviewArea

        -- Shoulder line
        local torsoLine = Instance.new("Frame")
        torsoLine.Size = UDim2.new(0, width * 0.6, 0, thickness)
        torsoLine.Position = UDim2.new(0, x + width/2 - (width * 0.6)/2, 0, y + headSize + 10)
        torsoLine.BackgroundColor3 = color
        torsoLine.BorderSizePixel = 0
        torsoLine.ZIndex = zIndex
        torsoLine.Parent = self.PreviewArea

        -- Torso vertical line
        local torsoVertical = Instance.new("Frame")
        torsoVertical.Size = UDim2.new(0, thickness, 0, torsoHeight - 20)
        torsoVertical.Position = UDim2.new(0, x + width/2 - thickness/2, 0, y + headSize + 10)
        torsoVertical.BackgroundColor3 = color
        torsoVertical.BorderSizePixel = 0
        torsoVertical.ZIndex = zIndex
        torsoVertical.Parent = self.PreviewArea

        -- Left arm line
        local leftArmLine = Instance.new("Frame")
        leftArmLine.Size = UDim2.new(0, thickness, 0, height * 0.25)
        leftArmLine.Position = UDim2.new(0, x + width * 0.2 - thickness/2, 0, y + headSize + 10)
        leftArmLine.BackgroundColor3 = color
        leftArmLine.BorderSizePixel = 0
        leftArmLine.ZIndex = zIndex
        leftArmLine.Parent = self.PreviewArea

        -- Right arm line
        local rightArmLine = Instance.new("Frame")
        rightArmLine.Size = UDim2.new(0, thickness, 0, height * 0.25)
        rightArmLine.Position = UDim2.new(0, x + width * 0.8 - thickness/2, 0, y + headSize + 10)
        rightArmLine.BackgroundColor3 = color
        rightArmLine.BorderSizePixel = 0
        rightArmLine.ZIndex = zIndex
        rightArmLine.Parent = self.PreviewArea

        -- Hip line
        local hipLine = Instance.new("Frame")
        hipLine.Size = UDim2.new(0, width * 0.4, 0, thickness)
        hipLine.Position = UDim2.new(0, x + width/2 - (width * 0.4)/2, 0, y + headSize + torsoHeight)
        hipLine.BackgroundColor3 = color
        hipLine.BorderSizePixel = 0
        hipLine.ZIndex = zIndex
        hipLine.Parent = self.PreviewArea

        -- Left leg line
        local leftLegLine = Instance.new("Frame")
        leftLegLine.Size = UDim2.new(0, thickness, 0, height * 0.3)
        leftLegLine.Position = UDim2.new(0, x + width * 0.3 - thickness/2, 0, y + headSize + torsoHeight)
        leftLegLine.BackgroundColor3 = color
        leftLegLine.BorderSizePixel = 0
        leftLegLine.ZIndex = zIndex
        leftLegLine.Parent = self.PreviewArea

        -- Right leg line
        local rightLegLine = Instance.new("Frame")
        rightLegLine.Size = UDim2.new(0, thickness, 0, height * 0.3)
        rightLegLine.Position = UDim2.new(0, x + width * 0.7 - thickness/2, 0, y + headSize + torsoHeight)
        rightLegLine.BackgroundColor3 = color
        rightLegLine.BorderSizePixel = 0
        rightLegLine.ZIndex = zIndex
        rightLegLine.Parent = self.PreviewArea
    end
end

function ESPPreview:CreateTextElements(centerX, topY)
    -- Username
    local username = Instance.new("TextLabel")
    username.Name = "Username"
    username.Size = UDim2.new(0, 100, 0, 15)
    username.Position = UDim2.new(0, centerX - 50, 0, topY - 20)
    username.BackgroundTransparency = 1
    username.Text = "PlayerName"
    username.TextColor3 = Color3.fromRGB(255, 255, 255)
    username.TextSize = 12
    username.Font = Enum.Font.Code
    username.TextStrokeTransparency = 0
    username.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    username.ZIndex = 13
    username.Parent = self.PreviewArea

    -- Distance
    local distance = Instance.new("TextLabel")
    distance.Name = "Distance"
    distance.Size = UDim2.new(0, 60, 0, 15)
    distance.Position = UDim2.new(0, centerX - 30, 0, topY + 135)
    distance.BackgroundTransparency = 1
    distance.Text = "25m"
    distance.TextColor3 = Color3.fromRGB(255, 255, 255)
    distance.TextSize = 11
    distance.Font = Enum.Font.Code
    distance.TextStrokeTransparency = 0
    distance.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distance.ZIndex = 13
    distance.Parent = self.PreviewArea

    -- Tool/Weapon
    local tool = Instance.new("TextLabel")
    tool.Name = "Tool"
    tool.Size = UDim2.new(0, 80, 0, 15)
    tool.Position = UDim2.new(0, centerX - 40, 0, topY + 150)
    tool.BackgroundTransparency = 1
    tool.Text = "AK-47"
    tool.TextColor3 = Color3.fromRGB(255, 255, 255)
    tool.TextSize = 11
    tool.Font = Enum.Font.Code
    tool.TextStrokeTransparency = 0
    tool.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    tool.ZIndex = 13
    tool.Parent = self.PreviewArea

    -- Flags
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

    self.Components.Text = {
        Username = username,
        Distance = distance,
        Tool = tool,
        Flags = flags
    }
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
    if self.MainFrame and self.MainFrame.Parent then
        self.MainFrame.Visible = visible
    end
end

function ESPPreview:UpdateComponentVisibility(component, visible)
    if not self.Components[component] then return end

    local comp = self.Components[component]
    if comp.Main then
        comp.Main.Visible = visible
        if comp.Outline then
            comp.Outline.Visible = visible
        end
        if comp.Fill then
            comp.Fill.Visible = visible
        end
    elseif comp.Background then
        comp.Background.Visible = visible
        if comp.Bar then
            comp.Bar.Visible = visible
        end
        if comp.Text then
            comp.Text.Visible = visible
        end
    end
end

function ESPPreview:UpdateComponentColor(component, color)
    if not self.Components[component] then return end

    local comp = self.Components[component]
    if component == "Box" and comp.Main then
        comp.Main.BorderColor3 = color
        if comp.Fill then
            comp.Fill.BackgroundColor3 = color
        end
    end
end

function ESPPreview:Cleanup()
    -- Disconnect all connections
    for name, connection in pairs(self.Connections or {}) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    self.Connections = {}
    
    -- Destroy GUI
    if self.MainFrame and self.MainFrame.Parent then
        self.MainFrame:Destroy()
    end
end

function ESPPreview:Destroy()
    self:Cleanup()
end

-- Safe initialization for loadstring
local function Initialize()
    -- Ensure we have required services
    if not RunService or not Players then
        error("Required services not available")
    end
    
    -- Wait for LocalPlayer if needed
    if not LocalPlayer then
        warn("LocalPlayer not available, waiting...")
        return nil
    end
    
    -- Create the preview instance
    local preview = ESPPreview.new()
    if not preview then
        error("Failed to create ESP Preview instance")
    end
    
    return preview
end

-- Execute and handle errors
local success, result = pcall(Initialize)

if success and result then
    print("ESP Preview loaded successfully!")
    
    -- Global access for external control
    getgenv().ESPPreview = ESPPreview
    getgenv().ESPPreviewInstance = result
    
    -- Optional: Auto-cleanup on game shutdown
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        if player == LocalPlayer and result then
            result:Destroy()
        end
    end)
    
    return ESPPreview, result
else
    warn("ESP Preview failed to load:", result or "Unknown error")
    return nil
end
