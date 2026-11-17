-- AI ghost for flicker (fixed)

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
local SavedDecals = {} -- [Decal/Texture] = original Transparency

local connections = {}

--===================== GUI =====================
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
    StatusButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
    StatusButton.Parent = ScreenGui

    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = StatusButton
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local dragging, dragStart, startPos
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

--===================== Helpers =====================
local function HideRealBody()
    if not RealCharacter or not RealCharacter.Parent then return end
    for _, v in ipairs(RealCharacter:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart") then
                v.Transparency = 1
                v.CanCollide = false
                v.CanTouch = false
            elseif v:IsA("Decal") or v:IsA("Texture") then
                -- FIX #2: hide face/decals too so nothing floats
                if SavedDecals[v] == nil then SavedDecals[v] = v.Transparency end
                v.Transparency = 1
            elseif v:IsA("BillboardGui") or v:IsA("Highlight") then
                v.Enabled = false
            end
        end)
    end
end

local function ShowRealBody()
    if not RealCharacter or not RealCharacter.Parent then return end
    for _, v in ipairs(RealCharacter:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart") then
                if v.Name == "HumanoidRootPart" then
                    v.Transparency = 1
                    v.CanCollide = false
                else
                    v.Transparency = 0
                    v.CanCollide = true
                end
                v.CanTouch = true
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = SavedDecals[v] or 0
            elseif v:IsA("BillboardGui") or v:IsA("Highlight") then
                v.Enabled = true
            end
        end)
    end
end

-- FIX #3: hold a character at an exact CFrame for a few frames
-- so the humanoid doesn't do the little "pop up and drop" settle.
local function SettleAt(part, hum, cf, frames)
    if not part or not cf then return end
    for _ = 1, (frames or 4) do
        if not part.Parent then return end
        part.CFrame = cf
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
        if hum then hum:ChangeState(Enum.HumanoidStateType.Running) end
        RunService.Heartbeat:Wait()
    end
end

--===================== Toggle =====================
_G.ToggleGhost = function()
    if IsProcessing then return end
    IsProcessing = true
    IsGhost = not IsGhost

    if IsGhost then
        --========== TURN ON ==========
        SavedDecals = {}
        RealCharacter = LocalPlayer.Character
        if not RealCharacter then
            IsGhost = false
            IsProcessing = false
            return
        end

        local realHRP = RealCharacter:FindFirstChild("HumanoidRootPart") or RealCharacter.PrimaryPart
        local startCFrame = realHRP and realHRP.CFrame
        local savedCamCFrame = Camera.CFrame

        RealCharacter.Archivable = true
        GhostCharacter = RealCharacter:Clone()
        GhostCharacter.Name = "LocalGhost"

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

        local gHRP = GhostCharacter:FindFirstChild("HumanoidRootPart")
        local gHum = GhostCharacter:FindFirstChildOfClass("Humanoid")

        -- FIX #3: align ghost EXACTLY to real HRP (no pop)
        if gHRP and startCFrame then
            gHRP.CFrame = startCFrame
            gHRP.AssemblyLinearVelocity = Vector3.zero
            gHRP.AssemblyAngularVelocity = Vector3.zero
        end

        -- Anchor the real body right away so it can't fall
        if realHRP then
            realHRP.Anchored = true
            realHRP.AssemblyLinearVelocity = Vector3.zero
            realHRP.AssemblyAngularVelocity = Vector3.zero
        end

        -- Swap control + camera together
        LocalPlayer.Character = GhostCharacter

        if gHum then
            gHum.Health = math.huge
            gHum:ChangeState(Enum.HumanoidStateType.Running)
            Camera.CameraSubject = gHum
        end
        Camera.CFrame = savedCamCFrame

        -- FIX #2: hide real body immediately (not just in the Stepped loop)
        HideRealBody()

        -- FIX #3: hold ghost in place for a few frames
        task.spawn(function()
            SettleAt(gHRP, gHum, startCFrame, 4)
        end)

        StatusButton.Text = "Ghost: ON"
        StatusButton.BackgroundColor3 = Color3.fromRGB(85, 255, 127)

    else
        --========== TURN OFF ==========
        -- FIX #1: save camera BEFORE anything
        local savedCamCFrame = Camera.CFrame

        local finalPos = nil
        if GhostCharacter then
            finalPos = GhostCharacter:GetPivot() -- = ghost HRP CFrame
        end

        local targetChar = RealCharacter
        if not targetChar or not targetChar.Parent then
            targetChar = LocalPlayer.Character
            RealCharacter = targetChar
        end

        if targetChar and targetChar.Parent then
            local realHRP = targetChar:FindFirstChild("HumanoidRootPart") or targetChar.PrimaryPart
            local realHum = targetChar:FindFirstChildOfClass("Humanoid")

            -- Restore visuals first so there's no visible snap
            ShowRealBody()

            -- Teleport real body to the exact ghost position
            if finalPos then
                targetChar:PivotTo(finalPos)
            end
            if realHRP then
                realHRP.AssemblyLinearVelocity = Vector3.zero
                realHRP.AssemblyAngularVelocity = Vector3.zero
                realHRP.Anchored = false
            end

            -- Swap character back
            LocalPlayer.Character = targetChar

            -- FIX #1: put the camera back on the real humanoid
            -- BEFORE destroying the ghost, so the camera never loses its subject.
            if realHum then
                Camera.CameraSubject = realHum
                realHum.PlatformStand = false
                realHum.Sit = false
                realHum:ChangeState(Enum.HumanoidStateType.Running)
            end
            Camera.CFrame = savedCamCFrame

            -- Now it's safe to delete the clone
            if GhostCharacter then
                GhostCharacter:Destroy()
                GhostCharacter = nil
            end

            -- FIX #3: kill the little drop the humanoid likes to do on re-activate
            task.spawn(function()
                SettleAt(realHRP, realHum, finalPos, 4)
            end)
        else
            -- Character respawned while ghost was on -> just clean up
            if GhostCharacter then
                GhostCharacter:Destroy()
                GhostCharacter = nil
            end
        end

        StatusButton.Text = "Ghost: OFF"
        StatusButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
    end

    task.wait(0.2)
    IsProcessing = false
end

--===================== Init =====================
CreateGUI()

table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.G then
        _G.ToggleGhost()
    end
end))

-- Brute-force bypass loop
table.insert(connections, RunService.Stepped:Connect(function()
    if IsGhost and not IsProcessing and RealCharacter and GhostCharacter then
        if LocalPlayer.Character ~= GhostCharacter then
            LocalPlayer.Character = GhostCharacter
        end

        local ghostHum = GhostCharacter:FindFirstChildOfClass("Humanoid")
        if ghostHum and Camera.CameraSubject ~= ghostHum then
            Camera.CameraSubject = ghostHum
        end

        for _, v in ipairs(GhostCharacter:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") then
                    if v.Name == "HumanoidRootPart" then
                        v.Transparency = 1
                    else
                        v.Transparency = 0.5
                    end
                elseif v:IsA("Decal") or v:IsA("Texture") then
                    v.Transparency = 0.5
                end
            end)
        end

        local hrp = RealCharacter:FindFirstChild("HumanoidRootPart") or RealCharacter.PrimaryPart
        local realHum = RealCharacter:FindFirstChildOfClass("Humanoid")

        if hrp then
            hrp.Anchored = true
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end

        HideRealBody()

        if realHum then
            realHum.Health = realHum.MaxHealth
        end
    end
end))

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function()
    if IsGhost then
        _G.ToggleGhost()
    end
end))

_G.a = connections
