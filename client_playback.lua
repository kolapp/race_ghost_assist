﻿----------------------------------------------------------------------------------------------------
-- Important variables
----------------------------------------------------------------------------------------------------
g_Root = getRootElement()

local nextNode = nil -- !!!
local prev, curr
local node1, node2
local lastNodeID = 1 -- gotta start at 1
local nextNodeID = 1 -- gotta start at 1

local id, idx
local x, y, z
local xx, yy, zz
local xx2, yy2, zz2
local rx, ry, rz
-- Letter "g" stands for "ground".
local gx, gy, gz

local ghost_speed
local my_speed
local my_dst
local prev_dst = math.huge
local dst = 0

local vehicle
local vType
local color_r, color_g, color_b, color_a
local my_weight = 1500
local arrowSize = 2

local drawRacingLine_HANDLER = nil
local assistTimer = nil
local recording = nil
local img = dxCreateTexture("img/arrow.png")

-- trying to buy some time
local sin = math.sin
local cos = math.cos
local rad = math.rad
local abs = math.abs


----------------------------------------------------------------------------------------------------
-- racing lines local/server mode
function assistMode(player, mode)
	Settings["mode"] = mode
	outputDebug("mode changed to: ".. inspect(Settings["mode"]))
	saveSettings()
end
addCommandHandler('assistmode', assistMode)


----------------------------------------------------------------------------------------------------
-- racing lines toggle on/off
function assistToggle(player, mode)
	mode = tonumber(mode)

	-- assist on/off
	if mode == 0 then
		outputChatBox("[Racing Assist] #ffffffby disabled.", 255, 170, 64, true)
		Settings["enable"] = "off"
		if recording then hide() end
		-- TODO: exports.messages:outputGameMessage("Racing assist disabled", g_Root, 2, 230, 220, 180)

	-- assist on
	else --if mode == anything
		outputChatBox("[Racing Assist] #ffffffby #ffaa40fak #ffffffstarted.", 255, 170, 64, true)
		Settings["enable"] = "on"
		if recording then
			show()
		else
			-- inform if no ghost is available when turning on
			outputChatBox("[Racing Assist] #ffffffLaunching on the next map.", 255, 170, 64, true)
		end
		-- TODO: exports.messages:outputGameMessage("Racing assist enabled", g_Root, 2, 230, 220, 180)
	end -- mode

	saveSettings()

	-- outputDebug("racing assist: ".. inspect(Settings["enable"])) -- DEBUG
end -- assistToggle
addCommandHandler('assist', assistToggle)


----------------------------------------------------------------------------------------------------
-- show the racing line
function show()
	if not drawRacingLine_HANDLER then
		drawRacingLine_HANDLER = function() drawRacingLine() end
		addEventHandler("onClientPreRender", g_Root, drawRacingLine_HANDLER)
		-- outputDebug("Racingline showing")
	end
end


----------------------------------------------------------------------------------------------------
-- hide the racing line
function hide()
	-- used for planes or when the line is too far
	if drawRacingLine_HANDLER then
		removeEventHandler("onClientPreRender", g_Root, drawRacingLine_HANDLER)
		drawRacingLine_HANDLER = nil
		-- outputDebug("Racingline hidden")
	end
end


----------------------------------------------------------------------------------------------------
-- cleanup at finish/map change
function destroy()
	-- who triggered it?
	outputDebug("@destroy, source: " .. inspect(eventName))

	-- must have
	if isTimer(assistTimer) then
		killTimer(assistTimer)
		assistTimer = nil
	end

	if drawRacingLine_HANDLER then
		removeEventHandler("onClientPreRender", g_Root, drawRacingLine_HANDLER)
		drawRacingLine_HANDLER = nil
		outputDebug("Racingline destroyed")
	end

	recording = nil
end -- destroy

addEventHandler(
	"onClientResourceStart",
	getRootElement(),
    function(startedRes)
		if startedRes == getThisResource() then
			-- !!!
			loadSettings()
			outputDebug("onClientResourceStart")
			addEventHandler("onClientPlayerFinish", g_Root, destroy)
			-- TODO: THIS DELETES MY GHOST AT THE WRONG TIME
			-- addEventHandler("onClientMapStopping", g_Root, destroy)
		end
    end
)


