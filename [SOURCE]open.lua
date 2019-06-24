logpath,flight_mode,flight_mode_prev,armed,batt_FS,ekf_FS,num_sats,gps_fix,hdop,adv_gps_fix,alt_msl,vfas,curr,fuse,fuel,disH,dirH,alt,v_speed,h_speed,hdg,roll,pitch,pitch_calc,gps_lat,gps_lon,tx_units = nil
params = {}
msg = {}

-- Display & Menu
display, menu_display, menu_selection, menu_option_gps,menu_option_shade,menu_option_alt = nil
display_option = {}

-- TEST MODE CONTROL --
test_mode = false
-----------------------

-- MAIN --
local function init()
	local dateinit,timestamp
	dateinit = getDateTime()
	logpath = "/SCRIPTS/TELEMETRY/" .. dateinit.mon .. "-" .. dateinit.day .. "-" .. dateinit.year .. "_" .. dateinit.hour .. "-" .. dateinit.min .. "-" .. dateinit.sec .. ".log"

	display = 0
	menu_display = 0
	menu_selection = 0

	center_x, center_y = 105, 35
	center_x_float,center_y_float = center_x, center_y		-- Start on center
		
	if test_mode then
		params[1] = 1		-- Frame Type  1 for Fixed Wing
		params[2] = 1080	-- Batt FS Voltage 	(cV)
		params[3] = 200		-- Batt FS Capacity (mAh)
		params[4] = 1300	-- Batt 1 Capacity	(mAh)
		params[5] = nil		-- Batt 2 Capacity	(mAh)
		
		flight_mode = 9
		armed = 1
		
		num_sats = 14		-- #
		gps_fix = 3			-- NO_GPS = 0, NO_FIX = 1, GPS_OK_FIX_2D = 2, GPS_OK_FIX_3D >= 3
		hdop = 5			-- decimeters
		adv_gps_fix = 1		-- 0: no advanced fix, 1: GPS_OK_FIX_3D_DGPS, 2: GPS_OK_FIX_3D_RTK_FLOAT, 3: GPS_OK_FIX_3D_RTK_FIXED
		alt_msl = 12		-- decimeters
		
		vfas = 117			-- deciVolts
		curr = 9			-- deciAmps
		fuse = 800			-- mAh
		fuel = (params[4] - fuse) / params[4] * 100
		
		disH = 88			-- meters
		dirH = 20			-- degrees
		alt = 1290			-- decimeters
		
		v_speed = 200		-- decimeters / s
		h_speed = 174		-- decimeters / s
		hdg = 50			-- degrees
		
		roll = 310			-- degrees
		pitch = 270			-- degrees
	end
	
	loadOptions()
end
local function bg()
	local sensor_id,frame_id,data_id,val,msg,param_id,param_val,label
	while(true)	do		
		sensor_id,frame_id,data_id,val = sportTelemetryPop()
		if data_id ~= nil then
			if data_id 	   == 20480 then 			--5000	Text messages (sent 3x whenever a msg is in queue)
			msg = p5000(val)
			--logger(msg)
			elseif data_id == 20481 then p5001(val)					--5001	AP STATUS (2Hz)
			elseif data_id == 20482 then p5002(val)					--5002	GPS STATUS (1Hz)
			elseif data_id == 20483 then p5003(val)					--5003	BATT (1Hz)
			elseif data_id == 20484 then p5004(val)					--5004	HOME (2Hz)
			elseif data_id == 20485 then p5005(val)					--5005	VELANDYAW (2Hz)
			elseif data_id == 20486 then p5006(val)					--5006	ATTIANDRNG (Max Hz)
			elseif data_id == 20487 then 
				param_id,param_val = p5007(val)						--5007	PARAMS (sent 3x each at init)
				params[param_id] = param_val
			else logger("Uncharted Waters!! - data_id: " .. data_id .. " - val: " .. val)
			end
		else break	-- no packets in queue
		end
	end
end
local function run(e)
	local left_x_limit,right_x_limit,top_y_limit,bot_y_limit,anchor_x,anchor_y,anchor_y_gps,roll_tan,roll_atan,roll_cos,roll_sin,b
	
	getUnitsType()
	
	calc_limits()
	calc_trig()
	
	displaySwap(e)
	displayMenu(e)
	resetTimer(e)
	if menu_display > 0 then return end
	
	lcd.clear()
	drawBG()
	drawFM()
	drawRSSI()	
	drawTxBt()
	
	drawVoltage()
	drawAmps()
	drawFuelRemain()
	drawFuel()
	
	drawSpeed()
	drawAlt()

	drawPitch()
	drawHorizon()
	--drawHorizonAngles()
	
	drawHeading()
	drawDirHLine()
	drawDirHPointer()
	drawDisH()
	drawGPS()
	
	drawTimer()
	drawMessage()
	drawPlane()
	drawArmed()
	
	--getUnitsType()
	
end

-- Helper Functions
function loadOptions()
	local options_conf
	
	options_conf = io.open("/SCRIPTS/TELEMETRY/open.conf","r")
	if options_conf ~= nil then 
		menu_option_gps = tonumber(string.match(io.read(options_conf,24),"GPS_COORDINATE_OVERLAY=(%d)"))
		menu_option_alt = tonumber(string.match(io.read(options_conf,17),"ALT_PREFER_GPS=(%d)"))
		menu_option_shade = tonumber(string.match(io.read(options_conf,13),"GREYSCALE=(%d+)"))
		io.close(options_conf)
	else
		menu_option_gps = 1
		menu_option_alt = 0
		menu_option_shade = 8
		options_conf = io.open("/SCRIPTS/TELEMETRY/open.conf","w")
		io.write(options_conf,"GPS_COORDINATE_OVERLAY=",menu_option_gps,"\n")
		io.write(options_conf,"ALT_PREFER_GPS=",menu_option_alt,"\n")
		io.write(options_conf,"GREYSCALE=",menu_option_shade,"\n")
		io.close(options_conf)
	end
end
function getTimestamp()
	local datenow = getDateTime()
	local timestamp = datenow.mon .. "-" .. datenow.day .. "-" .. datenow.year .. " " .. datenow.hour .. ":" .. datenow.min .. "." .. datenow.sec .. " -- "
	return timestamp
end
function logger(message)
	local timestamp = getTimestamp()
	local file = io.open(logpath, "a")
	io.write(file, timestamp, message, "\r\n")
	io.close(file)
	return 1
end
function round(val)
	return val % 1 >= 0.5 and math.ceil(val) or math.floor(val)
end
function roundInt(val,n)
	val = val / n
	val = round(val) * n
	return val
