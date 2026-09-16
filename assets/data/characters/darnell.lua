local animations = {
	["weekend-1-lightcan"] = "lightCan",
	["weekend-1-kickcan"] = "kickCan",
	["weekend-1-kneecan"] = "kneeCan"
}
local specialAnimations = {lightCan = true, kickCan = true, kneeCan = true}

function onNoteHit(event)
	if event.cancelled or event.character ~= self or event.note.wasGoodHit then return end
	local name = animations[event.note.type]
	if name then
		event:cancelAnim()
		self.lastHit = -math.huge
		self:playAnim(name, true, nil, true)
	elseif self.waitingFinish and specialAnimations[self.anim.curAnim.name] then
		event:cancelAnim()
	end
end
