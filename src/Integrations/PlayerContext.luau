local PlayerRegistry = require(script.Parent.Detection.PlayerRegistry)
local Scrubber = require(script.Parent.Detection.Scrubber)
local Table = require(script.Parent.Parent:WaitForChild("Utility"):WaitForChild("Table"))
local Types = require(script.Parent:WaitForChild("Types"))
local UserIdentity = require(script.Parent.Parent:WaitForChild("Hub"):WaitForChild("UserIdentity"))

export type Options = {
	Scrub: boolean?,
	Placeholder: string?,
	RetentionSeconds: number?,
	SendDefaultPII: boolean?,
	ExtraNames: { string }?,
}

local MinimumIdLength = 6

local function PlayerContext(Options: Options?): Types.Integration
	local Settings: Options = Options or {}
	local Scrub = Settings.Scrub ~= false
	local Placeholder = Settings.Placeholder or Scrubber.DefaultPlaceholder
	local Retention = Settings.RetentionSeconds or PlayerRegistry.DefaultRetention

	local function Collect(
		Registry: PlayerRegistry.Registry,
		ExtraNames: { string }?
	): ({ string }, { [string]: string })
		local Tokens = {}
		local NamesByToken = {}

		for _, Entry in PlayerRegistry.Entries(Registry) do
			if NamesByToken[Entry.Name] == nil then
				table.insert(Tokens, Entry.Name)
				NamesByToken[Entry.Name] = Entry.Name
			end

			local Id = tostring(Entry.UserId)

			if #Id >= MinimumIdLength and NamesByToken[Id] == nil then
				table.insert(Tokens, Id)
				NamesByToken[Id] = Entry.Name
			end
		end

		if ExtraNames ~= nil then
			for _, Name in ExtraNames do
				if NamesByToken[Name] == nil then
					table.insert(Tokens, Name)
					NamesByToken[Name] = Name
				end
			end
		end

		return Tokens, NamesByToken
	end

	local function ApplyUser(
		Event: Types.Event,
		Players: Players,
		Registry: PlayerRegistry.Registry,
		Implicated: { string },
		SendPII: boolean
	): ()
		if #Implicated ~= 1 then return end

		local Entry = PlayerRegistry.Find(Registry, Implicated[1])

		if Entry == nil then return end

		local Subject = Players:GetPlayerByUserId(Entry.UserId)
		local Built: Types.User

		if Subject ~= nil then
			Built = UserIdentity.FromSubject(Subject :: any, Subject.LocaleId, SendPII)
		elseif SendPII then
			Built = { id = Entry.UserId, username = Entry.Name }
		else
			Built = { id = Entry.UserId }
		end

		local Existing = Event.user

		if Existing == nil then
			Event.user = Built
		else
			Event.user = Table.Merge(Existing, Built) :: any
		end
	end

	return {
		Name = "PlayerContext",
		Realm = "Shared",
		Setup = function(Context: Types.Context)
			local Players = Context.Services.Players
			local Clock = Context.Services.Clock or os.clock
			local Registry = PlayerRegistry.new()
			local ExtraNames = Settings.ExtraNames
			local Connections = {}

			local SendPII: boolean

			if Settings.SendDefaultPII ~= nil then
				SendPII = Settings.SendDefaultPII
			else
				local SdkOptions = Context.Options
				SendPII = SdkOptions ~= nil and SdkOptions.SendDefaultPII == true
			end

			for _, Player in Players:GetPlayers() do
				PlayerRegistry.Add(Registry, Player.Name, Player.UserId)
			end

			table.insert(
				Connections,
				Players.PlayerAdded:Connect(function(Player)
					PlayerRegistry.Add(Registry, Player.Name, Player.UserId)
				end)
			)

			table.insert(
				Connections,
				Players.PlayerRemoving:Connect(function(Player)
					PlayerRegistry.Remove(Registry, Player.Name, Clock(), Retention)
				end)
			)

			Context.AddProcessor(function(Event: Types.Event, _Hint: Types.Hint?): Types.Event
				PlayerRegistry.Sweep(Registry, Clock())

				local Tokens, NamesByToken = Collect(Registry, ExtraNames)

				if #Tokens == 0 then return Event end

				local ImplicatedTokens: { string }

				if Scrub then
					local _, Found = Scrubber.Apply(Event, Tokens, Placeholder)

					ImplicatedTokens = Found
				else
					ImplicatedTokens = Scrubber.Find(Event, Tokens)
				end

				local Implicated = {}

				for _, Token in ImplicatedTokens do
					local Name = NamesByToken[Token]

					if Name ~= nil and not table.find(Implicated, Name) then table.insert(Implicated, Name) end
				end

				ApplyUser(Event, Players, Registry, Implicated, SendPII)

				return Event
			end)

			return function()
				for _, Connection in Connections do
					Connection:Disconnect()
				end
			end
		end,
	}
end

return PlayerContext
