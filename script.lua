-- Alacrity.lua
-- Solara · mouse-driven aim (mousemoverel) + esp · '94 REMASTERED
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/<you>/<repo>/main/Alacrity.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local mouseMove = mousemoverel or mouse_move_rel
local writeFile, readFile = writefile, readfile
local isFile, isFolder, makeFolder = isfile, isfolder, makefolder
local hasDrawing = Drawing ~= nil

local Theme = {
	accent = Color3.fromRGB(137, 92, 255),
	accent2 = Color3.fromRGB(56, 189, 248),
	background = Color3.fromRGB(18, 19, 26),
	panel = Color3.fromRGB(24, 25, 34),
	panelSoft = Color3.fromRGB(31, 32, 43),
	row = Color3.fromRGB(38, 39, 52),
	track = Color3.fromRGB(52, 54, 70),
	stroke = Color3.fromRGB(64, 66, 86),
	text = Color3.fromRGB(240, 241, 248),
	subtext = Color3.fromRGB(154, 158, 178),
	good = Color3.fromRGB(74, 222, 128),
	bad = Color3.fromRGB(248, 113, 113),
}

local WIDTH, HEIGHT = 620, 432

local State = {
	aim = {
		enabled = true,
		always = false,
		key = Enum.UserInputType.MouseButton2,
		part = "Head",
		mode = "Crosshair",
		fov = 140,
		smooth = 3,
		prediction = 0,
		teamCheck = true,
		wallCheck = true,
		showFov = true,
	},
	esp = {
		enabled = true,
		box = true,
		name = true,
		distance = true,
		health = true,
		tracer = false,
		teamCheck = true,
		maxDistance = 600,
	},
	menu = {
		key = Enum.KeyCode.Insert,
	},
}

local Syncer = {}
local connections = {}

local function split(path)
	local out = {}
	for piece in string.gmatch(path, "[^%.]+") do
		table.insert(out, piece)
	end
	return out
end

local function readPath(path)
	local node = State
	for _, key in ipairs(split(path)) do
		if node == nil then
			return nil
		end
		node = node[key]
	end
	return node
end

local function writePath(path, value)
	local keys = split(path)
	local node = State
	for index = 1, #keys - 1 do
		node = node[keys[index]]
	end
	node[keys[#keys]] = value
end

local function setFlag(path, value)
	writePath(path, value)
	local sync = Syncer[path]
	if sync then
		sync(value)
	end
end

local function bind(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function create(class, props, children)
	local instance = Instance.new(class)
	for key, value in next, props or {} do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in next, children or {} do
		if typeof(child) == "Instance" then
			child.Parent = instance
		end
	end
	local parent = props and props.Parent
	if typeof(parent) ~= "Instance" and type(parent) == "table" and typeof(parent.frame) == "Instance" then
		parent = parent.frame
	end
	if typeof(parent) == "Instance" then
		instance.Parent = parent
	end
	return instance
end

local function corner(radius, parent)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius),
		Parent = parent,
	})
end

local function stroke(color, thickness, transparency, parent)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function tween(instance, duration, props, style, direction)
	local info = TweenInfo.new(
		duration or 0.14,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)
	local animation = TweenService:Create(instance, info, props)
	animation:Play()
	return animation
end

local function textLabel(parent, props)
	local merged = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false,
	}
	for key, value in next, props or {} do
		merged[key] = value
	end
	merged.Parent = parent
	return create("TextLabel", merged)
end

local function guiParent()
	local ok, hidden = pcall(gethui)
	if ok and hidden then
		return hidden
	end
	local okCore, core = pcall(function()
		return game:GetService("CoreGui")
	end)
	if okCore and core then
		return core
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local screen = create("ScreenGui", {
	Name = "Alacrity",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 9999,
	Parent = guiParent(),
})

if syn and syn.protect_gui then
	pcall(syn.protect_gui, screen)
end

local root = create("Frame", {
	Name = "Root",
	Size = UDim2.fromOffset(WIDTH, HEIGHT),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Theme.background,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Parent = screen,
})
corner(14, root)

local backdrop = create("Frame", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 0,
	Parent = root,
})
create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 35, 47)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(19, 20, 28)),
	}),
	Rotation = 90,
	Parent = backdrop,
})
local border = stroke(Color3.fromRGB(76, 78, 102), 1, 0.3, root)

local scale = create("UIScale", { Scale = 0.96, Parent = root })

local header = create("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 61),
	BackgroundTransparency = 1,
	Active = true,
	Parent = root,
})

local mark = create("Frame", {
	Size = UDim2.fromOffset(8, 8),
	Position = UDim2.fromOffset(22, 27),
	BackgroundColor3 = Theme.accent,
	BorderSizePixel = 0,
	Parent = header,
})
corner(4, mark)
create("UIGradient", {
	Color = ColorSequence.new(Theme.accent, Theme.accent2),
	Rotation = 45,
	Parent = mark,
})

textLabel(header, {
	Text = "alacrity",
	Position = UDim2.fromOffset(38, 13),
	Size = UDim2.fromOffset(240, 24),
	Font = Enum.Font.GothamBold,
	TextSize = 17,
})

