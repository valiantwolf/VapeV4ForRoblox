local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local store = {
	attackReach = 0,
	attackReachUpdate = tick(),
	damageBlockFail = tick(),
	hand = {},
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	inventories = {},
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {}
}
local Reach = {}
local HitBoxes = {}
local InfiniteFly = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}

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

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local bowMeta = bedwars.ItemMeta[item.itemType].projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local swordMeta = bedwars.ItemMeta[item.itemType].sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local toolMeta = bedwars.ItemMeta[item.itemType].breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end

local function getWool()
	for _, wool in (inv or store.inventory.inventory.items) do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getStrength(plr)
	if not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end

local function getShieldAttribute(char)
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end

local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	for v in modifiers do
		local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
		if val and val > math.max(multi, 1) then
			increase = false
			multi = val - (0.06 * math.round(val))
		end
	end

	for v in modifiers do
		multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return 20 * (multi + 1)
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
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

local function notif(...) return
	vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function roundPos(vec)
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned and returned.Name ~= 'UpperTorso' or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local sortmethods = {
	Damage = function(a, b)
		return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
	end,
	Threat = function(a, b)
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKit')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKit')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		local selfrootpos = entitylib.character.RootPart.Position
		local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local angle = math.acos(localfacing:Dot(((a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		local angle2 = math.acos(localfacing:Dot(((b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		return angle < angle2
	end
}

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('entity') do
				customEntity(ent)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end

	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end

				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = plr and plr ~= lplr and {
				char:WaitForChild('ArmorInvItem_0', 5),
				char:WaitForChild('ArmorInvItem_1', 5),
				char:WaitForChild('ArmorInvItem_2', 5),
				char:WaitForChild('HandInvItem', 5)
			} or {}

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							task.delay(0.1, function()
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
									if playedanim.Animation.AnimationId == anim then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									end
								end))
							end)
						end

						task.delay(0.1, function()
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
		end

		for name, val in char:GetAttributes() do
			if name:find('Shield') and type(val) == 'number' then
				table.insert(tab, char:GetAttributeChangedSignal(name))
			end
		end

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get

	bedwars = setmetatable({
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8),
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.game.locker['kill-effect'].effects['default-kill-effect']),
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 6),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local remoteNames = {
		AfkStatus = debug.getproto(Knit.Controllers.AfkController.KnitStart, 1),
		AttackEntity = Knit.Controllers.SwordController.sendServerRequest,
		BeePickup = Knit.Controllers.BeeNetController.trigger,
		CannonAim = debug.getproto(Knit.Controllers.CannonController.startAiming, 5),
		CannonLaunch = Knit.Controllers.CannonHandController.launchSelf,
		ConsumeBattery = debug.getproto(Knit.Controllers.BatteryController.onKitLocalActivated, 1),
		ConsumeItem = debug.getproto(Knit.Controllers.ConsumeController.onEnable, 1),
		ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul,
		ConsumeTreeOrb = debug.getproto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1),
		DepositPinata = debug.getproto(debug.getproto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5),
		DragonBreath = debug.getproto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5),
		DragonEndFly = debug.getproto(Knit.Controllers.VoidDragonController.flapWings, 1),
		DragonFly = Knit.Controllers.VoidDragonController.flapWings,
		DropItem = Knit.Controllers.ItemDropController.dropItemInHand,
		EquipItem = debug.getproto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 3),
		FireProjectile = debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2),
		GroundHit = Knit.Controllers.FallDamageController.KnitStart,
		GuitarHeal = Knit.Controllers.GuitarController.performHeal,
		HannahKill = debug.getproto(Knit.Controllers.HannahController.registerExecuteInteractions, 1),
		HarvestCrop = debug.getproto(debug.getproto(Knit.Controllers.CropController.KnitStart, 4), 1),
		KaliyahPunch = debug.getproto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1),
		MageSelect = debug.getproto(Knit.Controllers.MageController.registerTomeInteraction, 1),
		MinerDig = debug.getproto(Knit.Controllers.MinerController.setupMinerPrompts, 1),
		PickupItem = Knit.Controllers.ItemDropController.checkForPickup,
		PickupMetal = debug.getproto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4),
		ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer,
		ResetCharacter = debug.getproto(Knit.Controllers.ResetController.createBindable, 1),
		SpawnRaven = debug.getproto(Knit.Controllers.RavenController.KnitStart, 1),
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack,
		WarlockTarget = debug.getproto(Knit.Controllers.WarlockStaffController.KnitStart, 2)
	}

	local function dumpRemote(tab)
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end

	for i, v in remoteNames do
		local remote = dumpRemote(debug.getconstants(v))
		if remote == '' then
			notif('Vape', 'Failed to grab remote ('..i..')', 10, 'alert')
		end
		remotes[i] = remote
	end

	OldBreak = bedwars.BlockController.isBlockBreakable

	Client.Get = function(self, remoteName)
		local call = OldGet(self, remoteName)

		if remoteName == remotes.AttackEntity then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local suc, plr = pcall(function()
						return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
					end)

					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = tick() + 1

					if Reach.Enabled or HitBoxes.Enabled then
						attackTable.validate.raycast = attackTable.validate.raycast or {}
						attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
					end

					if suc and plr then
						if not select(2, whitelist:get(plr)) then return end
					end

					return call:SendToServer(attackTable, ...)
				end
			}
		elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
			return {SendToServer = function() end}
		end

		return call
	end

	bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
		local obj = bedwars.BlockController:getStore():getBlockAt(breakTable.blockPosition)

		if obj and obj.Name == 'bed' then
			for _, plr in playersService:GetPlayers() do
				if obj:GetAttribute('Team'..(plr:GetAttribute('Team') or 0)..'NoBreak') and not select(2, whitelist:get(plr)) then
					return false
				end
			end
		end

		return OldBreak(self, breakTable, plr)
	end

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	local function getBlockHits(block, blockpos)
		if not block then return 0 end
		local breaktype = bedwars.ItemMeta[block.Name].block.breakType
		local tool = store.tools[breaktype]
		tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
		return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
	end

	--[[
		Pathfinding using a luau version of dijkstra's algorithm
		Source: https://stackoverflow.com/questions/39355587/speeding-up-dijkstras-algorithm-to-solve-a-3d-maze
	]]
	local function calculatePath(target, blockpos)
		if cache[blockpos] then
			return unpack(cache[blockpos])
		end
		local visited, unvisited, distances, air, path = {}, {{0, blockpos}}, {[blockpos] = 0}, {}, {}

		for _ = 1, 10000 do
			local _, node = next(unvisited)
			if not node then break end
			table.remove(unvisited, 1)
			visited[node[2]] = true

			for _, side in sides do
				side = node[2] + side
				if visited[side] then continue end

				local block = getPlacedBlock(side)
				if not block or block:GetAttribute('NoBreak') or block == target then
					if not block then
						air[node[2]] = true
					end
					continue
				end

				local curdist = getBlockHits(block, side) + node[1]
				if curdist < (distances[side] or math.huge) then
					table.insert(unvisited, {curdist, side})
					distances[side] = curdist
					path[side] = node[2]
				end
			end
		end

		local pos, cost = nil, math.huge
		for node in air do
			if distances[node] < cost then
				pos, cost = node, distances[node]
			end
		end

		if pos then
			cache[blockpos] = {
				pos,
				cost,
				path
			}
			return pos, cost, path
		end
	end

	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
		end
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive or InfiniteFly.Enabled then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge

		for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
			local dpos, dcost, dpath = calculatePath(block, v * 3)
			if dpos and dcost < cost then
				cost, pos, target, path = dcost, dpos, v * 3, dpath
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end

			if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4 then
				local breaktype = bedwars.ItemMeta[dblock.Name].block.breakType
				local tool = store.tools[breaktype]
				if tool then
					switchItem(tool.tool)
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end

			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						store.damageBlockFail = tick() + 1
						return
					end

					if effects then
						local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

						if blockhealthbar.blockHealth <= 0 then
							bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
							bedwars.BlockBreaker.healthbarMaid:DoCleaning()
							blockhealthbar.breakingBlockPosition = Vector3.zero
						else
							bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
						end
					end

					if anim then
						local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
						bedwars.ViewmodelController:playAnimation(15)
						task.wait(0.3)
						animation:Stop()
						animation:Destroy()
					end
				end
			end)

			if effects then
				return pos, path, target
			end
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end

		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				vapeEvents.InventoryChanged:Fire()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	updateStore(bedwars.Store:getState(), {})

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		vapeEvents.EntityDamageEvent:Fire({
			entityInstance = ...,
			damage = select(2, ...),
			damageType = select(3, ...),
			fromPosition = select(4, ...),
			fromEntity = select(5, ...),
			knockbackMultiplier = select(6, ...),
			knockbackId = select(7, ...),
			disableDamageHighlight = select(13, ...)
		})
	end))

	for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local data = {
				blockRef = {
					blockPosition = ...,
				},
				player = select(5, ...)
			}
			for i, v in cache do
				if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
					table.clear(v[3])
					table.clear(v)
					cache[i] = nil
				end
			end
			vapeEvents[event]:Fire(data)
		end))
	end

	store.blocks = collection('block', gui)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, gui, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, gui, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			mapname = workspace:WaitForChild('Map', 5):WaitForChild('Worlds', 5):GetChildren()[1].Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	task.spawn(function()
		repeat
			if entitylib.isAlive then
				entitylib.character.AirTime = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and tick() or entitylib.character.AirTime
			end

			for _, v in entitylib.List do
				v.LandTick = math.abs(v.RootPart.Velocity.Y) < 0.1 and v.LandTick or tick()
				if (tick() - v.LandTick) > 0.2 and v.Jumps ~= 0 then
					v.Jumps = 0
					v.Jumping = false
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)

	pcall(function()
		if getthreadidentity and setthreadidentity then
			local old = getthreadidentity()
			setthreadidentity(2)

			bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
			bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
			bedwars.Shop.getShopItem('iron_sword', lplr)

			setthreadidentity(old)
			store.shopLoaded = true
		else
			task.spawn(function()
				repeat
					task.wait(0.1)
				until vape.Loaded == nil or bedwars.AppController:isAppOpen('BedwarsItemShopApp')

				bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
				bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
				store.shopLoaded = true
			end)
		end
	end)

	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil
	end)
