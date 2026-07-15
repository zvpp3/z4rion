--============================================================================--
--  EggFarmUI  -  standalone loadstring UI library (Orion-style API)
--  Usage:
--    local Library = loadstring(game:HttpGet('YOUR_RAW_URL'))()
--    local Window  = Library:MakeWindow({ Name = 'Egg Farm', SubTitle = 'by zvppe' })
--    local Tab     = Window:MakeTab({ Name = 'Main' })
--    local Section = Tab:AddSection({ Name = 'Main' })
--    Section:AddToggle({ Name = 'Auto Hit', Default = false, Callback = function(v) end })
--    Library:MakeNotification('Title', 'Body', 3)
--============================================================================--

--============================================================================--
--  UI library hand-written (no HttpGet / loadstring for the UI)
--  by zvppe
--============================================================================--

--// Services --------------------------------------------------------------- --
local Workspace          = game:GetService("Workspace")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer


--============================================================================--
--// UI Library
--  Small Orion-like library so the setup section below reads like the
--  original script. Modern dark theme, TweenService driven animations.
--============================================================================--
local Library = {}
Library.__index = Library

--// Theme / palette --
local Theme = {
    Background   = Color3.fromRGB(18, 18, 22),   -- near-black window body
    Panel        = Color3.fromRGB(26, 26, 32),   -- raised panels / rows
    PanelLight   = Color3.fromRGB(34, 34, 42),   -- hover / lighter panel
    Stroke       = Color3.fromRGB(48, 48, 58),   -- subtle borders
    Accent       = Color3.fromRGB(139, 122, 255),-- soft violet accent
    AccentDim    = Color3.fromRGB(70, 62, 130),  -- muted accent (off states)
    Text         = Color3.fromRGB(235, 235, 245),
    SubText      = Color3.fromRGB(150, 150, 165),
    Toggle       = Color3.fromRGB(58, 58, 70),   -- toggle track when off
    Hover        = Color3.fromRGB(40, 40, 50),   -- subtle hover tint on rows
}

--// Reusable tween presets --
local FAST   = TweenInfo.new(0.16, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local SMOOTH = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local POP    = TweenInfo.new(0.30, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)

--// Small helper for creating instances with a property table --
local function create(className, props)
    local inst = Instance.new(className)
    for prop, value in pairs(props or {}) do
        if prop ~= "Parent" then
            inst[prop] = value
        end
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

--// Rounded corners helper --
local function corner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent,
    })
end

--// Subtle stroke helper --
local function stroke(parent, color, thickness)
    return create("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

--// Padding helper --
local function pad(parent, amount)
    return create("UIPadding", {
        PaddingTop    = UDim.new(0, amount),
        PaddingBottom = UDim.new(0, amount),
        PaddingLeft   = UDim.new(0, amount),
        PaddingRight  = UDim.new(0, amount),
        Parent = parent,
    })
end

--// Subtle hover feedback for clickable rows --
local function attachHover(button, baseColor, hoverColor)
    button.MouseEnter:Connect(function()
        TweenService:Create(button, FAST, { BackgroundColor3 = hoverColor }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, FAST, { BackgroundColor3 = baseColor }):Play()
    end)
end


-- Constructs a fresh library instance bound to one ScreenGui.
function Library.new()
    local self = setmetatable({}, Library)
    self._connections = {}   -- library-owned connections, cleared on close
    self._notifyStack = {}    -- active notification toasts
    return self
end

-- Tracks a connection so the library can clean up on close.
function Library:_connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self._connections, connection)
    return connection
end