textLabel(header, {
	Text = "mouse aim · esp · v1.0.0",
	Position = UDim2.fromOffset(39, 34),
	Size = UDim2.fromOffset(280, 14),
	TextSize = 11,
	TextColor3 = Theme.subtext,
	Font = Enum.Font.GothamMedium,
})

local divider = create("Frame", {
	Size = UDim2.new(1, -32, 0, 1),
	Position = UDim2.fromOffset(16, 61),
	BackgroundColor3 = Theme.stroke,
	BorderSizePixel = 0,
	Parent = root,
})
create("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Parent = divider,
})

local body = create("Frame", {
	Size = UDim2.new(1, 0, 1, -62),
	Position = UDim2.fromOffset(0, 62),
	BackgroundTransparency = 1,
	Parent = root,
})

local sidebar = create("Frame", {
	Size = UDim2.new(0, 152, 1, -24),
	Position = UDim2.fromOffset(16, 12),
	BackgroundColor3 = Theme.panel,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	Parent = body,
})
corner(12, sidebar)
stroke(Theme.stroke, 1, 0.6, sidebar)

local tabList = create("Frame", {
	Size = UDim2.new(1, -16, 0, 200),
	Position = UDim2.fromOffset(8, 10),
	BackgroundTransparency = 1,
	Parent = sidebar,
})
create("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = tabList,
})

textLabel(sidebar, {
	Text = "signed in · solara",
	Position = UDim2.new(0, 16, 1, -46),
	Size = UDim2.new(1, -24, 0, 14),
	TextSize = 10,
	TextColor3 = Theme.subtext,
	Font = Enum.Font.GothamMedium,
})

textLabel(sidebar, {
	Text = "build 1.0.0",
	Position = UDim2.new(0, 16, 1, -30),
	Size = UDim2.new(1, -24, 0, 14),
	TextSize = 10,
	TextColor3 = Color3.fromRGB(120, 124, 142),
	Font = Enum.Font.GothamMedium,
})

local pageHost = create("Frame", {
	Size = UDim2.new(1, -200, 1, -24),
	Position = UDim2.fromOffset(184, 12),
	BackgroundTransparency = 1,
	Parent = body,
})

local layoutOrder = 0
local function nextOrder()
	layoutOrder = layoutOrder + 1
	return layoutOrder
end

local pages = {}

local function addPage(name)
	local page = create("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.accent,
		ScrollBarImageTransparency = 0.4,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = pageHost,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})
	create("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 8),
		Parent = page,
	})
	table.insert(pages, page)
	return page
end

local tabButtons = {}
local activeTab
local activate

local function addTab(entry)
	local button = create("TextButton", {
		Text = "",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.panelSoft,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = #tabButtons + 1,
		Parent = tabList,
	})
	corner(9, button)

	local indicator = create("Frame", {
		Size = UDim2.new(0, 3, 0, 12),
		Position = UDim2.new(0, 0, 0.5, -6),
		BackgroundColor3 = Theme.accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = button,
	})
	corner(2, indicator)
	create("UIGradient", {
		Color = ColorSequence.new(Theme.accent, Theme.accent2),
		Rotation = 90,
		Parent = indicator,
	})

	local dot = create("Frame", {
		Size = UDim2.fromOffset(5, 5),
		Position = UDim2.fromOffset(16, 15),
		BackgroundColor3 = Theme.subtext,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = button,
	})
	corner(3, dot)

	local label = textLabel(button, {
		Text = entry.Name,
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -30, 1, 0),
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Theme.subtext,
	})

	local data = {
		entry = entry,
		button = button,
		indicator = indicator,
		dot = dot,
		label = label,
	}

	button.MouseButton1Click:Connect(function()
		activate(data)
	end)
	button.MouseEnter:Connect(function()
		if activeTab ~= data then
			tween(button, 0.12, { BackgroundTransparency = 0.88 })
			tween(label, 0.12, { TextColor3 = Theme.text })
		end
	end)
	button.MouseLeave:Connect(function()
		if activeTab ~= data then
			tween(button, 0.12, { BackgroundTransparency = 1 })
			tween(label, 0.12, { TextColor3 = Theme.subtext })
		end
	end)

	table.insert(tabButtons, data)
	return data
end

activate = function(data)
	activeTab = data
	for _, other in ipairs(tabButtons) do
		local active = other == data
		tween(other.button, 0.14, {
			BackgroundTransparency = active and 0.5 or 1,
		})
		tween(other.indicator, 0.14, {
			BackgroundTransparency = active and 0 or 1,
		})
		tween(other.label, 0.14, {
			TextColor3 = active and Theme.text or Theme.subtext,
		})
		tween(other.dot, 0.14, {
			BackgroundColor3 = active and Theme.accent or Theme.subtext,
			BackgroundTransparency = active and 0 or 0.3,
		})
		other.entry.Visible = active
	end
end

local function addSection(parent, title)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
	textLabel(frame, {
		Text = string.upper(title),
		Position = UDim2.fromOffset(0, 9),
		Size = UDim2.new(1, 0, 0, 12),
		TextSize = 10,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.subtext,
	})
	local line = create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.stroke,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = frame,
	})
	return frame
