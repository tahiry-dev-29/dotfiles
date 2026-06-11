require "nvchad.options"

local o = vim.o

-- System clipboard integration (essential for standard Copy/Paste)
o.clipboard = "unnamedplus"

-- Enable mouse support everywhere
o.mouse = "a"

-- Smooth scrolling margin (keeps context above/below cursor)
o.scrolloff = 8

-- Faster update time for better responsiveness
o.updatetime = 250

-- Désactiver les fichiers swap pour éviter l'erreur E325
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- Sauvegarde automatique quand on change de buffer ou qu'on perd le focus
vim.opt.autowrite = true
vim.opt.autowriteall = true