end
function hdgDirection(val)
	if val < 0 then val = 360 + val elseif val >= 360 then val = val - 360 end
	if val < 45  then hlabel = "N"
	elseif val >= 45  and val < 90  then hlabel = "NE"
	elseif val >= 90  and val < 135 then hlabel = "E"
	elseif val >= 135 and val < 180 then hlabel = "SE"
	elseif val >= 180 and val < 225 then hlabel = "S"
	elseif val >= 225 and val < 270 then hlabel = "SW"
	elseif val >= 270 and val < 315 then hlabel = "W"
	elseif val >= 315 and val < 360 then hlabel = "NW"
	end
	return hlabel
end
function calc_limits()
	left_x_limit = center_x - 37
	right_x_limit = center_x + 37
	top_y_limit = center_y - 27
	bot_y_limit = center_y + 28
	anchor_x, anchor_y = 161, 8
	anchor_y_gps = anchor_y + 4
end
function calc_trig()
	if roll == nil then return end
	roll_tan = math.tan(math.rad(-roll))
	roll_atan = round(math.deg(math.atan((center_y_float - top_y_limit) / (center_x_float - left_x_limit))))
	roll_cos = math.cos(math.rad(-roll))
	roll_sin = math.sin(math.rad(-roll))
	
	b = center_y_float - roll_tan * center_x_float
	
end
function displaySwap(e)
	if menu_display > 0 then return end
	if e == EVT_ENTER_BREAK then
		if display == 0 then
			display = 1
		elseif display == 1 then
			display = 0
		end			
	end
end
function displayMenu(e)
	local options_conf

	if e == EVT_MENU_BREAK then
		if menu_display == 0 then menu_display = 1 elseif menu_display == 1 then menu_display = 2 elseif menu_display == 2 then menu_display = 1 end
		menu_selection = 0
	end
	
	lcd.clear()
	lcd.drawLine(0,8,211,8,SOLID,FORCE)
	lcd.drawLine(0,61,211,61, SOLID,FORCE)
	lcd.drawFilledRectangle(3,62,207,2,GREY(10))
	lcd.drawLine(2,8,2,63,SOLID,FORCE)
	lcd.drawFilledRectangle(0,9,2,52,GREY(10))
	lcd.drawLine(209,8,209,63,SOLID,FORCE)
	lcd.drawFilledRectangle(210,9,2,52,GREY(10))

	
	if menu_display == 1 then
		lcd.drawScreenTitle("Menu Options",1,2)

		if e == EVT_MINUS_BREAK then menu_selection = menu_selection + 1 end
		if e == EVT_PLUS_BREAK then menu_selection = menu_selection - 1 end
		if menu_selection < 0 then menu_selection = 3 end
		if menu_selection > 3 then menu_selection = 0 end
		
		local menu_options1 = {"Disable", "Enable"}
		local menu_options2 = {"Barometer", "GPS"}
		local menu_options3 = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15}
		
		if menu_selection == 1 then
			display_option[1],display_option[2],display_option[3] = INVERS,0,0
		elseif menu_selection == 2 then
			display_option[1],display_option[2],display_option[3] = 0,INVERS,0
		elseif menu_selection == 3 then
			display_option[1],display_option[2],display_option[3] = 0,0,INVERS
		else
			display_option[1],display_option[2],display_option[3] = 0,0,0
		end
		
		if e == EVT_ENTER_BREAK then
			if menu_selection == 1 then
				if menu_option_gps == 0 then menu_option_gps = 1
				else menu_option_gps = 0
				end
			elseif menu_selection == 2 then
				if menu_option_alt == 0 then menu_option_alt = 1
				else menu_option_alt = 0
				end
			elseif menu_selection == 3 then
				menu_option_shade = menu_option_shade - 1
				if menu_option_shade < 0 then menu_option_shade = 15 end
			end
		end
				
		lcd.drawText(130, 13, "GPS Coordinate Overlay:", RIGHT)
		lcd.drawCombobox(137, 11, 70, menu_options1, menu_option_gps, display_option[1] )
		
		lcd.drawText(130, 27, "Altimeter Preference:", RIGHT)
		lcd.drawCombobox(137, 25, 70, menu_options2, menu_option_alt, display_option[2] )

		lcd.drawText(130, 41, "Shade Greyscale:", RIGHT)
		lcd.drawCombobox(137, 39, 70, menu_options3, menu_option_shade, display_option[3] )		
		
	elseif menu_display == 2 then
		lcd.drawScreenTitle("Usage Info",2,2)
		
		lcd.drawText(130, 13, "Transmitter Units:", RIGHT)
		lcd.drawText(155, 13, tx_units, 0)
		
		lcd.drawText(130,25, "Toggle Amps/Watts:", RIGHT)
		lcd.drawText(155,25, "ENT", 0)
		
		lcd.drawText(130,37, "Reset Timer:", RIGHT)
		lcd.drawText(155,37, "Hold (-)", 0)
		
		lcd.drawText(130,49, "Exit Menu:", RIGHT)
		lcd.drawText(155,49, "EXIT",0)
	end
	
	if e == EVT_EXIT_BREAK then 
		menu_display = 0
		menu_selection = 0
		
		-- WRITE OPTIONS TO SD CARD ON EXIT 
		options_conf = io.open("/SCRIPTS/TELEMETRY/open.conf","w")
		io.write(options_conf,"GPS_COORDINATE_OVERLAY=",menu_option_gps,"\n")
		io.write(options_conf,"ALT_PREFER_GPS=",menu_option_alt,"\n")
		io.write(options_conf,"GREYSCALE=",menu_option_shade,"\n")
		io.close(options_conf)
		
		return
	end
	
end
function getUnitsType()
	local tx_settings = getGeneralSettings()
	
	-- 0 = Metric	1 = Imperial
	if tx_settings['imperial'] == 0 then tx_units = "Metric" elseif tx_settings['imperial'] == 1 then tx_units = "Imperial" end
end
function resetTimer(e)
	if menu_display == 0 then
		if e == EVT_MINUS_REPT then model.resetTimer(0) end
	end
end
function announceFM()
	local sound
	local fm_sound_array = {}
	
	fm_sound_array = 	{	"manmd.wav","APM-Circle.wav","fm-stb.wav","trngmd.wav","fm-acr.wav","fbwa.wav","fbwb.wav",
							"fm-crs.wav","automd.wav","9","fm-ato.wav","fm-rtl.wav","fm-ltr.wav","13","APM-Guided.wav","15","16","17","18","19"
						}
	
	flight_mode_prev = flight_mode
	sound = fm_sound_array[flight_mode]
	playFile(sound)
end


