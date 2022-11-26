---@diagnostic disable: undefined-global
local portal_protocol = Proto("Portal", "Skylanders portal protocol")

local command = ProtoField.uint8("portal.command", "Command")
local music_data = ProtoField.string("portal.music.data", "Music data")
local color_red = ProtoField.uint8("portal.color.red", "Red")
local color_green = ProtoField.uint8("portal.color.green", "Green")
local color_blue = ProtoField.uint8("portal.color.blue", "Blue")
local color_side = ProtoField.uint8("portal.color.side", "Side")
local light_position = ProtoField.uint8("portal.light.position", "Position")
local activate = ProtoField.bool("portal.activate", "Activate")
local music_activate = ProtoField.bool("portal.music.activate", "Activate")
local status_activated = ProtoField.bool("portal.status.activated", "Activated")
local status_counter = ProtoField.uint8("portal.status.counter", "Counter")
local status_figure_indexes = ProtoField.uint32("portal.status.indexes.present", "Figure indexes")
local status_figure_added_indexes = ProtoField.uint32("portal.status.indexes.added", "Added figure indexes")
local status_figure_removed_indexes = ProtoField.uint32("portal.status.indexes.removed", "Removed figure indexes")
local id = ProtoField.string("portal.id", "ID")
local unknown = ProtoField.string("portal.unknown", "Unknown")
local query_figure_index = ProtoField.uint8("portal.query.figure_index", "Figure index")
local query_block_index = ProtoField.uint8("portal.query.block_index", "Block index")
local query_data = ProtoField.string("portal.query.data", "Data")

local command_lookup = {
	[0x41] = "Activate",
	[0x43] = "Color",
	[0x4A] = "J",
	[0x4C] = "Light",
	[0x4D] = "Music",
	[0x51] = "Query",
	[0x52] = "Reset",
	[0x53] = "Status",
	[0x56] = "Version?", --unsure of correct name or data
	[0x57] = "Write"
}

local color_side_lookup = {
	[0x00] = "Right",
	[0x01] = "Both",
	[0x02] = "Left"
}

local light_position_lookup = {
	[0x00] = "Right",
	[0x01] = "Trap",
	[0x02] = "Left"
}

portal_protocol.fields = { command, music_data, color_red, color_green, color_blue, activate, unknown, color_side, light_position, music_activate, id, status_activated, status_counter, status_figure_indexes, status_figure_added_indexes, status_figure_removed_indexes, query_figure_index, query_block_index, query_data }

local function is_response(pinfo)
	return tostring(pinfo.src) ~= "host"
end

local function table_contains_value(containing_table, check_value)

	for _, value in pairs(containing_table) do
		if value == check_value then
			return true
		end
	end

	return false

end

local function parse_command_character(pinfo, buffer, subtree)

	local command_char = buffer(0, 1):le_int()
	local command_text = command_lookup[command_char]

	subtree:add_le(command, buffer(0, 1)):append_text(string.format(" (%s)", command_text))

	local direction = string.upper("request")

	if is_response(pinfo) then direction = string.upper("response") end

	pinfo.cols.info = string.format("%s %s", string.upper(command_text), direction)

	return command_char

end

local function parse_activate(pinfo, buffer, subtree)
	subtree:add_le(activate, buffer(1, 1))

	if is_response(pinfo) then
		subtree:add_le(unknown, buffer(2, 2), buffer(2, 2):bytes():tohex())
	end
end

local function parse_color(_, buffer, subtree)
	subtree:add_le(color_red, buffer(1, 1))
	subtree:add_le(color_green, buffer(2, 1))
	subtree:add_le(color_blue, buffer(3, 1))
end

local function parse_color_sided(_, buffer, subtree)
	subtree:add_le(color_side, buffer(1, 1)):append_text(string.format(" (%s)", color_side_lookup[buffer(1, 1):le_int()]))
	subtree:add_le(color_red, buffer(2, 1))
	subtree:add_le(color_green, buffer(3, 1))
	subtree:add_le(color_blue, buffer(4, 1))
	subtree:add_le(unknown, buffer(5, 2), buffer(5, 2):bytes():tohex())
end

local function parse_color_light(_, buffer, subtree)
	subtree:add_le(light_position, buffer(1, 1)):append_text(string.format(" (%s)", light_position_lookup[buffer(1, 1):le_int()]))
	subtree:add_le(color_red, buffer(2, 1))
	subtree:add_le(color_green, buffer(3, 1))
	subtree:add_le(color_blue, buffer(4, 1))
