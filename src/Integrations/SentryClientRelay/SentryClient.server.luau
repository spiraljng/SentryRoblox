local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")
local LogService = game:GetService("LogService")

local Noise = require(script.Parent.Parent.Detection.Noise)
local Policy = require(script.Parent.Parent.Detection.Policy)

if not RunService:IsClient() then return end

local Relay = script.Parent:WaitForChild("RemoteEvent", 30)

if Relay == nil then return end

(Relay :: RemoteEvent).OnClientEvent:Connect(function(Payload: any)
	if type(Payload) ~= "table" or Payload.kind ~= "blocklist" then return end

	local Rules = Noise.Compile(Payload)

	if Rules ~= nil then Noise.Use(Rules) end
end)

pcall(function()
	(Relay :: RemoteEvent):FireServer({ kind = "blocklist" })
end)

local LocationPrefix = "^[^:]+:%d+: (.+)$"
local SelfPattern = "SentryRoblox"

local function Forward(Event: any, TracebackText: string?): ()
	pcall(function()
		(Relay :: RemoteEvent):FireServer({
			event = Event,
			traceback = TracebackText,
		})
	end)
end

ScriptContext.Error:Connect(function(Message: string, TracebackText: string, Origin: any)
	local Keep = Policy.Decide(Origin, TracebackText, game)

	if not Keep then return end

	if Noise.IsBlocked(Message) ~= nil or Noise.IsBlocked(TracebackText) ~= nil then return end

	Forward({
		level = "error",
		exception = {
			{
				type = "Error",
				value = string.match(Message, LocationPrefix) or Message,
				mechanism = {
					type = "generic",
					handled = false,
				},
			},
		},
	}, TracebackText)
end)

LogService.MessageOut:Connect(function(Message: string, MessageType: Enum.MessageType)
	if MessageType ~= Enum.MessageType.MessageWarning then return end

	if string.find(Message, SelfPattern, 1, true) ~= nil then return end

	if Policy.IsInternalText(Message) then return end

	if Noise.IsBlocked(Message) ~= nil then return end

	Forward({
		message = {
			message = Message,
			formatted = Message,
		},
		level = "warning",
	})
end)
