local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/valiantwolf/VapeV4ForRoblox/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local run = function(func)
	func()
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local lightingService = cloneref(game:GetService('Lighting'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local groupService = cloneref(game:GetService('GroupService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = {Enabled = false}
local Phase = {Enabled = false}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('newvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function calculateMoveVector(vec)
	local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function canClick()
	local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
	for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	for _, v in coreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do ind += 1 end
	return ind
end

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local visited, attempted, tpSwitch = {}, {}, false
local cacheExpire, cache = tick()
local function serverHop(pointer, filter)
	visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split('/') or {}
	if not table.find(visited, game.JobId) then
		table.insert(visited, game.JobId)
	end
	if not pointer then
		notif('Vape', 'Searching for an available server.', 2)
	end

	local suc, httpdata = pcall(function()
		return cacheExpire < tick() and game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder='..(filter == 'Ascending' and 1 or 2)..'&excludeFullGames=true&limit=100'..(pointer and '&cursor='..pointer or '')) or cache
	end)
	local data = suc and httpService:JSONDecode(httpdata) or nil
	if data and data.data then
		for _, v in data.data do
			if tonumber(v.playing) < playersService.MaxPlayers and not table.find(visited, v.id) and not table.find(attempted, v.id) then
				cacheExpire, cache = tick() + 60, httpdata
				table.insert(attempted, v.id)

				notif('Vape', 'Found! Teleporting.', 5)
				teleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
				return
			end
		end

		if data.nextPageCursor then
			serverHop(data.nextPageCursor, filter)
		else
			notif('Vape', 'Failed to find an available server.', 5, 'warning')
		end
	else
		notif('Vape', 'Failed to grab servers. ('..(data and data.errors[1].message or 'no data')..')', 5, 'warning')
	end
end

vape:Clean(lplr.OnTeleport:Connect(function()
	if not tpSwitch then
		tpSwitch = true
		queue_on_teleport("shared.vapeserverhoplist = '"..table.concat(visited, '/').."'\nshared.vapeserverhopprevious = '"..game.JobId.."'")
	end
end))

local frictionTable, oldfrict, entitylib = {}, {}
local function updateVelocity()
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, v in entitylib.character.Character:GetChildren() do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in oldfrict do
			i.CustomPhysicalProperties = v ~= 'none' and v or nil
		end
		table.clear(oldfrict)
	end
end

local function motorMove(target, cf)
	local part = Instance.new('Part')
	part.Anchored = true
	part.Parent = workspace
	local motor = Instance.new('Motor6D')
	motor.Part0 = target
	motor.Part1 = part
	motor.C1 = cf
	motor.Parent = part
	task.delay(0, part.Destroy, part)
end

local hash = loadstring(downloadFile('newvape/libraries/hash.lua'), 'hash')()
local prediction = loadstring(downloadFile('newvape/libraries/prediction.lua'), 'prediction')()
entitylib = loadstring(downloadFile('newvape/libraries/entity.lua'), 'entitylibrary')()
local whitelist = {
	alreadychecked = {},
	customtags = {},
	data = {WhitelistedUsers = {}},
	hashes = setmetatable({}, {
		__index = function(_, v)
			return hash and hash.sha512(v..'SelfReport') or ''
		end
	}),
	hooked = false,
	loaded = false,
	localprio = 0,
	said = {}
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash
vape.Libraries.auraanims = {
	Normal = {
		{CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)), Time = 0.1},
		{CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)), Time = 0.08},
		{CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)), Time = 0.03},
		{CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)), Time = 0.03}
	},
	Random = {},
	['Horizontal Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(-90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(180), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), 0, math.rad(-80)), Time = 0.12}
	},
	['Vertical Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(180), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(0, 0, math.rad(15)), Time = 0.12}
	},
	Exhibition = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2}
	},
	['Exhibition Old'] = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.15},
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.05},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05},
		{CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.15}
	}
}

local SpeedMethods
local SpeedMethodList = {'Velocity'}
SpeedMethods = {
	Velocity = function(options, moveDirection)
		local root = entitylib.character.RootPart
		root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end,
	Impulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
		if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
			root:ApplyImpulse(diff * root.AssemblyMass)
		end
	end,
	CFrame = function(options, moveDirection, dt)
		local root = entitylib.character.RootPart
		local dest = (moveDirection * math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
		if options.WallCheck.Enabled then
			options.rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			options.rayCheck.CollisionGroup = root.CollisionGroup
			local ray = workspace:Raycast(root.Position, dest, options.rayCheck)
			if ray then
				dest = ((ray.Position + ray.Normal) - root.Position)
			end
		end
		root.CFrame += dest
	end,
	TP = function(options, moveDirection)
		if options.TPTiming < tick() then
			options.TPTiming = tick() + options.TPFrequency.Value
			SpeedMethods.CFrame(options, moveDirection, 1)
		end
	end,
	WalkSpeed = function(options)
		if not options.WalkSpeed then options.WalkSpeed = entitylib.character.Humanoid.WalkSpeed end
		entitylib.character.Humanoid.WalkSpeed = options.Value.Value
	end,
	Pulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local dt = math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0)
		dt = dt * (1 - math.min((tick() % (options.PulseLength.Value + options.PulseDelay.Value)) / options.PulseLength.Value, 1))
		root.AssemblyLinearVelocity = (moveDirection * (entitylib.character.Humanoid.WalkSpeed + dt)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
}
for name in SpeedMethods do
	if not table.find(SpeedMethodList, name) then
		table.insert(SpeedMethodList, name)
	end
end

run(function()
	entitylib.getUpdateConnections = function(ent)
		local hum = ent.Humanoid
		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {
						Disconnect = function() end
					}
				end
			}
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		if vape.Categories.Main.Options['Teams by server'].Enabled then
			if not lplr.Team then return true end
			if not ent.Player.Team then return true end
			if ent.Player.Team ~= lplr.Team then return true end
			return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
		end
		return true
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
		if isFriend(ent, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
	end

	vape:Clean(function()
		entitylib.kill()
		entitylib = nil
	end)
	vape:Clean(vape.Categories.Friends.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(vape.Categories.Targets.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
	vape:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end))
end)

run(function()
	function whitelist:get(plr)
		local plrstr = self.hashes[plr.Name..plr.UserId]
		for _, v in self.data.WhitelistedUsers do
			if v.hash == plrstr then
				return v.level, v.attackable or whitelist.localprio >= v.level, v.tags
			end
		end
		return 0, true
	end

	function whitelist:isingame()
		for _, v in playersService:GetPlayers() do
			if self:get(v) ~= 0 then return true end
		end
		return false
	end

	function whitelist:tag(plr, text, rich)
		local plrtag, newtag = select(3, self:get(plr)) or self.customtags[plr.Name] or {}, ''
		if not text then return plrtag end
		for _, v in plrtag do
			newtag = newtag..(rich and '<font color="#'..v.color:ToHex()..'">['..v.text..']</font>' or '['..removeTags(v.text)..']')..' '
		end
		return newtag
	end

	function whitelist:getplayer(arg)
		if arg == 'default' and self.localprio == 0 then return true end
		if arg == 'private' and self.localprio == 1 then return true end
		if arg and lplr.Name:lower():sub(1, arg:len()) == arg:lower() then return true end
		return false
	end

	local olduninject
	function whitelist:playeradded(v, joined)
		if self:get(v) ~= 0 then
			if self.alreadychecked[v.UserId] then return end
			self.alreadychecked[v.UserId] = true
			self:hook()
			if self.localprio == 0 then
				olduninject = vape.Uninject
				vape.Uninject = function()
					notif('Vape', 'No escaping the private members :)', 10)
				end
				if joined then
					task.wait(10)
				end
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					local oldchannel = textChatService.ChatInputBarConfiguration.TargetTextChannel
					local newchannel = cloneref(game:GetService('RobloxReplicatedStorage')).ExperienceChat.WhisperChat:InvokeServer(v.UserId)
					if newchannel then
						newchannel:SendAsync('helloimusinginhaler')
					end
					textChatService.ChatInputBarConfiguration.TargetTextChannel = oldchannel
				elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('/w '..v.Name..' helloimusinginhaler', 'All')
				end
			end
		end
	end

	function whitelist:process(msg, plr)
		if plr == lplr and msg == 'helloimusinginhaler' then return true end

		if self.localprio > 0 and not self.said[plr.Name] and msg == 'helloimusinginhaler' and plr ~= lplr then
			self.said[plr.Name] = true
			notif('Vape', plr.Name..' is using vape!', 60)
			self.customtags[plr.Name] = {{
				text = 'VAPE USER',
				color = Color3.new(1, 1, 0)
			}}
			local newent = entitylib.getEntity(plr)
			if newent then
				entitylib.Events.EntityUpdated:Fire(newent)
			end
			return true
		end

		if self.localprio < self:get(plr) or plr == lplr then
			local args = msg:split(' ')
			table.remove(args, 1)
			if self:getplayer(args[1]) then
				table.remove(args, 1)
				for cmd, func in self.commands do
					if msg:sub(1, cmd:len() + 1):lower() == ';'..cmd:lower() then
						func(args, plr)
						return true
					end
				end
			end
		end

		return false
	end

	function whitelist:newchat(obj, plr, skip)
		obj.Text = self:tag(plr, true, true)..obj.Text
		local sub = obj.ContentText:find(': ')
		if sub then
			if not skip and self:process(obj.ContentText:sub(sub + 3, #obj.ContentText), plr) then
				obj.Visible = false
			end
		end
	end

	function whitelist:oldchat(func)
		local msgtable, oldchat = debug.getupvalue(func, 3)
		if typeof(msgtable) == 'table' and msgtable.CurrentChannel then
			whitelist.oldchattable = msgtable
		end

		oldchat = hookfunction(func, function(data, ...)
			local plr = playersService:GetPlayerByUserId(data.SpeakerUserId)
			if plr then
				data.ExtraData.Tags = data.ExtraData.Tags or {}
				for _, v in self:tag(plr) do
					table.insert(data.ExtraData.Tags, {TagText = v.text, TagColor = v.color})
				end
				if data.Message and self:process(data.Message, plr) then
					data.Message = ''
				end
			end
			return oldchat(data, ...)
		end)

		vape:Clean(function()
			hookfunction(func, oldchat)
		end)
	end

	function whitelist:hook()
		if self.hooked then return end
		self.hooked = true

		local exp = coreGui:FindFirstChild('ExperienceChat')
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			if exp and exp:WaitForChild('appLayout', 5) then
				vape:Clean(exp:FindFirstChild('RCTScrollContentView', true).ChildAdded:Connect(function(obj)
					local plr = playersService:GetPlayerByUserId(tonumber(obj.Name:split('-')[1]) or 0)
					obj = obj:FindFirstChild('TextMessage', true)
					if obj and obj:IsA('TextLabel') then
						if plr then
							self:newchat(obj, plr, true)
							obj:GetPropertyChangedSignal('Text'):Wait()
							self:newchat(obj, plr)
						end

						if obj.ContentText:sub(1, 35) == 'You are now privately chatting with' then
							obj.Visible = false
						end
					end
				end))
			end
		elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
			pcall(function()
				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewMessage.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessagePostedInChannel') then
						whitelist:oldchat(v.Function)
						break
					end
				end

				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessageFiltered') then
						whitelist:oldchat(v.Function)
						break
					end
				end
			end)
		end

		if exp then
			local bubblechat = exp:WaitForChild('bubbleChat', 5)
			if bubblechat then
				vape:Clean(bubblechat.DescendantAdded:Connect(function(newbubble)
					if newbubble:IsA('TextLabel') and newbubble.Text:find('helloimusinginhaler') then
						newbubble.Parent.Parent.Visible = false
					end
				end))
			end
		end
	end

	function whitelist:update(first)
		local suc = pcall(function()
			local _, subbed = pcall(function()
				return game:HttpGet('https://github.com/7GrandDadPGN/whitelists')
			end)
			local commit = subbed:find('currentOid')
			commit = commit and subbed:sub(commit + 13, commit + 52) or nil
			commit = commit and #commit == 40 and commit or 'main'
			whitelist.textdata = game:HttpGet('https://raw.githubusercontent.com/7GrandDadPGN/whitelists/'..commit..'/PlayerWhitelist.json', true)
		end)
		if not suc or not hash or not whitelist.get then return true end
		whitelist.loaded = true

		if not first or whitelist.textdata ~= whitelist.olddata then
			if not first then
				whitelist.olddata = isfile('newvape/profiles/whitelist.json') and readfile('newvape/profiles/whitelist.json') or nil
			end

			local suc, res = pcall(function()
				return httpService:JSONDecode(whitelist.textdata)
			end)

			whitelist.data = suc and type(res) == 'table' and res or whitelist.data
			whitelist.localprio = whitelist:get(lplr)

			for _, v in whitelist.data.WhitelistedUsers do
				if v.tags then
					for _, tag in v.tags do
						tag.color = Color3.fromRGB(unpack(tag.color))
					end
				end
			end

			if not whitelist.connection then
				whitelist.connection = playersService.PlayerAdded:Connect(function(v)
					whitelist:playeradded(v, true)
				end)
				vape:Clean(whitelist.connection)
			end

			for _, v in playersService:GetPlayers() do
				whitelist:playeradded(v)
			end

			if entitylib.Running and vape.Loaded then
				entitylib.refresh()
			end

			if whitelist.textdata ~= whitelist.olddata then
				if whitelist.data.Announcement.expiretime > os.time() then
					local targets = whitelist.data.Announcement.targets
					targets = targets == 'all' and {tostring(lplr.UserId)} or targets:split(',')

					if table.find(targets, tostring(lplr.UserId)) then
						local hint = Instance.new('Hint')
						hint.Text = 'VAPE ANNOUNCEMENT: '..whitelist.data.Announcement.text
						hint.Parent = workspace
						game:GetService('Debris'):AddItem(hint, 20)
					end
				end
				whitelist.olddata = whitelist.textdata
				pcall(function()
					writefile('newvape/profiles/whitelist.json', whitelist.textdata)
				end)
			end

			if whitelist.data.KillVape then
				vape:Uninject()
				return true
			end

			if whitelist.data.BlacklistedUsers[tostring(lplr.UserId)] then
				task.spawn(lplr.kick, lplr, whitelist.data.BlacklistedUsers[tostring(lplr.UserId)])
				return true
			end
		end
	end

	whitelist.commands = {
		byfron = function()
			task.spawn(function()
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				local UIBlox = getrenv().require(game:GetService('CorePackages').UIBlox)
				local Roact = getrenv().require(game:GetService('CorePackages').Roact)
				UIBlox.init(getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppUIBloxConfig))
				local auth = getrenv().require(coreGui.RobloxGui.Modules.LuaApp.Components.Moderation.ModerationPrompt)
				local darktheme = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Style).Themes.DarkTheme
				local fonttokens = getrenv().require(game:GetService("CorePackages").Packages._Index.UIBlox.UIBlox.App.Style.Tokens).getTokens('Desktop', 'Dark', true)
				local buildersans = getrenv().require(game:GetService('CorePackages').Packages._Index.UIBlox.UIBlox.App.Style.Fonts.FontLoader).new(true, fonttokens):loadFont()
				local tLocalization = getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppLocales).Localization
				local localProvider = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Localization).LocalizationProvider
				lplr.PlayerGui:ClearAllChildren()
				vape.gui.Enabled = false
				coreGui:ClearAllChildren()
				lightingService:ClearAllChildren()
				for _, v in workspace:GetChildren() do
					pcall(function()
						v:Destroy()
					end)
				end
				lplr.kick(lplr)
				guiService:ClearError()
				local gui = Instance.new('ScreenGui')
				gui.IgnoreGuiInset = true
				gui.Parent = coreGui
				local frame = Instance.new('ImageLabel')
				frame.BorderSizePixel = 0
				frame.Size = UDim2.fromScale(1, 1)
				frame.BackgroundColor3 = Color3.fromRGB(224, 223, 225)
				frame.ScaleType = Enum.ScaleType.Crop
				frame.Parent = gui
				task.delay(0.3, function()
					frame.Image = 'rbxasset://textures/ui/LuaApp/graphic/Auth/GridBackground.jpg'
				end)
				task.delay(0.6, function()
					local modPrompt = Roact.createElement(auth, {
						style = {},
						screenSize = vape.gui.AbsoluteSize or Vector2.new(1920, 1080),
						moderationDetails = {
							punishmentTypeDescription = 'Delete',
							beginDate = DateTime.fromUnixTimestampMillis(DateTime.now().UnixTimestampMillis - ((60 * math.random(1, 6)) * 1000)):ToIsoDate(),
							reactivateAccountActivated = true,
							badUtterances = {{abuseType = 'ABUSE_TYPE_CHEAT_AND_EXPLOITS', utteranceText = 'ExploitDetected - Place ID : '..game.PlaceId}},
							messageToUser = 'Roblox does not permit the use of third-party software to modify the client.'
						},
						termsActivated = function() end,
						communityGuidelinesActivated = function() end,
						supportFormActivated = function() end,
						reactivateAccountActivated = function() end,
						logoutCallback = function() end,
						globalGuiInset = {top = 0}
					})

					local screengui = Roact.createElement(localProvider, {
						localization = tLocalization.new('en-us')
					}, {Roact.createElement(UIBlox.Style.Provider, {
						style = {
							Theme = darktheme,
							Font = buildersans
						},
					}, {modPrompt})})

					Roact.mount(screengui, coreGui)
				end)
			end)
		end,
		crash = function()
			task.spawn(function()
				repeat
					local part = Instance.new('Part')
					part.Size = Vector3.new(1e10, 1e10, 1e10)
					part.Parent = workspace
				until false
			end)
		end,
		deletemap = function()
			local terrain = workspace:FindFirstChildWhichIsA('Terrain')
			if terrain then
				terrain:Clear()
			end

			for _, v in workspace:GetChildren() do
				if v ~= terrain and not v:IsDescendantOf(lplr.Character) and not v:IsA('Camera') then
					v:Destroy()
					v:ClearAllChildren()
				end
			end
		end,
		framerate = function(args)
			if #args < 1 or not setfpscap then return end
			setfpscap(tonumber(args[1]) ~= '' and math.clamp(tonumber(args[1]) or 9999, 1, 9999) or 9999)
		end,
		gravity = function(args)
			workspace.Gravity = tonumber(args[1]) or workspace.Gravity
		end,
		jump = function()
			if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end,
		kick = function(args)
			task.spawn(function()
				lplr:Kick(table.concat(args, ' '))
			end)
		end,
		kill = function()
			if entitylib.isAlive then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				entitylib.character.Humanoid.Health = 0
			end
		end,
		reveal = function()
			task.delay(0.1, function()
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('I am using the inhaler client')
				else
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('I am using the inhaler client', 'All')
				end
			end)
		end,
		shutdown = function()
			game:Shutdown()
		end,
		toggle = function(args)
			if #args < 1 then return end
			if args[1]:lower() == 'all' then
				for i, v in vape.Modules do
					if i ~= 'Panic' and i ~= 'ServerHop' and i ~= 'Rejoin' then
						v:Toggle()
					end
				end
			else
				for i, v in vape.Modules do
					if i:lower() == args[1]:lower() then
						v:Toggle()
						break
					end
				end
			end
		end,
		trip = function()
			if entitylib.isAlive then
				if entitylib.character.RootPart.Velocity.Magnitude < 15 then
					entitylib.character.RootPart.Velocity = entitylib.character.RootPart.CFrame.LookVector * 15
				end
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
			end
		end,
		uninject = function()
			if olduninject then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				olduninject(vape)
			else
				vape:Uninject()
			end
		end,
		void = function()
			if entitylib.isAlive then
				entitylib.character.RootPart.CFrame += Vector3.new(0, -1000, 0)
			end
		end
	}

	task.spawn(function()
		repeat
			if whitelist:update(whitelist.loaded) then return end
			task.wait(10)
		until vape.Loaded == nil
	end)

	vape:Clean(function()
		table.clear(whitelist.commands)
		table.clear(whitelist.data)
		table.clear(whitelist)
	end)
end)
entitylib.start()
run(function()
	local AimAssist
	local Targets
	local Part
	local FOV
	local Speed
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local RightClick
	local ShowTarget
	local moveConst = Vector2.new(1, 0.77) * math.rad(0.5)
	
	local function wrapAngle(num)
		num = num % math.pi
		num -= num >= (math.pi / 2) and math.pi or 0
		num += num < -(math.pi / 2) and math.pi or 0
		return num
	end
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback
			end
			if callback then
				local ent
				local rightClicked = not RightClick.Enabled or inputService:IsMouseButtonPressed(1)
				AimAssist:Clean(runService.RenderStepped:Connect(function(dt)
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end
	
					if rightClicked and not vape.gui.ScaledGui.ClickGui.Visible then
						ent = entitylib.EntityMouse({
							Range = FOV.Value,
							Part = Part.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled,
							Origin = gameCamera.CFrame.Position
						})
	
						if ent then
							local facing = gameCamera.CFrame.LookVector
							local new = (ent[Part.Value].Position - gameCamera.CFrame.Position).Unit
							new = new == new and new or Vector3.zero
	
							if ShowTarget.Enabled then
								targetinfo.Targets[ent] = tick() + 1
							end
	
							if new ~= Vector3.zero then
								local diffYaw = wrapAngle(math.atan2(facing.X, facing.Z) - math.atan2(new.X, new.Z))
								local diffPitch = math.asin(facing.Y) - math.asin(new.Y)
								local angle = Vector2.new(diffYaw, diffPitch) // (moveConst * UserSettings():GetService('UserGameSettings').MouseSensitivity)
	
								angle *= math.min(Speed.Value * dt, 1)
								mousemoverel(angle.X, angle.Y)
							end
						end
					end
				end))
	
				if RightClick.Enabled then
					AimAssist:Clean(inputService.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							ent = nil
							rightClicked = true
						end
					end))
	
					AimAssist:Clean(inputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							rightClicked = false
						end
					end))
				end
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target'
	})
	Targets = AimAssist:CreateTargets({Players = true})
	Part = AimAssist:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = AimAssist:CreateSlider({
		Name = 'FOV',
		Min = 0,
		Max = 1000,
		Default = 100,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end
	})
	Speed = AimAssist:CreateSlider({
		Name = 'Speed',
		Min = 0,
		Max = 30,
		Default = 15
	})
	AimAssist:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = FOV.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = AimAssist.Enabled
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = AimAssist:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = AimAssist:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = AimAssist:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
	RightClick = AimAssist:CreateToggle({
		Name = 'Require right click',
		Function = function()
			if AimAssist.Enabled then
				AimAssist:Toggle()
				AimAssist:Toggle()
			end
		end
	})
	ShowTarget = AimAssist:CreateToggle({
		Name = 'Show target info'
	})
end)
	
run(function()
	local AutoClicker
	local Mode
	local CPS
	
	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				repeat
					if Mode.Value == 'Tool' then
						local tool = getTool()
						if tool and inputService:IsMouseButtonPressed(0) then
							tool:Activate()
						end
					else
						if mouse1click and (isrbxactive or iswindowactive)() then
							if not vape.gui.ScaledGui.ClickGui.Visible then
								(Mode.Value == 'Click' and mouse1click or mouse2click)()
							end
						end
					end
	
					task.wait(1 / CPS.GetRandomValue())
				until not AutoClicker.Enabled
			end
		end,
		Tooltip = 'Automatically clicks for you'
	})
	Mode = AutoClicker:CreateDropdown({
		Name = 'Mode',
		List = {'Tool', 'Click', 'RightClick'},
		Tooltip = 'Tool - Automatically uses roblox tools (eg. swords)\nClick - Left click\nRightClick - Right click'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 8,
		DefaultMax = 12
	})
end)
	
run(function()
	local Reach
	local Targets
	local Mode
	local Value
	local Chance
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local modified = {}
	
	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				repeat
					local tool = getTool()
					tool = tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true)
					if tool then
						if Mode.Value == 'TouchInterest' then
							local entites = {}
							for _, v in entitylib.List do
								if v.Targetable then
									if not Targets.Players.Enabled and v.Player then continue end
									if not Targets.NPCs.Enabled and v.NPC then continue end
									table.insert(entites, v.Character)
								end
							end
	
							Overlay.FilterDescendantsInstances = entites
							local parts = workspace:GetPartBoundsInBox(tool.Parent.CFrame * CFrame.new(0, 0, Value.Value / 2), tool.Parent.Size + Vector3.new(0, 0, Value.Value), Overlay)
	
							for _, v in parts do
								if Random.new().NextNumber(Random.new(), 0, 100) > Chance.Value then
									task.wait(0.2)
									break
								end
	
								firetouchinterest(tool.Parent, v, 1)
								firetouchinterest(tool.Parent, v, 0)
							end
						else
							if not modified[tool.Parent] then
								modified[tool.Parent] = tool.Parent.Size
							end
							tool.Parent.Size = modified[tool.Parent] + Vector3.new(0, 0, Value.Value)
							tool.Parent.Massless = true
						end
					end
	
					task.wait()
				until not Reach.Enabled
			else
				for i, v in modified do
					i.Size = v
					i.Massless = false
				end
				table.clear(modified)
			end
		end,
		Tooltip = 'Extends tool attack reach'
	})
	Targets = Reach:CreateTargets({Players = true})
	Mode = Reach:CreateDropdown({
		Name = 'Mode',
		List = {'TouchInterest', 'Resize'},
		Function = function(val)
			Chance.Object.Visible = val == 'TouchInterest'
		end,
		Tooltip = 'TouchInterest - Reports fake collision events to the server\nResize - Physically modifies the tools size'
	})
	Value = Reach:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 2,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Chance = Reach:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
	
local mouseClicked
run(function()
	local SilentAim
	local Target
	local Mode
	local Method
	local MethodRay
	local IgnoredScripts
	local Range
	local HitChance
	local HeadshotChance
	local AutoFire
	local AutoFireShootDelay
	local AutoFireMode
	local AutoFirePosition
	local Wallbang
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local Projectile
	local ProjectileSpeed
	local ProjectileGravity
	local RaycastWhitelist = RaycastParams.new()
	RaycastWhitelist.FilterType = Enum.RaycastFilterType.Include
	local ProjectileRaycast = RaycastParams.new()
	ProjectileRaycast.RespectCanCollide = true
	local fireoffset, rand, delayCheck = CFrame.identity, Random.new(), tick()
	local oldnamecall, oldray

	local function getTarget(origin, obj)
		if rand.NextNumber(rand, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then return end
		local targetPart = (rand.NextNumber(rand, 0, 100) < (AutoFire.Enabled and 100 or HeadshotChance.Value)) and 'Head' or 'RootPart'
		local ent = entitylib['Entity'..Mode.Value]({
			Range = Range.Value,
			Wallcheck = Target.Walls.Enabled and (obj or true) or nil,
			Part = targetPart,
			Origin = origin,
			Players = Target.Players.Enabled,
			NPCs = Target.NPCs.Enabled
		})

		if ent then
			targetinfo.Targets[ent] = tick() + 1
			if Projectile.Enabled then
				ProjectileRaycast.FilterDescendantsInstances = {gameCamera, ent.Character}
				ProjectileRaycast.CollisionGroup = ent[targetPart].CollisionGroup
			end
		end

		return ent, ent and ent[targetPart], origin
	end

	local Hooks = {
		FindPartOnRayWithIgnoreList = function(args)
			local ent, targetPart, origin = getTarget(args[1].Origin, {args[2]})
			if not ent then return end
			if Wallbang.Enabled then
				return {targetPart, targetPart.Position, targetPart.GetClosestPointOnSurface(targetPart, origin), targetPart.Material}
			end
			args[1] = Ray.new(origin, CFrame.lookAt(origin, targetPart.Position).LookVector * args[1].Direction.Magnitude)
		end,
		Raycast = function(args)
			if MethodRay.Value ~= 'All' and args[3] and args[3].FilterType ~= Enum.RaycastFilterType[MethodRay.Value] then return end
			local ent, targetPart, origin = getTarget(args[1])
			if not ent then return end
			args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
			if Wallbang.Enabled then
				RaycastWhitelist.FilterDescendantsInstances = {targetPart}
				args[3] = RaycastWhitelist
			end
		end,
		ScreenPointToRay = function(args)
			local ent, targetPart, origin = getTarget(gameCamera.CFrame.Position)
			if not ent then return end
			local direction = CFrame.lookAt(origin, targetPart.Position)
			if Projectile.Enabled then
				local calc = prediction.SolveTrajectory(origin, ProjectileSpeed.Value, ProjectileGravity.Value, targetPart.Position, targetPart.Velocity, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
				if not calc then return end
				direction = CFrame.lookAt(origin, calc)
			end
			return {Ray.new(origin + (args[3] and direction.LookVector * args[3] or Vector3.zero), direction.LookVector)}
		end,
		Ray = function(args)
			local ent, targetPart, origin = getTarget(args[1])
			if not ent then return end
			if Projectile.Enabled then
				local calc = prediction.SolveTrajectory(origin, ProjectileSpeed.Value, ProjectileGravity.Value, targetPart.Position, targetPart.Velocity, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
				if not calc then return end
				args[2] = CFrame.lookAt(origin, calc).LookVector * args[2].Magnitude
			else
				args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
			end
		end
	}
	Hooks.FindPartOnRayWithWhitelist = Hooks.FindPartOnRayWithIgnoreList
	Hooks.FindPartOnRay = Hooks.FindPartOnRayWithIgnoreList
	Hooks.ViewportPointToRay = Hooks.ScreenPointToRay

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback and Mode.Value == 'Mouse'
			end
			if callback then
				if Method.Value == 'Ray' then
					oldray = hookfunction(Ray.new, function(origin, direction)
						if checkcaller() then
							return oldray(origin, direction)
						end
						local calling = getcallingscript()

						if calling then
							local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {'ControlScript', 'ControlModule'}
							if table.find(list, tostring(calling)) then
								return oldray(origin, direction)
							end
						end

						local args = {origin, direction}
						Hooks.Ray(args)
						return oldray(unpack(args))
					end)
				else
					oldnamecall = hookmetamethod(game, '__namecall', function(...)
						if getnamecallmethod() ~= Method.Value then
							return oldnamecall(...)
						end
						if checkcaller() then
							return oldnamecall(...)
						end

						local calling = getcallingscript()
						if calling then
							local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {'ControlScript', 'ControlModule'}
							if table.find(list, tostring(calling)) then
								return oldnamecall(...)
							end
						end

						local self, args = ..., {select(2, ...)}
						local res = Hooks[Method.Value](args)
						if res then
							return unpack(res)
						end
						return oldnamecall(self, unpack(args))
					end)
				end

				repeat
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end
					if AutoFire.Enabled then
						local origin = AutoFireMode.Value == 'Camera' and gameCamera.CFrame or entitylib.isAlive and entitylib.character.RootPart.CFrame or CFrame.identity
						local ent = entitylib['Entity'..Mode.Value]({
							Range = Range.Value,
							Wallcheck = Target.Walls.Enabled or nil,
							Part = 'Head',
							Origin = (origin * fireoffset).Position,
							Players = Target.Players.Enabled,
							NPCs = Target.NPCs.Enabled
						})

						if mouse1click and (isrbxactive or iswindowactive)() then
							if ent and canClick() then
								if delayCheck < tick() then
									if mouseClicked then
										mouse1release()
										delayCheck = tick() + AutoFireShootDelay.Value
									else
										mouse1press()
									end
									mouseClicked = not mouseClicked
								end
							else
								if mouseClicked then
									mouse1release()
								end
								mouseClicked = false
							end
						end
					end
					task.wait()
				until not SilentAim.Enabled
			else
				if oldnamecall then
					hookmetamethod(game, '__namecall', oldnamecall)
				end
				if oldray then
					hookfunction(Ray.new, oldray)
				end
				oldnamecall, oldray = nil, nil
			end
		end,
		ExtraText = function()
			return Method.Value:gsub('FindPartOnRay', '')
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Target = SilentAim:CreateTargets({Players = true})
	Mode = SilentAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			if CircleObject then
				CircleObject.Visible = SilentAim.Enabled and val == 'Mouse'
			end
		end,
		Tooltip = 'Mouse - Checks for entities near the mouses position\nPosition - Checks for entities near the local character'
	})
	Method = SilentAim:CreateDropdown({
		Name = 'Method',
		List = {'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Raycast', 'Ray'},
		Function = function(val)
			if SilentAim.Enabled then
				SilentAim:Toggle()
				SilentAim:Toggle()
			end
			MethodRay.Object.Visible = val == 'Raycast'
		end,
		Tooltip = 'FindPartOnRay* - Deprecated methods of raycasting used in old games\nRaycast - The modern raycast method\nPointToRay - Method to generate a ray from screen coords\nRay - Hooking Ray.new'
	})
	MethodRay = SilentAim:CreateDropdown({
		Name = 'Raycast Type',
		List = {'All', 'Exclude', 'Include'},
		Darker = true,
		Visible = false
	})
	IgnoredScripts = SilentAim:CreateTextList({Name = 'Ignored Scripts'})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	HitChance = SilentAim:CreateSlider({
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 85,
		Suffix = '%'
	})
	HeadshotChance = SilentAim:CreateSlider({
		Name = 'Headshot Chance',
		Min = 0,
		Max = 100,
		Default = 65,
		Suffix = '%'
	})
	AutoFire = SilentAim:CreateToggle({
		Name = 'AutoFire',
		Function = function(callback)
			AutoFireShootDelay.Object.Visible = callback
			AutoFireMode.Object.Visible = callback
			AutoFirePosition.Object.Visible = callback
		end
	})
	AutoFireShootDelay = SilentAim:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Visible = false,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	AutoFireMode = SilentAim:CreateDropdown({
		Name = 'Origin',
		List = {'RootPart', 'Camera'},
		Visible = false,
		Darker = true,
		Tooltip = 'Determines the position to check for before shooting'
	})
	AutoFirePosition = SilentAim:CreateTextBox({
		Name = 'Offset',
		Function = function()
			local suc, res = pcall(function()
				return CFrame.new(unpack(AutoFirePosition.Value:split(',')))
			end)
			if suc then fireoffset = res end
		end,
		Default = '0, 0, 0',
		Visible = false,
		Darker = true
	})
	Wallbang = SilentAim:CreateToggle({Name = 'Wallbang'})
	SilentAim:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = Range.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = SilentAim.Enabled and Mode.Value == 'Mouse'
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = SilentAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = SilentAim:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = SilentAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
	Projectile = SilentAim:CreateToggle({
		Name = 'Projectile',
		Function = function(callback)
			ProjectileSpeed.Object.Visible = callback
			ProjectileGravity.Object.Visible = callback
		end
	})
	ProjectileSpeed = SilentAim:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	ProjectileGravity = SilentAim:CreateSlider({
		Name = 'Gravity',
		Min = 0,
		Max = 192.6,
		Default = 192.6,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local TriggerBot
	local Targets
	local ShootDelay
	local Distance
	local rayCheck, delayCheck = RaycastParams.new(), tick()
	
	local function getTriggerBotTarget()
		rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
	
		local ray = workspace:Raycast(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Distance.Value, rayCheck)
		if ray and ray.Instance then
			for _, v in entitylib.List do
				if v.Targetable and v.Character and (Targets.Players.Enabled and v.Player or Targets.NPCs.Enabled and v.NPC) then
					if ray.Instance:IsDescendantOf(v.Character) then
						return entitylib.isVulnerable(v) and v
					end
				end
			end
		end
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					if mouse1click and (isrbxactive or iswindowactive)() then
						if getTriggerBotTarget() and canClick() then
							if delayCheck < tick() then
								if mouseClicked then
									mouse1release()
									delayCheck = tick() + ShootDelay.Value
								else
									mouse1press()
								end
								mouseClicked = not mouseClicked
							end
						else
							if mouseClicked then
								mouse1release()
							end
							mouseClicked = false
						end
					end
					task.wait()
				until not TriggerBot.Enabled
			else
				if mouse1click and (isrbxactive or iswindowactive)() then
					if mouseClicked then
						mouse1release()
					end
				end
				mouseClicked = false
			end
		end,
		Tooltip = 'Shoots people that enter your crosshair'
	})
	Targets = TriggerBot:CreateTargets({
		Players = true,
		NPCs = true
	})
	ShootDelay = TriggerBot:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'The delay set after shooting a target'
	})
	Distance = TriggerBot:CreateSlider({
		Name = 'Distance',
		Min = 0,
		Max = 1000,
		Default = 1000,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local AntiFall
	local Method
	local Mode
	local Material
	local Color
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local part
	
	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				if Method.Value == 'Part' then
					local debounce = tick()
					part = Instance.new('Part')
					part.Size = Vector3.new(10000, 1, 10000)
					part.Transparency = 1 - Color.Opacity
					part.Material = Enum.Material[Material.Value]
					part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					part.CanCollide = Mode.Value == 'Collide'
					part.Anchored = true
					part.CanQuery = false
					part.Parent = workspace
					AntiFall:Clean(part)
					AntiFall:Clean(part.Touched:Connect(function(touchedpart)
						if touchedpart.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
							local root = entitylib.character.RootPart
							debounce = tick() + 0.1
							if Mode.Value == 'Velocity' then
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 100, root.AssemblyLinearVelocity.Z)
							elseif Mode.Value == 'Impulse' then
								root:ApplyImpulse(Vector3.new(0, (100 - root.AssemblyLinearVelocity.Y), 0) * root.AssemblyMass)
							end
						end
					end))
	
					repeat
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character, part}
							rayCheck.CollisionGroup = root.CollisionGroup
							local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
							if ray then
								part.Position = ray.Position - Vector3.new(0, 15, 0)
							end
						end
						task.wait(0.1)
					until not AntiFall.Enabled
				else
					local lastpos
					AntiFall:Clean(runService.PreSimulation:Connect(function()
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							lastpos = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and root.Position or lastpos
							if (root.Position.Y + (root.Velocity.Y * 0.016)) <= (workspace.FallenPartsDestroyHeight + 10) then
								lastpos = lastpos or Vector3.new(root.Position.X, (workspace.FallenPartsDestroyHeight + 20), root.Position.Z)
								root.CFrame += (lastpos - root.Position)
								root.Velocity *= Vector3.new(1, 0, 1)
							end
						end
					end))
				end
			end
		end,
		Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
	})
	Method = AntiFall:CreateDropdown({
		Name = 'Method',
		List = {'Part', 'Classic'},
		Function = function(val)
			if Mode.Object then
				Mode.Object.Visible = val == 'Part'
				Material.Object.Visible = val == 'Part'
				Color.Object.Visible = val == 'Part'
			end
			if AntiFall.Enabled then
				AntiFall:Toggle()
				AntiFall:Toggle()
			end
		end,
		Tooltip = 'Part - Moves a part under you that does various methods to stop you from falling\nClassic - Teleports you out of the void after reaching the part destroy plane'
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Impulse', 'Velocity', 'Collide'},
		Darker = true,
		Function = function(val)
			if part then
				part.CanCollide = val == 'Collide'
			end
		end,
		Tooltip = 'Velocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = AntiFall:CreateDropdown({
		Name = 'Material',
		List = materials,
		Darker = true,
		Function = function(val)
			if part then
				part.Material = Enum.Material[val]
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Darker = true,
		Function = function(h, s, v, o)
			if part then
				part.Color = Color3.fromHSV(h, s, v)
				part.Transparency = 1 - o
			end
		end
	})
end)
	
local Fly
local LongJump
run(function()
	local Options = {TPTiming = tick()}
	local Mode
	local FloatMode
	local State
	local MoveMethod
	local Keys
	local VerticalValue
	local BounceLength
	local BounceDelay
	local FloatTPGround
	local FloatTPAir
	local CustomProperties
	local WallCheck
	local PlatformStanding
	local Platform, YLevel, OldYLevel
	local w, s, a, d, up, down = 0, 0, 0, 0, 0, 0
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	Options.rayCheck = rayCheck

	local Functions
	Functions = {
		Velocity = function()
			entitylib.character.RootPart.Velocity = (entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)) + Vector3.new(0, 2.25 + ((up + down) * VerticalValue.Value), 0)
		end,
		Impulse = function(options, moveDirection)
			local root = entitylib.character.RootPart
			local diff = (Vector3.new(0, 2.25 + ((up + down) * VerticalValue.Value), 0) - root.AssemblyLinearVelocity) * Vector3.new(0, 1, 0)
			if diff.Magnitude > 2 then
				root:ApplyImpulse(diff * root.AssemblyMass)
			end
		end,
		CFrame = function(dt)
			local root = entitylib.character.RootPart
			if not YLevel then
				YLevel = root.Position.Y
			end
			YLevel = YLevel + ((up + down) * VerticalValue.Value * dt)
			if WallCheck.Enabled then
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				rayCheck.CollisionGroup = root.CollisionGroup
				local ray = workspace:Raycast(root.Position, Vector3.new(0, YLevel - root.Position.Y, 0), rayCheck)
				if ray then
					YLevel = ray.Position.Y + entitylib.character.HipHeight
				end
			end
			root.Velocity *= Vector3.new(1, 0, 1)
			root.CFrame += Vector3.new(0, YLevel - root.Position.Y, 0)
		end,
		Bounce = function()
			Functions.Velocity()
			entitylib.character.RootPart.Velocity += Vector3.new(0, ((tick() % BounceDelay.Value) / BounceDelay.Value > 0.5 and 1 or -1) * BounceLength.Value, 0)
		end,
		Floor = function()
			Platform.CFrame = down ~= 0 and CFrame.identity or entitylib.character.RootPart.CFrame + Vector3.new(0, -(entitylib.character.HipHeight + 0.5), 0)
		end,
		TP = function(dt)
			Functions.CFrame(dt)
			if tick() % (FloatTPAir.Value + FloatTPGround.Value) > FloatTPAir.Value then
				OldYLevel = OldYLevel or YLevel
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				rayCheck.CollisionGroup = entitylib.character.RootPart.CollisionGroup
				local ray = workspace:Raycast(entitylib.character.RootPart.Position, Vector3.new(0, -1000, 0), rayCheck)
				if ray then
					YLevel = ray.Position.Y + entitylib.character.HipHeight
				end
			else
				if OldYLevel then
					YLevel = OldYLevel
					OldYLevel = nil
				end
			end
		end,
		Jump = function(dt)
			local root = entitylib.character.RootPart
			if not YLevel then
				YLevel = root.Position.Y
			end
			YLevel = YLevel + ((up + down) * VerticalValue.Value * dt)
			if root.Position.Y < YLevel then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	}

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			if Platform then
				Platform.Parent = callback and gameCamera or nil
			end
			frictionTable.Fly = callback and CustomProperties.Enabled or nil
			updateVelocity()
			if callback then
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						if PlatformStanding.Enabled then
							entitylib.character.Humanoid.PlatformStand = true
							entitylib.character.RootPart.RotVelocity = Vector3.zero
							entitylib.character.RootPart.CFrame = CFrame.lookAlong(entitylib.character.RootPart.CFrame.Position, gameCamera.CFrame.LookVector)
						end
						if State.Value ~= 'None' then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType[State.Value])
						end
						SpeedMethods[Mode.Value](Options, TargetStrafeVector or MoveMethod.Value == 'Direct' and calculateMoveVector(Vector3.new(a + d, 0, w + s)) or entitylib.character.Humanoid.MoveDirection, dt)
						Functions[FloatMode.Value](dt)
					else
						YLevel = nil
						OldYLevel = nil
					end
				end))

				w, s, a, d = inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
				up, down = 0, 0
				for _, v in {'InputBegan', 'InputEnded'} do
					Fly:Clean(inputService[v]:Connect(function(input)
						if not inputService:GetFocusedTextBox() then
							local divided = Keys.Value:split('/')
							if input.KeyCode == Enum.KeyCode.W then
								w = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.S then
								s = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode.A then
								a = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.D then
								d = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode[divided[1]] then
								up = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode[divided[2]] then
								down = v == 'InputBegan' and -1 or 0
							end
						end
					end))
				end
				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				YLevel, OldYLevel = nil, nil
				if entitylib.isAlive and PlatformStanding.Enabled then
					entitylib.character.Humanoid.PlatformStand = false
				end
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Makes you go zoom.'
	})
	Mode = Fly:CreateDropdown({
		Name = 'Speed Mode',
		List = SpeedMethodList,
		Function = function(val)
			WallCheck.Object.Visible = FloatMode.Value == 'CFrame' or FloatMode.Value == 'TP' or val == 'CFrame' or val == 'TP'
			Options.TPFrequency.Object.Visible = val == 'TP'
			Options.PulseLength.Object.Visible = val == 'Pulse'
			Options.PulseDelay.Object.Visible = val == 'Pulse'
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end,
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Large teleports within intervals\nPulse - Controllable bursts of speed\nWalkSpeed - The classic mode of speed, usually detected on most games.'
	})
	FloatMode = Fly:CreateDropdown({
		Name = 'Float Mode',
		List = {'Velocity', 'Impulse', 'CFrame', 'Bounce', 'Floor', 'Jump', 'TP'},
		Function = function(val)
			WallCheck.Object.Visible = Mode.Value == 'CFrame' or Mode.Value == 'TP' or val == 'CFrame' or val == 'TP'
			BounceLength.Object.Visible = val == 'Bounce'
			BounceDelay.Object.Visible = val == 'Bounce'
			VerticalValue.Object.Visible = val ~= 'Floor'
			FloatTPGround.Object.Visible = val == 'TP'
			FloatTPAir.Object.Visible = val == 'TP'
			if Platform then
				Platform:Destroy()
				Platform = nil
			end
			if val == 'Floor' then
				Platform = Instance.new('Part')
				Platform.CanQuery = false
				Platform.Anchored = true
				Platform.Size = Vector3.one
				Platform.Transparency = 1
				Platform.Parent = Fly.Enabled and gameCamera or nil
			end
		end,
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Teleports you to the ground within intervals\nFloor - Spawns a part under you\nJump - Presses space after going below a certain Y Level\nBounce - Vertical bouncing motion'
	})
	local states = {'None'}
	for _, v in Enum.HumanoidStateType:GetEnumItems() do
		if v.Name ~= 'Dead' and v.Name ~= 'None' then
			table.insert(states, v.Name)
		end
	end
	State = Fly:CreateDropdown({
		Name = 'Humanoid State',
		List = states
	})
	MoveMethod = Fly:CreateDropdown({
		Name = 'Move Mode',
		List = {'MoveDirection', 'Direct'},
		Tooltip = 'MoveDirection - Uses the games input vector for movement\nDirect - Directly calculate our own input vector'
	})
	Keys = Fly:CreateDropdown({
		Name = 'Keys',
		List = {'Space/LeftControl', 'Space/LeftShift', 'E/Q', 'Space/Q', 'ButtonA/ButtonL2'},
		Tooltip = 'The key combination for going up & down'
	})
	Options.Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Options.TPFrequency = Fly:CreateSlider({
		Name = 'TP Frequency',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Options.PulseLength = Fly:CreateSlider({
		Name = 'Pulse Length',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Options.PulseDelay = Fly:CreateSlider({
		Name = 'Pulse Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	BounceLength = Fly:CreateSlider({
		Name = 'Bounce Length',
		Min = 0,
		Max = 30,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	BounceDelay = Fly:CreateSlider({
		Name = 'Bounce Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	FloatTPGround = Fly:CreateSlider({
		Name = 'Ground',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.1,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	FloatTPAir = Fly:CreateSlider({
		Name = 'Air',
		Min = 0,
		Max = 5,
		Decimal = 10,
		Default = 2,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	WallCheck = Fly:CreateToggle({
		Name = 'Wall Check',
		Default = true,
		Darker = true,
		Visible = false
	})
	Options.WallCheck = WallCheck
	PlatformStanding = Fly:CreateToggle({
		Name = 'PlatformStand',
		Function = function(callback)
			if Fly.Enabled then
				entitylib.character.Humanoid.PlatformStand = callback
			end
		end,
		Tooltip = 'Forces the character to look infront of the camera'
	})
	CustomProperties = Fly:CreateToggle({
		Name = 'Custom Properties',
		Function = function()
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end,
		Default = true
	})
end)
	
run(function()
	local HighJump
	local Mode
	local Value
	local AutoDisable
	
	local function jump()
		local state = entitylib.isAlive and entitylib.character.Humanoid:GetState() or nil
	
		if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
			local root = entitylib.character.RootPart
	
			if Mode.Value == 'Velocity' then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, Value.Value, root.AssemblyLinearVelocity.Z)
			elseif Mode.Value == 'Impulse' then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				task.delay(0, function()
					root:ApplyImpulse(Vector3.new(0, Value.Value - root.AssemblyLinearVelocity.Y, 0) * root.AssemblyMass)
				end)
			else
				local start = math.max(Value.Value - entitylib.character.Humanoid.JumpHeight, 0)
				repeat
					root.CFrame += Vector3.new(0, start * 0.016, 0)
					start = start - (workspace.Gravity * 0.016)
					if Mode.Value == 'CFrame' then
						task.wait()
					end
				until start <= 0
			end
		end
	end
	
	HighJump = vape.Categories.Blatant:CreateModule({
		Name = 'HighJump',
		Function = function(callback)
			if callback then
				if AutoDisable.Enabled then
					jump()
					HighJump:Toggle()
				else
					HighJump:Clean(runService.RenderStepped:Connect(function()
						if not inputService:GetFocusedTextBox() and inputService:IsKeyDown(Enum.KeyCode.Space) then
							jump()
						end
					end))
				end
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Lets you jump higher'
	})
	Mode = HighJump:CreateDropdown({
		Name = 'Mode',
		List = {'Impulse', 'Velocity', 'CFrame', 'Instant'},
		Tooltip = 'Velocity - Uses smooth movement to boost you upward\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position upward\nInstant - Teleports you to the peak of the jump'
	})
	Value = HighJump:CreateSlider({
		Name = 'Velocity',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AutoDisable = HighJump:CreateToggle({
		Name = 'Auto Disable',
		Default = true
	})
end)
	
run(function()
	local HitBoxes
	local Targets
	local TargetPart
	local Expand
	local modified = {}
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				repeat
					for _, v in entitylib.List do
						if v.Targetable then
							if not Targets.Players.Enabled and v.Player then continue end
							if not Targets.NPCs.Enabled and v.NPC then continue end
							local part = v[TargetPart.Value]
							if not modified[part] then
								modified[part] = part.Size
							end
							part.Size = modified[part] + Vector3.new(Expand.Value, Expand.Value, Expand.Value)
						end
					end
					task.wait()
				until not HitBoxes.Enabled
			else
				for i, v in modified do
					i.Size = v
				end
				table.clear(modified)
			end
		end,
		Tooltip = 'Expands entities hitboxes'
	})
	Targets = HitBoxes:CreateTargets({Players = true})
	TargetPart = HitBoxes:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	Expand = HitBoxes:CreateSlider({
		Name = 'Expand amount',
		Min = 0,
		Max = 2,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local Invisible
	local clone, oldroot, hip, valid
	local animtrack
	local proper = true
	
	local function doClone()
		if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
			hip = entitylib.character.Humanoid.HipHeight
			oldroot = entitylib.character.HumanoidRootPart
			if not lplr.Character.Parent then
				return false
			end
	
			lplr.Character.Parent = game
			clone = oldroot:Clone()
			clone.Parent = lplr.Character
			oldroot.Parent = gameCamera
			clone.CFrame = oldroot.CFrame
	
			lplr.Character.PrimaryPart = clone
			entitylib.character.HumanoidRootPart = clone
			entitylib.character.RootPart = clone
			lplr.Character.Parent = workspace
	
			for _, v in lplr.Character:GetDescendants() do
				if v:IsA('Weld') or v:IsA('Motor6D') then
					if v.Part0 == oldroot then
						v.Part0 = clone
					end
					if v.Part1 == oldroot then
						v.Part1 = clone
					end
				end
			end
	
			return true
		end
	
		return false
	end
	
	local function revertClone()
		if not oldroot or not oldroot:IsDescendantOf(workspace) or not entitylib.isAlive then
			return false
		end
	
		lplr.Character.Parent = game
		oldroot.Parent = lplr.Character
		lplr.Character.PrimaryPart = oldroot
		entitylib.character.HumanoidRootPart = oldroot
		entitylib.character.RootPart = oldroot
		lplr.Character.Parent = workspace
		oldroot.CanCollide = true
	
		for _, v in lplr.Character:GetDescendants() do
			if v:IsA('Weld') or v:IsA('Motor6D') then
				if v.Part0 == clone then
					v.Part0 = oldroot
				end
				if v.Part1 == clone then
					v.Part1 = oldroot
				end
			end
		end
	
		local oldpos = clone.CFrame
		if clone then
			clone:Destroy()
			clone = nil
		end
	
		oldroot.CFrame = oldpos
		oldroot = nil
		entitylib.character.Humanoid.HipHeight = hip or 2
	end
	
	local function animationTrickery()
		if entitylib.isAlive then
			local anim = Instance.new('Animation')
			anim.AnimationId = 'http://www.roblox.com/asset/?id=18537363391'
			animtrack = entitylib.character.Humanoid.Animator:LoadAnimation(anim)
			animtrack.Priority = Enum.AnimationPriority.Action4
			animtrack:Play(0, 1, 0)
			anim:Destroy()
			animtrack.Stopped:Connect(function()
				if Invisible.Enabled then
					animationTrickery()
				end
			end)
	
			task.delay(0, function()
				animtrack.TimePosition = 0.77
				task.delay(1, function()
					animtrack:AdjustSpeed(math.huge)
				end)
			end)
		end
	end
	
	Invisible = vape.Categories.Blatant:CreateModule({
		Name = 'Invisible',
		Function = function(callback)
			if callback then
				if not proper then
					notif('Invisible', 'Broken state detected', 3, 'alert')
					Invisible:Toggle()
					return
				end
	
				success = doClone()
				if not success then
					Invisible:Toggle()
					return
				end
	
				animationTrickery()
				Invisible:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and oldroot then
						local root = entitylib.character.RootPart
						local cf = root.CFrame - Vector3.new(0, entitylib.character.Humanoid.HipHeight + (root.Size.Y / 2) - 1, 0)
	
						if not isnetworkowner(oldroot) then
							root.CFrame = oldroot.CFrame
							root.Velocity = oldroot.Velocity
							return
						end
	
						oldroot.CFrame = cf * CFrame.Angles(math.rad(180), 0, 0)
						oldroot.Velocity = root.Velocity
						oldroot.CanCollide = false
					end
				end))
	
				Invisible:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					local animator = char.Humanoid:WaitForChild('Animator', 1)
					if animator and Invisible.Enabled then
						oldroot = nil
						Invisible:Toggle()
						Invisible:Toggle()
					end
				end))
			else
				if animtrack then
					animtrack:Stop()
					animtrack:Destroy()
				end
	
				if success and clone and oldroot and proper then
					proper = true
					if oldroot and clone then
						revertClone()
					end
				end
			end
		end,
		Tooltip = 'Turns you invisible.'
	})
end)
	
run(function()
	local Killaura
	local Targets
	local CPS
	local SwingRange
	local AttackRange
	local AngleSlider
	local Max
	local Mouse
	local Lunge
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local Particles, Boxes, AttackDelay = {}, {}, tick()
	
	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end
	
		local tool = getTool()
		return tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true) or nil, tool
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				repeat
					local interest, tool = getAttackData()
					local attacked = {}
					if interest then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = Max.Value
						})
	
						if #plrs > 0 then
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	
							for _, v in plrs do
								local delta = (v.RootPart.Position - selfpos)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end
	
								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1
	
								if AttackDelay < tick() then
									AttackDelay = tick() + (1 / CPS.GetRandomValue())
									tool:Activate()
								end
	
								if Lunge.Enabled and tool.GripUp.X == 0 then break end
								if delta.Magnitude > AttackRange.Value then continue end
	
								Overlay.FilterDescendantsInstances = {v.Character}
								for _, part in workspace:GetPartBoundsInBox(v.RootPart.CFrame, Vector3.new(4, 4, 4), Overlay) do
									firetouchinterest(interest.Parent, part, 1)
									firetouchinterest(interest.Parent, part, 0)
								end
							end
						end
					end
	
					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end
	
					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end
	
					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.01, vec.Z))
					end
	
					task.wait()
				until not Killaura.Enabled
			else
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({Players = true})
	CPS = Killaura:CreateTwoSlider({
		Name = 'Attacks per Second',
		Min = 1,
		Max = 20,
		DefaultMin = 12,
		DefaultMax = 12
	})
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 30,
		Default = 13,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 30,
		Default = 13,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 90
	})
	Max = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 10,
		Default = 10
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Lunge = Killaura:CreateToggle({Name = 'Sword lunge only'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
end)
	
run(function()
	local Mode
	local Value
	local AutoDisable
	
	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			if callback then
				local exempt = tick() + 0.1
				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							if exempt < tick() and AutoDisable.Enabled then
								if LongJump.Enabled then
									LongJump:Toggle()
								end
							else
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							end
						end
	
						local root = entitylib.character.RootPart
						local dir = entitylib.character.Humanoid.MoveDirection * Value.Value
						if Mode.Value == 'Velocity' then
							root.AssemblyLinearVelocity = dir + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						elseif Mode.Value == 'Impulse' then
							local diff = (dir - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
							if diff.Magnitude > (dir == Vector3.zero and 10 or 2) then
								root:ApplyImpulse(diff * root.AssemblyMass)
							end
						else
							root.CFrame += dir * dt
						end
					end
				end))
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Lets you jump farther'
	})
	Mode = LongJump:CreateDropdown({
		Name = 'Mode',
		List = {'Velocity', 'Impulse', 'CFrame'},
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AutoDisable = LongJump:CreateToggle({
		Name = 'Auto Disable',
		Default = true
	})
end)
	
run(function()
	local MouseTP
	local Mode
	local MovementMode
	local Length
	local Delay
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	
	local function getWaypointInMouse()
		local returned, distance, mouseLocation = nil, math.huge, inputService:GetMouseLocation()
		for _, v in WaypointFolder:GetChildren() do
			local position, vis = gameCamera:WorldToViewportPoint(v.StudsOffsetWorldSpace)
			if not vis then continue end
			local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
			if mag < distance then
				returned, distance = v, mag
			end
		end
		return returned
	end
	
	MouseTP = vape.Categories.Blatant:CreateModule({
		Name = 'MouseTP',
		Function = function(callback)
			if callback then
				local position
				if Mode.Value == 'Mouse' then
					local ray = cloneref(lplr:GetMouse()).UnitRay
					rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
					ray = workspace:Raycast(ray.Origin, ray.Direction * 10000, rayCheck)
					position = ray and ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
				elseif Mode.Value == 'Waypoint' then
					local waypoint = getWaypointInMouse()
					position = waypoint and waypoint.StudsOffsetWorldSpace
				else
					local ent = entitylib.EntityMouse({
						Range = math.huge,
						Part = 'RootPart',
						Players = true
					})
					position = ent and ent.RootPart.Position
				end
	
				if not position then
					notif('MouseTP', 'No position found.', 5)
					MouseTP:Toggle()
					return
				end
	
				if MovementMode.Value ~= 'Lerp' then
					MouseTP:Toggle()
					if entitylib.isAlive then
						if MovementMode.Value == 'Motor' then
							motorMove(entitylib.character.RootPart, CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector))
						else
							entitylib.character.RootPart.CFrame = CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector)
						end
					end
				else
					MouseTP:Clean(runService.Heartbeat:Connect(function()
						if entitylib.isAlive then
							entitylib.character.RootPart.Velocity = Vector3.zero
						end
					end))
	
					repeat
						if entitylib.isAlive then
							local direction = CFrame.lookAt(entitylib.character.RootPart.Position, position).LookVector * math.min((entitylib.character.RootPart.Position - position).Magnitude, Length.Value)
							entitylib.character.RootPart.CFrame += direction
							if (entitylib.character.RootPart.Position - position).Magnitude < 3 and MouseTP.Enabled then
								MouseTP:Toggle()
							end
						elseif MouseTP.Enabled then
							MouseTP:Toggle()
							notif('MouseTP', 'Character missing', 5, 'warning')
						end
	
						task.wait(Delay.Value)
					until not MouseTP.Enabled
				end
			end
		end,
		Tooltip = 'Teleports to a selected position.'
	})
	Mode = MouseTP:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Player', 'Waypoint'}
	})
	MovementMode = MouseTP:CreateDropdown({
		Name = 'Movement',
		List = {'CFrame', 'Motor', 'Lerp'},
		Function = function(val)
			Length.Object.Visible = val == 'Lerp'
			Delay.Object.Visible = val == 'Lerp'
		end
	})
	Length = MouseTP:CreateSlider({
		Name = 'Length',
		Min = 0,
		Max = 150,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Delay = MouseTP:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
end)
	
run(function()
	local Mode
	local StudLimit = {Object = {}}
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local overlapCheck = OverlapParams.new()
	overlapCheck.MaxParts = 9e9
	local modified, fflag = {}
	local teleported
	
	local function grabClosestNormal(ray)
		local partCF, mag, closest = ray.Instance.CFrame, 0, Enum.NormalId.Top
		for _, normal in Enum.NormalId:GetEnumItems() do
			local dot = partCF:VectorToWorldSpace(Vector3.fromNormalId(normal)):Dot(ray.Normal)
			if dot > mag then
				mag, closest = dot, normal
			end
		end
		return Vector3.fromNormalId(closest).X ~= 0 and 'X' or 'Z'
	end
	
	local Functions = {
		Part = function()
			local chars = {gameCamera, lplr.Character}
			for _, v in entitylib.List do
				table.insert(chars, v.Character)
			end
			overlapCheck.FilterDescendantsInstances = chars
	
			local parts = workspace:GetPartBoundsInBox(entitylib.character.RootPart.CFrame + Vector3.new(0, 1, 0), entitylib.character.RootPart.Size + Vector3.new(1, entitylib.character.HipHeight, 1), overlapCheck)
			for _, part in parts do
				if part.CanCollide and (not Spider.Enabled or SpiderShift) then
					modified[part] = true
					part.CanCollide = false
				end
			end
	
			for part in modified do
				if not table.find(parts, part) then
					modified[part] = nil
					part.CanCollide = true
				end
			end
		end,
		Character = function()
			for _, part in lplr.Character:GetDescendants() do
				if part:IsA('BasePart') and part.CanCollide and (not Spider.Enabled or SpiderShift) then
					modified[part] = true
					part.CanCollide = Spider.Enabled and not SpiderShift
				end
			end
		end,
		CFrame = function()
			local chars = {gameCamera, lplr.Character}
			for _, v in entitylib.List do
				table.insert(chars, v.Character)
			end
			rayCheck.FilterDescendantsInstances = chars
			overlapCheck.FilterDescendantsInstances = chars
	
			local ray = workspace:Raycast(entitylib.character.Head.CFrame.Position, entitylib.character.Humanoid.MoveDirection * 1.1, rayCheck)
			if ray and (not Spider.Enabled or SpiderShift) then
				local phaseDirection = grabClosestNormal(ray)
				if ray.Instance.Size[phaseDirection] <= StudLimit.Value then
					local root = entitylib.character.RootPart
					local dest = root.CFrame + (ray.Normal * (-(ray.Instance.Size[phaseDirection]) - (root.Size.X / 1.5)))
	
					if #workspace:GetPartBoundsInBox(dest, Vector3.one, overlapCheck) <= 0 then
						if Mode.Value == 'Motor' then
							motorMove(root, dest)
						else
							root.CFrame = dest
						end
					end
				end
			end
		end,
		FFlag = function()
			if teleported then return end
			setfflag('AssemblyExtentsExpansionStudHundredth', '-10000')
			fflag = true
		end
	}
	Functions.Motor = Functions.CFrame
	
	Phase = vape.Categories.Blatant:CreateModule({
		Name = 'Phase',
		Function = function(callback)
			if callback then
				Phase:Clean(runService.Stepped:Connect(function()
					if entitylib.isAlive then
						Functions[Mode.Value]()
					end
				end))
	
				if Mode.Value == 'FFlag' then
					Phase:Clean(lplr.OnTeleport:Connect(function()
						teleported = true
						setfflag('AssemblyExtentsExpansionStudHundredth', '30')
					end))
				end
			else
				if fflag then
					setfflag('AssemblyExtentsExpansionStudHundredth', '30')
				end
				for part in modified do
					part.CanCollide = true
				end
				table.clear(modified)
				fflag = nil
			end
		end,
		Tooltip = 'Lets you Phase/Clip through walls. (Hold shift to use Phase over spider)'
	})
	Mode = Phase:CreateDropdown({
		Name = 'Mode',
		List = {'Part', 'Character', 'CFrame', 'Motor', 'FFlag'},
		Function = function(val)
			StudLimit.Object.Visible = val == 'CFrame' or val == 'Motor'
			if fflag then
				setfflag('AssemblyExtentsExpansionStudHundredth', '30')
			end
			for part in modified do
				part.CanCollide = true
			end
			table.clear(modified)
			fflag = nil
		end,
		Tooltip = 'Part - Modifies parts collision status around you\nCharacter - Modifies the local collision status of the character\nCFrame - Teleports you past parts\nMotor - Same as CFrame with a bypass\nFFlag - Directly adjusts all physics collisions'
	})
	StudLimit = Phase:CreateSlider({
		Name = 'Wall Size',
		Min = 1,
		Max = 20,
		Default = 5,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local Speed
	local Mode
	local Options
	local AutoJump
	local AutoJumpCustom
	local AutoJumpValue
	local w, s, a, d = 0, 0, 0, 0
	
	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			frictionTable.Speed = callback and CustomProperties.Enabled or nil
			updateVelocity()
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and not Fly.Enabled and not LongJump.Enabled then
						local state = entitylib.character.Humanoid:GetState()
						if state == Enum.HumanoidStateType.Climbing then return end
	
						local movevec = TargetStrafeVector or Options.MoveMethod.Value == 'Direct' and calculateMoveVector(Vector3.new(a + d, 0, w + s)) or entitylib.character.Humanoid.MoveDirection
						SpeedMethods[Mode.Value](Options, movevec, dt)
						if AutoJump.Enabled and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and movevec ~= Vector3.zero then
							if AutoJumpCustom.Enabled then
								local velocity = entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)
								entitylib.character.RootPart.Velocity = Vector3.new(velocity.X, AutoJumpValue.Value, velocity.Z)
							else
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							end
						end
					end
				end))
	
				w, s, a, d = inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
				for _, v in {'InputBegan', 'InputEnded'} do
					Speed:Clean(inputService[v]:Connect(function(input)
						if not inputService:GetFocusedTextBox() then
							if input.KeyCode == Enum.KeyCode.W then
								w = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.S then
								s = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode.A then
								a = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.D then
								d = v == 'InputBegan' and 1 or 0
							end
						end
					end))
				end
			else
				if Options.WalkSpeed and entitylib.isAlive then
					entitylib.character.Humanoid.WalkSpeed = Options.WalkSpeed
				end
				Options.WalkSpeed = nil
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Increases your movement with various methods.'
	})
	Mode = Speed:CreateDropdown({
		Name = 'Mode',
		List = SpeedMethodList,
		Function = function(val)
			Options.WallCheck.Object.Visible = val == 'CFrame' or val == 'TP'
			Options.TPFrequency.Object.Visible = val == 'TP'
			Options.PulseLength.Object.Visible = val == 'Pulse'
			Options.PulseDelay.Object.Visible = val == 'Pulse'
			if Speed.Enabled then
				Speed:Toggle()
				Speed:Toggle()
			end
		end,
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Large teleports within intervals\nPulse - Controllable bursts of speed\nWalkSpeed - The classic mode of speed, usually detected on most games.'
	})
	Options = {
		MoveMethod = Speed:CreateDropdown({
			Name = 'Move Mode',
			List = {'MoveDirection', 'Direct'},
			Tooltip = 'MoveDirection - Uses the games input vector for movement\nDirect - Directly calculate our own input vector'
		}),
		Value = Speed:CreateSlider({
			Name = 'Speed',
			Min = 1,
			Max = 150,
			Default = 50,
			Suffix = function(val)
				return val == 1 and 'stud' or 'studs'
			end
		}),
		TPFrequency = Speed:CreateSlider({
			Name = 'TP Frequency',
			Min = 0,
			Max = 1,
			Decimal = 100,
			Darker = true,
			Visible = false,
			Suffix = function(val)
				return val == 1 and 'second' or 'seconds'
			end
		}),
		PulseLength = Speed:CreateSlider({
			Name = 'Pulse Length',
			Min = 0,
			Max = 1,
			Decimal = 100,
			Darker = true,
			Visible = false,
			Suffix = function(val)
				return val == 1 and 'second' or 'seconds'
			end
		}),
		PulseDelay = Speed:CreateSlider({
			Name = 'Pulse Delay',
			Min = 0,
			Max = 1,
			Decimal = 100,
			Darker = true,
			Visible = false,
			Suffix = function(val)
				return val == 1 and 'second' or 'seconds'
			end
		}),
		WallCheck = Speed:CreateToggle({
			Name = 'Wall Check',
			Default = true,
			Darker = true,
			Visible = false
		}),
		TPTiming = tick(),
		rayCheck = RaycastParams.new()
	}
	Options.rayCheck.RespectCanCollide = true
	CustomProperties = Speed:CreateToggle({
		Name = 'Custom Properties',
		Function = function()
			if Speed.Enabled then
				Speed:Toggle()
				Speed:Toggle()
			end
		end,
		Default = true
	})
	AutoJump = Speed:CreateToggle({
		Name = 'AutoJump',
		Function = function(callback)
			AutoJumpCustom.Object.Visible = callback
		end
	})
	AutoJumpCustom = Speed:CreateToggle({
		Name = 'Custom Jump',
		Function = function(callback)
			AutoJumpValue.Object.Visible = callback
		end,
		Tooltip = 'Allows you to adjust the jump power',
		Darker = true,
		Visible = false
	})
	AutoJumpValue = Speed:CreateSlider({
		Name = 'Jump Power',
		Min = 1,
		Max = 50,
		Default = 30,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local Mode
	local Value
	local State
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local Active, Truss
	
	Spider = vape.Categories.Blatant:CreateModule({
		Name = 'Spider',
		Function = function(callback)
			if callback then
				if Truss then Truss.Parent = gameCamera end
				Spider:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local chars = {gameCamera, lplr.Character, Truss}
						for _, v in entitylib.List do
							table.insert(chars, v.Character)
						end
						SpiderShift = inputService:IsKeyDown(Enum.KeyCode.LeftShift)
						rayCheck.FilterDescendantsInstances = chars
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if Mode.Value ~= 'Part' then
							local vec = entitylib.character.Humanoid.MoveDirection * 2.5
							local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), vec, rayCheck)
							if Active and not ray then
								root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
							end
	
							Active = ray
							if Active and ray.Normal.Y == 0 then
								if not Phase.Enabled or not SpiderShift then
									if State.Enabled then
										entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
									end
	
									root.Velocity *= Vector3.new(1, 0, 1)
									if Mode.Value == 'CFrame' then
										root.CFrame += Vector3.new(0, Value.Value * dt, 0)
									elseif Mode.Value == 'Impulse' then
										root:ApplyImpulse(Vector3.new(0, Value.Value, 0) * root.AssemblyMass)
									else
										root.Velocity += Vector3.new(0, Value.Value, 0)
									end
								end
							end
						else
							local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), entitylib.character.RootPart.CFrame.LookVector * 2, rayCheck)
							if ray and (not Phase.Enabled or not SpiderShift) then
								Truss.Position = ray.Position - ray.Normal * 0.9 or Vector3.zero
							else
								Truss.Position = Vector3.zero
							end
						end
					end
				end))
			else
				if Truss then
					Truss.Parent = nil
				end
				SpiderShift = false
			end
		end,
		Tooltip = 'Lets you climb up walls. (Hold shift to use Phase over spider)'
	})
	Mode = Spider:CreateDropdown({
		Name = 'Mode',
		List = {'Velocity', 'Impulse', 'CFrame', 'Part'},
		Function = function(val)
			Value.Object.Visible = val ~= 'Part'
			State.Object.Visible = val ~= 'Part'
			if Truss then
				Truss:Destroy()
				Truss = nil
			end
			if val == 'Part' then
				Truss = Instance.new('TrussPart')
				Truss.Size = Vector3.new(2, 2, 2)
				Truss.Transparency = 1
				Truss.Anchored = true
				Truss.Parent = Spider.Enabled and gameCamera or nil
			end
		end,
		Tooltip = 'Velocity - Uses smooth movement to boost you upward\nCFrame - Directly adjusts the position upward\nPart - Positions a climbable part infront of you'
	})
	Value = Spider:CreateSlider({
		Name = 'Speed',
		Min = 0,
		Max = 100,
		Default = 30,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	State = Spider:CreateToggle({
		Name = 'Climb State',
		Darker = true
	})
end)
	
run(function()
	local SpinBot
	local Mode
	local XToggle
	local YToggle
	local ZToggle
	local Value
	local AngularVelocity
	
	SpinBot = vape.Categories.Blatant:CreateModule({
		Name = 'SpinBot',
		Function = function(callback)
			if callback then
				SpinBot:Clean(runService.PreSimulation:Connect(function()
					if entitylib.isAlive then
						if Mode.Value == 'RotVelocity' then
							local originalRotVelocity = entitylib.character.RootPart.RotVelocity
							entitylib.character.Humanoid.AutoRotate = false
							entitylib.character.RootPart.RotVelocity = Vector3.new(XToggle.Enabled and Value.Value or originalRotVelocity.X, YToggle.Enabled and Value.Value or originalRotVelocity.Y, ZToggle.Enabled and Value.Value or originalRotVelocity.Z)
						elseif Mode.Value == 'CFrame' then
							local val = math.rad((tick() * (20 * Value.Value)) % 360)
							local x, y, z = entitylib.character.RootPart.CFrame:ToOrientation()
							entitylib.character.RootPart.CFrame = CFrame.new(entitylib.character.RootPart.Position) * CFrame.Angles(XToggle.Enabled and val or x, YToggle.Enabled and val or y, ZToggle.Enabled and val or z)
						elseif AngularVelocity then
							AngularVelocity.Parent = entitylib.isAlive and entitylib.character.RootPart
							AngularVelocity.MaxTorque = Vector3.new(XToggle.Enabled and math.huge or 0, YToggle.Enabled and math.huge or 0, ZToggle.Enabled and math.huge or 0)
							AngularVelocity.AngularVelocity = Vector3.new(Value.Value, Value.Value, Value.Value)
						end
					end
				end))
			else
				if entitylib.isAlive and Mode.Value == 'RotVelocity' then
					entitylib.character.Humanoid.AutoRotate = true
				end
				if AngularVelocity then
					AngularVelocity.Parent = nil
				end
			end
		end,
		Tooltip = 'Makes your character spin around in circles (does not work in first person)'
	})
	Mode = SpinBot:CreateDropdown({
		Name = 'Mode',
		List = {'CFrame', 'RotVelocity', 'BodyMover'},
		Function = function(val)
			if AngularVelocity then
				AngularVelocity:Destroy()
				AngularVelocity = nil
			end
			AngularVelocity = val == 'BodyMover' and Instance.new('BodyAngularVelocity') or nil
		end
	})
	Value = SpinBot:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 100,
		Default = 40
	})
	XToggle = SpinBot:CreateToggle({Name = 'Spin X'})
	YToggle = SpinBot:CreateToggle({
		Name = 'Spin Y',
		Default = true
	})
	ZToggle = SpinBot:CreateToggle({Name = 'Spin Z'})
end)
	
run(function()
	local Swim
	local terrain = cloneref(workspace:FindFirstChildWhichIsA('Terrain'))
	local lastpos = Region3.new(Vector3.zero, Vector3.zero)
	
	Swim = vape.Categories.Blatant:CreateModule({
		Name = 'Swim',
		Function = function(callback)
			if callback then
				Swim:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local moving = entitylib.character.Humanoid.MoveDirection ~= Vector3.zero
						local rootvelo = root.Velocity
						local space = inputService:IsKeyDown(Enum.KeyCode.Space)
	
						if terrain then
							local factor = (moving or space) and Vector3.new(6, 6, 6) or Vector3.new(2, 1, 2)
							local pos = root.Position - Vector3.new(0, 1, 0)
							local newpos = Region3.new(pos - factor, pos + factor):ExpandToGrid(4)
							terrain:ReplaceMaterial(lastpos, 4, Enum.Material.Water, Enum.Material.Air)
							terrain:FillRegion(newpos, 4, Enum.Material.Water)
							lastpos = newpos
						end
					end
				end))
			else
				if terrain and lastpos then
					terrain:ReplaceMaterial(lastpos, 4, Enum.Material.Water, Enum.Material.Air)
				end
			end
		end,
		Tooltip = 'Lets you swim midair'
	})
end)
	
run(function()
	local TargetStrafe
	local Targets
	local SearchRange
	local StrafeRange
	local YFactor
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local module, old
	
	TargetStrafe = vape.Categories.Blatant:CreateModule({
		Name = 'TargetStrafe',
		Function = function(callback)
			if callback then
				if not module then
					local suc = pcall(function() module = require(lplr.PlayerScripts.PlayerModule).controls end)
					if not suc then
						module = {}
					end
				end
				
				old = module.moveFunction
				local flymod, ang, oldent = vape.Modules.Fly or {Enabled = false}
				module.moveFunction = function(self, vec, face)
					local wallcheck = Targets.Walls.Enabled
					local ent = not inputService:IsKeyDown(Enum.KeyCode.S) and entitylib.EntityPosition({
						Range = SearchRange.Value,
						Wallcheck = wallcheck,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled
					})
	
					if ent then
						local root, targetPos = entitylib.character.RootPart, ent.RootPart.Position
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, ent.Character}
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if flymod.Enabled or workspace:Raycast(targetPos, Vector3.new(0, -70, 0), rayCheck) then
							local factor, localPosition = 0, root.Position
							if ent ~= oldent then
								ang = math.deg(select(2, CFrame.lookAt(targetPos, localPosition):ToEulerAnglesYXZ()))
							end
							local yFactor = math.abs(localPosition.Y - targetPos.Y) * (YFactor.Value / 100)
							local entityPos = Vector3.new(targetPos.X, localPosition.Y, targetPos.Z)
							local newPos = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (StrafeRange.Value - yFactor))
							local startRay, endRay = entityPos, newPos
	
							if not wallcheck and workspace:Raycast(targetPos, (localPosition - targetPos), rayCheck) then
								startRay, endRay = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (entityPos - localPosition).Magnitude), entityPos
							end
	
							local ray = workspace:Blockcast(CFrame.new(startRay), Vector3.new(1, entitylib.character.HipHeight + (root.Size.Y / 2), 1), (endRay - startRay), rayCheck)
							if (localPosition - newPos).Magnitude < 3 or ray then
								factor = (8 - math.min((localPosition - newPos).Magnitude, 3))
								if ray then
									newPos = ray.Position + (ray.Normal * 1.5)
									factor = (localPosition - newPos).Magnitude > 3 and 0 or factor
								end
							end
	
							if not flymod.Enabled and not workspace:Raycast(newPos, Vector3.new(0, -70, 0), rayCheck) then
								newPos = entityPos
								factor = 40
							end
	
							ang += factor % 360
							vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
							vec = vec == vec and vec or Vector3.zero
							TargetStrafeVector = vec
						else
							ent = nil
						end
					end
	
					TargetStrafeVector = ent and vec or nil
					oldent = ent
					return old(self, vec, face)
				end
			else
				if module and old then
					module.moveFunction = old
				end
				TargetStrafeVector = nil
			end
		end,
		Tooltip = 'Automatically strafes around the opponent'
	})
	Targets = TargetStrafe:CreateTargets({
		Players = true,
		Walls = true
	})
	SearchRange = TargetStrafe:CreateSlider({
		Name = 'Search Range',
		Min = 1,
		Max = 30,
		Default = 24,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	StrafeRange = TargetStrafe:CreateSlider({
		Name = 'Strafe Range',
		Min = 1,
		Max = 30,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	YFactor = TargetStrafe:CreateSlider({
		Name = 'Y Factor',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
	
run(function()
	local Timer
	local Value
	
	Timer = vape.Categories.Blatant:CreateModule({
		Name = 'Timer',
		Function = function(callback)
			if callback then
				setfflag('SimEnableStepPhysics', 'True')
				setfflag('SimEnableStepPhysicsSelective', 'True')
				Timer:Clean(runService.RenderStepped:Connect(function(dt)
					if Value.Value > 1 then
						runService:Pause()
						workspace:StepPhysics(dt * (Value.Value - 1), {entitylib.character.RootPart})
						runService:Run()
					end
				end))
			end
		end,
		Tooltip = 'Change the game speed.'
	})
	Value = Timer:CreateSlider({
		Name = 'Value',
		Min = 1,
		Max = 3,
		Decimal = 10
	})
end)
	
run(function()
	local Arrows
	local Targets
	local Color
	local Teammates
	local Distance
	local DistanceLimit
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local arrow = Instance.new('ImageLabel')
		arrow.Size = UDim2.fromOffset(256, 256)
		arrow.Position = UDim2.fromScale(0.5, 0.5)
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.BackgroundTransparency = 1
		arrow.BorderSizePixel = 0
		arrow.Visible = false
		arrow.Image = getcustomasset('newvape/assets/new/arrowmodule.png')
		arrow.ImageColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		arrow.Parent = Folder
		Reference[ent] = arrow
	end
	
	local function Removed(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			v:Destroy()
		end
	end
	
	local function ColorFunc(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for ent, EntityArrow in Reference do
			EntityArrow.ImageColor3 = entitylib.getEntityColor(ent) or color
		end
	end
	
	local function Loop()
		for ent, arrow in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					arrow.Visible = false
					continue
				end
			end
	
			local _, rootVis = gameCamera:WorldToScreenPoint(ent.RootPart.Position)
			arrow.Visible = not rootVis
			if rootVis then continue end
	
			local dir = CFrame.lookAlong(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):PointToObjectSpace(ent.RootPart.Position)
			arrow.Rotation = math.deg(math.atan2(dir.Z, dir.X))
		end
	end
	
	Arrows = vape.Categories.Render:CreateModule({
		Name = 'Arrows',
		Function = function(callback)
			if callback then
				Arrows:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				for _, v in entitylib.List do
					if Reference[v] then Removed(v) end
					Added(v)
				end
				Arrows:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then Removed(ent) end
					Added(ent)
				end))
				Arrows:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc(Color.Hue, Color.Sat, Color.Value)
				end))
				Arrows:Clean(runService.RenderStepped:Connect(Loop))
			else
				for i in Reference do
					Removed(i)
				end
			end
		end,
		Tooltip = 'Draws arrows on screen when entities\nare out of your field of view.'
	})
	Targets = Arrows:CreateTargets({
		Players = true,
		Function = function()
			if Arrows.Enabled then
				Arrows:Toggle()
				Arrows:Toggle()
			end
		end
	})
	Color = Arrows:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if Arrows.Enabled then
				ColorFunc(hue, sat, val)
			end
		end,
	})
	Teammates = Arrows:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if Arrows.Enabled then
				Arrows:Toggle()
				Arrows:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
	Distance = Arrows:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = Arrows:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local Chams
	local Targets
	local Mode
	local FillColor
	local OutlineColor
	local FillTransparency
	local OutlineTransparency
	local Teammates
	local Walls
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		if Mode.Value == 'Highlight' then
			local cham = Instance.new('Highlight')
			cham.Adornee = ent.Character
			cham.DepthMode = Enum.HighlightDepthMode[Walls.Enabled and 'AlwaysOnTop' or 'Occluded']
			cham.FillColor = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
			cham.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
			cham.FillTransparency = FillTransparency.Value
			cham.OutlineTransparency = OutlineTransparency.Value
			cham.Parent = Folder
			Reference[ent] = cham
		else
			local chams = {}
			for _, v in ent.Character:GetChildren() do
				if v:IsA('BasePart') and (ent.NPC or v.Name:find('Arm') or v.Name:find('Leg') or v.Name:find('Hand') or v.Name:find('Feet') or v.Name:find('Torso') or v.Name == 'Head') then
					local box = Instance.new(v.Name == 'Head' and 'SphereHandleAdornment' or 'BoxHandleAdornment')
					if v.Name == 'Head' then
						box.Radius = 0.75
					else
						box.Size = v.Size
					end
					box.AlwaysOnTop = Walls.Enabled
					box.Adornee = v
					box.ZIndex = 0
					box.Transparency = FillTransparency.Value
					box.Color3 = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
					box.Parent = Folder
					table.insert(chams, box)
				end
			end
			Reference[ent] = chams
		end
	end
	
	local function Removed(ent)
		if Reference[ent] then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			if type(Reference[ent]) == 'table' then
				for _, v in Reference[ent] do
					v:Destroy()
				end
				table.clear(Reference[ent])
			else
				Reference[ent]:Destroy()
			end
			Reference[ent] = nil
		end
	end
	
	Chams = vape.Categories.Render:CreateModule({
		Name = 'Chams',
		Function = function(callback)
			if callback then
				Chams:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				Chams:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed(ent)
					end
					Added(ent)
				end))
				Chams:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					for i, v in Reference do
						local color = entitylib.getEntityColor(i) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
						if type(v) == 'table' then
							for _, v2 in v do v2.Color3 = color end
						else
							v.FillColor = color
						end
					end
				end))
				for _, v in entitylib.List do
					if Reference[v] then
						Removed(v)
					end
					Added(v)
				end
			else
				for i in Reference do
					Removed(i)
				end
			end
		end,
		Tooltip = 'Render players through walls'
	})
	Targets = Chams:CreateTargets({
		Players = true,
		Function = function()
			if Chams.Enabled then
				Chams:Toggle()
				Chams:Toggle()
			end
		end
		})
	Mode = Chams:CreateDropdown({
		Name = 'Mode',
		List = {'Highlight', 'BoxHandles'},
		Function = function(val)
			OutlineColor.Object.Visible = val == 'Highlight'
			OutlineTransparency.Object.Visible = val == 'Highlight'
			if Chams.Enabled then
				Chams:Toggle()
				Chams:Toggle()
			end
		end
	})
	FillColor = Chams:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for i, v in Reference do
				local color = entitylib.getEntityColor(i) or Color3.fromHSV(hue, sat, val)
				if type(v) == 'table' then
					for _, v2 in v do v2.Color3 = color end
				else
					v.FillColor = color
				end
			end
		end
	})
	OutlineColor = Chams:CreateColorSlider({
		Name = 'Outline Color',
		DefaultSat = 0,
		Function = function(hue, sat, val)
			for i, v in Reference do
				if type(v) ~= 'table' then
					v.OutlineColor = entitylib.getEntityColor(i) or Color3.fromHSV(hue, sat, val)
				end
			end
		end,
		Darker = true
	})
	FillTransparency = Chams:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Default = 0.5,
		Function = function(val)
			for _, v in Reference do
				if type(v) == 'table' then
					for _, v2 in v do v2.Transparency = val end
				else
					v.FillTransparency = val
				end
			end
		end,
		Decimal = 10
	})
	OutlineTransparency = Chams:CreateSlider({
		Name = 'Outline Transparency',
		Min = 0,
		Max = 1,
		Default = 0.5,
		Function = function(val)
			for _, v in Reference do
				if type(v) ~= 'table' then
					v.OutlineTransparency = val
				end
			end
		end,
		Decimal = 10,
		Darker = true
	})
	Walls = Chams:CreateToggle({
		Name = 'Render Walls',
		Function = function(callback)
			for _, v in Reference do
				if type(v) == 'table' then
					for _, v2 in v do
						v2.AlwaysOnTop = callback
					end
				else
					v.DepthMode = Enum.HighlightDepthMode[callback and 'AlwaysOnTop' or 'Occluded']
				end
			end
		end,
		Default = true
	})
	Teammates = Chams:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if Chams.Enabled then
				Chams:Toggle()
				Chams:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
end)
	
run(function()
	local ESP
	local Targets
	local Color
	local Method
	local BoundingBox
	local Filled
	local HealthBar
	local Name
	local DisplayName
	local Background
	local Teammates
	local Distance
	local DistanceLimit
	local Reference = {}
	local methodused
	
	local function ESPWorldToViewport(pos)
		local newpos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(gameCamera.CFrame:PointToObjectSpace(pos)))
		return Vector2.new(newpos.X, newpos.Y)
	end
	
	local ESPAdded = {
		Drawing2D = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local EntityESP = {}
			EntityESP.Main = Drawing.new('Square')
			EntityESP.Main.Transparency = BoundingBox.Enabled and 1 or 0
			EntityESP.Main.ZIndex = 2
			EntityESP.Main.Filled = false
			EntityESP.Main.Thickness = 1
			EntityESP.Main.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	
			if BoundingBox.Enabled then
				EntityESP.Border = Drawing.new('Square')
				EntityESP.Border.Transparency = 0.35
				EntityESP.Border.ZIndex = 1
				EntityESP.Border.Thickness = 1
				EntityESP.Border.Filled = false
				EntityESP.Border.Color = Color3.new()
				EntityESP.Border2 = Drawing.new('Square')
				EntityESP.Border2.Transparency = 0.35
				EntityESP.Border2.ZIndex = 1
				EntityESP.Border2.Thickness = 1
				EntityESP.Border2.Filled = Filled.Enabled
				EntityESP.Border2.Color = Color3.new()
			end
	
			if HealthBar.Enabled then
				EntityESP.HealthLine = Drawing.new('Line')
				EntityESP.HealthLine.Thickness = 1
				EntityESP.HealthLine.ZIndex = 2
				EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				EntityESP.HealthBorder = Drawing.new('Line')
				EntityESP.HealthBorder.Thickness = 3
				EntityESP.HealthBorder.Transparency = 0.35
				EntityESP.HealthBorder.ZIndex = 1
				EntityESP.HealthBorder.Color = Color3.new()
			end
			
			if Name.Enabled then
				if Background.Enabled then
					EntityESP.TextBKG = Drawing.new('Square')
					EntityESP.TextBKG.Transparency = 0.35
					EntityESP.TextBKG.ZIndex = 0
					EntityESP.TextBKG.Thickness = 1
					EntityESP.TextBKG.Filled = true
					EntityESP.TextBKG.Color = Color3.new()
				end
				EntityESP.Drop = Drawing.new('Text')
				EntityESP.Drop.Color = Color3.new()
				EntityESP.Drop.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
				EntityESP.Drop.ZIndex = 1
				EntityESP.Drop.Center = true
				EntityESP.Drop.Size = 20
				EntityESP.Text = Drawing.new('Text')
				EntityESP.Text.Text = EntityESP.Drop.Text
				EntityESP.Text.ZIndex = 2
				EntityESP.Text.Color = EntityESP.Main.Color
				EntityESP.Text.Center = true
				EntityESP.Text.Size = 20
			end
			Reference[ent] = EntityESP
		end,
		Drawing3D = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local EntityESP = {}
			EntityESP.Line1 = Drawing.new('Line')
			EntityESP.Line2 = Drawing.new('Line')
			EntityESP.Line3 = Drawing.new('Line')
			EntityESP.Line4 = Drawing.new('Line')
			EntityESP.Line5 = Drawing.new('Line')
			EntityESP.Line6 = Drawing.new('Line')
			EntityESP.Line7 = Drawing.new('Line')
			EntityESP.Line8 = Drawing.new('Line')
			EntityESP.Line9 = Drawing.new('Line')
			EntityESP.Line10 = Drawing.new('Line')
			EntityESP.Line11 = Drawing.new('Line')
			EntityESP.Line12 = Drawing.new('Line')
	
			local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			for _, v in EntityESP do
				v.Thickness = 1
				v.Color = color
			end
	
			Reference[ent] = EntityESP
		end,
		DrawingSkeleton = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local EntityESP = {}
			EntityESP.Head = Drawing.new('Line')
			EntityESP.HeadFacing = Drawing.new('Line')
			EntityESP.Torso = Drawing.new('Line')
			EntityESP.UpperTorso = Drawing.new('Line')
			EntityESP.LowerTorso = Drawing.new('Line')
			EntityESP.LeftArm = Drawing.new('Line')
			EntityESP.RightArm = Drawing.new('Line')
			EntityESP.LeftLeg = Drawing.new('Line')
			EntityESP.RightLeg = Drawing.new('Line')
	
			local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			for _, v in EntityESP do
				v.Thickness = 2
				v.Color = color
			end
	
			Reference[ent] = EntityESP
		end
	}
	
	local ESPRemoved = {
		Drawing2D = function(ent)
			local EntityESP = Reference[ent]
			if EntityESP then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Reference[ent] = nil
				for _, v in EntityESP do
					pcall(function()
						v.Visible = false
						v:Remove()
					end)
				end
			end
		end
	}
	ESPRemoved.Drawing3D = ESPRemoved.Drawing2D
	ESPRemoved.DrawingSkeleton = ESPRemoved.Drawing2D
	
	local ESPUpdated = {
		Drawing2D = function(ent)
			local EntityESP = Reference[ent]
			if EntityESP then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				
				if EntityESP.HealthLine then
					EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				end
	
				if EntityESP.Text then
					EntityESP.Text.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
					EntityESP.Drop.Text = EntityESP.Text.Text
				end
			end
		end
	}
	
	local ColorFunc = {
		Drawing2D = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.Main.Color = entitylib.getEntityColor(i) or color
				if v.Text then
					v.Text.Color = v.Main.Color
				end
			end
		end,
		Drawing3D = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				local playercolor = entitylib.getEntityColor(i) or color
				for _, v2 in v do
					v2.Color = playercolor
				end
			end
		end
	}
	ColorFunc.DrawingSkeleton = ColorFunc.Drawing3D
	
	local ESPLoop = {
		Drawing2D = function()
			for ent, EntityESP in Reference do
				if Distance.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						for _, obj in EntityESP do
							obj.Visible = false
						end
						continue
					end
				end
	
				local rootPos, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
				for _, obj in EntityESP do
					obj.Visible = rootVis
				end
				if not rootVis then continue end
	
				local topPos = gameCamera:WorldToViewportPoint((CFrame.lookAlong(ent.RootPart.Position, gameCamera.CFrame.LookVector) * CFrame.new(2, ent.HipHeight, 0)).p)
				local bottomPos = gameCamera:WorldToViewportPoint((CFrame.lookAlong(ent.RootPart.Position, gameCamera.CFrame.LookVector) * CFrame.new(-2, -ent.HipHeight - 1, 0)).p)
				local sizex, sizey = topPos.X - bottomPos.X, topPos.Y - bottomPos.Y
				local posx, posy = (rootPos.X - sizex / 2),  ((rootPos.Y - sizey / 2))
				EntityESP.Main.Position = Vector2.new(posx, posy) // 1
				EntityESP.Main.Size = Vector2.new(sizex, sizey) // 1
				if EntityESP.Border then
					EntityESP.Border.Position = Vector2.new(posx - 1, posy + 1) // 1
					EntityESP.Border.Size = Vector2.new(sizex + 2, sizey - 2) // 1
					EntityESP.Border2.Position = Vector2.new(posx + 1, posy - 1) // 1
					EntityESP.Border2.Size = Vector2.new(sizex - 2, sizey + 2) // 1
				end
	
				if EntityESP.HealthLine then
					local healthposy = sizey * math.clamp(ent.Health / ent.MaxHealth, 0, 1)
					EntityESP.HealthLine.Visible = ent.Health > 0
					EntityESP.HealthLine.From = Vector2.new(posx - 6, posy + (sizey - (sizey - healthposy))) // 1
					EntityESP.HealthLine.To = Vector2.new(posx - 6, posy) // 1
					EntityESP.HealthBorder.From = Vector2.new(posx - 6, posy + 1) // 1
					EntityESP.HealthBorder.To = Vector2.new(posx - 6, (posy + sizey) - 1) // 1
				end
	
				if EntityESP.Text then
					EntityESP.Text.Position = Vector2.new(posx + (sizex / 2), posy + (sizey - 28)) // 1
					EntityESP.Drop.Position = EntityESP.Text.Position + Vector2.new(1, 1)
					if EntityESP.TextBKG then
						EntityESP.TextBKG.Size = EntityESP.Text.TextBounds + Vector2.new(8, 4)
						EntityESP.TextBKG.Position = EntityESP.Text.Position - Vector2.new(4 + (EntityESP.Text.TextBounds.X / 2), 0)
					end
				end
			end
		end,
		Drawing3D = function()
			for ent, EntityESP in Reference do
				if Distance.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						for _, obj in EntityESP do
							obj.Visible = false
						end
						continue
					end
				end
	
				local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
				for _, obj in EntityESP do
					obj.Visible = rootVis
				end
				if not rootVis then continue end
	
				local point1 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, ent.HipHeight, 1.5))
				local point2 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, -ent.HipHeight, 1.5))
				local point3 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, ent.HipHeight, 1.5))
				local point4 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, -ent.HipHeight, 1.5))
				local point5 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, ent.HipHeight, -1.5))
				local point6 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, -ent.HipHeight, -1.5))
				local point7 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, ent.HipHeight, -1.5))
				local point8 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, -ent.HipHeight, -1.5))
				EntityESP.Line1.From = point1
				EntityESP.Line1.To = point2
				EntityESP.Line2.From = point3
				EntityESP.Line2.To = point4
				EntityESP.Line3.From = point5
				EntityESP.Line3.To = point6
				EntityESP.Line4.From = point7
				EntityESP.Line4.To = point8
				EntityESP.Line5.From = point1
				EntityESP.Line5.To = point3
				EntityESP.Line6.From = point1
				EntityESP.Line6.To = point5
				EntityESP.Line7.From = point5
				EntityESP.Line7.To = point7
				EntityESP.Line8.From = point7
				EntityESP.Line8.To = point3
				EntityESP.Line9.From = point2
				EntityESP.Line9.To = point4
				EntityESP.Line10.From = point2
				EntityESP.Line10.To = point6
				EntityESP.Line11.From = point6
				EntityESP.Line11.To = point8
				EntityESP.Line12.From = point8
				EntityESP.Line12.To = point4
			end
		end,
		DrawingSkeleton = function()
			for ent, EntityESP in Reference do
				if Distance.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						for _, obj in EntityESP do
							obj.Visible = false
						end
						continue
					end
				end
	
				local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
				for _, obj in EntityESP do
					obj.Visible = rootVis
				end
				if not rootVis then continue end
				
				local rigcheck = ent.Humanoid.RigType == Enum.HumanoidRigType.R6
				pcall(function()
					local offset = rigcheck and CFrame.new(0, -0.8, 0) or CFrame.identity
					local head = ESPWorldToViewport((ent.Head.CFrame).p)
					local headfront = ESPWorldToViewport((ent.Head.CFrame * CFrame.new(0, 0, -0.5)).p)
					local toplefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-1.5, 0.8, 0)).p)
					local toprighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(1.5, 0.8, 0)).p)
					local toptorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, 0.8, 0)).p)
					local bottomtorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, -0.8, 0)).p)
					local bottomlefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-0.5, -0.8, 0)).p)
					local bottomrighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0.5, -0.8, 0)).p)
					local leftarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Arm' or 'LeftHand')].CFrame * offset).p)
					local rightarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Arm' or 'RightHand')].CFrame * offset).p)
					local leftleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Leg' or 'LeftFoot')].CFrame * offset).p)
					local rightleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Leg' or 'RightFoot')].CFrame * offset).p)
					EntityESP.Head.From = toptorso
					EntityESP.Head.To = head
					EntityESP.HeadFacing.From = head
					EntityESP.HeadFacing.To = headfront
					EntityESP.UpperTorso.From = toplefttorso
					EntityESP.UpperTorso.To = toprighttorso
					EntityESP.Torso.From = toptorso
					EntityESP.Torso.To = bottomtorso
					EntityESP.LowerTorso.From = bottomlefttorso
					EntityESP.LowerTorso.To = bottomrighttorso
					EntityESP.LeftArm.From = toplefttorso
					EntityESP.LeftArm.To = leftarm
					EntityESP.RightArm.From = toprighttorso
					EntityESP.RightArm.To = rightarm
					EntityESP.LeftLeg.From = bottomlefttorso
					EntityESP.LeftLeg.To = leftleg
					EntityESP.RightLeg.From = bottomrighttorso
					EntityESP.RightLeg.To = rightleg
				end)
			end
		end
	}
	
	ESP = vape.Categories.Render:CreateModule({
		Name = 'ESP',
		Function = function(callback)
			if callback then
				methodused = 'Drawing'..Method.Value
				if ESPRemoved[methodused] then
					ESP:Clean(entitylib.Events.EntityRemoved:Connect(ESPRemoved[methodused]))
				end
				if ESPAdded[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then
							ESPRemoved[methodused](v)
						end
						ESPAdded[methodused](v)
					end
					ESP:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then
							ESPRemoved[methodused](ent)
						end
						ESPAdded[methodused](ent)
					end))
				end
				if ESPUpdated[methodused] then
					ESP:Clean(entitylib.Events.EntityUpdated:Connect(ESPUpdated[methodused]))
					for _, v in entitylib.List do
						ESPUpdated[methodused](v)
					end
				end
				if ColorFunc[methodused] then
					ESP:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if ESPLoop[methodused] then
					ESP:Clean(runService.RenderStepped:Connect(ESPLoop[methodused]))
				end
			else
				if ESPRemoved[methodused] then
					for i in Reference do
						ESPRemoved[methodused](i)
					end
				end
			end
		end,
		Tooltip = 'Extra Sensory Perception\nRenders an ESP on players.'
	})
	Targets = ESP:CreateTargets({
		Players = true,
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end
	})
	Method = ESP:CreateDropdown({
		Name = 'Mode',
		List = {'2D', '3D', 'Skeleton'},
		Function = function(val)
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
			BoundingBox.Object.Visible = (val == '2D')
			Filled.Object.Visible = (val == '2D')
			HealthBar.Object.Visible = (val == '2D')
			Name.Object.Visible = (val == '2D')
			DisplayName.Object.Visible = Name.Object.Visible and Name.Enabled
			Background.Object.Visible = Name.Object.Visible and Name.Enabled
		end,
	})
	Color = ESP:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if ESP.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	BoundingBox = ESP:CreateToggle({
		Name = 'Bounding Box',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Default = true,
		Darker = true
	})
	Filled = ESP:CreateToggle({
		Name = 'Filled',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Darker = true
	})
	HealthBar = ESP:CreateToggle({
		Name = 'Health Bar',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Darker = true
	})
	Name = ESP:CreateToggle({
		Name = 'Name',
		Function = function(callback)
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
			DisplayName.Object.Visible = callback
			Background.Object.Visible = callback
		end,
		Darker = true
	})
	DisplayName = ESP:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Default = true,
		Darker = true
	})
	Background = ESP:CreateToggle({
		Name = 'Show Background',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Darker = true
	})
	Teammates = ESP:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
	Distance = ESP:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = ESP:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local GamingChair = {Enabled = false}
	local Color
	local wheelpositions = {
		Vector3.new(-0.8, -0.6, -0.18),
		Vector3.new(0.1, -0.6, -0.88),
		Vector3.new(0, -0.6, 0.7)
	}
	local chairhighlight
	local currenttween
	local movingsound
	local flyingsound
	local chairanim
	local chair
	
	GamingChair = vape.Categories.Render:CreateModule({
		Name = 'GamingChair',
		Function = function(callback)
			if callback then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				chair = Instance.new('MeshPart')
				chair.Color = Color3.fromRGB(21, 21, 21)
				chair.Size = Vector3.new(2.16, 3.6, 2.3) / Vector3.new(12.37, 20.636, 13.071)
				chair.CanCollide = false
				chair.Massless = true
				chair.MeshId = 'rbxassetid://12972961089'
				chair.Material = Enum.Material.SmoothPlastic
				chair.Parent = workspace
				movingsound = Instance.new('Sound')
				--movingsound.SoundId = downloadVapeAsset('vape/assets/ChairRolling.mp3')
				movingsound.Volume = 0.4
				movingsound.Looped = true
				movingsound.Parent = workspace
				flyingsound = Instance.new('Sound')
				--flyingsound.SoundId = downloadVapeAsset('vape/assets/ChairFlying.mp3')
				flyingsound.Volume = 0.4
				flyingsound.Looped = true
				flyingsound.Parent = workspace
				local chairweld = Instance.new('WeldConstraint')
				chairweld.Part0 = chair
				chairweld.Parent = chair
				if entitylib.isAlive then
					chair.CFrame = entitylib.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
					chairweld.Part1 = entitylib.character.RootPart
				end
				chairhighlight = Instance.new('Highlight')
				chairhighlight.FillTransparency = 1
				chairhighlight.OutlineColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				chairhighlight.DepthMode = Enum.HighlightDepthMode.Occluded
				chairhighlight.OutlineTransparency = 0.2
				chairhighlight.Parent = chair
				local chairarms = Instance.new('MeshPart')
				chairarms.Color = chair.Color
				chairarms.Size = Vector3.new(1.39, 1.345, 2.75) / Vector3.new(97.13, 136.216, 234.031)
				chairarms.CFrame = chair.CFrame * CFrame.new(-0.169, -1.129, -0.013)
				chairarms.MeshId = 'rbxassetid://12972673898'
				chairarms.CanCollide = false
				chairarms.Parent = chair
				local chairarmsweld = Instance.new('WeldConstraint')
				chairarmsweld.Part0 = chairarms
				chairarmsweld.Part1 = chair
				chairarmsweld.Parent = chair
				local chairlegs = Instance.new('MeshPart')
				chairlegs.Color = chair.Color
				chairlegs.Name = 'Legs'
				chairlegs.Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
				chairlegs.CFrame = chair.CFrame * CFrame.new(0.047, -2.324, 0)
				chairlegs.MeshId = 'rbxassetid://13003181606'
				chairlegs.CanCollide = false
				chairlegs.Parent = chair
				local chairfan = Instance.new('MeshPart')
				chairfan.Color = chair.Color
				chairfan.Name = 'Fan'
				chairfan.Size = Vector3.zero
				chairfan.CFrame = chair.CFrame * CFrame.new(0, -1.873, 0)
				chairfan.MeshId = 'rbxassetid://13004977292'
				chairfan.CanCollide = false
				chairfan.Parent = chair
				local trails = {}
				for _, v in wheelpositions do
					local attachment = Instance.new('Attachment')
					attachment.Position = v
					attachment.Parent = chairlegs
					local attachment2 = Instance.new('Attachment')
					attachment2.Position = v + Vector3.new(0, 0, 0.18)
					attachment2.Parent = chairlegs
					local trail = Instance.new('Trail')
					trail.Texture = 'http://www.roblox.com/asset/?id=13005168530'
					trail.TextureMode = Enum.TextureMode.Static
					trail.Transparency = NumberSequence.new(0.5)
					trail.Color = ColorSequence.new(Color3.new(0.5, 0.5, 0.5))
					trail.Attachment0 = attachment
					trail.Attachment1 = attachment2
					trail.Lifetime = 20
					trail.MaxLength = 60
					trail.MinLength = 0.1
					trail.Parent = chairlegs
					table.insert(trails, trail)
				end
				GamingChair:Clean(chair)
				GamingChair:Clean(movingsound)
				GamingChair:Clean(flyingsound)
				chairanim = {Stop = function() end}
				local oldmoving = false
				local oldflying = false
				repeat
					if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
						if not chairanim.IsPlaying then
							local temp2 = Instance.new('Animation')
							temp2.AnimationId = entitylib.character.Humanoid.RigType == Enum.HumanoidRigType.R15 and 'http://www.roblox.com/asset/?id=2506281703' or 'http://www.roblox.com/asset/?id=178130996'
							chairanim = entitylib.character.Humanoid:LoadAnimation(temp2)
							chairanim.Priority = Enum.AnimationPriority.Movement
							chairanim.Looped = true
							chairanim:Play()
						end
						chair.CFrame = entitylib.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
						chairweld.Part1 = entitylib.character.RootPart
						chairlegs.Velocity = Vector3.zero
						chairlegs.CFrame = chair.CFrame * CFrame.new(0.047, -2.324, 0)
						chairfan.Velocity = Vector3.zero
						chairfan.CFrame = chair.CFrame * CFrame.new(0.047, -1.873, 0) * CFrame.Angles(0, math.rad(tick() * 180 % 360), math.rad(180))
						local moving = entitylib.character.Humanoid:GetState() == Enum.HumanoidStateType.Running and entitylib.character.Humanoid.MoveDirection ~= Vector3.zero
						local flying = vape.Modules.Fly and vape.Modules.Fly.Enabled or vape.Modules.LongJump and vape.Modules.LongJump.Enabled or vape.Modules.InfiniteFly and vape.Modules.InfiniteFly.Enabled
						if movingsound.TimePosition > 1.9 then
							movingsound.TimePosition = 0.2
						end
						movingsound.PlaybackSpeed = (entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)).Magnitude / 16
						for _, v in trails do
							v.Enabled = not flying and moving
							v.Color = ColorSequence.new(movingsound.PlaybackSpeed > 1.5 and Color3.new(1, 0.5, 0) or Color3.new())
						end
						if moving ~= oldmoving then
							if movingsound.IsPlaying then
								if not moving then
									movingsound:Stop()
								end
							else
								if not flying and moving then
									movingsound:Play()
								end
							end
							oldmoving = moving
						end
						if flying ~= oldflying then
							if flying then
								if movingsound.IsPlaying then
									movingsound:Stop()
								end
								if not flyingsound.IsPlaying then
									flyingsound:Play()
								end
								if currenttween then
									currenttween:Cancel()
								end
								tween = tweenService:Create(chairlegs, TweenInfo.new(0.15), {
									Size = Vector3.zero
								})
								tween.Completed:Connect(function(state)
									if state == Enum.PlaybackState.Completed then
										chairfan.Transparency = 0
										chairlegs.Transparency = 1
										tween = tweenService:Create(chairfan, TweenInfo.new(0.15), {
											Size = Vector3.new(1.534, 0.328, 1.537) / Vector3.new(791.138, 168.824, 792.027)
										})
										tween:Play()
									end
								end)
								tween:Play()
							else
								if flyingsound.IsPlaying then
									flyingsound:Stop()
								end
								if not movingsound.IsPlaying and moving then
									movingsound:Play()
								end
								if currenttween then currenttween:Cancel() end
								tween = tweenService:Create(chairfan, TweenInfo.new(0.15), {
									Size = Vector3.zero
								})
								tween.Completed:Connect(function(state)
									if state == Enum.PlaybackState.Completed then
										chairfan.Transparency = 1
										chairlegs.Transparency = 0
										tween = tweenService:Create(chairlegs, TweenInfo.new(0.15), {
											Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
										})
										tween:Play()
									end
								end)
								tween:Play()
							end
							oldflying = flying
						end
					else
						chair.Anchored = true
						chairlegs.Anchored = true
						chairfan.Anchored = true
						repeat task.wait() until entitylib.isAlive and entitylib.character.Humanoid.Health > 0
						chair.Anchored = false
						chairlegs.Anchored = false
						chairfan.Anchored = false
						chairanim:Stop()
					end
					task.wait()
				until not GamingChair.Enabled
			else
				if chairanim then
					chairanim:Stop()
				end
			end
		end,
		Tooltip = 'Sit in the best gaming chair known to mankind.'
	})
	Color = GamingChair:CreateColorSlider({
		Name = 'Color',
		Function = function(h, s, v)
			if chairhighlight then
				chairhighlight.OutlineColor = Color3.fromHSV(h, s, v)
			end
		end
	})
end)
	
run(function()
	local Health
	
	Health = vape.Categories.Render:CreateModule({
		Name = 'Health',
		Function = function(callback)
			if callback then
				local label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 30)
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.BackgroundTransparency = 1
				label.Text = '100 ❤️'
				label.TextSize = 18
				label.Font = Enum.Font.Arial
				label.Parent = vape.gui
				Health:Clean(label)
				
				repeat
					label.Text = entitylib.isAlive and math.round(entitylib.character.Humanoid.Health)..' ❤️' or ''
					label.TextColor3 = entitylib.isAlive and Color3.fromHSV((entitylib.character.Humanoid.Health / entitylib.character.Humanoid.MaxHealth) / 2.8, 0.86, 1) or Color3.new()
					task.wait()
				until not Health.Enabled
			end
		end,
		Tooltip = 'Displays your health in the center of your screen.'
	})
end)
	
run(function()
	local NameTags
	local Targets
	local Color
	local Background
	local DisplayName
	local Health
	local Distance
	local DrawingToggle
	local Scale
	local FontOption
	local Teammates
	local DistanceCheck
	local DistanceLimit
	local Strings, Sizes, Reference = {}, {}, {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local methodused
	
	local Added = {
		Normal = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
	
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
			end
	
			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end
	
			local nametag = Instance.new('TextLabel')
			nametag.TextSize = 14 * Scale.Value
			nametag.FontFace = FontOption.Value
			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = Background.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = Strings[ent]
			nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.RichText = true
			nametag.Parent = Folder
			Reference[ent] = nametag
		end,
		Drawing = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	
			local nametag = {}
			nametag.BG = Drawing.new('Square')
			nametag.BG.Filled = true
			nametag.BG.Transparency = 1 - Background.Value
			nametag.BG.Color = Color3.new()
			nametag.BG.ZIndex = 1
			nametag.Text = Drawing.new('Text')
			nametag.Text.Size = 15 * Scale.Value
			nametag.Text.Font = 0
			nametag.Text.ZIndex = 2
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
			end
	
			if Distance.Enabled then
				Strings[ent] = '[%s] '..Strings[ent]
			end
	
			nametag.Text.Text = Strings[ent]
			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
			Reference[ent] = nametag
		end
	}
	
	local Removed = {
		Normal = function(ent)
			local v = Reference[ent]
			if v then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				for _, obj in v do
					pcall(function()
						obj.Visible = false
						obj:Remove()
					end)
				end
			end
		end
	}
	
	local Updated = {
		Normal = function(ent)
			local nametag = Reference[ent]
			if nametag then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					local color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(color.R * 255))..','..tostring(math.floor(color.G * 255))..','..tostring(math.floor(color.B * 255))..')">'..math.round(ent.Health)..'</font>'
				end
	
				if Distance.Enabled then
					Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
				end
	
				local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
				nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
				nametag.Text = Strings[ent]
			end
		end,
		Drawing = function(ent)
			local nametag = Reference[ent]
			if nametag then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
				end
	
				if Distance.Enabled then
					Strings[ent] = '[%s] '..Strings[ent]
					nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				else
					nametag.Text.Text = Strings[ent]
				end
	
				nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
				nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			end
		end
	}
	
	local ColorFunc = {
		Normal = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.TextColor3 = entitylib.getEntityColor(i) or color
			end
		end,
		Drawing = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.Text.Color = entitylib.getEntityColor(i) or color
			end
		end
	}
	
	local Loop = {
		Normal = function()
			for ent, nametag in Reference do
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				nametag.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text = string.format(Strings[ent], mag)
						local ize = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
						nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
						Sizes[ent] = mag
					end
				end
				nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end,
		Drawing = function()
			for ent, nametag in Reference do
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Text.Visible = false
						nametag.BG.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				nametag.Text.Visible = headVis
				nametag.BG.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text.Text = string.format(Strings[ent], mag)
						nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
						Sizes[ent] = mag
					end
				end
				nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
				nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
			end
		end
	}
	
	NameTags = vape.Categories.Render:CreateModule({
		Name = 'NameTags',
		Function = function(callback)
			if callback then
				methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
				if Removed[methodused] then
					NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
				end
				if Added[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then
							Removed[methodused](v)
						end
						Added[methodused](v)
					end
					NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then
							Removed[methodused](ent)
						end
						Added[methodused](ent)
					end))
				end
				if Updated[methodused] then
					NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
					for _, v in entitylib.List do
						Updated[methodused](v)
					end
				end
				if ColorFunc[methodused] then
					NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if Loop[methodused] then
					NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
				end
			else
				if Removed[methodused] then
					for i in Reference do
						Removed[methodused](i)
					end
				end
			end
		end,
		Tooltip = 'Renders nametags on entities through walls.'
	})
	Targets = NameTags:CreateTargets({
		Players = true,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	FontOption = NameTags:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Color = NameTags:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if NameTags.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	Scale = NameTags:CreateSlider({
		Name = 'Scale',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10
	})
	Background = NameTags:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 10
	})
	Health = NameTags:CreateToggle({
		Name = 'Health',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Distance = NameTags:CreateToggle({
		Name = 'Distance',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	DisplayName = NameTags:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})
	Teammates = NameTags:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
	DrawingToggle = NameTags:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	DistanceCheck = NameTags:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = NameTags:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local PlayerModel
	local Scale
	local Local
	local Mesh
	local Texture
	local Rots = {}
	local models = {}
	
	local function addMesh(ent)
		if vape.ThreadFix then 
			setthreadidentity(8)
		end
		local root = ent.RootPart
		local part = Instance.new('Part')
		part.Size = Vector3.new(3, 3, 3)
		part.CFrame = root.CFrame * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
		part.Parent = workspace
		local meshd = Instance.new('SpecialMesh')
		meshd.MeshId = Mesh.Value
		meshd.TextureId = Texture.Value
		meshd.Scale = Vector3.one * Scale.Value
		meshd.Parent = part
		local weld = Instance.new('WeldConstraint')
		weld.Part0 = part
		weld.Part1 = root
		weld.Parent = part
		models[root] = part
	end
	
	local function removeMesh(ent)
		if models[ent.RootPart] then 
			models[ent.RootPart]:Destroy()
			models[ent.RootPart] = nil
		end
	end
	
	PlayerModel = vape.Categories.Render:CreateModule({
		Name = 'PlayerModel',
		Function = function(callback)
			if callback then 
				if Local.Enabled then 
					PlayerModel:Clean(entitylib.Events.LocalAdded:Connect(addMesh))
					PlayerModel:Clean(entitylib.Events.LocalRemoved:Connect(removeMesh))
					if entitylib.isAlive then 
						task.spawn(addMesh, entitylib.character)
					end
				end
				PlayerModel:Clean(entitylib.Events.EntityAdded:Connect(addMesh))
				PlayerModel:Clean(entitylib.Events.EntityRemoved:Connect(removeMesh))
				for _, ent in entitylib.List do 
					task.spawn(addMesh, ent)
				end
			else
				for _, part in models do 
					part:Destroy()
				end
				table.clear(models)
			end
		end,
		Tooltip = 'Change the player models to a Mesh'
	})
	Scale = PlayerModel:CreateSlider({
		Name = 'Scale',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 100,
		Function = function(val)
			for _, part in models do 
				part.Mesh.Scale = Vector3.one * val
			end
		end
	})
	for _, name in {'Rotation X', 'Rotation Y', 'Rotation Z'} do 
		table.insert(Rots, PlayerModel:CreateSlider({
			Name = name,
			Min = 0,
			Max = 360,
			Function = function(val)
				for root, part in models do 
					part.WeldConstraint.Enabled = false
					part.CFrame = root.CFrame * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
					part.WeldConstraint.Enabled = true
				end
			end
		}))
	end
	Local = PlayerModel:CreateToggle({
		Name = 'Local',
		Function = function()
			if PlayerModel.Enabled then 
				PlayerModel:Toggle()
				PlayerModel:Toggle()
			end
		end
	})
	Mesh = PlayerModel:CreateTextBox({
		Name = 'Mesh',
		Placeholder = 'mesh id',
		Function = function()
			for _, part in models do 
				part.Mesh.MeshId = Mesh.Value
			end
		end
	})
	Texture = PlayerModel:CreateTextBox({
		Name = 'Texture',
		Placeholder = 'texture id',
		Function = function()
			for _, part in models do 
				part.Mesh.TextureId = Texture.Value
			end
		end
	})
	
end)
	
run(function()
	local Radar
	local Targets
	local DotStyle
	local PlayerColor
	local Clamp
	local Reference = {}
	local bkg
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local dot = Instance.new('Frame')
		dot.Size = UDim2.fromOffset(4, 4)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
		dot.Parent = bkg
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(DotStyle.Value == 'Circles' and 1 or 0, 0)
		corner.Parent = dot
		local stroke = Instance.new('UIStroke')
		stroke.Color = Color3.new()
		stroke.Thickness = 1
		stroke.Transparency = 0.8
		stroke.Parent = dot
		Reference[ent] = dot
	end
	
	local function Removed(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			v:Destroy()
		end
	end
	
	Radar = vape:CreateOverlay({
		Name = 'Radar',
		Icon = getcustomasset('newvape/assets/new/radaricon.png'),
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(12, 13),
		Function = function(callback)
			if callback then
				Radar:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				for _, v in entitylib.List do
					if Reference[v] then
						Removed(v)
					end
					Added(v)
				end
				Radar:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed(ent)
					end
					Added(ent)
				end))
				Radar:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					for ent, dot in Reference do
						dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
					end
				end))
				Radar:Clean(runService.RenderStepped:Connect(function()
					for ent, dot in Reference do
						if entitylib.isAlive then
							local dt = CFrame.lookAlong(entitylib.character.RootPart.Position, gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):PointToObjectSpace(ent.RootPart.Position)
							dot.Position = UDim2.fromOffset(Clamp.Enabled and math.clamp(108 + dt.X, 2, 214) or 108 + dt.X, Clamp.Enabled and math.clamp(108 + dt.Z, 8, 214) or 108 + dt.Z)
						end
					end
				end))
			else
				for ent in Reference do
					Removed(ent)
				end
			end
		end
	})
	Targets = Radar:CreateTargets({
		Players = true,
		Function = function()
			if Radar.Button.Enabled then
				Radar.Button:Toggle()
				Radar.Button:Toggle()
			end
		end
	})
	DotStyle = Radar:CreateDropdown({
		Name = 'Dot Style',
		List = {'Circles', 'Squares'},
		Function = function(val)
			for _, dot in Reference do
				dot.UICorner.CornerRadius = UDim.new(val == 'Circles' and 1 or 0, 0)
			end
		end
	})
	PlayerColor = Radar:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			for ent, dot in Reference do
				dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(hue, sat, val)
			end
		end
	})
	bkg = Instance.new('Frame')
	bkg.Size = UDim2.fromOffset(216, 216)
	bkg.Position = UDim2.fromOffset(2, 2)
	bkg.BackgroundColor3 = Color3.new()
	bkg.BackgroundTransparency = 0.5
	bkg.ClipsDescendants = true
	bkg.Parent = Radar.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bkg
	local stroke = Instance.new('UIStroke')
	stroke.Thickness = 2
	stroke.Color = Color3.new()
	stroke.Transparency = 0.4
	stroke.Parent = bkg
	local line1 = Instance.new('Frame')
	line1.Size = UDim2.new(0, 2, 1, 0)
	line1.Position = UDim2.fromScale(0.5, 0.5)
	line1.AnchorPoint = Vector2.new(0.5, 0.5)
	line1.ZIndex = 0
	line1.BackgroundColor3 = Color3.new(1, 1, 1)
	line1.BackgroundTransparency = 0.5
	line1.BorderSizePixel = 0
	line1.Parent = bkg
	local line2 = line1:Clone()
	line2.Size = UDim2.new(1, 0, 0, 2)
	line2.Parent = bkg
	local bar = Instance.new('Frame')
	bar.Size = UDim2.new(1, -6, 0, 4)
	bar.Position = UDim2.fromOffset(3, 0)
	bar.BackgroundColor3 = Color3.fromHSV(0.44, 1, 1)
	bar.Parent = bkg
	local barcorner = Instance.new('UICorner')
	barcorner.CornerRadius = UDim.new(0, 8)
	barcorner.Parent = bar
	Radar:CreateColorSlider({
		Name = 'Bar Color',
		Function = function(hue, sat, val)
			bar.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		end
	})
	Radar:CreateToggle({
		Name = 'Show Background',
		Default = true,
		Function = function(callback)
			bkg.BackgroundTransparency = callback and 0.5 or 1
			bar.BackgroundTransparency = callback and 0 or 1
			stroke.Transparency = callback and 0.4 or 1
		end
	})
	Radar:CreateToggle({
		Name = 'Show Cross',
		Default = true,
		Function = function(callback)
			line1.BackgroundTransparency = callback and 0.5 or 1
			line2.BackgroundTransparency = callback and 0.5 or 1
		end
	})
	Clamp = Radar:CreateToggle({
		Name = 'Clamp Radar',
		Default = true
	})
end)
	
run(function()
	local Search
	local List
	local Color
	local FillTransparency
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Add(v)
		if not table.find(List.ListEnabled, v.Name) then return end
		if v:IsA('BasePart') or v:IsA('Model') then
			local box = Instance.new('BoxHandleAdornment')
			box.AlwaysOnTop = true
			box.Adornee = v
			box.Size = v:IsA('Model') and v:GetExtentsSize() or v.Size
			box.ZIndex = 0
			box.Transparency = FillTransparency.Value
			box.Color3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			box.Parent = Folder
			Reference[v] = box
		end
	end
	
	Search = vape.Categories.Render:CreateModule({
		Name = 'Search',
		Function = function(callback)
			if callback then
				Search:Clean(workspace.DescendantAdded:Connect(Add))
				Search:Clean(workspace.DescendantRemoving:Connect(function(v)
					if Reference[v] then
						Reference[v]:Destroy()
						Reference[v] = nil
					end
				end))
				
				for _, v in workspace:GetDescendants() do
					Add(v)
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'Draws box around selected parts\nAdd parts in Search frame'
	})
	List = Search:CreateTextList({
		Name = 'Parts',
		Function = function()
			if Search.Enabled then
				Search:Toggle()
				Search:Toggle()
			end
		end
	})
	Color = Search:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for _, v in Reference do
				v.Color3 = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	FillTransparency = Search:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Function = function(val)
			for _, v in Reference do
				v.Transparency = val
			end
		end,
		Decimal = 10
	})
end)
	
run(function()
	local SessionInfo
	local FontOption
	local Hide
	local TextSize
	local BorderColor
	local Title
	local TitleOffset = {}
	local Custom
	local CustomBox
	local infoholder
	local infolabel
	local infostroke
	
	SessionInfo = vape:CreateOverlay({
		Name = 'Session Info',
		Icon = getcustomasset('newvape/assets/new/textguiicon.png'),
		Size = UDim2.fromOffset(16, 12),
		Position = UDim2.fromOffset(12, 14),
		Function = function(callback)
			if callback then
				local teleportedServers
				SessionInfo:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
					if not teleportedServers then
						teleportedServers = true
						queue_on_teleport("shared.vapesessioninfo = '"..httpService:JSONEncode(vape.Libraries.sessioninfo.Objects).."'")
					end
				end))
	
				if shared.vapesessioninfo then
					for i, v in httpService:JSONDecode(shared.vapesessioninfo) do
						if vape.Libraries.sessioninfo.Objects[i] and v.Saved then
							vape.Libraries.sessioninfo.Objects[i].Value = v.Value
						end
					end
				end
	
				repeat
					if vape.Libraries.sessioninfo then
						local stuff = {''}
						if Title.Enabled then
							stuff[1] = TitleOffset.Enabled and '<b>Session Info</b>\n<font size="4"> </font>' or '<b>Session Info</b>'
						end
	
						for i, v in vape.Libraries.sessioninfo.Objects do
							stuff[v.Index] = not table.find(Hide.ListEnabled, i) and i..': '..v.Function(v.Value) or false
						end
	
						if #Hide.ListEnabled > 0 then
							local key, val
							repeat
								local oldkey = key
								key, val = next(stuff, key)
								if val == false then
									table.remove(stuff, key)
									key = oldkey
								end
							until not key
						end
	
						if Custom.Enabled then
							table.insert(stuff, CustomBox.Value)
						end
	
						if not Title.Enabled then
							table.remove(stuff, 1)
						end
						infolabel.Text = table.concat(stuff, '\n')
						infolabel.FontFace = FontOption.Value
						infolabel.TextSize = TextSize.Value
						local size = getfontsize(removeTags(infolabel.Text), infolabel.TextSize, infolabel.FontFace)
						infoholder.Size = UDim2.fromOffset(size.X + 16, size.Y + (Title.Enabled and TitleOffset.Enabled and 4 or 16))
					end
					task.wait(1)
				until not SessionInfo.Button or not SessionInfo.Button.Enabled
			end
		end
	})
	FontOption = SessionInfo:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial'
	})
	Hide = SessionInfo:CreateTextList({
		Name = 'Blacklist',
		Tooltip = 'Name of entry to hide.',
		Icon = getcustomasset('newvape/assets/new/blockedicon.png'),
		Tab = getcustomasset('newvape/assets/new/blockedtab.png'),
		TabSize = UDim2.fromOffset(21, 16),
		Color = Color3.fromRGB(250, 50, 56)
	})
	SessionInfo:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			infoholder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			infoholder.BackgroundTransparency = 1 - opacity
		end
	})
	BorderColor = SessionInfo:CreateColorSlider({
		Name = 'Border Color',
		Function = function(hue, sat, val, opacity)
			infostroke.Color = Color3.fromHSV(hue, sat, val)
			infostroke.Transparency = 1 - opacity
		end,
		Darker = true,
		Visible = false
	})
	TextSize = SessionInfo:CreateSlider({
		Name = 'Text Size',
		Min = 1,
		Max = 30,
		Default = 16
	})
	Title = SessionInfo:CreateToggle({
		Name = 'Title',
		Function = function(callback)
			if TitleOffset.Object then
				TitleOffset.Object.Visible = callback
			end
		end,
		Default = true
	})
	TitleOffset = SessionInfo:CreateToggle({
		Name = 'Offset',
		Default = true,
		Darker = true
	})
	SessionInfo:CreateToggle({
		Name = 'Border',
		Function = function(callback)
			infostroke.Enabled = callback
			BorderColor.Object.Visible = callback
		end
	})
	Custom = SessionInfo:CreateToggle({
		Name = 'Add custom text',
		Function = function(enabled)
			CustomBox.Object.Visible = enabled
		end
	})
	CustomBox = SessionInfo:CreateTextBox({
		Name = 'Custom text',
		Darker = true,
		Visible = false
	})
	infoholder = Instance.new('Frame')
	infoholder.BackgroundColor3 = Color3.new()
	infoholder.BackgroundTransparency = 0.5
	infoholder.Parent = SessionInfo.Children
	vape:Clean(SessionInfo.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local newside = SessionInfo.Children.AbsolutePosition.X > (vape.gui.AbsoluteSize.X / 2)
		infoholder.Position = UDim2.fromScale(newside and 1 or 0, 0)
		infoholder.AnchorPoint = Vector2.new(newside and 1 or 0, 0)
	end))
	local sessioninfocorner = Instance.new('UICorner')
	sessioninfocorner.CornerRadius = UDim.new(0, 5)
	sessioninfocorner.Parent = infoholder
	infolabel = Instance.new('TextLabel')
	infolabel.Size = UDim2.new(1, -16, 1, -16)
	infolabel.Position = UDim2.fromOffset(8, 8)
	infolabel.BackgroundTransparency = 1
	infolabel.TextXAlignment = Enum.TextXAlignment.Left
	infolabel.TextYAlignment = Enum.TextYAlignment.Top
	infolabel.TextSize = 16
	infolabel.TextColor3 = Color3.new(1, 1, 1)
	infolabel.TextStrokeColor3 = Color3.new()
	infolabel.TextStrokeTransparency = 0.8
	infolabel.Font = Enum.Font.Arial
	infolabel.RichText = true
	infolabel.Parent = infoholder
	infostroke = Instance.new('UIStroke')
	infostroke.Enabled = false
	infostroke.Color = Color3.fromHSV(0.44, 1, 1)
	infostroke.Parent = infoholder
	addBlur(infoholder)
	vape.Libraries.sessioninfo = {
		Objects = {},
		AddItem = function(self, name, startvalue, func, saved)
			func, saved = func or function(val) return val end, saved == nil or saved
			self.Objects[name] = {Function = func, Saved = saved, Value = startvalue or 0, Index = getTableSize(self.Objects) + 2}
			return {
				Increment = function(_, val)
					self.Objects[name].Value += (val or 1)
				end,
				Get = function()
					return self.Objects[name].Value
				end
			}
		end
	}
	vape.Libraries.sessioninfo:AddItem('Time Played', os.clock(), function(value)
		return os.date('!%X', math.floor(os.clock() - value))
	end)
end)
	
run(function()
	local Tracers
	local Targets
	local Color
	local Transparency
	local StartPosition
	local EndPosition
	local Teammates
	local DistanceColor
	local Distance
	local DistanceLimit
	local Behind
	local Reference = {}
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local EntityTracer = Drawing.new('Line')
		EntityTracer.Thickness = 1
		EntityTracer.Transparency = 1 - Transparency.Value
		EntityTracer.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		Reference[ent] = EntityTracer
	end
	
	local function Removed(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			pcall(function()
				v.Visible = false
				v:Remove()
			end)
		end
	end
	
	local function ColorFunc(hue, sat, val)
		if DistanceColor.Enabled then return end
		local tracerColor = Color3.fromHSV(hue, sat, val)
		for ent, EntityTracer in Reference do
			EntityTracer.Color = entitylib.getEntityColor(ent) or tracerColor
		end
	end
	
	local function Loop()
		local screenSize = vape.gui.AbsoluteSize
		local startVector = StartPosition.Value == 'Mouse' and inputService:GetMouseLocation() or Vector2.new(screenSize.X / 2, (StartPosition.Value == 'Middle' and screenSize.Y / 2 or screenSize.Y))
	
		for ent, EntityTracer in Reference do
			local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
			if Distance.Enabled and distance then
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					EntityTracer.Visible = false
					continue
				end
			end
	
			local pos = ent[EndPosition.Value == 'Torso' and 'RootPart' or 'Head'].Position
			local rootPos, rootVis = gameCamera:WorldToViewportPoint(pos)
			if not rootVis and Behind.Enabled then
				local tempPos = gameCamera.CFrame:PointToObjectSpace(pos)
				tempPos = CFrame.Angles(0, 0, (math.atan2(tempPos.Y, tempPos.X) + math.pi)):VectorToWorldSpace((CFrame.Angles(0, math.rad(89.9), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))))
				rootPos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(tempPos))
				rootVis = true
			end
	
			local endVector = Vector2.new(rootPos.X, rootPos.Y)
			EntityTracer.Visible = rootVis
			EntityTracer.From = startVector
			EntityTracer.To = endVector
			if DistanceColor.Enabled and distance then
				EntityTracer.Color = Color3.fromHSV(math.min((distance / 128) / 2.8, 0.4), 0.89, 0.75)
			end
		end
	end
	
	Tracers = vape.Categories.Render:CreateModule({
		Name = 'Tracers',
		Function = function(callback)
			if callback then
				Tracers:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				for _, v in entitylib.List do
					if Reference[v] then
						Removed(v)
					end
					Added(v)
				end
				Tracers:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed(ent)
					end
					Added(ent)
				end))
				Tracers:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc(Color.Hue, Color.Sat, Color.Value)
				end))
				Tracers:Clean(runService.RenderStepped:Connect(Loop))
			else
				for i in Reference do
					Removed(i)
				end
			end
		end,
		Tooltip = 'Renders tracers on players.'
	})
	Targets = Tracers:CreateTargets({
		Players = true,
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end
	})
	StartPosition = Tracers:CreateDropdown({
		Name = 'Start Position',
		List = {'Middle', 'Bottom', 'Mouse'},
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end
	})
	EndPosition = Tracers:CreateDropdown({
		Name = 'End Position',
		List = {'Head', 'Torso'},
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end
	})
	Color = Tracers:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if Tracers.Enabled then
				ColorFunc(hue, sat, val)
			end
		end
	})
	Transparency = Tracers:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Function = function(val)
			for _, tracer in Reference do
				tracer.Transparency = 1 - val
			end
		end,
		Decimal = 10
	})
	DistanceColor = Tracers:CreateToggle({
		Name = 'Color by distance',
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end
	})
	Distance = Tracers:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = Tracers:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
	Behind = Tracers:CreateToggle({
		Name = 'Behind',
		Default = true
	})
	Teammates = Tracers:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
end)
	
run(function()
	local Waypoints
	local FontOption
	local List
	local Color
	local Scale
	local Background
	WaypointFolder = Instance.new('Folder')
	WaypointFolder.Parent = vape.gui
	
	Waypoints = vape.Categories.Render:CreateModule({
		Name = 'Waypoints',
		Function = function(callback)
			if callback then
				for _, v in List.ListEnabled do
					local split = v:split('/')
					local tagSize = getfontsize(removeTags(split[2]), 14 * Scale.Value, FontOption.Value, Vector2.new(100000, 100000))
					local billboard = Instance.new('BillboardGui')
					billboard.Size = UDim2.fromOffset(tagSize.X + 8, tagSize.Y + 7)
					billboard.StudsOffsetWorldSpace = Vector3.new(unpack(split[1]:split(',')))
					billboard.AlwaysOnTop = true
					billboard.Parent = WaypointFolder
					local tag = Instance.new('TextLabel')
					tag.BackgroundColor3 = Color3.new()
					tag.BorderSizePixel = 0
					tag.Visible = true
					tag.RichText = true
					tag.FontFace = FontOption.Value
					tag.TextSize = 14 * Scale.Value
					tag.BackgroundTransparency = Background.Value
					tag.Size = billboard.Size
					tag.Text = split[2]
					tag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					tag.Parent = billboard
				end
			else
				WaypointFolder:ClearAllChildren()
			end
		end,
		Tooltip = 'Mark certain spots with a visual indicator'
	})
	FontOption = Waypoints:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if Waypoints.Enabled then
				Waypoints:Toggle()
				Waypoints:Toggle()
			end
		end,
	})
	List = Waypoints:CreateTextList({
		Name = 'Points',
		Placeholder = 'x, y, z/name',
		Function = function()
			if Waypoints.Enabled then
				Waypoints:Toggle()
				Waypoints:Toggle()
			end
		end
	})
	Waypoints:CreateButton({
		Name = 'Add current position',
		Function = function()
			if entitylib.isAlive then
				local pos = entitylib.character.RootPart.Position // 1
				List:ChangeValue(pos.X..','..pos.Y..','..pos.Z..'/Waypoint '..(#List.List + 1))
			end
		end
	})
	Color = Waypoints:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for _, v in WaypointFolder:GetChildren() do
				v.TextLabel.TextColor3 = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	Scale = Waypoints:CreateSlider({
		Name = 'Scale',
		Function = function()
			if Waypoints.Enabled then
				Waypoints:Toggle()
				Waypoints:Toggle()
			end
		end,
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10
	})
	Background = Waypoints:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if Waypoints.Enabled then
				Waypoints:Toggle()
				Waypoints:Toggle()
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 10
	})
	
end)
	
run(function()
	local AnimationPlayer
	local IDBox
	local Priority
	local Speed
	local anim, animobject
	
	local function playAnimation(char)
		local animcheck = anim
		if animcheck then
			anim = nil
			animcheck:Stop()
		end
	
		local suc, res = pcall(function()
			anim = char.Humanoid.Animator:LoadAnimation(animobject)
		end)
	
		if suc then
			local currentanim = anim
			anim.Priority = Enum.AnimationPriority[Priority.Value]
			anim:Play()
			anim:AdjustSpeed(Speed.Value)
			AnimationPlayer:Clean(anim.Stopped:Connect(function()
				if currentanim == anim then
					anim:Play()
				end
			end))
		else
			notif('AnimationPlayer', 'failed to load anim : '..(res or 'invalid animation id'), 5, 'warning')
		end
	end
	
	AnimationPlayer = vape.Categories.Utility:CreateModule({
		Name = 'AnimationPlayer',
		Function = function(callback)
			if callback then
				animobject = Instance.new('Animation')
				local suc, id = pcall(function()
					return string.match(game:GetObjects('rbxassetid://'..IDBox.Value)[1].AnimationId, '%?id=(%d+)')
				end)
				animobject.AnimationId = 'rbxassetid://'..(suc and id or IDBox.Value)
	
				if entitylib.isAlive then
					playAnimation(entitylib.character)
				end
				AnimationPlayer:Clean(entitylib.Events.LocalAdded:Connect(playAnimation))
				AnimationPlayer:Clean(animobject)
			else
				if anim then
					anim:Stop()
				end
			end
		end,
		Tooltip = 'Plays a specific animation of your choosing at a certain speed'
	})
	IDBox = AnimationPlayer:CreateTextBox({
		Name = 'Animation',
		Placeholder = 'anim (num only)',
		Function = function(enter)
			if enter and AnimationPlayer.Enabled then
				AnimationPlayer:Toggle()
				AnimationPlayer:Toggle()
			end
		end
	})
	local prio = {'Action4'}
	for _, v in Enum.AnimationPriority:GetEnumItems() do
		if v.Name ~= 'Action4' then
			table.insert(prio, v.Name)
		end
	end
	Priority = AnimationPlayer:CreateDropdown({
		Name = 'Priority',
		List = prio,
		Function = function(val)
			if anim then
				anim.Priority = Enum.AnimationPriority[val]
			end
		end
	})
	Speed = AnimationPlayer:CreateSlider({
		Name = 'Speed',
		Function = function(val)
			if anim then
				anim:AdjustSpeed(val)
			end
		end,
		Min = 0.1,
		Max = 2,
		Decimal = 10
	})
end)
	
run(function()
	local AntiRagdoll
	
	AntiRagdoll = vape.Categories.Utility:CreateModule({
		Name = 'AntiRagdoll',
		Function = function(callback)
			if entitylib.isAlive then
				entitylib.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not callback)
			end
	
			if callback then
				AntiRagdoll:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				end))
			end
		end,
		Tooltip = 'Prevents you from getting knocked down in a ragdoll state'
	})
end)
	
run(function()
	local AutoRejoin
	local Sort
	
	AutoRejoin = vape.Categories.Utility:CreateModule({
		Name = 'AutoRejoin',
		Function = function(callback)
			if callback then
				local check
				AutoRejoin:Clean(guiService.ErrorMessageChanged:Connect(function(str)
					if (not check or guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectLuaKick) and guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectConnectionLost and not str:lower():find('ban') then
						check = true
						serverHop(nil, Sort.Value)
					end
				end))
			end
		end,
		Tooltip = 'Automatically rejoins into a new server if you get disconnected / kicked'
	})
	Sort = AutoRejoin:CreateDropdown({
		Name = 'Sort',
		List = {'Descending', 'Ascending'},
		Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
	})
end)
	
run(function()
	local Blink
	local Type
	local AutoSend
	local AutoSendLength
	local oldphys, oldsend
	
	Blink = vape.Categories.Utility:CreateModule({
		Name = 'Blink',
		Function = function(callback)
			if callback then
				local teleported
				Blink:Clean(lplr.OnTeleport:Connect(function()
					setfflag('PhysicsSenderMaxBandwidthBps', '38760')
					setfflag('DataSenderRate', '60')
					teleported = true
				end))
	
				repeat
					local physicsrate, senderrate = '0', Type.Value == 'All' and '-1' or '60'
					if AutoSend.Enabled and tick() % (AutoSendLength.Value + 0.1) > AutoSendLength.Value then
						physicsrate, senderrate = '38760', '60'
					end
	
					if physicsrate ~= oldphys or senderrate ~= oldsend then
						setfflag('PhysicsSenderMaxBandwidthBps', physicsrate)
						setfflag('DataSenderRate', senderrate)
						oldphys, oldsend = physicsrate, senderrate
					end
	
					task.wait(0.03)
				until (not Blink.Enabled and not teleported)
			else
				if setfflag then
					setfflag('PhysicsSenderMaxBandwidthBps', '38760')
					setfflag('DataSenderRate', '60')
				end
				oldphys, oldsend = nil, nil
			end
		end,
		Tooltip = 'Chokes packets until disabled.'
	})
	Type = Blink:CreateDropdown({
		Name = 'Type',
		List = {'Movement Only', 'All'},
		Tooltip = 'Movement Only - Only chokes movement packets\nAll - Chokes remotes & movement'
	})
	AutoSend = Blink:CreateToggle({
		Name = 'Auto send',
		Function = function(callback)
			AutoSendLength.Object.Visible = callback
		end,
		Tooltip = 'Automatically send packets in intervals'
	})
	AutoSendLength = Blink:CreateSlider({
		Name = 'Send threshold',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
end)
	
run(function()
	local ChatSpammer
	local Lines
	local Mode
	local Delay
	local Hide
	local oldchat
	
	ChatSpammer = vape.Categories.Utility:CreateModule({
		Name = 'ChatSpammer',
		Function = function(callback)
			if callback then
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					if Hide.Enabled and coreGui:FindFirstChild('ExperienceChat') then
						ChatSpammer:Clean(coreGui.ExperienceChat:FindFirstChild('RCTScrollContentView', true).ChildAdded:Connect(function(msg)
							if msg.Name:sub(1, 2) == '0-' and msg.ContentText == 'You must wait before sending another message.' then
								msg.Visible = false
							end
						end))
					end
				elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
					if Hide.Enabled then
						oldchat = hookfunction(getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, function(data, ...)
							if data.Message:find('ChatFloodDetector') then return end
							return oldchat(data, ...)
						end)
					end
				else
					notif('ChatSpammer', 'unsupported chat', 5, 'warning')
					ChatSpammer:Toggle()
					return
				end
				
				local ind = 1
				repeat
					local message = (#Lines.ListEnabled > 0 and Lines.ListEnabled[math.random(1, #Lines.ListEnabled)] or 'vxpe on top')
					if Mode.Value == 'Order' and #Lines.ListEnabled > 0 then
						message = Lines.ListEnabled[ind] or Lines.ListEnabled[1]
						ind = (ind % #Lines.ListEnabled) + 1
					end
	
					if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
						textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
					else
						replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
					end
	
					task.wait(Delay.Value)
				until not ChatSpammer.Enabled
			else
				if oldchat then
					hookfunction(getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, oldchat)
				end
			end
		end,
		Tooltip = 'Automatically types in chat'
	})
	Lines = ChatSpammer:CreateTextList({Name = 'Lines'})
	Mode = ChatSpammer:CreateDropdown({
		Name = 'Mode',
		List = {'Random', 'Order'}
	})
	Delay = ChatSpammer:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 10,
		Default = 1,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Hide = ChatSpammer:CreateToggle({
		Name = 'Hide Flood Message',
		Default = true,
		Function = function()
			if ChatSpammer.Enabled then
				ChatSpammer:Toggle()
				ChatSpammer:Toggle()
			end
		end
	})
end)
	
run(function()
	local Disabler
	
	local function characterAdded(char)
		for _, v in getconnections(char.RootPart:GetPropertyChangedSignal('CFrame')) do
			hookfunction(v.Function, function() end)
		end
		for _, v in getconnections(char.RootPart:GetPropertyChangedSignal('Velocity')) do
			hookfunction(v.Function, function() end)
		end
	end
	
	Disabler = vape.Categories.Utility:CreateModule({
		Name = 'Disabler',
		Function = function(callback)
			if callback then
				Disabler:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
				if entitylib.isAlive then
					characterAdded(entitylib.character)
				end
			end
		end,
		Tooltip = 'Disables GetPropertyChangedSignal detections for movement'
	})
end)
	
run(function()
	vape.Categories.Utility:CreateModule({
		Name = 'Panic',
		Function = function(callback)
			if callback then
				for _, v in vape.Modules do
					if v.Enabled then
						v:Toggle()
					end
				end
			end
		end,
		Tooltip = 'Disables all currently enabled modules'
	})
end)
	
run(function()
	local Rejoin
	
	Rejoin = vape.Categories.Utility:CreateModule({
		Name = 'Rejoin',
		Function = function(callback)
			if callback then
				notif('Rejoin', 'Rejoining...', 5)
				Rejoin:Toggle()
				if playersService.NumPlayers > 1 then
					teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
				else
					teleportService:Teleport(game.PlaceId)
				end
			end
		end,
		Tooltip = 'Rejoins the server'
	})
end)
	
run(function()
	local ServerHop
	local Sort
	
	ServerHop = vape.Categories.Utility:CreateModule({
		Name = 'ServerHop',
		Function = function(callback)
			if callback then
				ServerHop:Toggle()
				serverHop(nil, Sort.Value)
			end
		end,
		Tooltip = 'Teleports into a unique server'
	})
	Sort = ServerHop:CreateDropdown({
		Name = 'Sort',
		List = {'Descending', 'Ascending'},
		Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
	})
	ServerHop:CreateButton({
		Name = 'Rejoin Previous Server',
		Function = function()
			notif('ServerHop', shared.vapeserverhopprevious and 'Rejoining previous server...' or 'Cannot find previous server', 5)
			if shared.vapeserverhopprevious then
				teleportService:TeleportToPlaceInstance(game.PlaceId, shared.vapeserverhopprevious)
			end
		end
	})
end)
	
run(function()
	local StaffDetector
	local Mode
	local Profile
	local Users
	local Group
	local Role
	
	local function getRole(plr, id)
		local suc, res
		for _ = 1, 3 do
			suc, res = pcall(function()
				return plr:GetRankInGroup(id)
			end)
			if suc then break end
		end
		return suc and res or 0
	end
	
	local function getLowestStaffRole(roles)
		local highest = math.huge
		for _, v in roles do
			local low = v.Name:lower()
			if (low:find('admin') or low:find('mod') or low:find('dev')) and v.Rank < highest then
				highest = v.Rank
			end
		end
		return highest
	end
	
	local function playerAdded(plr)
		if not vape.Loaded then
			repeat task.wait() until vape.Loaded
		end
	
		local user = table.find(Users.ListEnabled, tostring(plr.UserId))
		if user or getRole(plr, tonumber(Group.Value) or 0) >= (tonumber(Role.Value) or 1) then
			notif('StaffDetector', 'Staff Detected ('..(user and 'blacklisted_user' or 'staff_role')..'): '..plr.Name, 60, 'alert')
			whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}
	
			if Mode.Value == 'Uninject' then
				task.spawn(function()
					vape:Uninject()
				end)
				game:GetService('StarterGui'):SetCore('SendNotification', {
					Title = 'StaffDetector',
					Text = 'Staff Detected\n'..plr.Name,
					Duration = 60,
				})
			elseif Mode.Value == 'ServerHop' then
				serverHop()
			elseif Mode.Value == 'Profile' then
				vape.Save = function() end
				if vape.Profile ~= Profile.Value then
					vape.Profile = Profile.Value
					vape:Load(true, Profile.Value)
				end
			elseif Mode.Value == 'AutoConfig' then
				vape.Save = function() end
				for _, v in vape.Modules do
					if v.Enabled then
						v:Toggle()
					end
				end
			end
		end
	end
	
	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				if Group.Value == '' or Role.Value == '' then
					local placeinfo = {Creator = {CreatorTargetId = tonumber(Group.Value)}}
					if Group.Value == '' then
						placeinfo = marketplaceService:GetProductInfo(game.PlaceId)
						if placeinfo.Creator.CreatorType ~= 'Group' then
							local desc = placeinfo.Description:split('\n')
							for _, str in desc do
								local _, begin = str:find('roblox.com/groups/')
								if begin then
									local endof = str:find('/', begin + 1)
									placeinfo = {Creator = {
										CreatorType = 'Group',
										CreatorTargetId = str:sub(begin + 1, endof - 1)
									}}
								end
							end
						end
	
						if placeinfo.Creator.CreatorType ~= 'Group' then
							notif('StaffDetector', 'Automatic Setup Failed (no group detected)', 60, 'warning')
							return
						end
					end
	
					local groupinfo = groupService:GetGroupInfoAsync(placeinfo.Creator.CreatorTargetId)
					Group:SetValue(placeinfo.Creator.CreatorTargetId)
					Role:SetValue(getLowestStaffRole(groupinfo.Roles))
				end
	
				if Group.Value == '' or Role.Value == '' then
					return
				end
	
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				for _, v in playersService:GetPlayers() do
					task.spawn(playerAdded, v)
				end
			end
		end,
		Tooltip = 'Detects people with a staff rank ingame'
	})
	Mode = StaffDetector:CreateDropdown({
		Name = 'Mode',
		List = {'Uninject', 'ServerHop', 'Profile', 'AutoConfig', 'Notify'},
		Function = function(val)
			if Profile.Object then
				Profile.Object.Visible = val == 'Profile'
			end
		end
	})
	Profile = StaffDetector:CreateTextBox({
		Name = 'Profile',
		Default = 'default',
		Darker = true,
		Visible = false
	})
	Users = StaffDetector:CreateTextList({
		Name = 'Users',
		Placeholder = 'player (userid)'
	})
	Group = StaffDetector:CreateTextBox({
		Name = 'Group',
		Placeholder = 'Group Id'
	})
	Role = StaffDetector:CreateTextBox({
		Name = 'Role',
		Placeholder = 'Role Rank'
	})
end)
	
run(function()
	local connections = {}
	
	vape.Categories.World:CreateModule({
		Name = 'Anti-AFK',
		Function = function(callback)
			if callback then
				for _, v in getconnections(lplr.Idled) do
					table.insert(connections, v)
					v:Disable()
				end
			else
				for _, v in connections do
					v:Enable()
				end
				table.clear(connections)
			end
		end,
		Tooltip = 'Lets you stay ingame without getting kicked'
	})
end)
	
run(function()
	local Freecam
	local Value
	local randomkey, module, old = httpService:GenerateGUID(false)
	
	Freecam = vape.Categories.World:CreateModule({
		Name = 'Freecam',
		Function = function(callback)
			if callback then
				repeat
					task.wait(0.1)
					for _, v in getconnections(gameCamera:GetPropertyChangedSignal('CameraType')) do
						if v.Function then
							module = debug.getupvalue(v.Function, 1)
						end
					end
				until module or not Freecam.Enabled
	
				if module and module.activeCameraController and Freecam.Enabled then
					old = module.activeCameraController.GetSubjectPosition
					local camPos = old(module.activeCameraController) or Vector3.zero
					module.activeCameraController.GetSubjectPosition = function()
						return camPos
					end
	
					Freecam:Clean(runService.PreSimulation:Connect(function(dt)
						if not inputService:GetFocusedTextBox() then
							local forward = (inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
							local side = (inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
							local up = (inputService:IsKeyDown(Enum.KeyCode.Q) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.E) and 1 or 0)
							dt = dt * (inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 0.25 or 1)
							camPos = (CFrame.lookAlong(camPos, gameCamera.CFrame.LookVector) * CFrame.new(Vector3.new(side, up, forward) * (Value.Value * dt))).Position
						end
					end))
	
					contextService:BindActionAtPriority('FreecamKeyboard'..randomkey, function()
						return Enum.ContextActionResult.Sink
					end, false, Enum.ContextActionPriority.High.Value,
						Enum.KeyCode.W,
						Enum.KeyCode.A,
						Enum.KeyCode.S,
						Enum.KeyCode.D,
						Enum.KeyCode.E,
						Enum.KeyCode.Q,
						Enum.KeyCode.Up,
						Enum.KeyCode.Down
					)
				end
			else
				pcall(function()
					contextService:UnbindAction('FreecamKeyboard'..randomkey)
				end)
				if module and old then
					module.activeCameraController.GetSubjectPosition = old
					module = nil
					old = nil
				end
			end
		end,
		Tooltip = 'Lets you fly and clip through walls freely\nwithout moving your player server-sided.'
	})
	Value = Freecam:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local Gravity
	local Mode
	local Value
	local changed, old = false
	
	Gravity = vape.Categories.World:CreateModule({
		Name = 'Gravity',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Workspace' then
					old = workspace.Gravity
					workspace.Gravity = Value.Value
					Gravity:Clean(workspace:GetPropertyChangedSignal('Gravity'):Connect(function()
						if changed then return end
						changed = true
						old = workspace.Gravity
						workspace.Gravity = Value.Value
						changed = false
					end))
				else
					Gravity:Clean(runService.PreSimulation:Connect(function(dt)
						if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air then
							local root = entitylib.character.RootPart
							if Mode.Value == 'Impulse' then
								root:ApplyImpulse(Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0) * root.AssemblyMass)
							else
								root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0)
							end
						end
					end))
				end
			else
				if old then
					workspace.Gravity = old
					old = nil
				end
			end
		end,
		Tooltip = 'Changes the rate you fall'
	})
	Mode = Gravity:CreateDropdown({
		Name = 'Mode',
		List = {'Workspace', 'Velocity', 'Impulse'},
		Tooltip = 'Workspace - Adjusts the gravity for the entire game\nVelocity - Adjusts the local players gravity\nImpulse - Same as velocity while using forces instead'
	})
	Value = Gravity:CreateSlider({
		Name = 'Gravity',
		Min = 0,
		Max = 192,
		Function = function(val)
			if Gravity.Enabled and Mode.Value == 'Workspace' then
				changed = true
				workspace.Gravity = val
				changed = false
			end
		end,
		Default = 192
	})
end)
	
run(function()
	local Parkour
	
	Parkour = vape.Categories.World:CreateModule({
		Name = 'Parkour',
		Function = function(callback)
			if callback then 
				local oldfloor
				Parkour:Clean(runService.RenderStepped:Connect(function()
					if entitylib.isAlive then 
						local material = entitylib.character.Humanoid.FloorMaterial
						if material == Enum.Material.Air and oldfloor ~= Enum.Material.Air then 
							entitylib.character.Humanoid.Jump = true
						end
						oldfloor = material
					end
				end))
			end
		end,
		Tooltip = 'Automatically jumps after reaching the edge'
	})
end)
	
run(function()
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local module, old
	
	vape.Categories.World:CreateModule({
		Name = 'SafeWalk',
		Function = function(callback)
			if callback then
				if not module then
					local suc = pcall(function() 
						module = require(lplr.PlayerScripts.PlayerModule).controls 
					end)
					if not suc then module = {} end
				end
				
				old = module.moveFunction
				module.moveFunction = function(self, vec, face)
					if entitylib.isAlive then
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						local root = entitylib.character.RootPart
						local movedir = root.Position + vec
						local ray = workspace:Raycast(movedir, Vector3.new(0, -15, 0), rayCheck)
						if not ray then
							local check = workspace:Blockcast(root.CFrame, Vector3.new(3, 1, 3), Vector3.new(0, -(entitylib.character.HipHeight + 1), 0), rayCheck)
							if check then
								vec = (check.Instance:GetClosestPointOnSurface(movedir) - root.Position) * Vector3.new(1, 0, 1)
							end
						end
					end
	
					return old(self, vec, face)
				end
			else
				if module and old then
					module.moveFunction = old
				end
			end
		end,
		Tooltip = 'Prevents you from walking off the edge of parts'
	})
end)
	
run(function()
	local Xray
	local List
	local modified = {}
	
	local function modifyPart(v)
		if v:IsA('BasePart') and not table.find(List.ListEnabled, v.Name) then
			modified[v] = true
			v.LocalTransparencyModifier = 0.5
		end
	end
	
	Xray = vape.Categories.World:CreateModule({
		Name = 'Xray',
		Function = function(callback)
			if callback then
				Xray:Clean(workspace.DescendantAdded:Connect(modifyPart))
				for _, v in workspace:GetDescendants() do
					modifyPart(v)
				end
			else
				for i in modified do
					i.LocalTransparencyModifier = 0
				end
				table.clear(modified)
			end
		end,
		Tooltip = 'Renders whitelisted parts through walls.'
	})
	List = Xray:CreateTextList({
		Name = 'Part',
		Function = function()
			if Xray.Enabled then
				Xray:Toggle()
				Xray:Toggle()
			end
		end
	})
end)
	
run(function()
	local MurderMystery
	local murderer, sheriff, oldtargetable, oldgetcolor
	
	local function itemAdded(v, plr)
		if v:IsA('Tool') then
			local check = v:FindFirstChild('IsGun') and 'sheriff' or v:FindFirstChild('KnifeServer') and 'murderer' or nil
			check = check or v.Name:lower():find('knife') and 'murderer' or v.Name:lower():find('gun') and 'sheriff' or nil
			if check == 'murderer' and plr ~= murderer then
				murderer = plr
				if plr.Character then
					entitylib.refresh()
				end
			elseif check == 'sheriff' and plr ~= sheriff then
				sheriff = plr
				if plr.Character then
					entitylib.refresh()
				end
			end
		end
	end
	
	local function playerAdded(plr)
		MurderMystery:Clean(plr.DescendantAdded:Connect(function(v)
			itemAdded(v, plr)
		end))
		local pack = plr:FindFirstChildWhichIsA('Backpack')
		if pack then
			for _, v in pack:GetChildren() do
				itemAdded(v, plr)
			end
		end
		if plr.Character then
			for _, v in plr.Character:GetChildren() do
				itemAdded(v, plr)
			end
		end
	end
	
	MurderMystery = vape.Categories.Minigames:CreateModule({
		Name = 'MurderMystery',
		Function = function(callback)
			if callback then
				oldtargetable, oldgetcolor = entitylib.targetCheck, entitylib.getEntityColor
				entitylib.getEntityColor = function(ent)
					ent = ent.Player
					if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
					if isFriend(ent, true) then
						return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
					end
					return murderer == ent and Color3.new(1, 0.3, 0.3) or sheriff == ent and Color3.new(0, 0.5, 1) or nil
				end
				entitylib.targetCheck = function(ent)
					if ent.Player and isFriend(ent.Player) then return false end
					if murderer == lplr then return true end
					return murderer == ent.Player or sheriff == ent.Player
				end
				for _, v in playersService:GetPlayers() do
					playerAdded(v)
				end
				MurderMystery:Clean(playersService.PlayerAdded:Connect(playerAdded))
				entitylib.refresh()
			else
				entitylib.getEntityColor = oldgetcolor
				entitylib.targetCheck = oldtargetable
				entitylib.refresh()
			end
		end,
		Tooltip = 'Automatic murder mystery teaming based on equipped roblox tools.'
	})
end)
	
run(function()
	local Atmosphere
	local Toggles = {}
	local newobjects, oldobjects = {}, {}
	local apidump = {
		Sky = {
			SkyboxUp = 'Text',
			SkyboxDn = 'Text',
			SkyboxLf = 'Text',
			SkyboxRt = 'Text',
			SkyboxFt = 'Text',
			SkyboxBk = 'Text',
			SunTextureId = 'Text',
			SunAngularSize = 'Number',
			MoonTextureId = 'Text',
			MoonAngularSize = 'Number',
			StarCount = 'Number'
		},
		Atmosphere = {
			Color = 'Color',
			Decay = 'Color',
			Density = 'Number',
			Offset = 'Number',
			Glare = 'Number',
			Haze = 'Number'
		},
		BloomEffect = {
			Intensity = 'Number',
			Size = 'Number',
			Threshold = 'Number'
		},
		DepthOfFieldEffect = {
			FarIntensity = 'Number',
			FocusDistance = 'Number',
			InFocusRadius = 'Number',
			NearIntensity = 'Number'
		},
		SunRaysEffect = {
			Intensity = 'Number',
			Spread = 'Number'
		},
		ColorCorrectionEffect = {
			TintColor = 'Color',
			Saturation = 'Number',
			Contrast = 'Number',
			Brightness = 'Number'
		}
	}
	
	local function removeObject(v)
		if not table.find(newobjects, v) then
			local toggle = Toggles[v.ClassName]
			if toggle and toggle.Toggle.Enabled then
				if v.Parent then
					table.insert(oldobjects, v)
					v.Parent = game
				end
			end
		end
	end
	
	Atmosphere = vape.Legit:CreateModule({
		Name = 'Atmosphere',
		Function = function(callback)
			if callback then
				for _, v in lightingService:GetChildren() do
					removeObject(v)
				end
				Atmosphere:Clean(lightingService.ChildAdded:Connect(function(v)
					task.defer(removeObject, v)
				end))
	
				for i, v in Toggles do
					if v.Toggle.Enabled then
						local obj = Instance.new(i)
						for i2, v2 in v.Objects do
							if v2.Type == 'ColorSlider' then
								obj[i2] = Color3.fromHSV(v2.Hue, v2.Sat, v2.Value)
							else
								obj[i2] = apidump[i][i2] ~= 'Number' and v2.Value or tonumber(v2.Value) or 0
							end
						end
						obj.Parent = lightingService
						table.insert(newobjects, obj)
					end
				end
			else
				for _, v in newobjects do
					v:Destroy()
				end
				for _, v in oldobjects do
					v.Parent = lightingService
				end
				table.clear(newobjects)
				table.clear(oldobjects)
			end
		end,
		Tooltip = 'Custom lighting objects'
	})
	for i, v in apidump do
		Toggles[i] = {Objects = {}}
		Toggles[i].Toggle = Atmosphere:CreateToggle({
			Name = i,
			Function = function(callback)
				if Atmosphere.Enabled then
					Atmosphere:Toggle()
					Atmosphere:Toggle()
				end
				for _, toggle in Toggles[i].Objects do
					toggle.Object.Visible = callback
				end
			end
		})
	
		for i2, v2 in v do
			if v2 == 'Text' or v2 == 'Number' then
				Toggles[i].Objects[i2] = Atmosphere:CreateTextBox({
					Name = i2,
					Function = function(enter)
						if Atmosphere.Enabled and enter then
							Atmosphere:Toggle()
							Atmosphere:Toggle()
						end
					end,
					Darker = true,
					Default = v2 == 'Number' and '0' or nil,
					Visible = false
				})
			elseif v2 == 'Color' then
				Toggles[i].Objects[i2] = Atmosphere:CreateColorSlider({
					Name = i2,
					Function = function()
						if Atmosphere.Enabled then
							Atmosphere:Toggle()
							Atmosphere:Toggle()
						end
					end,
					Darker = true,
					Visible = false
				})
			end
		end
	end
end)
	
run(function()
	local Breadcrumbs
	local Texture
	local Lifetime
	local Thickness
	local FadeIn
	local FadeOut
	local trail, point, point2
	
	Breadcrumbs = vape.Legit:CreateModule({
		Name = 'Breadcrumbs',
		Function = function(callback)
			if callback then
				point = Instance.new('Attachment')
				point.Position = Vector3.new(0, Thickness.Value - 2.7, 0)
				point2 = Instance.new('Attachment')
				point2.Position = Vector3.new(0, -Thickness.Value - 2.7, 0)
				trail = Instance.new('Trail')
				trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
				trail.TextureMode = Enum.TextureMode.Static
				trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
				trail.Lifetime = Lifetime.Value
				trail.Attachment0 = point
				trail.Attachment1 = point2
				trail.FaceCamera = true
	
				Breadcrumbs:Clean(trail)
				Breadcrumbs:Clean(point)
				Breadcrumbs:Clean(point2)
				Breadcrumbs:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					point.Parent = ent.HumanoidRootPart
					point2.Parent = ent.HumanoidRootPart
					trail.Parent = gameCamera
				end))
				if entitylib.isAlive then
					point.Parent = entitylib.character.RootPart
					point2.Parent = entitylib.character.RootPart
					trail.Parent = gameCamera
				end
			else
				trail = nil
				point = nil
				point2 = nil
			end
		end,
		Tooltip = 'Shows a trail behind your character'
	})
	Texture = Breadcrumbs:CreateTextBox({
		Name = 'Texture',
		Placeholder = 'Texture Id',
		Function = function(enter)
			if enter and trail then
				trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
			end
		end
	})
	FadeIn = Breadcrumbs:CreateColorSlider({
		Name = 'Fade In',
		Function = function(hue, sat, val)
			if trail then
				trail.Color = ColorSequence.new(Color3.fromHSV(hue, sat, val), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
			end
		end
	})
	FadeOut = Breadcrumbs:CreateColorSlider({
		Name = 'Fade Out',
		Function = function(hue, sat, val)
			if trail then
				trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(hue, sat, val))
			end
		end
	})
	Lifetime = Breadcrumbs:CreateSlider({
		Name = 'Lifetime',
		Min = 1,
		Max = 5,
		Default = 3,
		Decimal = 10,
		Function = function(val)
			if trail then
				trail.Lifetime = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Thickness = Breadcrumbs:CreateSlider({
		Name = 'Thickness',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Function = function(val)
			if point then
				point.Position = Vector3.new(0, val - 2.7, 0)
			end
			if point2 then
				point2.Position = Vector3.new(0, -val - 2.7, 0)
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local Cape
	local Texture
	local part, motor
	
	local function createMotor(char)
		if motor then 
			motor:Destroy() 
		end
		part.Parent = gameCamera
		motor = Instance.new('Motor6D')
		motor.MaxVelocity = 0.08
		motor.Part0 = part
		motor.Part1 = char.Character:FindFirstChild('UpperTorso') or char.RootPart
		motor.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
		motor.C1 = CFrame.new(0, motor.Part1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
		motor.Parent = part
	end
	
	Cape = vape.Legit:CreateModule({
		Name = 'Cape',
		Function = function(callback)
			if callback then
				part = Instance.new('Part')
				part.Size = Vector3.new(2, 4, 0.1)
				part.CanCollide = false
				part.CanQuery = false
				part.Massless = true
				part.Transparency = 0
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.new()
				part.CastShadow = false
				part.Parent = gameCamera
				local capesurface = Instance.new('SurfaceGui')
				capesurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				capesurface.Adornee = part
				capesurface.Parent = part
	
				if Texture.Value:find('.webm') then
					local decal = Instance.new('VideoFrame')
					decal.Video = getcustomasset(Texture.Value)
					decal.Size = UDim2.fromScale(1, 1)
					decal.BackgroundTransparency = 1
					decal.Looped = true
					decal.Parent = capesurface
					decal:Play()
				else
					local decal = Instance.new('ImageLabel')
					decal.Image = Texture.Value ~= '' and (Texture.Value:find('rbxasset') and Texture.Value or assetfunction(Texture.Value)) or 'rbxassetid://14637958134'
					decal.Size = UDim2.fromScale(1, 1)
					decal.BackgroundTransparency = 1
					decal.Parent = capesurface
				end
				Cape:Clean(part)
				Cape:Clean(entitylib.Events.LocalAdded:Connect(createMotor))
				if entitylib.isAlive then
					createMotor(entitylib.character)
				end
	
				repeat
					if motor and entitylib.isAlive then
						local velo = math.min(entitylib.character.RootPart.Velocity.Magnitude, 90)
						motor.DesiredAngle = math.rad(6) + math.rad(velo) + (velo > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
					end
					capesurface.Enabled = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6
					part.Transparency = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6 and 0 or 1
					task.wait()
				until not Cape.Enabled
			else
				part = nil
				motor = nil
			end
		end,
		Tooltip = 'Add\'s a cape to your character'
	})
	Texture = Cape:CreateTextBox({
		Name = 'Texture'
	})
end)
	
run(function()
	local ChinaHat
	local Material
	local Color
	local hat
	
	ChinaHat = vape.Legit:CreateModule({
		Name = 'China Hat',
		Function = function(callback)
			if callback then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				hat = Instance.new('MeshPart')
				hat.Size = Vector3.new(3, 0.7, 3)
				hat.Name = 'ChinaHat'
				hat.Material = Enum.Material[Material.Value]
				hat.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				hat.CanCollide = false
				hat.CanQuery = false
				hat.Massless = true
				hat.MeshId = 'http://www.roblox.com/asset/?id=1778999'
				hat.Transparency = 1 - Color.Opacity
				hat.Parent = gameCamera
				hat.CFrame = entitylib.isAlive and entitylib.character.Head.CFrame + Vector3.new(0, 1, 0) or CFrame.identity
				local weld = Instance.new('WeldConstraint')
				weld.Part0 = hat
				weld.Part1 = entitylib.isAlive and entitylib.character.Head or nil
				weld.Parent = hat
				ChinaHat:Clean(hat)
				ChinaHat:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					if weld then 
						weld:Destroy() 
					end
					hat.Parent = gameCamera
					hat.CFrame = char.Head.CFrame + Vector3.new(0, 1, 0)
					hat.Velocity = Vector3.zero
					weld = Instance.new('WeldConstraint')
					weld.Part0 = hat
					weld.Part1 = char.Head
					weld.Parent = hat
				end))
	
				repeat
					hat.LocalTransparencyModifier = ((gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude <= 0.6 and 1 or 0)
					task.wait()
				until not ChinaHat.Enabled
			else
				hat = nil
			end
		end,
		Tooltip = 'Puts a china hat on your character (ty mastadawn)'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = ChinaHat:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if hat then
				hat.Material = Enum.Material[val]
			end
		end
	})
	Color = ChinaHat:CreateColorSlider({
		Name = 'Hat Color',
		DefaultOpacity = 0.7,
		Function = function(hue, sat, val, opacity)
			if hat then
				hat.Color = Color3.fromHSV(hue, sat, val)
				hat.Transparency = 1 - opacity
			end
		end
	})
end)
	
run(function()
	local Clock
	local TwentyFourHour
	local label
	
	Clock = vape.Legit:CreateModule({
		Name = 'Clock',
		Function = function(callback)
			if callback then
				repeat
					label.Text = DateTime.now():FormatLocalTime('LT', TwentyFourHour.Enabled and 'zh-cn' or 'en-us')
					task.wait(1)
				until not Clock.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current local time'
	})
	Clock:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Clock:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	TwentyFourHour = Clock:CreateToggle({
		Name = '24 Hour Clock'
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.new(0, 100, 0, 41)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0:00 PM'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Clock.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
run(function()
	local Disguise
	local Mode
	local IDBox
	local desc
	
	local function itemAdded(v, manual)
		if (not v:GetAttribute('Disguise')) and ((v:IsA('Accessory') and (not v:GetAttribute('InvItem')) and (not v:GetAttribute('ArmorSlot'))) or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') or manual) then
			repeat
				task.wait()
				v.Parent = game
			until v.Parent == game
			v:ClearAllChildren()
			v:Destroy()
		end
	end
	
	local function characterAdded(char)
		if Mode.Value == 'Character' then
			task.wait(0.1)
			char.Character.Archivable = true
			local clone = char.Character:Clone()
			repeat
				if pcall(function()
					desc = playersService:GetHumanoidDescriptionFromUserId(IDBox.Value == '' and 239702688 or tonumber(IDBox.Value))
				end) and desc then break end
				task.wait(1)
			until not Disguise.Enabled
			if not Disguise.Enabled then
				clone:ClearAllChildren()
				clone:Destroy()
				clone = nil
				if desc then
					desc:Destroy()
					desc = nil
				end
				return
			end
			clone.Parent = game
	
			local originalDesc = char.Humanoid:WaitForChild('HumanoidDescription', 2) or {
				HeightScale = 1,
				SetEmotes = function() end,
				SetEquippedEmotes = function() end
			}
			originalDesc.JumpAnimation = desc.JumpAnimation
			desc.HeightScale = originalDesc.HeightScale
	
			for _, v in clone:GetChildren() do
				if v:IsA('Accessory') or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') then
					v:ClearAllChildren()
					v:Destroy()
				end
			end
	
			clone.Humanoid:ApplyDescriptionClientServer(desc)
			for _, v in char.Character:GetChildren() do
				itemAdded(v)
			end
			Disguise:Clean(char.Character.ChildAdded:Connect(itemAdded))
	
			for _, v in clone:WaitForChild('Animate'):GetChildren() do
				if not char.Character:FindFirstChild('Animate') then return end
				local real = char.Character.Animate:FindFirstChild(v.Name)
				if v and real then
					local anim = v:FindFirstChildWhichIsA('Animation') or {AnimationId = ''}
					local realanim = real:FindFirstChildWhichIsA('Animation') or {AnimationId = ''}
					if realanim then
						realanim.AnimationId = anim.AnimationId
					end
				end
			end
	
			for _, v in clone:GetChildren() do
				v:SetAttribute('Disguise', true)
				if v:IsA('Accessory') then
					for _, v2 in v:GetDescendants() do
						if v2:IsA('Weld') and v2.Part1 then
							v2.Part1 = char.Character[v2.Part1.Name]
						end
					end
					v.Parent = char.Character
				elseif v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') then
					v.Parent = char.Character
				elseif v.Name == 'Head' and char.Head:IsA('MeshPart') and (not char.Head:FindFirstChild('FaceControls')) then
					char.Head.MeshId = v.MeshId
				end
			end
	
			local localface = char.Character:FindFirstChild('face', true)
			local cloneface = clone:FindFirstChild('face', true)
			if localface and cloneface then
				itemAdded(localface, true)
				cloneface.Parent = char.Head
			end
			originalDesc:SetEmotes(desc:GetEmotes())
			originalDesc:SetEquippedEmotes(desc:GetEquippedEmotes())
			clone:ClearAllChildren()
			clone:Destroy()
			clone = nil
			if desc then
				desc:Destroy()
				desc = nil
			end
		else
			local data
			repeat
				if pcall(function()
					data = marketplaceService:GetProductInfo(IDBox.Value == '' and 43 or tonumber(IDBox.Value), Enum.InfoType.Bundle)
				end) then break end
				task.wait(1)
			until not Disguise.Enabled
			if not Disguise.Enabled then
				if data then
					table.clear(data)
					data = nil
				end
				return
			end
			if data.BundleType == 'AvatarAnimations' then
				local animate = char.Character:FindFirstChild('Animate')
				if not animate then return end
				for _, v in desc.Items do
					local animtype = v.Name:split(' ')[2]:lower()
					if animtype ~= 'animation' then
						local suc, res = pcall(function() return game:GetObjects('rbxassetid://'..v.Id) end)
						if suc then
							animate[animtype]:FindFirstChildWhichIsA('Animation').AnimationId = res[1]:FindFirstChildWhichIsA('Animation', true).AnimationId
						end
					end
				end
			else
				notif('Disguise', 'that\'s not an animation pack', 5, 'warning')
			end
		end
	end
	
	Disguise = vape.Legit:CreateModule({
		Name = 'Disguise',
		Function = function(callback)
			if callback then
				Disguise:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
				if entitylib.isAlive then
					characterAdded(entitylib.character)
				end
			end
		end,
		Tooltip = 'Changes your character or animation to a specific ID (animation packs or userid\'s only)'
	})
	Mode = Disguise:CreateDropdown({
		Name = 'Mode',
		List = {'Character', 'Animation'},
		Function = function()
			if Disguise.Enabled then
				Disguise:Toggle()
				Disguise:Toggle()
			end
		end
	})
	IDBox = Disguise:CreateTextBox({
		Name = 'Disguise',
		Placeholder = 'Disguise User Id',
		Function = function()
			if Disguise.Enabled then
				Disguise:Toggle()
				Disguise:Toggle()
			end
		end
	})
end)
	
run(function()
	local FOV
	local Value
	local oldfov
	
	FOV = vape.Legit:CreateModule({
		Name = 'FOV',
		Function = function(callback)
			if callback then
				oldfov = gameCamera.FieldOfView
				repeat
					gameCamera.FieldOfView = Value.Value
					task.wait()
				until not FOV.Enabled
			else
				gameCamera.FieldOfView = oldfov
			end
		end,
		Tooltip = 'Adjusts camera vision'
	})
	Value = FOV:CreateSlider({
		Name = 'FOV',
		Min = 30,
		Max = 120
	})
end)
	
run(function()
	--[[
		Grabbing an accurate count of the current framerate
		Source: https://devforum.roblox.com/t/get-client-FPS-trough-a-script/282631
	]]
	local FPS
	local label
	
	FPS = vape.Legit:CreateModule({
		Name = 'FPS',
		Function = function(callback)
			if callback then
				local frames = {}
				local startClock = os.clock()
				local updateTick = tick()
				FPS:Clean(runService.Heartbeat:Connect(function()
					local updateClock = os.clock()
					for i = #frames, 1, -1 do
						frames[i + 1] = frames[i] >= updateClock - 1 and frames[i] or nil
					end
					frames[1] = updateClock
					if updateTick < tick() then
						updateTick = tick() + 1
						label.Text = math.floor(os.clock() - startClock >= 1 and #frames or #frames / (os.clock() - startClock))..' FPS'
					end
				end))
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current framerate'
	})
	FPS:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	FPS:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = 'inf FPS'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = FPS.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
run(function()
	local Keystrokes
	local Style
	local Color
	local keys, holder = {}
	
	local function createKeystroke(keybutton, pos, pos2, text)
		if keys[keybutton] then
			keys[keybutton].Key:Destroy()
			keys[keybutton] = nil
		end
		local key = Instance.new('Frame')
		key.Size = keybutton == Enum.KeyCode.Space and UDim2.new(0, 110, 0, 24) or UDim2.new(0, 34, 0, 36)
		key.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		key.BackgroundTransparency = 1 - Color.Opacity
		key.Position = pos
		key.Name = keybutton.Name
		key.Parent = holder
		local keytext = Instance.new('TextLabel')
		keytext.BackgroundTransparency = 1
		keytext.Size = UDim2.fromScale(1, 1)
		keytext.Font = Enum.Font.Gotham
		keytext.Text = text or keybutton.Name
		keytext.TextXAlignment = Enum.TextXAlignment.Left
		keytext.TextYAlignment = Enum.TextYAlignment.Top
		keytext.Position = pos2
		keytext.TextSize = keybutton == Enum.KeyCode.Space and 18 or 15
		keytext.TextColor3 = Color3.new(1, 1, 1)
		keytext.Parent = key
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = key
		keys[keybutton] = {Key = key}
	end
	
	Keystrokes = vape.Legit:CreateModule({
		Name = 'Keystrokes',
		Function = function(callback)
			if callback then
				createKeystroke(Enum.KeyCode.W, UDim2.new(0, 38, 0, 0), UDim2.new(0, 6, 0, 5), Style.Value == 'Arrow' and '↑' or nil)
				createKeystroke(Enum.KeyCode.S, UDim2.new(0, 38, 0, 42), UDim2.new(0, 8, 0, 5), Style.Value == 'Arrow' and '↓' or nil)
				createKeystroke(Enum.KeyCode.A, UDim2.new(0, 0, 0, 42), UDim2.new(0, 7, 0, 5), Style.Value == 'Arrow' and '←' or nil)
				createKeystroke(Enum.KeyCode.D, UDim2.new(0, 76, 0, 42), UDim2.new(0, 8, 0, 5), Style.Value == 'Arrow' and '→' or nil)
	
				Keystrokes:Clean(inputService.InputBegan:Connect(function(inputType)
					local key = keys[inputType.KeyCode]
					if key then
						if key.Tween then
							key.Tween:Cancel()
						end
						if key.Tween2 then
							key.Tween2:Cancel()
						end
	
						key.Pressed = true
						key.Tween = tweenService:Create(key.Key, TweenInfo.new(0.1), {
							BackgroundColor3 = Color3.new(1, 1, 1), 
							BackgroundTransparency = 0
						})
						key.Tween2 = tweenService:Create(key.Key.TextLabel, TweenInfo.new(0.1), {
							TextColor3 = Color3.new()
						})
						key.Tween:Play()
						key.Tween2:Play()
					end
				end))
	
				Keystrokes:Clean(inputService.InputEnded:Connect(function(inputType)
					local key = keys[inputType.KeyCode]
					if key then
						if key.Tween then
							key.Tween:Cancel()
						end
						if key.Tween2 then
							key.Tween2:Cancel()
						end
	
						key.Pressed = false
						key.Tween = tweenService:Create(key.Key, TweenInfo.new(0.1), {
							BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value), 
							BackgroundTransparency = 1 - Color.Opacity
						})
						key.Tween2 = tweenService:Create(key.Key.TextLabel, TweenInfo.new(0.1), {
							TextColor3 = Color3.new(1, 1, 1)
						})
						key.Tween:Play()
						key.Tween2:Play()
					end
				end))
			end
		end,
		Size = UDim2.fromOffset(110, 176),
		Tooltip = 'Shows movement keys onscreen'
	})
	holder = Instance.new('Frame')
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = Keystrokes.Children
	Style = Keystrokes:CreateDropdown({
		Name = 'Key Style',
		List = {'Keyboard', 'Arrow'},
		Function = function()
			if Keystrokes.Enabled then
				Keystrokes:Toggle()
				Keystrokes:Toggle()
			end
		end
	})
	Color = Keystrokes:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in keys do
				if not v.Pressed then
					v.Key.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					v.Key.BackgroundTransparency = 1 - opacity
				end
			end
		end
	})
	Keystrokes:CreateToggle({
		Name = 'Show Spacebar',
		Function = function(callback)
			Keystrokes.Children.Size = UDim2.fromOffset(110, callback and 107 or 78)
			if callback then
				createKeystroke(Enum.KeyCode.Space, UDim2.new(0, 0, 0, 83), UDim2.new(0, 25, 0, -10), '______')
			else
				keys[Enum.KeyCode.Space].Key:Destroy()
				keys[Enum.KeyCode.Space] = nil
			end
		end,
		Default = true
	})
end)
	
run(function()
	local Memory
	local label
	
	Memory = vape.Legit:CreateModule({
		Name = 'Memory',
		Function = function(callback)
			if callback then
				repeat
					label.Text = math.floor(tonumber(game:GetService('Stats'):FindFirstChild('PerformanceStats').Memory:GetValue()))..' MB'
					task.wait(1)
				until not Memory.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'A label showing the memory currently used by roblox'
	})
	Memory:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Memory:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.new(0, 100, 0, 41)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0 MB'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Memory.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
run(function()
	local Ping
	local label
	
	Ping = vape.Legit:CreateModule({
		Name = 'Ping',
		Function = function(callback)
			if callback then
				repeat
					label.Text = math.floor(tonumber(game:GetService('Stats'):FindFirstChild('PerformanceStats').Ping:GetValue()))..' ms'
					task.wait(1)
				until not Ping.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current connection speed to the roblox server'
	})
	Ping:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Ping:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.new(0, 100, 0, 41)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0 ms'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Ping.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
run(function()
	local SongBeats
	local List
	local FOV
	local FOVValue = {}
	local Volume
	local alreadypicked = {}
	local beattick = tick()
	local oldfov, songobj, songbpm, songtween
	
	local function choosesong()
		local list = List.ListEnabled
		if #alreadypicked >= #list then
			table.clear(alreadypicked)
		end
	
		if #list <= 0 then
			notif('SongBeats', 'no songs', 10)
			SongBeats:Toggle()
			return
		end
	
		local chosensong = list[math.random(1, #list)]
		if #list > 1 and table.find(alreadypicked, chosensong) then
			repeat
				task.wait()
				chosensong = list[math.random(1, #list)]
			until not table.find(alreadypicked, chosensong) or not SongBeats.Enabled
		end
		if not SongBeats.Enabled then return end
	
		local split = chosensong:split('/')
		if not isfile(split[1]) then
			notif('SongBeats', 'Missing song ('..split[1]..')', 10)
			SongBeats:Toggle()
			return
		end
	
		songobj.SoundId = assetfunction(split[1])
		repeat task.wait() until songobj.IsLoaded or not SongBeats.Enabled
		if SongBeats.Enabled then
			beattick = tick() + (tonumber(split[3]) or 0)
			songbpm = 60 / (tonumber(split[2]) or 50)
			songobj:Play()
		end
	end
	
	SongBeats = vape.Legit:CreateModule({
		Name = 'Song Beats',
		Function = function(callback)
			if callback then
				songobj = Instance.new('Sound')
				songobj.Volume = Volume.Value / 100
				songobj.Parent = workspace
				oldfov = gameCamera.FieldOfView
	
				repeat
					if not songobj.Playing then
						choosesong()
					end
					if beattick < tick() and SongBeats.Enabled and FOV.Enabled then
						beattick = tick() + songbpm
						gameCamera.FieldOfView = oldfov - FOVValue.Value
						songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {
							FieldOfView = oldfov
						})
						songtween:Play()
					end
					task.wait()
				until not SongBeats.Enabled
			else
				if songobj then
					songobj:Destroy()
				end
				if songtween then
					songtween:Cancel()
				end
				if oldfov then
					gameCamera.FieldOfView = oldfov
				end
				table.clear(alreadypicked)
			end
		end,
		Tooltip = 'Built in mp3 player'
	})
	List = SongBeats:CreateTextList({
		Name = 'Songs',
		Placeholder = 'filepath/bpm/start'
	})
	FOV = SongBeats:CreateToggle({
		Name = 'Beat FOV',
		Function = function(callback)
			if FOVValue.Object then
				FOVValue.Object.Visible = callback
			end
			if SongBeats.Enabled then
				SongBeats:Toggle()
				SongBeats:Toggle()
			end
		end,
		Default = true
	})
	FOVValue = SongBeats:CreateSlider({
		Name = 'Adjustment',
		Min = 1,
		Max = 30,
		Default = 5,
		Darker = true
	})
	Volume = SongBeats:CreateSlider({
		Name = 'Volume',
		Function = function(val)
			if songobj then
				songobj.Volume = val / 100
			end
		end,
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
	
run(function()
	local Speedmeter
	local label
	
	Speedmeter = vape.Legit:CreateModule({
		Name = 'Speedmeter',
		Function = function(callback)
			if callback then
				repeat
					local lastpos = entitylib.isAlive and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
					local dt = task.wait(0.2)
					local newpos = entitylib.isAlive and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
					label.Text = math.round(((lastpos - newpos) / dt).Magnitude)..' sps'
				until not Speedmeter.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'A label showing the average velocity in studs'
	})
	Speedmeter:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Speedmeter:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0 sps'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Speedmeter.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
run(function()
	local TimeChanger
	local Value
	local old
	
	TimeChanger = vape.Legit:CreateModule({
		Name = 'Time Changer',
		Function = function(callback)
			if callback then
				old = lightingService.TimeOfDay
				lightingService.TimeOfDay = Value.Value..':00:00'
			else
				lightingService.TimeOfDay = old
				old = nil
			end
		end,
		Tooltip = 'Change the time of the current world'
	})
	Value = TimeChanger:CreateSlider({
		Name = 'Time',
		Min = 0,
		Max = 24,
		Default = 12,
		Function = function(val)
			if TimeChanger.Enabled then 
				lightingService.TimeOfDay = val..':00:00'
			end
		end
	})
	
end)

-- This script was generated using the MoonVeil Obfuscator v1.4.0 [https://moonveil.cc]
local A,Vf,pe,ac,lj,zf=pairs,bit32.bxor,type,getmetatable;local Be,da,wl,xi,Fk,ve,hl,ja,ca,sc,ib,qf,Ak,yb,gf,xj,jb,Ci,Ve,hb,Ta,yi,hi,Yk,Da,Ye,Md,Jc,Cc,fh,_a,xh,Xe,yj,kl,jl,za,tc,Dd,nb,fg,md,He,kk wl=(getfenv());jl,fh,ve=(string.char),(string.byte),(bit32 .bxor);Yk=function(rb,Ce)local yg,ze,fj,Hj,Ej,s,oj,qi qi,s={},function(ui,db,bf)qi[ui]=Vf(db,64459)-Vf(bf,25858)return qi[ui]end Hj=qi[802]or s(802,4707,64216)repeat while true do if Hj>39652 then if Hj<=53409 then if Hj<=47416 then yg=yg+fj;ze=yg;if yg~=yg then Hj=30858 else Hj=qi[-31556]or s(-31556,547,22978)end else if(fj>=0 and yg>Ej)or((fj<0 or fj~=fj)and yg<Ej)then Hj=qi[21130]or s(21130,15696,11027)else Hj=60410 end end else oj=oj..jl(ve(fh(rb,(ze-56)+1),fh(Ce,(ze-56)%#Ce+1)))Hj=qi[-18091]or s(-18091,105384,52760)end elseif Hj<=24876 then if Hj>19784 then ze=yg;if Ej~=Ej then Hj=qi[-22712]or s(-22712,18246,8449)else Hj=qi[27769]or s(27769,85168,40785)end else oj='';yg,fj,Ej=56,1,(#rb-1)+56 Hj=20674 end else return oj end end until Hj==48394 end;ja=(select);sc=(function(...)return{[1]={...},[2]=ja('#',...)}end);Ak=((function()local function sl(yh,sa,Pi)if sa>Pi then return end return yh[sa],sl(yh,sa+1,Pi)end return sl end)());Md,fg=(string.gsub),(string.char);_a=(function(X)X=Md(X,'[^ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=]','')return(X:gsub('.',function(z)if(z=='=')then return''end local _l,sd='',(('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'):find(z)-1)for Gd=6,1,-1 do _l=_l..(sd%2^Gd-sd%2^(Gd-1)>0 and'1'or'0')end return _l;end):gsub('%d%d%d?%d?%d?%d?%d?%d?',function(_e)if(#_e~=8)then return''end local Si=0 for dd=1,8 do Si=Si+(_e:sub(dd,dd)=='1'and 2^(8-dd)or 0)end return fg(Si)end))end);da,za,hi,kk,Ci,ca,gf,xj=wl[Yk('{|saff','\b\b\1')][Yk('\aHN\19EU','r&>')],wl[Yk('\233\176\57\243\170,','\154\196K')][Yk('\165\163\180','\214')],wl[Yk('\235G\158\241]\139','\152\51\236')][Yk('\173\191\187\163','\207\198')],wl[Yk('\232\15\254U\184','\138f')][Yk('\236\224\49\233\245-','\128\147Y')],wl[Yk('\19\135\5\221C','q\238')][Yk('\134\26\143\157\15\147','\244i\231')],wl[Yk('\17\249\a\163A','s\144')][Yk('\29\131\17\134','\127\226')],wl[Yk('\14\"\24/\31','zC')][Yk(';\228);\234\51','X\139G')],{};yj=(function(Lj)local zj,Rh,Rf,Zd,Wb,Te,ga,Ld,nh,Oi,pb,nj,ic,mg,M,Rb,id,Mj M,ic={},function(Bh,rl,ce)M[Bh]=Vf(rl,61334)-Vf(ce,21950)return M[Bh]end nh=M[8338]or ic(8338,512,49253)repeat while true do if nh<=37069 then if nh<=22330 then if nh>15807 then if nh>19214 then zj=nil;if ca(Rf,1)~=0 then nh=M[21738]or ic(21738,14246,25063)break else nh=M[12980]or ic(12980,50971,22027)break end nh=52168 else return Wb end elseif nh>12004 then id,Te,Zd,Ld,nj=kk(1,12),kk(1,4),1,{},'';nh=47311;else if not(Zd+1<=#Lj)then nh=M[32079]or ic(32079,84065,35217)break else nh=M[1475]or ic(1475,429,14675)break end nh=M[-17692]or ic(-17692,89281,45617)end elseif nh>28844 then if nh<=32176 then Mj=Oi;if ga~=ga then nh=M[19334]or ic(19334,113047,51340)else nh=M[-31479]or ic(-31479,87475,38553)end elseif nh>34165 then Ld[#Ld+1]=zj nj=za(nj..zj,-id)nh=M[-12041]or ic(-12041,108386,55219)else Rb=da(Yk('?H3','\1'),Lj,Zd);Zd=Zd+2 mg,Rh=#nj-Ci(Rb,4),ca(Rb,(Te-1))+3 zj=za(nj,mg,mg+Rh-1)nh=M[19224]or ic(19224,82403,46867)end elseif nh<=22701 then Wb=xj[Lj];if not(Wb)then nh=M[32455]or ic(32455,14694,52158)break else nh=M[-29520]or ic(-29520,22947,8961)break end nh=14576 else zj=za(Lj,Zd,Zd)Zd=Zd+1 nh=M[-6367]or ic(-6367,127483,1819)end elseif nh>53324 then if nh<=63968 then if(pb>=0 and Oi>ga)or((pb<0 or pb~=pb)and Oi<ga)then nh=M[11382]or ic(11382,112143,62836)else nh=22183 end else Rf=gf(Ld);xj[Lj]=Rf return Rf end elseif nh>47558 then if nh>52046 then if nh>52670 then Rf=hi(Lj,Zd);Zd=Zd+1 pb,ga,Oi=1,(8)+210,211 nh=M[-32049]or ic(-32049,13815,15651)else Rf=Ci(Rf,1)if zj then nh=M[25470]or ic(25470,11144,28479)break end nh=M[-17295]or ic(-17295,102935,58148)end else Oi=Oi+pb;Mj=Oi;if Oi~=Oi then nh=M[8158]or ic(8158,99871,58628)else nh=63230 end end elseif nh>44627 then if Zd<=#Lj then nh=53173 else nh=64706 end else if Zd<=#Lj then nh=M[27435]or ic(27435,119786,46947)break end nh=M[10690]or ic(10690,89325,45581)end end until nh==35590 end);Fk=(function()local pd,Lh,Ah,O,Vk,pg,w,eg,xk,qc,ah,xf=wl[Yk('\241\156\231\198\161','\147\245')][Yk('\193\226\204\232','\163\154')],wl[Yk('\nC\28\25Z','h*')][Yk('@\252L\249','\"\157')],wl[Yk('4\180\"\238d','V\221')][Yk('S^C','1')],wl[Yk('I\198_\156\25','+\175')][Yk('\242\23O\247\2S',"\158d\'")],wl[Yk('\214\240\192\170\134','\180\153')][Yk('\234}]\241hA','\152\14\53')],wl[Yk('\22\209~\f\203k','e\165\f')][Yk('QW@','\"')],wl[Yk("n=\6t\'\19",'\29It')][Yk('\155\178\136\184','\235\211')],wl[Yk(':\230> \252+','I\146L')][Yk('\a\51\177\19>\170','r]\193')],wl[Yk('+\221\128\49\199\149','X\169\242')][Yk('@WB','2')],wl[Yk('\17]\aP\0','e<')][Yk('\137\135\154\141','\249\230')],wl[Yk('\160\159\182\146\177','\212\254')][Yk('\5 \233\17-\242','pN\153')],wl[Yk('D\244R\249U','0\149')][Yk('\21K\221\25W\218','|%\174')]local function jj(Ij,J,Nc,Eh,ta)local Dj,B,te,sf=Ij[J],Ij[Nc],Ij[Eh],Ij[ta]local ma Dj=Lh(Dj+B,4294967295)ma=pd(sf,Dj);sf=Lh(Ah(O(ma,16),Vk(ma,16)),4294967295)te=Lh(te+sf,4294967295)ma=pd(B,te);B=Lh(Ah(O(ma,12),Vk(ma,20)),4294967295)Dj=Lh(Dj+B,4294967295)ma=pd(sf,Dj);sf=Lh(Ah(O(ma,8),Vk(ma,24)),4294967295)te=Lh(te+sf,4294967295)ma=pd(B,te);B=Lh(Ah(O(ma,7),Vk(ma,25)),4294967295)Ij[J],Ij[Nc],Ij[Eh],Ij[ta]=Dj,B,te,sf return Ij end local eb,rd={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}local vk=function(Ib,kc,xl)local ok,Hk,xg,Xj,Ii,Od,ej,il,Vj ok,Xj={},function(pa,ih,_b)ok[pa]=Vf(ih,59992)-Vf(_b,21948)return ok[pa]end Ii=ok[8617]or Xj(8617,56837,18503)repeat while true do if Ii<=33556 then if Ii>16729 then if Ii<=24657 then if Ii<=20908 then if Ii>18753 then xg=Vj;if Od~=Od then Ii=25482 else Ii=ok[-27002]or Xj(-27002,38175,23910)end else xg=Vj;if Od~=Od then Ii=22156 else Ii=27100 end end elseif Ii<=23093 then Vj,Hk,Od=73,1,(10)+72 Ii=19719 else ej[(xg-86)]=Lh(ej[(xg-86)]+il[(xg-86)],4294967295)Ii=ok[15170]or Xj(15170,107979,55294)end elseif Ii<=28098 then if Ii<=25884 then if Ii>25075 then Vj,Hk,Od=87,1,(16)+86 Ii=45851 else Vj=Vj+Hk;xg=Vj;if Vj~=Vj then Ii=22156 else Ii=27100 end end else if(Hk>=0 and Vj>Od)or((Hk<0 or Hk~=Hk)and Vj<Od)then Ii=22156 else Ii=15557 end end elseif Ii>30922 then ej[(xg-241)+4]=Ib[(xg-241)]Ii=ok[-5153]or Xj(-5153,14156,17107)else if(Hk>=0 and Vj>Od)or((Hk<0 or Hk~=Hk)and Vj<Od)then Ii=ok[-3573]or Xj(-3573,26515,32765)else Ii=65181 end end elseif Ii>8744 then if Ii<=12339 then ej[13]=kc Vj,Od,Hk=96,(3)+95,1 Ii=ok[-21362]or Xj(-21362,107028,1821)elseif Ii>14636 then il[(xg-220)]=ej[(xg-220)]Ii=ok[30129]or Xj(30129,130608,57776)elseif Ii>13888 then return ej else Od,Vj,Hk=(16)+220,221,1 Ii=17787 end elseif Ii<=3830 then if(Hk>=0 and Vj>Od)or((Hk<0 or Hk~=Hk)and Vj<Od)then Ii=13715 else Ii=ok[21169]or Xj(21169,1815,5085)end elseif Ii<=4837 then Vj=Vj+Hk;xg=Vj;if Vj~=Vj then Ii=25482 else Ii=30317 end else ej,il=eb,rd;ej[1],ej[2],ej[3],ej[4]=3067308111,2768252519,2821727500,650695327 Od,Vj,Hk=(8)+241,242,1 Ii=47859 end elseif Ii<=49810 then if Ii>41149 then if Ii<=45296 then ej[(xg-95)+13]=xl[(xg-95)]Ii=ok[-10705]or Xj(-10705,97344,36436)elseif Ii<=46855 then xg=Vj;if Od~=Od then Ii=ok[32335]or Xj(32335,5130,37592)else Ii=40143 end elseif Ii<=47761 then Vj=Vj+Hk;xg=Vj;if Vj~=Vj then Ii=ok[18387]or Xj(18387,32337,3018)else Ii=1931 end else xg=Vj;if Od~=Od then Ii=9122 else Ii=34439 end end elseif Ii<=37291 then if(Hk>=0 and Vj>Od)or((Hk<0 or Hk~=Hk)and Vj<Od)then Ii=ok[20356]or Xj(20356,9883,64669)else Ii=ok[-27569]or Xj(-27569,31995,20167)end else if(Hk>=0 and Vj>Od)or((Hk<0 or Hk~=Hk)and Vj<Od)then Ii=ok[11913]or Xj(11913,40682,26744)else Ii=ok[-1544]or Xj(-1544,116017,33847)end end elseif Ii<=57889 then if Ii>51579 then Vj=Vj+Hk;xg=Vj;if Vj~=Vj then Ii=ok[-2798]or Xj(-2798,16756,8578)else Ii=ok[6814]or Xj(6814,111828,37889)end else Vj=Vj+Hk;xg=Vj;if Vj~=Vj then Ii=ok[-30927]or Xj(-30927,5333,36695)else Ii=ok[1014]or Xj(1014,127909,50890)end end elseif Ii>64036 then jj(il,1,5,9,13);jj(il,2,6,10,14);jj(il,3,7,11,15);jj(il,4,8,12,16);jj(il,1,6,11,16);jj(il,2,7,12,13);jj(il,3,8,9,14);jj(il,4,5,10,15)Ii=ok[13618]or Xj(13618,13404,39712)else xg=Vj;if Od~=Od then Ii=13715 else Ii=1931 end end end until Ii==13974 end local function Rk(yf,zc,cb,rc,Cf)local be,Kf,Ba,tb,Fc,od,Ek,p,tg,Ph be,tg={},function(Lb,Sd,mf)be[Lb]=Vf(Sd,25646)-Vf(mf,35954)return be[Lb]end Fc=be[6100]or tg(6100,38328,20264)repeat while true do if Fc<=33355 then if Fc>16650 then if Fc>31142 then wl[Yk('\155\129\199\159\128\192','\250\242\180')](#rc>=64)Ba,tb=qc(eg(Yk('\211-%\201\176\227\204^\15\210\178\140\25\157\31z\219-%\201\176\227\204^\15\210\178\140\25\157\31z\219','\239d\17\128\132\170\248\23;\155\134\197-\212+3'),rc,Cf)),vk(yf,zc,cb)od,Ph,Kf=139,(16)+138,1 Fc=be[-5035]or tg(-5035,91700,35288)else Ba=pg(rc,Cf);rc=Ba..xk(Yk('\254','\254'),64-p)Cf=1 Fc=be[-27067]or tg(-27067,49340,42415)end elseif Fc<=8368 then return od elseif Fc<=13342 then p=#rc-Cf+1;if p<64 then Fc=be[18121]or tg(18121,78105,20717)break end Fc=31413 else if(Kf>=0 and od>Ph)or((Kf<0 or Kf~=Kf)and od<Ph)then Fc=be[1744]or tg(1744,79244,18278)else Fc=64822 end end elseif Fc>49634 then if Fc>62704 then if Fc<=64541 then od=od+Kf;Ek=od;if od~=od then Fc=be[-30976]or tg(-30976,44045,52711)else Fc=14849 end elseif Fc>64723 then Ba[(Ek-138)]=pd(Ba[(Ek-138)],tb[(Ek-138)])Fc=be[-2119]or tg(-2119,116319,11039)else Ek=od;if Ph~=Ph then Fc=be[27292]or tg(27292,85552,12258)else Fc=14849 end end else od=pg(od,1,p)Fc=be[25594]or tg(25594,8421,45337)end else od=w(Yk('\18\211>l\141: Y\164\185e\214\195\3\251\149\26\211>l\141: Y\164\185e\214\195\3\251\149\26','.\154\n%\185s\20\16\144\240Q\159\247J\207\220'),ah(Ba));if not(p<64)then Fc=be[23589]or tg(23589,56814,15890)break else Fc=be[-8556]or tg(-8556,94637,42154)break end Fc=be[-26477]or tg(-26477,32948,20808)end end until Fc==29974 end local function Ji(si)local oh,Cj,I,_d,Bf,cd,Le,Ai _d,cd={},function(xb,wj,t)_d[xb]=Vf(wj,63624)-Vf(t,25924)return _d[xb]end Ai=_d[-28772]or cd(-28772,12411,50719)repeat while true do if Ai<=36576 then if Ai<=20277 then if Ai<=10262 then Le='';Cj,I,Bf=(#si)+38,39,1 Ai=_d[10732]or cd(10732,114249,11228)else return Le end else if(Bf>=0 and I>Cj)or((Bf<0 or Bf~=Bf)and I<Cj)then Ai=_d[-25220]or cd(-25220,22370,57361)else Ai=43062 end end elseif Ai>53295 then if Ai>60055 then oh=I;if Cj~=Cj then Ai=10901 else Ai=30930 end else I=I+Bf;oh=I;if I~=I then Ai=_d[-30718]or cd(-30718,21565,59236)else Ai=30930 end end else Le=Le..si[(oh-38)]Ai=_d[-9154]or cd(-9154,80163,33249)end end until Ai==1696 end local function hg(gc,Uk,Ac,Fj)local Ne,fa,ab,li,Gg,Se,ra fa,Se={},function(pl,If,o)fa[pl]=Vf(If,3758)-Vf(o,3879)return fa[pl]end li=fa[32071]or Se(32071,58745,1112)repeat while true do if li<=47629 then xf(ra,Rk(Gg,Uk,ab,Fj,Ne))Ne=Ne+64 Uk=Uk+1 li=fa[32199]or Se(32199,70319,21146)elseif li<=53070 then if Ne<=#Fj then li=fa[1752]or Se(1752,50525,14102)else li=57053 end elseif li<=57242 then return Ji(ra)else Gg,ab,ra,Ne=qc(eg(Yk('9(\150\198mv\134,1(\150\198mv\134,1','\5a\162\143Y?\178e'),gc)),qc(eg(Yk('\253\96$\136\29Y\245','\193)\16'),Ac)),{},1;li=48708;end end until li==51825 end return function(Wd,xe,wg)return hg(wg,0,xe,Wd)end end)();md=(function()local of,Ig,kh,di,yl,je,ha,pk,Mk,jd,Ch=wl[Yk('\154\4\140^\202','\248m')][Yk('P/]5','2A')],wl[Yk('a\205w\151\49','\3\164')][Yk('\166.\171$','\196V')],wl[Yk('\15\189\25\231_','m\212')][Yk('~\1\211e\20\207','\fr\187')],wl[Yk('>\179(\233n','\\\218')][Yk('\223\23\195\218\2\223','\179d\171')],wl[Yk("\153\'\143}\201",'\251N')][Yk('\18\16\30\21','pq')],wl[Yk('~\140h\214.','\28\229')][Yk('JGZ','(')],wl[Yk('\148\197\130\200\133','\224\164')][Yk('_\225\192S\253\199','6\143\179')],wl[Yk('f\253p\240w','\18\156')][Yk('\234\236q\254\225j','\159\130\1')],wl[Yk('\235\133J\241\159_','\152\241\56')][Yk('\195\212\193','\177')],wl[Yk('\186\240$\160\234\49','\201\132V')][Yk('\131\192\129\218','\224\168')],wl[Yk('\175\252I\181\230\\','\220\136;')][Yk('O\216Y\196','-\161')]local function Nb(Sf,fl)local Vg,Ub=kh(Sf,fl),di(Sf,32-fl)return yl(je(Vg,Ub),4294967295)end local bd bd=function(Ng)local Ob={1116352408,1899447441,3049323471,3921009573,961987163,1508970993,2453635748,2870763221,3624381080,310598401,607225278,1426881987,1925078388,2162078206,2614888103,3248222580,3835390401,4022224774,264347078,604807628,770255983,1249150122,1555081692,1996064986,2554220882,2821834349,2952996808,3210313671,3336571891,3584528711,113926993,338241895,666307205,773529912,1294757372,1396182291,1695183700,1986661051,2177026350,2456956037,2730485921,2820302411,3259730800,3345764771,3516065817,3600352804,4094571909,275423344,430227734,506948616,659060556,883997877,958139571,1322822218,1537002063,1747873779,1955562222,2024104815,2227730452,2361852424,2428436474,2756734187,3204031479,3329325298}local function Qd(C)local Jb,lh,Zj,Xg,Dk,Dc Dk,Jb={},function(Fg,Kd,vj)Dk[Fg]=Vf(Kd,29384)-Vf(vj,4589)return Dk[Fg]end Xg=Dk[-28373]or Jb(-28373,52742,25941)repeat while true do if Xg<=32025 then if Xg<=12805 then C=C..Mk(Yk('p','p'),Dc)Xg=Dk[-14019]or Jb(-14019,118883,54656)else lh=#C;Zj=lh*8;C=C..Yk('\b','\136')Dc=64-((lh+9)%64)if Dc~=64 then Xg=Dk[-26161]or Jb(-26161,40023,49991)break end Xg=Dk[2470]or Jb(2470,44472,4319)end else C=C..jd(yl(kh(Zj,56),255),yl(kh(Zj,48),255),yl(kh(Zj,40),255),yl(kh(Zj,32),255),yl(kh(Zj,24),255),yl(kh(Zj,16),255),yl(kh(Zj,8),255),yl(Zj,255))return C end end until Xg==47368 end local function lb(gk)local Xc,Yi,ia,Ha,Za,sb,qj,ge Yi,Za={},function(Ec,ea,Bi)Yi[Ec]=Vf(ea,44454)-Vf(Bi,36182)return Yi[Ec]end ia=Yi[5873]or Za(5873,28800,39283)repeat while true do if ia>28607 then if ia>50780 then Xc={};sb,ge,Ha=64,151,(#gk)+150 ia=50104 else qj=ge;if Ha~=Ha then ia=5835 else ia=Yi[15574]or Za(15574,100915,20064)end end elseif ia<=15726 then if ia>5796 then return Xc else ha(Xc,gk[Yk('\186\188\171','\201')](gk,(qj-150),(qj-150)+63))ia=Yi[-11905]or Za(-11905,17504,7518)end elseif ia<=24334 then ge=ge+sb;qj=ge;if ge~=ge then ia=Yi[-11226]or Za(-11226,50961,57018)else ia=25695 end else if(sb>=0 and ge>Ha)or((sb<0 or sb~=sb)and ge<Ha)then ia=5835 else ia=Yi[-6933]or Za(-6933,4026,1736)end end end until ia==1114 end local function oa(Yb,bc)local n,wd,Pk,dk,Qf,ji,ni,Mh,Zk,Re,vh,R,Zg,bk,xa,Oa,Zc,Xb,a,lf,Wk,Gh Xb,Zg={},function(Tg,Hg,Eg)Xb[Tg]=Vf(Hg,54730)-Vf(Eg,14247)return Xb[Tg]end vh=Xb[13383]or Zg(13383,108989,44696)repeat while true do if vh>35429 then if vh>50339 then if vh<=60925 then if vh<=57869 then Qf,lf=Ig(Nb(Oa,6),Nb(Oa,11),Nb(Oa,25)),Ig(yl(Oa,ni),yl(of(Oa),Zk));Wk,dk,Zc=yl(Re+Qf+lf+Ob[(n-19)]+xa[(n-19)],4294967295),Ig(Nb(ji,2),Nb(ji,13),Nb(ji,22)),Ig(yl(ji,Mh),yl(ji,wd),yl(Mh,wd));Gh=yl(dk+Zc,4294967295);Re=Zk Zk=ni ni=Oa Oa=yl(a+Wk,4294967295)a=wd wd=Mh Mh=ji ji=yl(Wk+Gh,4294967295)vh=Xb[-26863]or Zg(-26863,104397,34641)else xa={};wd,ji,Mh=1,121,(64)+120 vh=40472 end else if(a-120)<=16 then vh=Xb[16181]or Zg(16181,6815,43204)break else vh=Xb[30013]or Zg(30013,115406,44274)break end vh=Xb[7284]or Zg(7284,107785,50314)end elseif vh>43089 then if vh>47510 then if vh<=48699 then ji,Mh,wd,a,Oa,ni,Zk,Re=pk(bc);bk,Pk,R=20,1,(64)+19 vh=45241 else if(Pk>=0 and bk>R)or((Pk<0 or Pk~=Pk)and bk<R)then vh=Xb[-17183]or Zg(-17183,15800,28132)else vh=Xb[-878]or Zg(-878,12496,13215)end end else n=bk;if R~=R then vh=Xb[-22572]or Zg(-22572,105379,63389)else vh=49779 end end elseif vh<=38435 then if vh<=36768 then return yl(bc[1]+ji,4294967295),yl(bc[2]+Mh,4294967295),yl(bc[3]+wd,4294967295),yl(bc[4]+a,4294967295),yl(bc[5]+Oa,4294967295),yl(bc[6]+ni,4294967295),yl(bc[7]+Zk,4294967295),yl(bc[8]+Re,4294967295)else bk=bk+Pk;n=bk;if bk~=bk then vh=36399 else vh=49779 end end else a=ji;if Mh~=Mh then vh=47619 else vh=6579 end end elseif vh<=19364 then if vh<=9426 then if(wd>=0 and ji>Mh)or((wd<0 or wd~=wd)and ji<Mh)then vh=47619 else vh=Xb[-21040]or Zg(-21040,95683,37718)end else xa[(a-120)]=je(di(Ch(Yb,((a-120)-1)*4+1),24),di(Ch(Yb,((a-120)-1)*4+2),16),di(Ch(Yb,((a-120)-1)*4+3),8),Ch(Yb,((a-120)-1)*4+4))vh=Xb[-16261]or Zg(-16261,12246,19233)end elseif vh<=31906 then Oa,ni=Ig(Nb(xa[(a-120)-15],7),Nb(xa[(a-120)-15],18),kh(xa[(a-120)-15],3)),Ig(Nb(xa[(a-120)-2],17),Nb(xa[(a-120)-2],19),kh(xa[(a-120)-2],10));xa[(a-120)]=yl(xa[(a-120)-16]+Oa+xa[(a-120)-7]+ni,4294967295)vh=Xb[29892]or Zg(29892,114222,55785)else ji=ji+wd;a=ji;if ji~=ji then vh=47619 else vh=Xb[-29839]or Zg(-29839,48022,25358)end end end until vh==63879 end local Kc,wk,ya,ek,ue,Xi,T,fi,fe,Of,Yc,Hb Xi,ya={},function(se,pj,kd)Xi[se]=Vf(pj,20936)-Vf(kd,5809)return Xi[se]end Hb=Xi[6281]or ya(6281,96307,58097)repeat while true do if Hb<=34381 then if Hb<=18826 then if Hb>8666 then if Hb<=12574 then wk,ue,Of=A(wk)Hb=Xi[18062]or ya(18062,125316,61581)elseif Hb>13244 then Ng=Qd(Ng)ek,fe,T=lb(Ng),{1779033703,3144134277,1013904242,2773480762,1359893119,2600822924,528734635,1541459225},''wk,ue,Of=wl[Yk('\223\162\22\223\160\4','\182\210w')](ek)if pe(wk)~='function'then Hb=Xi[-6167]or ya(-6167,89328,52683)break end Hb=Xi[-22528]or ya(-22528,72250,28499)else Yc=ac(wk)if Yc~=nil and Yc.__iter~=nil then Hb=Xi[-21580]or ya(-21580,116268,36853)break elseif pe(wk)==Yk('$\224\50\237\53','P\129')then Hb=Xi[-1234]or ya(-1234,85840,58535)break end Hb=Xi[-15498]or ya(-15498,94312,22817)end else fe={oa(Kc,fe)}Hb=Xi[15315]or ya(15315,84964,24237)end elseif Hb>31552 then wk,ue,Of=A(wk)Hb=Xi[16550]or ya(16550,75413,61965)else wk,ue,Of=Yc.__iter(wk)Hb=Xi[8497]or ya(8497,33729,10713)end elseif Hb>51360 then if Hb<=58552 then if Hb>52848 then fi,Kc=wk(ue,Of);Of=fi;if Of==nil then Hb=Xi[15779]or ya(15779,129648,54940)else Hb=3578 end else T=T..jd(yl(kh(Kc,24),255))T=T..jd(yl(kh(Kc,16),255))T=T..jd(yl(kh(Kc,8),255))T=T..jd(yl(Kc,255))Hb=Xi[-8452]or ya(-8452,119795,63787)end elseif Hb>62741 then wk,ue,Of=Yc.__iter(wk)Hb=Xi[29390]or ya(29390,121013,41436)else wk,ue,Of=wl[Yk('\245\158\222\245\156\204','\156\238\191')](fe);if pe(wk)~='function'then Hb=Xi[28168]or ya(28168,68196,41050)break end;Hb=Xi[-25291]or ya(-25291,74521,63105);end elseif Hb<=41611 then fi,Kc=wk(ue,Of);Of=fi;if Of==nil then Hb=45686 else Hb=51920 end elseif Hb<=43931 then Yc=ac(wk)if Yc~=nil and Yc.__iter~=nil then Hb=Xi[-5519]or ya(-5519,65017,11386)break elseif pe(wk)==Yk('\223\229\201\232\206','\171\132')then Hb=Xi[-16643]or ya(-16643,119800,60324)break end Hb=Xi[25167]or ya(25167,52424,7406)else return T end end until Hb==20438 end;return bd end)();(function(Tk)local function l(Mg)return Tk[Mg-20715]end;local Fi,jk,kj,Fe,Dh,ml,zb,N,Xd,xc,Ud,cc,ad,ul,vc,Mb,i,dg,U,aj,lk,me,P,Gb,sk,Sa,zg,Ie,Ab=wl[Yk('\232\4\236\24','\156}')],wl[Yk('\195\233\210\230\223','\179\138')],wl[Yk('\24\15\15\18\15','}}')],wl[Yk('w\28ZIn\17QN','\3s4<')],wl[Yk('\233\14%\237\15\"','\136}V')],wl[Yk('P\255\132F\249\156','#\154\232')],wl[Yk('\178\225\29_\185\232\160\240\bP\176\249','\193\132i2\220\156')],wl[Yk('t\180\243n\174\230','\a\192\129')][Yk('\179##\184-%','\213LQ')],wl[Yk('V\204\130L\214\151','%\184\240')][Yk('\130ZZ\150WA','\247\52*')],wl[Yk('!\143\51;\149&','R\251A')][Yk('VPG','%')],wl[Yk('\n\169\19\16\179\6','y\221a')][Yk('I\254_\226','+\135')],wl[Yk('\167(\f\189\50\25','\212\\~')][Yk('\177\143\179\149','\210\231')],wl[Yk('\180\143\162\130\165','\192\238')][Yk('\255\240\228\250','\146\159')],wl[Yk('m\6{\v|','\25g')][Yk('[\204H\198','+\173')],wl[Yk('^\227H\238O','*\130')][Yk('f\179Pd\181P','\5\193\53')],wl[Yk('|LjAm','\b-')][Yk('\232\1\218\228\29\221','\129o\169')],wl[Yk('\214\28\192\17\199','\162}')][Yk('jq\227j\127\249','\t\30\141')],wl[Yk(';\158\131\127-\133\152~=','X\241\241\16')][Yk('\134\25\254\132\31\254','\229k\155')],wl[Yk('LJ\206\16ZQ\213\17J','/%\188\127')][Yk('M\225Q\228P','4\136')],wl[Yk('\172\220\172\f\186\199\183\r\170','\207\179\222c')][Yk('\162JP\165BF','\208/#')],wl[Yk(' \155\180_6\128\175^&','C\244\198\48')][Yk('\a\238\v\241\1','d\130')],wl[Yk('c\au]3','\1n')][Yk('\6\v\22','d')],wl[Yk('\147\208\133\138\195','\241\185')][Yk('\205w\192}','\175\15')],wl[Yk('\209\14\199T\129','\179g')][Yk('g\146k\151','\5\243')],wl[Yk('\151\174\129\244\199','\245\199')][Yk('\173\r\170\n\187','\207y')],wl[Yk('\197m\211\55\149','\167\4')][Yk('\143$~\148\49b','\253W\22')],wl[Yk('\200\243\222\169\152','\170\154')][Yk('\240Rb\245G~','\156!\n')],wl[Yk('r{d!\"','\16\18')][Yk('nE%y\\\50\127','\v=Q')],{[l(7787)]={},[32371]={},[l(-7372)]={{l(22858),6,l(27618)},{l(35602),3,l(-4478)},{l(39182),l(-5992),false},{3,l(52209),l(5487)},{l(-6215),l(20140),l(23095)},{l(31771),l(21374),l(9802)},{l(-5371),l(50970),l(12798)},{l(10362),l(25183),l(22485)},{l(1676),l(10879),l(13964)},{l(26583),l(9013),l(-9468)},{l(35659),l(5352),l(37033)},{l(-8727),l(45808),l(120)},{l(-3687),l(36980),l(13238)},{l(17525),l(29845),l(-11439)},{l(41955),l(660),l(3295)},{l(47900),l(9855),l(31046)},{l(3731),l(48644),l(26224)},{l(29943),7,false},{l(25644),l(21566),l(592)},{l(19111),l(38134),l(19773)},{l(44448),l(31392),l(10606)},{l(25289),l(13391),l(21713)},{l(34122),7,l(3196)},{l(16416),l(-11337),l(44364)},{l(-967),l(39325),l(-7876)},{l(47439),l(2706),l(19985)},{l(27322),l(28709),false},{8,l(15705),l(3886)},{l(10519),l(25075),l(45140)},{l(17016),l(51181),false},{l(29869),l(20402),l(13590)},{l(36780),l(-11205),l(42048)},{l(48754),l(2519),true},{l(23191),l(10904),l(49875)},{l(6432),l(-3860),l(42383)},{l(-6662),l(37735),l(2379)},{l(2363),l(32959),l(-8984)},{l(245),l(-7946),l(46294)},{l(-2035),l(26788),l(8838)},{l(41922),l(18231),l(41544)},{l(18689),l(23581),l(-2355)},{l(51049),l(-5312),l(39630)},{l(11120),l(7938),l(4625)},{7,l(-864),l(1392)},{l(12703),l(8147),l(40502)},{l(13826),l(37590),l(31928)},{l(49248),l(35707),false},{l(3189),l(47325),l(-7240)},{l(3411),l(-3272),l(25575)},{l(40703),l(45670),l(50575)},{l(16971),l(29807),l(12397)},{l(45380),l(21638),false},{l(26262),l(-9458),l(-4269)},{l(52674),l(21565),l(23223)},{3,l(50523),l(34731)},{l(10533),l(-5987),l(-5837)},{l(26414),l(36537),l(6868)},{l(29386),l(17221),l(18972)},{l(10822),l(-2042),l(12965)},{l(52309),l(33055),l(46621)},{l(43304),l(39332),l(48677)},{l(36475),l(48857),l(4301)},{l(22866),l(35930),l(37819)},{l(25971),6,l(18792)},{8,l(12336),l(16623)},{l(49430),5,l(4617)},{l(43658),l(-1508),l(-511)},{7,l(28231),l(19561)},{l(38827),l(31140),l(23985)},{l(41596),l(26920),l(36022)},{l(-7472),l(5375),l(44990)},{l(19777),l(2775),true},{3,l(-10399),false},{l(23659),5,l(44571)},{l(8367),l(-11777),l(49131)},{l(9593),l(-10089),l(-7615)},{l(46534),l(7774),l(39186)},{l(47834),l(39460),l(13167)},{l(47637),l(9679),l(34974)},{l(15484),l(36429),l(37408)},{l(-1352),l(9281),l(52260)},{l(39875),l(2773),l(38483)},{l(43282),l(45904),false},{l(43623),l(-7465),l(24143)},{l(42968),4,true},{l(4889),l(2906),l(11859)},{l(35990),10,l(25373)},{l(44984),l(17367),l(25661)},{l(9577),l(24800),l(17739)},{l(36892),l(-5685),l(29015)},{l(-2663),l(52892),l(43907)},{l(-2399),l(23171),l(27350)},{l(45762),7,l(39807)},{9,6,l(7618)},{l(16953),l(11725),l(-6421)},{l(10327),l(10562),l(-11900)},{l(13701),l(31041),l(36572)},{l(-8503),l(48001),l(6771)},{l(-3977),l(34873),l(30576)},{l(25578),l(27944),l(-481)},{l(-1133),l(14435),l(18953)},{l(13887),l(15440),false},{l(46537),l(45838),l(31425)},{3,l(38592),l(6532)},{l(45387),l(29525),l(-10877)},{l(11952),l(44020),l(16737)},{l(34744),l(44355),l(-8647)},{l(44946),l(34801),l(13266)},{l(12367),l(48926),l(45532)},{l(-6744),l(32973),true},{7,l(42647),l(22158)},{l(6359),l(49126),l(8335)},{l(36133),l(22133),l(42734)},{l(38660),l(1234),l(49211)},{3,l(9821),l(38566)},{7,l(33948),l(43865)},{l(21966),5,l(2231)},{l(21714),l(5209),l(46138)},{l(27880),9,l(2792)},{l(23768),l(35954),l(35031)},{l(31688),l(41099),false},{l(4750),l(52727),l(29479)},{l(39497),l(8070),l(26119)},{l(-5752),l(18179),l(-1068)},{l(35369),l(9407),false},{l(20926),7,l(30424)},{l(7844),l(9790),l(36938)},{l(29165),1,l(53028)},{l(24235),l(48071),l(-5198)},{l(-6303),l(20122),false},{l(8309),l(50713),l(9099)},{l(7021),l(3053),false},{l(5400),l(-9058),false},{l(6551),6,l(10990)},{l(103),l(38677),l(-7449)},{l(7827),l(11341),l(7842)},{l(31301),l(5306),l(21341)},{7,l(8694),l(2875)},{l(35462),l(40719),l(-6727)},{l(-8118),6,l(53043)},{l(23808),l(14810),l(8829)},{l(8424),l(26243),l(33332)},{l(-10044),l(10142),l(3842)},{l(608),l(20181),l(45981)},{l(30600),l(-3492),l(-3418)},{3,l(21394),false},{7,6,l(-11320)},{4,l(5779),l(-6950)},{l(13395),l(-9615),l(37713)},{l(27325),l(40568),l(4392)},{l(678),l(22094),l(47417)},{7,l(5559),l(13561)},{l(9625),l(24104),l(2690)},{l(11231),l(-6412),l(24778)},{l(40888),l(48759),l(35016)},{l(48283),l(53477),l(49009)},{l(30351),l(2949),l(-7872)},{l(13367),l(183),l(47311)},{l(-9403),l(31709),false},{l(43339),l(-495),l(50808)},{l(13935),l(14797),l(7251)},{l(39552),l(-10896),l(18968)},{l(37763),l(5690),l(42839)},{l(12308),6,l(-4120)},{l(10009),7,l(49960)},{l(39464),l(41387),l(16714)},{l(28466),l(28079),l(37651)},{l(30394),l(50025),false},{l(41297),l(37928),l(18834)},{4,l(23427),l(11371)},{l(520),l(43414),l(-10984)},{l(34842),l(30249),l(27539)},{l(9880),6,l(36545)},{l(10658),l(48694),l(5803)},{l(13134),l(51022),l(399)},{l(40305),l(36104),l(13376)},{l(41657),l(-7021),l(-1656)},{l(7071),l(-10557),l(2885)},{l(2258),l(9645),l(49422)},{l(5944),2,l(22940)},{l(2415),l(5539),false},{l(14983),l(-430),l(-801)},{7,l(46955),l(-5352)},{l(16234),l(41086),l(8749)},{l(27318),l(24217),l(-5378)},{l(1366),l(29947),l(52314)},{l(6255),l(33262),l(17361)},{l(32492),l(25181),l(9332)},{l(41000),l(42235),l(44492)},{l(-1053),l(2717),l(49439)},{l(-11280),l(23582),l(31345)},{l(43674),6,l(48190)},{l(52510),l(14881),l(34486)},{l(-4053),l(18414),l(53167)},{l(23578),l(17996),l(2978)},{l(41363),l(-11496),l(13705)},{l(40388),l(28462),l(51783)},{l(10838),l(16270),l(50432)},{l(-11624),l(34924),true},{l(26013),l(44449),l(52784)},{l(42577),l(3138),l(52308)},{l(7205),l(28335),l(34454)},{l(-8900),l(-11107),l(-1512)},{l(6897),l(28115),l(47911)},{l(38327),l(38581),false},{l(45984),l(-10543),l(30674)},{l(37115),l(33285),l(50120)},{l(42459),l(52275),l(17155)},{l(42368),l(3965),true},{l(23340),l(-9411),l(10001)},{l(19176),l(53329),l(40211)},{l(37837),l(37882),l(41413)},{l(47107),l(-1242),l(45284)},{l(26736),l(5154),l(16208)},{l(-816),l(3212),l(2128)},{l(34373),l(8353),l(17969)},{l(16310),l(20689),l(-6021)},{l(-9659),9,l(29207)},{l(42332),l(8635),l(-8763)},{l(13334),l(17901),l(-1946)},{l(-175),l(43614),l(41138)},{l(2942),l(19537),l(5864)},{l(43104),l(8293),l(45858)},{l(24772),l(20406),l(10382)},{l(45204),l(19397),l(10498)},{l(18514),l(-4588),l(46022)},{l(10851),l(8038),l(-7293)},{l(44690),7,l(31815)},{l(-8839),l(36276),l(16887)},{l(5595),l(39935),l(-7179)},{l(18207),5,l(26308)},{l(34792),10,l(8921)},{l(-190),l(12584),l(2807)},{l(45902),l(42686),l(26184)},{l(52049),l(-7011),l(7075)},{l(27232),l(-6836),l(19576)},{l(4280),l(-8976),true},{l(47017),l(5445),l(22012)},{l(29497),l(-7494),l(21574)},{l(49036),l(-1640),l(491)},{l(47390),l(4434),false},{7,l(17616),l(4650)},{l(42109),l(25536),l(-7024)},{l(40490),l(27257),l(17394)},{l(49743),9,l(30564)},{l(46478),l(34985),l(-4162)},{l(48174),l(7244),true},{l(16291),l(41830),l(7199)},{l(29589),l(10023),l(6543)},{l(30587),l(13865),l(31051)},{l(8702),l(36372),l(27211)},{l(44812),l(17593),l(48578)},{l(9097),l(19980),l(-4412)},{l(15470),l(-1362),l(27845)},{9,l(50825),l(7956)},{l(20577),l(22120),l(6140)}}}local function Ih(Ca)return(function(ec)local function sj(rk)return ec[rk- -18545]end;local zi=Ab[sj(-12466)][Ca]if not(zi)then else return zi end local Sg,dj=Ca,sj(2492)local function Ei()return(function(vg)local zk,Nj,ti,Wc,ki,Xh,fk,Mi,eh,ke,yk,dl,wb,Sj,jg,qg,La,jf,Vb,Bb,vl,ci,Lc,Pj,Ga,Bj,Qg,v,Ck,Pb,nk ki,Bj={},function(_g,_h,Yj)ki[_g]=Vf(_h,3518)-Vf(Yj,63721)return ki[_g]end Xh=ki[31731]or Bj(31731,104888,16164)repeat while true do if Xh>32978 then if Xh<=49075 then if Xh<=40775 then if Xh<=36698 then if Xh<=34734 then if Xh<=33478 then if Xh<=33299 then if Nj(-1852)then Xh=37250 else Xh=ki[20589]or Bj(20589,94938,25143)end else if Nj(34502)then Xh=ki[-22641]or Bj(-22641,82795,27209)else Xh=ki[-18088]or Bj(-18088,19462,51563)end end else Lc=ci Xh=ki[-7351]or Bj(-7351,95345,30905)break end elseif Xh>35641 then if Xh<=36237 then dl=Lc;zk=vc(dl);nk,Pb,wb=dl,Nj(40885),1 Xh=ki[-11709]or Bj(-11709,67642,5092)else eh=Nj(34061)Xh=ki[-28794]or Bj(-28794,107621,17548)end else nk[Nj(41277)]=wb[nk[Nj(8659)]+Nj(13294)]Xh=ki[23856]or Bj(23856,74670,47481)end elseif Xh<=38738 then if Xh<=37746 then Pb=zk;nk=Gb(Pb,Nj(46783));wb=Ab[Nj(14722)][nk+Nj(23921)];ke,qg,ci=wb[Nj(29652)],wb[Nj(37276)],wb[Nj(-6140)];Ga={[49222]=Nj(34041),[Nj(10839)]=Nj(35251),[Nj(1092)]=Nj(31734),[Nj(-1172)]=0,[Nj(21464)]=qg,[Nj(50946)]=Nj(50848),[Nj(56610)]=Nj(31837),[Nj(55618)]=Nj(9165),[Nj(1970)]=nk,[Nj(8959)]=Nj(54609),[Nj(19303)]=Nj(-4047),[Nj(23702)]=Nj(33962),[Nj(22429)]=Nj(14200),[Nj(-6623)]=Nj(50563),[Nj(38116)]=Nj(17297),[Nj(32292)]=0};Mb(dl,Ga)if ke==Nj(48204)then Xh=ki[-14142]or Bj(-14142,26632,59674)break elseif ke==Nj(43403)then Xh=ki[10784]or Bj(10784,109006,21972)break elseif not(ke==Nj(-7888))then Xh=ki[14159]or Bj(14159,117470,10121)break else Xh=ki[19524]or Bj(19524,42085,46081)break end Xh=ki[-28063]or Bj(-28063,71476,51811)elseif Xh>38225 then zk=P(Pb,Nj(36751))Xh=61060 break else if Nj(-2455)then Xh=ki[-26086]or Bj(-26086,79966,3452)else Xh=ki[24369]or Bj(24369,37733,36803)end end elseif Xh<=39537 then if Xh>39155 then if Xh<=39407 then Lc=P(dl,Nj(5404))Xh=36177 break else Xh=ki[23264]or Bj(23264,29244,34979)break end else nk[Nj(3010)]=wb[nk[Nj(13788)]+Nj(-993)]Xh=ki[-22691]or Bj(-22691,63190,62977)end elseif Xh>39989 then ke=P(qg,Nj(45454))Xh=ki[-22027]or Bj(-22027,42094,35352)break else dl=Mi;if vl~=vl then Xh=ki[-31283]or Bj(-31283,76396,53527)else Xh=50971 end end elseif Xh>44815 then if Xh<=46759 then if Xh<=45675 then Ga[24748]=Wc Xh=ki[-5567]or Bj(-5567,97587,28772)else Wc=if jf<Nj(-2347)then jf else jf-Nj(8466)Xh=ki[-14365]or Bj(-14365,68963,43106)break end elseif Xh<=48280 then Pj,Vb=Sj,Nj(16685);Xh=ki[-4583]or Bj(-4583,55288,17934);else dl=Nj(44134);Pb,zk,nk=Nj(15155),Nj(55767),1 Xh=6796 end elseif Xh>42282 then if Xh>42864 then ke=Nj(43887);Xh=1349;else if(zk>=0 and Lc>dl)or((zk<0 or zk~=zk)and Lc<dl)then Xh=3520 else Xh=ki[-8551]or Bj(-8551,98670,17016)end end elseif Xh<=41652 then if Xh>41430 then Lc=Lc+zk;Pb=Lc;if Lc~=Lc then Xh=ki[19478]or Bj(19478,55507,16196)else Xh=ki[-25842]or Bj(-25842,85112,25841)end else Mi=P(vl,Nj(46449))Xh=16459 break end elseif Xh<=41931 then Mi=nil;Xh=10161;else La,Sj=Ck,Nj(13224);Xh=4150;end elseif Xh<=57160 then if Xh<=53113 then if Xh>50811 then if Xh>51626 then if Xh<=52040 then if eh then Xh=ki[2667]or Bj(2667,51571,53226)break else Xh=ki[10482]or Bj(10482,100995,19877)break end Xh=ki[31685]or Bj(31685,70122,54839)else Nj=function(mc)return vg[mc-23853]end Ck=Nj(26885)Xh=ki[25778]or Bj(25778,58404,24779)end elseif Xh<=51184 then if(Lc>=0 and Mi>vl)or((Lc<0 or Lc~=Lc)and Mi<vl)then Xh=ki[8348]or Bj(8348,76407,53532)else Xh=ki[1870]or Bj(1870,61061,10931)end else if ci==Nj(2454)then Xh=ki[416]or Bj(416,51781,15554)break end Xh=ki[30793]or Bj(30793,114729,6654)end elseif Xh>49940 then if Xh<=50328 then dl,zk=ti,Nj(4416);Xh=58502;else Wc=fk;Ga[Nj(-4019)]=Wc;Mb(dl,{})Xh=ki[-30666]or Bj(-30666,59926,39751)end else Pb=Pb+wb;ke=Pb;if Pb~=Pb then Xh=9554 else Xh=9043 end end elseif Xh>55299 then if Xh>56169 then if Xh<=56549 then Lc=Nj(20431);Xh=ki[1321]or Bj(1321,69659,38976);else Vb=P(yk,Nj(21826))Xh=ki[22930]or Bj(22930,54125,65246)break end else yk,jg=Vb,Nj(-1225);Xh=9019;end elseif Xh>54084 then if Xh<=54395 then if Xh<=54343 then if true then Xh=ki[-18348]or Bj(-18348,80318,41869)else Xh=7007 end else Xh=ki[-22541]or Bj(-22541,79236,26219)break end elseif Xh<=54426 then zk=P(Pb,Nj(21541))Xh=37250 break else zk=zk+nk;wb=zk;if zk~=zk then Xh=ki[-1646]or Bj(-1646,68206,38641)else Xh=ki[-15715]or Bj(-15715,66155,58445)end end elseif Xh<=53768 then if Xh<=53729 then Pb=Lc;if dl~=dl then Xh=ki[3504]or Bj(3504,55000,13647)else Xh=42414 end elseif Xh>53738 then Lc=Nj(8584);Xh=ki[-18516]or Bj(-18516,81981,29015);else if Nj(36279)then Xh=50540 else Xh=24265 end end else Mi[Pb]=vl()Xh=ki[22732]or Bj(22732,82637,21504)end elseif Xh<=61741 then if Xh>59793 then if Xh<=60525 then nk[Nj(9096)]=wb[nk[Nj(53502)]+Nj(3961)]Xh=ki[-25596]or Bj(-25596,76967,52336)elseif Xh>60814 then if Xh>61072 then fk=Gb(Sa(qg,10),Nj(28257));nk[52725]=wb[fk+Nj(14772)]Xh=ki[-23284]or Bj(-23284,76967,52336)else Pb=zk;Bb=me(Bb,zg(Gb(Pb,Nj(27790)),dl*Nj(5522)))if not(not sk(Pb,Nj(11636)))then Xh=ki[8810]or Bj(8810,77787,9328)break else Xh=ki[-27321]or Bj(-27321,26380,50351)break end Xh=ki[28968]or Bj(28968,54398,27421)end elseif Xh<=60667 then if Nj(49337)then Xh=ki[-13846]or Bj(-13846,19901,63542)else Xh=ki[-22393]or Bj(-22393,54956,30963)end else v=v+Mi;vl=v;if v~=v then Xh=ki[-24600]or Bj(-24600,50046,31888)else Xh=ki[-32243]or Bj(-32243,28016,54164)end end elseif Xh<=59010 then if Xh>58578 then if Nj(2374)then Xh=63871 else Xh=ki[-7196]or Bj(-7196,105971,13409)end else Pb=Xd(Nj(39063),Sg,dj);dj=dj+Nj(38554)Xh=ki[12352]or Bj(12352,98806,20258)end elseif Xh>59414 then if ke==9 then Xh=ki[-17876]or Bj(-17876,93196,6524)break elseif ke==Nj(48)then Xh=ki[18667]or Bj(18667,45743,24858)break elseif not(ke==Nj(25506))then Xh=ki[-26149]or Bj(-26149,35272,36882)break else Xh=ki[32750]or Bj(32750,20282,63454)break end Xh=ki[-31243]or Bj(-31243,88724,37443)elseif Xh<=59351 then Wc=if jf<Nj(6777)then jf else jf-Nj(10706)Xh=10597 break else if not(ci)then Xh=ki[22697]or Bj(22697,65997,28816)break else Xh=ki[31139]or Bj(31139,47096,36744)break end Xh=ki[7628]or Bj(7628,54281,44372)end elseif Xh<=63618 then if Xh<=62858 then if(nk>=0 and zk>Pb)or((nk<0 or nk~=nk)and zk<Pb)then Xh=ki[28451]or Bj(28451,67560,34935)else Xh=ki[-28616]or Bj(-28616,69337,41692)end elseif Xh<=63371 then Ga[Nj(-8562)]=Gb(Sa(Pb,Nj(42745)),255)Ga[Nj(46537)]=Gb(Sa(Pb,Nj(18446)),Nj(35324))Ga[Nj(38982)]=Gb(Sa(Pb,Nj(22699)),Nj(-3305))Xh=ki[7296]or Bj(7296,82731,40572)else Bb=ti;if eh~=eh then Xh=ki[-28454]or Bj(-28454,62623,4352)else Xh=ki[30668]or Bj(30668,109765,20553)end end elseif Xh<=64343 then if Xh<=63789 then if(v>=0 and ti>eh)or((v<0 or v~=v)and ti<eh)then Xh=ki[5516]or Bj(5516,40289,31054)else Xh=ki[-24190]or Bj(-24190,105573,5731)end else eh=Lc Xh=ki[18113]or Bj(18113,124066,847)end else v=P(Bb,Nj(-215))Xh=ki[22479]or Bj(22479,23187,62288)break end elseif Xh<=16886 then if Xh<=8717 then if Xh>4008 then if Xh>5595 then if Xh<=6908 then if Xh>6785 then wb=zk;if Pb~=Pb then Xh=ki[31448]or Bj(31448,88238,17329)else Xh=62257 end else ke=Pb;if nk~=nk then Xh=ki[-10958]or Bj(-10958,68495,6198)else Xh=ki[2299]or Bj(2299,60689,17845)end end elseif Xh<=7024 then yk=Xd(Nj(56212),Sg,dj);dj=dj+Nj(-3552)Xh=56886 elseif Xh>7038 then if Nj(56581)then Xh=ki[-16738]or Bj(-16738,100371,28608)else Xh=10749 end else if not(ke==Nj(41628))then Xh=ki[-10119]or Bj(-10119,81859,48404)break else Xh=ki[-32007]or Bj(-32007,88170,37759)break end Xh=ki[-1551]or Bj(-1551,126730,3805)end elseif Xh<=4235 then Pj=Xd(Yk('\234','\168'),Sg,dj);dj=dj+Nj(41615)Xh=9245 else zk=Nj(42839);Xh=10749;end elseif Xh<=2436 then if Xh>1251 then if Xh>1438 then if Nj(17400)then Xh=42053 else Xh=20856 end elseif Xh<=1359 then qg=Xd(Yk('1','s'),Sg,dj);dj=dj+Nj(22902)Xh=40226 else fk=P(Wc,Nj(30569))Xh=ki[19945]or Bj(19945,75666,39977)break end else fk,Wc=Gb(Sa(qg,Nj(52090)),Nj(43272)),Gb(Sa(qg,Nj(-4318)),Nj(3677));nk[52725]=wb[fk+Nj(43780)]nk[Nj(-2986)]=wb[Wc+Nj(47364)]Xh=ki[-15537]or Bj(-15537,108815,16600)end elseif Xh>3708 then jg=P(Qg,Nj(17677))Xh=29589 break else dl,zk,Lc=Qg,1,Nj(47807)Xh=24593 end elseif Xh<=12662 then if Xh>10374 then if Xh<=11240 then if Xh>10692 then if Xh>10768 then if ke==Nj(18492)then Xh=ki[27622]or Bj(27622,38796,59744)break elseif not(ke==Nj(29237))then Xh=ki[14795]or Bj(14795,49930,38082)break else Xh=ki[26144]or Bj(26144,61314,45717)break end Xh=ki[20078]or Bj(20078,80699,45804)else Pb=Xd(Nj(56272),Sg,dj);dj=dj+Nj(34384)Xh=ki[-6921]or Bj(-6921,66168,33421)end else Ga[Nj(38831)]=Wc Xh=ki[20507]or Bj(20507,77678,49721)end else Xh=ki[30576]or Bj(30576,74300,51527)break end elseif Xh<=9513 then if Xh<=9183 then if Xh<=8954 then ti=ti+v;Bb=ti;if ti~=ti then Xh=ki[-14549]or Bj(-14549,46863,21392)else Xh=ki[4946]or Bj(4946,83747,43307)end elseif Xh>9031 then if(wb>=0 and Pb>nk)or((wb<0 or wb~=wb)and Pb<nk)then Xh=9554 else Xh=ki[-30276]or Bj(-30276,62209,27080)end else Qg=Nj(-5466);ti,eh,v=Nj(54698),4,1 Xh=ki[4163]or Bj(4163,75532,51750)end elseif Xh<=9373 then Sj=P(Pj,Nj(29893))Xh=ki[17212]or Bj(17212,50933,63487)break else qg=nk[Nj(32002)];ci,Ga=Sa(qg,Nj(14353)),Gb(Sa(qg,Nj(-7622)),Nj(-4428));nk[Nj(10489)]=wb[Ga+Nj(-5589)]nk[Nj(36018)]=ci if not(ci==Nj(14557))then Xh=ki[-32562]or Bj(-32562,117351,2042)break else Xh=ki[-6537]or Bj(-6537,100583,28244)break end Xh=ki[-17610]or Bj(-17610,118541,11994)end elseif Xh>9857 then vl=Xd(Nj(22119),Sg,dj);dj=dj+Nj(33970)Xh=41251 elseif Xh>9691 then jf=fk;Xh=ki[-14668]or Bj(-14668,96040,16120);else return{[Nj(47384)]=Pj,[Nj(42718)]=ti,[Nj(30664)]=Nj(-818),[Nj(37240)]=La,[Nj(42632)]=yk,[Nj(19271)]=zk}end elseif Xh<=14796 then if Xh<=13590 then nk[Nj(-1929)]=wb[Ie(nk[Nj(49986)],Nj(38962),Nj(38683))+Nj(-7831)]nk[Nj(34972)]=Ie(nk[Nj(28853)],Nj(45792),Nj(25297))==Nj(-346)Xh=ki[-30210]or Bj(-30210,107824,17639)elseif Xh>13848 then qg=ke;dl=me(dl,zg(Gb(qg,Nj(13400)),wb*Nj(21275)))if not(not sk(qg,Nj(39150)))then Xh=ki[7349]or Bj(7349,82647,33371)break else Xh=ki[13004]or Bj(13004,114197,10164)break end Xh=ki[7179]or Bj(7179,68321,51777)else if(Mi>=0 and v>Bb)or((Mi<0 or Mi~=Mi)and v<Bb)then Xh=19015 else Xh=ki[9898]or Bj(9898,73226,45493)end end elseif Xh>15820 then if Xh<=16311 then Lc=Lc+zk;Pb=Lc;if Lc~=Lc then Xh=56213 else Xh=32442 end else vl=Mi;Qg=me(Qg,zg(Gb(vl,127),Bb*Nj(43297)))if not sk(vl,128)then Xh=ki[-2956]or Bj(-2956,68503,38122)break end Xh=ki[17611]or Bj(17611,24081,51687)end elseif Xh<=15467 then jf=fk;Xh=ki[3782]or Bj(3782,67814,58691);elseif Xh>15736 then if Nj(55143)then Xh=ki[22015]or Bj(22015,31358,46770)else Xh=15181 end else if Nj(26196)then Xh=ki[-6677]or Bj(-6677,19497,62033)else Xh=1349 end end elseif Xh>24961 then if Xh<=29011 then if Xh>27086 then if Xh<=28148 then if Xh>27706 then zk[ke]=Ei()Xh=ki[-32325]or Bj(-32325,71311,41629)elseif Xh<=27409 then nk[Nj(47824)]=wb[nk[Nj(179)]+Nj(-1670)]Xh=ki[19013]or Bj(19013,69768,51295)else if Nj(19280)then Xh=ki[1497]or Bj(1497,61382,38410)else Xh=9019 end end else Ck=P(La,Nj(-3386))Xh=ki[28317]or Bj(28317,80148,26764)break end else if not(ke==Nj(34112))then Xh=ki[21716]or Bj(21716,90741,32676)break else Xh=ki[20269]or Bj(20269,27130,65282)break end Xh=ki[-11289]or Bj(-11289,90908,31435)end elseif Xh>31193 then if Xh<=32619 then if(zk>=0 and Lc>dl)or((zk<0 or zk~=zk)and Lc<dl)then Xh=56213 else Xh=ki[-30860]or Bj(-30860,84135,4808)end else nk[Nj(44481)]=wb[nk[Nj(42974)]+Nj(-402)]Xh=ki[-7876]or Bj(-7876,77960,43103)end else Qg=jg;ti,eh=vc(Qg),Nj(46829);Mi,Bb,v=1,Qg,Nj(35123)Xh=ki[16341]or Bj(16341,64102,23343)end elseif Xh<=20859 then if Xh>18990 then if Xh<=19935 then if Xh<=19165 then v=Nj(-1792);Xh=ki[21894]or Bj(21894,24639,59802);else Bb=v;Mi=vc(Bb);vl=function()return(function(Aa)local Ge,Bc,Ea,Ma,Ug,V,Pd,d,nd,zl,Uh,K,Qk,pi,aa,Hf Qk,Bc={},function(Xk,Nf,x)Qk[Xk]=Vf(Nf,36196)-Vf(x,43296)return Qk[Xk]end Uh=Qk[-13321]or Bc(-13321,18507,63627)repeat while true do if Uh>33361 then if Uh<=49551 then if Uh<=41838 then if Uh>37939 then if Uh<=39762 then if Uh<=38812 then if Uh>38351 then d=d+V;K=d;if d~=d then Uh=Qk[32272]or Bc(32272,20667,47420)else Uh=Qk[-31568]or Bc(-31568,98934,6613)end else if Ma(-1640)then Uh=Qk[-13937]or Bc(-13937,79393,19883)else Uh=Qk[-29633]or Bc(-29633,105740,34189)end end elseif Uh>39284 then if Ma(6084)then Uh=9364 else Uh=36159 end elseif Uh<=39010 then zl=Ak(aa[Ma(41107)],Ma(12525),aa[Ma(49064)])Uh=Qk[9708]or Bc(9708,121428,10357)else aa=pi Uh=Qk[-21591]or Bc(-21591,8106,50970)break end else Ug=P(nd,Ma(16683))Uh=Qk[-23469]or Bc(-23469,19745,7824)break end elseif Uh>35255 then if Uh>35729 then pi=Xd(Ma(57688),Sg,dj);dj=dj+Ma(14984)Uh=39080 else aa=sc(Ma(3160))Uh=60449 break end else aa=Ma(19597);Uh=36159;end elseif Uh>45694 then if Uh<=48963 then Uh=Qk[7159]or Bc(7159,29660,61919)break else Ug=Pd;if V~=V then Uh=Qk[5183]or Bc(5183,126653,5888)else Uh=42446 end end elseif Uh<=42553 then if Uh>42254 then if Uh>42435 then if(K>=0 and Pd>V)or((K<0 or K~=K)and Pd<V)then Uh=Qk[-14457]or Bc(-14457,13156,45415)else Uh=Qk[-29840]or Bc(-29840,23557,33764)end else pi=P(d,Ma(60690))Uh=21078 break end else Pd=Pd+K;Ug=Pd;if Pd~=Pd then Uh=Qk[14534]or Bc(14534,106806,12217)else Uh=42446 end end elseif Uh<=42848 then nd=Ma(-705);Uh=58299;else if Ea==Ma(21683)then Uh=Qk[27935]or Bc(27935,31170,35402)break elseif Ea==Ma(-2166)then Uh=Qk[8374]or Bc(8374,104032,31060)break end Uh=Qk[-16565]or Bc(-16565,77716,25653)end elseif Uh<=57810 then if Uh>53071 then if Uh>54418 then if Uh>55010 then if Ma(27712)then Uh=Qk[-29343]or Bc(-29343,127856,14547)else Uh=2099 end elseif Uh<=54858 then return zl else Ge=nd;d=me(d,zg(Gb(Ge,Ma(41764)),(Ug-255)*Ma(54610)))if not(not sk(Ge,128))then Uh=Qk[18791]or Bc(18791,106832,11973)break else Uh=Qk[24665]or Bc(24665,112419,54605)break end Uh=Qk[18348]or Bc(18348,128082,32199)end else zl=Ma(13259)Uh=Qk[-4698]or Bc(-4698,124888,15809)end elseif Uh<=51772 then if Ma(-2036)then Uh=Qk[-17246]or Bc(-17246,4927,40490)else Uh=Qk[30711]or Bc(30711,15534,10672)end else aa=sc(P(pi,Ma(42762)))Uh=38941 break end elseif Uh<=61525 then if Uh>59374 then if Uh>60164 then zl=Ak(aa[Ma(42187)],Ma(55794),aa[Ma(1504)])Uh=Qk[21588]or Bc(21588,26032,48089)else if Ma(2103)then Uh=Qk[-8589]or Bc(-8589,109582,8301)else Uh=Qk[-4373]or Bc(-4373,22598,12286)end end else Ge=Xd(Yk('\213','\151'),Sg,dj);dj=dj+Ma(7764)Uh=12658 end elseif Uh<=63192 then if Uh<=61915 then d=0;V,Pd,K=(Ma(47157))+255,255,1 Uh=Qk[-29371]or Bc(-29371,117446,12245)else Ea=Hf;if Ea==Ma(-2681)then Uh=Qk[27635]or Bc(27635,22605,59354)break elseif not(Ea==Ma(6086))then Uh=Qk[-30618]or Bc(-30618,110153,53802)break else Uh=Qk[-28643]or Bc(-28643,31155,20467)break end Uh=54747 end else Pd=K Uh=Qk[-3273]or Bc(-3273,122383,17722)break end elseif Uh>17620 then if Uh>26178 then if Uh>29859 then if Ma(5158)then Uh=21078 else Uh=Qk[-14791]or Bc(-14791,101716,42574)end elseif Uh>28010 then Ma=function(qe)return Aa[qe-29535]end Hf=Ma(41210)Uh=25335 else aa=sc(Pd)Uh=Qk[-10709]or Bc(-10709,99933,46648)break end elseif Uh>22597 then if Uh>24752 then if Uh>25720 then if Ma(53017)then Uh=Qk[20999]or Bc(20999,43365,45644)else Uh=Qk[3157]or Bc(3157,38894,48119)end else Ea=Xd(Ma(49467),Sg,dj);dj=dj+Ma(60660)Uh=8240 end elseif Uh<=23746 then Uh=Qk[11638]or Bc(11638,76272,32753)break else if(V>=0 and d>Pd)or((V<0 or V~=V)and d<Pd)then Uh=Qk[-15800]or Bc(-15800,27148,45189)else Uh=Qk[-14601]or Bc(-14601,63767,49721)end end elseif Uh<=20083 then if Uh<=19562 then aa=sc(Ma(10716));Uh=2099;else pi=Ma(23884);d,Pd,V=Ma(43797),Ma(45716),1 Uh=Qk[16044]or Bc(16044,56641,35967)end else d=pi;if d==Ma(17550)then Uh=Qk[9086]or Bc(9086,31012,50044)break else Uh=Qk[-27952]or Bc(-27952,12491,8743)break end Uh=Qk[1007]or Bc(1007,121143,54602)end elseif Uh>8561 then if Uh>12258 then if Uh<=13877 then if Uh>12785 then Pd=Ma(57682);Uh=Qk[14456]or Bc(14456,15558,10568);elseif Uh>12630 then nd=P(Ge,Ma(10559))Uh=54970 break else V=d;K=Xd(Ma(59441)..V,Sg,dj);dj=dj+V Uh=64751 end else if Ma(33089)then Uh=62197 else Uh=25335 end end elseif Uh<=10157 then zl=aa Uh=Qk[-19575]or Bc(-19575,104280,60737)else K=d;if Pd~=Pd then Uh=Qk[21835]or Bc(21835,20722,42739)else Uh=Qk[26075]or Bc(26075,109966,27629)end end elseif Uh>5105 then Hf=P(Ea,Ma(9091))Uh=62197 break elseif Uh>2779 then aa=sc(Ma(34062));Uh=20036;elseif Uh<=2182 then if Uh>2035 then pi=nil;Uh=61634;else nd=Xd(Ma(6116),Sg,dj);dj=dj+Ma(10793)Uh=Qk[12079]or Bc(12079,26303,57475)end elseif Uh>2295 then Ug=Ma(61844);Uh=1971;else nd=Ug;pi=me(pi,zg(Gb(nd,Ma(36711)),K*Ma(57725)))if not sk(nd,Ma(19849))then Uh=Qk[-20870]or Bc(-20870,61664,35645)break end Uh=Qk[-3784]or Bc(-3784,13824,36113)end end until Uh==44537 end)({[31155]=1107276476,[-20444]=38,[-16276]=nil,[-23419]=Yk('\230','\164'),[-28031]=2,[26259]=1,[-23451]=true,[-27432]=true,[7176]=127,[12652]=1,[13227]=1107276476,[29906]=Yk('\152','\251'),[11675]=nil,[-7852]=5,[23482]=true,[17622]=4,[-31175]=true,[-23449]=4,[-21771]=1,[3554]=true,[31125]=1,[19529]=2,[-32216]=6,[-26375]='',[28153]=Yk('\204\148','\240'),[-1823]=true,[-18976]=38,[28147]=nil,[-14551]=8,[11572]=1,[19932]=Yk('#','a'),[-11985]=0,[-17010]=1,[-18819]=nil,[-31571]=true,[32309]=nil,[16181]=4,[28190]=7,[-9938]=nil,[12229]=127,[-24377]=true,[-12852]=38,[-5651]=0,[14262]=0,[-9686]=128,[-18742]=1,[-31701]=1,[-30240]=nil,[25075]=7,[4527]=nil})end Lc,zk,dl=Nj(34141),1,Bb Xh=ki[5816]or Bj(5816,82406,33390)end else La=Xd(Nj(35580),Sg,dj);dj=dj+Nj(880)Xh=ki[10258]or Bj(10258,93407,2215)end elseif Xh>17877 then if Nj(-3394)then Xh=36177 else Xh=ki[-7087]or Bj(-7087,58569,54418)end elseif Xh<=17496 then fk=Nj(56143);Xh=24265;else Mi=Mi+Lc;dl=Mi;if Mi~=Mi then Xh=ki[-29632]or Bj(-29632,75590,54733)else Xh=ki[43]or Bj(43,67077,48201)end end elseif Xh<=22906 then if Xh<=21649 then if Xh>21370 then if Xh<=21482 then fk=Gb(Sa(Pb,8),Nj(-608));Ga[Nj(44540)]=fk Wc=Nj(20535)Xh=15181 else vl=v;if Bb~=Bb then Xh=ki[-3382]or Bj(-3382,34798,47328)else Xh=13649 end end else if Nj(37398)then Xh=ki[14861]or Bj(14861,67962,44187)else Xh=9829 end end else if Nj(5008)then Xh=ki[-27152]or Bj(-27152,37457,44178)else Xh=ki[16835]or Bj(16835,83166,5563)end end elseif Xh<=23940 then if Xh>23541 then if Xh>23680 then Ga[Nj(19497)]=Gb(Sa(Pb,Nj(17927)),Nj(33967))fk=Gb(Sa(Pb,Nj(-4618)),Nj(15692))Ga[Nj(36069)]=fk Wc=Nj(11141)Xh=ki[-28165]or Bj(-28165,68439,6253)elseif Xh>23603 then nk[Nj(22137)]=Ie(nk[Nj(-6181)],Nj(7301),Nj(5355))Xh=ki[-15929]or Bj(-15929,124565,1602)else Bb=Nj(24751);vl,Lc,Mi=Nj(-4859),1,Nj(27411)Xh=ki[-29582]or Bj(-29582,95459,9980)end else nk,wb=ti[Pb],Mi;ke=nk[Nj(49520)];if not(ke==Nj(8522))then Xh=ki[-22333]or Bj(-22333,28895,43991)break else Xh=ki[18528]or Bj(18528,86193,2768)break end Xh=ki[9808]or Bj(9808,62214,60113)end elseif Xh>24429 then Pb=Lc;if dl~=dl then Xh=ki[-10758]or Bj(-10758,109490,12958)else Xh=32442 end else Wc=Xd(Nj(13751),Sg,dj);dj=dj+Nj(1593)Xh=ki[-18289]or Bj(-18289,10536,59348)end end until Xh==33157 end)({[-20176]=1023,[29649]=17271,[31290]=true,[19444]=7,[-3422]=nil,[26133]=27029,[-6453]=true,[32728]=true,[-27405]=1,[-25705]=true,[-31741]=3,[18779]=51334,[68]=1,[19121]=22287,[17775]=2,[17762]=1,[6811]=60058,[-23674]=24748,[22684]=22287,[-26200]=32768,[17032]=1,[-27872]=27029,[15129]=63784,[-21883]=12893,[10208]=false,[-25025]=27029,[1444]=1,[30845]=0,[10114]=255,[25484]=true,[-20843]=26946,[25667]=14362,[3558]=0,[-6176]=1107276476,[22976]=false,[18865]=38943,[8149]=27029,[32290]=nil,[11727]=Yk('\173','\239'),[12898]=38,[10531]=1,[24351]=9,[8439]=47487,[-7168]=nil,[32359]=Yk('/','m'),[11398]=nil,[11471]=255,[-12712]=nil,[11119]=11929,[-1424]=24710,[21939]=31,[3937]=127,[-15387]=65536,[21601]=38,[-2027]=38,[-8161]=65535,[-23805]=10,[-10559]=1,[6716]=-1390721151,[10288]=1,[-17076]=8388608,[-15194]=63784,[-19437]=nil,[-28471]=16,[-1154]=24,[-5361]=7,[-27158]=255,[2343]=true,[3032]=nil,[14701]=4,[-2578]=7,[-15269]=nil,[12165]=24710,[-1716]=26946,[-29319]=0,[23971]=26946,[-4356]=3564,[-13147]=16777216,[-18845]=true,[-21479]=true,[-12217]=128,[7984]=0,[-22973]=1,[15109]=0,[-1734]=Yk('\229','\167'),[-24461]=16777215,[-951]=1,[13545]=true,[19550]=7,[23531]=51312,[-26839]=28360,[-25645]=nil,[-32415]=3564,[-151]=63784,[18892]=8,[20687]=47487,[-25078]=nil,[-10453]=127,[7881]=0,[-10102]=Yk('\197\176\205','\249'),[-28281]=1023,[-9653]=0,[20034]=nil,[27093]=3564,[19419]=1023,[1653]=3,[17424]=26946,[-14757]=26946,[-27900]=0,[-10065]=27029,[4404]=1023,[-4582]=39822,[-31684]=1,[11270]=1,[-30476]=17271,[-30034]=27029,[23511]=1,[10188]=0,[-4573]=true,[-5926]=8,[-8698]=4,[-24846]=1,[26710]=0,[-24671]='',[23954]=1,[30756]=0,[32419]=Yk('r','0'),[-3318]=nil,[-24255]=1,[-9500]=30,[-9081]=1,[-28171]=0,[18986]=nil,[-16552]=0,[13423]=2,[-9131]=21312,[12216]=49222,[5000]=27029,[10649]=true,[-13014]=49435,[-13364]=26946,[-22761]=11929,[20281]=0,[10259]=4,[5384]=5,[-29442]=1,[-18449]=1107276476,[-27247]=true,[-29993]=3,[-31475]=20,[-2312]=-1390721151,[-6556]=0,[-2389]=14362,[-25782]=26946,[10117]=1,[-25523]=1,[-10629]=nil,[15210]=Yk('z\15r','F'),[898]=0,[31914]=0,[-5407]=16,[32757]=24748,[12426]=true,[22930]=255,[-24199]=1,[31765]=52725,[26995]=0,[6040]=38,[10109]=0,[-9296]=2,[14830]=24,[14263]=28360,[-14894]=22287,[-14688]=0,[-22260]=4,[15297]=128,[28237]=10,[-15331]=8,[22596]=38,[-18331]=7,[-28712]=4,[13387]=10276,[-18498]=16,[-24068]=1107276476,[5799]=1,[-26308]=true,[-4550]=26946,[20628]=26946,[-27239]=38,[14978]=17271,[19927]=1,[-19892]=1,[-21399]=3})end local uf=Ei()Ab[sj(-25468)][Ca]=uf return uf end)({[6079]=32371,[21037]=1,[-6923]=32371})end local ud=wl[Yk('.\213K/\213Q?','I\176?')]()local function Jj(Uf,Va)Uf=Ih(Uf)local ll=Uf local function yc(De,Lk)local function Kh(...)return(function(oc,...)local function Dg(Ja)return oc[Ja- -30398]end;return{[Dg(-15735)]={...},[Dg(-58027)]=ml(Dg(-37723),...)}end)({[-7325]=Yk('\226','\193'),[14663]=61143,[-27629]=47320},...)end local function th(xd,Bg,Yf)return(function(Sk)local fd,mi,if_,ri fd,mi={},function(uh,Ic,Jg)fd[uh]=Vf(Ic,40069)-Vf(Jg,5588)return fd[uh]end if_=fd[21531]or mi(21531,57124,9844)repeat while true do if if_>28157 then return elseif if_<=12827 then ri=function(Rc)return Sk[Rc+9923]end if Bg>Yf then if_=fd[-2483]or mi(-2483,109551,32420)break end if_=fd[24618]or mi(24618,101079,55241)else return xd[Bg],th(xd,Bg+ri(17281),Yf)end end until if_==29822 end)({[27204]=1})end local function qk(Ke,zd,Ue,ob)return(function(ye)local gd,nc,ai,Kb,Z,Ia,Ik,ka,Eb,Sc,lc,lg,pf,gl,Gj,G,qa,Pc,Bd,Hh,Tc,Qb,_k,kf Tc,_k={},function(Jk,Qh,Zh)Tc[Jk]=Vf(Qh,20328)-Vf(Zh,29115)return Tc[Jk]end kf=Tc[-18859]or _k(-18859,52138,26523)repeat while true do if kf<=32639 then if kf<=16130 then if kf<=7758 then if kf<=3827 then if kf>1894 then if kf<=2972 then if kf<=2554 then if kf>2333 then if kf<=2478 then ka=Fi(gd)==Kb(14484)kf=23028 break else if not(qa>Kb(-33550))then kf=Tc[-9003]or _k(-9003,38274,24335)break else kf=Tc[24136]or _k(24136,117208,64908)break end kf=Tc[-14593]or _k(-14593,41408,21148)end else if Kb(21490)then kf=42545 else kf=4966 end end else Hh-=Kb(1000)Ue[Hh]={[Kb(-4058)]=Kb(-15207),[Kb(-13460)]=P(lg[3564],Kb(29824)),[Kb(21618)]=P(lg[Kb(23416)],Kb(11670)),[Kb(20949)]=Kb(-18872)}kf=Tc[-23419]or _k(-23419,47383,23365)end elseif kf>3468 then if kf<=3674 then Bd=Bd..cc(P(Ud(Eb,(Ia-191)+Kb(-21723)),Ud(ai,(Ia-191)%#ai+Kb(1094))))kf=Tc[23201]or _k(23201,65665,59303)else if lg[Kb(17844)]==Kb(-15837)then kf=Tc[-24965]or _k(-24965,116571,53143)break else kf=Tc[-28764]or _k(-28764,90764,34164)break end kf=Tc[7924]or _k(7924,130117,38423)end elseif kf<=3304 then pf=G+ai-Kb(29264)kf=Tc[-10467]or _k(-10467,74594,35873)else Sc=ka-Kb(-7641)kf=Tc[9176]or _k(9176,67,16638)end elseif kf>855 then if kf>1283 then Ia={[Kb(29281)]=Ke[Qb[Kb(-34599)]],[Kb(-15681)]=2};Ia[Kb(21702)]=Ia gl[Z]=Ia kf=Tc[-18680]or _k(-18680,105629,38736)elseif kf<=995 then if qa>Kb(303)then kf=Tc[-29938]or _k(-29938,97291,38840)break else kf=Tc[6271]or _k(6271,65607,54964)break end kf=Tc[24453]or _k(24453,122194,46850)elseif kf<=1128 then nc[lg]=Kb(-102)Hh+=Kb(-33293)kf=Tc[-24107]or _k(-24107,69467,1289)else if(Z>=0 and ai>Bd)or((Z<0 or Z~=Z)and ai<Bd)then kf=Tc[-17448]or _k(-17448,109684,35990)else kf=Tc[-27389]or _k(-27389,74070,39028)end end elseif kf<=369 then if kf>77 then if kf<=135 then Ke[lg[Kb(14422)]]=gd[lg[Kb(-231)]]kf=Tc[17297]or _k(17297,2698,16542)else if not(qa>Kb(-17805))then kf=Tc[-17240]or _k(-17240,1840,16839)break else kf=Tc[-17622]or _k(-17622,34171,27262)break end kf=Tc[32516]or _k(32516,44099,26129)end else if not(qa>Kb(-18342))then kf=Tc[31126]or _k(31126,93019,23596)break else kf=Tc[14254]or _k(14254,42742,5707)break end kf=Tc[32142]or _k(32142,72266,63514)end elseif kf>564 then if kf>719 then if not(lg[Kb(10247)]==Kb(15362))then kf=Tc[18708]or _k(18708,75437,55539)break else kf=Tc[14610]or _k(14610,69321,3922)break end kf=Tc[21410]or _k(21410,68753,2499)else gl[Z]=Ik kf=Tc[-18373]or _k(-18373,121513,55564)end elseif kf>456 then G=Lk[lg[Kb(434)]+1];Ke[lg[Kb(-22745)]]=G[Kb(-17730)][G[Kb(-26271)]]kf=Tc[-11351]or _k(-11351,73086,63278)elseif kf<=420 then G=if ka<Kb(-13225)then ka else ka-Kb(19085)kf=Tc[7084]or _k(7084,94737,38446)break else ka,gd,Sc=G.__iter(ka)kf=Tc[10070]or _k(10070,92448,44595)end elseif kf>5795 then if kf<=6881 then if not(qa>Kb(-25270))then kf=Tc[-5700]or _k(-5700,90330,58959)break else kf=Tc[3971]or _k(3971,95915,34299)break end kf=Tc[-2071]or _k(-2071,118809,41547)else return th(Ke,G,G+Sc-Kb(-6427))end elseif kf>4622 then if kf>5052 then Hh+=Kb(5617)kf=Tc[8618]or _k(8618,38709,32103)elseif kf<=4881 then if not(qa>Kb(-9615))then kf=Tc[-8309]or _k(-8309,96187,57155)break else kf=Tc[-7117]or _k(-7117,44961,14899)break end kf=Tc[27647]or _k(27647,42031,28285)else ka=P(lg[Kb(-6941)],Kb(-8719));kf=Tc[-18629]or _k(-18629,116025,33207);end elseif kf>4066 then ad(ob[Kb(-16246)],Kb(-32577),ka,G,Ke)kf=Tc[-11640]or _k(-11640,93879,10213)else gl=gl+ai;Bd=gl;if gl~=gl then kf=Tc[19989]or _k(19989,15931,28487)else kf=14457 end end elseif kf<=11726 then if kf>9749 then if kf>10842 then if kf>11207 then if kf>11455 then ud[lg[Kb(25824)]]=Ke[lg[Kb(-34595)]]Hh+=Kb(25115)kf=Tc[14193]or _k(14193,47778,23538)else if qa>Kb(6879)then kf=Tc[-6543]or _k(-6543,114932,60522)break else kf=Tc[-26412]or _k(-26412,62268,10108)break end kf=Tc[-9958]or _k(-9958,87693,16351)end else G=ac(ka)if G~=nil and G.__iter~=nil then kf=Tc[22866]or _k(22866,49863,23761)break elseif pe(ka)==Yk('f\208p\221w','\18\177')then kf=Tc[-5407]or _k(-5407,44662,5124)break end kf=Tc[-12462]or _k(-12462,74220,54031)end elseif kf>10284 then Sc=(function(...)return(function(cl,...)local function qh(he)return cl[he+29207]end;for gh,Yg,va,f,ld,Tb,W,nl,ik,Jd,Ed,bl,gj,bi,bg,Kk,_f,Uc,Wf,le,Uj,hd,Ti,g,Id,yd,Oc,td,ie,ua,Jh,_c,oi,Lf,L,Hd,Sh,Hi,Ok,ef,tj,ba,Nd,E,sh,Nh,Wh,mj,Db,Lg,Ef,hj,fc,nf,Zi,Rj,Hc,mh,hk,Xa,sg,hh,rf,tk,h,Vc,y,we,oe,Mf,Wj,Ni,m,vi,Kg,Pf,Ui,jc,el,_j,cj,Td,re,Pe,al,c,Qc,mb,Qa,ug,H,ph,Fd,Fb,ae,Ag,vd,Gc,zh,D,na,qd,gi,Na,wa,Gk,wf,Di,Gf,F,Wa,Y,tf,Cb,ck,Yd,Zf,hf,Qe,Tj,Ra,rj,Yh,e,_i,Qi,Rg,hc,Aj,ub,S,ii,Ka,Oe,wi,ag,Sb,Ki,b,q,Me,df,ol,Og,Je,de,dh,u,kg,vf,Pg,Ri,Jf,jh,ne,rh,qb,Oh,rg,uk,Ua,Oj,We,gb,tl,cf,Ze,Cg,Qj,Bk,Zb,Fa,bj,og,la,ei,kb,Nk,dc,uj in...do U({gh,Yg,va,f,ld,Tb,W,nl,ik,Jd,Ed,bl,gj,bi,bg,Kk,_f,Uc,Wf,le,Uj,hd,Ti,g,Id,yd,Oc,td,ie,ua,Jh,_c,oi,Lf,L,Hd,Sh,Hi,Ok,ef,tj,ba,Nd,E,sh,Nh,Wh,mj,Db,Lg,Ef,hj,fc,nf,Zi,Rj,Hc,mh,hk,Xa,sg,hh,rf,tk,h,Vc,y,we,oe,Mf,Wj,Ni,m,vi,Kg,Pf,Ui,jc,el,_j,cj,Td,re,Pe,al,c,Qc,mb,Qa,ug,H,ph,Fd,Fb,ae,Ag,vd,Gc,zh,D,na,qd,gi,Na,wa,Gk,wf,Di,Gf,F,Wa,Y,tf,Cb,ck,Yd,Zf,hf,Qe,Tj,Ra,rj,Yh,e,_i,Qi,Rg,hc,Aj,ub,S,ii,Ka,Oe,wi,ag,Sb,Ki,b,q,Me,df,ol,Og,Je,de,dh,u,kg,vf,Pg,Ri,Jf,jh,ne,rh,qb,Oh,rg,uk,Ua,Oj,We,gb,tl,cf,Ze,Cg,Qj,Bk,Zb,Fa,bj,og,la,ei,kb,Nk,dc,uj})end;U(qh(-53664))end)({[-24457]=-2},...)end);nc[gd]=dg(Sc)kf=Tc[-26302]or _k(-26302,57281,18)else Hh-=1 Ue[Hh]={[Kb(15004)]=228,[Kb(16766)]=P(lg[Kb(28781)],Kb(-13575)),[Kb(15313)]=P(lg[Kb(-27441)],94),[Kb(-5162)]=Kb(-13816)}kf=Tc[-11500]or _k(-11500,37256,25316)end elseif kf<=8776 then Hh+=lg[Kb(-8385)]kf=Tc[-23980]or _k(-23980,88375,15205)elseif kf>9276 then if kf>9556 then Hh+=lg[Kb(-18327)]kf=Tc[-15406]or _k(-15406,70746,65034)else Ke[lg[Kb(-32067)]]=#Ke[lg[22287]]kf=Tc[18913]or _k(18913,47848,22596)end else G,ka=lg[Kb(-21460)],lg[Kb(-27024)]-1;if not(ka==Kb(-5794))then kf=Tc[29318]or _k(29318,8458,11333)break else kf=Tc[-23838]or _k(-23838,37190,8838)break end kf=Tc[17727]or _k(17727,57051,61684)end elseif kf<=13678 then if kf<=12695 then if kf<=12140 then Ke[G+Kb(-997)]=Ke[G+Kb(17727)]Hh+=lg[Kb(8287)]kf=Tc[416]or _k(416,66988,3832)elseif kf<=12332 then Bd=gl;if Eb~=Eb then kf=Tc[21321]or _k(21321,89171,45407)else kf=14457 end else G=ac(ka)if G~=nil and G.__iter~=nil then kf=Tc[24779]or _k(24779,40127,41902)break elseif pe(ka)==Yk('nexh\127','\26\4')then kf=Tc[-12562]or _k(-12562,99776,48220)break end kf=Tc[-26741]or _k(-26741,41285,54998)end elseif kf>13126 then lc=Bd;if Z~=Z then kf=Tc[22124]or _k(22124,42181,15022)else kf=32260 end elseif kf>12829 then if kf<=12900 then ka=gl kf=36853 break else G=lg[26946];Ke[lg[63784]][G]=Ke[lg[22287]]Hh+=Kb(7217)kf=Tc[-24660]or _k(-24660,86293,9031)end else if qa>Kb(21017)then kf=Tc[29845]or _k(29845,78276,54883)break else kf=Tc[-18297]or _k(-18297,130416,36420)break end kf=Tc[25471]or _k(25471,122423,46181)end elseif kf<=14626 then if kf<=14174 then gd=G;kf=Tc[12325]or _k(12325,12145,10033);elseif kf>14441 then if kf>14535 then Ke[lg[Kb(-17466)]]=(function()return(function(Tf)local Pa,Q,Ae,wh,ij,r,ak,wc,af,Rd,bb,ql,Af,ng bb,wh={},function(Vi,k,Kj)bb[Vi]=Vf(k,47600)-Vf(Kj,18893)return bb[Vi]end r=bb[8516]or wh(8516,17191,35384)repeat while true do if r>33736 then if r<=51644 then if r<=40856 then if r>39010 then ng=ng+ak;wc=ng;if ng~=ng then r=bb[-25690]or wh(-25690,103901,62413)else r=bb[2593]or wh(2593,58294,32323)end else ak,ng,Q=1,Rd(13496),#Af[Rd(-5367)]r=bb[-12184]or wh(-12184,2356,60089)end else Pa,ql,Ae=Ab[32371];if pe(Pa)~='function'then r=bb[19222]or wh(19222,8682,13225)break end;r=bb[-2208]or wh(-2208,28962,8040);end else ij,Af=Pa(ql,Ae);Ae=ij;if Ae==nil then r=43059 else r=7364 end end elseif r>18158 then if r<=29077 then if r<=26615 then Af[Rd(12597)][wc]={[Rd(-22550)]=Rd(18944)}r=bb[-8763]or wh(-8763,1435,27497)else Pa,ql,Ae=af.__iter(Pa)r=bb[-24866]or wh(-24866,102281,28723)end elseif r>31354 then af=ac(Pa)if af~=nil and af.__iter~=nil then r=bb[-28572]or wh(-28572,105206,64183)break elseif pe(Pa)==Yk('\154\5\140\b\139','\238d')then r=bb[-18428]or wh(-18428,53204,32165)break end r=bb[25193]or wh(25193,74189,53775)else ij,Af=Pa(ql,Ae);Ae=ij;if Ae==nil then r=bb[16813]or wh(16813,15812,10703)else r=bb[13794]or wh(13794,25664,3967)end end elseif r>9832 then if r<=15439 then Rd=function(ig)return Tf[ig+13748]end Pa,ql,Ae=Ke if pe(Pa)~='function'then r=bb[21178]or wh(21178,598,28946)break end r=bb[-24395]or wh(-24395,91614,38526)elseif r<=16269 then Pa,ql,Ae=af.__iter(Pa)r=bb[-12526]or wh(-12526,110021,60357)else Pa,ql,Ae=A(Pa)r=bb[13717]or wh(13717,121375,11961)end elseif r<=6051 then if r>3122 then wc=ng;if Q~=Q then r=bb[-11704]or wh(-11704,117092,47018)else r=bb[-14348]or wh(-14348,16275,10854)end else Pa,ql,Ae=A(Pa)r=bb[13285]or wh(13285,50218,16992)end elseif r>8315 then if r>9077 then r=bb[-12803]or wh(-12803,126055,15499);break;else if(ak>=0 and ng>Q)or((ak<0 or ak~=ak)and ng<Q)then r=bb[29223]or wh(29223,109041,54297)else r=24675 end end elseif r>7485 then af=ac(Pa)if af~=nil and af.__iter~=nil then r=bb[13026]or wh(13026,111089,33646)break elseif pe(Pa)==Yk('\177\214\167\219\160','\197\183')then r=bb[-32543]or wh(-32543,31772,62234)break end r=bb[-2487]or wh(-2487,117121,46985)else Ke[ij]=Rd(-36914)r=bb[11253]or wh(11253,125099,7469)end end until r==57425 end)({[-8802]=12893,[-23166]=nil,[27244]=1,[26345]=38943,[8381]=38943,[32692]=160})end)kf=Tc[-27882]or _k(-27882,66065,61507)else if(ai>=0 and gl>Eb)or((ai<0 or ai~=ai)and gl<Eb)then kf=Tc[-13558]or _k(-13558,46581,55805)else kf=62437 end end else if Kb(-19117)then kf=22857 else kf=64628 end end elseif kf>15127 then if kf<=15341 then Sc=Ke[G]ai,gl,Eb=1,G+Kb(11044),ka kf=Tc[12403]or _k(12403,54867,6337)elseif kf>15430 then Sc=pf-G+1 kf=Tc[-13061]or _k(-13061,38974,51403)elseif kf>15373 then Hh+=Kb(-3109)kf=Tc[813]or _k(813,84649,19451)else lg[Kb(10185)]=Kb(-29877)Hh+=Kb(-13932)kf=Tc[-18422]or _k(-18422,98298,5290)end else if Kb(-2304)then kf=36853 else kf=37557 end end elseif kf>24221 then if kf>28452 then if kf>30571 then if kf<=31463 then if kf<=31046 then if kf>30789 then Hh-=Kb(-5934)Ue[Hh]={[Kb(27544)]=Kb(9339),[Kb(28938)]=P(lg[Kb(-14784)],Kb(15218)),[Kb(-9015)]=P(lg[Kb(-13150)],Kb(-20437)),[Kb(-15342)]=Kb(-16018)}kf=Tc[4637]or _k(4637,71869,65007)else if Kb(8554)then kf=Tc[21822]or _k(21822,51793,23294)else kf=Tc[23502]or _k(23502,5589,21677)end end else if Eb==Kb(-30901)then kf=Tc[-25916]or _k(-25916,50002,63074)break else kf=Tc[-7669]or _k(-7669,34256,10405)break end kf=Tc[-22157]or _k(-22157,43505,27299)end elseif kf>31890 then if(Qb>=0 and Bd>Z)or((Qb<0 or Qb~=Qb)and Bd<Z)then kf=Tc[8073]or _k(8073,72093,51174)else kf=Tc[-29441]or _k(-29441,130726,35167)end elseif kf<=31612 then if kf<=31551 then Ia=Qb[Kb(-9789)];Ik=Gj[Ia];if not(Ik==Kb(66))then kf=Tc[26429]or _k(26429,52682,3677)break else kf=Tc[17368]or _k(17368,53741,14086)break end kf=700 else ka,gd,Sc=A(ka)kf=Tc[-22896]or _k(-22896,86828,8655)end else Hh+=Kb(9716)kf=Tc[24434]or _k(24434,119395,41009)end elseif kf>29624 then if kf>30039 then if kf<=30325 then Pc=Kb(10306)Hh+=1 if not(qa>127)then kf=Tc[-12714]or _k(-12714,85148,59177)break else kf=Tc[3316]or _k(3316,62572,21378)break end kf=Tc[13706]or _k(13706,117896,51684)else lk(Eb)nc[gl]=Kb(29822)kf=Tc[18725]or _k(18725,35555,11355)end else Qb=Ue[Hh];Hh+=Kb(-27538)lc=Qb[Kb(-32342)]if not(lc==Kb(8581))then kf=Tc[-32360]or _k(-32360,70038,49554)break else kf=Tc[15954]or _k(15954,47620,40710)break end kf=Tc[-24147]or _k(-24147,72088,6237)end elseif kf<=28982 then if kf>28902 then if Kb(-15576)then kf=Tc[-7810]or _k(-7810,78033,50006)else kf=Tc[-25090]or _k(-25090,44967,61306)end else gl,Eb=aj(nc[lg],gd,Ke[G+Kb(-23705)],Ke[G+Kb(-20632)]);if not(not gl)then kf=Tc[-7164]or _k(-7164,93662,54862)break else kf=Tc[-25280]or _k(-25280,117188,52373)break end kf=31425 end else ad(Eb,1,ka,G+Kb(11860),Ke)Ke[G+Kb(7945)]=Ke[G+Kb(-9965)]Hh+=lg[Kb(-21535)]kf=Tc[15930]or _k(15930,125885,43247)end elseif kf<=26483 then if kf>25321 then if kf>25851 then if not(qa>Kb(-736))then kf=Tc[5376]or _k(5376,90026,54539)break else kf=Tc[9802]or _k(9802,37501,1181)break end kf=Tc[-1898]or _k(-1898,94078,9518)elseif kf<=25708 then gd[ai]=Lk[Bd[Kb(-34198)]+Kb(13250)]kf=Tc[-16013]or _k(-16013,47612,29317)else ka=P(lg[Kb(-16056)],18987);kf=390;end else ka,gd,Sc=G.__iter(ka)kf=Tc[-2628]or _k(-2628,86565,8390)end elseif kf>27406 then if kf>27870 then if kf<=28131 then if kf<=28002 then if kf>27971 then if qa>Kb(13016)then kf=Tc[7407]or _k(7407,86078,12013)break else kf=Tc[-7184]or _k(-7184,43395,24232)break end kf=Tc[-5112]or _k(-5112,120887,47717)elseif kf<=27955 then Z=Eb;if ai~=ai then kf=Tc[8297]or _k(8297,84865,41732)else kf=45783 end else Hh+=lg[Kb(-5391)]kf=Tc[-19285]or _k(-19285,129801,39259)end else gl={gd(Ke[G+Kb(10583)],Ke[G+Kb(-28275)])};ad(gl,Kb(12813),ka,G+Kb(-30966),Ke)if not(Ke[G+Kb(-2335)]~=Kb(-11722))then kf=Tc[-8213]or _k(-8213,87521,43690)break else kf=Tc[-1153]or _k(-1153,86485,33222)break end kf=Tc[20159]or _k(20159,76871,58901)end elseif kf>28271 then if kf<=28297 then ad(Eb[Kb(-13717)],Kb(-32485),ai,G,Ke)kf=Tc[-19559]or _k(-19559,97252,6320)else Kb=function(Df)return ye[Df+1839]end pf,Hh,Gj,nc,Pc=Kb(17186),Kb(-15711),zb({},{[Kb(27339)]=Kb(-27314)}),zb({},{[Yk(']\138\222m\177\214','\2\213\179')]=Kb(-20668)}),Kb(10841)kf=Tc[32719]or _k(32719,125369,43755)end else if lg[Kb(9150)]==Kb(-3866)then kf=Tc[-15330]or _k(-15330,121075,42787)break elseif lg[63784]==Kb(-13017)then kf=Tc[-27314]or _k(-27314,43243,3609)break elseif not(lg[63784]==Kb(-26007))then kf=Tc[23777]or _k(23777,85500,4446)break else kf=Tc[-19352]or _k(-19352,86216,4939)break end kf=Tc[26906]or _k(26906,97721,5867)end elseif kf>27542 then if qa>Kb(373)then kf=Tc[-18888]or _k(-18888,43485,25495)break else kf=Tc[-27818]or _k(-27818,31999,20832)break end kf=Tc[362]or _k(362,80388,55376)else if not(qa>229)then kf=Tc[-3754]or _k(-3754,69244,52351)break else kf=Tc[20898]or _k(20898,7223,20858)break end kf=Tc[28928]or _k(28928,82092,13816)end elseif kf>26593 then if kf>26652 then if not(not Pc)then kf=Tc[-19766]or _k(-19766,77735,39737)break else kf=Tc[-6215]or _k(-6215,83647,1051)break end kf=Tc[-17184]or _k(-17184,65939,43285)elseif kf>26615 then Bd=Ue[Hh];Hh+=Kb(-32149)Z=Bd[Kb(-17267)]if Z==Kb(10908)then kf=Tc[9508]or _k(9508,129297,41673)break elseif not(Z==2)then kf=Tc[-25470]or _k(-25470,109073,33688)break else kf=Tc[10762]or _k(10762,90142,47798)break end kf=Tc[-27169]or _k(-27169,130130,52831)else Ke[lg[Kb(498)]]=lg[Kb(26119)]kf=Tc[22296]or _k(22296,101892,33872)end elseif kf>26541 then Hh-=Kb(22932)Ue[Hh]={[Kb(21457)]=Kb(204),[Kb(1607)]=P(lg[Kb(-2515)],Kb(-28247)),[22287]=P(lg[22287],Kb(13095)),[Kb(9395)]=Kb(-21404)}kf=Tc[-3833]or _k(-3833,125047,43557)elseif kf<=26514 then if not(Eb[Kb(-29247)]>=lg[Kb(-1691)])then kf=Tc[-12406]or _k(-12406,124130,44545)break else kf=Tc[-16656]or _k(-16656,41871,5981)break end kf=Tc[-10862]or _k(-10862,114707,45584)else gl,Eb=ka(gd,Sc);Sc=gl;if Sc==nil then kf=Tc[-32205]or _k(-32205,115358,47920)else kf=Tc[17747]or _k(17747,96144,46049)end end elseif kf>19867 then if kf<=22125 then if kf>21343 then if kf>21738 then if kf>21986 then ka=G;gd=zd[ka+Kb(1748)];Sc=gd[Kb(-27297)];gl=vc(Sc);Ke[P(lg[Kb(25528)],Kb(13041))]=yc(gd,gl)ai,Eb,Bd=Sc,Kb(12549),1 kf=22582 else if not(qa>Kb(7536))then kf=Tc[-14256]or _k(-14256,71757,46025)break else kf=Tc[-14627]or _k(-14627,95947,33008)break end kf=Tc[-2900]or _k(-2900,119231,41709)end else Eb[Kb(-27423)]=Eb[1][Eb[Kb(24472)]]Eb[Kb(-34181)]=Eb Eb[Kb(19057)]=Kb(4828)Gj[gl]=Kb(-25286)kf=Tc[11927]or _k(11927,60010,12281)end elseif kf<=21003 then if kf<=20754 then if kf<=20712 then gd=Ue[Hh+lg[Kb(-6827)]];if nc[gd]==Kb(-9918)then kf=Tc[6981]or _k(6981,88177,40945)break end kf=Tc[31167]or _k(31167,25663,32236)else gl[Z]=Lk[Qb[22287]+Kb(-20612)]kf=Tc[-11256]or _k(-11256,107664,36693)end else Hh-=Kb(-30818)Ue[Hh]={[Kb(-8188)]=Kb(-16658),[Kb(-8413)]=P(lg[Kb(-24015)],87),[Kb(-4548)]=P(lg[Kb(-32260)],143),[Kb(-16004)]=Kb(19422)}kf=Tc[-6275]or _k(-6275,118408,51172)end elseif kf>21194 then Bd=Bd+Qb;lc=Bd;if Bd~=Bd then kf=Tc[-23874]or _k(-23874,115406,40117)else kf=Tc[-18711]or _k(-18711,71689,43238)end else Ke[lg[3564]]=Sc kf=Tc[-28644]or _k(-28644,32901,30167)end elseif kf<=23012 then if kf<=22664 then if kf<=22527 then Ik={[3]=Ia,[Kb(16475)]=Ke}Gj[Ia]=Ik kf=Tc[2588]or _k(2588,26083,22132)else Z=Eb;if ai~=ai then kf=Tc[-24155]or _k(-24155,95439,413)else kf=58050 end end elseif kf<=22811 then if kf<=22782 then ka[Kb(-21372)]=Sc gl=Kb(-14925)kf=57814 else if Kb(-25041)then kf=56694 else kf=57814 end end else if Sc then kf=Tc[7347]or _k(7347,77318,33397)break else kf=Tc[-6696]or _k(-6696,58418,19260)break end kf=Tc[21511]or _k(21511,86802,8514)end elseif kf<=23289 then if kf<=23053 then if kf>23026 then if not(not ka)then kf=Tc[-28968]or _k(-28968,47677,42990)break else kf=Tc[16287]or _k(16287,53560,15565)break end kf=Tc[17547]or _k(17547,38521,52138)else Sc=Kb(3629);kf=Tc[1828]or _k(1828,128952,47204);end else G=Lk[lg[Kb(-33664)]+Kb(-29448)];G[Kb(24266)][G[Kb(-13576)]]=Ke[lg[Kb(1793)]]kf=Tc[14373]or _k(14373,48069,22679)end else ai=ai+Z;Qb=ai;if ai~=ai then kf=Tc[-18906]or _k(-18906,71733,213)else kf=Tc[12987]or _k(12987,14589,669)end end elseif kf>17995 then if kf>18960 then if kf>19471 then if kf>19785 then G,ka=lg[24710],lg[Kb(-29242)];gd=ud[ka]or Ab[Kb(-1495)][ka];if not(G==Kb(22781))then kf=Tc[-3162]or _k(-3162,118057,39293)break else kf=Tc[-431]or _k(-431,96139,34066)break end kf=5309 else ai=ai..cc(P(Ud(gl,lc+Kb(6381)),Ud(Eb,lc%#Eb+Kb(-2969))))kf=Tc[21289]or _k(21289,82353,46935)end else Hh+=lg[Kb(27035)]kf=Tc[3677]or _k(3677,45340,17224)end elseif kf>18525 then G=zd[lg[Kb(-2557)]+Kb(-34210)];ka=G[Kb(-17640)];gd=vc(ka);Ke[lg[3564]]=yc(G,gd)gl,Eb,Sc=ka,1,Kb(-14092)kf=52326 elseif kf>18316 then if kf<=18466 then Bd=Bd+Qb;lc=Bd;if Bd~=Bd then kf=Tc[28921]or _k(28921,102951,44809)else kf=57091 end else ka,gd,Sc=Gj;if pe(ka)~='function'then kf=Tc[-23507]or _k(-23507,43193,52439)break end;kf=Tc[19957]or _k(19957,99602,36625);end else gl,Eb=ka(gd,Sc);Sc=gl;if Sc==nil then kf=Tc[-17765]or _k(-17765,74310,63156)else kf=Tc[-18836]or _k(-18836,14012,21599)end end elseif kf>17017 then if kf>17604 then if kf<=17823 then if kf>17807 then Hh+=Kb(9747)kf=Tc[-5882]or _k(-5882,71581,64719)else if qa>Kb(27132)then kf=Tc[-30994]or _k(-30994,43680,18030)break else kf=Tc[20844]or _k(20844,41977,59146)break end kf=Tc[-9668]or _k(-9668,95574,7942)end else G=ac(ka)if G~=nil and G.__iter~=nil then kf=Tc[26837]or _k(26837,96267,3493)break elseif pe(ka)==Yk('\188d\170i\173','\200\5')then kf=Tc[11207]or _k(11207,44322,32108)break end kf=Tc[27930]or _k(27930,43003,61779)end elseif kf<=17411 then if not(qa>Kb(-1856))then kf=Tc[-31378]or _k(-31378,42760,45810)break else kf=Tc[24828]or _k(24828,116452,45310)break end kf=Tc[-17199]or _k(-17199,69097,1723)else Ke[lg[Kb(16877)]]=gd kf=Tc[-15415]or _k(-15415,48260,44692)end elseif kf<=16546 then if kf>16217 then if kf>16250 then if not(qa>Kb(-17982))then kf=Tc[4550]or _k(4550,93242,7854)break else kf=Tc[-9563]or _k(-9563,5374,15730)break end kf=Tc[9562]or _k(9562,66151,61493)else Hh+=Kb(8049)kf=Tc[-10645]or _k(-10645,97010,7074)end elseif kf<=16183 then Qb=ai;if Bd~=Bd then kf=Tc[3874]or _k(3874,100458,37032)else kf=Tc[-24014]or _k(-24014,7082,8680)end else if not(qa>Kb(-34466))then kf=Tc[-6740]or _k(-6740,9635,18581)break else kf=Tc[9687]or _k(9687,97127,521)break end kf=Tc[-19890]or _k(-19890,94930,898)end elseif kf>16907 then Sc,gl,Eb=ka[Kb(2772)],lg[Kb(13424)],Kb(23650);ai,Bd,Z=Kb(3255),#Sc-1,1 kf=16182 else Sc=Kb(-7432);kf=61612;end elseif kf<=49238 then if kf>41175 then if kf<=45271 then if kf<=43281 then if kf>42215 then if kf<=42792 then ka=G;Ke[P(lg[Kb(2867)],Kb(9255))]=ka kf=Tc[14889]or _k(14889,33430,29638)elseif kf>43032 then if qa>Kb(-16615)then kf=Tc[-11347]or _k(-11347,6500,32170)break else kf=Tc[11980]or _k(11980,44201,15811)break end kf=Tc[13887]or _k(13887,37970,32258)else Ke[lg[Kb(4005)]]=Ke[lg[Kb(-25198)]]+lg[Kb(5905)]kf=Tc[17815]or _k(17815,93866,10234)end else if lg[Kb(-19623)]==Kb(-18266)then kf=Tc[22820]or _k(22820,89933,59102)break else kf=Tc[-17276]or _k(-17276,104730,44040)break end kf=Tc[-19423]or _k(-19423,86775,9125)end elseif kf<=44629 then if kf<=44354 then if kf<=44141 then Ke[lg[3564]]=Ke[lg[22287]]kf=Tc[13704]or _k(13704,74621,53551)else if(lc>=0 and Z>Qb)or((lc<0 or lc~=lc)and Z<Qb)then kf=Tc[2006]or _k(2006,46757,7075)else kf=Tc[16310]or _k(16310,5419,15840)end end elseif kf<=44576 then if qa>Kb(5248)then kf=Tc[29731]or _k(29731,82611,13281)break else kf=Tc[-2498]or _k(-2498,99757,44224)break end kf=Tc[-10607]or _k(-10607,129980,39144)else if qa>Kb(-25808)then kf=Tc[4165]or _k(4165,117823,39757)break else kf=Tc[-2586]or _k(-2586,47006,40595)break end kf=Tc[-19934]or _k(-19934,115649,45203)end elseif kf>44964 then if qa>Kb(28096)then kf=Tc[-6973]or _k(-6973,45595,13253)break else kf=Tc[-20482]or _k(-20482,77983,61682)break end kf=Tc[27520]or _k(27520,129966,39166)else if not(lc==Kb(-11919))then kf=Tc[-25835]or _k(-25835,115742,40032)break else kf=Tc[21006]or _k(21006,52988,30671)break end kf=Tc[-27333]or _k(-27333,88971,22114)end elseif kf>47372 then if kf>48358 then if kf>48860 then if not(qa>Kb(-2812))then kf=Tc[-5213]or _k(-5213,48060,32967)break else kf=Tc[3131]or _k(3131,61618,57917)break end kf=Tc[-24134]or _k(-24134,117156,51952)elseif kf<=48709 then ai=gd-Kb(20641)kf=Tc[16779]or _k(16779,46905,63578)elseif kf>48780 then Hh+=lg[24748]kf=Tc[26803]or _k(26803,126439,42677)else if not(lg[Kb(15236)]==Kb(9724))then kf=Tc[-14763]or _k(-14763,86823,35027)break else kf=Tc[2444]or _k(2444,32488,30797)break end kf=Tc[9112]or _k(9112,76416,60380)end elseif kf>47934 then if kf<=48122 then if kf>48007 then Hh+=lg[Kb(7350)]kf=Tc[272]or _k(272,87209,8699)else ka,gd,Sc=G.__iter(ka)kf=Tc[-6540]or _k(-6540,35714,11396)end else Hh-=Kb(13230)Ue[Hh]={[Kb(-29678)]=Kb(20286),[Kb(14360)]=P(lg[Kb(-29250)],Kb(-31805)),[Kb(23554)]=P(lg[Kb(30506)],Kb(20983)),[Kb(-5671)]=Kb(-19584)}kf=Tc[-26158]or _k(-26158,72649,63643)end elseif kf>47713 then if qa>Kb(12147)then kf=Tc[-32622]or _k(-32622,60286,4593)break else kf=Tc[-24537]or _k(-24537,116561,56269)break end kf=Tc[25204]or _k(25204,97123,6449)else Z=Z+lc;Ia=Z;if Z~=Z then kf=Tc[-28714]or _k(-28714,46552,6976)else kf=44197 end end elseif kf<=46465 then if kf>45899 then if kf<=46173 then if not(lg[63784]==Kb(12992))then kf=Tc[-16535]or _k(-16535,40960,40254)break else kf=Tc[-20188]or _k(-20188,128929,48164)break end kf=Tc[-13132]or _k(-13132,128224,33212)else lc=Bd;if Z~=Z then kf=Tc[-510]or _k(-510,92347,22669)else kf=Tc[25126]or _k(25126,77564,62250)end end elseif kf>45688 then if(Bd>=0 and Eb>ai)or((Bd<0 or Bd~=Bd)and Eb<ai)then kf=Tc[32187]or _k(32187,56204,4865)else kf=Tc[-19672]or _k(-19672,42729,22996)end else Ke[lg[Kb(-29928)]]=vc(lg[27029])Hh+=Kb(-15627)kf=Tc[-11291]or _k(-11291,119897,48651)end elseif kf<=47201 then if kf>47124 then Ke[lg[Kb(968)]]=Kb(4123)kf=Tc[31855]or _k(31855,130767,38813)else if not(qa>Kb(-22206))then kf=Tc[-9226]or _k(-9226,23461,25974)break else kf=Tc[3056]or _k(3056,87219,44313)break end kf=Tc[24272]or _k(24272,85845,17671)end else ai=ai..cc(P(Ud(gl,lc+Kb(2295)),Ud(Eb,lc%#Eb+Kb(-34029))))kf=Tc[-16719]or _k(-16719,66396,35148)end elseif kf>37155 then if kf<=39252 then if kf>38254 then if kf>38922 then if kf<=39062 then if qa>Kb(-5869)then kf=Tc[-18194]or _k(-18194,125184,36835)break else kf=Tc[12040]or _k(12040,36115,6634)break end kf=Tc[-12272]or _k(-12272,88466,15042)else if not(qa>Kb(3169))then kf=Tc[-24580]or _k(-24580,12879,3383)break else kf=Tc[-23289]or _k(-23289,69193,13406)break end kf=Tc[-29588]or _k(-29588,69272,2004)end elseif kf>38787 then if qa>Kb(-23872)then kf=Tc[-30719]or _k(-30719,36127,9357)break else kf=Tc[-10710]or _k(-10710,77135,33360)break end kf=Tc[-25077]or _k(-25077,71936,64348)else if not(qa>Kb(-27843))then kf=Tc[-8640]or _k(-8640,46529,24211)break else kf=Tc[31967]or _k(31967,82164,19372)break end kf=Tc[-28040]or _k(-28040,78539,50073)end elseif kf<=37801 then if kf<=37475 then G,ka=lg[Kb(19679)],lg[Kb(17181)];pf=G+Kb(22836)gd,Sc=Ke[G],Kb(-30178)kf=Tc[-7590]or _k(-7590,130348,50283)else gd,Sc,gl=G[Kb(-9327)],lg[Kb(-22494)],Kb(9253);ai,Eb,Bd=#gd-Kb(7182),Kb(-11281),1 kf=27941 end elseif kf<=38076 then if kf>38005 then G,ka=lg[Kb(-22226)],lg[22287];gd,Sc=jk(i,Ke,Kb(10003),G,ka);if not gd then kf=Tc[-30964]or _k(-30964,64344,2376)break end kf=Tc[7018]or _k(7018,97162,37680)elseif kf<=37966 then lg=Ue[Hh]qa=lg[Kb(7424)]kf=Tc[1611]or _k(1611,62342,14106)else Sc=Fi(gl)==Kb(-3905)kf=22857 break end elseif kf>38155 then G,ka,gd=lg[Kb(30319)],lg[Kb(-12972)],Ke[lg[Kb(-928)]];if(gd==G)~=ka then kf=Tc[9984]or _k(9984,86277,11809)break else kf=Tc[2183]or _k(2183,7918,31312)break end kf=Tc[21200]or _k(21200,115634,45282)else Ke[lg[Kb(-23718)]]=gd[lg[Kb(10113)]][lg[Kb(-20236)]]kf=Tc[-23385]or _k(-23385,2696,16536)end elseif kf>40201 then if kf>40729 then if kf>41068 then Sc=ai kf=34258 break else G=Kb(-27132);kf=25712;end else if lc==Kb(-19298)then kf=Tc[-18120]or _k(-18120,15208,21169)break end kf=Tc[-27740]or _k(-27740,99565,44992)end elseif kf<=39392 then if G==Kb(-32958)then kf=Tc[-6573]or _k(-6573,17824,31727)break elseif G==Kb(-23238)then kf=Tc[-6096]or _k(-6096,80314,36934)break end kf=Tc[-1158]or _k(-1158,11597,15571)else G=if ka<Kb(15723)then ka else ka-Kb(24957)kf=Tc[6994]or _k(6994,84003,4257)break end elseif kf>35025 then if kf>36072 then if kf<=36786 then if Kb(-23539)then kf=22765 else kf=61169 end elseif kf>36821 then G[Kb(29734)]=ka lg[Kb(11157)]=Kb(-23512)kf=Tc[-25151]or _k(-25151,91072,4252)else gl=Bd kf=Tc[1648]or _k(1648,81198,58731)break end elseif kf<=35430 then if not(Ke[lg[Kb(-31026)]]<Ke[lg[Kb(-10529)]])then kf=Tc[20581]or _k(20581,48585,48299)break else kf=Tc[-4873]or _k(-4873,91009,49323)break end kf=Tc[382]or _k(382,83022,19998)else ka=ob[Kb(-31239)]pf=G+ka-Kb(-15513)kf=Tc[-15508]or _k(-15508,40231,45136)end elseif kf<=33751 then if kf>33407 then if lg[63784]==161 then kf=Tc[12032]or _k(12032,62644,49647)break elseif not(lg[Kb(-10818)]==Kb(-22906))then kf=Tc[6405]or _k(6405,125721,40347)break else kf=Tc[4473]or _k(4473,54030,15008)break end kf=Tc[27715]or _k(27715,83765,19815)elseif kf<=33209 then G,ka,gd=lg[Kb(1351)],lg[Kb(17893)],lg[Kb(-32462)];Sc=Ke[ka];Ke[G+Kb(-32818)]=Sc Ke[G]=Sc[gd]Hh+=Kb(-9532)kf=Tc[31909]or _k(31909,38005,32295)else Hh-=1 Ue[Hh]={[Kb(2061)]=Kb(-21695),[Kb(24084)]=P(lg[Kb(-15428)],Kb(934)),[Kb(-3750)]=P(lg[Kb(-4881)],96),[Kb(-24851)]=Kb(1827)}kf=Tc[-26811]or _k(-26811,89854,14254)end elseif kf>34104 then if kf>34281 then Eb[Kb(9411)]=Eb[Kb(-17905)][Eb[Kb(17876)]]Eb[Kb(-26451)]=Eb Eb[3]=Kb(-24915)Gj[gl]=nil kf=Tc[8563]or _k(8563,129766,38917)else ka[52725]=Sc kf=Tc[9451]or _k(9451,82434,41152)end else Eb=Eb..cc(P(Ud(Sc,Qb+Kb(-33162)),Ud(gl,Qb%#gl+Kb(6730))))kf=Tc[12849]or _k(12849,15988,25760)end elseif kf<=57262 then if kf<=53168 then if kf>51062 then if kf<=51996 then if kf<=51416 then if kf>51192 then G,ka,gd=lg[Kb(-27337)],Ue[Hh+Kb(-30163)],Kb(8782);kf=16910;else ka,gd,Sc=Gj;if pe(ka)~='function'then kf=Tc[8346]or _k(8346,3018,26033)break end;kf=Tc[18426]or _k(18426,60769,10994);end elseif kf>51650 then Hh-=Kb(-11254)Ue[Hh]={[Kb(5507)]=Kb(1002),[Kb(14925)]=P(lg[Kb(-21445)],Kb(24822)),[22287]=P(lg[Kb(24482)],Kb(-20918)),[Kb(5560)]=Kb(-33380)}kf=Tc[-12192]or _k(-12192,78690,49458)else kj(Eb)kf=Tc[13980]or _k(13980,80376,35444)end elseif kf<=52488 then if kf<=52262 then if kf>52138 then if kf>52178 then Hh+=lg[Kb(534)]kf=Tc[14376]or _k(14376,68023,2789)else gl,Eb=ka(gd,Sc);Sc=gl;if Sc==nil then kf=Tc[29994]or _k(29994,81646,55230)else kf=Tc[23851]or _k(23851,16169,31100)end end else if Kb(-10773)then kf=Tc[29752]or _k(29752,40004,7000)else kf=51113 end end elseif kf>52377 then ka[Kb(-11474)]=gd if G==Kb(-17778)then kf=Tc[-17608]or _k(-17608,64476,791)break elseif G==Kb(15551)then kf=Tc[-22548]or _k(-22548,87322,45370)break end kf=Tc[-24983]or _k(-24983,37935,61155)else ai=Sc;if gl~=gl then kf=Tc[7990]or _k(7990,71085,65279)else kf=61651 end end else if Ke[lg[Kb(16459)]]==Ke[lg[Kb(-30319)]]then kf=Tc[-17497]or _k(-17497,69066,1909)break else kf=Tc[-545]or _k(-545,669,24690)break end kf=Tc[25448]or _k(25448,39152,32172)end elseif kf>49761 then if kf<=50063 then if kf>49937 then kf=Tc[17281]or _k(17281,89233,3288);break;else Hh-=Kb(7226)Ue[Hh]={[12893]=Kb(-3847),[Kb(-16140)]=P(lg[Kb(-10147)],Kb(-19169)),[Kb(28898)]=P(lg[Kb(18140)],140),[Kb(-2001)]=Kb(26810)}kf=Tc[-16959]or _k(-16959,77777,58499)end elseif kf<=50245 then if not(qa>Kb(-7208))then kf=Tc[-5143]or _k(-5143,82231,3573)break else kf=Tc[-27930]or _k(-27930,58603,4066)break end kf=Tc[-22757]or _k(-22757,84931,18577)else if not(qa>Kb(17978))then kf=Tc[-975]or _k(-975,125278,37801)break else kf=Tc[6848]or _k(6848,83501,20590)break end kf=Tc[10589]or _k(10589,127564,32792)end elseif kf>49335 then if kf>49418 then gl=gl..cc(P(Ud(gd,Z+Kb(-14033)),Ud(Sc,Z%#Sc+1)))kf=Tc[18501]or _k(18501,72543,5919)else Hh-=Kb(1875)Ue[Hh]={[Kb(3762)]=Kb(-18953),[Kb(1754)]=P(lg[Kb(-16650)],Kb(-29382)),[Kb(-18042)]=P(lg[Kb(-33445)],Kb(18587)),[Kb(-20181)]=Kb(-14602)}kf=Tc[16117]or _k(16117,38310,32502)end elseif kf<=49261 then G,ka=Ke[lg[Kb(22206)]],Kb(-15528);kf=13735;else if not(lg[63784]==Kb(-27373))then kf=Tc[27812]or _k(27812,68686,62811)break else kf=Tc[-11281]or _k(-11281,63416,18096)break end kf=Tc[20261]or _k(20261,100322,36018)end elseif kf>55424 then if kf>56892 then if(Qb>=0 and Bd>Z)or((Qb<0 or Qb~=Qb)and Bd<Z)then kf=Tc[-27364]or _k(-27364,108952,39400)else kf=Tc[-14103]or _k(-14103,64427,5675)end elseif kf>56732 then Ke[lg[Kb(18610)]]=Ke[lg[Kb(16037)]]-lg[Kb(-17529)]kf=Tc[18096]or _k(18096,97619,5889)else ka[Kb(-15090)]=gl kf=Tc[29688]or _k(29688,84795,47583)end elseif kf>54377 then if kf>54702 then if qa>Kb(1064)then kf=Tc[15460]or _k(15460,114868,52325)break else kf=Tc[1961]or _k(1961,44785,44597)break end kf=Tc[-10158]or _k(-10158,68935,1813)elseif kf>54535 then if kf<=54652 then ka,gd,Sc=A(ka)kf=Tc[-22257]or _k(-22257,89446,56280)else Hh+=Kb(-27504)kf=Tc[22087]or _k(22087,122778,46282)end else if Ke[lg[Kb(30121)]]then kf=Tc[-32611]or _k(-32611,9950,28492)break end kf=Tc[-32627]or _k(-32627,99767,36581)end else G=lg[Kb(-3600)];Ke[lg[Kb(-32375)]]=Ke[lg[Kb(-10052)]][G]Hh+=Kb(6697)kf=Tc[31695]or _k(31695,72440,64436)end elseif kf<=61546 then if kf>59596 then if kf>60790 then if kf<=61099 then Eb=Eb+Bd;Z=Eb;if Eb~=Eb then kf=Tc[-26788]or _k(-26788,86084,40121)else kf=45783 end elseif kf>61274 then Hh+=Kb(-17281)kf=Tc[-25576]or _k(-25576,38419,31809)else gl,Eb,ai=ka[Kb(15573)],lg[Kb(-20870)],Kb(-5811);Z,Qb,Bd=#gl-Kb(-28346),1,Kb(-18940)kf=Tc[19349]or _k(19349,120741,38379)end elseif kf<=60474 then Hh-=Kb(24495)Ue[Hh]={[Kb(14257)]=Kb(20234),[Kb(6529)]=P(lg[3564],Kb(243)),[Kb(-15831)]=P(lg[Kb(-3978)],255),[Kb(-29231)]=Kb(-33896)}kf=Tc[-31968]or _k(-31968,94409,1435)elseif kf<=60640 then if Kb(-4647)then kf=21988 else kf=Tc[20590]or _k(20590,39533,302)end elseif kf<=60714 then Eb=Eb+Bd;Z=Eb;if Eb~=Eb then kf=Tc[-20302]or _k(-20302,129712,39916)else kf=Tc[12279]or _k(12279,83964,21609)end else if not Ke[lg[Kb(-29917)]]then kf=Tc[12769]or _k(12769,84231,25635)break end kf=Tc[8371]or _k(8371,119700,41152)end elseif kf>58531 then if kf<=59055 then if kf<=58887 then gd=Eb kf=Tc[29987]or _k(29987,88981,14730)break else ka,gd,Sc=nc;if pe(ka)~='function'then kf=Tc[-9948]or _k(-9948,45269,52154)break end;kf=Tc[-17912]or _k(-17912,40006,6712);end else if not(qa>Kb(9920))then kf=Tc[-31019]or _k(-31019,90685,17030)break else kf=Tc[29201]or _k(29201,38495,18764)break end kf=Tc[11902]or _k(11902,84633,19403)end elseif kf>57966 then if kf>58084 then Qb={[Kb(29796)]=Ke[Bd[Kb(-3790)]],[Kb(-4061)]=Kb(-1381)};Qb[Kb(-29106)]=Qb gd[ai]=Qb kf=Tc[28681]or _k(28681,120124,55109)else if(Bd>=0 and Eb>ai)or((Bd<0 or Bd~=Bd)and Eb<ai)then kf=Tc[-10728]or _k(-10728,46362,24394)else kf=29712 end end else Eb,ai,Bd=ka[Kb(-2881)],lg[Kb(-12061)],Kb(25147);lc,Qb,Z=1,(#Eb-Kb(-31579))+191,191 kf=64128 end elseif kf>63445 then if kf<=64479 then if kf>63997 then if kf>64170 then if kf>64245 then if not(qa>Kb(-16475))then kf=Tc[16351]or _k(16351,115733,46764)break else kf=Tc[-15197]or _k(-15197,36480,24783)break end kf=Tc[17536]or _k(17536,96131,7377)else G=Kb(-21429);kf=Tc[1124]or _k(1124,46519,38594);end elseif kf<=64076 then G,ka,gd=P(lg[Kb(9183)],Kb(22088)),P(lg[22287],Kb(-29284)),P(lg[Kb(11672)],Kb(20061));Sc,gl=ka==Kb(2534)and pf-G or ka-Kb(3059),Ke[G];Eb=Kh(gl(th(Ke,G+Kb(26169),G+Sc)));ai=Eb[Kb(-3449)];if gd==0 then kf=Tc[-26172]or _k(-26172,21114,24956)break else kf=Tc[-4826]or _k(-4826,70706,60441)break end kf=28272 elseif kf<=64124 then G,ka=Ue[Hh],Kb(11412);kf=Tc[-31215]or _k(-31215,88242,62622);else Ia=Z;if Qb~=Qb then kf=Tc[13520]or _k(13520,33911,19153)else kf=44197 end end else G,ka=lg[Kb(-33953)],lg[Kb(7551)];gd=ka-Kb(-31154);if gd==Kb(-15642)then kf=Tc[-31505]or _k(-31505,15883,17789)break else kf=Tc[21577]or _k(21577,51618,2302)break end kf=7654 end elseif kf>64953 then if kf<=65230 then if kf<=65189 then Sc=ai kf=Tc[-24446]or _k(-24446,65780,34580)break else if not(qa>Kb(27021))then kf=Tc[7935]or _k(7935,94070,50367)break else kf=Tc[17691]or _k(17691,77157,5861)break end kf=Tc[-3245]or _k(-3245,65704,62852)end else if Kb(23618)then kf=34258 else kf=Tc[-31198]or _k(-31198,117514,57869)end end elseif kf>64666 then ka,gd,Sc=A(ka)kf=Tc[23552]or _k(23552,93877,43686)else gl=gd;kf=37990;end elseif kf<=62372 then if kf>61953 then Sc=Sc+Eb;ai=Sc;if Sc~=Sc then kf=Tc[5118]or _k(5118,90663,4213)else kf=61651 end elseif kf<=61755 then if kf<=61633 then gl,Eb,ai=ka[Kb(16422)],lg[Kb(11218)],Kb(24383);Bd,Z,Qb=Kb(-724),#gl-Kb(-32163),1 kf=13551 elseif kf>61653 then Hh+=lg[24748]kf=Tc[-832]or _k(-832,68920,1908)else if(Eb>=0 and Sc>gl)or((Eb<0 or Eb~=Eb)and Sc<gl)then kf=Tc[1774]or _k(1774,128910,40158)else kf=26624 end end else if not(qa>Kb(4883))then kf=Tc[-20663]or _k(-20663,58041,8174)break else kf=Tc[15610]or _k(15610,70358,65173)break end kf=Tc[-4128]or _k(-4128,116065,53043)end elseif kf>62784 then G,ka,gd=lg[Kb(-32927)],lg[Kb(6005)],Ke[lg[Kb(17170)]];if(gd==G)~=ka then kf=Tc[24197]or _k(24197,38943,27158)break else kf=Tc[28339]or _k(28339,84349,26601)break end kf=Tc[10377]or _k(10377,102083,34705)else Sc..=Ke[Bd]kf=Tc[18339]or _k(18339,25810,28129)end end until kf==38550 end)({[11952]=52725,[26311]=3,[7844]=11929,[458]=2,[-28480]=27029,[32345]=22287,[23296]=12893,[-4988]=24748,[-1761]=26946,[-14776]=69,[4134]=1,[19715]=3,[-27411]=3564,[-3042]=22287,[-6349]=12893,[-14819]=252,[-162]=63784,[-8308]=3564,[2773]=217,[31661]=nil,[26796]=65536,[16199]=3564,[2903]=38,[30620]=3564,[17075]=63784,[-32756]=22287,[27958]=26946,[-32627]=44,[-1911]=22287,[-13674]=1,[-6574]=3564,[-13788]=1,[-11386]=32768,[-15966]=160,[17562]=32768,[-1951]=22287,[-2808]=true,[22856]=36,[13509]=28,[-15891]=1,[9021]=1,[26334]=1,[-23431]=146,[-16066]=1,[-19590]=nil,[-11178]=76,[6667]=2,[9390]=22287,[8718]=104,[-12253]=1,[-23447]=nil,[-11878]=61143,[9375]=148,[25923]=3564,[22788]=63784,[8368]=3564,[-25458]=51334,[23541]=1,[-30324]=1,[16843]=12893,[-18397]=28360,[-32371]=1,[24771]=1,[-29400]=47320,[-20387]=63784,[2273]=22287,[2933]=1,[-13998]=141,[5008]=193,[14652]=1,[-15428]=3564,[-25699]=1,[-1042]=28360,[-14217]=49222,[-19621]=3564,[-15690]=26946,[-14811]=3564,[7087]=159,[2212]=96,[-30979]=1,[19025]=-1,[-9635]=26946,[-14165]=63784,[31120]=2,[8220]=1,[-23012]=63784,[26661]=120,[9784]=2,[842]=2,[2337]=3564,[-15939]=2,[26105]=1,[-9442]=0,[-27543]=56,[11094]=84,[19020]=26946,[-22033]=139,[6722]=110,[-2066]=Yk('^\153 2L\133!?','8\236NQ'),[23927]=92,[-16203]=22287,[31663]=97,[-8934]=true,[-17745]=0,[-16488]=24748,[-9883]=nil,[-13503]=63784,[-30310]=1,[-5593]=nil,[-18773]=1,[28649]=0,[-27403]=26946,[-24168]=117,[-31541]=0,[16261]=3564,[11563]=184,[-29127]=3,[-2222]=3,[-465]=true,[-13872]=1,[-30503]=3564,[7744]=26946,[1737]=nil,[20449]=22287,[-13589]=3564,[-11621]=3564,[-23076]=2,[-26408]=185,[-2709]=22287,[15263]=26946,[-9415]=1,[-14179]=0,[-17278]=true,[2841]=106,[9065]=1,[-26004]=67,[7456]=1,[-21673]=160,[-14407]=61143,[10126]=24748,[15069]=1,[-11133]=11929,[2373]=24748,[28860]=230,[2082]=39,[-31606]=22287,[-2008]=110,[30737]=22287,[-676]=3564,[-8979]=63784,[29935]=241,[-718]=26946,[10989]=63784,[-11737]=3,[-25665]=1,[1608]=52725,[-11977]=0,[-29062]=-2,[18605]=3564,[-29187]=3564,[-27445]=183,[13699]=3,[148]=3564,[-24432]=3,[-30228]=3564,[3714]=1,[-4588]=1,[22073]=133,[18261]=52725,[-1130]=1,[4611]=26946,[26222]='',[-31825]=22287,[7346]=12893,[19566]=3,[-30738]=1,[-13086]=nil,[-3323]=63784,[2807]=3564,[13986]=248,[17201]=95,[4706]=3564,[-23359]=3564,[29383]=12893,[21518]=3564,[9263]=12893,[-11311]=22287,[9888]=1,[-3832]=63784,[-5802]=1,[12747]=0,[-8213]=22287,[10621]=nil,[24620]=1,[19683]=63784,[4898]=1,[-25498]=24710,[-29740]=1,[32158]=26946,[-25185]=22287,[5094]=0,[-19079]=123,[-17]=253,[18298]=3564,[-31088]=26946,[-8079]=nil,[-29966]=28,[-8126]=3,[16764]=3564,[-7950]=22287,[-2027]=68,[-25584]=2,[19817]=206,[-31711]=176,[1115]=0,[-15627]=3564,[14831]=35,[-24612]=1,[-17330]=77,[-17101]=0,[3900]=12893,[5468]=nil,[-6880]=50181,[12996]=12893,[-23202]=true,[3587]=1,[-28089]=3564,[22125]=149,[-13803]=-1,[-32342]=1,[-21879]=3564,[11092]='',[-31454]=1,[12422]=1,[-28078]=3564,[-32760]=22287,[17057]=151,[-18793]=2,[-2139]=22287,[25489]='',[8569]=1,[22480]=1,[2142]=76,[-5102]=49222,[-12763]=0,[-17033]=0,[-973]=90,[-19533]=52725,[30777]=3564,[-20906]=3564,[13057]=52725,[16096]=12893,[14855]=57,[-12194]=1,[-13368]=15,[-7176]=22287,[-5369]=199,[-16503]=3,[-27267]=1,[-28324]=1,[-7693]=1,[-28979]=1,[-16427]=140,[19979]=22287,[-23969]=181,[-19884]=1,[31573]=26946,[-7488]=26946,[18314]=1,[11234]=63784,[-21399]=3,[-10080]=1,[-18829]=Yk('x\96','\19'),[-7776]=95,[-17114]=38,[29178]=Yk('\177z\161\129A\169','\238%\204'),[-496]=3,[25393]=22287,[-3552]=24748,[-28038]=68,[-31323]=1,[11178]=132,[12883]=1,[-13251]=28360,[19009]=3564,[7399]=63784,[-14301]=3564,[-3955]=-1,[16323]=Yk('\161\215\210\198\179\203\211\203','\199\162\188\165'),[3593]=3564,[-32359]=22287,[12024]=12893,[-29315]=1,[14934]=249,[24045]=3564,[-19606]=3564,[-27609]=1,[11555]=1,[28971]=154,[-26436]=2,[3666]=0,[13511]=3564,[-27392]=63784,[21261]=0,[-15442]=1,[-25475]=Yk('jo','\28'),[22822]=186,[26954]=1,[-8690]=27029,[-6546]=24748,[-31119]=2,[21900]=79,[-4030]=186,[-2219]=12893,[17412]=52725,[-18598]=173,[-13737]=true,[344]=50491,[23329]=true,[-10222]=28360,[12086]=63784,[20896]=3,[3632]=3564,[-4095]=1,[-30646]=1,[-19565]=0,[28874]=24748,[27663]=26946,[25457]=true,[-21067]=213,[-28339]=nil,[31635]=2,[-25293]=nil,[-22176]=3564,[12145]=false,[-1610]=47320,[14388]=1,[-13992]=22287,[10393]=true,[-19696]=24748,[-20655]=26946,[-15801]=51334,[-1270]=1,[-14636]=225,[911]=3564,[-11736]=101,[-18342]=63784,[8536]=1,[11759]=211,[-21866]=1,[-21700]=true,[5844]=63784,[3190]=3564,[-16143]=108,[-32114]=3564,[2043]=184,[5601]=12893,[-30536]=63784,[-30623]=26946,[-12093]=1,[-25534]=113,[12680]=false,[9056]=1,[-25602]=22287,[-13842]=3,[17152]=22287,[1103]=99,[3446]=3564,[23457]=22287,[31960]=3564,[-26507]=1,[-17784]=63784,[31103]=1,[-12945]=3564,[11842]='',[17390]=3,[9189]=24748,[-32057]=0,[-32190]=1,[25255]=22287,[20426]=195,[15089]=1,[13251]=nil,[27367]=3564,[-19856]=174,[20924]=65536,[14880]=142,[5962]=nil,[-3972]='',[24675]=6,[11022]=63784,[-27839]=12893,[-17459]=2,[-13689]=nil,[10420]=0,[1905]=nil,[-20367]=27,[11250]=2,[17876]=3564,[11586]=1,[28008]=1,[-30421]=22287,[26321]=22287,[19732]=63784,[4373]=0,[2839]=1,[18716]=3564,[-19031]=52725,[-27408]=3,[26986]=''})end local fb fb=function(...)return(function(Th,...)local Ee,mk,uc,Ad,gg,ee,Wg,Ya,ff,Wi,Li mk,gg={},function(Vd,Cd,Ff)mk[Vd]=Vf(Cd,39312)-Vf(Ff,58328)return mk[Vd]end Ee=mk[18404]or gg(18404,9743,20236)repeat while true do if Ee<=30969 then if Ee<=15360 then if Ee<=8183 then if Ee>5461 then uc=Kh(jk(qk,Li,De[ff(-7101)],De[ff(-22482)],Wg));if uc[ff(9104)][ff(-28595)]then Ee=mk[-28396]or gg(-28396,81469,4984)break else Ee=mk[28399]or gg(28399,112300,14180)break end Ee=mk[-15884]or gg(-15884,124357,14031)else ff=function(Fh)return Th[Fh-2623]end Wi,Li,Wg=ul(...),vc(De[10276]),{[ff(25084)]={},[ff(1418)]=ff(-17232)};ad(Wi,ff(4790),De[ff(-1980)],ff(-24790),Li)if De[ff(21633)]<Wi[Yk('\96','\14')]then Ee=mk[26773]or gg(26773,31622,57655)break end Ee=6111 end else ee=Fi(Ya)==ff(-27015)Ee=mk[24550]or gg(24550,72710,19623)break end elseif Ee>24539 then Ad=Fi(Ad)Ee=mk[23633]or gg(23633,3471,61081)else Ad,ee=uc[ff(18389)][ff(-5718)],ff(34345);Ee=mk[14330]or gg(14330,130169,29160);end elseif Ee<=45826 then if Ee>38670 then Ee=mk[28343]or gg(28343,30519,48353);break;elseif Ee>36359 then if ff(-5714)then Ee=mk[9059]or gg(9059,76746,16283)else Ee=54201 end else return kj(Ad,0)end elseif Ee>51994 then if Ee>55664 then uc,Ad=De[ff(-22235)]+ff(-5981),Wi[Yk(')','G')]-De[ff(-17101)];Wg[ff(32544)]=Ad;ad(Wi,uc,uc+Ad-ff(-6445),ff(-16169),Wg[ff(13809)])Ee=mk[-30394]or gg(-30394,102854,5039)elseif Ee>54504 then if ee==ff(13499)then Ee=mk[25863]or gg(25863,106722,14308)break end Ee=34526 else Ya=Ad;Ee=mk[15053]or gg(15053,12668,38929);end else return th(uc[ff(-12562)],ff(23588),uc[ff(-18665)])end end until Ee==36718 end)({[31722]=nil,[19010]=51312,[-15185]=61143,[2167]=1,[20965]=2,[-4603]=51312,[-31218]=1,[22461]=61143,[-19855]=0,[-8604]=1,[-19724]=51312,[-29638]=Yk('\162_s\184Ef','\209+\1'),[-9068]=1,[29921]=47320,[-1205]=47320,[6481]=61143,[-18792]=1,[-24858]=51312,[15766]=61143,[-25105]=38943,[10876]=false,[-21288]=47320,[-8341]=2,[-27413]=0,[11186]=61143,[-9724]=39822,[-8337]=true},...)end return fb end return yc(Uf,Va)end local Xf Xf,lj={[l(29867)]=l(37094)},function()return(function(Vh)local function ed(ch)return Vh[ch-17601]end;Xf[ed(8188)]=Xf[ed(958)]+ed(-12760)return{[ed(13649)]=Xf[ed(-13620)],[ed(605)]=Xf}end)({[-16996]=1,[-30361]=1,[-9413]=0,[-31221]=0,[-3952]=3,[-16643]=0})end zf=Jj end)({[3053]=8,[32328]=false,[-10894]=6,[-17908]=true,[-534]=7,[21617]=8,[-32154]=true,[18610]=7,[-11616]=false,[859]=false,[-4507]=true,[-7010]=false,[-26]=6,[-28087]=21312,[27356]=9,[-24877]=false,[22699]=5,[-13097]=true,[21394]=7,[17048]=9,[25143]=false,[27475]=false,[3428]=true,[-18352]=7,[-7917]=true,[-30759]=3,[-13464]=false,[17167]=7,[14016]=false,[-15561]=9,[-30183]=false,[-14172]=false,[-8379]=10,[-31592]=false,[-15156]=5,[20698]=false,[-7320]=7,[-23378]=7,[-10182]=0,[-11966]=false,[-12291]=7,[10331]=false,[22124]=true,[9885]=9,[-29218]=3,[-29554]=7,[850]=7,[32177]=8,[2225]=false,[-7548]=false,[17768]=false,[-26467]=8,[-20195]=7,[16265]=5,[8764]=false,[-13644]=3,[-29699]=true,[-27736]=8,[-21848]=0,[999]=8,[3389]=10,[-2508]=7,[-17503]=1,[-3190]=8,[16379]=0,[-5245]=3,[-20224]=false,[-17998]=1,[15857]=true,[24672]=7,[-18484]=false,[-21531]=8,[-31258]=10,[-28187]=7,[-17809]=9,[-13694]=7,[-21210]=3,[626]=false,[11213]=false,[19590]=8,[-10353]=8,[20423]=false,[-8856]=true,[-1762]=false,[12570]=6,[-11886]=true,[-3321]=true,[-11070]=3,[-14460]=8,[23649]=true,[-593]=9,[24955]=9,[9152]=0,[20648]=3,[-22067]=3,[25266]=false,[30334]=4,[-19481]=6,[-13847]=false,[32313]=false,[-22750]=7,[2625]=8,[-10217]=false,[-313]=6,[28142]=1,[21520]=9,[-8318]=false,[26392]=3,[27185]=7,[-7125]=false,[2867]=6,[-16065]=true,[31795]=3,[-18457]=8,[6610]=7,[-29442]=8,[-13640]=true,[-26930]=4,[-27665]=false,[7364]=9,[-30804]=7,[15714]=10,[15307]=true,[9849]=true,[-16829]=true,[-13944]=false,[-30173]=7,[-27459]=3,[-8990]=4,[-29773]=6,[-9725]=false,[31560]=6,[-3762]=4,[-21145]=9,[6073]=6,[2151]=4,[18782]=4,[-12941]=5,[-28180]=4,[-4001]=false,[-3122]=6,[-10925]=3,[22589]=9,[-8407]=7,[-11036]=9,[31545]=false,[26240]=0,[-13510]=3,[23640]=6,[29808]=6,[29998]=9,[-28164]=false,[-575]=6,[-29691]=4,[-32211]=4,[13771]=false,[211]=7,[-32052]=5,[-11794]=false,[-20595]=true,[-5905]=3,[-12568]=4,[-24692]=3,[9959]=true,[27979]=3,[26702]=false,[1405]=5,[15389]=6,[5868]=0,[10336]=false,[4574]=4,[-21579]=5,[-5010]=4,[-3699]=9,[8450]=7,[-10573]=7,[22899]=5,[4821]=7,[-16090]=true,[-8012]=9,[-20890]=8,[15760]=8,[-19039]=3,[18745]=6,[5256]=4,[-7449]=false,[14086]=6,[20371]=6,[28321]=3,[-1154]=false,[14654]=3,[26724]=4,[22567]=7,[22389]=9,[-12928]=50491,[25307]=true,[-5275]=6,[22253]=4,[-15826]=4,[-27377]=9,[12340]=6,[10630]=false,[-27127]=6,[28211]=7,[21207]=7,[2866]=6,[-20316]=false,[12547]=1,[15830]=false,[30110]=10,[7165]=9,[-26067]=false,[-26400]=9,[20582]=7,[-31822]=5,[998]=false,[18749]=9,[2712]=5,[-27551]=9,[-18300]=7,[32069]=true,[-17942]=6,[17020]=1,[-17773]=0,[9154]=7,[-14283]=7,[-12422]=5,[27568]=7,[6903]=true,[6635]=false,[25093]=3,[-28330]=false,[-2719]=6,[19673]=3,[-2976]=true,[14944]=7,[32614]=7,[8874]=9,[-17840]=true,[-16281]=7,[-20532]=8,[-20470]=7,[-3560]=false,[-3354]=true,[25123]=4,[-11383]=true,[-6780]=8,[10710]=false,[-16323]=false,[-11090]=7,[15418]=3,[-1923]=true,[-13516]=false,[-16435]=7,[-27018]=0,[-15176]=6,[23305]=6,[-12080]=4,[-12021]=7,[28416]=false,[20672]=6,[-1881]=true,[21240]=7,[-13471]=7,[31494]=1,[23777]=false,[-9595]=0,[-26702]=9,[-10109]=false,[-10860]=6,[6205]=6,[14259]=false,[31593]=false,[-1139]=false,[-25127]=false,[14747]=8,[-7348]=3,[17962]=4,[-15506]=3,[22019]=true,[-6280]=7,[-30126]=8,[9232]=7,[-14575]=false,[-11308]=10,[20829]=true,[17419]=4,[28724]=false,[7229]=6,[12258]=4,[4860]=false,[-14771]=9,[-4424]=0,[4658]=true,[-12873]=false,[-21957]=3,[-31114]=8,[15215]=7,[25822]=8,[5528]=6,[659]=6,[-17923]=true,[26302]=8,[27196]=true,[23856]=false,[-6889]=8,[-18336]=false,[29245]=false,[24269]=7,[-24575]=6,[-23987]=5,[-735]=6,[31334]=3,[-31920]=6,[5547]=0,[12617]=false,[-9374]=9,[-2536]=8,[20942]=9,[17213]=6,[21115]=7,[13407]=9,[16936]=false,[-31995]=4,[-942]=true,[-7014]=3,[-20107]=8,[17945]=3,[-15409]=0,[11056]=3,[-24768]=4,[23150]=false,[-18025]=false,[6517]=7,[-15228]=true,[25047]=8,[3093]=9,[32762]=6,[-26552]=true,[25763]=3,[-9864]=4,[-29615]=7,[7994]=6,[-11138]=3,[-5834]=6,[4468]=10,[-7477]=true,[5469]=false,[10326]=3,[-24835]=false,[-4299]=7,[-27136]=false,[7516]=6,[-17577]=6,[-15340]=5,[21971]=6,[-11702]=9,[24231]=7,[14301]=false,[-22757]=3,[17866]=6,[14209]=5,[-1318]=5,[26675]=0,[18467]=4,[16400]=7,[-16750]=3,[-12013]=7,[30093]=false,[-20123]=true,[-7381]=3,[-5231]=9,[16998]=false,[-29478]=false,[-31272]=6,[21744]=7,[-3828]=false,[10425]=6,[23975]=7,[27863]=false,[23192]=true,[-28661]=9,[10994]=6,[-22227]=true,[7400]=9,[-309]=7,[7747]=4,[3270]=true,[-2746]=false,[-22077]=8,[-12406]=4,[20004]=7,[-14164]=7,[-24207]=6,[-16414]=false,[4466]=10,[-17662]=4,[-2026]=3,[-17940]=9,[-17420]=true,[5298]=7,[-10196]=3,[-9344]=true,[-27894]=false,[-15965]=4,[30255]=5,[24425]=true,[31959]=0,[17104]=false,[-12677]=4,[-21783]=true,[24275]=true,[9092]=8,[8810]=6,[8671]=4,[24097]=7,[28039]=3,[14077]=0,[4085]=6,[-1747]=true,[16065]=7,[-3348]=7,[-7154]=true,[2380]=false,[-13818]=4,[9534]=6,[11777]=9,[-10333]=false,[21932]=6,[25269]=0,[24569]=true,[4063]=true,[-11434]=4,[9709]=false,[-10388]=3,[29405]=false,[15275]=3,[-4092]=false,[-23114]=0,[6607]=8,[-18196]=6,[15822]=6,[-14356]=8,[25579]=true,[-23070]=false,[-730]=false,[-14183]=false,[19988]=3,[19853]=6,[24817]=true,[-6850]=6,[-12888]=8,[26610]=7,[-17519]=false,[4360]=1,[-6828]=7,[4057]=4,[-9484]=3,[18617]=6,[-31611]=1,[19787]=true,[851]=6,[16318]=false,[15239]=6,[14158]=6,[9872]=4,[-28209]=6,[14992]=10,[2944]=4,[9228]=7,[-22661]=false,[15561]=6,[6603]=7,[-30118]=3,[-29362]=false,[-10835]=7,[13233]=5,[-15315]=7,[-20905]=3,[-1539]=3,[-12362]=7,[3502]=6,[6496]=false,[29717]=false,[10677]=8,[-11618]=7,[18471]=true,[-12759]=true,[-15120]=7,[-1743]=false,[32452]=false,[13658]=8,[13739]=true,[-2301]=6,[-24984]=true,[-16984]=3,[-32492]=6,[-28587]=false,[679]=6,[-27726]=8,[-4481]=7,[-14851]=false,[7620]=1,[1297]=true,[-7324]=3,[30307]=6,[27962]=false,[-10057]=9,[-9877]=3,[18915]=false,[-9836]=3,[5404]=false,[2508]=false,[-30330]=6,[32012]=3,[4929]=3,[14887]=3,[21668]=true,[-16873]=true,[17851]=true,[6824]=false,[-4445]=7,[-20055]=8,[6542]=6,[-2201]=4,[-27442]=true,[-28008]=true,[-22355]=7,[25187]=3,[4946]=false,[19496]=false,[-18009]=5,[14127]=3,[-2814]=6,[2863]=8,[1770]=false,[-12645]=4,[5699]=9,[20285]=7,[3520]=7,[27286]=8,[28411]=3,[-12348]=3,[17612]=4,[-28591]=false,[10586]=7,[-7581]=7,[9861]=false,[-12777]=7,[-8348]=3,[2456]=4,[-32035]=false,[-8131]=1,[19092]=false,[31594]=4,[-5732]=9,[-26086]=7,[-15363]=7,[-25193]=true,[-25303]=3,[28533]=8,[27119]=3,[16875]=6,[31068]=true,[-10153]=6,[9636]=4,[22624]=0,[-3744]=3,[7751]=0,[-21226]=false,[11100]=false,[-19323]=true,[-9893]=3,[20173]=0,[-26093]=false,[19160]=7,[24665]=0,[4863]=3,[24489]=8,[23734]=6,[15657]=6,[-19349]=8,[28044]=6,[18837]=0,[-22223]=8,[-12380]=true,[17877]=8,[-27739]=false,[-17737]=true,[-10706]=9,[-32615]=true,[29310]=4,[1443]=false,[10973]=8,[-20037]=3,[2143]=7,[26922]=3,[-32339]=7,[25906]=false,[-2484]=5,[12244]=5,[31599]=false,[23733]=9,[-24402]=9,[29028]=7,[14316]=false,[-17526]=3,[-26027]=4,[29860]=false,[-21768]=8,[-30374]=0,[20384]=7,[-10913]=true,[29160]=true,[22959]=3,[-31699]=false,[-7750]=false,[16177]=0,[8300]=true,[-26736]=false,[22908]=7,[-25913]=false,[21333]=false,[-1604]=4,[28294]=false,[7130]=true,[-11877]=false,[1379]=8,[-26707]=9,[27929]=8,[-12871]=4,[14270]=3,[-15025]=4,[-14912]=false,[-10692]=8,[28707]=false,[30466]=3,[-3978]=true,[-15270]=8,[17122]=7,[-21196]=false,[6021]=8,[8492]=true,[-28833]=7,[28715]=3,[-14936]=1,[9679]=0,[-6751]=true,[-21682]=4,[8782]=7,[-27955]=false,[27459]=3,[25819]=0,[-7339]=true,[22943]=9,[-8763]=3,[923]=7,[-4405]=3,[-3099]=6,[-138]=9,[-1178]=5,[19220]=6,[-11122]=9,[-3494]=10,[-10714]=true,[25423]=true,[1418]=7,[-16098]=false,[28496]=false,[-9811]=3,[5509]=true,[14029]=7,[18112]=9,[20881]=0,[5593]=true,[21653]=8,[16223]=false,[25189]=6,[16693]=false,[-21516]=false,[-20612]=8,[21862]=7,[26596]=false,[2476]=9,[-938]=0,[-17830]=true,[-24133]=false,[9130]=9,[-17304]=3,[-22371]=true,[-17766]=7,[1251]=3,[-18587]=true,[-5918]=6,[19775]=9})return(function()return(function(pc)local function Mc(Gi)return pc[Gi-10184]end;local cg={[Mc(4563)]=zf,[Mc(38092)]=2}cg[Mc(34984)]=cg local bh={[Mc(34805)]=yj,[Mc(-10879)]=Mc(8148)}bh[Mc(8431)]=bh local vb={[Mc(-11901)]=Fk,[Mc(-11113)]=Mc(-5271)}vb[Mc(36594)]=vb local j={[Mc(6020)]=Mc(-5516),[Mc(-13141)]=md}j[Mc(18640)]=j return zf(_a('LiYihsPYqSIEf9jpBH7Z6TJEG63mRRutTgqu8KNFG62BRxutTgqv8QR+2OkEfdnpBHza6TJDG63mQxqtMkIbreZCGa0Eedvp65l73E4IrfZOCKz3Tgis8k4KrPOjRButgUcbrU4Kr/DrnHrc7zxgIE4IrPPrYuSOnMPYqSInss7YqSIFrtb49lhqxN1Y0qs6xMCuqpOlLE0/ybNgnN1z/HCnlBfXN5NmDW0h7o6ysmGlgLEmvMbWaHD/VO9+1I9al7aPVnTeM0u+AHsyEYQon7aOrfyQ95yNN9QCS6pkoTc4rTYrE2tZW9O6IAeFf8bnGkBdAe2qxGq8AKfYfqGIf3Re9bKteXmzT8RLP6IEenNvYewEqg1RE2Ie9or10+5NGlpz6go9rL7GdSWk7+dpvIwRKvNgrNmoSGwTgc3aCtMRRq6bBYvJ5OuXy7+EeEC0xfYzmndH5sYVWZJrC+bWKCASdbuVWImbICEnXMYsFdalCQXXY66fIlP5dDYaF7PqP9qPTF+vJybcBh8GDaK98DJuKu4Rmdl4ugdKexFbTdf28c6DjuJBjLBVBHXVK6aazNamNYKmJiL2KmAPl6DPfvnFAertLHs191R9VP22YRrpc7ShEgL3JG2lNQPZMZF9YGK+5pff8sJEOh29Pokm7KglOGU/tvsieGdlaEsmzSj+lUXIy3wVaBTAqQk1ZHTvlsd6cYRXUxANke0y3sr6r4J1LUiBh0/SAWd2qEm+o1su1UR1L817svlVevfvepRP1RT3Z8xaYN+huLSEk+x91EJfxPiN5S+W9bFz1xl1IFHjgtrZU79RSZCseGjU1Xwy14NP9oK2SSK/L4SJX5TC0IqjmhI8AriP0FuH8jou9sPuKh11jeuSNoUCckJNUMS10LANWgGqH8mhBecHFUm3ZzWeXsr9xtN3tXxgldICgx0KfHApjO3nFjFsWVN3hec3mrlLij3Pe6C3x3/3RyfUuiudFmGKrNfp7ZmhvcznitXwcpScJ2C09pFpwNFPADGR4n8AFA0pjK1OnO3seFG1m24Kqax6ZriVR41LK9x5kVU/bF80wVZZ0wReZSzJ2ZOPvBePqq1HVOXT/J11jznNmoxVM98JOe2UNxFuBQpjJGUF41cJq64RUomyRxdHq8cY2qxwOguTqKbCWJMSccIJfqdJ9raxElK8tXh9hFiPvyyJEjKxZsi3Y0aB823AFeOlF5A0ggosD03r+OPSyMEQdI42WPmChJ7gzNkWGUwTPb1IlYEjGtNM9jLU5HUgKqxvMFJaBjKxpiPu1r6py08N5+K1TsMHaaHSY4HjFcl8uJGtxwmxabcekqNu9cCgCyROswNmWWnEU/I2xIBUwrpJ94XWFEwWrZfIaCmcF1Wp5CbikqChRIVAIYx3Nw6SD0JB0cXgIeKccAeFwywmeCNVdNU5EVhYdvZIGGXF7RogGMJM5IaCaqfg8qGb7NTk85g1yT5TZ6ufcYEL472yjpVDtuaTfMv+w0xXF1OzvxP/LbsV+5DqZNjNr4sQSjsE0Cwr8yWTiFCcyiFInavR/DAlR1TIX470uHPhhgiZl8NY/xU68YrGoBQ2+Z/afU/T3IpDZUvc/cwKqGyqm5YLBccHCtmAyxiS0/qSN7j0SjVdhjVdffmXTPbcX+O6luQP0YFT1DkcIWaAv19LMJTFSOQLHVKy6gq9oRqilOq+lrATc6B8d5U/k/bOEvfPiCjjA511UdmHK0BsuZWwhyjW0VaZqq6IddeBG7y3HPZJLz8+xvM4bJYE0Id9JtQ8pstfbsp1ouN+JoQtKbro+98j83AXASM6NXJ0nj6JoPH4teXp+1mr9msc+A6axCmuNsGyhos3ghzgBfi2HAjF9ZNYuNdtw36M5f1b8hINkXUlqvocblLMH3XhLsUXqkUqVnb+817JCJ7haj1+2jlRg5t95796pbnnXi9Dvd1zjQPAaQOw8cNWg2jYtj6y1QN/Wc9G/cO56ie1xJlxdU61MF0YS4Mezixycap2trxCWdXpoZenDYtXIAc4dh+3O8YxO6dopV3qbilLf5jC5vHqwEOOmjTuCRZl04SvCMVSKSgXXxOIPfC61zDJOcjOgG6thQ67LFJ0yw6vXXxOGXI60GRCKst4EMkcw8iSsufMu8qcdCw6JdLgykE3C9HVapQ2C9jvLuyucMASIubIWC0DdW9ovYnF1cJvt8JO81vCIhm9U7VddQXBfAfxHtt8JVIRJONhTjt9Mybt3XNL1xS53bScBiBur8i/qYaCt8W0JHQjgTUfGgDv378oJe9SIhs3beVgJg4Xp8Z1GX3TLHu/cxv23cfZzUmnEMpk1BeTXTHS/cf4x4OE8u/xbTQcCMudCSSHiDOi6IKocgCJxyUP1XJH8TsLFQBZBNS5IP+m0/xOMAu9NCuA8Pp8/Es+gpJ3+oaD5xy+JGkgfi1h999pOs0nssTYqSJGH13Y5BsWmvzjK6ltkCipidwwfPQKf7JlT1PsaNGQ8om4H8TCU1NWwNfcHDEmLReh4tZLK3n8Xr+aEwhclGBpY4bBzaMg1FJUQFVVsmwKbc91tj54azcKMPdLguznE0Ch2MpoPT836UOJuKi1DkCmXxyN3Oa562CA2cVf4kq8AnuKB2Lw+YaMIv9KI23M4FiBuGhoP+vOzSmSckFGVhEFZdcMhUFpd7+na0NoKJu9dvMPcKRW46cGaiQjzYx9U6x2dDpEmSM1Qhg5JOEQbHLKTUifLQ33+KSClAzCb9gTOlaVacTKcS2sJkkoCo5WJG0bYJyTCzNIyfpjSJkCaZrVTLfW0ViLs3IhQmQW25m84LTqx/TZ34g1EnWs6eEVg0pV9rU1BU8AGsP2o/W57OwqmM1EQMpu7inXxWu5rpMOypMncV8ZJRUCIDrQJPwfBDnWuP+r9REMYdnFwXyFfnJDVsJwPds22pZIej3W0F0pAHDco4khfXr5AtZBCYwVg2uG8VAYiIpUQCKIldc3IyNFYXXywtuX+yP7Qrdjv3hlDPUZwpvHOmRPY8aBICTdRtMFW9FVZlfNmM92rkGDVaVbFig3Wn4CxMky9DdRyAG9GZewPUTilFxLqdfqOHvz6v6Rg34rM6Eccn8Ty2GTn+v5sSA2MN1nxHh0eyVuGFBuFiGGCbsJimHzYj4No8gVMNsDKu2Ysmw4/gmdqw1qffDrlOejNZr9u88zJji6xCM9UaK3rbZBc2OXCmMXF70znBRgDGaDEzGiV206LhzAZPYb/JOgpDXP283Jm4jjbHzF15cRLqMSu2zTRbmk9fuORiZJpPM86bFjTQV+L2wcYZqgKDsJGVon9pOoodPUDPyI7igY5kqwFG3FnCS3TBwsXbbMRxMwGhizsa0nK0ze7wJrwxNAPyDM12WhO78zA0ItZSKL7un6ePwFQH7OVq7oUeJ76Q1YK0l06xeKyBUbgmTIABgQXcXS5crVBhlMZ3ti7sJuFggDy1ilYEvPkL+1YWGn+jQ6JemySZCXnEZA4/T1QqVQKAtV9ANWtx8uC4BuEb0xQDi7FpseRXDScbcxlkriIieCblWZaZJWKhKlJ2l3SVVz4tz3OkPAmyqSQ8yvhvLsQyzO4aIL+eL+tEf68xa7bdS3XNcW2CFKNdm9FCQtvQIrj0L7bRCp5Goy99cVUeD0s5SGdLOqY1xc6ReSqUbyzCwDkyUho2Kt3E7xxw9gmRpedy4K6kInlsPYqSIf/kykxorBHBPJhK8nzsXYqSL6mPDeHZqybf+n4PQhaSbpsT5YU00PSPTrcAo1EWmn5Bw6N2Dd4brKq5GywkqldBrKaz2SdXCPHwJhktGlOl2pE2E1FA7DFXqBymj/3qWO3QP7GsVDBzPADFV+DPV+tptlGJT3rDggXdtu5DmbxqMeEUCYnpS68OjK05PRZNmBcvPg0fKw/4pBwA3zmTJwzN5cVAzhUnKz8tFUC8GmfLz973UMqcHDB+y46phsyJMUVfYfYussTRMW88bfddnnR56eeZs2o/Q6ICX/pHJJovdD2GDq84EL/jt0TvSpL1chcsuMeI7kMl41I8rTEK6RDHrSHKaaXVaGcUovEsz9wM1zXiBFNVC6FG4QH9DkPQSQL14JNOsdoarsFP9D5lj1AfznjxKyzKRRdHNlsNtGpAm9KuuURSPGYWr1kdOCeI8+cqf/kcAHlVPMv1UlYChBDkOi4+O2OsArNfNq2gl7kGrPpofZAt6zkS/cNHguQZpF1mYOJVO3cpOO/zbZEWb0OL0jUg75bubAWOIdf4TG09KFxspG/uNNgkDPU8hKx59pRJbO3FF/CxadOEwK616fKlDWEoJwF7wbLRm9+pY+zxaE784rlUijzPmG4v3Z5i0BykhQ/YsC98Bq2qmYTlBTztfRIke3BW+g1YNGp6AnmvxYUHH7V485LHU8y5c2nIlSirUo8NjgNtU3MQau0Unue+I8rtbEYZVENr2uxvj1UBYzQvqNgcjwcKx4WmpJZ5bxGZW55fToC3zB9wZmR3wKyF9WHtN6JRJL0FPGetzuhCgSkGG9hGSrI0J7Kx6gTXNeFmI52FaVYWen3iFfeg+C/kpjRM8GQxdOv/eydTDCmCimpoR1cyci3/UC3RwPYBmXqP8H7OGcinKAlsCM5nhZBYA9exx+QAUP34s21vokCxjmD4q62uUyT+uf9PI1ZY7wx3eudSDAyPSZEpGtqEUFmFcJq47hba4pRTaw6eCB2s20+N60VTvC2Umzd0aqdFCJ0Sq6ICu5nQ/AiFLsD8828DGSHiOQ+VcjYW2RMd21aKRaEinjKNXrKTjA4sFjXqc2K/8zcp6Tkygf6hivRmkXruIeLEdOEtrQp4obB9n+Y0VtPcyxdXjIpEzzpWbwpeJmnza5PY8nzsDYqSKw+bjB8L+eB1+bOwvthCr6OV6a2TeHmfGaqQh01DUdy0v8XHiBMpsnotDbT1/mF6Zf4u8p7Zkzbi1RzXG8DU3ctKijt2zEshPSk1+yu62lOMBj4sCKTa9yhvW00LXnZrJIaBOEgdX9IRDJxmw0Pu2k9j7RDy/Xu2LZlAewYUUlNXP/NmZpFJdEvyflHGLBGIRNjYtF3UxerHkpcIoKnk05txia2l8PGKomqdwJYwga2Q+8WCd33+wBGzIuPM3tLyG6O9uifTACz4Pe4ow1ZlEnMQ01vAUVrn8D4c4OW/tn2+jdraGuDfDk3sWuAdGoDCTotJrEPOv3NpAj8/jXqLpYwoOFi6Lb/IHK89WMBQ1lk0C4cXh2+jnrR/+CKAquSMewd/hOuTiAiaB0mIe3+k7DVHNRAzITv3NJPfIpy4J95vZIHVsciANx8TM7GGPSNsZBVpe1H5I+Bj+Yr54+hItYcKNEzXrMNdlClWazkZtPDEEMUGgpVt74JWMd5EJyne4dNozv8alNa4iqmAvh2CvgHcU64hiI6AguHDbRxL3RKj+NXTpLGxSzNsYrI9lDgpqkcwJKtLNxZu12XCJz7jotLgRZbKUFfl0EH50XrW/PNTFlZE8nnMPYqSJUZGEHhjeaw9ipIg=='),{[Mc(32210)]=vb,[Mc(-16826)]=bh,[4]=j,[Mc(31468)]=cg})end)({[-2036]=2,[-21063]=3,[22026]=3,[-22085]=2,[24800]=1,[26410]=1,[-21297]=3,[-15700]=2,[21284]=1,[-1753]=1,[-27010]=2,[-23325]=2,[-4164]=3,[-5621]=2,[8456]=1,[27908]=3,[-15455]=2,[24621]=2})end)()(...)
