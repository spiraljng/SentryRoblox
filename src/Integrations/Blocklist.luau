local Noise = require(script.Parent.Detection.Noise)
local Types = require(script.Parent:WaitForChild("Types"))

export type Options = {
	URL: string?,
	RefreshInterval: number?,
	ExtraRules: { Noise.Rule }?,
}

local DefaultURL = "https://raw.githubusercontent.com/spiraljng/sentryroblox/main/noise/blocklist.json"
local DefaultRefreshInterval = 3600
local RetryInterval = 60
local MaximumBodyLength = 262144

local function Blocklist(Options: Options?): Types.Integration
	local Settings: Options = Options or {}

	local Extra: { Noise.Rule } = table.freeze({})

	if Settings.ExtraRules ~= nil then
		local Compiled = Noise.Compile({ rules = Settings.ExtraRules })

		if Compiled ~= nil then Extra = Compiled end
	end

	local State = {
		Generation = 0,
		Stopped = false,
	}

	local function Fetch(HttpService: any): ({ Noise.Rule }?, string?)
		local Success, Response = pcall(function()
			return HttpService:RequestAsync({
				Url = Settings.URL or DefaultURL,
				Method = "GET",
			})
		end)

		if not Success then return nil, "the request raised" end
		if type(Response) ~= "table" then return nil, "the response was malformed" end

		if Response.Success ~= true then
			return nil, `the request failed with status {tostring(Response.StatusCode)}`
		end

		local Body = Response.Body

		if type(Body) ~= "string" or Body == "" then return nil, "the response was empty" end

		if #Body > MaximumBodyLength then return nil, "the response was too large" end

		local DecodeSuccess, Decoded = pcall(function()
			return HttpService:JSONDecode(Body)
		end)

		if not DecodeSuccess then return nil, "the response was not valid JSON" end

		return Noise.Compile(Decoded)
	end

	return {
		Name = "Blocklist",
		Realm = "Server",
		Setup = function(Context: Types.Context)
			local HttpService = Context.Services.HttpService

			if HttpService == nil then return nil end

			local SdkOptions = Context.Options
			local Debug = SdkOptions ~= nil and SdkOptions.Debug == true
			local Interval = math.max(Settings.RefreshInterval or DefaultRefreshInterval, 1)

			State.Generation += 1
			State.Stopped = false

			local Mine = State.Generation

			local function Apply(Rules: { Noise.Rule }): ()
				Noise.Use(Noise.Merge(Rules, Extra))
			end

			if #Extra > 0 then Apply(Noise.Fallback) end

			task.spawn(function()
				local Backoff = RetryInterval

				while not State.Stopped and Mine == State.Generation do
					local Rules, Reason = Fetch(HttpService)

					if Rules ~= nil then
						Apply(Rules)

						if Debug then print(`[SentryRoblox] blocklist loaded {#Rules} rules`) end

						Backoff = RetryInterval

						task.wait(Interval)
					else
						if Debug then print(`[SentryRoblox] blocklist fetch failed: {Reason}`) end

						task.wait(Backoff)

						Backoff = math.min(Backoff * 2, Interval)
					end
				end
			end)

			return function()
				State.Stopped = true

				Noise.Reset()
			end
		end,
	}
end

return Blocklist
