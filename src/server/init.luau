--[=[
	Vanilla datastores don't really offer much versatility, nor secure checks. 
	Mainly optimized for regular Datastores, :GetDatastore. Compatability or different
	versions for OrderedDatastores will come eventually.
	@objective fix this issue with datastores, making them as versatile as possible! 
	@author localonex
	@date 2025-05-13
	@version beta 1.0.0
]=]-- 
local module = {}

-- | Packages
local Promise = require(game.ReplicatedStorage.Packages.Promise)
local MockSignal = require(game.ReplicatedStorage.Packages.MockSignal)

-- | Types
type raw_schema = {
	_name: string,
	_scope: string?,
	_options: Instance?,
	_datastore: DataStore,
}

type proto_schema = {
	new: (self: schema, name: string, scope: string?, options: Instance?) -> schema?,
	GetAsync: (self: schema, key: string, options: DataStoreGetOptions?) -> (...any),
	SetAsync: (self: schema, key: string, value: any, userIds: {any}?, options: DataStoreSetOptions?) -> (...any),
	UpdateAsync: (self: schema, key: string, transformFunction: (...T) -> (...R)) -> (...any), 
}

export type schema = typeof(setmetatable({}::raw_schema, {__index = {}::proto_schema}))

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

--- warning for disabled studio api access.
if not pcall(function() HttpService:GetAsync("https://www.google.com/") end) then
	warn("StudioAccessToApisNotAllowed May not be ENABLED! Please enable it to use Datastore!")
end

--- promise calls are very secure, and will track errors.
local function promisecall<R, T>(callback: (...T?) -> (...R), ...) 
	--- solution to thread errors
	local args = {...}
	
	return assert(Promise.new(function(resolve, reject)
		local success, response = pcall(callback, unpack(args))
		if not success then
			reject(response)
		else
			resolve(response)
		end
	end))
end

--- yield important datastore functions, attempt multiple times.
local function ycall<R, T>(callback: (...T?) -> (...R), yield: number?)
	local yield: number = yield or 1
	local attempts = 0 
	
	while attempts < 5 do
		local success, response = pcall(callback)
		if success then
			return response
		end
		
		attempts += 1
		task.wait(yield)
	end 
	
	error(debug.traceback("[ycall]\n", 2))
end

local function utf_8_check()
	
end

--[=[
	This function creates a DataStore instance with the provided name and scope. 
	Subsequent calls to this method with the same name/scope will return the same object.
	
	```lua
		local datastore = Datastore.new("myDatastore", "global", Instance.new("DatastoreOptions"))
	```
	
	@return Datastore
]=]--
function module.new(name: string, scope: string?, options: Instance?): schema
	--- 
	return select(2, promisecall(function()
		return DataStoreService:GetDataStore(name, scope, options)
	end):andThen(function(datastore)  
		assert(typeof(datastore) == "Instance" and datastore:IsA("DataStore"), debug.traceback(nil, 2))
		
		local rawData: raw_schema = {
			_name = name,
			_scope = scope,
			_options = options, 
			_datastore = datastore
		} 

		local self: schema = setmetatable(rawData, {__index = module})

		return self
	end):await())
end  
 
--[=[
	Sets the value of the data store for the given key.
	
	```lua
		local returnedData = Datastore:GetAsync("example"):await() 
	```
	
	@yields
	@return promise
]=]--
function module:GetAsync(key: string, options: DataStoreGetOptions?) 
	return select(2, promisecall(ycall, function() 
		return self._datastore:GetAsync(key, options)
	end):await())
end

--[=[
	Retrieves the specified key version. 
	
	```lua
		local returnedData = Datastore:GetVersionAsync("example", "v1") 
	```
	
	@yields
	@return promise
]=]--
function module:GetVersionAsync(key: string, version: string) 
	return select(2, promisecall(ycall, function() 
		return self._datastore:GetVersionAsync(key, version)
	end):await())
end

--[=[
	Retrieves the key version that was current at a given time.
	
	```lua
		local versions = Datastore:GetVersionAsync("example", 1747281688) 
	```
	
	@yields
	@return promise
]=]--
function module:GetVersionAtTimeAsync(key: string, timestamp: number) 
	return select(2, promisecall(ycall, function() 
		return self._datastore:GetVersionAtTimeAsync(key, timestamp)
	end):await())
end

--[=[
	Returns a DataStoreKeyPages object for enumerating through keys of a data store.   
	@yields
	@return promise
]=]--
function module:ListKeysAsync(prefix: string, pageSize: number, cursor: string, excludeDeleted: boolean) 
	return select(2, promisecall(ycall, function() 
		return self._datastore:ListKeysAsync(prefix, pageSize, cursor, excludeDeleted)
	end):await())
end

--[=[
	Returns a DataStoreKeyPages object for enumerating through keys of a data store.   
	@yields
	@return promise
]=]--
function module:RemoveVersionAsync(key: string, version: string)
	return select(2, promisecall(ycall, function() 
		return self._datastore:RemoveVersionAsync(key, version)
	end):await())
end
 
--[=[
	Sets the value of the data store for the given key.
	
	```lua
		Datastore:SetAsync("example", true)
	```
	
	@yields
	@return any
]=]--
function module:SetAsync(key: string, value: any, userIds: {any}?, options: DataStoreSetOptions?) 
	return promisecall(ycall, function()
		return self._datastore:SetAsync(key, value, userIds, options)
	end)
end

--[=[
	Increments the value of a key by the provided amount (both must be integers).
	
	```lua
		Datastore:IncrementAsync("example"):await()
	```
	
	@yields
	@return any
]=]--
function module:IncrementAsync(key: string, delta: number?, userIds: {any}?, options: DataStoreIncrementOptions?) 
	return promisecall(ycall, function()
		return self._datastore:IncrementAsync(key, delta, userIds, options)
	end)
end

--[=[
	Removes the specified key while also retaining an accessible version.
	
	```lua
		Datastore:RemoveAsync("example"):await()
	```
	
	@yields
	@return any
]=]--
function module:RemoveAsync(key: string) 
	return promisecall(ycall, function()
		return self._datastore:RemoveAsync(key)
	end)
end


--[=[
    Updates a key's value with a new value from the specified callback function. 

	```lua
		Datastore:UpdateAsync("example", function(old)
			if old == true then
				old = false
			else
				old = true
			end
			
			return old
		end)
	```
	
	@yields
	@return any
]=]-- 
function module:UpdateAsync<R, T>(key: string, transformFunction: (...T) -> (...R)) 
	return promisecall(ycall, function()
		return self._datastore:UpdateAsync(key, transformFunction)
	end)
end 

function module:OnUpdate()
	error("Unimplemented")
end

---TODO: Global Implemenation using MessagingService

return module
