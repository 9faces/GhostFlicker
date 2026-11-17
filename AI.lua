-- Placeholder Update #3
-- DO NOT CAT

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
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Ghost = false
local Busy = false
local Character = nil
local GhostChar = nil
local ToggleButton = nil

local PartProps = {}
local DecalProps = {}
local Connections = {}

local ConfigFile = "GhostGUI_Position.txt"

local function SavePosition()
    if not writefile or not ToggleButton then return end
    local Pos = ToggleButton.Position
    local Data = string.format("%f,%d,%f,%d", Pos.X.Scale, Pos.X.Offset, Pos.Y.Scale, Pos.Y.Offset)
    pcall(function() writefile(ConfigFile, Data) end)
end

local function LoadPosition()
    if not (readfile and isfile) then return nil end
    local Ok, Exists = pcall(isfile, ConfigFile)
    if not Ok or not Exists then return nil end

    local Ok2, Data = pcall(readfile, ConfigFile)
    if not Ok2 or not Data then return nil end

    local Xs, Xo, Ys, Yo = Data:match("([%d%.%-]+),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")

    if Xs and Xo and Ys and Yo then
        return UDim2.new(tonumber(Xs), tonumber(Xo), tonumber(Ys), tonumber(Yo))
    end

    return nil
end

local function CreateGUI()
    if Player.PlayerGui:FindFirstChild("GhostGUI") then
        Player.PlayerGui.GhostGUI:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GhostGUI"
    ScreenGui.ResetOnSpawn = false

    ToggleButton = Instance.new("TextButton")
    local Corner = Instance.new("UICorner")

    ToggleButton.Size = UDim2.new(0, 140, 0, 50)
    ToggleButton.Position = LoadPosition() or UDim2.new(0.5, -70, 0.15, 0)
    ToggleButton.Text = "Ghost: OFF"
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.TextSize = 16
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
    ToggleButton.Parent = ScreenGui

    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = ToggleButton

    ScreenGui.Parent = Player:WaitForChild("PlayerGui")

    local Dragging = false
    local DragStart
    local StartPos
    local DragPos
    local Moved = false

    ToggleButton.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true
            Moved = false
            DragStart = Input.Position
            DragPos = Input.Position
            StartPos = ToggleButton.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(Input)
        if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
            if (Input.Position - DragPos).Magnitude > 5 then
                Moved = true
            end

            local Delta = Input.Position - DragStart
            ToggleButton.Position = UDim2.new(
                StartPos.X.Scale,
                StartPos.X.Offset + Delta.X,
                StartPos.Y.Scale,
                StartPos.Y.Offset + Delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging = false
            if Moved then
                SavePosition()
            end
        end
    end)

    ToggleButton.MouseButton1Click:Connect(function()
        if Moved then return end
        if _G.ToggleGhost then
            _G.ToggleGhost()
        end
    end)
end

local function SaveState()
    PartProps = {}
    DecalProps = {}

    if not Character then return end

    for _, Obj in ipairs(Character:GetDescendants()) do
        if Obj:IsA("BasePart") then
            PartProps[Obj] = {
                Transparency = Obj.Transparency,
                CanCollide = Obj.CanCollide,
                CanTouch = Obj.CanTouch
            }
        elseif Obj:IsA("Decal") or Obj:IsA("Texture") then
            DecalProps[Obj] = Obj.Transparency
        end
    end
end

local function HideCharacter()
    if not Character or not Character.Parent then return end

    for _, Obj in ipairs(Character:GetDescendants()) do
        pcall(function()
            if Obj:IsA("BasePart") then
                Obj.Transparency = 1
                Obj.CanCollide = false
                Obj.CanTouch = false
            elseif Obj:IsA("Decal") or Obj:IsA("Texture") then
                Obj.Transparency = 1
            elseif Obj:IsA("BillboardGui") or Obj:IsA("Highlight") then
                Obj.Enabled = false
            end
        end)
    end
end

local function ShowCharacter()
    if not Character or not Character.Parent then return end

    for _, Obj in ipairs(Character:GetDescendants()) do
        pcall(function()
            if Obj:IsA("BasePart") then
                local Original = PartProps[Obj]

                if Obj.Name == "HumanoidRootPart" then
                    Obj.Transparency = 1
                    Obj.CanCollide = Original and Original.CanCollide or false
                    Obj.CanTouch = Original and Original.CanTouch or false
                elseif Original then
                    Obj.Transparency = Original.Transparency
                    Obj.CanCollide = Original.CanCollide
                    Obj.CanTouch = Original.CanTouch
                else
                    Obj.Transparency = 0
                    Obj.CanCollide = true
                    Obj.CanTouch = true
                end
            elseif Obj:IsA("Decal") or Obj:IsA("Texture") then
                Obj.Transparency = DecalProps[Obj] or 0
            elseif Obj:IsA("BillboardGui") or Obj:IsA("Highlight") then
                Obj.Enabled = true
            end
        end)
    end
end

local function StopVelocity(Part, Frames)
    if not Part then return end

    for _ = 1, (Frames or 3) do
        if not Part.Parent then return end

        Part.AssemblyLinearVelocity = Vector3.zero
        Part.AssemblyAngularVelocity = Vector3.zero

        RunService.Heartbeat:Wait()
    end
end

