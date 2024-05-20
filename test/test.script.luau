local Promise = require(-directory)

local function asyncOperation(resolve, reject, reportProgress)
	print("Starting async operation...")
	local progress = 0
	local interval = 0.5
	local totalProgress = 5

	local timer = setInterval(interval, function()
		progress = progress + interval
		reportProgress(progress)

		if progress >= totalProgress then
			clearInterval(timer)
			resolve("Operation completed successfully")
		end
	end)
end

-- Test chaining promises with timeout
local function testChainingWithTimeout()
	print("Testing chaining promises with timeout...")
	local timeoutDuration = 3 -- 3 seconds timeout
	local chainedPromise = Promise.new(function(resolve, reject, reportProgress)
		Promise.retryWithTimeout(asyncOperation, 3, timeoutDuration)
			:then_(function(result)
				print("Chained promise resolved:", result)
				resolve("Chained promise completed successfully")
			end)
			:catch(function(error)
				print("Chained promise rejected:", error)
				reject("Chained promise failed")
			end)
			:timeout(timeoutDuration)
	end)

	chainedPromise
		:then_(function(result)
			print("Test completed:", result)
		end)
		:catch(function(error)
			print("Test failed:", error)
		end)
end

-- Test canceling a promise
local function testCancelingPromise()
	print("Testing canceling a promise...")
	local promise = Promise.new(function(resolve, reject, reportProgress)
		local timer = setTimeout(5, function()
			resolve("Operation completed successfully")
		end)

		-- Assume cancellation occurs after 2 seconds
		setTimeout(2, function()
			promise:cancel()
		end)
	end)

	promise
		:then_(function(result)
			print("Promise resolved:", result)
		end)
		:catch(function(error)
			print("Promise rejected:", error)
		end)
end

-- Run tests
testChainingWithTimeout()
testCancelingPromise()