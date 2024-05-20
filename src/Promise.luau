local Promise = {}
Promise.__index = Promise

-- Create a new promise.
-- @param executor (function(resolve: function, reject: function, reportProgress: function))
--     A function that receives three parameters:
--     - resolve: A function to call when the asynchronous operation succeeds.
--     - reject: A function to call when the asynchronous operation fails.
--     - reportProgress: A function to report progress during the asynchronous operation (optional).
--     The executor function represents the asynchronous operation to be performed.
-- @returns (table) A new promise object.
function Promise.new(executor)
	local self = setmetatable({}, Promise)
	self._resolved = false
	self._rejected = false
	self._value = nil
	self._reason = nil
	self._callbacks = {}
	self._errorHandlers = {}
	self._nextPromise = nil
	self._cancellation = nil
	self._cleanupFunctions = {}
	self._timeout = nil

	local function resolve(...)
		if not self._resolved and not self._rejected then
			self._resolved = true
			self._value = {...}
			self:_executeCallbacks(...)
		end
	end

	local function reject(...)
		if not self._resolved and not self._rejected then
			self._rejected = true
			self._reason = {...}
			self:_executeErrorHandlers(...)
		end
	end

	self._executor = function(...)
		executor(
			function(...)
				if self._cancellation and self._cancellation.cancelled then
					self:_executeCleanup()
					reject("Promise cancelled")
				else
					resolve(...)
				end
			end,
			function(...)
				self:_executeCleanup()
				reject(...)
			end,
			function(progress)
				self:_reportProgress(progress)
			end
		)
	end

	return self
end

-- Execute the promise chain.
function Promise:_executeCallbacks(...)
	if self._nextPromise then
		self._nextPromise._executor(...)
	end
	for _, callback in ipairs(self._callbacks) do
		callback(...)
	end
end

-- Execute error handlers in case of rejection.
function Promise:_executeErrorHandlers(...)
	for _, errorHandler in ipairs(self._errorHandlers) do
		errorHandler(...)
	end
end

-- Execute cleanup functions.
function Promise:_executeCleanup()
	for _, cleanupFunc in ipairs(self._cleanupFunctions) do
		cleanupFunc()
	end
end

-- Report progress of the promise.
function Promise:_reportProgress(progress)
	if self._progressHandler then
		self._progress = progress
		self._progressHandler(progress)
	end
end

-- Catch any errors or rejections in the promise chain.
-- @param errorHandler (function(...))
--     A function to handle any errors or rejections in the promise chain.
-- @returns (table) The promise object with the error handler added.
function Promise:catch(errorHandler)
	if self._rejected then
		errorHandler(unpack(self._reason))
	elseif not self._resolved then
		table.insert(self._errorHandlers, errorHandler)
	end
	return self
end

-- Add a callback function to the promise chain.
-- @param callback (function(...))
--     A function to be called when the promise is resolved.
-- @returns (table) The promise object with the callback added.
function Promise:then_(callback)
	if not self._resolved then
		table.insert(self._callbacks, callback)
	else
		self:_executeCallbacks(unpack(self._value))
	end
	return self
end

-- Cancel the promise, if possible.
-- @returns (nil)
function Promise:cancel()
	self._cancellation = { cancelled = true }
end

-- Specify a timeout for the promise.
-- @param duration (number) The duration of the timeout in seconds.
-- @returns (table) The promise object with timeout set.
function Promise:timeout(duration)
	self._timeout = duration
	return self
end

-- Check if an object is a promise.
-- @param obj (any) The object to check.
-- @returns (boolean) True if the object is a promise, false otherwise.
function Promise.isPromise(obj)
	return type(obj) == "table" and obj.__index == Promise
end

-- Retry the promise with a timeout.
-- @param executor (function(resolve: function, reject: function, reportProgress: function))
--     A function representing the asynchronous operation to be retried.
-- @param retries (number) The number of retries allowed.
-- @param timeout (number) The timeout duration in seconds (optional).
-- @returns (table) A new promise object with retry and timeout functionality.
function Promise.retryWithTimeout(executor, retries, timeout)
	return Promise.new(
		function(resolve, reject, reportProgress)
			local attempt = 1
			local function try()
				executor(resolve, reject, reportProgress)
				attempt = attempt + 1
			end

			local function retry()
				if attempt <= retries then
					try()
				else
					reject("Retry limit exceeded")
				end
			end

			local function timeoutHandler()
				reject("Promise timed out")
			end

			try()

			if timeout then
				spawn(
					function()
						wait(timeout)
						if not self._resolved and not self._rejected then
							timeoutHandler()
						end
					end
				)
			end
		end
	)
end

return Promise
