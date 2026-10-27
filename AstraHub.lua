-- Galaxy edition: asset-free native UI, 740 x 500 desktop default.
--============================================================================--
--
--  Setup:
--    local Library = loadstring(game:HttpGet('YOUR_RAW_URL'))()
--    local Window  = Library:MakeWindow({ Name = 'AstraHub', SubTitle = 'by zvppe' })
--    local Tab     = Window:MakeTab({ Name = 'Main' })
--    local Section = Tab:AddSection({ Name = 'Main' })
--
--  Elements exist on BOTH sections and tabs (Tab:AddButton{...} works too).
--  Every adder takes a config table and returns a handle (methods listed).
--
--    :AddLabel(text | { Name, Expandable = false })           -> { Set(text) }
--    :AddParagraph({ Name, Content, Expandable = false })     -> { Set(content) }
--  Expandable text starts closed; handles also expose SetExpanded(bool), Expanded.
--  Its disclosure arrow rotates when opened; collapsed text has a preview.
--    :AddButton({ Name, Callback })                          -> { Set(text) }
--    :AddToggle({ Name, Default, Callback })                 -> { Set(bool), Value }
--    :AddSlider({ Name, Min, Max, Increment, Default,
--                 ValueName, Color, Callback })              -> { Set(num), Value }
--    :AddDropdown({ Name, Default, Options, Callback })
--                 -> { Set(opt), Refresh(optsArray, deleteCurrent), Value }
--    :AddMultiDropdown({ Name, Default, Options, Callback }) -> { Set(array), Value }
--    :AddBind({ Name, Default (KeyCode), Hold, Callback })   -> { Set(keycode), Value }
--    :AddTextbox({ Name, Default, TextDisappear, Callback }) -> { Set(text), Value }
--    :AddColorpicker({ Name, Default (Color3), Callback })   -> { Set(color3), Value }
--
--  Toggles/dropdowns/sliders/colorpickers fire Callback once at creation.
--  Saved controls restore their saved value instead of firing the default.
--
--  MakeWindow accepts Icon = "rbxassetid://..." (Logo is an alias), using
--  rbxassetid://134705462875606 by default. UseSplash = true is the default;
--  UseSplash = false skips the entrance card. Lua booleans are lowercase.
--  splashTip sets the splash heading; defaults to "YOUR WORKSPACE".
--  MakeWindow also accepts SaveConfig (false by default), ConfigName (defaults
--  to Name), and ConfigFolder (defaults to "AstraHub"). Config files are named
--  AstraHub_<ConfigName>.txt and contain JSON. Requires executor file functions.
--  Value controls accept Flag (unique stable ID) and SaveConfig (false by default).
--  Set SaveConfig = true on BOTH the window and each control to opt into saving.
--  All element config tables accept HoverTip = "". Nonempty tips appear above
--  the mouse after two seconds of hovering, and disappear when you leave.
--  Without Flag, IDs are generated from the tab/section/control names.
--    Library:SaveCfg() / Library:SaveConfigFile() -> success, path/error
--    Library:LoadConfig()                       -> success, error
--    Library:LoadCfg(jsonString)                 -> success, error
--  Changes auto-save after a short debounce; SaveConfig = false disables
--  automatic loading/saving. Call SaveCfg/LoadConfig for manual use.
--
--    Library:MakeNotification('Title', 'Body', 3)
--    Library:MakeNotification({ Name = 'Title', Content = 'Body', Time = 3 })
--    RightShift fades window visibility.  Library:Destroy() tears it all down.
--  Drag the bottom-right grip to resize; size stays within the screen bounds.
--  Releasing, leaving the screen, or losing client focus ends the drag.
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
local HttpService        = game:GetService("HttpService")
local TextService        = game:GetService("TextService")
local GuiService         = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local guiTitle, guiSubtitle, guiCredits

--============================================================================--
--// UI Library
--  Small Orion-like library so the setup section below reads like the
--  original script. Modern dark theme, TweenService driven animations.
--============================================================================--
local Library = {}
Library.__index = Library

--// Galaxy palette: quiet ink surfaces over violet / blue / magenta light.
local Theme = {
    Background = Color3.fromRGB(9, 7, 18),
    Panel      = Color3.fromRGB(18, 14, 32),
    PanelLight = Color3.fromRGB(30, 23, 48),
    Stroke     = Color3.fromRGB(81, 62, 115),
    Accent     = Color3.fromRGB(177, 126, 255),
    AccentDim  = Color3.fromRGB(80, 48, 126),
    Text       = Color3.fromRGB(245, 240, 255),
    SubText    = Color3.fromRGB(167, 156, 190),
    Toggle     = Color3.fromRGB(56, 43, 76),
    Hover      = Color3.fromRGB(49, 35, 73),
    Blue       = Color3.fromRGB(77, 109, 240),
    Pink       = Color3.fromRGB(213, 87, 203),
}

local FAST   = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SMOOTH = TweenInfo.new(0.21, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local POP    = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDER_GLIDE = TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local THUMB_MOTION = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TOAST_ENTER = TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local DEFAULT_ICON = "rbxassetid://87317389654710"
local ICON_ROTATION_SPEED = 8 -- Degrees per second; one full turn every 45 seconds.
local TITLE_HEIGHT = 64
local SIDEBAR_WIDTH = 176

--// Small helper for creating instances with a property table --
local function create(className, props)
    local inst = Instance.new(className)
    if inst:IsA("GuiObject") then inst.BorderSizePixel = 0 end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") then
        inst.TextTruncate = Enum.TextTruncate.AtEnd
    end
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

-- Native gradients and line icons; no external image dependencies.
local function gradient(parent, first, last, rotation)
    return create("UIGradient", {
        Color = ColorSequence.new(first, last), Rotation = rotation or 0, Parent = parent,
    })
end

local function line(parent, x, y, width, rotation, color)
    local part = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, 1.5), Rotation = rotation or 0,
        BackgroundColor3 = color or Theme.SubText, Parent = parent,
    })
    corner(part, 1)
    return part
end

local function chevron(parent, position)
    local icon = create("Frame", {
        Name = "Chevron", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = position, Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1, Parent = parent,
    })
    line(icon, 5.5, 8, 7, 45)
    line(icon, 10.5, 8, 7, -45)
    return icon
end

local function tabIcon(parent, index)
    local icon = create("Frame", {
        Name = "Icon", Size = UDim2.fromOffset(20, 20),
        Position = UDim2.new(0, 10, 0.5, -10), BackgroundTransparency = 1, Parent = parent,
    })
    local parts = {}
    local variant = (index - 1) % 3
    if variant == 0 then
        for _, point in ipairs({{5, 5}, {15, 5}, {5, 15}, {15, 15}}) do
            local tile = create("Frame", {
                Position = UDim2.fromOffset(point[1] - 3, point[2] - 3),
                Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Theme.SubText, Parent = icon,
            })
            corner(tile, 2)
            table.insert(parts, tile)
        end
    elseif variant == 1 then
        for i, y in ipairs({4, 10, 16}) do
            table.insert(parts, line(icon, 10, y, 18, 0))
            local dot = create("Frame", {
                Position = UDim2.fromOffset(i == 2 and 5 or 12, y - 2.5),
                Size = UDim2.fromOffset(5, 5), BackgroundColor3 = Theme.SubText, Parent = icon,
            })
            corner(dot, 2)
            table.insert(parts, dot)
        end
    else
        for _, edge in ipairs({{6,6,11,-45}, {14,6,11,45}, {14,14,11,-45}, {6,14,11,45}}) do
            table.insert(parts, line(icon, edge[1], edge[2], edge[3], edge[4]))
        end
    end
    return icon, parts
end

local function attachHover(lib, button, baseColor, hoverColor)
    local outline = button:FindFirstChildOfClass("UIStroke") or stroke(button)
    outline.Transparency = 0.72
    lib:_connect(button.MouseEnter, function()
        lib:_tween(button, FAST, { BackgroundColor3 = hoverColor }):Play()
        lib:_tween(outline, FAST, { Color = Theme.Accent, Transparency = 0.35 }):Play()
    end)
    lib:_connect(button.MouseLeave, function()
        lib:_tween(button, FAST, { BackgroundColor3 = baseColor }):Play()
        lib:_tween(outline, FAST, { Color = Theme.Stroke, Transparency = 0.72 }):Play()
    end)
    return outline
end

-- Constructs a fresh library instance bound to one ScreenGui.
function Library.new()
    local self = setmetatable({}, Library)
    self._connections = {}   -- library-owned connections, cleared on close
    self._tweens = {}
    self._tasks = {}
    self._notifyStack = {}    -- active notification toasts
    self.Flags = {}
    self.Folder = "AstraHub"
    self._configData = {}
    self._flagCounts = {}
    self._saveVersion = 0
    return self
end

-- Tracks a connection so the library can clean up on close.
function Library:_connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self._connections, connection)
    return connection
end

-- Use frame time for a continuous spin at the same speed on every frame rate.
function Library:_spinIcon(icon)
    local connection = self:_connect(RunService.RenderStepped, function(dt)
        icon.Rotation = (icon.Rotation + ICON_ROTATION_SPEED * dt) % 360
    end)
    self:_connect(icon.Destroying, function()
        connection:Disconnect()
    end)
end

-- Cancel only overlapping property animations so hover and movement cooperate.
function Library:_cancelTweens(target, goals)
    local cancel = {}
    for tween, record in pairs(self._tweens) do
        if record.Target == target then
            local overlaps = goals == nil
            if goals then
                for property in pairs(goals) do
                    if record.Goals[property] ~= nil then overlaps = true; break end
                end
            end
            if overlaps then table.insert(cancel, tween) end
        end
    end
    for _, tween in ipairs(cancel) do
        local record = self._tweens[tween]
        if record then record.Connection:Disconnect(); self._tweens[tween] = nil end
        tween:Cancel()
    end
end

function Library:_tween(target, info, goals)
    self:_cancelTweens(target, goals)
    local tween = TweenService:Create(target, info, goals)
    local record = { Target = target, Goals = goals }
    record.Connection = tween.Completed:Connect(function()
        record.Connection:Disconnect()
        self._tweens[tween] = nil
    end)
    self._tweens[tween] = record
    return tween
end

function Library:_delay(seconds, callback)
    local thread
    thread = task.delay(seconds, function()
        self._tasks[thread] = nil
        if not self._destroyed then callback() end
    end)
    self._tasks[thread] = true
    return thread
end