----------------------------------------------------------------------------------------------------
function loadGhost(mapName)

	-- race_ghost is required to run
	if not getResourceFromName("race_ghost") then
		outputChatBox("[Racing Assist] #ffffffPlease start the race_ghost resource.", 255, 170, 64, true)
		return false
	end

	-- local ghosts are in the "race_ghost" resource!
	local ghost = xmlLoadFile(":race_ghost/ghosts/" .. mapName .. ".ghost")
	outputDebug("@loadGhost: " .. inspect(ghost)) -- DEBUG

	if ghost then
		-- Construct a table
		local index = 0
		local node = xmlFindChild(ghost, "n", index)
		local recording = {}

		while (node) do
			if type(node) ~= "userdata" then
				outputDebugString("race_ghost - playback_local_client.lua: Invalid node data while loading ghost: " .. type(node) .. ":" .. tostring(node), 1)
				break
			end

			local attributes = xmlNodeGetAttributes(node)
			local row = {}
			for k, v in pairs(attributes) do
				row[k] = convert(v)
			end

			-- !!!
			-- we only need "po" data
			if (row.ty == "po") then
				table.insert(recording, row)
				-- outputDebug("row: " .. inspect(row)) -- DEBUG
			end

			index = index + 1
			node = xmlFindChild(ghost, "n", index)
		end -- while

		-- Retrieve info about the ghost
		-- outputDebug("Found a valid local ghost for " .. mapName)
		-- local info = xmlFindChild(ghost, "i", 0)
		-- outputChatBox("* Race assist loaded. (" ..xmlNodeGetAttribute(info, "r").. ") " ..FormatDate(xmlNodeGetAttribute(info, "timestamp")), 0, 255, 0)

		-- TODO: exports.messages:outputGameMessage("Racing assist loaded", g_Root, 2, 230, 220, 180, true)
		-- outputChatBox("* Racing assist loaded.", 230, 220, 180)

		xmlUnloadFile(ghost)
		return recording
	else
		outputDebug("loading ghost failed") -- DEBUG
		outputChatBox("[Racing Assist] #ffffffGhost for this map was not found.", 255, 170, 64, true)
		return false
	end -- ghost

end -- loadGhost


----------------------------------------------------------------------------------------------------
-- setup ghost from your LOCAL FOLDERS
addEventHandler(
	"onClientMapStarting",
	g_Root,
	function(mapInfo)
		outputDebug("onClientMapStarting")

		if Settings["enable"] == "on" and Settings["mode"] == "local" then
			-- disable for NTS
			local currentGameMode = string.upper(mapInfo.modename)
			if currentGameMode == "NEVER THE SAME" then
				return
			end

			-- destroy any leftover stuff
			if recording then
				destroy()
			end
			-- !!!
			recording = loadGhost(mapInfo.resname)

			-- ghost was read successfully
			if recording then

				-- !!!
				lastNodeID = 1
				nextNodeID = 1
				-- start a assistTimer that updates raceline parameters
				assistTimer = setTimer(updateRacingLine, 150, 0)
				-- show racing line at race start
				show()
				outputDebug("ghost loaded, starting assist") -- DEBUG
				outputChatBox("[Racing Assist] #ffffffLocal ghost loaded.", 255, 170, 64, true)
			end -- rec
		end -- setting
	end -- func
)


----------------------------------------------------------------------------------------------------
-- setup ghost received from SERVER
addEventHandler(
	"onClientGhostDataReceive",
	g_Root,
	function(rec, bestTime, racer, _, _)
		outputDebug("onClientGhostDataReceive")

		if Settings["enable"] == "on" and Settings["mode"] == "top" then
			-- destroy any leftover stuff
			if recording then
				destroy()
			end

			-- ghost data from "race_ghost" folder must be converted
			recording = {}

			-- copy and filter
			local i = 1
			while(rec[i]) do
				-- only need po type
				if (rec[i].ty == "po") then
					table.insert(recording, rec[i])
				end
				i = i + 1
			end

			lastNodeID = 1
			nextNodeID = 1
			-- !!!
			-- start a timer that updates raceline parameters
			assistTimer = setTimer(updateRacingLine, 150, 0)
			-- start drawing the racing line
			show()

			outputDebug("ghost loaded, starting assist") -- DEBUG
			outputChatBox("[Racing Assist] #ffffffGhost by " .. RemoveHEXColorCode(racer) .. " @".. msToTimeStr(bestTime).. " loaded.", 255, 170, 64, true)
		end -- if
	end -- func
)


