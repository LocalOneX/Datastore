--!strict

local Datastore = require("../Datastore")
local datastore = Datastore.new("TestDS", "global")

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player: Player)
	local lastGUID = datastore:GetAsync(tostring(player.UserId)) 
	print(string.format("Last GUID '%s'", tostring(lastGUID))) 
	
	datastore:UpdateAsync(tostring(player.UserId), function(oldGUID)
		print(string.format("OLD GUID '%s'", tostring(oldGUID))) 
		return HttpService:GenerateGUID(false)
	end):await()
	
	print("Successfully set new player GUID::")
	print(datastore:GetAsync(tostring(player.UserId)))
end)
