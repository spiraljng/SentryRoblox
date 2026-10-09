return function(t)
	local fs = require("@lune/fs")

	local Changelog = require("../scripts/Shared/Changelog")
	local Manifest = require("../scripts/Shared/Manifest")

	local Sample = table.concat({
		"# Changelog",
		"",
		"## 2.1.0 - 2026-01-01",
		"",
		"### Added",
		"",
		"- one thing",
		"",
		"## 2.0.0 - 2025-12-01",
		"",
		"### Fixed",
		"",
		"- another thing",
		"",
	}, "\n")

	t.describe("Changelog.Extract", function()
		t.test("returns only the requested section", function()
			local Body = Changelog.Extract(Sample, "2.1.0")

			t.expect(Body).never_is(nil)
			t.expect(string.find(Body :: string, "one thing", 1, true)).never_is(nil)
			t.expect(string.find(Body :: string, "another thing", 1, true)).is(nil)
			t.expect(string.find(Body :: string, "### Added", 1, true)).never_is(nil)
		end)

		t.test("accepts bracketed headings", function()
			local Bracketed = Sample:gsub("## 2%.1%.0", "## [2.1.0]")

			t.expect(Changelog.Extract(Bracketed, "2.1.0")).never_is(nil)
		end)

		t.test("reports a version that has no section", function()
			local Body, Reason = Changelog.Extract(Sample, "9.9.9")

			t.expect(Body).is(nil)
			t.expect(Reason).never_is(nil)
		end)

		t.test("does not confuse a partial version with a full one", function()
			t.expect(Changelog.Extract(Sample, "2.1")).is(nil)
		end)

		t.test("trims surrounding blank lines but keeps inner ones", function()
			local Body = Changelog.Extract(Sample, "2.0.0")

			t.expect(Body).never_is(nil)
			t.expect(string.sub(Body :: string, 1, 4)).is("### ")
			t.expect(string.find(Body :: string, "\n\n", 1, true)).never_is(nil)
		end)
	end)

	t.describe("CHANGELOG.md", function()
		t.test("has notes for the version in pesde.toml", function()
			local Body = Changelog.Extract(fs.readFile(Changelog.Path), Manifest.Read().version)

			t.expect(Body).never_is(nil)
			t.expect(#(Body :: string) > 0).is_true()
		end)
	end)
end