end)

run(function()
    local Desync = {}
    local oldroot
    local clone
    local hip = 2.6
    local waitTime

    local function createClone()
        if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 and (not oldroot or not oldroot.Parent) then
            hip = entitylib.character.Humanoid.HipHeight
            oldroot = entitylib.character.HumanoidRootPart
            if not lplr.Character.Parent then return false end
            lplr.Character.Parent = game
            clone = oldroot:Clone()
            clone.Parent = lplr.Character
            oldroot.Transparency = 0
            local highlight = Instance.new("Highlight")
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.OutlineTransparency = 0
            highlight.Parent = oldroot
            oldroot.Parent = gameCamera
            store.rootpart = clone
            bedwars.QueryUtil:setQueryIgnored(oldroot, true)
            lplr.Character.PrimaryPart = clone
            lplr.Character.Parent = workspace
            for _, v in ipairs(lplr.Character:GetDescendants()) do
                if v:IsA("Weld") or v:IsA("Motor6D") then
                    if v.Part0 == oldroot then v.Part0 = clone end
                    if v.Part1 == oldroot then v.Part1 = clone end
                end
            end
            return true
        end
        return false
    end

    local function restoreCharacter()
        if oldroot and oldroot.Parent then
            local hl = oldroot:FindFirstChildOfClass("Highlight")
            if hl then pcall(function() hl:Destroy() end) end
            lplr.Character.Parent = game
            oldroot.Parent = lplr.Character
            lplr.Character.PrimaryPart = oldroot
            lplr.Character.Parent = workspace
            for _, v in ipairs(lplr.Character:GetDescendants()) do
                if v:IsA("Weld") or v:IsA("Motor6D") then
                    if v.Part0 == clone then v.Part0 = oldroot end
                    if v.Part1 == clone then v.Part1 = oldroot end
                end
            end
            entitylib.character.Humanoid.HipHeight = hip or 2.6
            oldroot.Transparency = 1
        end
        if clone and clone.Parent then
            pcall(function() clone:Destroy() end)
            clone = nil
        end
        store.rootpart = nil
        oldroot = nil
    end

    Desync = vape.Categories.Blatant:CreateModule({
        Name = "Desync",
        Tooltip = "Clones character and teleports your real body to it periodically",
        Function = function(call)
            if call then
                if createClone() then
                    local last = 0
                    local conn = runService.Heartbeat:Connect(function()
                        if not Desync.Enabled then return end
                        if not clone or not oldroot or not oldroot.Parent then return end
                        if tick() - last >= waitTime.Value then
                            if entitylib.isAlive then
                                oldroot.CFrame = clone.CFrame
                            end
                            last = tick()
                        end
                    end)
                    Desync:Clean(function()
                        if conn then conn:Disconnect() end
                        restoreCharacter()
                    end)
                else
                    Desync:Toggle(false)
                end
            else
                restoreCharacter()
            end
        end
    })

    waitTime = Desync:CreateSlider({
        Name = "Delay",
        Min = 1,
        Max = 5,
        Default = 1,
        Function = function(val) waitTime.Value = val end
    })
end)
				
