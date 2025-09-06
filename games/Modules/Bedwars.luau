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
