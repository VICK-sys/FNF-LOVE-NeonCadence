local Spraycan = AnimateAtlas:extend("Spraycan")
local assetPath = "stages/phillyStreets/"
local bounds

function Spraycan:new(x, y, spawnExplosion)
	Spraycan.super.new(self, x, y, paths.getAnimateAtlas(assetPath .. "spraycanAtlas"))
	self.spawnExplosion = spawnExplosion
	self.currentState = "arcing"
	self.exploded = false

	if not bounds then
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for frame = 0, self.library:getLength() - 1 do
			self.frame = frame
			local left, top = self:getBoundTopLeft()
			local width, height = self:getBoundDimensions()
			if width > 0 and height > 0 then
				minX, minY = math.min(minX, left), math.min(minY, top)
				maxX, maxY = math.max(maxX, left + width), math.max(maxY, top + height)
			end
		end
		bounds = {minX, minY, maxX - minX, maxY - minY}
	end
	self.offset:set(bounds[1], bounds[2])
	self.width, self.height = bounds[3], bounds[4]
	self.origin:set(0, 0)

	for _, name in ipairs({"Can Start", "Can Shot", "Hit Pico"}) do
		self.animation:addFromLibrary(name, name, "", 24, false)
	end
	self.animation:play("Can Start")
end

function Spraycan:shoot()
	if self.currentState ~= "arcing" or not self.exists then return end
	self.currentState = "shot"
	self.animation:play("Can Shot", true)
end

function Spraycan:miss()
	if self.currentState == "arcing" then self.currentState = "impacted" end
end

function Spraycan:explode(hitPico)
	if self.exploded then return end
	self.exploded = true
	local explosion = Sprite(self.x + (hitPico and 750 or 150), self.y - (hitPico and 100 or 250))
	explosion:setFrames(paths.getSparrowAtlas(assetPath .. (hitPico and "spraypaintExplosionEZ" or "SpraypaintExplosion")))
	explosion.animation:addByPrefix("explode", hitPico and "explosion round 1 short0" or "Explosion 1 movie0", 24, false)
	explosion.animation.onFinish:add(function() explosion:kill() end)
	explosion.animation:play("explode")
	self.spawnExplosion(explosion)
end

function Spraycan:update(dt)
	Spraycan.super.update(self, dt)
	local animation = self.animation.curAnim
	if animation.name == "Can Shot" and animation.frame >= 4 then self:explode(false) end
	if animation.finished then
		if animation.name == "Can Start" then
			self.animation:play("Hit Pico")
		else
			if animation.name == "Hit Pico" then self:explode(true) end
			self:kill()
		end
	end
end

return Spraycan
