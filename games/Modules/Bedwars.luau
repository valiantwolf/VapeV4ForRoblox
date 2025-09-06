run(function()
	local InfiniteJump = {Enabled = false}
	local Mode = {Value = "State"}
	local Power = {Value = 50}
	InfiniteJump = vape.Categories.Blatant:CreateModule({
		Name = "InfiniteJump",
		HoverText = HoverText("Let's you jump in the air."),
		Function = function(callback)
			if callback then
				local connection = inputService.JumpRequest:Connect(function()
					if Mode.Value == "State" then
						lplr.Character.Humanoid:ChangeState("Jumping")
					else
						lplr.Character.HumanoidRootPart.Velocity += Vector3.new(0, Power.Value, 0)
					end
				end)
				AirJump.Connection = connection
			else
				if AirJump.Connection then
					AirJump.Connection:Disconnect()
					AirJump.Connection = nil
				end
			end
		end,
		Default = false,
		ExtraText = function()
			return Mode.Value
		end
	})
	Mode = InfiniteJump:CreateDropdown({
		Name = "Mode",
		List = {
			"State",
			"Velocity"
		},
		Default = "State",
		HoverText = HoverText("Mode to customize the jumping ability."),
		Function = function() end
	})
	Power = InfiniteJump:CreateSlider({
		Name = "Power",
		Min = 1,
		Max = 100,
		HoverText = HoverText("Power to boost the velocity."),
		Function = function() end,
		Default = 50
	})
end)