run(function()
	local Card: table = {["Enabled"] = false};
	local CardGradient: table = {["Enabled"] = false};
	local Highlight: table = {};
	local HighlightColor: table = {};
	local CardColor: table = {};
	local CardColor2: table = {};
	local Object: table = {};
	local Round: table = {};
	local Font: table = {};
	local FontSetting: table = {["Value"] = Enum.Font.SourceSans};
	local CardFunc: () -> () = function()
		if not lplr.PlayerGui:FindFirstChild('QueueApp') and Card["Enabled"] then 
			return;
		end;
		local card: Frame = lplr.PlayerGui.QueueApp:WaitForChild('1', math.huge);
		local corners: UICorner = card:FindFirstChildOfClass('UICorner') or Instance.new('UICorner', card);
		corners.CornerRadius = UDim.new(0, Round["Value"]);
		card.BackgroundColor3 = Color3.fromHSV(CardColor["Hue"], CardColor["Sat"], CardColor["Value"]);
        	if not table.find(Object, corners) then
            		table.insert(Object, corners);
        	end;

		if Font["Enabled"] then
			for i: any, v: any in next, card:GetDescendants() do
				if v:IsA("TextLabel") or v:IsA("TextButton") then
					v.Font = FontSetting["Value"];
				end;
			end;
		end;
		if Highlight["Enabled"] then 
			local stroke: UIStroke? = card:FindFirstChildOfClass('UIStroke') or Instance.new('UIStroke', card);
			stroke.Thickness = 1.7;
			stroke.Color = Color3.fromHSV(HighlightColor["Hue"], HighlightColor["Sat"], HighlightColor["Value"]);
			if not table.find(Object, stroke) then
				table.insert(Object, stroke);
			end;
		else
			local stroke: UIStroke? = card:FindFirstChildOfClass("UIStroke") or Instance.new('UIStroke', card);
            		if stroke then
                		stroke:Destroy();
            		end;
		end;
		if CardGradient["Enabled"] then
			card.BackgroundColor3 = Color3.fromRGB(255, 255, 255);
			local gradient: UIGradient = card:FindFirstChildWhichIsA('UIGradient') or Instance.new('UIGradient', card);
			gradient.Color = ColorSequence.new({
				[1] = ColorSequenceKeypoint.new(0, Color3.fromHSV(CardColor["Hue"], CardColor["Sat"], CardColor["Value"])), 
				[2] = ColorSequenceKeypoint.new(1, Color3.fromHSV(CardColor2["Hue"], CardColor2["Sat"], CardColor2["Value"]))
			});
			if not table.find(Object, gradient) then
				table.insert(Object, gradient);
			end;
		end;
	end;
	Card = vape.Legit:CreateModule({
		["Name"] = 'QueueCardVisuals',
		["Function"] = function(callback: boolean): void
			if callback then 
				pcall(CardFunc);
				table.insert(Card.Connections, lplr.PlayerGui.ChildAdded:Connect(CardFunc));
			else
                		for _, x in next, Object do
                    			if x and x.Destroy then
                        			x:Destroy();
                    			end;
                		end;
                		Object = {}
                		for _, v in next, Card.Connections do
                    			if v.Disconnect then
                        			v:Disconnect();
                   			end;
                		end;
                		Card.Connections = {};
            		end;
		end;
	});
	CardGradient = Card:CreateToggle({
		["Name"] = 'Gradient',
		["Function"] = function(callback: boolean): void
			pcall(function() CardColor2.Object.Visible = callback end);
		end;
	});
	Round = Card:CreateSlider({
		["Name"] = 'Rounding',
		["Min"] = 0,
		["Max"] = 20,
		["Default"] = 4,
		["Function"] = function(value: number): ()
			for i: number, v: UICorner? in Object do 
				if v.ClassName == 'UICorner' then 
					v.CornerRadius = value;
				end;
			end;
		end;
	})
	CardColor = Card:CreateColorSlider({
		["Name"] = 'Color',
		["Function"] = function()
			task.spawn(pcall, CardFunc);
		end;
	});
	CardColor2 = Card:CreateColorSlider({
		["Name"] = 'Color 2',
		["Function"] = function()
			task.spawn(pcall, CardFunc);
		end;
	});
	Highlight = Card:CreateToggle({
		["Name"] = 'Highlight',
		["Function"] = function()
			task.spawn(pcall, CardFunc);
		end;
	});
	HighlightColor = Card:CreateColorSlider({
		["Name"] = 'Highlight Color',
		["Function"] = function()
			task.spawn(pcall, CardFunc);
		end;
	});
	Font = Card:CreateToggle({
		["Name"] ='Font',
		["HoverText"] = 'custom fonts.',
		["Function"] = function(callback: boolean): void 
			FontSetting.Object.Visible = callback;
		end;
	})
	FontSetting = Card:CreateDropdown({
		["Name"] ="Fonts",
		["List"] = GetItems("Font"),
		["HoverText"] = "Font of the text.",
		["Function"] = function()
			if Card["Enabled"] then
				Card:Toggle();
				Card:Toggle();
			end;
		end;
	});
end);

run(function()
    local AirJump: table = {["Enabled"] = false}
	local Mode: table = {["Value"] = "State"}
	local Power: table = {["Value"] = 50}
	AirJump = vape.Categories.Velocity:CreateModule({
		["Name"] = "AirJump",
      --["HoverText"] = HoverText("Let's you jump in the air."),
		["Function"] = function(callback: boolean): void
			if callback then
				local connection: any = inputService["JumpRequest"]:Connect(function()
					if Mode["Value"] == "State" then
						lplr["Character"]["Humanoid"]:ChangeState("Jumping")
					else
						lplr["Character"]["HumanoidRootPart"]["Velocity"] += Vector3.new(0, Power["Value"], 0)
					end
				end)
                		AirJump["Connection"] = connection
			else
               			 if AirJump["Connection"] then
                    			AirJump["Connection"]:Disconnect()
                    			AirJump["Connection"] = nil
                		end
			end
		end,
        	["Default"] = false,
        	["ExtraText"] = function()
            		return Mode["Value"]
        	end
	})
	Mode = AirJump:CreateDropdown({
		["Name"] = "Mode",
		["List"] = {
			"State",
			"Velocity"
		},
		["Default"] = "State",
		--["HoverText"] = HoverText("Mode to customize the jumping ability."),
		["Function"] = function() end
	})
	Power = AirJump:CreateSlider({
		["Name"] = "Power",
		["Min"] = 1,
		["Max"] = 100,
		--["HoverText"] = HoverText("Power to boost the velocity."),
		["Function"] = function() end,
		["Default"] = 50
	})
end)