-- Pull data
function p5000(val)	-- 5000	Text messages (sent 3x whenever a msg is in queue)
--[[
/*
 * grabs one "chunk" (4 bytes) of the queued message to be transmitted
 * for FrSky SPort Passthrough (OpenTX) protocol (X-receivers)
 */
...

        if (!character || (_msg_chunk.char_index == sizeof(_statustext_queue[0]->text))) { // we've reached the end of the message (string terminated by '\0' or last character of the string has been processed)
            _msg_chunk.char_index = 0; // reset index to get ready to process the next message
            // add severity which is sent as the MSB of the last three bytes of the last chunk (bits 24, 16, and 8) since a character is on 7 bits
            _msg_chunk.chunk |= (_statustext_queue[0]->severity & 0x4)<<21;
            _msg_chunk.chunk |= (_statustext_queue[0]->severity & 0x2)<<14;
            _msg_chunk.chunk |= (_statustext_queue[0]->severity & 0x1)<<7;
        }
    }

    if (_msg_chunk.repeats++ > 2) { // repeat each message chunk 3 times to ensure transmission
        _msg_chunk.repeats = 0;
        if (_msg_chunk.char_index == 0) { // if we're ready for the next message
            _statustext_queue.remove(0);
        }
    }
    return true;
}

--]]
	local raw_message,message,severity,n 
	local d ={}
	for n = 1,4 do
		d[n] = bit32.extract(val,24 - 8 * (n-1),8)
		-- Last chunk includes severity
		
		d[n] = string.char(d[n])
	end
	message = d[1] .. d[2] .. d[3] .. d[4]
	return message
end	
function p5001(val)	-- 5001	AP STATUS (2Hz)								flight_mode,armed,batt_FS,ekf_FS
	local simple_mode,land_success

	flight_mode = bit32.extract(val,0,5)
	--simple_mode = bit32.extract(val,5,2)
	--land_success = bit32.extract(val,7,1)
	armed = bit32.extract(val,8,1)
	batt_FS = bit32.extract(val,9,1)
	ekf_FS = bit32.extract(val,10,2)
	
	setTelemetryValue(5001,1,0,flight_mode,0,0,"FM")		-- Flight Mode
end
function p5002(val)	-- 5002	GPS STATUS (1Hz)							num_sats,gps_fix,adv_gps_fix,hdop,alt_msl
	local hdop_expo,hdop_scaled,alt_msl_expo,alt_msl_scaled,alt_msl_direction -- vdop_expo,vdop_scaled,
	
	num_sats = bit32.extract(val,0,4)
	gps_fix = bit32.extract(val,4,2)				-- NO_GPS = 0, NO_FIX = 1, GPS_OK_FIX_2D = 2, GPS_OK_FIX_3D or GPS_OK_FIX_3D_DGPS or GPS_OK_FIX_3D_RTK_FLOAT or GPS_OK_FIX_3D_RTK_FIXED = 3
	hdop_expo = bit32.extract(val,6,1)
	hdop_scaled = bit32.extract(val,7,7)
	adv_gps_fix = bit32.extract(val,14,2)			-- 0: no advanced fix, 1: GPS_OK_FIX_3D_DGPS, 2: GPS_OK_FIX_3D_RTK_FLOAT, 3: GPS_OK_FIX_3D_RTK_FIXED
	alt_msl_expo = bit32.extract(val,22,2)
	alt_msl_scaled = bit32.extract(val,24,7)
	alt_msl_direction = bit32.extract(val,31,1)
	
	hdop = hdop_scaled * math.pow(10,hdop_expo)
	if alt_msl_direction == 0 then alt_msl_direction = 1 else alt_msl_direction = -1 end
	alt_msl = alt_msl_scaled * math.pow(10,alt_msl_expo) * alt_msl_direction
	
	setTelemetryValue(5002,0,0,num_sats,0,0,"Sats")
	setTelemetryValue(5002,1,0,gps_fix,0,0,"GSta")
	setTelemetryValue(5002,4,0,alt_msl,10,1,"GAlt")
end
function p5003(val)	-- 5003	BATT (1Hz)									vfas,curr,fuse,fuel
	local current_expo,current_scaled

	vfas = bit32.extract(val,0,9)							-- deciVolts
	current_expo = bit32.extract(val,9,1)					-- 10^x
	current_scaled = bit32.extract(val,10,7)				-- deciAmps
	fuse = bit32.extract(val,17,15)							-- mAh
	
	curr = current_scaled * math.pow(10,current_expo)		-- Scale
	if params[4] ~= nil then
		fuel = round(100 * ( params[4] - fuse ) / params[4])	-- %
	end
	
	setTelemetryValue(5003,0,0,vfas,1,1,"VFAS")				-- Volts
	setTelemetryValue(5003,1,0,curr,2,1,"Curr")				-- Amps
	if fuel ~= nil then
		setTelemetryValue(5003,3,0,fuel,13,0,"Fuel")		-- %
	end
end
function p5004(val)	-- 5004	HOME (2Hz)									disH,dirH,alt
	local disH_expo,disH_scaled,alt_expo,alt_scaled,alt_dirH
	disH_expo = bit32.extract(val,0,2)
	disH_scaled = bit32.extract(val,2,10)
	alt_expo = bit32.extract(val,12,2)
	alt_scaled = bit32.extract(val,14,10)
	alt_dirH = bit32.extract(val,24,1)
	dirH = bit32.extract(val,25,7)
	
	disH = disH_scaled * math.pow(10,disH_expo)
	dirH = dirH * 3
	if alt_dirH == 0 then alt_dirH = 1 else alt_dirH = -1 end
	alt = alt_scaled * math.pow(10,alt_expo) * alt_dirH

	setTelemetryValue(5004,2,0,alt,9,1,"Alt")	
end
function p5005(val)	-- 5005	VELANDYAW (2Hz)								v_speed,h_speed,hdg
	local v_speed_expo,v_speed_scaled,v_speed_direction,h_speed_expo,h_speed_scaled,v_speed_dump
	
	v_speed_expo = bit32.extract(val,0,1)
	v_speed_scaled = bit32.extract(val,1,7)
	v_speed_direction = bit32.extract(val,8,1)
	h_speed_expo = bit32.extract(val,9,1)
	h_speed_scaled = bit32.extract(val,10,7)
	hdg = bit32.extract(val,17,11)

	if v_speed_direction == 0 then v_speed_direction = 1 else v_speed_direction = -1 end
	v_speed = v_speed_scaled * math.pow(10,v_speed_expo) * v_speed_direction
	h_speed = h_speed_scaled * math.pow(10,h_speed_expo)
	hdg = hdg * .2
	
	setTelemetryValue (5005,1,0,h_speed,5,1,"Spd")	-- m/s
	setTelemetryValue (5005,2,0,hdg,20,0,"Hdg")
	setTelemetryValue (5005,3,0,v_speed,5,0,"VSpd")	-- dm/s
