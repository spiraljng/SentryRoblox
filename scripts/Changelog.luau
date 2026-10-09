local fs = require("@lune/fs")
local Process = require("@lune/process")

local Changelog = require("./Shared/Changelog")
local Manifest = require("./Shared/Manifest")

local function FirstArgument(): string?
	for _, Argument in Process.args do
		if Argument ~= "--" then return Argument end
	end

	return nil
end

local Requested = FirstArgument()
local Version = string.gsub(Requested or Manifest.Read().version, "^v", "")

local Body, Reason = Changelog.Extract(fs.readFile(Changelog.Path), Version)

if Body == nil then
	print(`changelog: {Reason}`)

	Process.exit(1)
end

print(Body)
