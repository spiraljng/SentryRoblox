export type Rule = {
	Match: string,
	Type: string,
}

export type Entry = string | { Match: string, Type: string? }

local Allowlist = {}

Allowlist.MaximumRules = 256
Allowlist.MaximumMatchLength = 200

local function CompileEntry(Entry: any): Rule?
	if type(Entry) == "string" then
		if Entry == "" or #Entry > Allowlist.MaximumMatchLength then return nil end

		local Substring: Rule = { Match = Entry, Type = "substring" }

		return Substring
	end

	if type(Entry) ~= "table" then return nil end

	local Match = Entry.Match
	local Kind: string = Entry.Type or "substring"

	if type(Match) ~= "string" or Match == "" or #Match > Allowlist.MaximumMatchLength then return nil end

	if Kind ~= "substring" and Kind ~= "pattern" then return nil end

	local Compiled: Rule = { Match = Match, Type = Kind }

	return Compiled
end

function Allowlist.Compile(Entries: { Entry }?): { Rule }
	local Rules: { Rule } = {}

	if Entries == nil then return table.freeze(Rules) end

	for _, Entry in Entries do
		if #Rules >= Allowlist.MaximumRules then break end

		local Rule = CompileEntry(Entry)

		if Rule ~= nil then table.insert(Rules, table.freeze(Rule)) end
	end

	return table.freeze(Rules)
end

function Allowlist.Matches(Rules: { Rule }?, Text: string?): boolean
	if Rules == nil or Text == nil or Text == "" then return false end

	for _, Rule in Rules do
		if Rule.Type == "pattern" then
			local Success, Found = pcall(string.find, Text, Rule.Match)

			if Success and Found ~= nil then return true end
		elseif string.find(Text, Rule.Match, 1, true) ~= nil then
			return true
		end
	end

	return false
end

return table.freeze(Allowlist)