_G.ToggleGhost = function()
    if Busy then return end

    Busy = true
    Ghost = not Ghost

    if Ghost then
        Character = Player.Character

        if not Character then
            Ghost = false
            Busy = false
            return
        end

        SaveState()

        local Root = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
        local StartCFrame = Root and Root.CFrame

        local CamCFrame = Camera.CFrame
        local CamFocus = Camera.Focus
        local CamType = Camera.CameraType

        Camera.CameraType = Enum.CameraType.Scriptable

        Character.Archivable = true
        GhostChar = Character:Clone()
        GhostChar.Name = "LocalGhost"

        for _, Obj in ipairs(GhostChar:GetDescendants()) do
            pcall(function()
                if Obj:IsA("BasePart") then
                    Obj.Transparency = Obj.Name == "HumanoidRootPart" and 1 or 0.5
                    Obj.CanCollide = false
                    Obj.CanTouch = false
                elseif Obj:IsA("Decal") or Obj:IsA("Texture") then
                    Obj.Transparency = 0.5
                end
            end)
        end

        local GhostRoot = GhostChar:FindFirstChild("HumanoidRootPart")
        local GhostHum = GhostChar:FindFirstChildOfClass("Humanoid")

        if GhostRoot and StartCFrame then
            GhostRoot.CFrame = StartCFrame
            GhostRoot.AssemblyLinearVelocity = Vector3.zero
            GhostRoot.AssemblyAngularVelocity = Vector3.zero
        end

        GhostChar.Parent = workspace

        if Root then
            Root.Anchored = true
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end

        Player.Character = GhostChar

        if GhostHum then
            GhostHum.Health = math.huge
            Camera.CameraSubject = GhostHum
        end

        Camera.CFrame = CamCFrame
        Camera.Focus = CamFocus

        HideCharacter()

        task.spawn(function()
            StopVelocity(GhostRoot, 3)

            Camera.CFrame = CamCFrame
            Camera.Focus = CamFocus
            RunService.RenderStepped:Wait()

            Camera.CFrame = CamCFrame
            Camera.Focus = CamFocus
            RunService.RenderStepped:Wait()

            Camera.CFrame = CamCFrame
            Camera.Focus = CamFocus
            Camera.CameraType = CamType
        end)

        ToggleButton.Text = "Ghost: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(85, 255, 127)

    else
        local CamCFrame = Camera.CFrame
        local CamFocus = Camera.Focus
        local CamType = Camera.CameraType

        Camera.CameraType = Enum.CameraType.Scriptable

        local FinalPos = GhostChar and GhostChar:GetPivot()

        local Target = Character

        if not Target or not Target.Parent then
            Target = Player.Character
            Character = Target
        end

        if Target and Target.Parent then
            local Root = Target:FindFirstChild("HumanoidRootPart") or Target.PrimaryPart
            local Hum = Target:FindFirstChildOfClass("Humanoid")

            if FinalPos then
                Target:PivotTo(FinalPos)
            end

            ShowCharacter()

            if Root then
                Root.Anchored = false
                Root.AssemblyLinearVelocity = Vector3.zero
                Root.AssemblyAngularVelocity = Vector3.zero
            end

            Player.Character = Target

            if Hum then
                Camera.CameraSubject = Hum

                if Hum.PlatformStand then
                    Hum.PlatformStand = false
                end

                if Hum.Sit then
                    Hum.Sit = false
                end
            end

            Camera.CFrame = CamCFrame
            Camera.Focus = CamFocus

            if GhostChar then
                GhostChar:Destroy()
                GhostChar = nil
            end

            task.spawn(function()
                StopVelocity(Root, 3)

                Camera.CFrame = CamCFrame
                Camera.Focus = CamFocus
                RunService.RenderStepped:Wait()

                Camera.CFrame = CamCFrame
                Camera.Focus = CamFocus
                RunService.RenderStepped:Wait()

                Camera.CFrame = CamCFrame
                Camera.Focus = CamFocus
                Camera.CameraType = CamType
            end)
        else
            if GhostChar then
                GhostChar:Destroy()
                GhostChar = nil
            end

            Camera.CameraType = CamType
        end

        ToggleButton.Text = "Ghost: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
    end

    task.wait(0.2)
    Busy = false
end

CreateGUI()

table.insert(Connections, UserInputService.InputBegan:Connect(function(Input, Processed)
    if not Processed and Input.KeyCode == Enum.KeyCode.G then
        _G.ToggleGhost()
    end
end))

table.insert(Connections, RunService.Stepped:Connect(function()
    if Ghost and not Busy and Character and GhostChar then
        if Player.Character ~= GhostChar then
            Player.Character = GhostChar
        end

        local GhostHum = GhostChar:FindFirstChildOfClass("Humanoid")

        if GhostHum and Camera.CameraSubject ~= GhostHum then
            Camera.CameraSubject = GhostHum
        end

        for _, Obj in ipairs(GhostChar:GetDescendants()) do
            pcall(function()
                if Obj:IsA("BasePart") then
                    Obj.Transparency = Obj.Name == "HumanoidRootPart" and 1 or 0.5
                elseif Obj:IsA("Decal") or Obj:IsA("Texture") then
                    Obj.Transparency = 0.5
                end
            end)
        end

        local Root = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
        local Hum = Character:FindFirstChildOfClass("Humanoid")

        if Root then
            Root.Anchored = true
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end

        HideCharacter()

        if Hum then
            Hum.Health = Hum.MaxHealth
        end
    end
end))

table.insert(Connections, Player.CharacterAdded:Connect(function()
    if Ghost then
        _G.ToggleGhost()
    end
end))

_G.a = Connections
