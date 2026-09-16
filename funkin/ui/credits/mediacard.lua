local MediaCard = Graphic:extend("MediaCard")

function MediaCard:new(x, y, icon, text, color)
	MediaCard.super.new(self, x, y)

	self.icon = icon
	self.text = text

	self.color = color or {0.5, 0.5, 0.5}
	self.config.round = {16, 16}
end

function MediaCard:setSize(width, height)
	self.width, self.height = width, height

	self.icon.x, self.icon.y = 10, (self.height - self.icon.height) / 2

	self.text.x, self.text.y = self.icon.x + self.icon.width + 10,
		(self.height - self.text:getHeight()) / 2
	self.text.limit = (self.width - self.icon.width) - 30
end

function MediaCard:update(dt)
	MediaCard.super.update(self, dt)
	self.icon:update(dt)
	self.text:update(dt)
end

function MediaCard:__render(camera)
	MediaCard.super.__render(self, camera)

	for _, member in ipairs({self.icon, self.text}) do
		local x, y = member.x, member.y
		member.x, member.y = self.x + x, self.y + y
		member.scrollFactor = self.scrollFactor
		member:__render(camera)
		member.x, member.y = x, y
	end
end

return MediaCard
