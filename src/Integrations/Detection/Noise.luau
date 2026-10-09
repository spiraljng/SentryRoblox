export type Rule = {
	Id: string,
	Match: string,
	Type: string,
}

local Noise = {}

Noise.Schema = 1

Noise.MaximumRules = 256
Noise.MaximumMatchLength = 200

local Fallback: { Rule } = {
	{ Id = "http-dns-resolve", Match = "HttpError: DnsResolve", Type = "substring" },
	{ Id = "http-connect-fail", Match = "HttpError: ConnectFail", Type = "substring" },
	{ Id = "http-timeout", Match = "HttpError: Timed[Oo]ut", Type = "pattern" },
	{ Id = "http-net-fail", Match = "HttpError: NetFail", Type = "substring" },
	{ Id = "http-aborted", Match = "HttpError: Aborted", Type = "substring" },
	{ Id = "http-connection-closed", Match = "HttpError: ConnectionClosed", Type = "substring" },
	{ Id = "http-inactivity-timeout", Match = "HttpError: InactivityTimeout", Type = "substring" },
	{ Id = "http-ssl-connect-fail", Match = "HttpError: SslConnectFail", Type = "substring" },
	{ Id = "http-ssl-verification-fail", Match = "HttpError: SslVerificationFail", Type = "substring" },
	{ Id = "http-server-protocol-error", Match = "HttpError: ServerProtocolError", Type = "substring" },
	{ Id = "player-not-in-datamodel", Match = "Player not in datamodel", Type = "substring" },
	{ Id = "player-being-removed", Match = "Character cannot be changed as Player", Type = "substring" },
	{ Id = "datastore-request-queued", Match = "DataStore request was added to queue", Type = "substring" },
	{ Id = "stylelink-multiple", Match = "Multiple StyleLinks under RobloxGui", Type = "substring" },
	{
		Id = "guiservice-selected-object",
		Match = "Setting GuiService.SelectedObject to invalid GuiObject",
		Type = "substring",
	},
}

Noise.Fallback = table.freeze(Fallback)

local Active: { Rule } = Noise.Fallback
local Listeners: { (Rules: { Rule }) -> () } = {}

function Noise.Compile(Payload: any): ({ Rule }?, string?)
	if type(Payload) ~= "table" then return nil, "the payload is not a table" end

	local Raw = Payload.rules

	if type(Raw) ~= "table" then return nil, "the payload has no rules" end

	local Count = #Raw

	if Count == 0 then return nil, "the payload has no rules" end

	if Count > Noise.MaximumRules then
		return nil, `the payload has {Count} rules, more than the {Noise.MaximumRules} allowed`
	end

	local Rules: { Rule } = {}

	for _, Entry in Raw do
		if type(Entry) ~= "table" then continue end

		local Id = Entry.id
		local Match = Entry.match
		local Kind: string = Entry.type or "substring"

		if type(Id) ~= "string" or Id == "" then continue end
		if type(Match) ~= "string" or Match == "" or #Match > Noise.MaximumMatchLength then continue end
		if Kind ~= "substring" and Kind ~= "pattern" then continue end

		local Compiled: Rule = {
			Id = Id,
			Match = Match,
			Type = Kind,
		}

		table.insert(Rules, table.freeze(Compiled))
	end

	if #Rules == 0 then return nil, "the payload has no usable rules" end

	return table.freeze(Rules), nil
end

function Noise.Match(Text: string?, Rules: { Rule }): Rule?
	if Text == nil or Text == "" then return nil end

	for _, Rule in Rules do
		if Rule.Type == "pattern" then
			local Success, Found = pcall(string.find, Text, Rule.Match)

			if Success and Found ~= nil then return Rule end
		elseif string.find(Text, Rule.Match, 1, true) ~= nil then
			return Rule
		end
	end

	return nil
end

function Noise.Merge(Rules: { Rule }?, Extra: { Rule }?): { Rule }
	local Merged: { Rule } = {}
	local Seen: { [string]: boolean } = {}

	local function Append(Source: { Rule }?)
		if Source == nil then return end

		for _, Rule in Source do
			if Seen[Rule.Id] ~= nil then continue end

			Seen[Rule.Id] = true

			table.insert(Merged, Rule)
		end
	end

	Append(Rules)
	Append(Extra)

	return table.freeze(Merged)
end

function Noise.Rules(): { Rule }
	return Active
end

function Noise.IsBlocked(Text: string?): Rule?
	return Noise.Match(Text, Active)
end

function Noise.Use(Rules: { Rule }?): ()
	Active = Rules or Noise.Fallback

	for _, Listener in Listeners do
		pcall(Listener, Active)
	end
end

function Noise.Reset(): ()
	Noise.Use(nil)
end

function Noise.OnChange(Listener: (Rules: { Rule }) -> ()): () -> ()
	table.insert(Listeners, Listener)

	return function()
		local Index = table.find(Listeners, Listener)

		if Index ~= nil then table.remove(Listeners, Index) end
	end
end

return table.freeze(Noise)
