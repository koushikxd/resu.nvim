if vim.g.loaded_resu then
  return
end
vim.g.loaded_resu = 1

local function complete_args(arg_lead, cmd_line, cursor_pos)
  -- Add completion logic if needed
  return {}
end

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

vim.api.nvim_create_user_command("ResuReset", function()
  require("resu").reset()
end, { desc = "Reset all file states" })

-- Toggle keymap
vim.keymap.set("n", "<leader>rt", function()
  require("resu").toggle()
end, { desc = "Toggle Resu panel" })
