local HttpService = game:GetService("HttpService")

local Constants = require(script.Parent.Parent:WaitForChild("Constants"))
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Table = require(script.Parent.Parent:WaitForChild("Utility"):WaitForChild("Table"))
local Report = require(script.Parent.Parent:WaitForChild("Utility"):WaitForChild("Report"))
local DefaultTransport = require(script.Parent.Parent:WaitForChild("Transport"))

local Client = {}
local Metatable = { __index = Client }

local FailureReported = false

local function ReportFailure(Response: any): ()
	if Response == nil or Response.Success ~= false then
		FailureReported = false

		return
	end

	if FailureReported then return end

	FailureReported = true

	local Body = tostring(Response.Body or "")

	if #Body > 500 then Body = string.sub(Body, 1, 500) end

	print(`[SentryRoblox] capture failed: {Response.StatusCode} {Response.StatusMessage} {Body}`)
end

local EncodeFailureReported = false

local function ReportEncodeFailure(Error: any): ()
	if EncodeFailureReported then return end

	EncodeFailureReported = true

	print(`[SentryRoblox] dropping an event that could not be encoded: {tostring(Error)}`)
end

function Client.new(Transport: Types.Transport?): Types.Client
	return setmetatable({
		Transport = Transport,
	}, Metatable) :: any
end

function Client.CaptureEvent(
	_Self: Types.Client,
	Event: Types.Event,
	Hint: Types.Hint?,
	Scope: Types.Scope,
	Options: Types.Options?
): any
	local ResolvedHint: Types.Hint = Hint or {}

	if table.isfrozen(Event) then Event = table.clone(Event) end

	Event.event_id = (ResolvedHint.event_id or string.gsub(HttpService:GenerateGUID(false), "-", ""))
	Event.timestamp = DateTime.now().UnixTimestamp
	Event.platform = "other"

	local Processed = Scope:ApplyToEvent(Event, ResolvedHint)

	if Processed == nil then return end

	Processed.sdk = Constants.Interface

	local BeforeSend = if Options ~= nil then Options.BeforeSend else nil

	if BeforeSend ~= nil then
		local Success, Result = pcall(BeforeSend, Processed, ResolvedHint)

		if not Success then
			Report.Once("BeforeSend", `BeforeSend threw, dropping the event: {tostring(Result)}`)

			return
		end

		if Result == nil then return end

		Processed = Result
	end

	local EncodeSuccess, EncodedPayload = pcall(HttpService.JSONEncode, HttpService, Processed)

	if not EncodeSuccess then
		EncodeSuccess, EncodedPayload = pcall(HttpService.JSONEncode, HttpService, Table.Sanitize(Processed))
	end

	if not EncodeSuccess then
		ReportEncodeFailure(EncodedPayload)

		return
	end

	local Transport = if Options ~= nil and Options.Transport ~= nil then Options.Transport else DefaultTransport
	local Response = Transport:CaptureEvent(EncodedPayload, Processed.event_id)

	ReportFailure(Response)

	return Response
end

local function Delegate(Self: Types.Client, Name: string, Timeout: number?): boolean
	local Transport: any = Self.Transport

	if Transport == nil then return true end

	local Handler: any = Transport[Name]

	if Handler == nil then return true end

	local Success, Result = pcall(Handler, Transport, Timeout)

	return Success and Result == true
end

function Client.Close(Self: Types.Client, Timeout: number?): boolean
	return Delegate(Self, "Close", Timeout)
end

function Client.Flush(Self: Types.Client, Timeout: number?): boolean
	return Delegate(Self, "Flush", Timeout)
end

return Client
