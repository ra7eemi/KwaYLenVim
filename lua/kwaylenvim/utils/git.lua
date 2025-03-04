--- ### Git LUA API
--
-- This module can be loaded with `local git = require "kwaylenvim.utils.git"`
--
-- @module kwaylenvim.utils.git
-- @copyright 2022
-- @license GNU General Public License v3.0

local git = { url = "https://github.com/" }

local function trim_or_nil(str) return type(str) == "string" and vim.trim(str) or nil end

--- Run a git command from the kwaylenvim installation directory
---@param args string|string[] the git arguments
---@return string|nil # The result of the command or nil if unsuccessful
function git.cmd(args, ...)
  if type(args) == "string" then args = { args } end
  return require("kwaylenvim.utils").cmd(vim.list_extend({ "git", "-C", kwaylenvim.install.home }, args), ...)
end

--- Get the first worktree that a file belongs to
---@param file string? the file to check, defaults to the current file
---@param worktrees table<string, string>[]? an array like table of worktrees with entries `toplevel` and `gitdir`, default retrieves from `vim.g.git_worktrees`
---@return table<string, string>|nil # a table specifying the `toplevel` and `gitdir` of a worktree or nil if not found
function git.file_worktree(file, worktrees)
  worktrees = worktrees or vim.g.git_worktrees
  if not worktrees then return end
  file = file or vim.fn.expand "%"
  for _, worktree in ipairs(worktrees) do
    if
      require("kwaylenvim.utils").cmd({
        "git",
        "--work-tree",
        worktree.toplevel,
        "--git-dir",
        worktree.gitdir,
        "ls-files",
        "--error-unmatch",
        file,
      }, false)
    then
      return worktree
    end
  end
end

--- Check if the kwaylenvim is able to reach the `git` command
---@return boolean # The result of running `git --help`
function git.available() return vim.fn.executable "git" == 1 end

--- Check the git client version number
---@return table|nil # A table with version information or nil if there is an error
function git.git_version()
  local output = git.cmd({ "--version" }, false)
  if output then
    local version_str = output:match "%d+%.%d+%.%d"
    local major, min, patch = unpack(vim.tbl_map(tonumber, vim.split(version_str, "%.")))
    return { major = major, min = min, patch = patch, str = version_str }
  end
end

--- Check if the kwaylenvim home is a git repo
---@return string|nil # The result of the command
function git.is_repo() return git.cmd({ "rev-parse", "--is-inside-work-tree" }, false) end

--- Fetch git remote
---@param remote string the remote to fetch
---@return string|nil # The result of the command
function git.fetch(remote, ...) return git.cmd({ "fetch", remote }, ...) end

--- Pull the git repo
---@return string|nil # The result of the command
function git.pull(...) return git.cmd({ "pull", "--rebase" }, ...) end

--- Checkout git target
---@param dest string the target to checkout
---@return string|nil # The result of the command
function git.checkout(dest, ...) return git.cmd({ "checkout", dest }, ...) end

--- Hard reset to a git target
-- @param dest the target to hard reset to
---@return string|nil # The result of the command
function git.hard_reset(dest, ...) return git.cmd({ "reset", "--hard", dest }, ...) end

--- Check if a branch contains a commit
---@param remote string the git remote to check
---@param branch string the git branch to check
---@param commit string the git commit to check for
---@return boolean # The result of the command
function git.branch_contains(remote, branch, commit, ...)
  return git.cmd({ "merge-base", "--is-ancestor", commit, remote .. "/" .. branch }, ...) ~= nil
end

--- Get the remote name for a given branch
---@param branch string the git branch to check
---@return string|nil # The name of the remote for the given branch
function git.branch_remote(branch, ...) return trim_or_nil(git.cmd({ "config", "branch." .. branch .. ".remote" }, ...)) end

--- Add a git remote
---@param remote string the remote to add
---@param url string the url of the remote
---@return string|nil # The result of the command
function git.remote_add(remote, url, ...) return git.cmd({ "remote", "add", remote, url }, ...) end

--- Update a git remote URL
---@param remote string the remote to update
---@param url string the new URL of the remote
---@return string|nil # The result of the command
function git.remote_update(remote, url, ...) return git.cmd({ "remote", "set-url", remote, url }, ...) end

--- Get the URL of a given git remote
---@param remote string the remote to get the URL of
---@return string|nil # The url of the remote
function git.remote_url(remote, ...) return trim_or_nil(git.cmd({ "remote", "get-url", remote }, ...)) end

