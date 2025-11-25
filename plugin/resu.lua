if vim.g.loaded_resu then
  return
end
vim.g.loaded_resu = 1

local function complete_args(arg_lead, cmd_line, cursor_pos)
  -- Add completion logic if needed
  return {}
end

vim.api.nvim_create_user_command("AIReviewOpen", function()
  require("resu").open()
end, { desc = "Open AI Review panel" })

vim.api.nvim_create_user_command("AIReviewClose", function()
  require("resu").close()
end, { desc = "Close AI Review panel" })

vim.api.nvim_create_user_command("AIReviewToggle", function()
  require("resu").toggle()
end, { desc = "Toggle AI Review panel" })

vim.api.nvim_create_user_command("AIReviewNext", function()
  require("resu").next()
end, { desc = "Jump to next changed file" })

vim.api.nvim_create_user_command("AIReviewPrev", function()
  require("resu").prev()
end, { desc = "Jump to previous changed file" })

vim.api.nvim_create_user_command("AIReviewAccept", function()
  require("resu").accept()
end, { desc = "Accept changes in current file" })

vim.api.nvim_create_user_command("AIReviewDecline", function()
  require("resu").decline()
end, { desc = "Decline changes in current file" })

vim.api.nvim_create_user_command("AIReviewReset", function()
  require("resu").reset()
end, { desc = "Reset all file states" })