----------------------------------------------------------------------------------------------------
function convert(value)
	if tonumber(value) ~= nil then
		return tonumber(value)
	else
		if tostring(value) == "true" then
			return true
		elseif tostring(value) == "false" then
			return false
		else
			return tostring(value)
		end
	end
end


----------------------------------------------------------------------------------------------------
-- trying to buy some time
local function getPositionFromElementOffset(x, y, z, rx, ry, rz, offZ)
	-- read more:
	-- https://wiki.multitheftauto.com/wiki/GetElementMatrix

	rx, ry, rz = rad(rx), rad(ry), rad(rz)

	local tx =  offZ * (cos(rz)*sin(ry) + cos(ry)*sin(rz)*sin(rx)) + x
	local ty =  offZ * (sin(rz)*sin(ry) - cos(rz)*cos(ry)*sin(rx)) + y
	local tz =  offZ * (cos(rx)*cos(ry)) + z

    return tx, ty, tz
end


--------------------------------------------------------------------------------------------------
function updateRacingLine()

	vehicle = getPedOccupiedVehicle(getLocalPlayer()) -- keep this

	-- hide racing line for air vehicles
	if Settings["enable"] == "on" and vehicle then
		vType = getVehicleType(vehicle)
		if (vType == "Plane" or vType == "Helicopter" or vType == "Boat") then
			hide()
		else
			show()
		end
	end

	------------------------------------------------------------------------------------------------
	-- Looking for the next valid ghostpoint, the first unvisited node that is within range.
	-- Search starts from the last visited node. Only looking forward from there!
	------------------------------------------------------------------------------------------------
	-- TODO: this is a mess
	-- save the last, before looking for a new one
	lastNodeID = nextNodeID -- remove this to see already visited routes
	nextNode = nil
	id = lastNodeID

	while(recording[id]) do
		dst = getDistanceBetweenPoints3D(
			recording[id].x, recording[id].y, recording[id].z,
			getElementPosition(getLocalPlayer())
		)

		-- found it, a nearby and unvisited point
		if (dst < 50 and id >= lastNodeID) then
			nextNode = id
			break
		end

		id = id + 1
	end


	------------------------------------------------------------------------------------------------
	-- At this point, the racing line is too far behind the player. It is valid, but looks stupid.
	-- I want the racing line to start from the vehicle.
	-- For that, I scroll through a few nodes to find one closest to the player.
	-- TODO: somewhat hard to understand the concept from code
	------------------------------------------------------------------------------------------------
	if (nextNode ~= nil) then
		prev_dst = math.huge
		dst = 0

		if (vehicle) then
			x, y, z = getElementPosition(vehicle)
			-- looking for a node pair, where "i+1" is further than "i"
			-- move it one step closer to player on every iteration
			prev = recording[nextNode]

			idx = nextNode + 1
			curr = recording[idx]
			if (curr and prev) then
				prev_dst = getDistanceBetweenPoints3D(prev.x, prev.y, prev.z, x, y, z) or 0
				dst = getDistanceBetweenPoints3D(curr.x, curr.y, curr.z, x, y, z) or 0

				if (prev_dst > dst) then
					-- !!!
					-- this will be the nearest valid node to player
					nextNodeID = idx
					-- !!!
				end
			end
		end -- vehicle
	end -- nil


	------------------------------------------------------------------------------------------------
	-- resize arrow based on vehicle size
	my_weight = 1500
	arrowSize = 2
	if (vehicle) then
		my_weight = getVehicleHandling(vehicle).mass

		-- dirt 3 style arrow
		arrowSize = math.clamp(1, (0.04 * my_weight + 180) / 200, 3)
	end

end