-- One inexpensive, throttled clock drives the decorative starfield.
function Library:_galaxy(parent)
    local sky = create("Frame", {
        Name = "Galaxy", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), ClipsDescendants = true,
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 1, Parent = parent,
    })
    corner(sky, 16)
    gradient(sky, Color3.fromRGB(30, 46, 120), Color3.fromRGB(109, 28, 113), 12)
    local shade = create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Background, Parent = sky,
    })
    corner(shade, 16)
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 0.03),
            NumberSequenceKeypoint.new(0.7, 0.38), NumberSequenceKeypoint.new(1, 0.86),
        }), Parent = shade,
    })
    local stars, random = {}, Random.new(427)
    for index = 1, 48 do
        local size = index % 9 == 0 and 2.5 or random:NextNumber(1, 1.8)
        local star = create("Frame", {
            Name = "Star", Size = UDim2.fromOffset(size, size),
            BackgroundColor3 = index % 3 == 0 and Theme.Accent or Theme.Text,
            BackgroundTransparency = 0.65, Parent = sky,
        })
        corner(star, 3)
        stars[index] = { Object = star, X = random:NextNumber(), Y = random:NextNumber(),
            Speed = random:NextNumber(0.003, 0.009), Phase = random:NextNumber(0, math.pi * 2) }
        star.Position = UDim2.fromScale(stars[index].X, stars[index].Y)
    end
    local elapsed, accumulator = 0, 0
    self:_connect(RunService.RenderStepped, function(dt)
        if not parent.Visible or self._windowWantedVisible == false or not self._screenGui.Enabled or self._minimized then return end
        elapsed, accumulator = elapsed + dt, accumulator + dt
        if accumulator < 1 / 30 then return end
        accumulator = 0
        for _, star in ipairs(stars) do
            star.Object.Position = UDim2.fromScale(
                (star.X + math.sin(elapsed * 0.09 + star.Phase) * 0.012) % 1,
                (star.Y - elapsed * star.Speed) % 1)
            star.Object.BackgroundTransparency = 0.48 + 0.28 * (0.5 + 0.5 * math.sin(elapsed * 0.8 + star.Phase))
        end
    end)
    return sky
end