end

local function addToggle(parent, spec)
	local frame = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Theme.row,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
	corner(8, frame)
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.stroke,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = frame,
	})
	textLabel(frame, {
		Text = spec.text,
		Position = UDim2.fromOffset(2, 0),
		Size = UDim2.new(1, -60, 1, 0),
		TextSize = 13,
	})
	local track = create("Frame", {
		Size = UDim2.fromOffset(34, 18),
		Position = UDim2.new(1, -34, 0.5, -9),
		BackgroundColor3 = Theme.track,
		BorderSizePixel = 0,
		Parent = frame,
	})
	corner(9, track)
	local knob = create("Frame", {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Color3.fromRGB(152, 156, 172),
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(6, knob)

	local function render(value)
		tween(track, 0.15, {
			BackgroundColor3 = value and Theme.accent or Theme.track,
		})
		tween(knob, 0.15, {
			Position = UDim2.fromOffset(value and 19 or 3, 3),
			BackgroundColor3 = value and Color3.new(1, 1, 1) or Color3.fromRGB(152, 156, 172),
		})
	end

	render(readPath(spec.path) and true or false)
	Syncer[spec.path] = function(value)
		render(value and true or false)
	end

	frame.MouseButton1Click:Connect(function()
		local nextValue = not readPath(spec.path)
		writePath(spec.path, nextValue)
		render(nextValue)
	end)
	frame.MouseEnter:Connect(function()
		tween(frame, 0.14, { BackgroundTransparency = 0.7 })
	end)
	frame.MouseLeave:Connect(function()
		tween(frame, 0.14, { BackgroundTransparency = 1 })
	end)
end

local function formatNumber(value, decimals)
	local factor = 10 ^ (decimals or 0)
	return string.format("%." .. tostring(decimals or 0) .. "f", math.floor(value * factor + 0.5) / factor)
end

local function addSlider(parent, spec)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.stroke,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = frame,
	})
	textLabel(frame, {
		Text = spec.text,
		Position = UDim2.fromOffset(2, 10),
		Size = UDim2.new(1, -80, 0, 14),
		TextSize = 13,
	})
	local valueLabel = textLabel(frame, {
		Text = "",
		Position = UDim2.new(1, -80, 0, 10),
		Size = UDim2.fromOffset(80, 14),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.subtext,
		Font = Enum.Font.GothamMedium,
	})
	local track = create("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.new(0, 0, 0, 36),
		BackgroundColor3 = Theme.track,
		BorderSizePixel = 0,
		Parent = frame,
	})
	corner(2, track)
	local fill = create("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(2, fill)
	create("UIGradient", {
		Color = ColorSequence.new(Theme.accent, Theme.accent2),
		Parent = fill,
	})
	local knob = create("Frame", {
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(5, knob)

	local hit = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 28),
		Parent = frame,
	})

	local decimals = spec.decimals or 0
	local step = spec.step or ((spec.max - spec.min) / 100)

	local function render(value)
		local alpha = (value - spec.min) / (spec.max - spec.min)
		alpha = math.clamp(alpha, 0, 1)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = formatNumber(value, decimals) .. (spec.suffix or "")
	end

	local function fromX(absoluteX)
		local origin = track.AbsolutePosition.X
		local width = math.max(track.AbsoluteSize.X, 1)
		local alpha = math.clamp((absoluteX - origin) / width, 0, 1)
		local raw = spec.min + (spec.max - spec.min) * alpha
		local snapped = math.floor(raw / step + 0.5) * step
		snapped = math.clamp(snapped, spec.min, spec.max)
		return math.floor(snapped * 100 + 0.5) / 100
	end

	render(readPath(spec.path))
	Syncer[spec.path] = function(value)
		render(value)
	end

	local dragging = false

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			local value = fromX(input.Position.X)
			writePath(spec.path, value)
			render(value)
		end
	end)

	bind(UserInputService.InputChanged, function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local value = fromX(input.Position.X)
			writePath(spec.path, value)
			render(value)
		end
	end)

	bind(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	hit.MouseEnter:Connect(function()
		tween(knob, 0.12, { Size = UDim2.fromOffset(13, 13) })
	end)
	hit.MouseLeave:Connect(function()
		if not dragging then
			tween(knob, 0.12, { Size = UDim2.fromOffset(10, 10) })
		end
	end)
end

local function addDropdown(parent, spec)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.stroke,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = frame,
	})
	textLabel(frame, {
		Text = spec.text,
		Position = UDim2.fromOffset(2, 0),
		Size = UDim2.new(1, -150, 1, 0),
		TextSize = 13,
	})

	local button = create("TextButton", {
		Text = tostring(readPath(spec.path)),
		AutoButtonColor = false,
		Size = UDim2.fromOffset(136, 26),
		Position = UDim2.new(1, -136, 0, 8),
		BackgroundColor3 = Theme.panelSoft,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	corner(7, button)
	stroke(Theme.stroke, 1, 0.35, button)

	local chevron = textLabel(button, {
		Text = "▼",
		Position = UDim2.new(1, -21, 0, 4),
		Size = UDim2.fromOffset(16, 18),
		TextSize = 8,
		TextColor3 = Theme.subtext,
	})

	local buttonOverlay = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = button,
	})
	corner(7, buttonOverlay)

	local rowHeight = 26
	local list = create("Frame", {
		Size = UDim2.new(1, 0, 0, #spec.options * rowHeight + 8),
		Position = UDim2.fromOffset(0, 38),
		BackgroundColor3 = Theme.panelSoft,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
		Parent = frame,
	})
	corner(8, list)
	stroke(Theme.stroke, 1, 0.4, list)

	local expandedHeight = 42 + #spec.options * rowHeight + 12

	local function setExpanded(expanded)
		list.Visible = expanded
		frame.Size = UDim2.new(1, 0, 0, expanded and expandedHeight or 42)
		chevron.Text = expanded and "▲" or "▼"
	end

	local items = {}

	for index, option in ipairs(spec.options) do
		local item = create("TextButton", {
			Text = option,
			AutoButtonColor = false,
			Size = UDim2.new(1, -8, 0, rowHeight),
			Position = UDim2.fromOffset(4, 4 + (index - 1) * rowHeight),
			BackgroundColor3 = Theme.row,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = Theme.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = list,
		})
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			Parent = item,
		})

		item.MouseEnter:Connect(function()
			tween(item, 0.1, { BackgroundTransparency = 0.5 })
			tween(item, 0.1, { TextColor3 = Theme.text })
		end)
		item.MouseLeave:Connect(function()
			tween(item, 0.1, { BackgroundTransparency = 1 })
			tween(item, 0.1, {
				TextColor3 = (readPath(spec.path) == option) and Theme.text or Theme.subtext,
			})
		end)
		item.MouseButton1Click:Connect(function()
			writePath(spec.path, option)
			button.Text = option
			setExpanded(false)
			for _, other in ipairs(items) do
				other.TextColor3 = Theme.subtext
			end
			item.TextColor3 = Theme.text
		end)

		table.insert(items, item)
		if readPath(spec.path) == option then
			item.TextColor3 = Theme.text
		end
	end

	Syncer[spec.path] = function(value)
		button.Text = tostring(value)
		for _, other in ipairs(items) do
			other.TextColor3 = (other.Text == tostring(value)) and Theme.text or Theme.subtext
		end
	end

	button.MouseButton1Click:Connect(function()
		setExpanded(not list.Visible)
	end)
	button.MouseEnter:Connect(function()
		tween(buttonOverlay, 0.12, { BackgroundTransparency = 0.93 })
	end)
	button.MouseLeave:Connect(function()
		tween(buttonOverlay, 0.12, { BackgroundTransparency = 1 })
	end)
