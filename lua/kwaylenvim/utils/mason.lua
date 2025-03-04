--- ### Mason Utils
--
-- Mason related utility functions to use within kwaylenvim and user configurations.
--
-- This module can be loaded with `local mason_utils = require("kwaylenvim.utils.mason")`
--
-- @module kwaylenvim.utils.mason
-- @see kwaylenvim.utils
-- @copyright 2022
-- @license GNU General Public License v3.0

local M = {}

local utils = require "kwaylenvim.utils"
local astroevent = utils.event
local function mason_notify(msg, type) utils.notify(msg, type, { title = "Mason" }) end

--- Update specified mason packages, or just update the registries if no packages are listed
---@param pkg_names? string|string[] The package names as defined in Mason (Not mason-lspconfig or mason-null-ls) if the value is nil then it will just update the registries
---@param auto_install? boolean whether or not to install a package that is not currently installed (default: True)
function M.update(pkg_names, auto_install)
  pkg_names = pkg_names or {}
  if type(pkg_names) == "string" then pkg_names = { pkg_names } end
  if auto_install == nil then auto_install = true end
  local registry_avail, registry = pcall(require, "mason-registry")
  if not registry_avail then
    vim.api.nvim_err_writeln "Unable to access mason registry"
    return
  end

  registry.update(vim.schedule_wrap(function(success, updated_registries)
    if success then
      local count = #updated_registries
      if vim.tbl_count(pkg_names) == 0 then
        mason_notify(("Successfully updated %d %s."):format(count, count == 1 and "registry" or "registries"))
      end
      for _, pkg_name in ipairs(pkg_names) do
        local pkg_avail, pkg = pcall(registry.get_package, pkg_name)
        if not pkg_avail then
          mason_notify(("`%s` is not available"):format(pkg_name), vim.log.levels.ERROR)
        else
          if not pkg:is_installed() then
            if auto_install then
              mason_notify(("Installing `%s`"):format(pkg.name))
              pkg:install()
            else
              mason_notify(("`%s` not installed"):format(pkg.name), vim.log.levels.WARN)
            end
          else
            pkg:check_new_version(function(update_available, version)
              if update_available then
                mason_notify(("Updating `%s` to %s"):format(pkg.name, version.latest_version))
                pkg:install():on("closed", function() mason_notify(("Updated %s"):format(pkg.name)) end)
              else
                mason_notify(("No updates available for `%s`"):format(pkg.name))
              end
            end)
          end
        end
      end
    else
      mason_notify(("Failed to update registries: %s"):format(updated_registries), vim.log.levels.ERROR)
    end
  end))
end

--- Update all packages in Mason
function M.update_all()
  local registry_avail, registry = pcall(require, "mason-registry")
  if not registry_avail then
    vim.api.nvim_err_writeln "Unable to access mason registry"
    return
  end

  mason_notify "Checking for package updates..."
  registry.update(vim.schedule_wrap(function(success, updated_registries)
    if success then
      local installed_pkgs = registry.get_installed_packages()
      local running = #installed_pkgs
      local no_pkgs = running == 0

      if no_pkgs then
        mason_notify "No updates available"
        astroevent "MasonUpdateCompleted"
      else
        local updated = false
        for _, pkg in ipairs(installed_pkgs) do
          pkg:check_new_version(function(update_available, version)
            if update_available then
              updated = true
              mason_notify(("Updating `%s` to %s"):format(pkg.name, version.latest_version))
              pkg:install():on("closed", function()
                running = running - 1
                if running == 0 then
                  mason_notify "Update Complete"
                  astroevent "MasonUpdateCompleted"
                end
              end)
            else
              running = running - 1
              if running == 0 then
                if updated then
                  mason_notify "Update Complete"
                else
                  mason_notify "No updates available"
                end
                astroevent "MasonUpdateCompleted"
              end
            end
          end)
        end
      end
    else
      mason_notify(("Failed to update registries: %s"):format(updated_registries), vim.log.levels.ERROR)
    end
  end))
end

return M
