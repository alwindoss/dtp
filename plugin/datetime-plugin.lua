-- plugin/datetime-plugin.lua
-- This file automatically loads when Neovim starts

-- Prevent loading the plugin multiple times
if vim.g.loaded_datetime_plugin then
  return
end
vim.g.loaded_datetime_plugin = true

-- Load and setup the plugin
local datetime_plugin = require('datetime-plugin')

-- Setup with default configuration
datetime_plugin.setup({
  keymaps = {
    datetime = '<leader>dt',  -- Press <leader>dt to insert datetime
    date = '<leader>dd'       -- Press <leader>dd to insert date
  }
})