end

local MOUSE_LABELS = {
	MouseButton1 = "M1",
	MouseButton2 = "M2",
	MouseButton3 = "M3",
}

local function bindName(value)
	if typeof(value) ~= "EnumItem" then
		return "none"
	end
	if value.EnumType == Enum.UserInputType then
		return MOUSE_LABELS[value.Name] or value.Name
	end
	return value.Name
end

local function addKeybind(parent, spec)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.stroke,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = frame,
	})
	textLabel(frame, {
		Text = spec.text,
		Position = UDim2.fromOffset(2, 0),
		Size = UDim2.new(1, -120, 1, 0),
		TextSize = 13,
	})

	local button = create("TextButton", {
		Text = bindName(readPath(spec.path)),
		AutoButtonColor = false,
		Size = UDim2.fromOffset(104, 26),
		Position = UDim2.new(1, -104, 0.5, -13),
		BackgroundColor3 = Theme.panelSoft,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	corner(7, button)
	local outline = stroke(Theme.stroke, 1, 0.35, button)

	local listening = false
	local armedAt = 0

	local function stopListening()
		listening = false
		button.Text = bindName(readPath(spec.path))
		tween(outline, 0.14, { Color = Theme.stroke, Transparency = 0.35 })
	end

	button.MouseButton1Click:Connect(function()
		listening = true
		armedAt = os.clock()
		button.Text = "press a key"
		tween(outline, 0.14, { Color = Theme.accent, Transparency = 0 })
	end)

	bind(UserInputService.InputBegan, function(input)
		if not listening then
			return
		end
		if os.clock() - armedAt < 0.12 then
			return
		end

		local chosen
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				stopListening()
				return
			end
			chosen = input.KeyCode
		elseif input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3 then
			chosen = input.UserInputType
		end

		if chosen then
			setFlag(spec.path, chosen)
			stopListening()
		end
	end)

	Syncer[spec.path] = function(value)
		if not listening then
			button.Text = bindName(value)
		end
	end
end

local function addButton(parent, spec)
	local button = create("TextButton", {
		Text = spec.text,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = spec.accent and Theme.accent or Theme.panelSoft,
		BackgroundTransparency = spec.accent and 0.05 or 0.1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = spec.accent and Color3.new(1, 1, 1) or Theme.text,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
	corner(8, button)
	if spec.accent then
		create("UIGradient", {
			Color = ColorSequence.new(Theme.accent, Theme.accent2),
			Rotation = 15,
			Parent = button,
		})
	else
		stroke(Theme.stroke, 1, 0.4, button)
	end
	local buttonOverlay = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = button,
	})
	corner(8, buttonOverlay)
	button.MouseEnter:Connect(function()
		tween(buttonOverlay, 0.12, { BackgroundTransparency = 0.9 })
	end)
	button.MouseLeave:Connect(function()
		tween(buttonOverlay, 0.12, { BackgroundTransparency = 1 })
	end)
	button.MouseButton1Click:Connect(function()
		if spec.callback then
			spec.callback()
		end
	end)
	return button
end

local function addSpacer(parent, height)
	return create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
end

local function addNote(parent, text)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.panelSoft,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
	corner(8, frame)
	stroke(Theme.stroke, 1, 0.6, frame)
	textLabel(frame, {
		Text = text,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		TextSize = 11,
		TextColor3 = Theme.subtext,
		Font = Enum.Font.GothamMedium,
	})
	return frame
end

local aimPage = addPage("aimbot")
local visualPage = addPage("visuals")
local settingsPage = addPage("settings")

addTab(aimPage)
addTab(visualPage)
addTab(settingsPage)

addSection(aimPage, "aim")
addToggle(aimPage, { text = "enabled", path = "aim.enabled" })
addToggle(aimPage, { text = "always on (ignore key)", path = "aim.always" })
addKeybind(aimPage, { text = "aim key", path = "aim.key" })
addDropdown(aimPage, {
	text = "target part",
	path = "aim.part",
	options = { "Head", "Torso", "Auto" },
})
addDropdown(aimPage, {
	text = "selection",
	path = "aim.mode",
	options = { "Crosshair", "Distance" },
})

addSection(aimPage, "tuning")
addSlider(aimPage, {
	text = "fov radius",
	path = "aim.fov",
	min = 20,
	max = 400,
	step = 1,
	decimals = 0,
	suffix = " px",
})
addSlider(aimPage, {
	text = "smoothing",
	path = "aim.smooth",
	min = 1,
	max = 20,
	step = 1,
	decimals = 0,
})
addSlider(aimPage, {
	text = "prediction",
	path = "aim.prediction",
	min = 0,
	max = 250,
	step = 5,
	decimals = 0,
	suffix = " ms",
})

addSection(aimPage, "filters")
addToggle(aimPage, { text = "team check", path = "aim.teamCheck" })
addToggle(aimPage, { text = "wall check", path = "aim.wallCheck" })
addToggle(aimPage, { text = "draw fov circle", path = "aim.showFov" })

addSection(visualPage, "esp")
addToggle(visualPage, { text = "enabled", path = "esp.enabled" })
addToggle(visualPage, { text = "boxes", path = "esp.box" })
addToggle(visualPage, { text = "names", path = "esp.name" })
addToggle(visualPage, { text = "distance", path = "esp.distance" })
addToggle(visualPage, { text = "health bar", path = "esp.health" })
addToggle(visualPage, { text = "tracers", path = "esp.tracer" })
addToggle(visualPage, { text = "team check", path = "esp.teamCheck" })
addSlider(visualPage, {
	text = "max distance",
	path = "esp.maxDistance",
	min = 50,
	max = 2000,
	step = 50,
	decimals = 0,
	suffix = " m",
})

addSection(settingsPage, "interface")
addKeybind(settingsPage, { text = "menu key", path = "menu.key" })
addNote(settingsPage, "insert toggles the window · esc cancels a bind")

addSection(settingsPage, "config")
addButton(settingsPage, {
	text = "save config",
	callback = function()
		if saveConfig() then
			toast("config saved")
		else
			toast("config save failed")
		end
	end,
})
addButton(settingsPage, {
	text = "load config",
	callback = function()
		if loadConfig() then
			toast("config loaded")
		else
			toast("no config found")
		end
	end,
})
addSpacer(settingsPage, 8)
addButton(settingsPage, {
	text = "unload",
	callback = function()
		unload()
	end,
})

local function headerButton(glyph, x, danger)
	local button = create("TextButton", {
		Text = glyph,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Theme.subtext,
		BackgroundColor3 = Theme.panelSoft,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromOffset(x, 17),
		Parent = header,
	})
	corner(7, button)
	button.MouseEnter:Connect(function()
		tween(button, 0.12, {
			BackgroundTransparency = 0.2,
			TextColor3 = danger and Theme.bad or Theme.text,
		})
	end)
	button.MouseLeave:Connect(function()
		tween(button, 0.12, {
			BackgroundTransparency = 1,
			TextColor3 = Theme.subtext,
		})
	end)
	return button
end

local closeButton = headerButton("×", WIDTH - 42, true)
local minButton = headerButton("—", WIDTH - 74, false)

local minimized = false

local function setMinimized(value)
	minimized = value
	if value then
		tween(root, 0.2, { Size = UDim2.fromOffset(WIDTH, 62) }, Enum.EasingStyle.Quart)
		task.delay(0.2, function()
			if minimized then
				body.Visible = false
			end
		end)
	else
		body.Visible = true
		tween(root, 0.2, { Size = UDim2.fromOffset(WIDTH, HEIGHT) }, Enum.EasingStyle.Quart)
	end
end

local menuOpen = true

local function setMenuOpen(open)
	menuOpen = open
	if open then
		root.Visible = true
		scale.Scale = 0.97
		tween(scale, 0.16, { Scale = 1 }, Enum.EasingStyle.Quart)
	else
		root.Visible = false
	end
end

local function toggleMenu()
	setMenuOpen(not menuOpen)
end

local toastCount = 0

function toast(message, duration)
	toastCount = toastCount + 1
	local index = toastCount
	local box = create("Frame", {
		Name = "Toast",
		Size = UDim2.fromOffset(300, 34),
		Position = UDim2.new(0.5, 0, 0, 18 + (index % 3) * 40),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Parent = screen,
	})
	corner(9, box)
	stroke(Theme.stroke, 1, 0.35, box)
	textLabel(box, {
		Text = message,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamMedium,
	})
	task.delay(duration or 2.2, function()
		if box and box.Parent then
			box:Destroy()
		end
	end)
end

local function encodeBind(value)
	if typeof(value) ~= "EnumItem" then
		return nil
	end
	local enumName = string.gsub(tostring(value.EnumType), "Enum%.", "")
	return { enum = enumName, name = value.Name }
end

local function decodeBind(raw)
	if type(raw) ~= "table" or type(raw.enum) ~= "string" or type(raw.name) ~= "string" then
		return nil
	end
	local enumType = Enum[raw.enum]
	if not enumType then
		return nil
	end
	return enumType[raw.name]
end

local CONFIG_DIR = "alacrity"
local CONFIG_FILE = "alacrity/config.json"

function saveConfig()
	if not writeFile then
		return false
	end
	local snapshot = {}
	for group, values in pairs(State) do
		snapshot[group] = {}
		for key, value in pairs(values) do
			if typeof(value) == "EnumItem" then
				snapshot[group][key] = encodeBind(value)
			elseif type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
				snapshot[group][key] = value
			end
		end
	end
	local ok = pcall(function()
		if makeFolder and isFolder and not isFolder(CONFIG_DIR) then
			makeFolder(CONFIG_DIR)
		end
		writeFile(CONFIG_FILE, HttpService:JSONEncode(snapshot))
	end)
	return ok
end

function loadConfig()
	if not readFile or not isFile then
		return false
	end
	local okRead, raw = pcall(function()
		if not isFile(CONFIG_FILE) then
			return nil
		end
		return readFile(CONFIG_FILE)
	end)
	if not okRead or type(raw) ~= "string" or #raw == 0 then
		return false
	end
	local okDecode, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not okDecode or type(data) ~= "table" then
		return false
	end
	for group, values in pairs(data) do
		if type(values) == "table" and State[group] then
			for key, value in pairs(values) do
				if key == "key" then
					local decoded = decodeBind(value)
					if decoded then
						setFlag(group .. ".key", decoded)
					end
				elseif State[group][key] ~= nil then
					local current = State[group][key]
					if type(value) == type(current) then
						setFlag(group .. "." .. key, value)
					end
				end
			end
		end
	end
	return true
end

local fovRing
if hasDrawing then
	local okCircle, circle = pcall(Drawing.new, "Circle")
	if okCircle and circle then
		fovRing = circle
		pcall(function()
			circle.Thickness = 1
			circle.NumSides = 96
			circle.Radius = State.aim.fov
			circle.Filled = false
			circle.Transparency = 0.65
			circle.Color = Theme.accent
			circle.Visible = false
		end)
	end
end

local EXCLUDE = Enum.RaycastFilterType.Exclude
local rayParams = RaycastParams.new()
rayParams.FilterType = EXCLUDE
rayParams.IgnoreWater = true

local function aliveCharacter(character)
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function partVisible(character, part)
	local filter = { Camera }
	if LocalPlayer.Character then
		table.insert(filter, LocalPlayer.Character)
	end
	rayParams.FilterDescendantsInstances = filter
	local origin = Camera.CFrame.Position
	local hit = workspace:Raycast(origin, part.Position - origin, rayParams)
	if not hit then
		return true
	end
	return hit.Instance:IsDescendantOf(character)
end

local function candidateParts(character)
	local head = character:FindFirstChild("Head")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local mode = State.aim.part
	if mode == "Head" then
		return head and { head } or {}
	elseif mode == "Torso" then
		return torso and { torso } or {}
	end
	local list = {}
	if head then
		table.insert(list, head)
	end
	if torso then
		table.insert(list, torso)
	end
	return list
end

local function friendly(player)
	if not State.aim.teamCheck then
		return false
	end
	local mine = LocalPlayer.Team
	local theirs = player.Team
	return mine ~= nil and theirs ~= nil and mine == theirs
end

local function findTarget()
	local viewport = Camera.ViewportSize
	local origin = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
	local bestPart
	local bestScore = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and not friendly(player) then
			local character = player.Character
			if aliveCharacter(character) then
				for _, part in ipairs(candidateParts(character)) do
					local screen, onScreen = Camera:WorldToViewportPoint(part.Position)
					if onScreen then
						local offset = Vector2.new(screen.X, screen.Y) - origin
						local distance = offset.Magnitude
						if distance <= State.aim.fov then
							local score = distance
							if State.aim.mode == "Distance" then
								score = (Camera.CFrame.Position - part.Position).Magnitude
							end
							if score < bestScore and (not State.aim.wallCheck or partVisible(character, part)) then
								bestScore = score
								bestPart = part
							end
						end
					end
				end
			end
		end
	end

	return bestPart
end

local function aimAt(part)
	if not mouseMove then
		return
	end
	local viewport = Camera.ViewportSize
	local position = part.Position
	if State.aim.prediction > 0 then
		local velocity = part.AssemblyLinearVelocity
		if velocity then
			position = position + velocity * (State.aim.prediction / 1000)
		end
	end
	local screen, onScreen = Camera:WorldToViewportPoint(position)
	if not onScreen then
		return
	end
	local delta = Vector2.new(screen.X - viewport.X * 0.5, screen.Y - viewport.Y * 0.5)
	local magnitude = delta.Magnitude
	if magnitude < 0.75 then
		return
	end
	local factor = 1 / math.max(State.aim.smooth, 1)
	local step = delta * factor
	local maxStep = 220
	if step.Magnitude > maxStep then
		step = step.Unit * maxStep
	end
	pcall(mouseMove, step.X, step.Y)
end

local espObjects = {}

local function resolveDrawing(candidates)
	if not hasDrawing then
		return nil
	end
	for _, name in ipairs(candidates) do
		local ok, object = pcall(Drawing.new, name)
		if ok and object then
			pcall(function()
				object.Visible = false
			end)
			pcall(function()
				object:Remove()
			end)
			return name
		end
	end
	return nil
end

local BOX_CLASS = resolveDrawing({ "Rectangle", "Square", "Quad" })
local TEXT_CLASS = resolveDrawing({ "Text" })
local LINE_CLASS = resolveDrawing({ "Line" })
local espLimited = hasDrawing and (BOX_CLASS == nil or TEXT_CLASS == nil or LINE_CLASS == nil)

local function nullDrawing()
	return setmetatable({}, {
		__index = function()
			return nil
		end,
		__newindex = function() end,
	})
end

local function newDrawing(class)
	if not class then
		return nullDrawing()
	end
	local ok, object = pcall(Drawing.new, class)
	if ok and object then
		return object
	end
	return nullDrawing()
end

local function newEspObjects()
	local objects = {
		box = newDrawing(BOX_CLASS),
		health = newDrawing(BOX_CLASS),
		name = newDrawing(TEXT_CLASS),
		distance = newDrawing(TEXT_CLASS),
		tracer = newDrawing(LINE_CLASS),
	}
	objects.box.Thickness = 1
	objects.box.Filled = false
	objects.box.Transparency = 0.9
	objects.box.Color = Theme.accent

	objects.health.Thickness = 1
	objects.health.Filled = true
	objects.health.Transparency = 0.9
	objects.health.Color = Theme.good

	objects.name.Size = 13
	objects.name.Center = true
	objects.name.Outline = true
	objects.name.OutlineColor = Color3.new(0, 0, 0)
	objects.name.Transparency = 1
	objects.name.Color = Theme.text

	objects.distance.Size = 11
	objects.distance.Center = true
	objects.distance.Outline = true
	objects.distance.OutlineColor = Color3.new(0, 0, 0)
	objects.distance.Transparency = 1
	objects.distance.Color = Theme.subtext

	objects.tracer.Thickness = 1
	objects.tracer.Transparency = 0.55
	objects.tracer.Color = Theme.accent
	return objects
end

local function hideEsp(objects)
	objects.box.Visible = false
	objects.health.Visible = false
	objects.name.Visible = false
	objects.distance.Visible = false
	objects.tracer.Visible = false
end

local function updateEsp()
	if not hasDrawing then
		return
	end
	local viewport = Camera.ViewportSize
	local eye = Camera.CFrame.Position

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local objects = espObjects[player]
			if objects then
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local head = character and character:FindFirstChild("Head")
				local root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
				local drawn = false

				if State.esp.enabled and humanoid and head and root and humanoid.Health > 0 then
					local distance = (eye - root.Position).Magnitude
					local isFriendly = player.Team ~= nil and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team
					if distance <= State.esp.maxDistance and not (State.esp.teamCheck and isFriendly) then
						local top, topOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.55, 0))
						local bottom, bottomOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.5, 0))
						if topOn and bottomOn then
							local height = bottom.Y - top.Y
							local width = height * 0.5
							if height > 8 and height < 1600 then
								drawn = true
								local x = top.X - width * 0.5
								local y = top.Y
								local color = windowColorFor(player, isFriendly)

								if State.esp.box then
									objects.box.Visible = true
									objects.box.Position = Vector2.new(x, y)
									objects.box.Size = Vector2.new(width, height)
									objects.box.Color = color
								else
									objects.box.Visible = false
								end

								if State.esp.health then
									local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
									objects.health.Visible = true
									objects.health.Position = Vector2.new(x - 5, y + height * (1 - ratio))
									objects.health.Size = Vector2.new(2, math.max(height * ratio, 1))
									objects.health.Color = Color3.fromRGB(
										math.floor(255 * (1 - ratio)),
										math.floor(255 * ratio),
										90
									)
								else
									objects.health.Visible = false
								end

								if State.esp.name then
									objects.name.Visible = true
									objects.name.Text = player.Name
									objects.name.Position = Vector2.new(top.X, y - 15)
									objects.name.Color = color
								else
									objects.name.Visible = false
								end

								if State.esp.distance then
									objects.distance.Visible = true
									objects.distance.Text = string.format("%dm", math.floor(distance))
									objects.distance.Position = Vector2.new(top.X, y + height + 2)
								else
									objects.distance.Visible = false
								end

								if State.esp.tracer then
									objects.tracer.Visible = true
									objects.tracer.From = Vector2.new(viewport.X * 0.5, viewport.Y)
									objects.tracer.To = Vector2.new(top.X, y + height)
									objects.tracer.Color = color
								else
									objects.tracer.Visible = false
								end
							end
						end
					end
				end

				if not drawn then
					hideEsp(objects)
				end
			end
		end
	end