end
function p5006(val)	-- 5006	ATTIANDRNG (Max Hz)							roll,pitch
	local rangefinder_expo,rangefinder_distance_scaled,rangefinder_distance
	roll = bit32.extract(val,0,11)
	pitch = bit32.extract(val,11,10)
	--rangefinder_expo = bit32.extract(val,21,1)
	--rangefinder_distance_scaled = bit32.extract(val,22,10)
	
	roll = roll * .2
	pitch = pitch * .2
	--rangefinder_distance= rangefinder_distance_scaled * math.pow(10,rangefinder_expo)

end
function p5007(val)	-- 5007	PARAMS (sent 3x each at init)
	local param_id,param_val
	param_val = bit32.extract(val,0,24)
	param_id = bit32.extract(val,24,8)
	return param_id,param_val
end

-- Draw Screen
function drawBG()
	-- TOP BAR --
	lcd.drawRectangle(0,0,53,8,SOLID)
	lcd.drawFilledRectangle(0,0,53,8,SOLID)
	lcd.drawRectangle(158,0,54,8,SOLID)
	lcd.drawFilledRectangle(158,0,54,8,SOLID)
	
	-- BOT BAR -- 
	lcd.drawRectangle(0,56,53,8,SOLID)
	lcd.drawFilledRectangle(0,56,53,8,SOLID)
	lcd.drawRectangle(158,56,54,8,SOLID)
	lcd.drawFilledRectangle(158,56,54,8,SOLID)
	
	-- LEFT BAR --	
	lcd.drawRectangle(50,8,3,48,SOLID)				
	lcd.drawFilledRectangle(50,8,3,48,SOLID)
	
	-- RIGHT BAR --
	lcd.drawRectangle(158,8,3,48,SOLID)				
	lcd.drawFilledRectangle(158,8,3,48,SOLID)
	
	-- GPS --
	lcd.drawLine(anchor_x, anchor_y + 17, anchor_x, anchor_y + 34,SOLID,FORCE)				-- GPS big block
	lcd.drawFilledRectangle(anchor_x, anchor_y + 17, 21,18,SOLID,FORCE)
	
	lcd.drawPoint(anchor_x + 21, anchor_y + 19,SOLID, FORCE)	-- Top Slant
	
	lcd.drawLine(anchor_x + 21, anchor_y + 29, anchor_x + 21, anchor_y + 32, SOLID, FORCE)	-- Bot Slant
	lcd.drawLine(anchor_x + 22, anchor_y + 29, anchor_x + 22, anchor_y + 31, SOLID, FORCE)	
	lcd.drawLine(anchor_x + 23, anchor_y + 29, anchor_x + 23, anchor_y + 30, SOLID, FORCE)
	lcd.drawPoint(anchor_x + 24, anchor_y + 29, SOLID, FORCE)
	
	lcd.drawRectangle(anchor_x + 21,anchor_y + 20,30,9,SOLID,FORCE)			-- SATs small block
	lcd.drawFilledRectangle(anchor_x + 21,anchor_y + 20,30,9,SOLID,FORCE)
	
	drawTarget()
	
	-- HUD SECTION --
		-- Compass --
	lcd.drawLine(center_x - 52, top_y_limit, center_x + 52, top_y_limit, SOLID, FORCE)
	
		-- SPEED --
	lcd.drawLine(left_x_limit, top_y_limit, left_x_limit, bot_y_limit, SOLID, FORCE)
	lcd.drawFilledRectangle(left_x_limit - 15, center_y - 4, 17, 8, SOLID)
	lcd.drawLine(left_x_limit - 15, center_y - 4, left_x_limit - 15, center_y + 3, SOLID, FORCE)
	lcd.drawLine(left_x_limit + 2, center_y + 1, left_x_limit + 2, center_y - 2, SOLID, FORCE)
	lcd.drawLine(left_x_limit + 3, center_y, left_x_limit + 3, center_y - 1, SOLID, FORCE)
	
		-- SPEED LINES
	local spread = (bot_y_limit - top_y_limit - 7) / 4	
	lcd.drawLine(left_x_limit - 6, top_y_limit + spread, left_x_limit - 1, top_y_limit + spread, DOTTED, FORCE)	-- Mid-top
	lcd.drawLine(left_x_limit - 6, bot_y_limit - spread, left_x_limit - 1, bot_y_limit - spread, DOTTED, FORCE)	-- Mid-Bot
	
		-- ALT --
	lcd.drawLine(right_x_limit, top_y_limit, right_x_limit, bot_y_limit, SOLID, FORCE)
	lcd.drawFilledRectangle(right_x_limit - 1, center_y - 4, 17, 8, SOLID)
	lcd.drawLine(right_x_limit + 15, center_y - 4, right_x_limit + 15, center_y + 3, SOLID, FORCE)
	lcd.drawLine(right_x_limit - 2, center_y + 1, right_x_limit - 2, center_y - 2, SOLID, FORCE)
	lcd.drawLine(right_x_limit - 3, center_y, right_x_limit - 3, center_y - 1, SOLID, FORCE)

		-- ALT LINES --
	lcd.drawLine(right_x_limit + 1, top_y_limit + spread, right_x_limit + 6, top_y_limit + spread, DOTTED, FORCE)	-- Mid-top
	lcd.drawLine(right_x_limit + 1, bot_y_limit - spread, right_x_limit + 6, bot_y_limit - spread, DOTTED, FORCE)	-- Mid-Bot

end
function drawFM()
	local fm, text
	local fm_array = {}
	
	if flight_mode ~= nil then
		fm_array = 	{ "Manual","Circle","Stablze","Train","Acro","FBWA","FBWB",
					"Cruise","A-Tune","9","Auto","RTL","Loiter","Avoid","Guided",
					"QStablze","QHover","QLoiter","QLand","QRTL" 
					}
					
		text = fm_array[flight_mode]
		if flight_mode_prev ~= flight_mode then announceFM() end

	else fm,text = getFlightMode()
	end
	lcd.drawText(1,1,"FM: " .. text, INVERS + SMLSIZE)
end
function drawRSSI()
	local rssi,rssi_low,rssi_crit,rssi_hi,rssi_x1,spread,opt

	-- RSSI 	45db = low alarm	42db = crit alarm
	rssi,rssi_low,rssi_crit = getRSSI("RSSI")
	rssi_hi = 100
	spread = (rssi_hi - rssi_crit) / 4
	rssi_x1 = 160
	opt = GREY(9)
	
	lcd.drawText(rssi_x1,1,"Tx: ", INVERS + SMLSIZE)	
	if rssi > rssi_crit then lcd.drawRectangle(rssi_x1 + 14,6,2,1,ERASE) else lcd.drawRectangle(174,6,2,1,opt) end
	if rssi > rssi_hi - round(spread * 3) then lcd.drawRectangle(rssi_x1 + 17,4,2,3,ERASE) else lcd.drawRectangle(rssi_x1 + 17,4,2,3,opt) end
	if rssi > rssi_hi - round(spread * 2) then lcd.drawRectangle(rssi_x1 + 20,2,2,5,ERASE) else lcd.drawRectangle(rssi_x1 + 20,2,2,5,opt) end
	if rssi > rssi_hi - round(spread * 1) then lcd.drawRectangle(rssi_x1 + 23,0,2,7,ERASE) else lcd.drawRectangle(rssi_x1 + 23,0,2,7,opt) end