--- Get branches from a git remote
---@param remote string the remote to setup branches for
---@param branch string the branch to setup
---@return string|nil # The result of the command
function git.remote_set_branches(remote, branch, ...) return git.cmd({ "remote", "set-branches", remote, branch }, ...) end

--- Get the current version with git describe including tags
---@return string|nil # The current git describe string
function git.current_version(...) return trim_or_nil(git.cmd({ "describe", "--tags" }, ...)) end

--- Get the current branch
---@return string|nil # The branch of the kwaylenvim installation
function git.current_branch(...) return trim_or_nil(git.cmd({ "rev-parse", "--abbrev-ref", "HEAD" }, ...)) end

--- Verify a reference
---@return string|nil # The referenced commit
function git.ref_verify(ref, ...) return trim_or_nil(git.cmd({ "rev-parse", "--verify", ref }, ...)) end

--- Get the current head of the git repo
---@return string|nil # the head string
function git.local_head(...) return trim_or_nil(git.cmd({ "rev-parse", "HEAD" }, ...)) end

--- Get the current head of a git remote
---@param remote string the remote to check
---@param branch string the branch to check
---@return string|nil # The head string of the remote branch
function git.remote_head(remote, branch, ...)
  return trim_or_nil(git.cmd({ "rev-list", "-n", "1", remote .. "/" .. branch }, ...))
end

--- Get the commit hash of a given tag
---@param tag string the tag to resolve
---@return string|nil # The commit hash of a git tag
function git.tag_commit(tag, ...) return trim_or_nil(git.cmd({ "rev-list", "-n", "1", tag }, ...)) end

--- Get the commit log between two commit hashes
---@param start_hash? string the start commit hash
---@param end_hash? string the end commit hash
---@return string[] # An array like table of commit messages
function git.get_commit_range(start_hash, end_hash, ...)
  local range = start_hash and end_hash and start_hash .. ".." .. end_hash or nil
  local log = git.cmd({ "log", "--no-merges", '--pretty="format:[%h] %s"', range }, ...)
  return log and vim.fn.split(log, "\n") or {}
end

--- Get a list of all tags with a regex filter
---@param search? string a regex to search the tags with (defaults to "v*" for version tags)
---@return string[] # An array like table of tags that match the search
function git.get_versions(search, ...)
  local tags = git.cmd({ "tag", "-l", "--sort=version:refname", search == "latest" and "v*" or search }, ...)
  return tags and vim.fn.split(tags, "\n") or {}
end

--- Get the latest version of a list of versions
---@param versions? table a list of versions to search (defaults to all versions available)
---@return string|nil # The latest version from the array
function git.latest_version(versions, ...)
  if not versions then versions = git.get_versions(...) end
  return versions[#versions]
end

--- Parse a remote url
---@param str string the remote to parse to a full git url
---@return string # The full git url for the given remote string
function git.parse_remote_url(str)
  return vim.fn.match(str, require("kwaylenvim.utils").url_matcher) == -1
      and git.url .. str .. (vim.fn.match(str, "/") == -1 and "/kwaylenvim.git" or ".git")
    or str
end

--- Check if a Conventional Commit commit message is breaking or not
---@param commit string a commit message
---@return boolean true if the message is breaking, false if the commit message is not breaking
function git.is_breaking(commit) return vim.fn.match(commit, "\\[.*\\]\\s\\+\\w\\+\\((\\w\\+)\\)\\?!:") ~= -1 end

--- Get a list of breaking commits from commit messages using Conventional Commit standard
---@param commits string[] an array like table of commit messages
---@return string[] # An array like table of commits that are breaking
function git.breaking_changes(commits) return vim.tbl_filter(git.is_breaking, commits) end

--- Generate a table of commit messages for neovim's echo API with highlighting
---@param commits string[] an array like table of commit messages
---@return string[][] # An array like table of echo messages to provide to nvim_echo or kwaylenvim.echo
function git.pretty_changelog(commits)
  local changelog = {}
  for _, commit in ipairs(commits) do
    local hash, type, msg = commit:match "(%[.*%])(.*:)(.*)"
    if hash and type and msg then
      vim.list_extend(changelog, {
        { hash, "DiffText" },
        { type, git.is_breaking(commit) and "DiffDelete" or "DiffChange" },
        { msg },
        { "\n" },
      })
    end
  end
  return changelog
end

return git