end

function windowColorFor(player, isFriendly)
	if isFriendly then
		return Theme.good
	end
	local ok, color = pcall(function()
		return player.TeamColor.Color
	end)
	if ok and typeof(color) == "Color3" then
		return color
	end
	return Theme.accent
end

local function inputMatches(input, target)
	if typeof(target) ~= "EnumItem" then
		return false
	end
	if target.EnumType == Enum.KeyCode then
		return input.KeyCode == target
	end
	if target.EnumType == Enum.UserInputType then
		return input.UserInputType == target
	end
	return false
end

local function isAimHeld()
	local target = State.aim.key
	if typeof(target) ~= "EnumItem" then
		return false
	end
	if target.EnumType == Enum.KeyCode then
		return UserInputService:IsKeyDown(target)
	end
	if target.EnumType == Enum.UserInputType then
		return UserInputService:IsMouseButtonPressed(target)
	end
	return false
end

bind(UserInputService.InputBegan, function(input)
	if inputMatches(input, State.menu.key) or input.KeyCode == Enum.KeyCode.Insert then
		toggleMenu()
	end
end)

bind(Players.PlayerRemoving, function(player)
	local objects = espObjects[player]
	if objects then
		for _, object in pairs(objects) do
			pcall(function()
				object:Remove()
			end)
		end
		espObjects[player] = nil
	end
end)

