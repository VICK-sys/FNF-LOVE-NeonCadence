local root = love.filesystem.getWorkingDirectory()
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

function love.load()
	local ok, err = xpcall(function()
		dofile(root .. "/tests/freeplay/fixtures.lua")
		dofile(root .. "/tests/freeplay/spec.lua")
	end, debug.traceback)
	if not ok then print(err) end
	love.event.quit(ok and 0 or 1)
end
