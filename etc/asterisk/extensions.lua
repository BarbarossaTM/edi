extensions = {}
extensions["from-sipgate"] = {}


function Set (list)
  local set = {}
  for _, l in ipairs(list) do set[l] = true end
  return set
end

sms_tts_callees = Set({"01930100"})

user_db = {}
user_db["foo"] = { nick = "irq0" }
user_db["foo"] = { nick = "irq0" }
user_db["foo"] = { nick = "snowball" }

menu = {}

menu["1"] = function(callee)
	-- todo message like "blabla press rautetaste"
	app.Record("/tmp/call_" .. callee .. "_%d.wav", 0, 60, "k")

	filename = channel.RECORDED_FILE:get()

	app.verbose("Recorded message from " .. user_db[callee].nick .. ": " .. filename)
	os.execute("AMQP_SERVER=172.17.42.1 /srv/edi/emit_notification " .. filename .. ".*")
end

menu["5"] = function(callee)
	f = io.popen("AMQP_SERVER=172.17.42.1 /srv/edi/read_msg.py /tmp 2> /dev/null")

	for fn in f:lines() do
		app.verbose("Playing: " .. fn .. " for " .. callee)
		app.playback(string.gsub(fn, ".mp3",""))
	end
end

function fuckyou()
	app.playback("tt-monkeys")
	app.hangup()
end

function handle_sms_tts()
	app.Record("/tmp/sms_%d.wav", 0, 60, "y")
	app.hangup()
end

function authorized_call(callee)
	if sms_tts_callees[callee] then
		handle_sms_tts()
	else
		app.verbose("User " .. user_db[callee]["nick"] .. " connected")
		main_menu(callee)
	end
end

function main_menu(callee)
	app.answer()

	app.read("menuitem", "/srv/edi/menu", 1)
	i = channel["menuitem"]:get()
	app.saydigits(i)

	if menu[i] then
		menu[i](callee)
	else
		fuckyou()
	end

	app.hangup()
end

extensions["from-sipgate"]["_X."] = function(context, extension)
	app.verbose("Call from " .. channel.CALLERID("all"):get())

	callee = channel.CALLERID("num"):get()

	if user_db[callee] then
		authorized_call(callee)
	else
		app.verbose("Rejecting call from " .. callee)
		fuckyou()
	end
end