bind(RunService.RenderStepped, function()
	if workspace.CurrentCamera ~= Camera then
		Camera = workspace.CurrentCamera
	end
	if not Camera then
		return
	end

	local viewport = Camera.ViewportSize

	if fovRing then
		pcall(function()
			fovRing.Position = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
			fovRing.Radius = State.aim.fov
			fovRing.Visible = State.aim.showFov and not minimized
			fovRing.Color = Theme.accent
		end)
	end

	if State.aim.enabled and (State.aim.always or isAimHeld()) then
		local okAim, target = pcall(findTarget)
		if okAim and target then
			aimAt(target)
		end
	end

	if hasDrawing and State.esp.enabled then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and not espObjects[player] then
				local okCreate, objects = pcall(newEspObjects)
				if okCreate and objects then
					espObjects[player] = objects
				end
			end
		end
	end

	pcall(updateEsp)
end)

local dragging = false
local dragStart
local dragOrigin

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		dragOrigin = root.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

bind(UserInputService.InputChanged, function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		root.Position = UDim2.new(
			dragOrigin.X.Scale,
			dragOrigin.X.Offset + delta.X,
			dragOrigin.Y.Scale,
			dragOrigin.Y.Offset + delta.Y
		)
	end
end)

closeButton.MouseButton1Click:Connect(function()
	setMenuOpen(false)
end)

