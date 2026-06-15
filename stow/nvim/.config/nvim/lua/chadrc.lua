---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "onedark",
  theme_toggle = { "onedark", "one_light" },
  transparency = false,
}

M.ui = { theme = "onedark" } -- Default NvChad Theme

M.mappings = require "mappings"

return M
