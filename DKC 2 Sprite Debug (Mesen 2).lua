--DKC 2 Sprite Debug Script v0.03
--By: H4v0c21
--Designed for: Mesen S 2.0.0

--Controls:

--Left click+drag to move objects
--Right click to freeze/unfreeze objects
--Shift to toggle object info and hitboxes
--Hold CTRL to show all object variables
--L/R on controller to cycle object variable to view


mesen_version = 2

object_base_address = 0xDE2
object_size = 0x5E
object_routine_table = 0xB38348
animation_table = 0xF90000
hitbox_table = 0xBCB600
hitbox_base = 0xBC0000

draw_object_info = true
draw_hitboxes = true
drag_objects = true
freeze_objects = true
hover_object_info = true

draw_y_offset = 7
bg_color = 0x80404040

if mesen_version == 2 then
	ctrl_key = "Left Ctrl"
	alt_key =  "Left Alt"
	shift_key =  "Left Shift"
else
	ctrl_key = "Ctrl"
	alt_key =  "Alt"
	shift_key =  "Shift"
end



function ReadByte(address)
	byte = emu.read(address, emu.memType[cpuDebug], false)
	return byte
end


function ReadWord(address)
	word = emu.readWord(address, emu.memType[cpuDebug], false)
	return word
end


function ReadObjectVariableWord(object,variable_offset)
	word = ReadWord(object+variable_offset)
	return word
end


function ReadObjectVariableByte(object,variable_offset)
	byte = ReadByte(object+variable_offset)
	return byte
end


function ToHexLong(number)
	local hex_string = string.format("%X", number)
	
	while #hex_string < 6 do
		hex_string = "0" .. hex_string
	end
	
	hex_string = hex_string:upper()
	return hex_string
end


function ToHexWord(number)
	local hex_string = string.format("%X", number)
	
	while #hex_string < 4 do
		hex_string = "0" .. hex_string
	end
	
	hex_string = hex_string:upper()
	return hex_string
end


function ToHexByte(number)
	local hex_string = string.format("%X", number)
	
	while #hex_string < 2 do
		hex_string = "0" .. hex_string
	end
	
	hex_string = hex_string:upper()
	return hex_string
end


local function BitAND(a,b)
	local p,c=1,0
	
	while a>0 and b>0 do
		local ra,rb=a%2,b%2
		if ra+rb>1 then c=c+p end
		a,b,p=(a-ra)/2,(b-rb)/2,p*2
	end
	
	return c
end


function IsMouseInsideBox(mouse_x, mouse_y, box_x, box_y, box_width, box_height)
	if mouse_x >= box_x and mouse_x <= box_x + box_width and
		mouse_y >= box_y and mouse_y <= box_y + box_height then
		return true
	else
		return false
	end
end


function FindInTable(tbl, value)
    
	for i, entry in ipairs(tbl) do
		v = entry[1]
        if v == value then
            return i
        end
    end
    return nil
end


colors = {
	0xFF0000,   -- Red
	0xFF00FF,   -- Magenta
	0x00FF00,   -- Lime
	0x0000FF,   -- Blue
	0xFFFF00,   -- Yellow
	0x00FFFF,   -- Cyan
	0xFF8000,   -- Orange
	0x8000FF,   -- Purple
	0x00FF80,   -- Spring green
	0xFF0080,   -- Rose
	0x80FF00,   -- Chartreuse
	0x0080FF,   -- Deep sky blue
	0xFF8080,   -- Light coral
	0x808000,   -- Olive
	0xFFA500,   -- Orange
	0xFF4500,   -- Orange-red
	0x008000,   -- Green
	0x000080,   -- Navy
	0xFFC0CB,   -- Pink
	0x8B008B,   -- Dark magenta
	0x008080,   -- Teal
	0xFF6347,   -- Tomato
	0xFF1493,   -- Deep pink
	0xFF8C00    -- Dark orange
}

viewed_variable_number = 0
grabbed_objects = {}
frozen_objects = {}

mouse_left_hold = false
mouse_left_press = false
mouse_left_release = false
mouse_right_hold = false
mouse_right_press = false
mouse_right_release = false

shift_hold = false
shift_press = false
shift_release = false