run(function()
    local Skybox
    GameThemeV2 = vape.Categories.Render:CreateModule({
        Name = 'GameThemeV2',
        Tooltip = '',
        Function = function(call)
            if call then
                if Skybox.Value == "NebulaSky" then
					local Vignette = true

					local Lighting = game:GetService("Lighting")
					local ColorCor = Instance.new("ColorCorrectionEffect")
					local Sky = Instance.new("Sky")
					local Atm = Instance.new("Atmosphere")
					
					for i, v in pairs(Lighting:GetChildren()) do
						if v then
							v:Destroy()
						end
					end
					
					ColorCor.Parent = Lighting
					Sky.Parent = Lighting
					Atm.Parent = Lighting
					
					if Vignette == true then
						local Gui = Instance.new("ScreenGui")
						Gui.Parent = game:GetService("StarterGui")
						Gui.IgnoreGuiInset = true
					
						local ShadowFrame = Instance.new("ImageLabel")
						ShadowFrame.Parent = Gui
						ShadowFrame.AnchorPoint = Vector2.new(0, 1)
						ShadowFrame.Position = UDim2.new(0, 0, 0, 0)
						ShadowFrame.Size = UDim2.new(0, 0, 0, 0)
						ShadowFrame.BackgroundTransparency = 1
						ShadowFrame.Image = ""
						ShadowFrame.ImageTransparency = 1
						ShadowFrame.ZIndex = 0
					end
					
					ColorCor.Brightness = 0
					ColorCor.Contrast = 0.5
					ColorCor.Saturation = -0.3
					ColorCor.TintColor = Color3.fromRGB(255, 235, 203)
					
					Sky.SkyboxBk = "rbxassetid://13581437029"
					Sky.SkyboxDn = "rbxassetid://13581439832"
					Sky.SkyboxFt = "rbxassetid://13581447312"
					Sky.SkyboxLf = "rbxassetid://13581443463"
					Sky.SkyboxRt = "rbxassetid://13581452875"
					Sky.SkyboxUp = "rbxassetid://13581450222"
					Sky.SunAngularSize = 0
					
					Lighting.Ambient = Color3.fromRGB(2, 2, 2)
					Lighting.Brightness = 1
					Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
					Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
					Lighting.EnvironmentDiffuseScale = 0.2
					Lighting.EnvironmentSpecularScale = 0.2
					Lighting.GlobalShadows = true
					Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
					Lighting.ShadowSoftness = 0.2
					Lighting.ClockTime = 8
					Lighting.GeographicLatitude = 45
					Lighting.ExposureCompensation = 0.5
					
					Atm.Density = 0.364
					Atm.Offset = 0.556
					Atm.Color = Color3.fromRGB(172, 120, 186)
					Atm.Decay = Color3.fromRGB(155, 212, 255)
					Atm.Glare = 0.36
					Atm.Haze = 1.72					
                elseif Skybox.Value == "PinkMountainSky" then
					game.Lighting.Sky.SkyboxBk = "http://www.roblox.com/asset/?id=160188495"
					game.Lighting.Sky.SkyboxDn = "http://www.roblox.com/asset/?id=160188614"
					game.Lighting.Sky.SkyboxFt = "http://www.roblox.com/asset/?id=160188609"
					game.Lighting.Sky.SkyboxLf = "http://www.roblox.com/asset/?id=160188589"
					game.Lighting.Sky.SkyboxRt = "http://www.roblox.com/asset/?id=160188597"
					game.Lighting.Sky.SkyboxUp = "http://www.roblox.com/asset/?id=160188588"
                elseif Skybox.Value == "CitySky" then

					local Vignette = true

					local Lighting = game:GetService("Lighting")
					local ColorCor = Instance.new("ColorCorrectionEffect")
					local Sky = Instance.new("Sky")
					local Atm = Instance.new("Atmosphere")

					game.Lighting.Sky.SkyboxBk = "rbxassetid://11263062161"
					game.Lighting.Sky.SkyboxDn = "rbxassetid://11263065295"
					game.Lighting.Sky.SkyboxFt = "rbxassetid://11263066644"
					game.Lighting.Sky.SkyboxLf = "rbxassetid://11263068413"
					game.Lighting.Sky.SkyboxRt = "rbxassetid://11263069782"
					game.Lighting.Sky.SkyboxUp = "rbxassetid://11263070890"

					Atm.Density = 0.364
					Atm.Offset = 0.556
					Atm.Color = Color3.fromRGB(172, 120, 186)
					Atm.Decay = Color3.fromRGB(155, 212, 255)
					Atm.Glare = 0.36
					Atm.Haze = 1.72		
                elseif Skybox.Value == "PinkSky" then
					game.Lighting.Sky.SkyboxBk = "http://www.roblox.com/asset/?id=271042516"
					game.Lighting.Sky.SkyboxDn = "http://www.roblox.com/asset/?id=271077243"
					game.Lighting.Sky.SkyboxFt = "http://www.roblox.com/asset/?id=271042556"
					game.Lighting.Sky.SkyboxLf = "http://www.roblox.com/asset/?id=271042310"
					game.Lighting.Sky.SkyboxRt = "http://www.roblox.com/asset/?id=271042467"
					game.Lighting.Sky.SkyboxUp = "http://www.roblox.com/asset/?id=271077958"
                elseif Skybox.Value == "EgirlSky" then
					game.Lighting.Sky.SkyboxBk = "rbxassetid://2128458653"
					game.Lighting.Sky.SkyboxDn = "rbxassetid://2128462480"
					game.Lighting.Sky.SkyboxFt = "rbxassetid://2128458653"
					game.Lighting.Sky.SkyboxLf = "rbxassetid://2128462027"
					game.Lighting.Sky.SkyboxRt = "rbxassetid://2128462027"
					game.Lighting.Sky.SkyboxUp = "rbxassetid://2128462236"
					game.Lighting.sky.SunAngularSize = 4
					game.Lighting.sky.MoonTextureId = "rbxassetid://8139665943"
					game.Lighting.sky.MoonAngularSize = 11
					lightingService.Atmosphere.Color = Color3.fromRGB(255, 214, 172)
					lightingService.Atmosphere.Decay = Color3.fromRGB(255, 202, 175)
                elseif Skybox.Value == "SpaceSky" then
					game.Lighting.Sky.SkyboxBk = "rbxassetid://1735468027"
					game.Lighting.Sky.SkyboxDn = "rbxassetid://1735500192"
					game.Lighting.Sky.SkyboxFt = "rbxassetid://1735467260"
					game.Lighting.Sky.SkyboxLf = "rbxassetid://1735467682"
					game.Lighting.Sky.SkyboxRt = "rbxassetid://1735466772"
					game.Lighting.Sky.SkyboxUp = "rbxassetid://1735500898"
				elseif Skybox.Value == "WhiteMountains" then 
					local Vignette = true
					local Lighting = game:GetService("Lighting")
					local ColorCor = Instance.new("ColorCorrectionEffect")
					local SunRays = Instance.new("SunRaysEffect")
					local Sky = Instance.new("Sky")
					local Atm = Instance.new("Atmosphere")
					game.Lighting.Sky.SkyboxBk = "http://www.roblox.com/asset/?id=14365017479"
					game.Lighting.Sky.SkyboxDn = "http://www.roblox.com/asset/?id=14365021997"
					game.Lighting.Sky.SkyboxFt = "http://www.roblox.com/asset/?id=14365016611"
					game.Lighting.Sky.SkyboxLf = "http://www.roblox.com/asset/?id=14365016884"
					game.Lighting.Sky.SkyboxRt = "http://www.roblox.com/asset/?id=14365016261"
					game.Lighting.Sky.SkyboxUp = "http://www.roblox.com/asset/?id=14365017884"
					

					Lighting.Ambient = Color3.fromRGB(2,2,2)
					Lighting.Brightness = 0.3
					Lighting.EnvironmentDiffuseScale = 0.2
					Lighting.EnvironmentSpecularScale = 0.2
					Lighting.GlobalShadows = true
					Lighting.ShadowSoftness = 0.2
					Lighting.ClockTime = 15
					Lighting.GeographicLatitude = 45
					Lighting.ExposureCompensation = 0.5
					Atm.Density = 0.364
					Atm.Offset = 0.556
					Atm.Glare = 0.36
					Atm.Haze = 1.72
                elseif Skybox.Value == "Infinite" then
					game.Lighting.Sky.SkyboxBk = "rbxassetid://14358449723"
					game.Lighting.Sky.SkyboxDn = "rbxassetid://14358455642"
					game.Lighting.Sky.SkyboxFt = "rbxassetid://14358452362"
					game.Lighting.Sky.SkyboxLf = "rbxassetid://14358784700"
					game.Lighting.Sky.SkyboxRt = "rbxassetid://14358454172"
					game.Lighting.Sky.SkyboxUp = "rbxassetid://14358455112"
                end
            end
        end
    })
    Skybox = GameThemeV2:CreateDropdown({
        Name = 'Themes',
        List = {'NebulaSky', "PinkMountainSky", 
		"CitySky", "PinkSky", 
		"EgirlSky", "SpaceSky", "WhiteMountains",
		"Infinite"},
        ["Function"] = function() end
    })
end)