end
function drawTxBt()
	local txbt
	txbt = getValue("tx-voltage") * 10
	lcd.drawNumber(205, 1, txbt, RIGHT + PREC1 + INVERS + SMLSIZE)
	lcd.drawText(211,1,"V", RIGHT + INVERS + SMLSIZE)
end
function drawVoltage()
	if vfas == nil then return end
	local voltage_x1, voltage_y1 = 26, 9
	if params[2] ~= nil then
		if vfas >= (params[2] / 10) then lcd.drawNumber(voltage_x1, voltage_y1, vfas, PREC1 + MIDSIZE + RIGHT )
		else lcd.drawNumber(voltage_x1, voltage_y1, vfas, PREC1 + MIDSIZE + INVERS + BLINK + RIGHT )
		end
	else lcd.drawNumber(voltage_x1, voltage_y1, vfas, PREC1 + MIDSIZE + RIGHT )
	end
	lcd.drawText(27, voltage_y1 + 3, "V", SMLSIZE)
end
function drawAmps()
	if curr == nil or vfas == nil then return end
	local current_x1,current_y1 = 26, 23
	if display == 0 then
		lcd.drawNumber(current_x1, current_y1, curr, MIDSIZE + PREC1 + RIGHT)
		lcd.drawText(27, current_y1 + 3, "A", SMLSIZE)
	elseif display == 1 then
		local power = round(curr * vfas)
		if power < 1000 then
			lcd.drawNumber(current_x1, current_y1, power, MIDSIZE + PREC1 + RIGHT)
		elseif power >= 1000 then
			lcd.drawNumber(current_x1, current_y1, round(power / 10), MIDSIZE + RIGHT)
		end
		lcd.drawText(27, current_y1 + 3, "W", SMLSIZE)
	end
end
function drawFuelRemain()
	if fuse == nil then return end 
	local fuel_remain_x1, fuel_remain_y1 = 24, 35
	if params[4] ~= nil then
		local fuel_left = params[4] - fuse
		if fuel_left < 100000 and fuel_left >= 10000 then
			lcd.drawNumber(fuel_remain_x1 + 1, fuel_remain_y1 + 2, fuel_left / 100, MIDSIZE + PREC1 + RIGHT)
			lcd.drawText(fuel_remain_x1 + 2, fuel_remain_y1 + 5, "Ah", SMLSIZE)
		elseif fuel_left < 10000 and fuel_left >= 1000 then
			lcd.drawNumber(fuel_remain_x1 + 1, fuel_remain_y1 + 2, fuel_left / 10, MIDSIZE + PREC2 + RIGHT)
			lcd.drawText(fuel_remain_x1 + 2, fuel_remain_y1 + 5, "Ah", SMLSIZE)
		elseif fuel_left < 1000 then
			if params[3] ~= nil then
				if fuel_left >= params[3] then lcd.drawNumber(fuel_remain_x1, fuel_remain_y1 + 2, fuel_left, MIDSIZE + RIGHT)
				elseif fuel_left < params[3] then lcd.drawNumber(fuel_remain_x1, fuel_remain_y1 + 2, fuel_left, MIDSIZE + BLINK + INVERS + RIGHT)
				end
			else lcd.drawNumber(fuel_remain_x1, fuel_remain_y1 + 2, fuel_left, MIDSIZE + RIGHT)
			end
			lcd.drawText(fuel_remain_x1 + 3, fuel_remain_y1, "m", SMLSIZE)
			lcd.drawText(fuel_remain_x1 + 2, fuel_remain_y1 + 7, "Ah", SMLSIZE)
		end
	lcd.drawText(fuel_remain_x1 + 7, fuel_remain_y1 + 14, "remain", SMLSIZE + RIGHT)
	end
end
function drawFuel()
	if fuel == nil then return end
	local fuel_x1,fuel_y1,fuel_w,fuel_h = 36,12,12,34
	fuel = round(fuel)
	
	lcd.drawRectangle(fuel_x1,fuel_y1,fuel_w,fuel_h, SOLID)
	lcd.drawRectangle(fuel_x1 - 3 + fuel_w / 2,fuel_y1 - 2, fuel_w / 2, 3, SOLID)
	
	local spread = round((fuel_h - 1) * fuel / 100)
	lcd.drawFilledRectangle(fuel_x1 + 1, fuel_y1 + fuel_h - spread, fuel_w - 2, spread - 1, GREY(menu_option_shade))
	
	spread = fuel_h / 4
	lcd.drawLine(fuel_x1 + fuel_w - 4, fuel_y1 + round(spread * 1), fuel_x1 + fuel_w - 2, fuel_y1 + round(spread * 1), SOLID, FORCE)
	lcd.drawLine(fuel_x1 + fuel_w - 4, fuel_y1 + round(spread * 2), fuel_x1 + fuel_w - 2, fuel_y1 + round(spread * 2), SOLID, FORCE)
	lcd.drawLine(fuel_x1 + fuel_w - 4, fuel_y1 + round(spread * 3), fuel_x1 + fuel_w - 2, fuel_y1 + round(spread * 3), SOLID, FORCE)
	
	if fuel <= 100 and fuel > 9  then lcd.drawText(fuel_x1 + 14 ,fuel_y1 + fuel_h + 2, fuel .. "%", SMLSIZE + RIGHT)
	elseif fuel <= 9 then lcd.drawText(fuel_x1 + 14 ,fuel_y1 + fuel_h + 2, fuel .. "%", SMLSIZE + INVERS + BLINK + RIGHT)
	end
