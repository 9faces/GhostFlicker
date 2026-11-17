-- Do not the cat

-- Flicker best script

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

local SavedPartProps = {}
local SavedDecals    = {}

local connections = {}

--===================== Config persistence =====================
local CONFIG_FILE = "GhostGUI_Position.txt"

local function SaveGUIPosition()
    if not writefile then return end
    local pos = StatusButton.Position
    local data = string.format("%f,%d,%f,%d", pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset)
    pcall(function() writefile(CONFIG_FILE, data) end)
end

local function LoadGUIPosition()
    if not (readfile and isfile) then return nil end
    local ok, exists = pcall(isfile, CONFIG_FILE)
    if not ok or not exists then return nil end
    local ok2, data = pcall(readfile, CONFIG_FILE)
    if not ok2 or not data then return nil end
    local xs, xo, ys, yo = data:match("([%d%.%-]+),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")
    if xs and xo and ys and yo then
        return UDim2.new(tonumber(xs), tonumber(xo), tonumber(ys), tonumber(yo))
    end
    return nil
end

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
    StatusButton.Position = LoadGUIPosition() or UDim2.new(0.5, -70, 0.15, 0)
    StatusButton.Text = "Ghost: OFF"
    StatusButton.Font = Enum.Font.GothamBold
    StatusButton.TextSize = 16
    StatusButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StatusButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
    StatusButton.Parent = ScreenGui

    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = StatusButton
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local dragging = false
    local dragStart
    local startPos
    local dragStartPos
    local didDrag = false

    StatusButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            didDrag = false
            dragStart = input.Position
            dragStartPos = input.Position
            startPos = StatusButton.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if (input.Position - dragStartPos).Magnitude > 5 then
                didDrag = true
            end
            local delta = input.Position - dragStart
            StatusButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if didDrag then
                SaveGUIPosition()
            end
        end
    end)

    StatusButton.MouseButton1Click:Connect(function()
        if didDrag then return end
        if _G.ToggleGhost then _G.ToggleGhost() end
    end)
end

--===================== State save/restore =====================
local function SaveOriginalState()
    SavedPartProps = {}
    SavedDecals = {}
    if not RealCharacter then return end
    for _, v in ipairs(RealCharacter:GetDescendants()) do
        if v:IsA("BasePart") then
            SavedPartProps[v] = {
                Transparency = v.Transparency,
                CanCollide   = v.CanCollide,
                CanTouch     = v.CanTouch,
            }
        elseif v:IsA("Decal") or v:IsA("Texture") then
            SavedDecals[v] = v.Transparency
        end
    end
end

local function HideRealBody()
    if not RealCharacter or not RealCharacter.Parent then return end
    for _, v in ipairs(RealCharacter:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart") then
                v.Transparency = 1
                v.CanCollide = false
                v.CanTouch = false
            elseif v:IsA("Decal") or v:IsA("Texture") then
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
                local orig = SavedPartProps[v]
                if v.Name == "HumanoidRootPart" then
                    v.Transparency = 1
                    v.CanCollide = orig and orig.CanCollide or false
                    v.CanTouch   = orig and orig.CanTouch   or false
                elseif orig then
                    v.Transparency = orig.Transparency
                    v.CanCollide   = orig.CanCollide
                    v.CanTouch     = orig.CanTouch
                else
                    v.Transparency = 0
                    v.CanCollide   = true
                    v.CanTouch     = true
                end
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = SavedDecals[v] or 0
            elseif v:IsA("BillboardGui") or v:IsA("Highlight") then
                v.Enabled = true
            end
        end)
    end
end

-- FIX: pins HRP at a CFrame while keeping it anchored during the settle,
-- then RESTORES whatever Anchored state it had before.
-- No ChangeState calls -> idle animation is never interrupted.
local function PinAt(hrp, cf, frames)
    if not hrp or not cf then return end
    local wasAnchored = hrp.Anchored
    hrp.Anchored = true
    for _ = 1, (frames or 4) do
        if not hrp.Parent then break end
        hrp.CFrame = cf
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end
    if hrp.Parent then
        hrp.Anchored = wasAnchored
    end
end