end

local function parse_music(pinfo, buffer, subtree)
	subtree:add_le(music_activate, buffer(1, 1))

	if is_response(pinfo) then
		subtree:add_le(unknown, buffer(2, 2), buffer(2, 2):bytes():tohex())
	end
end

local function parse_query(pinfo, buffer, subtree)
	subtree:add_le(query_figure_index, buffer(1, 1), buffer(1, 1):le_int() % 16)
	subtree:add_le(query_block_index, buffer(2, 1))

	if is_response(pinfo) then
		subtree:add_le(query_data, buffer(3), buffer(3):bytes():tohex())
	end
end

local function parse_reset(pinfo, buffer, subtree)
	if is_response(pinfo) then
		subtree:add_le(id, buffer(1, 2), buffer(1, 2):bytes():tohex())
	end
end

local function parse_status(pinfo, buffer, subtree)
	if is_response(pinfo) then
		local indexes = {}
		local added_indexes = {}
		local removed_indexes = {}

		for j=0, 3, 1 do
			for i=0, 3, 1 do
				if bit.band(buffer(1 + j, 1):le_int(), bit.lshift(1, i * 2)) > 0 then
					table.insert(indexes, j * 4 + i)
				end
			end
		end

		for j=0, 3, 1 do
			for i=0, 3, 1 do
				if bit.band(buffer(1 + j, 1):le_int(), bit.lshift(2, i * 2)) > 0 then
					if table_contains_value(indexes, j * 4 + i) then
						table.insert(added_indexes, j * 4 + i)
					else
						table.insert(removed_indexes, j * 4 + i)
					end
				end
			end
		end

		local index_text = " (none)"

		if #indexes ~= 0 then
			index_text = string.format(" (%s)", table.concat(indexes, ", "))
		end

		subtree:add_le(status_figure_indexes, buffer(1, 4)):append_text(index_text)
		for _ in pairs(added_indexes) do
			subtree:add_le(status_figure_added_indexes, buffer(1, 4)):append_text(string.format(" (%s)", table.concat(added_indexes, ", ")))
			break
		end
		for _ in pairs(removed_indexes) do
			subtree:add_le(status_figure_removed_indexes, buffer(1, 4)):append_text(string.format(" (%s)", table.concat(removed_indexes, ", ")))
			break
		end
		subtree:add_le(status_counter, buffer(5, 1))
		subtree:add_le(status_activated, buffer(6, 1))
	end
end

local function parse_version(pinfo, buffer, subtree)
	subtree:add_le(id, buffer(1, 3), buffer(1, 3):bytes():tohex())
end

local command_parsers = {
	[0x41] = parse_activate,
	[0x43] = parse_color,
	[0x4A] = parse_color_sided,
	[0x4C] = parse_color_light,
	[0x4D] = parse_music,
	[0x51] = parse_query,
	[0x52] = parse_reset,
	[0x53] = parse_status,
	[0x56] = parse_version, --unsure of correct name or data
	--[0x57] = "Write"
}

local function parse_command(pinfo, buffer, subtree)

	local command_char = parse_command_character(pinfo, buffer, subtree)

	local parser = command_parsers[command_char]
	if parser ~= nil then
		parser(pinfo, buffer, subtree)
	end
end

local function parse_music(buffer, pinfo, subtree)
	subtree:add_le(music_data, buffer(0), buffer(0):bytes():tohex())

	pinfo.cols.info = string.format("MUSIC_DATA")
end

function portal_protocol.dissector(buffer, pinfo, tree)
	local length = buffer:len()
	-- first 7 bytes are setup data
	if length <= 7 then return end

	pinfo.cols.protocol = portal_protocol.name

	local offset = 0

	if is_response(pinfo) ~= true then
		offset = 7
	end

	local subtree = tree:add(portal_protocol, buffer(offset), "Skylanders portal data")

	if is_response(pinfo) ~= true then
		-- TODO: check if packet is interrupt. Not length
		if pinfo.len == 91 then
			parse_music(buffer, pinfo, subtree)
			return
		end
	end

	parse_command(pinfo, buffer(offset), subtree)

	
end

DissectorTable.get("usb.product"):add(0x14300150, portal_protocol)