end
function drawSpeed()
	if h_speed == nil then lcd.drawText(center_x - 37, center_y - 3, "spd", SMLSIZE + INVERS + RIGHT) return end
	local aspd_x,speed_offset,speed_top,speed_bot,h_speed_m,speedline_y
	if h_speed >= 100 then aspd_x = 3 else aspd_x = 5 end	
	lcd.drawNumber(center_x - aspd_x - 33, center_y - 3, h_speed, PREC1 + SMLSIZE + INVERS + RIGHT)
	
	speed_offset = roundInt(h_speed / 10, 5)
	speed_top = speed_offset + 5
	speed_bot = speed_offset - 5
	if speed_bot < 0 then speed_bot = 0 end
	if speed_top < 10 then speed_top = 10 end
	
	if speed_top >= 10 then aspd_x = 4 else aspd_x = 6 end
	lcd.drawNumber(left_x_limit - aspd_x, top_y_limit + 2, speed_top, SMLSIZE + RIGHT)
	
	if speed_bot >= 10 then aspd_x = 4 else aspd_x = 6 end
	lcd.drawNumber(left_x_limit - aspd_x, bot_y_limit - 6, speed_bot, SMLSIZE + RIGHT)
	
	h_speed_m = h_speed / 10
	if speed_top - 5 < h_speed_m then speedline_y = center_y - 4 - (h_speed_m - (speed_top - 5)) / 5 * (center_y - top_y_limit - 5)
	elseif speed_bot + 5 > h_speed_m then speedline_y = center_y + 4 + (speed_bot + 5 - h_speed_m) / 5 * (bot_y_limit - center_y - 4)
	elseif speed_top - 5 == h_speed_m or speed_bot + 5 == h_speed_m then return
	end
	if speedline_y ~= nil then lcd.drawLine(left_x_limit - 3, speedline_y, left_x_limit - 1, speedline_y, SOLID, FORCE + GREY(6)) end
	
end
function drawAlt()
	local altitude_m,sensor,alt_x,alt_line_offset,alt_line_top,alt_line_bot,alt_line_y

	if (alt ~= nil and menu_option_alt == 0) then
		altitude_m = round(alt / 10)
		sensor = "B"
	elseif alt_msl ~= nil and menu_option_alt == 1 then
		if gps_fix >= 3 then
			altitude_m = round(alt_msl / 10)
			sensor = "G"
		end
	end

	if altitude_m == nil then lcd.drawText(center_x + 53, center_y - 3, "alt", SMLSIZE + INVERS + RIGHT) return end
	if altitude_m >= 100 then alt_x = 20 elseif altitude_m >= 10 then alt_x = 18 else alt_x = 15 end
	lcd.drawNumber(center_x + alt_x + 33, center_y - 3, altitude_m, SMLSIZE + INVERS + RIGHT)
	lcd.drawText(center_x + 52, center_y + 5, sensor, SMLSIZE + RIGHT)
	
	alt_line_offset = roundInt(altitude_m, 10)
	alt_line_top = alt_line_offset + 10
	alt_line_bot = alt_line_offset - 10
	if alt_line_bot < 0 then alt_line_bot = 0 alt_line_top = 20 end
	
	if alt_line_top >= 100 then alt_x = 16 elseif alt_line_top >= 10 then alt_x = 16 else alt_x = 14 end
	lcd.drawNumber(right_x_limit + alt_x, top_y_limit + 2, alt_line_top, SMLSIZE + RIGHT)
	
	if alt_line_bot >= 100 then alt_x = 16 elseif alt_line_bot >= 10 then alt_x = 16 else alt_x = 14 end
	lcd.drawNumber(right_x_limit + alt_x, bot_y_limit - 6, alt_line_bot, SMLSIZE + RIGHT)
	
	if alt_line_top - 10 < altitude_m then alt_line_y = center_y - 4 - (altitude_m - (alt_line_top - 10)) / 10 * (center_y - top_y_limit - 5)
	elseif alt_line_bot + 10 > altitude_m then alt_line_y = center_y + 4 + (alt_line_bot + 10 - altitude_m) / 10 * (bot_y_limit - center_y - 4)
	elseif alt_line_top - 10 == altitude_m or alt_line_bot + 10 == altitude_m then return
	end
	if alt_line_y ~= nil then lcd.drawLine(right_x_limit + 1, alt_line_y, right_x_limit + 3, alt_line_y, SOLID, FORCE + GREY(6)) end
	
end
function drawPlane()
	local bar_x_outer,bar_x_inner = 25,14
	lcd.drawLine(center_x, center_y + 1, center_x - 5, center_y + 3, SOLID, FORCE)
	lcd.drawLine(center_x, center_y + 1, center_x + 5, center_y + 3, SOLID, FORCE)
	lcd.drawLine(center_x - bar_x_outer, center_y, center_x - bar_x_inner, center_y, SOLID, FORCE)
	lcd.drawLine(center_x + bar_x_inner, center_y, center_x + bar_x_outer, center_y, SOLID, FORCE)
end
function drawHorizon()
	if roll == nil or pitch == nil then return end
	local x1,y1,x2,y2,n = nil

	local opt = FORCE + GREY(menu_option_shade)

	if roll <= roll_atan or (roll > 180 - roll_atan and roll <= 180 + roll_atan) or roll >= 360 - roll_atan then
		for n = left_x_limit,right_x_limit,1 do
			x1 = n
			x2 = n
			y1 = round(roll_tan * x1 + b)
			y2 = bot_y_limit + 1

			if y1 > bot_y_limit + 1 then y1 = bot_y_limit + 1 elseif y1 < top_y_limit then y1 = top_y_limit end
			if (roll >= 360 - roll_atan or roll <= roll_atan) then y2 = top_y_limit end
			if pitch >= 180 then if y2 == bot_y_limit + 1 then y2 = top_y_limit else y2 = bot_y_limit + 1 end end
			
			lcd.drawLine(x1,y1,x2,y2,SOLID,opt)
		end
	elseif (roll > roll_atan and roll <= 180 - roll_atan) or (roll > 180 + roll_atan and roll < 360 - roll_atan) then
		for n = top_y_limit,bot_y_limit,1 do
			y1 = n
			y2 = n
			x1 = round(y1 - b) / roll_tan
			x2 = left_x_limit

			if x1 < left_x_limit then x1 = left_x_limit elseif x1 > right_x_limit then x1 = right_x_limit end
			if ( roll < 360 - roll_atan and roll > 180 + roll_atan ) then x2 = right_x_limit end
			if (roll_atan < 0 and pitch >= 180) then if x2 == left_x_limit then x2 = right_x_limit else x2 = left_x_limit end end
			if (roll_atan >= 0 and pitch >= 180) then if x2 == left_x_limit then x2 = right_x_limit else x2 = left_x_limit end end
			
			lcd.drawLine(x1,y1,x2,y2,SOLID,opt)
		end
	end
end
function drawHorizonAngles()
	local angle,x1,x2,y1,y2,cosrad,sinrad
	local frad = 26
	local irad = 24
		
	for n = 1,3,1 do
		angle = 180 - n * 30
		cosrad = math.cos(math.rad(angle))
		sinrad = math.sin(math.rad(angle))
		
		x1 = round(center_x - cosrad * irad)
		x2 = round(center_x - cosrad * frad)
		y1 = round(center_y - sinrad * irad)
		y2 = round(center_y - sinrad * frad)
		lcd.drawLine(x1,y1,x2,y2,SOLID,FORCE)
		
		if n ~= 3 then
			x1 = round(center_x + cosrad * irad)
			x2 = round(center_x + cosrad * frad)
			y1 = round(center_y - sinrad * irad)
			y2 = round(center_y - sinrad * frad)
			lcd.drawLine(x1,y1,x2,y2,SOLID,FORCE)
		end
	end	
