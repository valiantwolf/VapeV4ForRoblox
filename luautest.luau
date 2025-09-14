
local part: BasePart = Instance.new("Part")
part.Size = Vector3.new(4, 1, 4)
part.Position = Vector3.new(0, 5, 0)
part.Anchored = true
part.Transparency = 1
part.Parent = workspace

local bounceHeight: number = 5
local bounceSpeed: number = 2

local function bounce(t: number): Vector3
    return Vector3.new(0, 5 + math.sin(t * bounceSpeed) * bounceHeight, 0)
end

spawn(function()
    local startTime: number = tick()
    while true do
        part.Position = bounce(tick() - startTime)
        wait(0.03)
    end
end)
