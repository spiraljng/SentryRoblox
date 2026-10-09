local Changelog = {}

Changelog.Path = "CHANGELOG.md"

local function HeadingVersion(Line: string): string?
	return string.match(Line, "^##%s+%[?([%w%.%-_]+)%]?")
end

local function IsBlank(Line: string): boolean
	return string.match(Line, "^%s*$") ~= nil
end

function Changelog.Extract(Text: string, Version: string): (string?, string?)
	local Lines = string.split(Text, "\n")
	local Start: number? = nil

	for Index, Line in Lines do
		if HeadingVersion(Line) == Version then
			Start = Index + 1

			break
		end
	end

	if Start == nil then return nil, `${Changelog.Path} has no section for {Version}` end

	local Body: { string } = {}

	for Index = Start, #Lines do
		local Line = string.gsub(Lines[Index], "\r$", "")

		if HeadingVersion(Line) ~= nil then break end

		table.insert(Body, Line)
	end

	while #Body > 0 and IsBlank(Body[#Body]) do
		table.remove(Body)
	end

	while #Body > 0 and IsBlank(Body[1]) do
		table.remove(Body, 1)
	end

	if #Body == 0 then return nil, `${Changelog.Path} section for {Version} is empty` end

	return table.concat(Body, "\n"), nil
end

return table.freeze(Changelog)