-- A fixed sidebar identity card. Thumbnail work never blocks window creation.
function Library:_makeProfile(rail)
    local username = LocalPlayer.Name
    local card = create("Frame", {
        Name = "PlayerProfile", AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 70),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.12, Parent = rail,
    })
    corner(card, 10)
    local rim = stroke(card, Theme.Accent)
    rim.Transparency = 0.68
    gradient(rim, Theme.Blue, Theme.Accent, 35)
    local portrait = create("TextLabel", {
        Name = "AvatarPlaceholder", Position = UDim2.fromOffset(9, 10), Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = Theme.AccentDim, Text = string.upper(string.sub(username, 1, 1)),
        Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Theme.Text, Parent = card,
    })
    corner(portrait, 16)
    stroke(portrait, Theme.Accent).Transparency = 0.42
    local avatar = create("ImageLabel", {
        Name = "Avatar", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Image = "", ScaleType = Enum.ScaleType.Crop, Parent = portrait,
    })
    corner(avatar, 16)
    create("TextLabel", {
        Name = "Username", Position = UDim2.fromOffset(49, 10), Size = UDim2.new(1, -58, 0, 33),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, Text = username,
        TextSize = 11, TextColor3 = Theme.Text, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    create("Frame", {
        Position = UDim2.new(0, 10, 1, -22), Size = UDim2.new(1, -20, 0, 1),
        BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.6, Parent = card,
    })
    create("TextLabel", {
        Name = "VisibilityHint", Position = UDim2.new(0, 8, 1, -17), Size = UDim2.new(1, -16, 0, 12),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, Text = "RSHIFT / SHOW-HIDE",
        TextSize = 8, TextColor3 = Theme.SubText, Parent = card,
    })

    local function requestAvatar(attempt)
        if self._destroyed or not avatar:IsDescendantOf(self._screenGui) then return end
        local thread
        thread = task.defer(function()
            local ok, content, ready = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId,
                    Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            self._tasks[thread] = nil
            if self._destroyed or not avatar:IsDescendantOf(self._screenGui) then return end
            if ok and ready and type(content) == "string" and content ~= "" then
                avatar.Image = content
                avatar.ImageTransparency = 1
                portrait.TextTransparency = 1
                self:_tween(avatar, SMOOTH, { ImageTransparency = 0 }):Play()
            elseif attempt < 3 then
                self:_delay(0.8, function() requestAvatar(attempt + 1) end)
            end
        end)
        self._tasks[thread] = true
    end
    requestAvatar(1)
end

--// Hover descriptions --------------------------------------------------- --
function Library:_hideHoverTip()
    self._hoverVersion = (self._hoverVersion or 0) + 1
    self._hoverTarget = nil
    if self._hoverTip then self._hoverTip.Visible = false end
end

function Library:_canShowHoverTip(row)
    if self._destroyed or self._windowWantedVisible == false or not row.Parent or not self._screenGui.Enabled then return false end
    -- AbsolutePosition uses the core-UI origin; mouse input includes the top bar.
    local pointer = UserInputService:GetMouseLocation()
    local inset = GuiService:GetGuiInset()
    local mouse = Vector2.new(pointer.X - inset.X, pointer.Y - inset.Y)
    local function contains(object)
        local position, size = object.AbsolutePosition, object.AbsoluteSize
        return mouse.X >= position.X and mouse.X <= position.X + size.X
            and mouse.Y >= position.Y and mouse.Y <= position.Y + size.Y
    end
    if not contains(row) then return false end
    local ancestor = row
    while ancestor and ancestor ~= self._screenGui do
        if ancestor:IsA("GuiObject") then
            if not ancestor.Visible then return false end
            if ancestor.ClipsDescendants and not contains(ancestor) then return false end
        end
        ancestor = ancestor.Parent
    end
    return ancestor == self._screenGui
end

function Library:_positionHoverTip()
    local tip = self._hoverTip
    local pointer = UserInputService:GetMouseLocation()
    local inset = GuiService:GetGuiInset()
    local origin = self._screenGui.AbsolutePosition
    local mouse = Vector2.new(pointer.X - inset.X - origin.X, pointer.Y - inset.Y - origin.Y)
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or self._screenGui.AbsoluteSize
    local width, height = tip.Size.X.Offset, tip.Size.Y.Offset
    local x = math.clamp(mouse.X + 12, 8, math.max(8, viewport.X - width - 8))
    local y = math.clamp(mouse.Y - 12, height + 8, math.max(height + 8, viewport.Y - 8))
    tip.Position = UDim2.fromOffset(x, y)
end

function Library:_attachHoverTip(row, cfg)
    local text = type(cfg.HoverTip) == "string" and cfg.HoverTip or ""
    if text == "" then return end
    if not self._hoverTip then
        local tip = create("TextLabel", {
            Name = "HoverTip",
            AnchorPoint = Vector2.new(0, 1),
            Size = UDim2.fromOffset(1, 1),
            BackgroundColor3 = Theme.PanelLight,
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            Text = "",
            TextSize = 12,
            TextColor3 = Theme.Text,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Active = false,
            Selectable = false,
            Visible = false,
            ZIndex = 1000,
            Parent = self._screenGui,
        })
        corner(tip, 6)
        stroke(tip)
        pad(tip, 8)
        self._hoverTip = tip
        self:_connect(RunService.RenderStepped, function()
            if not self._hoverTarget then return end
            if not self:_canShowHoverTip(self._hoverTarget) then
                self:_hideHoverTip()
            elseif tip.Visible then
                self:_positionHoverTip()
            end
        end)
    end
    self:_connect(row.MouseEnter, function()
        self:_hideHoverTip()
        self._hoverTarget = row
        local version = self._hoverVersion
        self:_delay(2, function()
            if version ~= self._hoverVersion or self._hoverTarget ~= row then return end
            if not self:_canShowHoverTip(row) then
                self:_hideHoverTip()
                return
            end
            local camera = Workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or self._screenGui.AbsoluteSize
            local width = math.max(40, math.min(300, viewport.X - 32))
            local bounds = TextService:GetTextSize(text, 12, Enum.Font.Gotham,
                Vector2.new(width - 16, 100000))
            local tip = self._hoverTip
            tip.Text = text
            tip.Size = UDim2.fromOffset(math.ceil(bounds.X) + 16, math.ceil(bounds.Y) + 16)
            self:_positionHoverTip()
            tip.Visible = true
            tip.TextTransparency = 1
            self:_tween(tip, FAST, { TextTransparency = 0 }):Play()
        end)
    end)
    local function leave()
        if self._hoverTarget == row then self:_hideHoverTip() end
    end
    self:_connect(row.MouseLeave, leave)
    self:_connect(row.Destroying, leave)
end

--// Configs -------------------------------------------------------------- --
local function configFileName(name)
    local safe = tostring(name or "Script"):gsub('[%c<>:"/\\|?*]', "_")
    safe = safe:gsub("%s+", "_"):gsub("[%. ]+$", "")
    return "AstraHub_" .. (safe ~= "" and safe or "Script") .. ".txt"
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function packFlag(handle)
    local value = handle.Value
    if value == nil then
        return { __AstraHubNil = true }
    elseif handle.Type == "Colorpicker" then
        return { R = value.R * 255, G = value.G * 255, B = value.B * 255 }
    elseif handle.Type == "Bind" then
        return value.Name
    end
    return value
end

local function unpackFlag(handle, value)
    local kind = handle.Type
    if type(value) == "table" and value.__AstraHubNil == true then
        assert(kind == "Bind" or kind == "Dropdown", "This control cannot be empty")
        return nil
    elseif kind == "Colorpicker" then
        assert(type(value) == "table", "Expected packed RGB color")
        for _, channel in ipairs({ "R", "G", "B" }) do
            assert(finite(value[channel]) and value[channel] >= 0 and value[channel] <= 255,
                "Invalid color channel " .. channel)
        end
        return Color3.fromRGB(value.R, value.G, value.B)
    elseif kind == "Bind" then
        assert(type(value) == "string", "Expected a key name")
        local key = Enum.KeyCode[value]
        assert(key ~= nil, "Unknown key " .. value)
        return key
    elseif kind == "Toggle" then
        assert(type(value) == "boolean", "Expected a boolean")
    elseif kind == "Slider" then
        assert(finite(value), "Expected a finite number")
    elseif kind == "Textbox" then
        assert(type(value) == "string", "Expected text")
    elseif kind == "Dropdown" then
        assert(type(value) == "string" or finite(value), "Expected an option")
    elseif kind == "MultiDropdown" then
        assert(type(value) == "table", "Expected an option array")
        for index, option in pairs(value) do
            assert(type(index) == "number" and index >= 1 and index % 1 == 0
                and index <= #value, "Expected an option array")
            assert(type(option) == "string" or finite(option), "Invalid option")
        end
    end
    return value
end

function Library:GetConfigPath(name)
    return self.Folder .. "/" .. configFileName(name or self.ConfigName)
end

function Library:SaveCfg(name)
    local ok, result = pcall(function()
        assert(typeof(writefile) == "function", "writefile is unavailable")
        assert(typeof(isfolder) == "function" and typeof(makefolder) == "function",
            "Folder file functions are unavailable")
        if not isfolder(self.Folder) then
            makefolder(self.Folder)
        end
        -- Preserve not-yet-created controls when saving during setup.
        local data = {}
        for flag, value in pairs(self._configData) do data[flag] = value end
        for flag, handle in pairs(self.Flags) do
            if handle.Save then data[flag] = packFlag(handle) else data[flag] = nil end
        end
        local path = self:GetConfigPath(name)
        writefile(path, HttpService:JSONEncode(data))
        self._configData = data
        self._configLoadFailed = false
        self._configDirty = false
        return path
    end)
    if not ok then warn("AstraHub Config Saver - " .. tostring(result)) end
    return ok, result
end

Library.SaveConfigFile = Library.SaveCfg

function Library:_restoreFlag(flag, handle)
    local saved = self._configData[flag]
    if saved == nil or not handle.Save then return false end
    local previous = self._loadingConfig
    self._loadingConfig = true
    local ok, err = pcall(function()
        local value = unpackFlag(handle, saved)
        handle.Set(value)
    end)
    self._loadingConfig = previous
    if not ok then
        self._configLoadFailed = true
        warn("AstraHub Config Loader - Could not restore " .. flag .. ": " .. tostring(err))
    end
    return ok, err
end

function Library:LoadCfg(config)
    local ok, data = pcall(function()
        local decoded = HttpService:JSONDecode(config)
        assert(type(decoded) == "table", "Expected a config object")
        for flag in pairs(decoded) do
            assert(type(flag) == "string", "Expected string flag names")
        end
        return decoded
    end)
    if not ok then
        self._configLoadFailed = true
        warn("AstraHub Config Loader - " .. tostring(data))
        return false, data
    end
    self._configData = data
    self._saveVersion = self._saveVersion + 1
    self._configDirty = false
    self._configLoadFailed = false
    local errors = {}
    for flag, handle in pairs(self.Flags) do
        if handle.Save and data[flag] ~= nil then
            local restored, err = self:_restoreFlag(flag, handle)
            if not restored then table.insert(errors, flag .. ": " .. tostring(err)) end
        end
    end
    if #errors > 0 then
        self._configLoadFailed = true
        return false, table.concat(errors, "; ")
    end
    return true
end

function Library:LoadConfig(name)
    local ok, config = pcall(function()
        assert(typeof(isfile) == "function" and typeof(readfile) == "function",
            "Read file functions are unavailable")
        local path = self:GetConfigPath(name)
        assert(isfile(path), "Config does not exist: " .. path)
        return readfile(path)
    end)
    if not ok then
        self._configLoadFailed = true
        warn("AstraHub Config Loader - " .. tostring(config))
        return false, config
    end
    return self:LoadCfg(config)
end

function Library:_queueSave()
    if not self.SaveConfig or self._loadingConfig or self._destroyed or self._configLoadFailed then
        return
    end
    self._configDirty = true
    self._saveVersion = self._saveVersion + 1
    local version = self._saveVersion
    self:_delay(0.35, function()
        if self.SaveConfig and not self._destroyed and not self._configLoadFailed
            and self._configDirty and version == self._saveVersion then
            self:SaveCfg()
        end
    end)
end

function Library:_registerFlag(cfg, handle, kind, scope)
    local flag = cfg.Flag
    if flag == nil then
        local base = scope .. "/" .. kind .. ":" .. tostring(cfg.Name or kind)
        self._flagCounts[base] = (self._flagCounts[base] or 0) + 1
        flag = base .. "#" .. self._flagCounts[base]
    else
        flag = tostring(flag)
    end
    assert(not self.Flags[flag], "Duplicate config Flag: " .. flag)
    handle.Flag, handle.Type = flag, kind
    handle.SaveConfig = cfg.SaveConfig == true
    handle.Save = handle.SaveConfig
    self.Flags[flag] = handle
    local originalSet = handle.Set
    handle.Set = function(first, second)
        local value = first
        if first == handle then value = second end
        originalSet(value)
        if handle.Save then self:_queueSave() end
    end
    return self:_restoreFlag(flag, handle)
end


--// Window ---------------------------------------------------------------- --
-- Builds the ScreenGui, intro splash and main window. Returns a window
-- object exposing MakeTab. Tabs may be added immediately even while the
-- intro is still playing (the main frame exists, just hidden).
function Library:MakeWindow(config)
    config = config or {}
    local title    = config.Name     or "Window"
    local subtitle = config.SubTitle or ""
    local credits = config.Credits or ""
    local icon = tostring(config.Icon or config.Logo or DEFAULT_ICON)
    if icon:match("^%d+$") then icon = "rbxassetid://" .. icon end
    self._icon = icon:match("^rbxassetid://%d+$") and icon or DEFAULT_ICON
    self._introPending = config.UseSplash ~= false
    self._splashTip = tostring(config.splashTip or "YOUR WORKSPACE")
    local wantedVisible = true
    self._windowWantedVisible = true
    self.ConfigName = config.ConfigName or title
    self.Folder = config.ConfigFolder or "AstraHub"
    self.SaveConfig = config.SaveConfig == true

    --// ScreenGui, with re-execute cleanup of any previous instance --
    local guiName = "Window"

    guiTitle = title
    guiSubtitle = subtitle
    guiCredits = credits
    
    
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
    self:_connect(screenGui.Destroying, function()
        self:Destroy()
    end)

    -- Read after replacing the old GUI, so its pending changes flush first.
    if self.SaveConfig then
        if typeof(isfile) == "function" and typeof(readfile) == "function"
            and typeof(writefile) == "function" then
            local ok, exists = pcall(isfile, self:GetConfigPath())
            if ok and exists then
                self:LoadConfig()
            elseif not ok then
                self._configLoadFailed = true
                warn("AstraHub Config Loader - " .. tostring(exists))
            end
        else
            self.SaveConfig = false
            warn("AstraHub Config - File functions unavailable; automatic configs disabled")
        end
    end

    --// Notification container (bottom-right stack) --
    local notifyHolder = create("Frame", {
        Name = "Notifications",
        ZIndex = 100,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, 320, 1, -32),
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

    --// Spacious galaxy shell -------------------------------------------- --
    local mainSize = UDim2.fromOffset(740, 500)
    local main = create("CanvasGroup", {
        Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = mainSize,
        BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = screenGui,
    })
    corner(main, 16)
    self._main, self._mainSize = main, mainSize
    local surface = self:_galaxy(main)
    -- The stroke belongs to a descendant, so it fades with every other pixel.
    local rim = stroke(surface, Theme.Accent, 1)
    rim.Transparency = 0.5
    gradient(rim, Theme.Blue, Theme.Pink, 25)
    local fadeBlocker = create("TextButton", {
        Name = "FadeInputBlocker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        AutoButtonColor = false, Text = "", Active = true, Visible = false, ZIndex = 100, Parent = main,
    })

    local titleBar = create("Frame", {
        Name = "TitleBar", Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
        BackgroundTransparency = 1, Active = true, ZIndex = 3, Parent = main,
    })
    local brand = create("ImageLabel", {
        Name = "GalaxyLogo", Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(42, 42),
        BackgroundTransparency = 1, Image = self._icon, ScaleType = Enum.ScaleType.Fit,
        Parent = titleBar,
    })
    self:_spinIcon(brand)
    create("TextLabel", {
        Name = "Title", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(68, 13), Size = UDim2.new(1, -166, 0, 23),
        Font = Enum.Font.GothamBold, Text = title, TextColor3 = Theme.Text, TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar,
    })
    create("TextLabel", {
        Name = "SubTitle", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(69, 36), Size = UDim2.new(1, -167, 0, 16),
        Font = Enum.Font.Gotham, Text = subtitle, TextColor3 = Theme.SubText, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar,
    })
    local separator = create("Frame", {
        Position = UDim2.new(0, 18, 1, -1), Size = UDim2.new(1, -36, 0, 1),
        BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.7, Parent = titleBar,
    })
    gradient(separator, Theme.Blue, Theme.Pink)

    local function makeControl(name, offset, close)
        local button = create("TextButton", {
            Name = name, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, offset, 0.5, 0), Size = UDim2.fromOffset(30, 30),
            BackgroundColor3 = Theme.PanelLight, BackgroundTransparency = 0.25,
            AutoButtonColor = false, Text = "", Parent = titleBar,
        })
        corner(button, 9)
        attachHover(self, button, Theme.PanelLight, close and Color3.fromRGB(126, 45, 86) or Theme.Hover)
        line(button, 15, 15, 12, close and 45 or 0, Theme.Text)
        if close then line(button, 15, 15, 12, -45, Theme.Text) end
        local scale = create("UIScale", { Parent = button })
        self:_connect(button.MouseEnter, function() self:_tween(scale, POP, { Scale = 1.08 }):Play() end)
        self:_connect(button.MouseLeave, function() self:_tween(scale, SMOOTH, { Scale = 1 }):Play() end)
        return button
    end
    local closeBtn = makeControl("Close", -18, true)
    local minimizeBtn = makeControl("Minimize", -57, false)

    local body = create("Frame", {
        Name = "Body", Position = UDim2.fromOffset(0, TITLE_HEIGHT),
        Size = UDim2.new(1, 0, 1, -TITLE_HEIGHT), BackgroundTransparency = 1,
        ZIndex = 3, Parent = main,
    })
    local rail = create("Frame", {
        Name = "Navigation", Position = UDim2.fromOffset(12, 12),
        Size = UDim2.new(0, SIDEBAR_WIDTH - 18, 1, -24),
        BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.32, Parent = body,
    })
    corner(rail, 12)
    stroke(rail).Transparency = 0.7
    create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 14),
        Size = UDim2.new(1, -28, 0, 14), Text = "WORKSPACE", Font = Enum.Font.GothamBold,
        TextSize = 9, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
        Parent = rail,
    })
    local sidebar = create("ScrollingFrame", {
        Name = "Sidebar", Position = UDim2.fromOffset(12, 50),
        Size = UDim2.new(1, -24, 1, -140), BackgroundTransparency = 1,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Accent, Parent = rail,
    })
    local tabList = create("Frame", {
        Name = "Tabs", Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Parent = sidebar,
    })
    -- Keep the first/last tab strokes inside the scrolling viewport.
    create("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = tabList,
    })
    create("UIListLayout", {
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList,
    })
    local indicator = create("Frame", {
        Name = "SelectedTab", Position = UDim2.fromOffset(1, 15), Size = UDim2.fromOffset(3, 24),
        BackgroundColor3 = Theme.Accent, ZIndex = 4, Parent = sidebar,
    })
    corner(indicator, 2)
    gradient(indicator, Theme.Accent, Theme.Pink, 90)
    self:_makeProfile(rail)
    local content = create("Frame", {
        Name = "Content", Position = UDim2.fromOffset(SIDEBAR_WIDTH + 4, 12),
        Size = UDim2.new(1, -SIDEBAR_WIDTH - 18, 1, -24), BackgroundTransparency = 1,
        ClipsDescendants = true, Parent = body,
    })

    -- One active control drag, terminated on release anywhere, hide, tab change,
    -- focus loss, leaving the viewport, and teardown. No per-drag connections.
    local controlDrag
    local function stopControlDrag()
        local drag = controlDrag
        controlDrag = nil
        if drag and drag.Finish then drag.Finish() end
    end
    self._stopControlDrag = stopControlDrag
    local function bindDrag(grabber, onMove, onBegin, onFinish)
        self:_connect(grabber.InputBegan, function(input)
            if not wantedVisible or not main.Visible or not screenGui.Enabled then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            stopControlDrag()
            self:_hideHoverTip()
            controlDrag = { Input = input, Move = onMove, Finish = onFinish, Grabber = grabber,
                Touch = input.UserInputType == Enum.UserInputType.Touch }
            if onBegin then onBegin() end
            onMove(input)
        end)
    end
    self:_connect(UserInputService.InputChanged, function(input)
        if not controlDrag then return end
        if (controlDrag.Touch and input == controlDrag.Input)
            or (not controlDrag.Touch and input.UserInputType == Enum.UserInputType.MouseMovement) then
            controlDrag.Move(input)
        end
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if controlDrag and (input == controlDrag.Input
            or input.UserInputType == Enum.UserInputType.MouseButton1) then stopControlDrag() end
    end)
    self:_connect(UserInputService.WindowFocusReleased, stopControlDrag)
    self:_connect(RunService.RenderStepped, function()
        if not controlDrag then return end
        local pointer = UserInputService:GetMouseLocation()
        local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or screenGui.AbsoluteSize
        if not controlDrag.Grabber:IsDescendantOf(screenGui)
            or controlDrag.Input.UserInputState == Enum.UserInputState.End
            or controlDrag.Input.UserInputState == Enum.UserInputState.Cancel
            or (not controlDrag.Touch and (not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                or pointer.X < 0 or pointer.Y < 0 or pointer.X >= viewport.X or pointer.Y >= viewport.Y)) then
            stopControlDrag()
        end
    end)

    --====================================================================--
    -- attachElements: installs every element adder onto `target`, parenting
    -- the created rows into `container`. Used by both tabs (container = page)
    -- and sections (container = the section frame) so tab-level and section
    -- elements share a single implementation.
    --====================================================================--
    local function attachElements(target, container)
        -- `self` inside the colon-methods below is the target (tab/section),
        -- so keep a reference to the library instance for tracked connections.
        local lib = self

        -- Labels and paragraphs share the same optional animated disclosure.
        local function addTextPanel(cfg, paragraph)
            local expandable = cfg.Expandable == true
            local padding = 12
            local headerH = 40
            local panel = create("Frame", {
                Name = paragraph and "Paragraph" or "Label",
                Size = UDim2.new(1, 0, 0, expandable and headerH or 0),
                AutomaticSize = expandable and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Panel,
                BorderSizePixel = 0,
                ClipsDescendants = expandable,
                Parent = container,
            })
            corner(panel, 10)
            panel.BackgroundTransparency = 0.28
            stroke(panel).Transparency = 0.78
            lib:_attachHoverTip(panel, cfg)
            local content = panel
            local header, arrow
            if expandable then
                header = create("TextButton", {
                    Name = "Expand",
                    Size = UDim2.new(1, 0, 0, headerH),
                    BackgroundTransparency = 1,
                    AutoButtonColor = false,
                    Text = "",
                    Parent = panel,
                })
                arrow = create("TextLabel", {
                    Name = "Arrow",
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 10, 0.5, 0),
                    Size = UDim2.fromOffset(18, 18),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold,
                    Text = ">",
                    TextSize = 18,
                    TextColor3 = Theme.SubText,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Rotation = 0,
                    Parent = header,
                })
                create("TextLabel", {
                    Name = "Preview", BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -48, 1, 0),
                    Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
                    Text = cfg.Name or (paragraph and "Details" or "Label"),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
                })
                content = create("Frame", {
                    Name = "TextContent",
                    Position = UDim2.new(0, padding, 0, headerH + padding),
                    Size = UDim2.new(1, -2 * padding, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.None,
                    BackgroundTransparency = 1,
                    Parent = panel,
                })
            else
                pad(panel, padding)
            end
            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = content,
            })
            local textLabels = {}
            if paragraph then
                local title = create("TextLabel", {
                    Name = "Title",
                    LayoutOrder = 1,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, expandable and 0 or 18),
                    AutomaticSize = Enum.AutomaticSize.None,
                    Font = Enum.Font.GothamBold,
                    Text = cfg.Name or "",
                    TextColor3 = Theme.Text,
                    TextSize = 14,
                    TextWrapped = expandable,
                    TextTransparency = expandable and 1 or 0,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = content,
                })
                table.insert(textLabels, title)
            end
            local body = create("TextLabel", {
                Name = "Body",
                LayoutOrder = 2,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = expandable and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
                Font = Enum.Font.Gotham,
                Text = paragraph and (cfg.Content or "") or (cfg.Name or ""),
                TextColor3 = Theme.SubText,
                TextSize = 13,
                TextWrapped = true,
                TextTruncate = Enum.TextTruncate.None,
                TextTransparency = expandable and 1 or 0,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                Parent = content,
            })
            table.insert(textLabels, body)
            local handle = { Expanded = not expandable }
            handle.Set = function(first, second)
                local text = first
                if first == handle then text = second end
                body.Text = text or ""
                if header and not paragraph then header.Preview.Text = body.Text end
            end
            if expandable then
                local sizeTween, arrowTween
                local textTweens = {}
                local function measureText()
                    local width = panel.AbsoluteSize.X - 2 * padding
                    if width <= 0 then return 0 end
                    local height = 0
                    for index, label in ipairs(textLabels) do
                        local bounds = TextService:GetTextSize(label.Text, label.TextSize,
                            label.Font, Vector2.new(width, 100000))
                        local textHeight = label.Text == "" and 0 or math.ceil(bounds.Y) + 2
                        label.Size = UDim2.new(1, 0, 0, textHeight)
                        height = height + textHeight + (index > 1 and 4 or 0)
                    end
                    content.Size = UDim2.new(1, -2 * padding, 0, height)
                    return height
                end
                local function resize()
                    local textHeight = measureText()
                    if sizeTween then sizeTween:Cancel() end
                    local height = headerH
                    if handle.Expanded then
                        height = height + textHeight + 2 * padding
                    end
                    sizeTween = lib:_tween(panel, SMOOTH, { Size = UDim2.new(1, 0, 0, height) })
                    sizeTween:Play()
                end
                handle.SetExpanded = function(first, second)
                    local open = first
                    if first == handle then open = second end
                    handle.Expanded = open == true
                    resize()
                    arrow.Text = ">"
                    if arrowTween then arrowTween:Cancel() end
                    arrowTween = lib:_tween(arrow, SMOOTH, {
                        TextColor3 = handle.Expanded and Theme.Accent or Theme.SubText,
                        Rotation = handle.Expanded and 90 or 0,
                    })
                    arrowTween:Play()
                    for index, label in ipairs(textLabels) do
                        if textTweens[index] then textTweens[index]:Cancel() end
                        textTweens[index] = lib:_tween(label, SMOOTH, {
                            TextTransparency = handle.Expanded and 0 or 1,
                        })
                        textTweens[index]:Play()
                    end
                end
                header.Activated:Connect(function()
                    handle.SetExpanded(not handle.Expanded)
                end)
                -- Measure directly: clipped automatic layouts may report zero
                -- height. Remeasure when text changes or a hidden tab is shown.
                for _, label in ipairs(textLabels) do
                    lib:_connect(label:GetPropertyChangedSignal("Text"), resize)
                end
                local lastWidth = panel.AbsoluteSize.X
                lib:_connect(panel:GetPropertyChangedSignal("AbsoluteSize"), function()
                    local width = panel.AbsoluteSize.X
                    if width ~= lastWidth then
                        lastWidth = width
                        resize()
                    end
                end)
            end
            return handle
        end

        --// Label ------------------------------------------------------- --
        function target:AddLabel(cfg)
            if type(cfg) == "string" then cfg = { Name = cfg } end
            return addTextPanel(cfg or {}, false)
        end

        --// Paragraph --------------------------------------------------- --
        function target:AddParagraph(cfg)
            return addTextPanel(cfg or {}, true)
        end

        --// Button ------------------------------------------------------ --
        function target:AddButton(cfg)
            cfg = cfg or {}

            local btn = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = Theme.PanelLight,
                AutoButtonColor = false,
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Button",
                TextColor3 = Theme.Text,
                TextSize = 14,
                Parent = container,
            })
            corner(btn, 10)
            lib:_attachHoverTip(btn, cfg)
            attachHover(lib, btn, Theme.PanelLight, Theme.Hover)
            btn.TextXAlignment = Enum.TextXAlignment.Left
            pad(btn, 13)
            local arrow = chevron(btn, UDim2.new(1, -3, 0.5, 0))
            arrow.Rotation = -90
            local scale = create("UIScale", { Parent = btn })
            lib:_connect(btn.MouseEnter, function() lib:_tween(scale, POP, { Scale = 1.015 }):Play() end)
            lib:_connect(btn.MouseLeave, function() lib:_tween(scale, SMOOTH, { Scale = 1 }):Play() end)
            local pressVersion = 0
            btn.MouseButton1Click:Connect(function()
                pressVersion = pressVersion + 1
                local version = pressVersion
                lib:_tween(btn, FAST, { BackgroundColor3 = Theme.AccentDim }):Play()
                lib:_tween(scale, FAST, { Scale = 0.98 }):Play()
                lib:_delay(0.10, function()
                    if version ~= pressVersion or not btn.Parent then return end
                    lib:_tween(scale, POP, { Scale = 1 }):Play()
                    lib:_tween(btn, FAST, { BackgroundColor3 = Theme.PanelLight }):Play()
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
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = Theme.PanelLight,
                BorderSizePixel = 0,
                Parent = container,
            })
            corner(row, 10)
            row.BackgroundTransparency = 0.12
            attachHover(lib, row, Theme.PanelLight, Theme.Hover)
            lib:_attachHoverTip(row, cfg)
            pad(row, 12)

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
                Size = UDim2.fromOffset(46, 24),
                BackgroundColor3 = state and Theme.Accent or Theme.Toggle,
                AutoButtonColor = false,
                Text = "",
                Parent = row,
            })
            corner(track, 12)
            local trackScale = create("UIScale", { Parent = track })
            local trackRim = stroke(track, Theme.Accent)
            trackRim.Transparency = state and 0.38 or 0.85
            local trackGradient = gradient(track, Color3.new(1, 1, 1), Color3.fromRGB(205, 155, 255), 20)
            local hovered = false
            local function resizeTrack()
                lib:_tween(trackScale, POP, { Scale = hovered and 1.1 or 1 }):Play()
            end
            lib:_connect(row.MouseEnter, function() hovered = true; resizeTrack() end)
            lib:_connect(row.MouseLeave, function() hovered = false; resizeTrack() end)

            local knob = create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                Size = UDim2.fromOffset(18, 18),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                Parent = track,
            })
            corner(knob, 9)

            local handle = { Value = state }

            local function render()
                lib:_tween(track, FAST, {
                    BackgroundColor3 = state and Theme.Accent or Theme.Toggle,
                }):Play()
                lib:_tween(trackRim, FAST, { Transparency = state and 0.38 or 0.85 }):Play()
                lib:_tween(knob, POP, {
                    Position = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                }):Play()
            end

            local function setState(newState, fire)
                state = newState and true or false
                handle.Value = state
                render()
                if handle.Save then lib:_queueSave() end
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
            if not lib:_registerFlag(cfg, handle, "Toggle", target._configScope) and cfg.Callback then
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
                Size = UDim2.new(1, 0, 0, 66),
                BackgroundColor3 = Theme.PanelLight,
                BorderSizePixel = 0,
                Parent = container,
            })
            corner(row, 10)
            row.BackgroundTransparency = 0.12
            attachHover(lib, row, Theme.PanelLight, Theme.Hover)
            lib:_attachHoverTip(row, cfg)

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
                Position = UDim2.new(0, 17, 0, 46),
                Size = UDim2.new(1, -34, 0, 6),
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
            gradient(fill, fillColor, fillColor:Lerp(Color3.new(1, 1, 1), 0.3))
            local thumb = create("TextButton", {
                Name = "Thumb", AutoButtonColor = false, Text = "", ZIndex = 3, AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(alphaFor(value), 0, 0.5, 0), Size = UDim2.fromOffset(14, 14),
                BackgroundColor3 = Theme.Text, Parent = track,
            })
            corner(thumb, 7)
            local halo = stroke(thumb, fillColor, 3)
            halo.Transparency = 0.65
            local thumbScale = create("UIScale", { Parent = thumb })
            local catcher = create("TextButton", {
                Name = "SliderHitArea", ZIndex = 2, Position = UDim2.new(0, -6, 0.5, -15),
                Size = UDim2.new(1, 12, 0, 30), BackgroundTransparency = 1,
                AutoButtonColor = false, Text = "", Parent = track,
            })
            local hovering, dragging = false, false
            local function emphasize()
                lib:_tween(thumbScale, THUMB_MOTION, { Scale = dragging and 1.55 or (hovering and 1.3 or 1) }):Play()
                lib:_tween(halo, FAST, { Transparency = (hovering or dragging) and 0.2 or 0.65 }):Play()
                lib:_tween(readout, FAST, { TextColor3 = (hovering or dragging) and Theme.Accent or Theme.SubText }):Play()
            end
            lib:_connect(thumb.MouseEnter, function() hovering = true; emphasize() end)
            lib:_connect(thumb.MouseLeave, function() hovering = false; emphasize() end)

            local handle = { Value = value }

            -- Applies a new value: updates fill + readout, fires the callback
            -- only when the stepped value actually changes. Pointer input and
            -- Set both glide visually while Value and callbacks stay immediate.
            local function applyValue(newValue, live, fireCallback)
                newValue = snap(newValue)
                local changed = (newValue ~= value)
                value = newValue
                handle.Value = value
                readout.Text = formatValue(value)
                -- The logical value is immediate; only the visual thumb/fill trail.
                -- Repeated pointer samples at the same snapped value do not restart motion.
                if changed or not live then
                    lib:_tween(fill, SLIDER_GLIDE, { Size = UDim2.new(alphaFor(value), 0, 1, 0) }):Play()
                    lib:_tween(thumb, SLIDER_GLIDE, { Position = UDim2.new(alphaFor(value), 0, 0.5, 0) }):Play()
                end
                if changed and handle.Save then lib:_queueSave() end
                if fireCallback and (changed or lib._loadingConfig) and cfg.Callback then
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

            local function moveSlider(input)
                applyValue(valueFromX(input.Position.X), true, true)
            end
            local function startSlider()
                dragging = true
                emphasize()
            end
            local function finishSlider()
                dragging = false
                local mouse, inset = UserInputService:GetMouseLocation(), GuiService:GetGuiInset()
                local position, size = thumb.AbsolutePosition, thumb.AbsoluteSize
                hovering = mouse.X - inset.X >= position.X and mouse.X - inset.X <= position.X + size.X
                    and mouse.Y - inset.Y >= position.Y and mouse.Y - inset.Y <= position.Y + size.Y
                emphasize()
            end
            bindDrag(catcher, moveSlider, startSlider, finishSlider)
            bindDrag(thumb, moveSlider, startSlider, finishSlider)

            handle.Set = function(v)
                applyValue(v, false, true)
            end

            -- Fire once at creation with the default value.
            if not lib:_registerFlag(cfg, handle, "Slider", target._configScope) and cfg.Callback then
                cfg.Callback(value)
            end

            return handle
        end

        --// Dropdowns: shared visual shell, original selection semantics ---- --
        local function dropdownShell(cfg)
            local headerH, optionH = 58, 34
            local panel = create("Frame", {
                Name = "Dropdown", Size = UDim2.new(1, 0, 0, headerH),
                BackgroundColor3 = Theme.PanelLight, BackgroundTransparency = 0.12,
                ClipsDescendants = true, Parent = container,
            })
            corner(panel, 10)
            local outline = attachHover(lib, panel, Theme.PanelLight, Theme.Hover)
            lib:_attachHoverTip(panel, cfg)
            local header = create("TextButton", {
                Name = "Header", Size = UDim2.new(1, 0, 0, headerH),
                BackgroundTransparency = 1, AutoButtonColor = false, Text = "", Parent = panel,
            })
            create("TextLabel", {
                BackgroundTransparency = 1, Position = UDim2.fromOffset(13, 9),
                Size = UDim2.new(1, -52, 0, 16), Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Select", TextColor3 = Theme.SubText, TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
            })
            local summary = create("TextLabel", {
                Name = "Selection", BackgroundTransparency = 1, Position = UDim2.fromOffset(13, 28),
                Size = UDim2.new(1, -52, 0, 20), Font = Enum.Font.GothamMedium,
                Text = "None", TextColor3 = Theme.Text, TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
            })
            local arrow = chevron(header, UDim2.new(1, -24, 0.5, 0))
            local group = create("CanvasGroup", {
                Name = "OptionsReveal", Position = UDim2.fromOffset(8, headerH),
                Size = UDim2.new(1, -16, 0, 0), BackgroundTransparency = 1,
                GroupTransparency = 1, Visible = false, Parent = panel,
            })
            local holder = create("ScrollingFrame", {
                Name = "Options", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 2,
                ScrollBarImageColor3 = Theme.Accent, Parent = group,
            })
            local holderPad = pad(holder, 2)
            holderPad.PaddingRight = UDim.new(0, 5)
            create("UIListLayout", {
                Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder,
            })
            local shell = { Panel = panel, Header = header, Holder = holder, Summary = summary,
                Expanded = false, Count = 0, Version = 0 }
            function shell:Resize()
                local optionsH = math.min(190, self.Count * (optionH + 4) + 4)
                group.Size = UDim2.new(1, -16, 0, optionsH)
                lib:_tween(panel, SMOOTH, {
                    Size = UDim2.new(1, 0, 0, self.Expanded and headerH + optionsH + 8 or headerH),
                }):Play()
            end
            function shell:Expand(open)
                self.Expanded = open
                self.Version = self.Version + 1
                local version = self.Version
                if not open then stopControlDrag() end
                if open then group.Visible = true end
                self:Resize()
                lib:_tween(arrow, POP, { Rotation = open and 180 or 0 }):Play()
                lib:_tween(group, SMOOTH, {
                    GroupTransparency = open and 0 or 1,
                    Position = UDim2.fromOffset(8, headerH + (open and 0 or -6)),
                }):Play()
                lib:_tween(outline, FAST, { Transparency = open and 0.35 or 0.72 }):Play()
                if not open then
                    lib:_delay(0.22, function()
                        if version == self.Version then group.Visible = false end
                    end)
                end
            end
            lib:_connect(header.MouseButton1Click, function() shell:Expand(not shell.Expanded) end)
            return shell
        end

        local function optionButton(shell, option, order, isSelected, callback)
            local button = create("TextButton", {
                Name = "Option", LayoutOrder = order, Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.4,
                AutoButtonColor = false, Text = "", Parent = shell.Holder,
            })
            corner(button, 7)
            local label = create("TextLabel", {
                BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, -42, 1, 0), Font = Enum.Font.Gotham,
                Text = tostring(option), TextSize = 13, TextColor3 = Theme.SubText,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = button,
            })
            local check = create("TextLabel", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
                Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold, Text = "\u{2713}", TextSize = 16,
                TextColor3 = Theme.Accent, Parent = button,
            })
            local hovered = false
            local function paint()
                local selected = isSelected()
                lib:_tween(button, FAST, {
                    BackgroundColor3 = selected and Theme.AccentDim or (hovered and Theme.Hover or Theme.Panel),
                    BackgroundTransparency = selected and 0.2 or (hovered and 0.1 or 0.4),
                }):Play()
                lib:_tween(label, FAST, { TextColor3 = selected and Theme.Text or Theme.SubText }):Play()
                lib:_tween(check, POP, { TextTransparency = selected and 0 or 1, TextSize = selected and 16 or 10 }):Play()
            end
            -- Instance-owned signals disconnect when Refresh destroys the button.
            button.MouseEnter:Connect(function() hovered = true; paint() end)
            button.MouseLeave:Connect(function() hovered = false; paint() end)
            button.MouseButton1Click:Connect(callback)
            check.TextTransparency = isSelected() and 0 or 1
            paint()
            return { Button = button, Label = label, Check = check, Paint = paint }
        end

        function target:AddDropdown(cfg)
            cfg = cfg or {}
            local options, selected = cfg.Options or {}, cfg.Default
            local shell = dropdownShell(cfg)
            local handle = { Value = selected }
            local buttons = {}
            local function refreshLabel()
                shell.Summary.Text = selected ~= nil and tostring(selected) or "Select an option"
                for _, item in ipairs(buttons) do item.Paint() end
            end
            local function rebuild(newOptions)
                if newOptions then options = newOptions end
                for _, item in ipairs(buttons) do
                    lib:_cancelTweens(item.Button)
                    lib:_cancelTweens(item.Label)
                    lib:_cancelTweens(item.Check)
                    item.Button:Destroy()
                end
                buttons = {}
                for index, option in ipairs(options) do
                    table.insert(buttons, optionButton(shell, option, index,
                        function() return selected == option end,
                        function()
                            selected, handle.Value = option, option
                            if handle.Save then lib:_queueSave() end
                            refreshLabel()
                            shell:Expand(false)
                            if cfg.Callback then cfg.Callback(selected) end
                        end))
                end
                shell.Count = #options
                shell:Resize()
                refreshLabel()
            end
            handle.Set = function(option)
                selected, handle.Value = option, option
                refreshLabel()
                if cfg.Callback then cfg.Callback(selected) end
            end
            handle.Refresh = function(newOptions, deleteCurrent)
                if deleteCurrent then
                    selected, handle.Value = nil, nil
                    if handle.Save then lib:_queueSave() end
                end
                rebuild(newOptions)
            end
            rebuild(options)
            if not lib:_registerFlag(cfg, handle, "Dropdown", target._configScope)
                and cfg.Callback and selected ~= nil then cfg.Callback(selected) end
            return handle
        end

        function target:AddMultiDropdown(cfg)
            cfg = cfg or {}
            local options, chosen = cfg.Options or {}, {}
            for _, name in ipairs(cfg.Default or {}) do chosen[name] = true end
            local function selectedList()
                local list = {}
                for _, name in ipairs(options) do
                    if chosen[name] then table.insert(list, name) end
                end
                return list
            end
            local shell = dropdownShell(cfg)
            shell.Count = #options
            local handle, buttons = { Value = selectedList() }, {}
            local function refreshSummary()
                local list = selectedList()
                local labels = {}
                for _, option in ipairs(list) do table.insert(labels, tostring(option)) end
                shell.Summary.Text = #list > 0 and table.concat(labels, ", ") or "None selected"
                for _, item in ipairs(buttons) do item.Paint() end
            end
            for index, option in ipairs(options) do
                table.insert(buttons, optionButton(shell, option, index,
                    function() return chosen[option] == true end,
                    function()
                        chosen[option] = not chosen[option]
                        handle.Value = selectedList()
                        if handle.Save then lib:_queueSave() end
                        refreshSummary()
                        if cfg.Callback then cfg.Callback(selectedList()) end
                    end))
            end
            handle.Set = function(selectedArray)
                chosen = {}
                for _, name in ipairs(selectedArray or {}) do chosen[name] = true end
                handle.Value = selectedList()
                refreshSummary()
                if cfg.Callback then cfg.Callback(selectedList()) end
            end
            refreshSummary()
            if not lib:_registerFlag(cfg, handle, "MultiDropdown", target._configScope) and cfg.Callback then
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
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = Theme.PanelLight,
                BorderSizePixel = 0,
                Parent = container,
            })
            corner(row, 10)
            row.BackgroundTransparency = 0.12
            attachHover(lib, row, Theme.PanelLight, Theme.Hover)
            lib:_attachHoverTip(row, cfg)

            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -112, 1, 0),
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
                Size = UDim2.fromOffset(82, 28),
                BackgroundColor3 = Theme.Panel,
                AutoButtonColor = false,
                Font = Enum.Font.GothamMedium,
                Text = keyName(key),
                TextColor3 = Theme.SubText,
                TextSize = 13,
                Parent = row,
            })
            corner(chip, 6)
            attachHover(lib, chip, Theme.Panel, Theme.PanelLight)

            local handle = { Value = key }

            chip.MouseButton1Click:Connect(function()
                listening = true
                chip.Text = "..."
            end)

            lib:_connect(UserInputService.InputBegan, function(input, gameProcessed)
                if listening then
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        if input.KeyCode == Enum.KeyCode.Escape then
                            key = nil
                            handle.Value = nil
                            listening = false
                            chip.Text = "NONE"
                        
                            if handle.Save then
                                lib:_queueSave()
                            end
                        else
                            key = input.KeyCode
                            handle.Value = key
                            if handle.Save then lib:_queueSave() end
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
                lib:_connect(UserInputService.InputEnded, function(input, gameProcessed)
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

            lib:_registerFlag(cfg, handle, "Bind", target._configScope)
            return handle
        end

        --// Textbox ----------------------------------------------------- --
        function target:AddTextbox(cfg)
            cfg = cfg or {}

            local row = create("Frame", {
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = Theme.Panel,
                BorderSizePixel = 0,
                Parent = container,
            })
            corner(row, 10)
            row.BackgroundTransparency = 0.12
            attachHover(lib, row, Theme.PanelLight, Theme.Hover)
            lib:_attachHoverTip(row, cfg)

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
                Size = UDim2.new(0.6, -16, 0, 28),
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

            local handle = { Value = box.Text }

            box.Focused:Connect(function()
                lib:_tween(boxStroke, FAST, { Color = Theme.Accent }):Play()
            end)
            box.FocusLost:Connect(function(enterPressed)
                lib:_tween(boxStroke, FAST, { Color = Theme.Stroke }):Play()
                handle.Value = box.Text
                if handle.Save then lib:_queueSave() end
                if cfg.Callback then
                    cfg.Callback(box.Text, enterPressed)
                end
                if cfg.TextDisappear then
                    box.Text = ""
                end
            end)

            handle.Set = function(text)
                handle.Value = text or ""
                box.Text = handle.Value
                if cfg.Callback then cfg.Callback(handle.Value, false) end
            end
            lib:_registerFlag(cfg, handle, "Textbox", target._configScope)
            return handle
        end

        --// Colorpicker ------------------------------------------------- --
        -- Collapsed row with a swatch; expands to an SV square + hue bar.
        function target:AddColorpicker(cfg)
            cfg = cfg or {}
            local color = cfg.Default or Color3.fromRGB(255, 255, 255)
            local h, s, v = color:ToHSV()
            local expanded = false

            local headerH   = 44
            local svSize    = 142
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
            lib:_attachHoverTip(container2, cfg)
            attachHover(lib, container2, Theme.PanelLight, Theme.Hover)

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
                Size = UDim2.fromOffset(30, 22),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                Parent = header,
            })
            corner(swatch, 6)
            stroke(swatch, Theme.Stroke, 1)

            local swatchScale = create("UIScale", { Parent = swatch })
            lib:_connect(header.MouseEnter, function() lib:_tween(swatchScale, POP, { Scale = 1.1 }):Play() end)
            lib:_connect(header.MouseLeave, function() lib:_tween(swatchScale, SMOOTH, { Scale = 1 }):Play() end)
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
                if handle.Save then lib:_queueSave() end
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
                if not open then stopControlDrag() end
                lib:_tween(container2, SMOOTH, {
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
            if not lib:_registerFlag(cfg, handle, "Colorpicker", target._configScope) and cfg.Callback then
                cfg.Callback(Color3.fromHSV(h, s, v))
            end

            return handle
        end
    end


    --// Window object exposed to existing callers ------------------------- --
    local window = { _tabs = {} }
    local lib = self
    local selectedTab

    local function paintTab(tab)
        local active = selectedTab == tab
        lib:_tween(tab.Button, FAST, {
            BackgroundColor3 = active and Theme.AccentDim or (tab.Hovered and Theme.Hover or Theme.Panel),
            BackgroundTransparency = active and 0.08 or (tab.Hovered and 0.15 or 0.65),
        }):Play()
        lib:_tween(tab.Outline, FAST, { Transparency = active and 0.35 or (tab.Hovered and 0.6 or 1) }):Play()
        lib:_tween(tab.Label, FAST, { TextColor3 = active and Theme.Text or (tab.Hovered and Theme.Text or Theme.SubText) }):Play()
        lib:_tween(tab.IconScale, POP, { Scale = tab.Hovered and 1.12 or 1 }):Play()
        for _, part in ipairs(tab.IconParts) do
            lib:_tween(part, FAST, { BackgroundColor3 = active and Theme.Accent or Theme.SubText }):Play()
        end
    end

    local function selectTab(target)
        if target == selectedTab then return end
        lib:_hideHoverTip()
        stopControlDrag()
        local previous = selectedTab
        selectedTab = target
        for _, tab in ipairs(window._tabs) do
            local active = tab == target
            lib:_cancelTweens(tab.Group)
            tab.Page.Visible, tab.Group.Visible = active, active
            if active then
                local direction = previous and target.Index < previous.Index and -1 or 1
                tab.Group.Position = UDim2.fromOffset(direction * 18, 0)
                tab.Group.GroupTransparency = 0.75
                lib:_tween(tab.Group, SMOOTH, {
                    Position = UDim2.fromOffset(0, 0), GroupTransparency = 0,
                }):Play()
            end
            paintTab(tab)
        end
        lib:_tween(indicator, POP, {
            Position = UDim2.fromOffset(1, (target.Index - 1) * 48 + 15),
        }):Play()
    end

    function window:MakeTab(tabConfig)
        tabConfig = tabConfig or {}
        local index = #window._tabs + 1
        local button = create("TextButton", {
            Name = tabConfig.Name or "Tab", LayoutOrder = index,
            Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Theme.Panel,
            BackgroundTransparency = 0.65, AutoButtonColor = false, Text = "", Parent = tabList,
        })
        corner(button, 9)
        local outline = stroke(button, Theme.Accent)
        outline.Transparency = 1
        local icon, iconParts = tabIcon(button, index)
        local iconScale = create("UIScale", { Parent = icon })
        local label = create("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, -44, 1, 0),
            Position = UDim2.fromOffset(37, 0), Font = Enum.Font.GothamMedium,
            Text = tabConfig.Name or "Tab", TextColor3 = Theme.SubText, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = button,
        })
        local group = create("CanvasGroup", {
            Name = (tabConfig.Name or "Tab") .. "Transition", Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, Visible = false, Parent = content,
        })
        local page = create("ScrollingFrame", {
            Name = (tabConfig.Name or "Tab") .. "Page", Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent,
            ScrollBarImageTransparency = 0.35, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false, Parent = group,
        })
        local padding = pad(page, 6)
        padding.PaddingRight = UDim.new(0, 12)
        padding.PaddingBottom = UDim.new(0, 16)
        create("UIListLayout", {
            Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page,
        })
        create("TextLabel", {
            Name = "PageTitle", LayoutOrder = -100, Size = UDim2.new(1, 0, 0, 38),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            Text = tabConfig.Name or "Tab", TextSize = 23, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = page,
        })
        local tab = { Button = button, Label = label, Page = page, Group = group,
            Outline = outline, IconParts = iconParts, IconScale = iconScale, Index = index,
            _configScope = tostring(tabConfig.Name or "Tab") }
        table.insert(window._tabs, tab)
        lib:_connect(button.MouseEnter, function() tab.Hovered = true; paintTab(tab) end)
        lib:_connect(button.MouseLeave, function() tab.Hovered = false; paintTab(tab) end)
        lib:_connect(button.MouseButton1Click, function() selectTab(tab) end)
        if index == 1 then selectTab(tab) end
        attachElements(tab, page)

        function tab:AddSection(sectionConfig)
            sectionConfig = sectionConfig or {}
            local sectionFrame = create("Frame", {
                Name = "Section", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.18, Parent = page,
            })
            corner(sectionFrame, 12)
            stroke(sectionFrame).Transparency = 0.55
            pad(sectionFrame, 12)
            create("UIListLayout", {
                Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sectionFrame,
            })
            local header = create("TextLabel", {
                Name = "Header", LayoutOrder = -100, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.GothamBold,
                Text = sectionConfig.Name or "Section", TextColor3 = Theme.Text, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = sectionFrame,
            })
            create("UIPadding", { PaddingLeft = UDim.new(0, 11), Parent = header })
            local mark = create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -11, 0.5, 0),
                Size = UDim2.fromOffset(3, 13), BackgroundColor3 = Theme.Accent, Parent = header,
            })
            corner(mark, 2)
            gradient(mark, Theme.Accent, Theme.Pink, 90)
            local section = { _configScope = tab._configScope .. "/" .. tostring(sectionConfig.Name or "Section") }
            attachElements(section, sectionFrame)
            return section
        end
        return tab
    end

    --// Window movement and bottom-right resizing ------------------------- --
    local resizeHandle = create("TextButton", {
        Name = "ResizeHandle",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -3, 1, -3),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Active = true,
        Text = "",
        ZIndex = 50,
        Parent = main,
    })
    local gripArt = create("Frame", {
        Name = "GripArt", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 51, Parent = resizeHandle,
    })
    local gripScale = create("UIScale", { Parent = gripArt })
    self:_connect(resizeHandle.MouseEnter, function()
        self:_tween(gripScale, THUMB_MOTION, { Scale = 1.3 }):Play()
    end)
    self:_connect(resizeHandle.MouseLeave, function()
        self:_tween(gripScale, THUMB_MOTION, { Scale = 1 }):Play()
    end)
    for index = 1, 3 do
        create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -4, 1, -4 - (index - 1) * 5),
            Size = UDim2.fromOffset(index * 4, 2),
            Rotation = -45,
            BackgroundColor3 = Theme.SubText,
            BorderSizePixel = 0,
            ZIndex = 51,
            Parent = gripArt,
        })
    end
    local minimized = false
    local gesture, stateConnection, windowTween
    local lastViewportX, lastViewportY
    local screenMargin = 8

    local function viewportSize()
        local camera = Workspace.CurrentCamera
        local size = camera and camera.ViewportSize or screenGui.AbsoluteSize
        return math.max(1, size.X), math.max(1, size.Y)
    end

    local fitWindow
    local function stopWindowDrag()
        local previous = gesture
        gesture = nil
        if stateConnection then
            stateConnection:Disconnect()
            stateConnection = nil
        end
        if previous and previous.ResumeFit and not self._destroyed then fitWindow(SMOOTH) end
    end
    self._stopWindowDrag = stopWindowDrag

    local function setGeometry(left, top, width, height, tweenInfo)
        if windowTween then windowTween:Cancel(); windowTween = nil end
        self:_cancelTweens(main, { Size = true, Position = true })
        local goals = {
            Size = UDim2.fromOffset(width, height),
            Position = UDim2.fromOffset(left + width * main.AnchorPoint.X,
                top + height * main.AnchorPoint.Y),
        }
        if tweenInfo then
            windowTween = self:_tween(main, tweenInfo, goals)
            windowTween:Play()
        else
            main.Size = goals.Size
            main.Position = goals.Position
        end
    end

    fitWindow = function(tweenInfo)
        local viewX, viewY = viewportSize()
        lastViewportX, lastViewportY = viewX, viewY
        local marginX = math.min(screenMargin, (viewX - 1) / 2)
        local marginY = math.min(screenMargin, (viewY - 1) / 2)
        local maxWidth, maxHeight = viewX - 2 * marginX, viewY - 2 * marginY
        local width = math.clamp(self._mainSize.X.Offset, math.min(560, maxWidth), maxWidth)
        local fullHeight = math.clamp(self._mainSize.Y.Offset, math.min(340, maxHeight), maxHeight)
        local height = minimized and math.min(TITLE_HEIGHT, maxHeight) or fullHeight
        local left = math.clamp(main.AbsolutePosition.X - screenGui.AbsolutePosition.X, marginX, viewX - width - marginX)
        local top = math.clamp(main.AbsolutePosition.Y - screenGui.AbsolutePosition.Y, marginY, viewY - height - marginY)
        self._mainSize = UDim2.fromOffset(width, fullHeight)
        setGeometry(left, top, width, height, tweenInfo)
        return left, top, width, height
    end

    local function beginWindowDrag(input, resizing)
        if self._destroyed or not wantedVisible or not main.Visible or not screenGui.Enabled or (resizing and minimized) then return end
        local touch = input.UserInputType == Enum.UserInputType.Touch
        if not touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        stopWindowDrag()
        local pointer = touch and input.Position or UserInputService:GetMouseLocation()
        local viewX, viewY = viewportSize()
        if not finite(pointer.X) or not finite(pointer.Y) or pointer.X < 0 or pointer.Y < 0
            or pointer.X >= viewX or pointer.Y >= viewY then return end
        -- Snapshot the rendered rectangle without fitting or writing geometry.
        -- Cancel an in-flight minimize/restore and finish it after the gesture.
        local resumeFit = windowTween ~= nil and self._tweens[windowTween] ~= nil
        if windowTween then windowTween:Cancel(); windowTween = nil end
        self:_cancelTweens(main, { Size = true, Position = true })
        local origin = screenGui.AbsolutePosition
        local left, top = main.AbsolutePosition.X - origin.X, main.AbsolutePosition.Y - origin.Y
        local width, height = main.AbsoluteSize.X, main.AbsoluteSize.Y
        self:_hideHoverTip()
        gesture = { Input = input, Touch = touch, Resizing = resizing,
            X = pointer.X, Y = pointer.Y, LastX = pointer.X, LastY = pointer.Y,
            Left = left, Top = top, Width = width, Height = height, ResumeFit = resumeFit }
        stateConnection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
            if input.UserInputState == Enum.UserInputState.End
                or input.UserInputState == Enum.UserInputState.Cancel then
                stopWindowDrag()
            end
        end)
    end

    self:_connect(resizeHandle.InputBegan, function(input) beginWindowDrag(input, true) end)
    self:_connect(titleBar.InputBegan, function(input) beginWindowDrag(input, false) end)
    self:_connect(UserInputService.InputEnded, function(input)
        if gesture and (input == gesture.Input
            or (not gesture.Touch and input.UserInputType == Enum.UserInputType.MouseButton1)) then
            stopWindowDrag()
        end
    end)
    self:_connect(UserInputService.WindowFocusReleased, function()
        stopWindowDrag()
        self:_hideHoverTip()
    end)
    self:_connect(main:GetPropertyChangedSignal("Visible"), function()
        if not main.Visible then
            stopWindowDrag()
            if self._stopControlDrag then self._stopControlDrag() end
            self:_hideHoverTip()
        end
    end)
    self:_connect(screenGui:GetPropertyChangedSignal("Enabled"), function()
        if not screenGui.Enabled then
            stopWindowDrag()
            if self._stopControlDrag then self._stopControlDrag() end
            self:_hideHoverTip()
        end
    end)
    self:_connect(RunService.RenderStepped, function()
        local viewX, viewY = viewportSize()
        if viewX ~= lastViewportX or viewY ~= lastViewportY then
            stopWindowDrag()
            fitWindow()
        end
        if not gesture then return end
        local drag = gesture
        local state = drag.Input.UserInputState
        if not main.Visible or not screenGui.Enabled or state == Enum.UserInputState.End
            or state == Enum.UserInputState.Cancel
            or (not drag.Touch and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
            stopWindowDrag()
            return
        end
        local pointer = drag.Touch and drag.Input.Position or UserInputService:GetMouseLocation()
        if not finite(pointer.X) or not finite(pointer.Y) or pointer.X < 0 or pointer.Y < 0
            or pointer.X >= viewX or pointer.Y >= viewY then
            stopWindowDrag()
            return
        end
        -- Always measure from the original press; repeated frames cannot grow
        -- the window unless the pointer itself actually moves.
        if pointer.X == drag.LastX and pointer.Y == drag.LastY then return end
        drag.LastX, drag.LastY = pointer.X, pointer.Y
        local dx, dy = pointer.X - drag.X, pointer.Y - drag.Y
        if drag.Resizing then
            local maxWidth = math.max(1, viewX - screenMargin - drag.Left)
            local maxHeight = math.max(1, viewY - screenMargin - drag.Top)
            local width = math.clamp(drag.Width + dx, math.min(560, maxWidth), maxWidth)
            local height = math.clamp(drag.Height + dy, math.min(340, maxHeight), maxHeight)
            self._mainSize = UDim2.fromOffset(width, height)
            setGeometry(drag.Left, drag.Top, width, height)
        else
            local marginX = math.min(screenMargin, (viewX - drag.Width) / 2)
            local marginY = math.min(screenMargin, (viewY - drag.Height) / 2)
            local left = math.clamp(drag.Left + dx, marginX, viewX - drag.Width - marginX)
            local top = math.clamp(drag.Top + dy, marginY, viewY - drag.Height - marginY)
            setGeometry(left, top, drag.Width, drag.Height)
        end
    end)

    -- Preserve the resized dimensions when minimizing and restoring.
    minimizeBtn.MouseButton1Click:Connect(function()
        stopWindowDrag()
        minimized = not minimized
        self._minimized = minimized
        if self._stopControlDrag then self._stopControlDrag() end
        self:_hideHoverTip()
        body.Visible = not minimized
        resizeHandle.Visible = not minimized
        fitWindow(SMOOTH)
    end)

    --// Close: destroy the GUI and drop the library's own connections --
    closeBtn.MouseButton1Click:Connect(function()
        self:Destroy()
    end)

    -- One reversible opacity tween owns visibility. Geometry is never animated
    -- by this path, and completion cannot hide a subsequently reopened window.
    local fadeCompletion
    local function cancelWindowFade()
        if fadeCompletion then fadeCompletion:Disconnect(); fadeCompletion = nil end
        self:_cancelTweens(main, { GroupTransparency = true })
    end
    self._cancelWindowFade = cancelWindowFade
    local function setWindowVisible(visible)
        if self._destroyed then return end
        wantedVisible = visible
        self._windowWantedVisible = visible
        if self._cancelIntro then self._cancelIntro() end
        stopWindowDrag()
        stopControlDrag()
        self:_hideHoverTip()
        cancelWindowFade()
        fadeBlocker.Visible = not visible
        if visible then
            if not main.Visible then fitWindow(); main.Visible = true end
        elseif not main.Visible then
            main.GroupTransparency = 1
            fadeBlocker.Visible = false
            return
        end
        local target = visible and 0 or 1
        -- A full fade takes 0.28 seconds; reversing uses the remaining distance.
        local duration = 0.28 * math.abs(main.GroupTransparency - target)
        if duration < 0.001 then
            main.GroupTransparency = target
            main.Visible = visible
            fadeBlocker.Visible = false
            return
        end
        local tween = self:_tween(main, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            GroupTransparency = target,
        })
        local connection
        connection = tween.Completed:Connect(function(state)
            connection:Disconnect()
            if fadeCompletion == connection then fadeCompletion = nil end
            if state == Enum.PlaybackState.Completed and not self._destroyed and wantedVisible == visible then
                main.Visible = visible
                fadeBlocker.Visible = false
            end
        end)
        fadeCompletion = connection
        tween:Play()
    end

    --// RightShift toggles logical visibility, including during a fade --
    self:_connect(UserInputService.InputBegan, function(input, gameProcessed)
        if UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            setWindowVisible(not wantedVisible)

            local closeOrShown = wantedVisible and "Shown" or "Closed"
            local hideOrShow = wantedVisible and "hide" or "open"
            self:MakeNotification("Window " .. closeOrShown, "RightShift to " .. hideOrShow .. " the window again.", 3)
        end
    end)

    -- The splash is optional and never waits for image loading. Main-window
    -- geometry stays unscaled so grabbing it cannot capture a transient UIScale.
    local function revealWindow()
        if self._destroyed then return end
        self._introPending = false
        setWindowVisible(wantedVisible)
    end
    if self._introPending then self:_playIntro(revealWindow) else revealWindow() end

    self:_queueSave()
    return window