--// Window ---------------------------------------------------------------- --
-- Builds the ScreenGui, intro splash and main window. Returns a window
-- object exposing MakeTab. Tabs may be added immediately even while the
-- intro is still playing (the main frame exists, just hidden).
function Library:MakeWindow(config)
    config = config or {}
    local title    = config.Name     or "Window"
    local subtitle = config.SubTitle or ""

    --// ScreenGui, with re-execute cleanup of any previous instance --
    local guiName = "EggFarmGui_zvppe"

    local function destroyExisting(parent)
        local old = parent and parent:FindFirstChild(guiName)
        if old then
            old:Destroy()
        end
    end

    local screenGui = create("ScreenGui", {
        Name = guiName,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    })

    -- Parent using gethui() -> CoreGui (pcall) -> PlayerGui, cleaning old copies.
    local parented = false
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            destroyExisting(hui)
            screenGui.Parent = hui
            parented = true
        end
    end
    if not parented then
        local ok = pcall(function()
            local coreGui = game:GetService("CoreGui")
            destroyExisting(coreGui)
            screenGui.Parent = coreGui
        end)
        parented = ok
    end
    if not parented then
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")
        destroyExisting(playerGui)
        screenGui.Parent = playerGui
    end

    self._screenGui = screenGui

    --// Notification container (bottom-right stack) --
    local notifyHolder = create("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, 300, 1, -32),
        BackgroundTransparency = 1,
        Parent = screenGui,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = notifyHolder,
    })
    self._notifyHolder = notifyHolder

    --// Main window frame (built hidden, revealed after the intro) --
    local mainSize = UDim2.fromOffset(560, 380)

    local main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = mainSize,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Visible = false,
        Parent = screenGui,
    })
    corner(main, 12)
    stroke(main, Theme.Stroke, 1)
    self._main = main
    self._mainSize = mainSize

    --// Title bar (draggable, holds minimize + close) --
    local titleBar = create("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Parent = main,
    })
    corner(titleBar, 12)
    -- cover the lower rounded corners of the title bar so it meets the body
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Parent = titleBar,
    })

    local titleText = create("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 6),
        Size = UDim2.new(1, -120, 0, 20),
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleBar,
    })
    create("TextLabel", {
        Name = "SubTitle",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 25),
        Size = UDim2.new(1, -120, 0, 16),
        Font = Enum.Font.Gotham,
        Text = subtitle,
        TextColor3 = Theme.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleBar,
    })

    --// Window control buttons (minimize / close) --
    local function makeControl(text, xOffset, hoverColor)
        local btn = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.fromOffset(28, 28),
            BackgroundColor3 = Theme.PanelLight,
            AutoButtonColor = false,
            Font = Enum.Font.GothamBold,
            Text = text,
            TextColor3 = Theme.Text,
            TextSize = 16,
            Parent = titleBar,
        })
        corner(btn, 8)
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, FAST, { BackgroundColor3 = hoverColor }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, FAST, { BackgroundColor3 = Theme.PanelLight }):Play()
        end)
        return btn
    end

    local closeBtn    = makeControl("X", -12, Color3.fromRGB(200, 60, 70))
    local minimizeBtn = makeControl("-", -48, Theme.Accent)

    --// Body: sidebar (tabs) + content (scrolling) --
    local body = create("Frame", {
        Name = "Body",
        Position = UDim2.new(0, 0, 0, 46),
        Size = UDim2.new(1, 0, 1, -46),
        BackgroundTransparency = 1,
        Parent = main,
    })

    local sidebar = create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 140, 1, 0),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Parent = body,
    })
    pad(sidebar, 10)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = sidebar,
    })

    local content = create("Frame", {
        Name = "Content",
        Position = UDim2.new(0, 140, 0, 0),
        Size = UDim2.new(1, -140, 1, 0),
        BackgroundTransparency = 1,
        Parent = body,
    })

    --// Drag helper ------------------------------------------------------ --
    -- Sets up press-drag-release on a grabber GuiObject. `onMove` runs on the
    -- initial press and for every movement while held (mouse + touch). The
    -- movement connection is disconnected on release and is library-tracked so
    -- Library:Destroy tears it down even if released mid-drag.
    local function bindDrag(grabber, onMove)
        local moveConn

        grabber.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                onMove(input)
                if moveConn then
                    moveConn:Disconnect()
                end
                moveConn = UserInputService.InputChanged:Connect(function(moveInput)
                    if moveInput.UserInputType == Enum.UserInputType.MouseMovement
                        or moveInput.UserInputType == Enum.UserInputType.Touch then
                        onMove(moveInput)
                    end
                end)
                table.insert(self._connections, moveConn)
            end
        end)

        grabber.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                if moveConn then
                    moveConn:Disconnect()
                    moveConn = nil
                end
            end
        end)
    end

    --====================================================================--
    -- attachElements: installs every element adder onto `target`, parenting
    -- the created rows into `container`. Used by both tabs (container = page)
    -- and sections (container = the section frame) so tab-level and section
    -- elements share a single implementation.
    --====================================================================--
    local function attachElements(target, container)

        --// Label ------------------------------------------------------- --
        -- Accepts either a string or { Name = string }.
        function target:AddLabel(cfg)
            local text
            if type(cfg) == "string" then
                text = cfg
            else
                cfg = cfg or {}
                text = cfg.Name or ""
            end

            local row = create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Panel,
                BorderSizePixel = 0,
                Parent = container,
            })
            corner(row, 8)
            pad(row, 8)

            local label = create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Font = Enum.Font.Gotham,
                Text = text,
                TextColor3 = Theme.SubText,
                TextSize = 13,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })

            return {
                Set = function(newText)
                    label.Text = newText
                end,
            }
        end

        --// Paragraph --------------------------------------------------- --
        -- Bold title line plus a wrapped body that auto-sizes its height.
        function target:AddParagraph(cfg)
            cfg = cfg or {}

            local panel = create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Panel,
                BorderSizePixel = 0,
                Parent = container,
            })
            corner(panel, 8)
            pad(panel, 10)
            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = panel,
            })

            create("TextLabel", {
                Name = "Title",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = Enum.Font.GothamBold,
                Text = cfg.Name or "",
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = panel,
            })

            local body = create("TextLabel", {
                Name = "Body",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Font = Enum.Font.Gotham,
                Text = cfg.Content or "",
                TextColor3 = Theme.SubText,
                TextSize = 13,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                Parent = panel,
            })

            return {
                Set = function(content)
                    body.Text = content
                end,
            }
        end

        --// Button ------------------------------------------------------ --
        function target:AddButton(cfg)
            cfg = cfg or {}

            local btn = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = Theme.PanelLight,
                AutoButtonColor = false,
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Button",
                TextColor3 = Theme.Text,
                TextSize = 14,
                Parent = container,
            })
            corner(btn, 8)
            attachHover(btn, Theme.PanelLight, Theme.Hover)

            btn.MouseButton1Click:Connect(function()
                -- Quick press feedback: flash to accent and back.
                TweenService:Create(btn, FAST, { BackgroundColor3 = Theme.Accent }):Play()
                task.delay(0.12, function()
                    TweenService:Create(btn, FAST, { BackgroundColor3 = Theme.PanelLight }):Play()
                end)
                if cfg.Callback then
                    cfg.Callback()
                end
            end)

            return {
                Set = function(text)
                    btn.Text = text
                end,
            }
        end

        --// Toggle ------------------------------------------------------ --
        -- Pill-style animated switch.
        function target:AddToggle(cfg)
            cfg = cfg or {}
            local state = cfg.Default and true or false

            local row = create("Frame", {
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = Theme.PanelLight,
                BorderSizePixel = 0,
                Parent = container,
            })
            corner(row, 8)
            pad(row, 8)

            create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -60, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Toggle",
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })

            -- Track + knob.
            local track = create("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(44, 22),
                BackgroundColor3 = state and Theme.Accent or Theme.Toggle,
                AutoButtonColor = false,
                Text = "",
                Parent = row,
            })
            corner(track, 11)

            local knob = create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                Size = UDim2.fromOffset(18, 18),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                Parent = track,
            })
            corner(knob, 9)

            local handle = { Value = state }

            local function render()
                TweenService:Create(track, FAST, {
                    BackgroundColor3 = state and Theme.Accent or Theme.Toggle,
                }):Play()
                TweenService:Create(knob, FAST, {
                    Position = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                }):Play()
            end

            local function setState(newState, fire)
                state = newState and true or false
                handle.Value = state
                render()
                if fire and cfg.Callback then
                    cfg.Callback(state)
                end
            end

            track.MouseButton1Click:Connect(function()
                setState(not state, true)
            end)

            handle.Set = function(v)
                setState(v, true)
            end

            -- Fire once for the default so logic + UI start in sync.
            if cfg.Callback then
                cfg.Callback(state)
            end
            return handle
        end

        --// Slider ------------------------------------------------------ --
        function target:AddSlider(cfg)
            cfg = cfg or {}
            local min       = cfg.Min or 0
            local max       = cfg.Max or 100
            local increment = cfg.Increment or 1
            local valueName = cfg.ValueName or ""
            local fillColor = cfg.Color or Theme.Accent

            if max < min then
                max = min
            end

            -- Snaps a raw value to the nearest increment step, clamped to range.
            local function snap(raw)
                local steps = math.floor((raw - min) / increment + 0.5)
                local stepped = min + steps * increment
                return math.clamp(stepped, min, max)
            end

            -- Formats a value, dropping trailing zeros for integer increments.
            local function formatValue(v)
                local text
                if increment % 1 == 0 then
                    text = tostring(math.floor(v + 0.5))
                else
                    text = string.format("%.3f", v)
                    text = text:gsub("0+$", "")
                    text = text:gsub("%.$", "")
                end
                if valueName ~= "" then
                    text = text .. " " .. valueName
                end
                return text
            end

            local value = snap(cfg.Default or min)

            local row = create("Frame", {
                Size = UDim2.new(1, 0, 0, 48),
                BackgroundColor3 = Theme.PanelLight,
                BorderSizePixel = 0,
                Parent = container,
            })
            corner(row, 8)

            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 6),
                Size = UDim2.new(1, -130, 0, 18),
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Slider",
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })

            local readout = create("TextLabel", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 6),
                Size = UDim2.new(0, 108, 0, 18),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                Text = formatValue(value),
                TextColor3 = Theme.SubText,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = row,
            })

            local track = create("Frame", {
                Position = UDim2.new(0, 12, 0, 32),
                Size = UDim2.new(1, -24, 0, 8),
                BackgroundColor3 = Theme.Toggle,
                BorderSizePixel = 0,
                Parent = row,
            })
            corner(track, 4)

            local function alphaFor(v)
                if max <= min then
                    return 0
                end
                return (v - min) / (max - min)
            end

            local fill = create("Frame", {
                Size = UDim2.new(alphaFor(value), 0, 1, 0),
                BackgroundColor3 = fillColor,
                BorderSizePixel = 0,
                Parent = track,
            })
            corner(fill, 4)

            local handle = { Value = value }

            -- Applies a new value: updates fill + readout, fires the callback
            -- only when the stepped value actually changes. `live` sets the
            -- fill instantly (during drag); otherwise it tweens (on :Set).
            local function applyValue(newValue, live, fireCallback)
                newValue = snap(newValue)
                local changed = (newValue ~= value)
                value = newValue
                handle.Value = value
                readout.Text = formatValue(value)
                if live then
                    fill.Size = UDim2.new(alphaFor(value), 0, 1, 0)
                else
                    TweenService:Create(fill, FAST, {
                        Size = UDim2.new(alphaFor(value), 0, 1, 0),
                    }):Play()
                end
                if fireCallback and changed and cfg.Callback then
                    cfg.Callback(value)
                end
            end

            -- Converts a pointer X position to a value along the track.
            local function valueFromX(px)
                local rel = 0
                if track.AbsoluteSize.X > 0 then
                    rel = math.clamp((px - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                end
                return min + rel * (max - min)
            end

            bindDrag(track, function(input)
                applyValue(valueFromX(input.Position.X), true, true)
            end)

            handle.Set = function(v)
                applyValue(v, false, true)
            end

            -- Fire once at creation with the default value.
            if cfg.Callback then
                cfg.Callback(value)
            end

            return handle
        end

        --// Dropdown (single select) ------------------------------------ --
        function target:AddDropdown(cfg)
            cfg = cfg or {}
            local options = cfg.Options or {}
            local selected = cfg.Default
            local expanded = false

            local headerH = 34
            local optionH = 28

            local container2 = create("Frame", {
                Size = UDim2.new(1, 0, 0, headerH),
                BackgroundColor3 = Theme.PanelLight,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = container,
            })
            corner(container2, 8)
            attachHover(container2, Theme.PanelLight, Theme.Hover)

            local header = create("TextButton", {
                Size = UDim2.new(1, 0, 0, headerH),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "",
                Parent = container2,
            })
            local valueLabel = create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -36, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = "",
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = header,
            })
            local arrow = create("TextLabel", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 0),
                Size = UDim2.new(0, 20, 0, headerH),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                Text = "v",
                TextColor3 = Theme.SubText,
                TextSize = 14,
                Parent = header,
            })

            local holder = create("Frame", {
                Position = UDim2.new(0, 0, 0, headerH),
                Size = UDim2.new(1, 0, 1, -headerH),
                BackgroundTransparency = 1,
                Parent = container2,
            })
            pad(holder, 4)
            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 2),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = holder,
            })

            local handle = { Value = selected }

            local function refreshLabel()
                local shown = (selected ~= nil) and tostring(selected) or "..."
                valueLabel.Text = (cfg.Name or "Dropdown") .. ": " .. shown
            end

            local function expandedHeight()
                return headerH + (#options * optionH) + 6
            end

            local function setExpanded(open)
                expanded = open
                TweenService:Create(container2, SMOOTH, {
                    Size = UDim2.new(1, 0, 0, open and expandedHeight() or headerH),
                }):Play()
                TweenService:Create(arrow, FAST, {
                    Rotation = open and 180 or 0,
                }):Play()
            end

            -- Builds the option buttons from the current options array.
            local function rebuild(newOptions)
                if newOptions then
                    options = newOptions
                end
                for _, child in ipairs(holder:GetChildren()) do
                    if child:IsA("TextButton") then
                        child:Destroy()
                    end
                end
                for _, option in ipairs(options) do
                    local optBtn = create("TextButton", {
                        Size = UDim2.new(1, 0, 0, optionH - 2),
                        BackgroundColor3 = Theme.Panel,
                        AutoButtonColor = false,
                        Font = Enum.Font.Gotham,
                        Text = option,
                        TextColor3 = Theme.SubText,
                        TextSize = 13,
                        Parent = holder,
                    })
                    corner(optBtn, 6)
                    attachHover(optBtn, Theme.Panel, Theme.PanelLight)

                    optBtn.MouseButton1Click:Connect(function()
                        selected = option
                        handle.Value = selected
                        refreshLabel()
                        setExpanded(false)
                        if cfg.Callback then
                            cfg.Callback(selected)
                        end
                    end)
                end
                -- Recompute height if currently open (option count may differ).
                if expanded then
                    container2.Size = UDim2.new(1, 0, 0, expandedHeight())
                end
            end

            header.MouseButton1Click:Connect(function()
                setExpanded(not expanded)
            end)

            rebuild(options)
            refreshLabel()

            handle.Set = function(option)
                selected = option
                handle.Value = selected
                refreshLabel()
                if cfg.Callback then
                    cfg.Callback(selected)
                end
            end

            handle.Refresh = function(newOptions, deleteCurrent)
                if deleteCurrent then
                    selected = nil
                    handle.Value = nil
                    refreshLabel()
                end
                rebuild(newOptions)
            end

            -- Fire once with the default selection.
            if cfg.Callback and selected ~= nil then
                cfg.Callback(selected)
            end
            return handle
        end

        --// Multi-select dropdown --------------------------------------- --
        -- Each option toggles into a selection set. Callback receives the full
        -- selected list (array of strings).
        function target:AddMultiDropdown(cfg)
            cfg = cfg or {}
            local options = cfg.Options or {}
            local expanded = false

            -- Selection state keyed by option name.
            local chosen = {}
            for _, name in ipairs(cfg.Default or {}) do
                chosen[name] = true
            end

            -- Builds the ordered array of currently selected options.
            local function selectedList()
                local list = {}
                for _, name in ipairs(options) do
                    if chosen[name] then
                        table.insert(list, name)
                    end
                end
                return list
            end

            local headerH   = 34
            local optionH   = 28
            local expandedH = headerH + (#options * optionH) + 6

            local container2 = create("Frame", {
                Size = UDim2.new(1, 0, 0, headerH),
                BackgroundColor3 = Theme.PanelLight,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = container,
            })
            corner(container2, 8)
            attachHover(container2, Theme.PanelLight, Theme.Hover)

            local header = create("TextButton", {
                Size = UDim2.new(1, 0, 0, headerH),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "",
                Parent = container2,
            })
            local valueLabel = create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -36, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Select",
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = header,
            })
            local arrow = create("TextLabel", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 0),
                Size = UDim2.new(0, 20, 0, headerH),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                Text = "v",
                TextColor3 = Theme.SubText,
                TextSize = 14,
                Parent = header,
            })

            local function refreshSummary()
                local list = selectedList()
                local summary = (#list > 0) and table.concat(list, ", ") or "None"
                valueLabel.Text = (cfg.Name or "Select") .. ": " .. summary
            end

            local holder = create("Frame", {
                Position = UDim2.new(0, 0, 0, headerH),
                Size = UDim2.new(1, 0, 0, expandedH - headerH),
                BackgroundTransparency = 1,
                Parent = container2,
            })
            pad(holder, 4)
            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 2),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = holder,
            })

            local function setExpanded(open)
                expanded = open
                TweenService:Create(container2, SMOOTH, {
                    Size = UDim2.new(1, 0, 0, open and expandedH or headerH),
                }):Play()
                TweenService:Create(arrow, FAST, {
                    Rotation = open and 180 or 0,
                }):Play()
            end

            local handle = { Value = selectedList() }

            -- Checkmark labels keyed by option, so :Set can refresh them.
            local checks = {}

            for _, option in ipairs(options) do
                local optBtn = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, optionH - 2),
                    BackgroundColor3 = Theme.Panel,
                    AutoButtonColor = false,
                    Text = "",
                    Parent = holder,
                })
                corner(optBtn, 6)
                attachHover(optBtn, Theme.Panel, Theme.PanelLight)

                create("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0),
                    Size = UDim2.new(1, -40, 1, 0),
                    Font = Enum.Font.Gotham,
                    Text = option,
                    TextColor3 = Theme.SubText,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = optBtn,
                })

                -- Checkmark indicator on the right.
                local check = create("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.fromOffset(18, 18),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold,
                    Text = chosen[option] and "\u{2713}" or "",
                    TextColor3 = Theme.Accent,
                    TextSize = 16,
                    Parent = optBtn,
                })
                checks[option] = check

                optBtn.MouseButton1Click:Connect(function()
                    chosen[option] = not chosen[option]
                    check.Text = chosen[option] and "\u{2713}" or ""
                    handle.Value = selectedList()
                    refreshSummary()
                    if cfg.Callback then
                        cfg.Callback(selectedList())
                    end
                end)
            end

            header.MouseButton1Click:Connect(function()
                setExpanded(not expanded)
            end)

            refreshSummary()

            handle.Set = function(selectedArray)
                chosen = {}
                for _, name in ipairs(selectedArray or {}) do
                    chosen[name] = true
                end
                for option, check in pairs(checks) do
                    check.Text = chosen[option] and "\u{2713}" or ""
                end
                handle.Value = selectedList()
                refreshSummary()
                if cfg.Callback then
                    cfg.Callback(selectedList())
                end
            end

            -- Fire once with the default selection array.
            if cfg.Callback then
                cfg.Callback(selectedList())
            end
            return handle
        end

        --// Bind -------------------------------------------------------- --
        -- Row with a key chip; click to rebind, listens for the next key.
        function target:AddBind(cfg)
            cfg = cfg or {}
            local key = cfg.Default
            local hold = cfg.Hold and true or false
            local listening = false

            local row = create("Frame", {
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = Theme.PanelLight,
                BorderSizePixel = 0,
                Parent = container,
            })
            corner(row, 8)

            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -90, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Bind",
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })

            local function keyName(k)
                if not k then
                    return "NONE"
                end
                return k.Name
            end

            local chip = create("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.fromOffset(64, 24),
                BackgroundColor3 = Theme.Panel,
                AutoButtonColor = false,
                Font = Enum.Font.GothamMedium,
                Text = keyName(key),
                TextColor3 = Theme.SubText,
                TextSize = 13,
                Parent = row,
            })
            corner(chip, 6)
            attachHover(chip, Theme.Panel, Theme.PanelLight)

            local handle = { Value = key }

            chip.MouseButton1Click:Connect(function()
                listening = true
                chip.Text = "..."
            end)

            self:_connect(UserInputService.InputBegan, function(input, gameProcessed)
                if listening then
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        if input.KeyCode == Enum.KeyCode.Escape then
                            -- Cancel and keep the previous bind.
                            listening = false
                            chip.Text = keyName(key)
                        else
                            key = input.KeyCode
                            handle.Value = key
                            listening = false
                            chip.Text = keyName(key)
                        end
                    end
                    return
                end

                if gameProcessed then
                    return
                end
                if UserInputService:GetFocusedTextBox() then
                    return
                end
                if key and input.KeyCode == key then
                    if hold then
                        if cfg.Callback then
                            cfg.Callback(true)
                        end
                    else
                        if cfg.Callback then
                            cfg.Callback()
                        end
                    end
                end
            end)

            if hold then
                self:_connect(UserInputService.InputEnded, function(input, gameProcessed)
                    if listening then
                        return
                    end
                    if UserInputService:GetFocusedTextBox() then
                        return
                    end
                    if key and input.KeyCode == key then
                        if cfg.Callback then
                            cfg.Callback(false)
                        end
                    end
                end)
            end

            handle.Set = function(k)
                key = k
                handle.Value = key
                chip.Text = keyName(key)
            end

            return handle
        end

        --// Textbox ----------------------------------------------------- --
        function target:AddTextbox(cfg)
            cfg = cfg or {}

            local row = create("Frame", {
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = Theme.Panel,
                BorderSizePixel = 0,
                Parent = container,
            })
            corner(row, 8)

            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(0.4, -12, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Textbox",
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })

            local box = create("TextBox", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.new(0.6, -16, 0, 24),
                BackgroundColor3 = Theme.PanelLight,
                BorderSizePixel = 0,
                ClearTextOnFocus = false,
                Font = Enum.Font.Gotham,
                PlaceholderText = "...",
                PlaceholderColor3 = Theme.SubText,
                Text = cfg.Default or "",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            corner(box, 6)
            create("UIPadding", {
                PaddingLeft  = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8),
                Parent = box,
            })
            local boxStroke = stroke(box, Theme.Stroke, 1)

            box.Focused:Connect(function()
                TweenService:Create(boxStroke, FAST, { Color = Theme.Accent }):Play()
            end)
            box.FocusLost:Connect(function(enterPressed)
                TweenService:Create(boxStroke, FAST, { Color = Theme.Stroke }):Play()
                if cfg.Callback then
                    cfg.Callback(box.Text, enterPressed)
                end
                if cfg.TextDisappear then
                    box.Text = ""
                end
            end)

            return {
                Set = function(text)
                    box.Text = text
                end,
            }
        end

        --// Colorpicker ------------------------------------------------- --
        -- Collapsed row with a swatch; expands to an SV square + hue bar.
        function target:AddColorpicker(cfg)
            cfg = cfg or {}
            local color = cfg.Default or Color3.fromRGB(255, 255, 255)
            local h, s, v = color:ToHSV()
            local expanded = false

            local headerH   = 34
            local svSize    = 110
            local hueH      = 14
            local expandedH = headerH + 12 + svSize + 10 + hueH + 12

            local container2 = create("Frame", {
                Size = UDim2.new(1, 0, 0, headerH),
                BackgroundColor3 = Theme.PanelLight,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = container,
            })
            corner(container2, 8)
            attachHover(container2, Theme.PanelLight, Theme.Hover)

            local header = create("TextButton", {
                Size = UDim2.new(1, 0, 0, headerH),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "",
                Parent = container2,
            })
            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -60, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Color",
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = header,
            })

            local swatch = create("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0, headerH / 2),
                Size = UDim2.fromOffset(24, 18),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                Parent = header,
            })
            corner(swatch, 6)
            stroke(swatch, Theme.Stroke, 1)

            -- Expandable body: SV square on top, hue bar below.
            local body = create("Frame", {
                Position = UDim2.new(0, 0, 0, headerH),
                Size = UDim2.new(1, 0, 0, expandedH - headerH),
                BackgroundTransparency = 1,
                Parent = container2,
            })
            pad(body, 12)
            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 10),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = body,
            })

            -- SV square: pure-hue base + white(horizontal) + black(vertical).
            local svSquare = create("Frame", {
                Size = UDim2.new(1, 0, 0, svSize),
                BackgroundColor3 = Color3.fromHSV(h, 1, 1),
                BorderSizePixel = 0,
                Parent = body,
            })
            corner(svSquare, 6)

            local whiteOverlay = create("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                Parent = svSquare,
            })
            corner(whiteOverlay, 6)
            create("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }),
                Parent = whiteOverlay,
            })

            local blackOverlay = create("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Parent = svSquare,
            })
            corner(blackOverlay, 6)
            create("UIGradient", {
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0),
                }),
                Parent = blackOverlay,
            })

            local svSelector = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(s, 0, 1 - v, 0),
                Size = UDim2.fromOffset(10, 10),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                Parent = svSquare,
            })
            corner(svSelector, 5)
            stroke(svSelector, Color3.fromRGB(0, 0, 0), 1)

            local svCatcher = create("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "",
                Parent = svSquare,
            })

            -- Hue bar: rainbow spectrum with its own selector.
            local hueBar = create("Frame", {
                Size = UDim2.new(1, 0, 0, hueH),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                Parent = body,
            })
            corner(hueBar, 6)
            create("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
                }),
                Parent = hueBar,
            })

            local hueSelector = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(h, 0, 0.5, 0),
                Size = UDim2.new(0, 6, 1, 4),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                Parent = hueBar,
            })
            corner(hueSelector, 3)
            stroke(hueSelector, Color3.fromRGB(0, 0, 0), 1)

            local hueCatcher = create("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "",
                Parent = hueBar,
            })

            local handle = { Value = color }

            -- Repaints swatch, SV base and both selectors from h, s, v.
            local function applyColor(fireCallback)
                local current = Color3.fromHSV(h, s, v)
                handle.Value = current
                swatch.BackgroundColor3 = current
                svSquare.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                svSelector.Position = UDim2.new(s, 0, 1 - v, 0)
                hueSelector.Position = UDim2.new(h, 0, 0.5, 0)
                if fireCallback and cfg.Callback then
                    cfg.Callback(current)
                end
            end

            bindDrag(svCatcher, function(input)
                local relX, relY = 0, 0
                if svSquare.AbsoluteSize.X > 0 then
                    relX = math.clamp((input.Position.X - svSquare.AbsolutePosition.X) / svSquare.AbsoluteSize.X, 0, 1)
                end
                if svSquare.AbsoluteSize.Y > 0 then
                    relY = math.clamp((input.Position.Y - svSquare.AbsolutePosition.Y) / svSquare.AbsoluteSize.Y, 0, 1)
                end
                s = relX
                v = 1 - relY
                applyColor(true)
            end)

            bindDrag(hueCatcher, function(input)
                local relX = 0
                if hueBar.AbsoluteSize.X > 0 then
                    relX = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
                end
                h = relX
                applyColor(true)
            end)

            local function setExpanded(open)
                expanded = open
                TweenService:Create(container2, POP, {
                    Size = UDim2.new(1, 0, 0, open and expandedH or headerH),
                }):Play()
            end

            header.MouseButton1Click:Connect(function()
                setExpanded(not expanded)
            end)

            handle.Set = function(newColor)
                h, s, v = newColor:ToHSV()
                applyColor(true)
            end

            -- Fire once at creation with the default color.
            if cfg.Callback then
                cfg.Callback(Color3.fromHSV(h, s, v))
            end

            return handle
        end
    end


    --// Window object exposed to the setup code --
    local window = {}
    window._tabs = {}

    -- Selects a tab: shows its page, hides the rest, highlights the button.
    local function selectTab(target)
        for _, tab in ipairs(window._tabs) do
            local active = (tab == target)
            tab.Page.Visible = active
            TweenService:Create(tab.Button, FAST, {
                BackgroundColor3 = active and Theme.Accent or Theme.PanelLight,
            }):Play()
            TweenService:Create(tab.Label, FAST, {
                TextColor3 = active and Color3.fromRGB(255, 255, 255) or Theme.SubText,
            }):Play()
        end
    end

    -- Creates a tab: a sidebar button plus a scrolling content page.
    function window:MakeTab(tabConfig)
        tabConfig = tabConfig or {}

        local button = create("TextButton", {
            Name = tabConfig.Name or "Tab",
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = Theme.PanelLight,
            AutoButtonColor = false,
            Text = "",
            Parent = sidebar,
        })
        corner(button, 8)

        local label = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -20, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            Font = Enum.Font.GothamMedium,
            Text = tabConfig.Name or "Tab",
            TextColor3 = Theme.SubText,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = button,
        })

        local page = create("ScrollingFrame", {
            Name = (tabConfig.Name or "Tab") .. "Page",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            Parent = content,
        })
        pad(page, 12)
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = page,
        })

        local tab = { Button = button, Label = label, Page = page }
        table.insert(window._tabs, tab)

        button.MouseButton1Click:Connect(function()
            selectTab(tab)
        end)

        -- First tab is selected by default.
        if #window._tabs == 1 then
            selectTab(tab)
        end

        --// Section: a labelled group inside this tab's page --
        function tab:AddSection(sectionConfig)
            sectionConfig = sectionConfig or {}

            local sectionFrame = create("Frame", {
                Name = "Section",
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Panel,
                BorderSizePixel = 0,
                Parent = page,
            })
            corner(sectionFrame, 10)
            stroke(sectionFrame, Theme.Stroke, 1)
            pad(sectionFrame, 12)
            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = sectionFrame,
            })

            create("TextLabel", {
                Name = "Header",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = Enum.Font.GothamBold,
                Text = sectionConfig.Name or "Section",
                TextColor3 = Theme.Accent,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = sectionFrame,
            })

            local section = {}

            ------------------------------------------------------------------
            -- Toggle: pill-style animated switch.
            ------------------------------------------------------------------
            function section:AddToggle(cfg)
                cfg = cfg or {}
                local state = cfg.Default and true or false

                local row = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 34),
                    BackgroundColor3 = Theme.PanelLight,
                    BorderSizePixel = 0,
                    Parent = sectionFrame,
                })
                corner(row, 8)
                pad(row, 8)

                create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -60, 1, 0),
                    Font = Enum.Font.GothamMedium,
                    Text = cfg.Name or "Toggle",
                    TextColor3 = Theme.Text,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row,
                })

                -- Track + knob.
                local track = create("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(44, 22),
                    BackgroundColor3 = state and Theme.Accent or Theme.Toggle,
                    AutoButtonColor = false,
                    Text = "",
                    Parent = row,
                })
                corner(track, 11)

                local knob = create("Frame", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                    Size = UDim2.fromOffset(18, 18),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BorderSizePixel = 0,
                    Parent = track,
                })
                corner(knob, 9)

                local function render()
                    TweenService:Create(track, FAST, {
                        BackgroundColor3 = state and Theme.Accent or Theme.Toggle,
                    }):Play()
                    TweenService:Create(knob, FAST, {
                        Position = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                    }):Play()
                end

                track.MouseButton1Click:Connect(function()
                    state = not state
                    render()
                    if cfg.Callback then
                        cfg.Callback(state)
                    end
                end)

                -- Fire once for the default so logic + UI start in sync.
                if cfg.Callback then
                    cfg.Callback(state)
                end
                return section
            end

            ------------------------------------------------------------------
            -- Button: click-feedback animation.
            ------------------------------------------------------------------
            function section:AddButton(cfg)
                cfg = cfg or {}

                local btn = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 34),
                    BackgroundColor3 = Theme.PanelLight,
                    AutoButtonColor = false,
                    Font = Enum.Font.GothamMedium,
                    Text = cfg.Name or "Button",
                    TextColor3 = Theme.Text,
                    TextSize = 14,
                    Parent = sectionFrame,
                })
                corner(btn, 8)

                btn.MouseButton1Click:Connect(function()
                    -- Quick press feedback: flash to accent and back.
                    TweenService:Create(btn, FAST, { BackgroundColor3 = Theme.Accent }):Play()
                    task.delay(0.12, function()
                        TweenService:Create(btn, FAST, { BackgroundColor3 = Theme.PanelLight }):Play()
                    end)
                    if cfg.Callback then
                        cfg.Callback()
                    end
                end)
                return section
            end

            ------------------------------------------------------------------
            -- Dropdown (single select).
            ------------------------------------------------------------------
            function section:AddDropdown(cfg)
                cfg = cfg or {}
                local options = cfg.Options or {}
                local selected = cfg.Default
                local expanded = false

                local headerH  = 34
                local optionH  = 28
                local expandedH = headerH + (#options * optionH) + 6

                local container = create("Frame", {
                    Size = UDim2.new(1, 0, 0, headerH),
                    BackgroundColor3 = Theme.PanelLight,
                    BorderSizePixel = 0,
                    ClipsDescendants = true,
                    Parent = sectionFrame,
                })
                corner(container, 8)

                local header = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, headerH),
                    BackgroundTransparency = 1,
                    AutoButtonColor = false,
                    Text = "",
                    Parent = container,
                })
                create("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, 0),
                    Size = UDim2.new(1, -24, 1, 0),
                    Font = Enum.Font.GothamMedium,
                    Text = (cfg.Name or "Dropdown") .. ": " .. tostring(selected),
                    TextColor3 = Theme.Text,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Name = "Value",
                    Parent = header,
                })
                local arrow = create("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -12, 0, 0),
                    Size = UDim2.new(0, 20, 0, headerH),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold,
                    Text = "v",
                    TextColor3 = Theme.SubText,
                    TextSize = 14,
                    Parent = header,
                })

                local valueLabel = header:FindFirstChild("Value")

                -- Options holder positioned below the header.
                local holder = create("Frame", {
                    Position = UDim2.new(0, 0, 0, headerH),
                    Size = UDim2.new(1, 0, 0, expandedH - headerH),
                    BackgroundTransparency = 1,
                    Parent = container,
                })
                pad(holder, 4)
                create("UIListLayout", {
                    FillDirection = Enum.FillDirection.Vertical,
                    Padding = UDim.new(0, 2),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = holder,
                })

                local function setExpanded(open)
                    expanded = open
                    TweenService:Create(container, SMOOTH, {
                        Size = UDim2.new(1, 0, 0, open and expandedH or headerH),
                    }):Play()
                    TweenService:Create(arrow, FAST, {
                        Rotation = open and 180 or 0,
                    }):Play()
                end

                for _, option in ipairs(options) do
                    local optBtn = create("TextButton", {
                        Size = UDim2.new(1, 0, 0, optionH - 2),
                        BackgroundColor3 = Theme.Panel,
                        AutoButtonColor = false,
                        Font = Enum.Font.Gotham,
                        Text = option,
                        TextColor3 = Theme.SubText,
                        TextSize = 13,
                        Parent = holder,
                    })
                    corner(optBtn, 6)

                    optBtn.MouseButton1Click:Connect(function()
                        selected = option
                        valueLabel.Text = (cfg.Name or "Dropdown") .. ": " .. tostring(selected)
                        setExpanded(false)
                        if cfg.Callback then
                            cfg.Callback(selected)
                        end
                    end)
                end

                header.MouseButton1Click:Connect(function()
                    setExpanded(not expanded)
                end)

                -- Fire once with the default selection.
                if cfg.Callback and selected ~= nil then
                    cfg.Callback(selected)
                end
                return section
            end

            ------------------------------------------------------------------
            -- Multi-select dropdown: each option toggles into a selection set.
            -- Callback receives the full selected list (array of strings).
            ------------------------------------------------------------------
            function section:AddMultiDropdown(cfg)
                cfg = cfg or {}
                local options = cfg.Options or {}
                local expanded = false

                -- Selection state keyed by option name.
                local chosen = {}
                for _, name in ipairs(cfg.Default or {}) do
                    chosen[name] = true
                end

                -- Builds the ordered array of currently selected options.
                local function selectedList()
                    local list = {}
                    for _, name in ipairs(options) do
                        if chosen[name] then
                            table.insert(list, name)
                        end
                    end
                    return list
                end

                local headerH   = 34
                local optionH   = 28
                local expandedH = headerH + (#options * optionH) + 6

                local container = create("Frame", {
                    Size = UDim2.new(1, 0, 0, headerH),
                    BackgroundColor3 = Theme.PanelLight,
                    BorderSizePixel = 0,
                    ClipsDescendants = true,
                    Parent = sectionFrame,
                })
                corner(container, 8)

                local header = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, headerH),
                    BackgroundTransparency = 1,
                    AutoButtonColor = false,
                    Text = "",
                    Parent = container,
                })
                local valueLabel = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, 0),
                    Size = UDim2.new(1, -24, 1, 0),
                    Font = Enum.Font.GothamMedium,
                    Text = cfg.Name or "Select",
                    TextColor3 = Theme.Text,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = header,
                })
                local arrow = create("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -12, 0, 0),
                    Size = UDim2.new(0, 20, 0, headerH),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold,
                    Text = "v",
                    TextColor3 = Theme.SubText,
                    TextSize = 14,
                    Parent = header,
                })

                local function refreshSummary()
                    local list = selectedList()
                    local summary = (#list > 0) and table.concat(list, ", ") or "None"
                    valueLabel.Text = (cfg.Name or "Select") .. ": " .. summary
                end

                local holder = create("Frame", {
                    Position = UDim2.new(0, 0, 0, headerH),
                    Size = UDim2.new(1, 0, 0, expandedH - headerH),
                    BackgroundTransparency = 1,
                    Parent = container,
                })
                pad(holder, 4)
                create("UIListLayout", {
                    FillDirection = Enum.FillDirection.Vertical,
                    Padding = UDim.new(0, 2),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = holder,
                })

                local function setExpanded(open)
                    expanded = open
                    TweenService:Create(container, SMOOTH, {
                        Size = UDim2.new(1, 0, 0, open and expandedH or headerH),
                    }):Play()
                    TweenService:Create(arrow, FAST, {
                        Rotation = open and 180 or 0,
                    }):Play()
                end

                for _, option in ipairs(options) do
                    local optBtn = create("TextButton", {
                        Size = UDim2.new(1, 0, 0, optionH - 2),
                        BackgroundColor3 = Theme.Panel,
                        AutoButtonColor = false,
                        Text = "",
                        Parent = holder,
                    })
                    corner(optBtn, 6)

                    create("TextLabel", {
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 10, 0, 0),
                        Size = UDim2.new(1, -40, 1, 0),
                        Font = Enum.Font.Gotham,
                        Text = option,
                        TextColor3 = Theme.SubText,
                        TextSize = 13,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = optBtn,
                    })

                    -- Checkmark indicator on the right.
                    local check = create("TextLabel", {
                        AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.new(1, -10, 0.5, 0),
                        Size = UDim2.fromOffset(18, 18),
                        BackgroundTransparency = 1,
                        Font = Enum.Font.GothamBold,
                        Text = chosen[option] and "\u{2713}" or "",
                        TextColor3 = Theme.Accent,
                        TextSize = 16,
                        Parent = optBtn,
                    })

                    optBtn.MouseButton1Click:Connect(function()
                        chosen[option] = not chosen[option]
                        check.Text = chosen[option] and "\u{2713}" or ""
                        refreshSummary()
                        if cfg.Callback then
                            cfg.Callback(selectedList())
                        end
                    end)
                end

                header.MouseButton1Click:Connect(function()
                    setExpanded(not expanded)
                end)

                refreshSummary()

                -- Fire once with the default selection array.
                if cfg.Callback then
                    cfg.Callback(selectedList())
                end
                return section
            end

            return section
        end

        return tab
    end

    --// Dragging (mouse + touch) via the title bar --
    do
        local dragging = false
        local dragStart, startPos

        local function beginDrag(input)
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end

        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                beginDrag(input)
            end
        end)
        titleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        self:_connect(UserInputService.InputChanged, function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                main.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    --// Minimize: collapse to just the title bar, toggle back on click --
    do
        local minimized = false
        minimizeBtn.MouseButton1Click:Connect(function()
            minimized = not minimized
            body.Visible = not minimized
            TweenService:Create(main, SMOOTH, {
                Size = minimized and UDim2.fromOffset(mainSize.X.Offset, 46) or mainSize,
            }):Play()
        end)
    end

    --// Close: destroy the GUI and drop the library's own connections --
    closeBtn.MouseButton1Click:Connect(function()
        self:Destroy()
    end)

    --// RightShift toggles window visibility --
    self:_connect(UserInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            main.Visible = not main.Visible
        end
    end)

    --// Intro splash, then reveal the window --
    self:_playIntro(function()
        main.Visible = true
        main.Size = UDim2.fromOffset(mainSize.X.Offset * 0.85, mainSize.Y.Offset * 0.85)
        TweenService:Create(main, POP, { Size = mainSize }):Play()
    end)

    return window
end


--// Intro splash --------------------------------------------------------- --
-- Brief fade-in / fade-out credits card, ~1.5s, then calls onDone.
function Library:_playIntro(onDone)
    local splash = create("Frame", {
        Name = "Intro",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(320, 90),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self._screenGui,
    })
    corner(splash, 12)
    local splashStroke = stroke(splash, Theme.Accent, 1)
    splashStroke.Transparency = 1

    local titleLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 22),
        Size = UDim2.new(1, 0, 0, 24),
        Font = Enum.Font.GothamBold,
        Text = "Egg Farm",
        TextColor3 = Theme.Text,
        TextTransparency = 1,
        TextSize = 20,
        Parent = splash,
    })
    local creditsLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 48),
        Size = UDim2.new(1, 0, 0, 18),
        Font = Enum.Font.Gotham,
        Text = "Credits: zvppe",
        TextColor3 = Theme.Accent,
        TextTransparency = 1,
        TextSize = 14,
        Parent = splash,
    })

    task.spawn(function()
        -- Fade in.
        TweenService:Create(splash, SMOOTH, { BackgroundTransparency = 0.05 }):Play()
        TweenService:Create(splashStroke, SMOOTH, { Transparency = 0 }):Play()
        TweenService:Create(titleLabel, SMOOTH, { TextTransparency = 0 }):Play()
        TweenService:Create(creditsLabel, SMOOTH, { TextTransparency = 0 }):Play()

        task.wait(1.5)

        -- Fade out.
        TweenService:Create(splash, SMOOTH, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(splashStroke, SMOOTH, { Transparency = 1 }):Play()
        TweenService:Create(titleLabel, SMOOTH, { TextTransparency = 1 }):Play()
        TweenService:Create(creditsLabel, SMOOTH, { TextTransparency = 1 }):Play()

        task.wait(0.25)
        splash:Destroy()

        if onDone then
            onDone()
        end
    end)
end


--// Notifications -------------------------------------------------------- --
-- Bottom-right toast: slides / fades in, auto-dismisses after `time` seconds.
function Library:MakeNotification(title, desc, time)
    time = time or 3

    local toast = create("Frame", {
        Size = UDim2.new(1, 0, 0, 64),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(1, 20, 0, 0),  -- start off to the right
        Parent = self._notifyHolder,
    })
    corner(toast, 10)
    local toastStroke = stroke(toast, Theme.Accent, 1)
    toastStroke.Transparency = 1
    pad(toast, 12)

    -- Accent bar down the left edge.
    create("Frame", {
        Size = UDim2.new(0, 3, 1, -16),
        Position = UDim2.new(0, 0, 0, 8),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = toast,
    })

    local titleLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -10, 0, 20),
        Font = Enum.Font.GothamBold,
        Text = title or "",
        TextColor3 = Theme.Text,
        TextTransparency = 1,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = toast,
    })
    local descLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 22),
        Size = UDim2.new(1, -10, 1, -22),
        Font = Enum.Font.Gotham,
        Text = desc or "",
        TextColor3 = Theme.SubText,
        TextTransparency = 1,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Parent = toast,
    })

    task.spawn(function()
        -- Slide + fade in.
        TweenService:Create(toast, SMOOTH, {
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 0.05,
        }):Play()
        TweenService:Create(toastStroke, SMOOTH, { Transparency = 0.4 }):Play()
        TweenService:Create(titleLabel, SMOOTH, { TextTransparency = 0 }):Play()
        TweenService:Create(descLabel, SMOOTH, { TextTransparency = 0 }):Play()

        task.wait(time)

        -- Slide + fade out, then clean up.
        TweenService:Create(toast, SMOOTH, {
            Position = UDim2.new(1, 20, 0, 0),
            BackgroundTransparency = 1,
        }):Play()
        TweenService:Create(toastStroke, SMOOTH, { Transparency = 1 }):Play()
        TweenService:Create(titleLabel, SMOOTH, { TextTransparency = 1 }):Play()
        TweenService:Create(descLabel, SMOOTH, { TextTransparency = 1 }):Play()

        task.wait(0.3)
        toast:Destroy()
    end)
end


--// Teardown ------------------------------------------------------------- --
-- Destroys the GUI and disconnects every library-owned connection.
function Library:Destroy()
    for _, connection in ipairs(self._connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self._connections = {}
    if self._screenGui then
        self._screenGui:Destroy()
    end
end


-- Return a ready-to-use library instance (one ScreenGui per load), Orion-style.
return Library.new()
