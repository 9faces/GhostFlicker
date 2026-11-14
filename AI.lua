-- AI ghost for flicker

-- TRUE SERVER-SIDE GHOST SCRIPT (v13 - Fixed HRP Visibility on Toggle Off)
if _G.a then
    for _, conn in pairs(_G.a) do
        pcall(function() conn:Disconnect() end)
    end
    _G.a = nil
end

repeat task.wait() until game.Players.LocalPlayer

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local IsGhost = false
local IsProcessing = false 
local RealCharacter = nil
local GhostCharacter = nil
local StatusButton = nil

local connections = {}

-- Function to create the GUI
local function CreateGUI()
    if LocalPlayer.PlayerGui:FindFirstChild("GhostGUI") then
        LocalPlayer.PlayerGui.GhostGUI:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GhostGUI"
    ScreenGui.ResetOnSpawn = false 
    
    StatusButton = Instance.new("TextButton")
    local UICorner = Instance.new("UICorner")
    
    StatusButton.Size = UDim2.new(0, 140, 0, 50)
    StatusButton.Position = UDim2.new(0.5, -70, 0.15, 0)
    StatusButton.Text = "Ghost: OFF"
    StatusButton.Font = Enum.Font.GothamBold
    StatusButton.TextSize = 16
    StatusButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StatusButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85) -- Red
    StatusButton.Parent = ScreenGui

    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = StatusButton
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Drag Logic
    local dragging, dragInput, dragStart, startPos
    StatusButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = StatusButton.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            StatusButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    StatusButton.MouseButton1Click:Connect(function()
        if _G.ToggleGhost then _G.ToggleGhost() end
    end)
end

-- Main Toggle Function
_G.ToggleGhost = function()
    if IsProcessing then return end
    IsProcessing = true
    IsGhost = not IsGhost

    if IsGhost then
        -- TURN ON
        RealCharacter = LocalPlayer.Character
        if not RealCharacter then 
            IsProcessing = false
            return 
        end

        RealCharacter.Archivable = true
        GhostCharacter = RealCharacter:Clone()
        GhostCharacter.Name = "LocalGhost"
        
        -- Make clone transparent (0.5), but keep HRP invisible (1)
        for _, v in ipairs(GhostCharacter:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") then
                    if v.Name == "HumanoidRootPart" then
                        v.Transparency = 1 
                    else
                        v.Transparency = 0.5 
                    end
                    v.CanCollide = false
                    v.CanTouch = false
                elseif v:IsA("Decal") or v:IsA("Texture") then
                    v.Transparency = 0.5
                end
            end)
        end
        
        GhostCharacter.Parent = workspace

        -- Swap control & CAMERA
        LocalPlayer.Character = GhostCharacter
        local hum = GhostCharacter:FindFirstChildOfClass("Humanoid")
        if hum then 
            hum.Health = math.huge 
            Camera.CameraSubject = hum 
        end

        StatusButton.Text = "Ghost: ON"
        StatusButton.BackgroundColor3 = Color3.fromRGB(85, 255, 127)

    else
        -- TURN OFF (EXACT SPAWN, FIXED HRP)
        local finalPos = CFrame.new()
        if GhostCharacter then
            finalPos = GhostCharacter:GetPivot() 
        end

        if RealCharacter and RealCharacter.Parent then
            local realHrp = RealCharacter:FindFirstChild("HumanoidRootPart") or RealCharacter.PrimaryPart
            local realHum = RealCharacter:FindFirstChildOfClass("Humanoid")
            
            -- 1. Unanchor your real body
            if realHrp then
                realHrp.Anchored = false
            end
            
            -- 2. Restore your real body's visibility and nametag (KEEPING HRP INVISIBLE)
            for _, v in ipairs(RealCharacter:GetDescendants()) do
                pcall(function()
                    if v:IsA("BasePart") then
                        if v.Name == "HumanoidRootPart" then
                            v.Transparency = 1 -- FIX: Keep HRP invisible
                            v.CanCollide = false
                        else
                            v.Transparency = 0 -- Make normal body parts visible
                            v.CanCollide = true
                        end
                        v.CanTouch = true
                    elseif v:IsA("BillboardGui") or v:IsA("Highlight") then
                        v.Enabled = true 
                    end
                end)
            end

            -- 3. Teleport real body to the EXACT ghost position
            RealCharacter:PivotTo(finalPos)
            
            -- 4. Clean up clone
            if GhostCharacter then
                GhostCharacter:Destroy()
                GhostCharacter = nil
            end

            -- 5. Swap back to Real Character
            LocalPlayer.Character = RealCharacter
            
            -- 6. Reset physics perfectly so you don't fall or ragdoll
            if realHum then
                realHum.PlatformStand = false
                realHum.Sit = false
                realHum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            
            if realHrp then
                realHrp.AssemblyLinearVelocity = Vector3.zero
                realHrp.AssemblyAngularVelocity = Vector3.zero
            end
            
            -- 7. Wait a split second, then lock the camera
            task.wait(0.15) 
            if realHum then
                Camera.CameraSubject = realHum
            end
        end

        StatusButton.Text = "Ghost: OFF"
        StatusButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
    end
    
    task.wait(0.2)
    IsProcessing = false
end

-- Initialize
CreateGUI()

-- Keybind Listener
table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.G then
        _G.ToggleGhost()
    end
end))

-- The Brute Force Bypass Loop
table.insert(connections, RunService.Stepped:Connect(function()
    if IsGhost and not IsProcessing and RealCharacter and GhostCharacter then
        
        if LocalPlayer.Character ~= GhostCharacter then
            LocalPlayer.Character = GhostCharacter
        end

        -- Force Camera to follow clone
        local ghostHum = GhostCharacter:FindFirstChildOfClass("Humanoid")
        if ghostHum and Camera.CameraSubject ~= ghostHum then
            Camera.CameraSubject = ghostHum
        end

        -- Force clone to stay TRANSPARENT (0.5) & HRP invisible (1)
        for _, v in ipairs(GhostCharacter:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") then
                    if v.Name == "HumanoidRootPart" then
                        v.Transparency = 1
                    else
                        v.Transparency = 0.5
                    end
                end
            end)
        end

        -- Hide Real Character & Hide its BillboardGui
        local hrp = RealCharacter:FindFirstChild("HumanoidRootPart") or RealCharacter.PrimaryPart
        local realHum = RealCharacter:FindFirstChildOfClass("Humanoid")
        
        if hrp then
            hrp.Anchored = true 
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        
        for _, v in ipairs(RealCharacter:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") then
                    v.Transparency = 1
                    v.CanCollide = false
                    v.CanTouch = false
                elseif v:IsA("BillboardGui") or v:IsA("Highlight") then
                    v.Enabled = false 
                end
            end)
        end

        if realHum then
            realHum.Health = realHum.MaxHealth
        end
    end
end))

-- Handle Respawn
table.insert(connections, LocalPlayer.CharacterAdded:Connect(function()
    if IsGhost then
        _G.ToggleGhost()
    end
end))

_G.a = connections
