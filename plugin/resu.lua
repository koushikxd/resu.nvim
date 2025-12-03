if vim.g.loaded_resu then
  return
end
vim.g.loaded_resu = 1

vim.api.nvim_create_user_command("ResuOpen", function()
  require("resu").open()
end, { desc = "Open Resu diff view" })

vim.api.nvim_create_user_command("ResuClose", function()
  require("resu").close()
end, { desc = "Close Resu diff view" })

vim.api.nvim_create_user_command("ResuToggle", function()
  require("resu").toggle()
end, { desc = "Toggle Resu diff view" })

vim.api.nvim_create_user_command("ResuRefresh", function()
  require("resu").refresh()
end, { desc = "Refresh Resu view" })

vim.api.nvim_create_user_command("ResuAccept", function()
  require("resu").accept()
end, { desc = "Accept/stage current file" })

vim.api.nvim_create_user_command("ResuDecline", function()
  require("resu").decline()
end, { desc = "Decline/revert current file" })

vim.api.nvim_create_user_command("ResuAcceptAll", function()
  require("resu").accept_all()
end, { desc = "Accept/stage all changes" })

vim.api.nvim_create_user_command("ResuDeclineAll", function()
  require("resu").decline_all()
end, { desc = "Decline/revert all changes" })

vim.api.nvim_create_user_command("ResuReset", function()
  require("resu").reset()
end, { desc = "Reset Resu state" })