minButton.MouseButton1Click:Connect(function()
	setMinimized(not minimized)
end)

activate(tabButtons[1])

function unload()
	saveConfig()
	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	for _, objects in pairs(espObjects) do
		for _, object in pairs(objects) do
			pcall(function()
				object:Remove()
			end)
		end
	end
	if fovRing then
		pcall(function()
			fovRing:Remove()
		end)
	end
	pcall(function()
		screen:Destroy()
	end)
end

task.spawn(function()
	loadConfig()
end)

tween(scale, 0.26, { Scale = 1 }, Enum.EasingStyle.Quart)

if hasDrawing then
	print(string.format(
		"[alacrity] drawing: box=%s text=%s line=%s",
		tostring(BOX_CLASS),
		tostring(TEXT_CLASS),
		tostring(LINE_CLASS)
	))
end

task.delay(0.3, function()
	if mouseMove then
		toast("alacrity loaded · " .. bindName(State.menu.key) .. " toggles", 2.6)
	else
		toast("mousemoverel unavailable in this executor", 4)
	end
	if espLimited then
		local missing = {}
		if not BOX_CLASS then
			table.insert(missing, "box")
		end
		if not TEXT_CLASS then
			table.insert(missing, "text")
		end
		if not LINE_CLASS then
			table.insert(missing, "line")
		end
		toast("esp: no " .. table.concat(missing, "/") .. " in drawing api", 3.4)
	end
end)
