local Report = {}

local Reported: { [string]: boolean } = {}

function Report.Once(Key: string, Message: string): ()
	if Reported[Key] then return end

	Reported[Key] = true

	print(`[SentryRoblox] {Message}`)
end

return table.freeze(Report)
