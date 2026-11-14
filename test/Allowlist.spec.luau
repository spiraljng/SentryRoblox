return function(t)
	local Allowlist = require("../src/Integrations/Detection/Allowlist")

	t.describe("Allowlist.Compile", function()
		t.test("allows nothing when there are no entries", function()
			t.expect(#Allowlist.Compile(nil)).is(0)
			t.expect(#Allowlist.Compile({})).is(0)
		end)

		t.test("reads a bare string as a substring rule", function()
			local Rules = Allowlist.Compile({ "Item not found" })

			t.expect(#Rules).is(1)
			t.expect(Rules[1].Match).is("Item not found")
			t.expect(Rules[1].Type).is("substring")
		end)

		t.test("reads an explicit pattern rule", function()
			local Rules = Allowlist.Compile({ { Match = "^%[Quest%]", Type = "pattern" } })

			t.expect(#Rules).is(1)
			t.expect(Rules[1].Match).is("^%[Quest%]")
			t.expect(Rules[1].Type).is("pattern")
		end)

		t.test("ignores entries it cannot use", function()
			local Rules = Allowlist.Compile({
				"keep",
				42,
				{},
				{ Match = "" },
				{ Match = "no kind", Type = "regex" },
				{ Match = string.rep("x", Allowlist.MaximumMatchLength + 1) },
			})

			t.expect(#Rules).is(1)
			t.expect(Rules[1].Match).is("keep")
		end)

		t.test("stops at the rule cap", function()
			local Entries = {}

			for Index = 1, Allowlist.MaximumRules + 10 do
				table.insert(Entries, `entry {Index}`)
			end

			t.expect(#Allowlist.Compile(Entries)).is(Allowlist.MaximumRules)
		end)
	end)

	t.describe("Allowlist.Matches", function()
		t.test("allows nothing without rules", function()
			t.expect(Allowlist.Matches(nil, "anything")).is(false)
			t.expect(Allowlist.Matches({}, "anything")).is(false)
		end)

		t.test("matches a substring case sensitively", function()
			local Rules = Allowlist.Compile({ "Item not found" })

			t.expect(Allowlist.Matches(Rules, "Item not found")).is(true)
			t.expect(Allowlist.Matches(Rules, "warn: Item not found for Bob")).is(true)
			t.expect(Allowlist.Matches(Rules, "item not found")).is(false)
			t.expect(Allowlist.Matches(Rules, "Item not found!")).is(true)
		end)

		t.test("matches a pattern rule", function()
			local Rules = Allowlist.Compile({ { Match = "^%[Quest%]", Type = "pattern" } })

			t.expect(Allowlist.Matches(Rules, "[Quest] rerolled")).is(true)
			t.expect(Allowlist.Matches(Rules, "Quest rerolled")).is(false)
		end)

		t.test("treats a broken pattern as no match instead of raising", function()
			local Rules = Allowlist.Compile({ { Match = "([", Type = "pattern" } })

			t.expect(Allowlist.Matches(Rules, "anything")).is(false)
		end)

		t.test("never matches empty text", function()
			local Rules = Allowlist.Compile({ { Match = ".", Type = "pattern" } })

			t.expect(Allowlist.Matches(Rules, "")).is(false)
			t.expect(Allowlist.Matches(Rules, nil)).is(false)
			t.expect(Allowlist.Matches(Rules, "anything")).is(true)
		end)
	end)
end