function Sprite_Debug()
	emu.clearScreen()
	
	state = emu.getState()
	mouseState = emu.getMouseState()
	player_input = ReadWord(0x7E0510)
	
	
	--update input states
	if mouse_left_hold ~= mouseState.left then
		if mouseState.left == true then
			mouse_left_press = true
			mouse_left_release = false
		else
			mouse_left_press = false
			mouse_left_release = true
		end
	else
		mouse_left_press = false
		mouse_left_release = false
	end
	
	if mouse_right_hold ~= mouseState.right then
		if mouseState.right == true then
			mouse_right_press = true
			mouse_right_release = false
		else
			mouse_right_press = false
			mouse_right_release = true
		end
	else
		mouse_right_press = false
		mouse_right_release = false
	end

	mouse_left_hold = mouseState.left
	mouse_right_hold = mouseState.right


	if shift_hold ~= emu.isKeyPressed(shift_key) then
		if emu.isKeyPressed(shift_key) == true then
			shift_press = true
			shift_release = false
		else
			shift_press = false
			shift_release = true
		end
	else
		shift_press = false
		shift_release = false
	end
	
	shift_hold = emu.isKeyPressed(shift_key)
	
	if shift_press == true then
		draw_object_info = not draw_object_info
		draw_hitboxes = not draw_hitboxes
	end


	--if mouse left not held drop all objects
	if mouse_left_hold == false then grabbed_objects = {} end
	
	
	--if L pressed decrease variable to display
	if BitAND(player_input,0x0020) == 0x0020 then
		viewed_variable_number = viewed_variable_number - 2
		
		--if variable underflowed loop back around to variable $5C,x
		if viewed_variable_number < 0 then
			viewed_variable_number = 0x5C
		end
	end
	
	--if R pressed increase variable to display
	if BitAND(player_input,0x0010) == 0x0010 then
		viewed_variable_number = viewed_variable_number + 2
		
		--if variable overflowed loop back around to variable $00,x
		if viewed_variable_number >= 0x5E then
			viewed_variable_number = 0
		end
	end
	
	--draw object info box
	if draw_object_info == true then
		
		--if ctrl isn't pressed draw object info header box
		if emu.isKeyPressed(ctrl_key) ~= true then
			--init y draw offset of info box
			gui_object_info_y_offset = 0
			
			--draw info box
			emu.drawRectangle(0, 10, 110, 10, bg_color, true, 1)
			
			--draw info header text
			emu.drawString(0, 10, "address type  $" .. ToHexByte(viewed_variable_number) .. ",x", 0xFFFFFF, 0xFF000000)
			
			--update y draw offset
			gui_object_info_y_offset = gui_object_info_y_offset + 20
		end
	end
	
	--update game variables
	camera_x = ReadWord(0x7E0AD7)
	camera_y = ReadWord(0x7E0ADB)
	
	--iterate through objects
	for object_index = 0,23,1 do
		
		--assign color to object
		object_color = colors[object_index+1]
		
		--get object info
		object = object_size * object_index + object_base_address									--generate object address
		object_type = ReadObjectVariableWord(object,0)												--get object type
		object_main_routine = ReadObjectVariableWord(object_routine_table,object_type)				--lookup object main routine
		object_animation_id = ReadObjectVariableWord(object,0x36)									--get animation id
		object_animation_script = ReadObjectVariableWord(animation_table,object_animation_id*4)		--lookup animation script
		
		--if object is valid process the object
		if object_type ~= 0 then
			
			--get object position and direction
			object_x = ReadObjectVariableWord(object,0x6)
			object_y = ReadObjectVariableWord(object,0xA)
			object_facing = ReadObjectVariableWord(object,0x12)
			
			--get object hitbox
			hitbox_id = ReadObjectVariableWord(object,0x1A)
			hitbox_offset = emu.readWord(hitbox_table+hitbox_id / 2, emu.memType[cpuDebug], false)
			hitbox_x_offset = emu.readWord(hitbox_base+hitbox_offset, emu.memType[cpuDebug], true)
			hitbox_y_offset = emu.readWord(hitbox_base+hitbox_offset+2, emu.memType[cpuDebug], true)
			hitbox_width = emu.readWord(hitbox_base+hitbox_offset+4, emu.memType[cpuDebug], true)
			hitbox_height = emu.readWord(hitbox_base+hitbox_offset+6, emu.memType[cpuDebug], true)
			
			--get viewed variable value
			viewed_variable = ReadObjectVariableWord(object,viewed_variable_number)
			
			--if object is flipped mirror the hitbox
			if BitAND(object_facing,0x4000) == 1 then
				hitbox_width = hitbox_width * -1
			end
	
			--render object hitbox
			if draw_hitboxes == true then
				emu.drawRectangle((object_x-camera_x)+hitbox_x_offset, (object_y-camera_y)+hitbox_y_offset+draw_y_offset, hitbox_width, hitbox_height, object_color+0x80000000, false, 1)
			end
			
			--render object info
			if draw_object_info == true then
				
				--if control isn't pressed render object info
				if emu.isKeyPressed(ctrl_key) == false then
					
					--draw object origin
					emu.drawPixel(object_x-camera_x, object_y-camera_y+draw_y_offset, object_color)
					
					--draw info box
					emu.drawRectangle(0, gui_object_info_y_offset, 110, 10, bg_color, true, 1)
					
					--draw info text
					emu.drawString(0, gui_object_info_y_offset, "$" .. ToHexWord(object).. " #" .. ToHexWord(object_type) .." 0x" .. ToHexWord(viewed_variable), object_color, 0xFF000000)
					
					--update draw offset
					gui_object_info_y_offset = gui_object_info_y_offset + 10
				end
			end
			
			--handle object dragging
			if drag_objects == true then
				
				--if left click is pressed and if the mouse is over an object add it to dragged objects
				if mouse_left_hold == true then
					if IsMouseInsideBox(mouseState.x, mouseState.y-draw_y_offset, object_x-camera_x+hitbox_x_offset, object_y-camera_y+hitbox_y_offset, hitbox_width, hitbox_height) == true then
						table.insert(grabbed_objects, object)
					end
				end
			end
			
			--handle object position freezing
			if freeze_objects == true then
				if mouse_right_press == true then
					if IsMouseInsideBox(mouseState.x, mouseState.y-draw_y_offset, object_x-camera_x+hitbox_x_offset, object_y-camera_y+hitbox_y_offset, hitbox_width, hitbox_height) == true then
						frozen_object = {object, object_x, object_y}
						
						table_index = FindInTable(frozen_objects, object)
						
						if table_index == nil then
							table.insert(frozen_objects, frozen_object)
						else
							table.remove(frozen_objects, table_index)
						end

					end
				end
			end
			
			--handle object hover info
			if hover_object_info == true then
				
				--if mouse is over an object
				if IsMouseInsideBox(mouseState.x, mouseState.y-draw_y_offset, object_x-camera_x+hitbox_x_offset, object_y-camera_y+hitbox_y_offset, hitbox_width, hitbox_height) == true then
					
					--if ctrl is pressed render all object variables
					if emu.isKeyPressed(ctrl_key) == true then
						
						--draw variable box
						emu.drawRectangle(0, 0, 250, 125, bg_color, true, 1)
						
						--draw variable header text
						emu.drawString(0, 10, "$$", object_color, 0xFF000000)
						
						--draw object variables
						for i = 0,15,1 do
							emu.drawString(i * 14+14+4, 10, ToHexByte(i), object_color, 0xFF000000)
						end
						
						for i = 0,5,1 do
							emu.drawString(0, i * 16+24, ToHexByte(i), object_color, 0xFF000000)
						end
						
						for v = 0,0x5D,1 do
							variable_byte = ReadObjectVariableByte(object,v)
							emu.drawString((v%16) * 14 +14+4, (v//16) * 16+24, ToHexByte(variable_byte), object_color, 0x10000000)
						end
					
					--ctrl is not pressed, draw normal hover info
					else
						emu.drawRectangle(mouseState.x-4, mouseState.y-draw_y_offset-4, 80, 64, bg_color, true, 1)
						
						emu.drawString(mouseState.x, mouseState.y-draw_y_offset, "slot: #" .. object_index, object_color, 0xFF000000)
						emu.drawString(mouseState.x, mouseState.y-draw_y_offset+10, "address: $" .. ToHexWord(object), object_color, 0xFF000000)
						emu.drawString(mouseState.x, mouseState.y-draw_y_offset+20, "type: #" .. ToHexWord(object_type), object_color, 0xFF000000)
						emu.drawString(mouseState.x, mouseState.y-draw_y_offset+30,"$" .. ToHexByte(viewed_variable_number) .. ",x: 0x" .. ToHexWord(viewed_variable), object_color, 0xFF000000)
						emu.drawString(mouseState.x, mouseState.y-draw_y_offset+40, "main: $B3" .. ToHexWord(object_main_routine), object_color, 0xFF000000)
						emu.drawString(mouseState.x, mouseState.y-draw_y_offset+50, "anim: $F9" .. ToHexWord(object_animation_script), object_color, 0xFF000000)
					end
				end
			end
		end
	end
	
	
	--move all dragged objects to mouse position
	if drag_objects == true then
		for object = 1, #grabbed_objects do
			emu.writeWord(grabbed_objects[object]+0x06, mouseState.x+camera_x, emu.memType[cpuDebug])
			emu.writeWord(grabbed_objects[object]+0x0A, mouseState.y-draw_y_offset+camera_y, emu.memType[cpuDebug])
		end
	end

	--handle object position freezing
	if freeze_objects == true then
		for _, frozen_object in ipairs(frozen_objects) do
			local object = frozen_object[1]
			local x = frozen_object[2]
			local y = frozen_object[3]
			emu.writeWord(object+0x06, x, emu.memType[cpuDebug])
			emu.writeWord(object+0x0A, y, emu.memType[cpuDebug])
			emu.drawRectangle(x-camera_x-4, y-camera_y+draw_y_offset-4, 2, 8, 0x00FFFFFF, true, 1)
			emu.drawRectangle(x-camera_x, y-camera_y+draw_y_offset-4, 2, 8, 0x00FFFFFF, true, 1)
		end
	end

end

--call sprite debug
emu.addEventCallback(Sprite_Debug, emu.eventType.endFrame);

--display startup message
emu.displayMessage("Script", "DKC 2 Sprite Debug Script loaded.")