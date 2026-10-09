return function(t)
	local fs = require("@lune/fs")
	local Serde = require("@lune/serde")

	local Noise = require("../src/Integrations/Detection/Noise")

	t.describe("Noise.Compile", function()
		t.test("rejects payloads that are not rule tables", function()
			local Rules, Reason = Noise.Compile(nil)

			t.expect(Rules).is(nil)
			t.expect(Reason).never_is(nil)

			Rules, Reason = Noise.Compile({})

			t.expect(Rules).is(nil)
			t.expect(Reason).never_is(nil)

			Rules, Reason = Noise.Compile({ rules = {} })

			t.expect(Rules).is(nil)
			t.expect(Reason).never_is(nil)
		end)

		t.test("ignores unusable entries and keeps the rest", function()
			local Rules = Noise.Compile({
				rules = {
					{ id = "keep", match = "keep this" },
					"not a rule",
					{ id = "", match = "no id" },
					{ id = "no-match" },
					{ id = "bad-kind", match = "bad kind", type = "regex" },
					{ id = "too-long", match = string.rep("x", Noise.MaximumMatchLength + 1) },
					{ id = "pattern", match = "Timed[Oo]ut", type = "pattern" },
				},
			})

			t.expect(Rules).never_is(nil)
			t.expect(#(Rules :: any)).is(2)
		end)

		t.test("rejects payloads above the rule cap", function()
			local Raw = {}

			for Index = 1, Noise.MaximumRules + 1 do
				table.insert(Raw, { id = `rule-{Index}`, match = `match-{Index}` })
			end

			local Rules, Reason = Noise.Compile({ rules = Raw })

			t.expect(Rules).is(nil)
			t.expect(Reason).never_is(nil)
		end)

		t.test("defaults the type to substring", function()
			local Rules = Noise.Compile({ rules = { { id = "plain", match = "plain text" } } })

			t.expect(Rules).never_is(nil)
			t.expect((Rules :: any)[1].Id).is("plain")
			t.expect((Rules :: any)[1].Type).is("substring")
		end)
	end)

	t.describe("Noise.Match", function()
		t.test("matches plain substrings", function()
			local Rules = Noise.Compile({ rules = { { id = "dns", match = "HttpError: DnsResolve" } } })

			t.expect(Noise.Match("boom HttpError: DnsResolve end", Rules)).never_is(nil)
			t.expect(Noise.Match("HttpError: ConnectFail", Rules)).is(nil)
			t.expect(Noise.Match(nil, Rules)).is(nil)
			t.expect(Noise.Match("", Rules)).is(nil)
		end)

		t.test("treats pattern characters literally for substring rules", function()
			local Rules = Noise.Compile({ rules = { { id = "literal", match = "100%s done" } } })

			t.expect(Noise.Match("progress 100%s done", Rules)).never_is(nil)
			t.expect(Noise.Match("progress 100s done", Rules)).is(nil)
		end)

		t.test("supports Lua patterns", function()
			local Rules = Noise.Compile({
				rules = { { id = "timeout", match = "HttpError: Timed[Oo]ut", type = "pattern" } },
			})

			t.expect(Noise.Match("HttpError: Timedout", Rules)).never_is(nil)
			t.expect(Noise.Match("HttpError: TimedOut", Rules)).never_is(nil)
			t.expect(Noise.Match("HttpError: TimedIn", Rules)).is(nil)
		end)

		t.test("ignores a malformed pattern", function()
			local Rules = Noise.Compile({ rules = { { id = "broken", match = "[", type = "pattern" } } })

			t.expect(Rules).never_is(nil)
			t.expect(Noise.Match("[ anything", Rules)).is(nil)
		end)
	end)

	t.describe("Noise.IsBlocked", function()
		t.test("uses the fallback until the list is replaced", function()
			Noise.Reset()

			t.expect(Noise.IsBlocked("HttpError: DnsResolve")).never_is(nil)
			t.expect(Noise.IsBlocked("something ordinary")).is(nil)
		end)

		t.test("replaces the list and resets it", function()
			Noise.Use(Noise.Compile({ rules = { { id = "custom", match = "custom noise" } } }))

			t.expect(Noise.IsBlocked("custom noise")).never_is(nil)
			t.expect(Noise.IsBlocked("HttpError: DnsResolve")).is(nil)

			Noise.Reset()

			t.expect(Noise.IsBlocked("HttpError: DnsResolve")).never_is(nil)
		end)
	end)

	t.describe("Noise.OnChange", function()
		t.test("notifies listeners until they unsubscribe", function()
			Noise.Reset()

			local Seen = 0
			local Unsubscribe = Noise.OnChange(function()
				Seen += 1
			end)

			Noise.Use(Noise.Fallback)

			t.expect(Seen).is(1)

			Unsubscribe()

			Noise.Use(Noise.Fallback)

			t.expect(Seen).is(1)

			Noise.Reset()
		end)
	end)

	t.describe("Noise.Fallback", function()
		t.test("mirrors every rule in noise/blocklist.json", function()
			local Decoded = Serde.decode("json", fs.readFile("noise/blocklist.json"))
			local Rules = Noise.Compile(Decoded)

			t.expect(Rules).never_is(nil)

			local Index: { [string]: any } = {}

			for _, Rule in Rules :: any do
				Index[Rule.Id] = Rule
			end

			for _, Rule in Noise.Fallback do
				local Mirrored = Index[Rule.Id]

				t.expect(Mirrored).never_is(nil)

				if Mirrored ~= nil then
					t.expect(Mirrored.Match).is(Rule.Match)
					t.expect(Mirrored.Type).is(Rule.Type)
				end
			end
		end)
	end)
end