----------------------------------------------------------------------------------------------------
function drawRacingLine()
	-- read more:
	-- http://mathworld.wolfram.com/RelativeError.html
	-- https://www.lua.org/gems/sample.pdf


	------------------------------------------------------------------------------------------------
	-- DEBUG
	-- Show the full racing line, highlight nearby and next node.
	------------------------------------------------------------------------------------------------
	-- local i = 1
	-- node1 = recording[i]
	-- node2 = recording[i+1]
	-- while(node1 and node2) do
	-- 	-- one line-piece of whole racing line
	-- 	dxDrawLine3D(
	-- 		node1.x, node1.y, node1.z-0.4,
	-- 		node2.x, node2.y, node2.z-0.4,
	-- 		tocolor(255,255,255, 128),
	-- 		8
	-- 	)

	-- 	-- a few nodes near the player
	-- 	dst = getDistanceBetweenPoints3D(
	-- 		node1.x, node1.y, node1.z,
	-- 		getElementPosition(getLocalPlayer())
	-- 	)
	-- 	if (dst < 50) then
	-- 		dxDrawLine3D(
	-- 			node1.x, node1.y, node1.z-0.6,
	-- 			node1.x, node1.y, node1.z-0.4,
	-- 			tocolor(255, 0, 0, 255),
	-- 			25
	-- 		)
	-- 	end

	-- 	i = i + 1
	-- 	node1 = recording[i]
	-- 	node2 = recording[i+1]
	-- end

	-- -- draw the next node
	-- node1 = recording[nextNodeID]
	-- if (node1) then
	-- 	dxDrawLine3D(
	-- 		node1.x, node1.y, node1.z-0.6,
	-- 		node1.x, node1.y, node1.z-0.4,
	-- 		tocolor(0, 255, 0, 255),
	-- 		40
	-- 	)
	-- end


	------------------------------------------------------------------------------------------------
	-- Draw a section of the racing line. The magic happens here.
	------------------------------------------------------------------------------------------------
	vehicle = getPedOccupiedVehicle(getLocalPlayer()) -- keep this

	-- DEBUG rotation
	-- rx, ry, _ = getElementRotation(vehicle)
	-- if (rx > 180) then rx = rx - 360 end
	-- if (ry > 180) then ry = ry - 360 end
	-- dxDrawText("rx " .. math.floor(rx),
	-- 	800, 400, 1920, 1080, tocolor(255, 128, 0, 255), 1, "pricedown"
	-- )
	-- dxDrawText("ry " .. math.floor(ry),
	-- 	800, 450, 1920, 1080, tocolor(255, 128, 0, 255), 1, "pricedown"
	-- )

	-- the next few nodes
	local start = nextNodeID
	for i = start, start + Settings["linelength"], 1 do
		node1 = recording[i]
		-- need 2 valid nodes to make a line AND being in a vehicle to continue
		if (node1 and vehicle) then

			----------------------------------------------------------------------------------------
			-- Racing line coloring
			-- Color coding using RELATIVE SPEED ERROR
			-- red=too fast, green=same speed as ghost, white=too slow
			-- speed_err = 0.5 means you go 50% faster than the ghost
			----------------------------------------------------------------------------------------
			-- Get ghost AND player speed for EVERY PIECE OF RACE LINE
			ghost_speed = getDistanceBetweenPoints3D(0, 0, 0, node1.vX, node1.vY, node1.vZ)
			my_speed = getDistanceBetweenPoints3D(0, 0, 0, getElementVelocity(vehicle))
			my_dst = getDistanceBetweenPoints3D(node1.x, node1.y, node1.z, getElementPosition(vehicle))

			speed_err = Settings["sensitivity"] * ((my_speed - ghost_speed) / ghost_speed)
			-- speed_err = (ghost_speed - my_speed) * 160 -- old: speed difference roughly in kmh

			-- DEBUG
			-- watch vehicle speeds on the screen
			-- if i == start then
			-- 	dxDrawText("speed error: "..math.floor(speed_err*100).. " %",
			-- 		800, 440, 1920, 1080, tocolor(255, 128, 0, 255), 1, "pricedown"
			-- 	)
			-- end
			-- if i == start then
			-- 	dxDrawText("my speed: ".. math.floor(my_speed*160),
			-- 		800, 480, 1920, 1080, tocolor(255, 128, 0, 255), 1, "pricedown"
			-- 	)
			-- end
			-- if i == start then
			-- 	dxDrawText("ghost speed: ".. math.floor(ghost_speed*160),
			-- 		800, 520, 1920, 1080, tocolor(255, 128, 0, 255), 1, "pricedown"
			-- 	)
			-- end

			color_r = math.clamp(0, 510 * math.abs(speed_err), 255)
			color_g = math.clamp(0, -510 * speed_err + 255, 255)
			color_b = math.clamp(0, -510 * speed_err, 255)
			color_a = math.clamp(0, 0.5 * my_dst ^ 2, 175) -- sharp fade

			-- speed color coding, red=too fast, green=normal, white=too slow
			-- scaled to [-25, 25] kmh speed diff interval
			-- color_r = math.clamp(0, math.abs(-10*speed_err), 255)
			-- color_g = math.clamp(0, 10*speed_err + 255, 255)
			-- color_b = math.clamp(0, 10*speed_err, 255)
			-- color_a = math.clamp(0, 0.5*my_dst^2, 175) -- sharper fade


			----------------------------------------------------------------------------------------
			-- Draw one line piece
			-- Snap the racing line to the surface
			----------------------------------------------------------------------------------------
			rx, ry, rz = node1.rX, node1.rY, node1.rZ
			if (rx > 180) then rx = rx - 360 end
			if (ry > 180) then ry = ry - 360 end

			-- PLAN A) Look for hitpoints directly under the ghost car.
			-- The line (xx, yy, zz) <--> (node1.x, node1.y, node1.z) is perpendicular
			-- to the plane of the car and points down.
			-- Works even if the car is upside down!
			xx, yy, zz = getPositionFromElementOffset(node1.x, node1.y, node1.z, rx, ry, rz, -4)

			_, gx, gy, gz, _ = processLineOfSight(
				node1.x, node1.y, node1.z,
				xx, yy, zz,
				true, false, false, true
			)
			-- DEBUG, see hitpoint ray
			-- dxDrawLine3D(node1.x, node1.y, node1.z, xx, yy, zz, tocolor(255, 255, 255, 255), 8)


			-- PLAN B) Simply snap to the ground, because there was no collision.
			-- rx > 80: very steep uphill/downhill or a coaster loop
			-- ry > 70: going sideways on a wall
			if not gx and abs(rx) < 80 and abs(ry) < 70 then
				gx, gy, gz = node1.x, node1.y, getGroundPosition(node1.x, node1.y, node1.z)

				-- DEBUG: keep this, see ground coordinates
				-- dxDrawLine3D(gx, gy, gz, gx, gy, gz+0.2, tocolor(255, 0, 0, 255), 15)

				-- dont snap if ground is too far
				if abs(gz - node1.z) > 15 then
					gx, gy, gz = nil
				end
			end


			-- Some ground coordinates were found.
			if gx then
				-- nudge it above the road a little (works upside down too)
				gx, gy, gz = getPositionFromElementOffset(gx, gy, gz, rx, ry, rz, 0.2)

				-- DEBUG: keep this, see ground coordinates
				-- dxDrawLine3D(gx, gy, gz-0.1, gx, gy, gz+0.1, tocolor(255, 0, 0, 255), 15)

				-- !!!
				if gx and xx2 and i ~= start then
					dxDrawMaterialLine3D(
						gx, gy, gz,
						xx2, yy2, zz2,
						img, arrowSize, tocolor(color_r, color_g, color_b, color_a),
						xx, yy, zz
					)
				end

				-- !!!
				-- Ground coordinates are saved for the next iteration because it takes
				-- two points to make a line. Also to have a fewer calculations.
				xx2, yy2, zz2 = gx, gy, gz

			-- there was no collision
			else
				xx2, yy2, zz2 = nil, nil, nil

				-- DEBUG: keep this
				-- one node and scanline
				-- dxDrawLine3D(xx, yy, zz-0.1, xx, yy, zz+0.1, tocolor(255,0,0, 255), 15)
				-- dxDrawLine3D(xx, yy, zz, node1.x, node1.y, node1.z, tocolor(255,0,0, 255))
			end -- gx
		end	-- node check
	end	-- for
end
