ESX.RegisterServerCallback('linden_outlawalert:getCharData', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not xPlayer then return end
	MySQL.query('SELECT firstname, lastname, phone_number FROM users WHERE identifier = ?', {xPlayer.identifier}, function(result)
		if result then
			print(ESX.DumpTable(result))
			cb(result[1])
		end
	end)
	-- MySQL.Async.fetchAll('SELECT firstname, lastname, phone_number FROM users WHERE identifier = @identifier', {
	-- 	['@identifier'] = identifier
	-- }, function(results)
	-- 	cb(results[1])
	-- end)
end)

ESX.RegisterServerCallback('linden_outlawalert:isVehicleOwned', function(source, cb, plate)
	MySQL.scalar('SELECT plate FROM owned_vehicles WHERE plate = ?', {plate}, function(theReturnPlate)
		print(theReturnPlate)
		if theReturnPlate then
			cb(true)
		else
			cb(false)
		end
	end)
end)

function getCaller(src)
	local xPlayer = ESX.GetPlayerFromId(src)
	if not xPlayer then return end
	return xPlayer.name
end

function getTitle(src)
	local xPlayer = ESX.GetPlayerFromId(src)
	if not xPlayer then return end
	local title = ('%s %s'):format(xPlayer.job.grade_label, xPlayer.get('lastName'))
	return title
end

local dispatchCodes = {
	melee = { displayCode = '10-10', description = _U('melee'), isImportant = 0, recipientList = {'police'},
	blipSprite = 652, blipColour = 84, blipScale = 1.5 },

	officerdown = {displayCode = '10-99', description = _U('officerdown'), isImportant = 1, recipientList = {'police', 'ambulance'},
	blipSprite = 653, blipColour = 84, blipScale = 1.5, infoM = 'fa-portrait'},

	persondown = {displayCode = '10-52', description = _U('persondown'), isImportant = 0, recipientList = {'police', 'ambulance'},
	blipSprite = 153, blipColour = 84, blipScale = 1.5, infoM = 'fa-portrait'},

	autotheft = {displayCode = '10-16', description = _U('autotheft'), isImportant = 0, recipientList = {'police'},
	blipSprite = 651, blipColour = 84, blipScale = 1.5, infoM = 'fa-car', infoM2 = 'fa-palette' },

	speeding = {displayCode = '10-66', description = _U('speeding'), isImportant = 0, recipientList = {'police'},
	blipSprite = 650, blipColour = 84, blipScale = 1.5, infoM = 'fa-car', infoM2 = 'fa-palette' },

	shooting = { displayCode = '10-13', description = _U('shooting'), isImportant = 0, recipientList = {'police'},
	blipSprite = 648, blipColour = 84, blipScale = 1.5 },

	driveby = { displayCode = '10-13', description = _U('driveby'), isImportant = 0, recipientList = {'police'},
	blipSprite = 649, blipColour = 84, blipScale = 1.5, infoM = 'fa-car', infoM2 = 'fa-palette' },
}


--[[ Example custom alert
RegisterCommand('testvangelico', function(playerId, args, rawCommand)
	local data = {displayCode = '211', description = 'Robbery', isImportant = 0, recipientList = {'police'}, length = '10000', infoM = 'fa-info-circle', info = 'Vangelico Jewelry Store'}
	local dispatchData = {dispatchData = data, caller = 'Alarm', coords = vec3(-633.9, -241.7, 38.1)}
	TriggerEvent('wf-alerts:svNotify', dispatchData)
end, false)
--]]


local blacklistedIdentifiers = {
	'steam:xxxxxxxxxxx',
	'license:xxxxxxxxxxx',
	'discord:xxxxxxxxxxx'
}

function Blacklisted(source)
	local Identifiers = GetPlayerIdentifiers(source)
	for _, theClientIdentifier in pairs(Identifiers) do
		for k, theBlacklistedIdentifier in pairs(blacklistedIdentifiers)
		if theClientIdentifier == theBlacklistedIdentifier then
			return true
		end
	end
	return false
end

RegisterServerEvent('wf-alerts:svNotify')
AddEventHandler('wf-alerts:svNotify', function(pData)
	if not Blacklisted(source) then
		local dispatchData
		if pData.dispatchCode == 'officerdown' then
			pData.info = getTitle(source)
		end
		if pData.dispatchCode == 'persondown' then
			pData.caller = getCaller(source)
		end
		if not pData.dispatchCode then dispatchData = pData.dispatchData elseif dispatchCodes[pData.dispatchCode] ~= nil then dispatchData = dispatchCodes[pData.dispatchCode] end
		if not pData.info then pData.info = dispatchData.info end
		if not pData.info2 then pData.info2 = dispatchData.info2 end
		if not pData.length then pData.length = dispatchData.length end
		pData.displayCode = dispatchData.displayCode
		pData.dispatchMessage = dispatchData.description
		pData.isImportant = dispatchData.isImportant
		pData.recipientList = dispatchData.recipientList
		pData.infoM = dispatchData.infoM
		pData.infoM2 = dispatchData.infoM2
		pData.sprite = dispatchData.blipSprite
		pData.colour = dispatchData.blipColour
		pData.scale = dispatchData.blipScale
		TriggerClientEvent('wf-alerts:clNotify', -1, pData)
		local n = [[]]
		local details = pData.dispatchMessage
		if pData.info then details = details .. n .. pData.info end
		if pData.info2 then details = details .. n .. pData.info2 end
		if pData.recipientList[1] == 'police' then TriggerEvent('mdt:newCall', details, pData.caller, vec3(pData.coords.x, pData.coords.y, pData.coords.z), false) end
	end
end)


RegisterServerEvent('wf-alerts:svNotify911')
AddEventHandler('wf-alerts:svNotify911', function(message, caller, coords)
	if message ~= nil then
		local pData = {}
		pData.displayCode = '911'
		if caller == _U('caller_unknown') then pData.dispatchMessage = _U('unknown_caller') else
		pData.dispatchMessage = _U('call_from') .. caller end
		pData.recipientList = {'police', 'ambulance'}
		pData.length = 13000
		pData.infoM = 'fa-phone'
		pData.info = message
		pData.coords = vec3(coords.x, coords.y, coords.z)
		pData.sprite, pData.colour, pData.scale =  480, 84, 2.0 -- radar_vip, blue
		TriggerClientEvent('wf-alerts:clNotify', -1, pData) -- Send to all clients then check auth clientside?
		TriggerEvent('mdt:newCall', message, caller, vec3(coords.x, coords.y, coords.z), false)
	end
end)