run(function()
    local antihit
    local antihitdelay
    local antihitcloned = false
    local oldroot
    local clone
    local hip
    local antihitting = false
    local lastAntihitting = false

    local function doClone()
        if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 and not antihitcloned then
            hip = entitylib.character.Humanoid.HipHeight
            oldroot = entitylib.character.HumanoidRootPart
            lplr.Character.Parent = game
            clone = oldroot:Clone()
            clone.Parent = lplr.Character
            oldroot.Parent = gameCamera
            bedwars.QueryUtil:setQueryIgnored(oldroot, true)
            clone.CFrame = oldroot.CFrame
            lplr.Character.PrimaryPart = clone
            lplr.Character.Parent = workspace
            for _, v in lplr.Character:GetDescendants() do
                if v:IsA('Weld') or v:IsA('Motor6D') then
                    if v.Part0 == oldroot then v.Part0 = clone end
                    if v.Part1 == oldroot then v.Part1 = clone end
                end
            end
            oldroot.Transparency = 0.5
            antihitcloned = true
        end
    end

    local function revertClone(teleportUp)
        if not antihitcloned or not oldroot or not oldroot.Parent or not entitylib.isAlive then 
            antihitcloned = false 
            return
        end
        lplr.Character.Parent = game
        oldroot.Parent = lplr.Character
        lplr.Character.PrimaryPart = oldroot
        lplr.Character.Parent = workspace
        oldroot.CanCollide = true
        for _, v in lplr.Character:GetDescendants() do
            if v:IsA('Weld') or v:IsA('Motor6D') then
                if v.Part0 == clone then v.Part0 = oldroot end
                if v.Part1 == clone then v.Part1 = oldroot end
            end
        end
        if clone then
            clone:Destroy()
            clone = nil
        end
        if teleportUp then
            oldroot.CFrame = oldroot.CFrame + Vector3.new(0, 6, 0)
        end
        oldroot.Transparency = 1
        oldroot = nil
        entitylib.character.Humanoid.HipHeight = hip or 2
        antihitcloned = false
    end

    local antihitsky = tick()
    antihit = vape.Categories.Blatant:CreateModule({
        Name = 'AntiHit',
        Function = function(call)
            if call then
                antihit:Clean(runService.Heartbeat:Connect(function()
                    if oldroot and oldroot.Parent and antihitcloned then
                        local lastypos
                        if not antihitting then
                            lastypos = clone.CFrame.Y
                        end
                        oldroot.CFrame = antihitting and CFrame.new(clone.CFrame.X, (lastypos or clone.CFrame.Y) + 500, clone.CFrame.Z) or clone.CFrame
                    end
                end))
                repeat
                    if entitylib.isAlive then
                        if store.KillauraTarget then
                            doClone()
                            antihitting = true
                            repeat task.wait() until (tick() - antihitsky) > (0.1 * antihitdelay.Value)
                            antihitsky = tick() + 0.07
                            antihitting = false
                        else
                            antihitting = false
                            revertClone(false)
                        end
                        if lastAntihitting and not antihitting then
                            revertClone(true)
                        end
                        lastAntihitting = antihitting
                    end
                    task.wait(0.2)
                until not antihit.Enabled
            else
                revertClone(false)
            end
        end
    })
    antihitdelay = antihit:CreateSlider({
        Name = 'Sky Delay',
        Min = 1,
        Max = 9,
        Default = 9,
        Function = function() end
    })
end)