end


--// Intro splash --------------------------------------------------------- --
-- A short entrance sequence, not a loading meter. No image preload can block it.
function Library:_playIntro(onDone)
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or self._screenGui.AbsoluteSize
    local width, height = math.min(440, math.max(1, viewport.X - 24)), math.min(252, math.max(1, viewport.Y - 24))
    local splash = create("CanvasGroup", {
        Name = "Intro", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(width, height), BackgroundTransparency = 1,
        GroupTransparency = 1, ZIndex = 60, Parent = self._screenGui,
    })
    local card = create("Frame", {
        Name = "SplashCard", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4),
        BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = splash,
    })
    corner(card, 16)
    gradient(card, Color3.fromRGB(8, 6, 17), Color3.fromRGB(39, 18, 65), 65)
    local rim = stroke(card, Theme.Accent)
    rim.Transparency = 0.45
    gradient(rim, Theme.Blue, Theme.Pink, 20)
    for index = 1, 12 do
        local star = create("Frame", {
            Position = UDim2.fromScale((index * 0.173) % 1, (index * 0.317) % 1),
            Size = UDim2.fromOffset(index % 3 == 0 and 2 or 1, index % 3 == 0 and 2 or 1),
            BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.72, Parent = card,
        })
        corner(star, 2)
    end
    create("TextLabel", {
        Name = "Eyebrow", Position = UDim2.new(0, 24, 0, 19), Size = UDim2.new(1, -48, 0, 14),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
        Text = self._splashTip, TextSize = 9, TextColor3 = Theme.SubText, Parent = card,
    })
    local orbit = create("Frame", {
        Name = "Orbit", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 94),
        Size = UDim2.fromOffset(112, 76), BackgroundTransparency = 1, Rotation = -22, Parent = card,
    })
    corner(orbit, 100)
    stroke(orbit, Theme.Accent).Transparency = 0.77
    local logo = create("ImageLabel", {
        Name = "GalaxyLogo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 94),
        Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1,
        Image = self._icon, ScaleType = Enum.ScaleType.Fit, Parent = card,
    })
    self:_spinIcon(logo)
    local logoScale = create("UIScale", { Scale = 0.86, Parent = logo })
    create("TextLabel", {
        Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 148),
        Size = UDim2.new(1, -48, 0, 29), Font = Enum.Font.GothamBold,
        Text = guiTitle or "", TextColor3 = Theme.Text, TextSize = 23, Parent = card,
    })
    create("TextLabel", {
        Name = "SubTitle", BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 181),
        Size = UDim2.new(1, -48, 0, 18), Font = Enum.Font.Gotham,
        Text = guiSubtitle ~= "" and guiSubtitle or (guiCredits ~= "" and ("By " .. guiCredits) or "Welcome"),
        TextColor3 = Theme.SubText, TextSize = 12, Parent = card,
    })
    if guiCredits ~= "" then
        create("TextLabel", {
            Name = "Credits", BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 203),
            Size = UDim2.new(1, -48, 0, 13), Font = Enum.Font.Gotham,
            Text = "By " .. guiCredits, TextColor3 = Theme.SubText, TextSize = 10, Parent = card,
        })
    end
    local lineTrack = create("Frame", {
        Position = UDim2.new(0, 32, 1, -26), Size = UDim2.new(1, -64, 0, 1),
        BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.5, ClipsDescendants = true, Parent = card,
    })
    local glint = create("Frame", {
        Position = UDim2.fromOffset(-72, 0), Size = UDim2.fromOffset(72, 1),
        BackgroundColor3 = Theme.Accent, Parent = lineTrack,
    })
    gradient(glint, Theme.Blue, Theme.Pink)
    self:_tween(splash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
    self:_tween(logoScale, TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    self:_tween(orbit, TweenInfo.new(1.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Rotation = -8 }):Play()
    self:_tween(glint, TweenInfo.new(1.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), { Position = UDim2.new(1, 0, 0, 0) }):Play()
    local ended, threads = false, {}
    local function cancel()
        if ended then return end
        ended = true
        self._introPending = false
        for _, thread in ipairs(threads) do
            if self._tasks[thread] then task.cancel(thread); self._tasks[thread] = nil end
        end
        self:_cancelTweens(splash)
        self:_cancelTweens(logoScale)
        self:_cancelTweens(orbit)
        self:_cancelTweens(glint)
        splash:Destroy()
        self._cancelIntro = nil
    end
    self._cancelIntro = cancel
    table.insert(threads, self:_delay(3, function()
        if ended then return end
        self:_tween(splash, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 1 }):Play()
        table.insert(threads, self:_delay(0.25, function()
            if ended then return end
            cancel()
            if onDone then onDone() end
        end))
    end))
end

--// Notifications -------------------------------------------------------- --
-- The layout owns a slot; the toast animates inside it, so sliding is not
-- overwritten by UIListLayout. Text measurement allows multiline messages.
function Library:MakeNotification(title, desc, time)
    if self._destroyed or not self._notifyHolder then return end
    if type(title) == "table" then
        local cfg = title
        title, desc, time = cfg.Name, cfg.Content, cfg.Time
    end
    time = math.max(0.3, tonumber(time) or 3)
    title, desc = tostring(title or ""), tostring(desc or "")
    local height = TextService:GetTextSize(desc, 12, Enum.Font.Gotham, Vector2.new(264, 100000)).Y
    local slot = create("Frame", {
        Name = "ToastSlot", Size = UDim2.new(1, 0, 0, math.max(72, height + 50)),
        BackgroundTransparency = 1, Parent = self._notifyHolder,
    })
    local toast = create("CanvasGroup", {
        Name = "Toast", Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(30, 0),
        BackgroundTransparency = 1, GroupTransparency = 1, Parent = slot,
    })
    local card = create("Frame", {
        Name = "ToastCard", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4),
        BackgroundColor3 = Theme.Panel, Parent = toast,
    })
    corner(card, 12)
    local rim = stroke(card, Theme.Accent)
    rim.Transparency = 0.48
    gradient(rim, Theme.Blue, Theme.Pink, 15)
    local bar = create("Frame", {
        Position = UDim2.fromOffset(0, 14), Size = UDim2.new(0, 3, 1, -28),
        BackgroundColor3 = Theme.Accent, Parent = card,
    })
    gradient(bar, Theme.Accent, Theme.Pink, 90)
    create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(17, 12),
        Size = UDim2.new(1, -34, 0, 20), Font = Enum.Font.GothamBold,
        Text = title, TextColor3 = Theme.Text, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(17, 36),
        Size = UDim2.new(1, -34, 1, -45), Font = Enum.Font.Gotham,
        Text = desc, TextColor3 = Theme.SubText, TextSize = 12, TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        Parent = card,
    })
    self:_tween(toast, TOAST_ENTER, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }):Play()
    self:_delay(time, function()
        self:_tween(toast, SMOOTH, { Position = UDim2.fromOffset(30, 0), GroupTransparency = 1 }):Play()
        self:_delay(0.22, function() slot:Destroy() end)
    end)
end

--// Teardown ------------------------------------------------------------- --
-- Destroys the GUI and disconnects every library-owned connection.
function Library:Destroy()
    if self._destroyed then return end
    if self._cancelWindowFade then self._cancelWindowFade() end
    if self._cancelIntro then self._cancelIntro() end
    if self._stopWindowDrag then self._stopWindowDrag() end
    if self._stopControlDrag then self._stopControlDrag() end
    if self.SaveConfig and self._configDirty and not self._configLoadFailed then
        self:SaveCfg()
    end
    self:_hideHoverTip()
    self._destroyed = true
    self._saveVersion = self._saveVersion + 1
    for thread in pairs(self._tasks) do task.cancel(thread) end
    self._tasks = {}
    for tween, record in pairs(self._tweens) do
        record.Connection:Disconnect()
        tween:Cancel()
    end
    self._tweens = {}
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