local FlyLandTick = tick()
local InfiniteFly = {}
local performanceStats = game:GetService('Stats'):FindFirstChild('PerformanceStats')
run(function()
	local FlySpeed
	local VerticalSpeed
	local SafeMode

	local rayCheck = RaycastParams.new()
	local oldroot
	local clone

	local hip = 2.6

	local function createClone()
		if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 and (not oldroot or not oldroot.Parent) then
			hip = entitylib.character.Humanoid.HipHeight
			oldroot = entitylib.character.HumanoidRootPart
			if not lplr.Character.Parent then return false end
			lplr.Character.Parent = game
			clone = oldroot:Clone()
			clone.Parent = lplr.Character
			--oldroot.CanCollide = false
			oldroot.Transparency = 1
			Instance.new('Highlight', oldroot)
			oldroot.Parent = gameCamera
			store.rootpart = clone
			bedwars.QueryUtil:setQueryIgnored(oldroot, true)
			lplr.Character.PrimaryPart = clone
			lplr.Character.Parent = workspace
			for _, v in lplr.Character:GetDescendants() do
				if v:IsA('Weld') or v:IsA('Motor6D') then
					if v.Part0 == oldroot then v.Part0 = clone end
					if v.Part1 == oldroot then v.Part1 = clone end
				end
			end
			return true
		end
		return false
	end

	local function destroyClone()
		if not oldroot or not oldroot.Parent or not entitylib.isAlive then return false end
		lplr.Character.Parent = game
		oldroot.Parent = lplr.Character
		lplr.Character.PrimaryPart = oldroot
		lplr.Character.Parent = workspace
		for _, v in lplr.Character:GetDescendants() do
			if v:IsA('Weld') or v:IsA('Motor6D') then
				if v.Part0 == clone then v.Part0 = oldroot end
				if v.Part1 == clone then v.Part1 = oldroot end
			end
		end
		oldroot.CanCollide = true
		if clone then
			clone:Destroy()
			clone = nil
		end
		entitylib.character.Humanoid.HipHeight = hip or 2.6
		oldroot.Transparency = 1
		oldroot = nil
		store.rootpart = nil
		FlyLandTick = tick() + 0.01
	end

	local up = 0
	local down = 0
	local startTick = tick()

	InfiniteFly = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteFly',
		Tooltip = 'Makes you go zoom.',
		Function = function(callback)
			if callback then
				task.wait()
				startTick = tick()
				if not entitylib.isAlive or FlyLandTick > tick() or not isnetworkowner(entitylib.character.RootPart) then
					return InfiniteFly:Toggle()
				end
				local a, b = pcall(createClone)
				if not a then
					return InfiniteFly:Toggle()
				end
				rayCheck.FilterDescendantsInstances = {lplr.Character, oldroot, clone, gameCamera}
				InfiniteFly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
							up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
							down = -1
						end
					end
				end))
				InfiniteFly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
						down = 0
					end
				end))

				local lastY = entitylib.character.RootPart.Position.Y
				local lastVelo = 0
				local cancelThread = false
				InfiniteFly:Clean(runService.PreSimulation:Connect(function(delta)
					if not entitylib.isAlive or not clone or not clone.Parent or not isnetworkowner(oldroot) or (workspace:GetServerTimeNow() - lplr:GetAttribute('LastTeleported')) < 2 then
						if not isnetworkowner(oldroot) then
							--notif('InfiniteFly', 'Flag detected, Landing', 1.1, 'alert')
						end
						return InfiniteFly:Toggle()
					end
					FlyLandTick = tick() + 0.1
					local mass = 1.3 + ((up + down) * VerticalSpeed.Value)
					local moveDir = entitylib.character.Humanoid.MoveDirection
					local velo = getSpeed()
					local destination = (moveDir * math.max(FlySpeed.Value - velo, 0) * delta)
					clone.CFrame = clone.CFrame + destination
					clone.AssemblyLinearVelocity = (moveDir * velo) + Vector3.new(0, mass, 0)

					rayCheck.FilterDescendantsInstances = {lplr.Character, oldroot, clone, gameCamera}

					local raycast = workspace:Blockcast(oldroot.CFrame + Vector3.new(0, 250, 0), Vector3.new(3, 3, 3), Vector3.new(0, -500, 0), rayCheck)
					local groundcast = workspace:Blockcast(clone.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, -3, 0), rayCheck)
					local upperRay = not workspace:Blockcast(oldroot.CFrame + (oldroot.CFrame.LookVector * 17), Vector3.new(3, 3, 3), Vector3.new(0, -150, 0), rayCheck) and workspace:Blockcast(oldroot.CFrame + (oldroot.CFrame.LookVector * 17), Vector3.new(3, 3, 3), Vector3.new(0, 150, 0), rayCheck)

					local changeYLevel = 300
					local yLevel = 0

					if lastVelo - oldroot.AssemblyLinearVelocity.Y > 1200 then
						oldroot.CFrame = oldroot.CFrame + Vector3.new(0, 200, 0)
					end

					for i,v in {50, 1000, 2000, 3000, 4000, 5000, 6000, 7000} do
						if oldroot.AssemblyLinearVelocity.Y < -v then
							changeYLevel = changeYLevel + 100
							yLevel = yLevel - 15
						end
					end

					lastVelo = oldroot.AssemblyLinearVelocity.Y

					if raycast then
						oldroot.AssemblyLinearVelocity = Vector3.zero
						oldroot.CFrame = groundcast and clone.CFrame or CFrame.lookAlong(Vector3.new(clone.Position.X, raycast.Position.Y + hip, clone.Position.Z), clone.CFrame.LookVector)
					elseif (oldroot.Position.Y < (lastY - (200 + yLevel))) and not cancelThread and (oldroot.AssemblyLinearVelocity.Y < -200 or not upperRay) then
						if upperRay then
							oldroot.CFrame = CFrame.lookAlong(Vector3.new(oldroot.CFrame.X, upperRay.Position.Y, oldroot.CFrame.Z), clone.CFrame.LookVector)
						else
							oldroot.CFrame = oldroot.CFrame + Vector3.new(0, changeYLevel, 0)
						end
						if oldroot.AssemblyLinearVelocity.Y < -800 then
							oldroot.AssemblyLinearVelocity = oldroot.AssemblyLinearVelocity + Vector3.new(0, 1, 0)
						end
					end

					oldroot.CFrame = CFrame.lookAlong(Vector3.new(clone.Position.X, oldroot.Position.Y, clone.Position.Z), clone.CFrame.LookVector)
				end))
			else
				--notif('InfiniteFly', tostring(tick() - startTick):sub(1, 4).. 's', 4, 'alert')
				if (SafeMode.Enabled and (tick() - startTick) > 3) or performanceStats.Ping:GetValue() > 180 then
					oldroot.CFrame = CFrame.new(-9e9, 0, -9e9)
					clone.CFrame = CFrame.new(-9e9, 0, -9e9)
				end
				destroyClone()
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end
	})
	FlySpeed = InfiniteFly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23
	})
	VerticalSpeed = InfiniteFly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 70
	})
	SafeMode = InfiniteFly:CreateToggle({
		Name = 'Safe Mode'
	})
end)																																																																																																																				

run(function()
	local antihit
	local antihitdelay
	local antihitcloned = false
	local oldroot
	local clone
	local hip
	local function doClone()
		if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 and not antihitcloned then
			hip = entitylib.character.Humanoid.HipHeight
			oldroot = entitylib.character.HumanoidRootPart
			lplr.Character.Parent = workspace.Parent
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
	
	local function revertClone()
		if not antihitcloned or not oldroot or not oldroot.Parent or not entitylib.isAlive then 
			antihitcloned = false 
			return
		end
		lplr.Character.Parent = workspace.Parent
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
		oldroot.Transparency = 1
		oldroot = nil
		entitylib.character.Humanoid.HipHeight = hip or 2
	end
	local antihitting = false
	local antihitsky = tick()
	antihit = vape.Categories.Blatant:CreateModule({
		Name = 'AntiHit',
		Function = function(call)
			if call then
				local lastypos
				antihit:Clean(runService.Heartbeat:Connect(function()
					if oldroot and oldroot.Parent and antihitcloned then
						if not antihitting then
							lastypos = clone.CFrame.Y
						end
						oldroot.CFrame = antihitting and CFrame.new(clone.CFrame.X, lastypos + -100, clone.CFrame.Z) or clone.CFrame
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
							revertClone()
						end
					end
					task.wait(0.2)
				until not antihit.Enabled
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