-- credits to catvape + render + snoopy + lunar + lunarvape
-- IF YOU WANT THEM REMOVED, TELL ME AND I WILL REMOVE
run(function()
    local texture_pack: table = {["Enabled"] = false};
    local texture_pack_color: table = {["Hue"] = 0, ["Sat"] = 0, ["Value"] = 0};
    local texture_pack_m: table = {};
    texture_pack = vape.Categories.Render:CreateModule({
        ["Name"] ='TexturePack',
        ["HoverText"] = 'Customizes the texture pack.',
        ["Function"] = function(callback: boolean): void
            if callback then
                if texture_pack_m["Value"] == 'Velocity' then
					task.spawn(function()
						local Players: Players = game:GetService("Players")
						local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Workspace: Workspace = game:GetService("Workspace")
						local objs: any = game:GetObjects("rbxassetid://13988978091")
						local import: any = objs[1]
						import.Parent = game:GetService("ReplicatedStorage")
						local index: table? = {
							{
								name = "wood_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},
							{
								name = "stone_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							{
								name = "iron_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							{
								name = "diamond_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							{
								name = "emerald_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Emerald_Sword"),
							},
							{
								name = "wood_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-190), math.rad(-95)),
								model = import:WaitForChild("Wood_Pickaxe"),
							},
							{
								name = "stone_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-190), math.rad(-95)),
								model = import:WaitForChild("Stone_Pickaxe"),
							},
							{
								name = "iron_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-190), math.rad(-95)),
								model = import:WaitForChild("Iron_Pickaxe"),
							},
							{
								name = "diamond_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(80), math.rad(-95)),
								model = import:WaitForChild("Diamond_Pickaxe"),
							},
							{
								name = "wood_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Wood_Axe"),
							},
							{
								name = "stone_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Stone_Axe"),
							},
							{
								name = "iron_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Iron_Axe"),
							},
							{
								name = "diamond_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(-95)),
								model = import:WaitForChild("Diamond_Axe"),
							},
						}
						local func = Workspace.Camera.Viewmodel.ChildAdded:Connect(function(tool)
							if not tool:IsA("Accessory") then
								return
							end
							for _, v in next, index do
								if v.name == tool.Name then
									for _, part in next, tool:GetDescendants() do
										if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
											part.Transparency = 1
										end
									end
									local model = v.model:Clone()
									model.CFrame = tool.Handle.CFrame * v.offset
									model.CFrame = model.CFrame * CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
									model.Parent = tool
									local weld = Instance.new("WeldConstraint")
									weld.Part0 = model
									weld.Part1 = tool.Handle
									weld.Parent = model
									local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
									for _, part in ipairs(tool2:GetDescendants()) do
										if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
											part.Transparency = 1
											if part.Name == "Handle" then
												part.Transparency = 0
											end
										end
									end
								end
							end
						end)
					end)
                elseif texture_pack_m["Value"] == 'Aquarium' then
					task.spawn(function()
						local Players = game:GetService("Players")
						local ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Workspace = game:GetService("Workspace")
						local objs = game:GetObjects("rbxassetid://14217388022")
						local import = objs[1]
						import.Parent = game:GetService("ReplicatedStorage")
						local index = {
						
							{
								name = "wood_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},
							
							{
								name = "stone_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							
							{
								name = "iron_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							
							{
								name = "diamond_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							
							{
								name = "emerald_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							
							{
								name = "Rageblade",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
						}
						local func = Workspace:WaitForChild("Camera").Viewmodel.ChildAdded:Connect(function(tool)
							if(not tool:IsA("Accessory")) then return end
							for i,v in pairs(index) do
								if(v.name == tool.Name) then
									for i,v in pairs(tool:GetDescendants()) do
										if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
											v.Transparency = 1
										end
									end
									local model = v.model:Clone()
									model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
									model.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
									model.Parent = tool
									local weld = Instance.new("WeldConstraint",model)
									weld.Part0 = model
									weld.Part1 = tool:WaitForChild("Handle")
									local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
									for i,v in pairs(tool2:GetDescendants()) do
										if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
											v.Transparency = 1
										end
									end
									local model2 = v.model:Clone()
									model2.Anchored = false
									model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
									model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
									model2.CFrame *= CFrame.new(0.4,0,-.9)
									model2.Parent = tool2
									local weld2 = Instance.new("WeldConstraint",model)
									weld2.Part0 = model2
									weld2.Part1 = tool2:WaitForChild("Handle")
								end
							end
						end)
					end)
                elseif texture_pack_m["Value"] == 'Ocean' then
					task.spawn(function()
						local Players = game:GetService("Players")
						local ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Workspace = game:GetService("Workspace")
						local objs = game:GetObjects("rbxassetid://14356045010")
						local import = objs[1]
						import.Parent = game:GetService("ReplicatedStorage")
						index = {
							{
								name = "wood_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},
							{
								name = "stone_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							{
								name = "iron_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							{
								name = "diamond_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							{
								name = "emerald_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Emerald_Sword"),
							}, 
							{
								name = "rageblade",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(90)),
								model = import:WaitForChild("Rageblade"),
							}, 
							{
								name = "fireball",
										offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Fireball"),
							}, 
							{
								name = "telepearl",
										offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Telepearl"),
							}, 
							{
								name = "wood_bow",
								offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Bow"),
							},
							{
								name = "wood_crossbow",
								offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Crossbow"),
							},
							{
								name = "tactical_crossbow",
								offset = CFrame.Angles(math.rad(0), math.rad(180), math.rad(-90)),
								model = import:WaitForChild("Crossbow"),
							},
								{
								name = "wood_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Wood_Pickaxe"),
							},
							{
								name = "stone_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Stone_Pickaxe"),
							},
							{
								name = "iron_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Iron_Pickaxe"),
							},
							{
								name = "diamond_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(80), math.rad(-95)),
								model = import:WaitForChild("Diamond_Pickaxe"),
							},
						{
									
								name = "wood_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Wood_Axe"),
							},
							{
								name = "stone_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Stone_Axe"),
							},
							{
								name = "iron_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Iron_Axe"),
							},
							{
								name = "diamond_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-95)),
								model = import:WaitForChild("Diamond_Axe"),
							},
						
						
						
						}
						local func = Workspace:WaitForChild("Camera").Viewmodel.ChildAdded:Connect(function(tool)
							if(not tool:IsA("Accessory")) then return end
							for i,v in pairs(index) do
								if(v.name == tool.Name) then
									for i,v in pairs(tool:GetDescendants()) do
										if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
											v.Transparency = 1
										end
									end
									local model = v.model:Clone()
									model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
									model.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
									model.Parent = tool
									local weld = Instance.new("WeldConstraint",model)
									weld.Part0 = model
									weld.Part1 = tool:WaitForChild("Handle")
									local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
									for i,v in pairs(tool2:GetDescendants()) do
										if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
											v.Transparency = 1
										end
									end
									local model2 = v.model:Clone()
									model2.Anchored = false
									model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
									model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
									model2.CFrame *= CFrame.new(.7,0,-.8)
									model2.Parent = tool2
									local weld2 = Instance.new("WeldConstraint",model)
									weld2.Part0 = model2
									weld2.Part1 = tool2:WaitForChild("Handle")
								end
							end
						end)
					end)
                elseif texture_pack_m["Value"] == 'Animated' then
                    task.spawn(function()
                        workspace:WaitForChild("Camera").Viewmodel.ChildAdded:Connect(function(tool)
                            if not tool:IsA("Accessory") then 
                                return 
                            end
                            local handle: any = tool:FindFirstChild("Handle")
                            if handle then
                                if string.find(tool.Name:lower(), 'sword') then
                                    handle.Material = Enum.Material.ForceField
                                    handle.MeshId = "rbxassetid://13471207377"
                                    handle.BrickColor = BrickColor.new("Hot pink")
                                    local outline: Highlight = Instance.new('Highlight')
                                    outline.Adornee = handle 
                                    outline.FillTransparency = 0.5
                                    outline.FillColor = Color3.fromRGB(221, 193, 255) 
                                    outline.OutlineTransparency = 0.2
                                    outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                    outline.Parent = handle
                                    local highlight: Highlight = Instance.new('Highlight')
                                    highlight.Adornee = handle 
                                    highlight.FillTransparency = 0.5
                                    highlight.FillColor = Color3.fromHSV(texture_pack_color["Hue"], texture_pack_color["Sat"], texture_pack_color["Value"])
                                    highlight.OutlineTransparency = 0.2
                                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                    highlight.Parent = handle
                                end
                            end
                        end)
                    end)
				elseif texture_pack_m["Value"] == 'DemonSlayer' then
					task.spawn(function()
						local Players = game:GetService("Players")
						local ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Workspace = game:GetService("Workspace")
						local objs = game:GetObjects("rbxassetid://14241215869")
						local import = objs[1]
						import.Parent = ReplicatedStorage
						local index = {
							{
								name = "wood_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},	
							{
								name = "stone_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							{
								name = "iron_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							{
								name = "diamond_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							{
								name = "emerald_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Emerald_Sword"),
							},
							{
								name = "wood_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Wood_Pickaxe"),
							},
							{
								name = "stone_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Stone_Pickaxe"),
							},
							{
								name = "iron_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Iron_Pickaxe"),
							},
							{
								name = "diamond_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(90), math.rad(-95)),
								model = import:WaitForChild("Diamond_Pickaxe"),
							},	
							{
								name = "fireball",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Fireball"),
							},	
							{
								name = "telepearl",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Telepearl"),
							},
							{
								name = "diamond",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(-90)),
								model = import:WaitForChild("Diamond"),
							},
							{
								name = "iron",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Iron"),
							},
							{
								name = "gold",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Gold"),
							},
							{
								name = "emerald",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(-90)),
								model = import:WaitForChild("Emerald"),
							},
							{
								name = "wood_bow",
								offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Bow"),
							},
							{
								name = "wood_crossbow",
								offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Bow"),
							},
							{
								name = "tactical_crossbow",
								offset = CFrame.Angles(math.rad(0), math.rad(180), math.rad(-90)),
								model = import:WaitForChild("Bow"),
							},
							{
								name = "wood_dao",
								offset = CFrame.Angles(math.rad(0), math.rad(89), math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},
							{
								name = "stone_dao",
								offset = CFrame.Angles(math.rad(0), math.rad(89), math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							{
								name = "iron_dao",
								offset = CFrame.Angles(math.rad(0), math.rad(89), math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							{
								name = "diamond_dao",
								offset = CFrame.Angles(math.rad(0), math.rad(89), math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
						}
						local func = Workspace.Camera.Viewmodel.ChildAdded:Connect(function(tool)	
							if not tool:IsA("Accessory") then return end	
							for _, v in ipairs(index) do	
								if v.name == tool.Name then		
									for _, part in ipairs(tool:GetDescendants()) do
										if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
											part.Transparency = 1
										end			
									end		
									local model = v.model:Clone()
									model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
									model.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
									model.Parent = tool			
									local weld = Instance.new("WeldConstraint", model)
									weld.Part0 = model
									weld.Part1 = tool:WaitForChild("Handle")			
									local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)			
									for _, part in ipairs(tool2:GetDescendants()) do
										if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
											part.Transparency = 1				
										end			
									end			
									local model2 = v.model:Clone()
									model2.Anchored = false
									model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
									model2.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
									if v.name:match("rageblade") then
										model2.CFrame *= CFrame.new(0.7, 0, -.7)                           
									elseif v.name:match("sword") or v.name:match("blade") then
										model2.CFrame *= CFrame.new(.2, 0, -.8)
									elseif v.name:match("dao") then
										model2.CFrame *= CFrame.new(.7, 0, -1.3)
									elseif v.name:match("axe") and not v.name:match("pickaxe") and v.name:match("diamond") then
										model2.CFrame *= CFrame.new(.08, 0, -1.1) - Vector3.new(0, 0, -1.1)
									elseif v.name:match("axe") and not v.name:match("pickaxe") and not v.name:match("diamond") then
										model2.CFrame *= CFrame.new(-.2, 0, -2.4) + Vector3.new(0, 0, 2.12)
									elseif v.name:match("diamond_pickaxe") then
										model2.CFrame *= CFrame.new(.2, 0, -.26)
									elseif v.name:match("iron") and not v.name:match("iron_pickaxe") then
										model2.CFrame *= CFrame.new(0, -.24, 0)
									elseif v.name:match("gold") then
										model2.CFrame *= CFrame.new(0, .03, 0)
									elseif v.name:match("diamond") or v.name:match("emerald") then
										model2.CFrame *= CFrame.new(0, -.03, 0)
									elseif v.name:match("telepearl") then
										model2.CFrame *= CFrame.new(.1, 0, .1)
									elseif v.name:match("fireball") then
										model2.CFrame *= CFrame.new(.28, .1, 0)
									elseif v.name:match("bow") and not v.name:match("crossbow") then
										model2.CFrame *= CFrame.new(-.2, .1, -.05)
									elseif v.name:match("wood_crossbow") and not v.name:match("tactical_crossbow") then
										model2.CFrame *= CFrame.new(-.5, 0, .05)
									elseif v.name:match("tactical_crossbow") and not v.name:match("wood_crossbow") then
										model2.CFrame *= CFrame.new(-.35, 0, -1.2)
									else
										model2.CFrame *= CFrame.new(.0, 0, -.06)
									end
									model2.Parent = tool2
									local weld2 = Instance.new("WeldConstraint", model)
									weld2.Part0 = model2
									weld2.Part1 = tool2:WaitForChild("Handle")
								end
							end
						end)
					end)
				elseif texture_pack_m["Value"] == 'Glizzy' then
					task.spawn(function()
						local Players = game:GetService("Players")
						local ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Workspace = game:GetService("Workspace")
						local objs = game:GetObjects("rbxassetid://13804645310")
						local import = objs[1]
						import.Parent = game:GetService("ReplicatedStorage")
						
						local index = {
							{
								name = "wood_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},
							{
								name = "stone_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							{
								name = "iron_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							{
								name = "diamond_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							{
								name = "emerald_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Emerald_Sword"),
							},
							{
								name = "rageblade",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-270)),
								model = import:WaitForChild("Rageblade"),
							},
						}
						
						local func = Workspace:WaitForChild("Camera").Viewmodel.ChildAdded:Connect(function(tool)
							if not tool:IsA("Accessory") then return end
							for _,v in pairs(index) do
								if v.name == tool.Name then
									for _,v in pairs(tool:GetDescendants()) do
										if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation") then
											v.Transparency = 1
										end
									end
									local model = v.model:Clone()
									model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
									model.CFrame = model.CFrame * CFrame.Angles(math.rad(0), math.rad(100), math.rad(0))
									model.Parent = tool
									local weld = Instance.new("WeldConstraint", model)
									weld.Part0 = model
									weld.Part1 = tool:WaitForChild("Handle")
									
									local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
									for _,v in pairs(tool2:GetDescendants()) do
										if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation") then
											v.Transparency = 1
										end
									end
									local model2 = v.model:Clone()
									model2.Anchored = false
									model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
									model2.CFrame = model2.CFrame * CFrame.Angles(math.rad(0), math.rad(-105), math.rad(0))
									model2.CFrame = model2.CFrame * CFrame.new(-0.4, 0, -0.10)
									model2.Parent = tool2
									local weld2 = Instance.new("WeldConstraint", model2)
									weld2.Part0 = model2
									weld2.Part1 = tool2:WaitForChild("Handle")
								end
							end
						end)					
					end)
				elseif texture_pack_m["Value"] == 'FirstPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/Pack%231"))()  
					end)
				elseif texture_pack_m["Value"] == 'SecondPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/Pack%232"))()  
					end)
				elseif texture_pack_m["Value"] == 'ThirdPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/Modules/main/TexturePack"))()  
					end)
				elseif texture_pack_m["Value"] == 'FourthPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/Pack%234"))()  
					end)
				elseif texture_pack_m["Value"] == 'FifthPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/Pack%235"))()  
					end)
				elseif texture_pack_m["Value"] == 'SixthPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/Pack%236"))()  
					end)
				elseif texture_pack_m["Value"] == 'SeventhPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/Pack%237"))()  
					end)
				elseif texture_pack_m["Value"] == 'EighthPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/1024xPack"))()  
					end)
				elseif texture_pack_m["Value"] == 'EgirlPack' then
					task.spawn(function() 	
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/E-Girl"))()  		             
					end)
				elseif texture_pack_m["Value"] == 'CottonCandy' then
					task.spawn(function() 
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/CottonCandy256x"))()           
					end)
				elseif texture_pack_m["Value"] == 'PrivatePack' then
					task.spawn(function()
						local Players = game:GetService("Players")
						local ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Workspace = game:GetService("Workspace")
						local objs = game:GetObjects("rbxassetid://14161283331")
						local import = objs[1]
						import.Parent = ReplicatedStorage
						local index = {
							{
								name = "wood_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},	
							{
								name = "stone_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							{
								name = "iron_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							{
								name = "diamond_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							{
								name = "emerald_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Emerald_Sword"),
							},
							{
								name = "rageblade",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(90)),
								model = import:WaitForChild("Rageblade"),
							}, 
							{
								name = "wood_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Wood_Pickaxe"),
							},
							{
								name = "stone_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Stone_Pickaxe"),
							},
							{
								name = "iron_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-18033), math.rad(-95)),
								model = import:WaitForChild("Iron_Pickaxe"),
							},
							{
								name = "diamond_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(80), math.rad(-95)),
								model = import:WaitForChild("Diamond_Pickaxe"),
							},	
							{
								name = "wood_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Wood_Axe"),
							},	
							{
								name = "stone_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Stone_Axe"),
							},	
							{
								name = "iron_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Iron_Axe"),
							},	
							{
								name = "diamond_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-95)),
								model = import:WaitForChild("Diamond_Axe"),
							},	
							{
								name = "fireball",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Fireball"),
							},	
							{
								name = "telepearl",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Telepearl"),
							},
							{
								name = "diamond",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Diamond"),
							},
							{
								name = "iron",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Iron"),
							},
							{
								name = "gold",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Gold"),
							},
							{
								name = "emerald",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Emerald"),
							},
							{
								name = "wood_bow",
								offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Bow"),
							},
							{
								name = "wood_crossbow",
								offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Bow"),
							},
							{
								name = "tactical_crossbow",
								offset = CFrame.Angles(math.rad(0), math.rad(180), math.rad(-90)),
								model = import:WaitForChild("Bow"),
							},
						}
						local func = Workspace.Camera.Viewmodel.ChildAdded:Connect(function(tool)	
							if not tool:IsA("Accessory") then return end	
							for _, v in ipairs(index) do	
								if v.name == tool.Name then		
									for _, part in ipairs(tool:GetDescendants()) do
										if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
											part.Transparency = 1
										end			
									end		
									local model = v.model:Clone()
									model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
									model.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
									model.Parent = tool			
									local weld = Instance.new("WeldConstraint", model)
									weld.Part0 = model
									weld.Part1 = tool:WaitForChild("Handle")			
									local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)			
									for _, part in ipairs(tool2:GetDescendants()) do
										if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
											part.Transparency = 1				
										end			
									end			
									local model2 = v.model:Clone()
									model2.Anchored = false
									model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
									model2.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
									if v.name:match("rageblade") then
										model2.CFrame *= CFrame.new(0.7, 0, -1)                           
									elseif v.name:match("sword") or v.name:match("blade") then
										model2.CFrame *= CFrame.new(.6, 0, -1.1) - Vector3.new(0, 0, -.3)
									elseif v.name:match("axe") and not v.name:match("pickaxe") and v.name:match("diamond") then
										model2.CFrame *= CFrame.new(.08, 0, -1.1) - Vector3.new(0, 0, -1.1)
									elseif v.name:match("axe") and not v.name:match("pickaxe") and not v.name:match("diamond") then
										model2.CFrame *= CFrame.new(-.2, 0, -2.4) + Vector3.new(0, 0, 2.12)
									elseif v.name:match("iron") then
										model2.CFrame *= CFrame.new(0, -.24, 0)
									elseif v.name:match("gold") then
										model2.CFrame *= CFrame.new(0, .03, 0)
									elseif v.name:match("diamond") then
										model2.CFrame *= CFrame.new(0, .027, 0)
									elseif v.name:match("emerald") then
										model2.CFrame *= CFrame.new(0, .001, 0)
									elseif v.name:match("telepearl") then
										model2.CFrame *= CFrame.new(.1, 0, .1)
									elseif v.name:match("fireball") then
										model2.CFrame *= CFrame.new(.28, .1, 0)
									elseif v.name:match("bow") and not v.name:match("crossbow") then
										model2.CFrame *= CFrame.new(-.29, .1, -.2)
									elseif v.name:match("wood_crossbow") and not v.name:match("tactical_crossbow") then
										model2.CFrame *= CFrame.new(-.6, 0, 0)
									elseif v.name:match("tactical_crossbow") and not v.name:match("wood_crossbow") then
										model2.CFrame *= CFrame.new(-.5, 0, -1.2)
									else
										model2.CFrame *= CFrame.new(.2, 0, -.2)
									end
									model2.Parent = tool2
									local weld2 = Instance.new("WeldConstraint", model)
									weld2.Part0 = model2
									weld2.Part1 = tool2:WaitForChild("Handle")
								end
							end
						end)            
					end)
				elseif texture_pack_m["Value"] == 'FirstHighResPack' then	
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/512xPack"))()   
					end)
				elseif texture_pack_m["Value"] == 'SecondHighResPack' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/1024xPack"))()   
					end)
				elseif texture_pack_m["Value"] == 'FatCat' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/"..Pack.Value..".lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Simply' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Simply.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'VioletsDreams' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/VioletsDreams.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Enlightened' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Enlightened.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Onyx' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Onyx.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Fury' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Fury.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Wichtiger' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Wichtiger.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Makima' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Makima.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Marin-Kitsawaba' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Marin-Kitsawaba.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Prime' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Prime.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Vile' then	
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Vile.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Devourer' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Devourer.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Acidic' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Acidic.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Moon4Real' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Moon4Real.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Nebula' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Nebula.lua"))()
					end)
				else
					local connect: any;
					local pack: any = game:GetObjects("rbxassetid://14027120450");
					local txtpack: any = unpack(pack)
					txtpack.Parent = game:GetService("ReplicatedStorage")
					connect = workspace.Camera.Viewmodel.DescendantAdded:Connect(function(d)
						for i,v in next, txtpack:GetChildren() do
							if v.Name == d.Name then
								for i1,v1 in next, d:GetDescendants() do
									if v1:IsA("Part") or v1:IsA("MeshPart") then
										v1.Transparency = 1
									end
								end
								for i1,v1 in next, lplr.Character:GetChildren() do
									if v1.Name == v.Name then
										for i2,v2 in next, v1:GetDescendants() do
											if v2.Name ~= d.Name then
												if v2:IsA("Part") or v2:IsA("MeshPart") then
													v2.Transparency = 1;
												end;
											end;
										end;
									end;
								end;
								local handle: Handle? = d:FindFirstChild("Handle");
								if handle and handle:IsA("BasePart") then
									local vmmodel: any = v:Clone();
									vmmodel.CFrame = handle.CFrame * CFrame.Angles(math.rad(90), math.rad(-130), 0);
									if d.Name == "rageblade" then
										vmmodel.CFrame = CFrame.Angles(math.rad(-80), math.rad(230), math.rad(10));
									end;
									vmmodel.Parent = d;
									local vmmodelweld: WeldConstraint = Instance.new("WeldConstraint", vmmodel);
									vmmodelweld.Part0 = vmmodel;
									vmmodelweld.Part1 = handle;
									local charPart: any = lplr.Character:FindFirstChild(d.Name);
									local charHandle: any = charPart and charPart:FindFirstChild("Handle");
									if charHandle and charHandle:IsA("BasePart") then
										local charmodel: any = v:Clone();
										charmodel.CFrame = charHandle.CFrame * CFrame.Angles(math.rad(90), math.rad(-130), 0);
										if d.Name == "rageblade" then
											charmodel.CFrame = CFrame.Angles(math.rad(-80), math.rad(230), math.rad(10));
										end;
										charmodel.Anchored = false;
										charmodel.CanCollide = false;
										charmodel.Parent = charPart;
										local charmodelweld: WeldConstraint = Instance.new("WeldConstraint", charmodel);
										charmodelweld.Part0 = charmodel;
										charmodelweld.Part1 = charHandle;
									end;
								end;
							end;
						end;
					end);
				end;
			end;
		end;
    })
    texture_pack_m = texture_pack:CreateDropdown({
        ["Name"] ='Mode',
        ["List"] = {
            'Velocity',
			"FirstPack", 
			"SecondPack", 
			"ThirdPack", 
			"FourthPack", 
			"FifthPack", 
			"SixthPack", 
			"SeventhPack",
			"EighthPack", 
			"EgirlPack", 
			"CottonCandy", 
			"Pack512x", 
			"Pack1056x",
	        "PrivatePack",
            'Aquarium',
            'Ocean',
            'Animated',
			'DemonSlayer',
			'Glizzy',
			'FatCat',
			'Simply',
			'VioletsDreams',
			'Enlightened',
			"Onyx", 
			"Fury", 
			"Wichtiger", 
			"Makima", 
			"Marin-Kitsawaba", 
			"Prime", 
			"Vile", 
			"Devourer", 
			"Acidic", 
			"Moon4Real", 
			"Nebula",
			'Lunar'
        },
        ["Default"] ='Velocity',
        ["HoverText"] = 'Mode to render the texture pack, credits to Snoopy and CatVape.',
        ["Function"] = function() end
    })
    texture_pack_color = texture_pack:CreateColorSlider({
        ["Name"] ="Animated Color",
        ["HoverText"] = "Color of the ANIMATED texturepack.",
        ["Function"] = function() end
    })
end)
