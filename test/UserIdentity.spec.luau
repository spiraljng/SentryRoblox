return function(t)
	local UserIdentity = require("../src/Hub/UserIdentity")

	local function Subject(Overrides: { [string]: any }?): any
		local Base = {
			UserId = 123,
			Name = "Alice",
			AccountAge = 42,
			MembershipType = { Name = "Premium" },
			Team = nil,
		}

		for Key, Value in next, Overrides or {} do
			Base[Key] = Value
		end

		return Base
	end

	t.describe("UserIdentity.FromSubject", function()
		t.test("keeps only the id when identity is off", function()
			local User = UserIdentity.FromSubject(Subject(), "en-US", false)

			t.expect(User.id).is(123)
			t.expect(User.username).is(nil)
			t.expect(User.data).is(nil)
			t.expect(User.geo).is(nil)
		end)

		t.test("builds the full user when identity is on", function()
			local Team = setmetatable({}, {
				__tostring = function()
					return "Red"
				end,
			})

			local User = UserIdentity.FromSubject(Subject({ Team = Team }), "en-US", true)

			t.expect(User.id).is(123)
			t.expect(User.username).is("Alice")
			t.expect(User.data.AccountAge).is(42)
			t.expect(User.data.MembershipType).is("Premium")
			t.expect(User.data.Team).is("Red")
			t.expect(User.geo.city).is("Unknown")
			t.expect(User.geo.country_code).is("US")
			t.expect(User.geo.region).is("US")
		end)

		t.test("handles a locale without a country code", function()
			local User = UserIdentity.FromSubject(Subject(), "en", true)

			t.expect(User.geo.country_code).is(nil)
			t.expect(User.geo.region).is(nil)
		end)

		t.test("handles a missing locale", function()
			local User = UserIdentity.FromSubject(Subject(), nil, true)

			t.expect(User.geo.country_code).is(nil)
		end)

		t.test("handles a missing membership type", function()
			local User = UserIdentity.FromSubject({
				UserId = 1,
				Name = "Bob",
				AccountAge = 1,
			}, "en-GB", true)

			t.expect(User.data.MembershipType).is(nil)
		end)

		t.test("handles a missing account age", function()
			local User = UserIdentity.FromSubject({
				UserId = 1,
				Name = "Bob",
				MembershipType = { Name = "None" },
			}, "en-GB", true)

			t.expect(User.data.AccountAge).is(nil)
		end)
	end)
end