end
function drawPitch()
	local line_distance,line_offset,line_length,xll,yll,line_center_x,line_center_y,x1,y1,x2,y2

	if pitch == nil or roll == nil then return end
	
	if pitch > 180 then pitch_calc = 360 - pitch else pitch_calc = pitch end
	
	line_distance = (bot_y_limit - center_y) / 2
	line_offset = (pitch_calc - 90) / 15
	line_length = 12
	xll = roll_cos * line_length
	yll = roll_sin * line_length
	
	if pitch < 180 then 
		center_x_float = round(center_x + line_offset * roll_sin * line_distance)
		center_y_float = round(center_y - line_offset * roll_cos * line_distance)
	else
		center_x_float = round(center_x - line_offset * roll_sin * line_distance)
		center_y_float = round(center_y + line_offset * roll_cos * line_distance)
	end
	
	for n = -20,20,1 do
		if n ~= 0 then
			
			line_center_x = round(center_x_float - roll_sin * line_distance * n)
			line_center_y = round(center_y_float + roll_cos * line_distance * n)
			
			x1 = round(line_center_x - xll)
			x2 = round(line_center_x + xll)
			y1 = round(line_center_y - yll)
			y2 = round(line_center_y + yll)
			
			if not ((x1 < left_x_limit and x2 < left_x_limit) or (x1 > right_x_limit and x2 > right_x_limit) or (y1 < top_y_limit and y2 < top_y_limit) or (y1 > bot_y_limit + 1 and y2 > bot_y_limit + 1)) then
				
				if y2 < top_y_limit then
					y2 = top_y_limit
					x2 = round(line_center_x - (line_center_y - y2) / roll_tan)
				elseif y2 > bot_y_limit then
					y2 = bot_y_limit
					x2 = round(line_center_x - (line_center_y - y2) / roll_tan)
				end
				
				if y1 < top_y_limit then
					y1 = top_y_limit
					x1 = round(line_center_x - (line_center_y - y1) / roll_tan)
				elseif y1 > bot_y_limit then 
					y1 = bot_y_limit
					x1 = round(line_center_x - (line_center_y - y1) / roll_tan)
				end
				
				if x1 < left_x_limit then
					x1 = left_x_limit
					y1 = round(line_center_y + roll_tan * (x1 - line_center_x))
				elseif x1 > right_x_limit then 
					x1 = right_x_limit
					y1 = round(line_center_y + roll_tan * (x1 - line_center_x))
				end
				
				if x2 < left_x_limit then
					x2 = left_x_limit
					y2 = round(line_center_y + roll_tan * (x2 - line_center_x))
				elseif x2 > right_x_limit then
					x2 = right_x_limit
					y2 = round(line_center_y + roll_tan * (x2 - line_center_x))
				end
	
				lcd.drawLine(x1,y1,x2,y2,DOTTED,FORCE)
			end
		end
	end
end
function drawHeading()
	local i
	if hdg == nil then return end 
	local line_spacing,label_spacing = 13,39
	local line_offset = round(line_spacing / 15 * (hdg % 15))
	local center_label = center_x - 2
	
	for i = -4,4,1 do
		local dir_x = center_x - line_offset + i * line_spacing
		if dir_x >= 53 and dir_x <= 157 then
			lcd.drawLine(dir_x, top_y_limit - 1, dir_x, top_y_limit - 2, SOLID, FORCE)
		end	
	end
	for i = -2,2,1 do
		local direction = hdg + 45 * i
		local label = hdgDirection(direction)
		local label_offset = round(label_spacing / 45 * (direction % 45))
		local label_x = center_label - label_offset + i * label_spacing
		
		if label_x < 149 and label_x > 52 then 
			lcd.drawText(label_x,1,label,SMLSIZE) 
		end
	end
end
function drawDirHLine()
	if hdg == nil or dirH == nil then return end
	local spread = 52
	local dirH_x
	
	if hdg == dirH then dirH_x = center_x	
	elseif math.abs(hdg - dirH) == 180 then
		dirH_x = center_x - spread
		lcd.drawLine(dirH_x, top_y_limit - 1, dirH_x, 0, SOLID, FORCE + GREY(6))
		lcd.drawLine(dirH_x, top_y_limit / 2 - 2, dirH_x + 3, top_y_limit / 2 - 2, SOLID, FORCE + GREY(6))
		dirH_x = center_x + spread
	elseif (dirH - hdg > 60 and dirH - hdg < 180) or (hdg - dirH > 180 and hdg - dirH < 300)  then dirH_x = center_x + spread
	elseif (dirH > hdg + 180 and dirH < 300) or (hdg - dirH > 60 and hdg - dirH < 180) then dirH_x = center_x - spread

	elseif dirH > hdg then
		if dirH - hdg <= 60 then dirH_x = round(center_x + (dirH - hdg) / 60 * spread)
		elseif dirH - hdg >= 300 then dirH_x = round(center_x - (360 + hdg - dirH) / 60 * spread)
		end
	elseif dirH < hdg then
		if hdg - dirH <= 60 then dirH_x = round(center_x - (hdg - dirH) / 60 * spread)
		elseif hdg - dirH >= 300 then dirH_x = round(center_x + (360 - hdg + dirH) / 60 * spread)
		end
	end
	
	if dirH_x == nil then return end	
	
	lcd.drawLine(dirH_x, top_y_limit - 1, dirH_x, 0, SOLID, FORCE + GREY(6))
	
	if dirH_x == center_x - spread then lcd.drawLine(dirH_x, top_y_limit / 2 - 2, dirH_x + 3, top_y_limit / 2 - 2, SOLID, FORCE + GREY(6))
	elseif dirH_x == center_x + spread then lcd.drawLine(dirH_x, top_y_limit / 2 - 2, dirH_x - 3, top_y_limit / 2 - 2, SOLID, FORCE + GREY(6))
	end