--===================== Toggle =====================
_G.ToggleGhost = function()
    if IsProcessing then return end
    IsProcessing = true
    IsGhost = not IsGhost

    if IsGhost then
        --========== TURN ON ==========
        RealCharacter = LocalPlayer.Character
        if not RealCharacter then
            IsGhost = false
            IsProcessing = false
            return
        end

        SaveOriginalState()

        local realHRP = RealCharacter:FindFirstChild("HumanoidRootPart") or RealCharacter.PrimaryPart
        local startCFrame = realHRP and realHRP.CFrame

        local savedCamCFrame = Camera.CFrame
        local savedCamFocus  = Camera.Focus
        local prevCameraType = Camera.CameraType
        Camera.CameraType = Enum.CameraType.Scriptable

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

        local gHRP = GhostCharacter:FindFirstChild("HumanoidRootPart")
        local gHum = GhostCharacter:FindFirstChildOfClass("Humanoid")

        if gHRP and startCFrame then
            gHRP.CFrame = startCFrame
            gHRP.AssemblyLinearVelocity  = Vector3.zero
            gHRP.AssemblyAngularVelocity = Vector3.zero
        end

        GhostCharacter.Parent = workspace

        if realHRP then
            realHRP.Anchored = true
            realHRP.AssemblyLinearVelocity  = Vector3.zero
            realHRP.AssemblyAngularVelocity = Vector3.zero
        end

        LocalPlayer.Character = GhostCharacter

        if gHum then
            gHum.Health = math.huge
            -- FIX: removed gHum:ChangeState(Running) — let it stay in whatever
            -- state it was cloned with so no animation flash on ON either.
            Camera.CameraSubject = gHum
        end

        Camera.CFrame = savedCamCFrame
        Camera.Focus  = savedCamFocus

        HideRealBody()

        task.spawn(function()
            PinAt(gHRP, startCFrame, 4)
            Camera.CFrame = savedCamCFrame
            Camera.Focus  = savedCamFocus
            RunService.RenderStepped:Wait()
            Camera.CFrame = savedCamCFrame
            Camera.Focus  = savedCamFocus
            RunService.RenderStepped:Wait()
            Camera.CFrame = savedCamCFrame
            Camera.Focus  = savedCamFocus
            Camera.CameraType = prevCameraType
        end)

        StatusButton.Text = "Ghost: ON"
        StatusButton.BackgroundColor3 = Color3.fromRGB(85, 255, 127)

    else
        --========== TURN OFF ==========
        local savedCamCFrame = Camera.CFrame
        local savedCamFocus  = Camera.Focus
        local prevCameraType = Camera.CameraType
        Camera.CameraType = Enum.CameraType.Scriptable

        local finalPos = nil
        if GhostCharacter then
            finalPos = GhostCharacter:GetPivot()
        end

        local targetChar = RealCharacter
        if not targetChar or not targetChar.Parent then
            targetChar = LocalPlayer.Character
            RealCharacter = targetChar
        end

        if targetChar and targetChar.Parent then
            local realHRP = targetChar:FindFirstChild("HumanoidRootPart") or targetChar.PrimaryPart
            local realHum = targetChar:FindFirstChildOfClass("Humanoid")

            ShowRealBody()

            -- FIX: keep real HRP anchored through teleport + settle.
            -- Anchored humanoids do NOT transition to Freefall/Land, so the
            -- idle animation is never interrupted.
            if realHRP then
                realHRP.Anchored = true
                realHRP.AssemblyLinearVelocity  = Vector3.zero
                realHRP.AssemblyAngularVelocity = Vector3.zero
            end

            if finalPos then
                targetChar:PivotTo(finalPos)
            end

            LocalPlayer.Character = targetChar

            if realHum then
                Camera.CameraSubject = realHum
                -- FIX: only reset if actually set — avoids spurious state resets
                if realHum.PlatformStand then realHum.PlatformStand = false end
                if realHum.Sit then realHum.Sit = false end
                -- FIX: removed realHum:ChangeState(Running) — this was the
                -- main cause of the idle reset tell.
            end

            Camera.CFrame = savedCamCFrame
            Camera.Focus  = savedCamFocus

            if GhostCharacter then
                GhostCharacter:Destroy()
                GhostCharacter = nil
            end

            task.spawn(function()
                -- real HRP is already anchored; PinAt keeps it anchored
                -- through the settle, then we unanchor AFTER.
                PinAt(realHRP, finalPos, 4)
                if realHRP and realHRP.Parent then
                    realHRP.Anchored = false
                end
                Camera.CFrame = savedCamCFrame
                Camera.Focus  = savedCamFocus
                RunService.RenderStepped:Wait()
                Camera.CFrame = savedCamCFrame
                Camera.Focus  = savedCamFocus
                RunService.RenderStepped:Wait()
                Camera.CFrame = savedCamCFrame
                Camera.Focus  = savedCamFocus
                Camera.CameraType = prevCameraType
            end)
        else
            if GhostCharacter then
                GhostCharacter:Destroy()
                GhostCharacter = nil
            end
            Camera.CameraType = prevCameraType
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
            hrp.AssemblyLinearVelocity  = Vector3.zero
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
