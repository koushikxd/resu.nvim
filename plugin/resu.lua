--- Plugin loader: registers user commands and default keymap.
--- This file is auto-loaded by Neovim's plugin system.
if vim.g.loaded_resu then
  return
end
vim.g.loaded_resu = 1

vim.api.nvim_create_user_command("ResuOpen", function()
  require("resu").open()
end, { desc = "Open Resu panel" })

vim.api.nvim_create_user_command("ResuClose", function()
  require("resu").close()
end, { desc = "Close Resu panel" })

vim.api.nvim_create_user_command("ResuToggle", function()
  require("resu").toggle()
end, { desc = "Toggle Resu panel" })

vim.api.nvim_create_user_command("ResuNext", function()
  require("resu").next()
end, { desc = "Jump to next changed file" })

vim.api.nvim_create_user_command("ResuPrev", function()
  require("resu").prev()
end, { desc = "Jump to previous changed file" })

vim.api.nvim_create_user_command("ResuAccept", function()
  require("resu").accept()
end, { desc = "Accept changes in current file" })

vim.api.nvim_create_user_command("ResuDecline", function()
  require("resu").decline()
end, { desc = "Decline changes in current file" })

vim.api.nvim_create_user_command("ResuAcceptAll", function()
  require("resu").accept_all()
end, { desc = "Accept all pending changes" })

vim.api.nvim_create_user_command("ResuDeclineAll", function()
  require("resu").decline_all()
end, { desc = "Decline all pending changes" })

vim.api.nvim_create_user_command("ResuReset", function()
  require("resu").reset()
end, { desc = "Reset all file states" })

vim.keymap.set("n", "<leader>rt", function()
  require("resu").toggle()
end, { desc = "Toggle Resu panel" })
