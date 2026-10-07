export type Subject = {
	UserId: number,
	Name: string,
	AccountAge: number?,
	MembershipType: { Name: string }?,
	Team: any?,
}

export type Geo = {
	city: string?,
	country_code: string?,
	region: string?,
}

export type User = {
	id: number?,
	username: string?,
	email: string?,
	data: { [string]: any }?,
	geo: Geo?,
}

local UserIdentity = {}

local function BuildGeo(LocaleId: string?): Geo
	local CountryCode = if LocaleId ~= nil then string.split(LocaleId, "-")[2] else nil

	if CountryCode ~= nil then CountryCode = string.upper(CountryCode) end

	return {
		city = "Unknown",
		country_code = CountryCode,
		region = CountryCode,
	}
end

function UserIdentity.FromSubject(Subject: Subject, LocaleId: string?, IncludeIdentity: boolean): User
	if not IncludeIdentity then return { id = Subject.UserId } end

	local Membership = Subject.MembershipType

	return {
		id = Subject.UserId,
		username = Subject.Name,
		data = {
			AccountAge = Subject.AccountAge,
			MembershipType = if Membership ~= nil then Membership.Name else nil,
			Team = (if Subject.Team ~= nil then tostring(Subject.Team) else nil),
		},
		geo = BuildGeo(LocaleId),
	}
end

return table.freeze(UserIdentity)