end
function drawDirHPointer()
	if hdg == nil or dirH == nil then return end
	local p_anchor_x,p_anchor_y,dir_pointer_angle,radius,top_x,top_y,r_x,r_y,l_x,l_y
	p_anchor_x, p_anchor_y = anchor_x + 8, top_y_limit + 8
	
	if dirH >= hdg then dir_pointer_angle = dirH - hdg
	elseif dirH < hdg then dir_pointer_angle = dirH - hdg
	end
	
	radius = 7
	
	local cos90p = math.cos(math.rad(dir_pointer_angle + 90))
	local sin90p = math.sin(math.rad(dir_pointer_angle + 90))
	local cos225 = math.cos(math.rad(dir_pointer_angle + 225))
	local cos315 = math.cos(math.rad(dir_pointer_angle + 315))
	local sin225 = math.sin(math.rad(dir_pointer_angle + 225))
	local sin315 = math.sin(math.rad(dir_pointer_angle + 315))
	
	local top_x = p_anchor_x - round(radius * cos90p)
	local top_y = p_anchor_y - round(radius * sin90p)
	local r_x = p_anchor_x - round(radius * cos225)
	local r_y = p_anchor_y - round(radius * sin225)
	local l_x = p_anchor_x - round(radius * cos315)
	local l_y = p_anchor_y - round(radius * sin315)
	
	lcd.drawLine(top_x,top_y,r_x,r_y,SOLID,FORCE)
	lcd.drawLine(top_x,top_y,l_x,l_y,SOLID,FORCE)
	
	lcd.drawLine(r_x,r_y,p_anchor_x,p_anchor_y,SOLID,FORCE)
	lcd.drawLine(l_x,l_y,p_anchor_x,p_anchor_y,SOLID,FORCE)
	
end
function drawDisH()
	if disH == nil then return end
	local units
	
	if disH >= 10000 then
		lcd.drawNumber(anchor_x + 39, anchor_y + 1, disH / 1000, DBLSIZE + RIGHT)
		units = "km"
	elseif disH >= 1000 then
		lcd.drawNumber(anchor_x + 39, anchor_y + 1, disH / 100, PREC1 + DBLSIZE + RIGHT)
		units = "km"
	elseif disH < 1000 then
		lcd.drawText(anchor_x + 44, anchor_y + 1, disH, DBLSIZE + RIGHT)
		units = "m"
	end
	lcd.drawText(anchor_x + 51, anchor_y + 8, units, SMLSIZE + RIGHT)
end
function drawGPS()
	if num_sats == nil or gps_fix == nil or adv_gps_fix == nil then return end
	local text,text2,x_offset	
	
	if gps_fix == 0 then text = "GPS"
	elseif gps_fix == 1 then text = "FIX"
	elseif gps_fix == 2 then text = "2D"
	elseif gps_fix >= 3 then text = "3D"
	end

	if adv_gps_fix == 0 then text2,x_offset = "NO GPS STAT",211
	elseif adv_gps_fix == 1 then text2,x_offset = "DGPS",198
	elseif adv_gps_fix == 2 then text2,x_offset = "RTK FLOAT",208
	elseif adv_gps_fix == 3 then text2,x_offset = "RTK FIXED",208
	end
	
	if gps_fix < 2 then
		lcd.drawText(anchor_x + 3, anchor_y + 17, "NO", MIDSIZE + INVERS)
		lcd.drawText(anchor_x + 30, anchor_y + 20, text, INVERS)
		lcd.drawText(anchor_x + 49, anchor_y + 33, "N.A.", MIDSIZE + RIGHT)
	elseif gps_fix >= 2 then
		lcd.drawText(anchor_x + 1, anchor_y + 18, text, DBLSIZE + INVERS)
		drawGPSPrecision()
		
		lcd.drawText(anchor_x + 52, anchor_y + 21, num_sats .. " sat", SMLSIZE + RIGHT + INVERS)
		
		if string.match(menu_option_gps,"1") then drawGPSCoord() end
	end
	lcd.drawText(x_offset, 57, text2, SMLSIZE + RIGHT + INVERS)
end
function drawGPSPrecision()
	if hdop == nil or hdop >= 1000000 then return end
	local units
	
	if hdop >= 10000 then lcd.drawNumber(anchor_x + 39, anchor_y + 30, round(hdop / 10000), DBLSIZE + RIGHT) units = "km"
	elseif hdop >= 1000 then 
	lcd.drawText(anchor_x + 30, anchor_y + 30, ".", DBLSIZE + RIGHT)
	lcd.drawNumber(lcd.getLastRightPos(), anchor_y + 30, round(hdop / 1000), DBLSIZE) 
	units = "km"
	elseif hdop >= 100 then lcd.drawNumber(anchor_x + 44, anchor_y + 30, round(hdop / 10), DBLSIZE + RIGHT) units = "m"
	elseif hdop < 100 then lcd.drawNumber(anchor_x + 44, anchor_y + 30, hdop, PREC1 + DBLSIZE + RIGHT) units = "m"	
	end
	lcd.drawText(anchor_x + 51, anchor_y + 38, units, SMLSIZE + RIGHT)
end
function drawTarget()
	lcd.drawPixmap(anchor_x + 1, anchor_y + 38, "/IMAGES/trgt.bmp")
	lcd.drawLine(anchor_x + 11, anchor_y + 36, anchor_x + 11, anchor_y + 41, SOLID, FORCE)
end
function drawGPSCoord()
	local gps_table = getValue('GPS')
	if (type(gps_table) == "table") then
		gps_lat = roundInt(gps_table["lat"] * 100,1) / 100
		gps_lon = roundInt(gps_table["lon"] * 100,1) / 100
		--if gps_lat == nil or gps_lon == nil then 
			--lcd.drawText(left_x_limit + 11, bot_y_limit - 7, "no GPS coord", SMLSIZE + BLINK) 
		--	return 
		--end
	end
	if gps_lat == nil or gps_lon == nil then return end
	lcd.drawText(left_x_limit + 2, bot_y_limit - 7, gps_lat, SMLSIZE)
	lcd.drawText(right_x_limit - 1, bot_y_limit - 7, gps_lon, SMLSIZE + RIGHT)
end
function drawTimer()
	local minutes,seconds
	local timer = model.getTimer(0)
	
	if (type(timer)) == "table" then
		seconds = timer["value"] % 60
		minutes = math.floor(timer["value"] / 60)
		lcd.drawText(40, 57, seconds .. "s", SMLSIZE + INVERS + RIGHT)
		lcd.drawText(20, 57, minutes .. "m", SMLSIZE + INVERS + RIGHT)
	end
end
function drawArmed()
	local text
	if armed == nil then return
	elseif armed == 0 then lcd.drawText(center_x - 34, center_y + 7, "DISARMED", MIDSIZE) text = "D"
	elseif armed == 1 then text = "A"
	end	
	lcd.drawText(48, 57, text, SMLSIZE + INVERS) 
end
function drawMessage()	-- Comments Here
	local message
	if test_mode then
		message = "TEST MODE"
	else
		message = "message"
	end
	--lcd.drawText(5,57,message, SMLSIZE + INVERS)
end


return { run=run, background=bg, init=init  }