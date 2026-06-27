
# vimtagger.nvim

> A simple, project-local file tagging plugin for Neovim with Telescope integration.

https://github.com/user-attachments/assets/cb79bf9a-1143-45bb-892f-01ad7151ce61

## Features

*  Tag files with arbitrary labels.
*  Search files by tags using Telescope.
*  Tags are stored per project.
*  Fast lookups using an inverted index.
*  Includes tools to inspect and validate the tag database.
*  A Pane to check tags, rename and files associated with tags

---

## Requirements

* Neovim >= 0.10
* [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

---

## Installation

Using **lazy.nvim**

```lua
{
    "Rimkomatic/vimtagger.nvim",
    dependencies = {
        "nvim-telescope/telescope.nvim",
    },
    config = function()
        require("vimtagger").setup()
    end,
}
```

---

## Quick Start

Initialize vimtagger for your project.

```vim
:VimtaggerInit
```

Add a tag to the current file.

```vim
:TagAdd backend
```

Add another tag.

```vim
:TagAdd api
```

Search files by tag.

```vim
:TagFindFiles
```

Open the panel to edit tags, files etc 

```vim
:TagTogglePane
```


---

## Commands

| Command            | Description                                          |
| ------------------ | ---------------------------------------------------- |
| `:VimtaggerInit`   | Initialize the tag database for the current project. |
| `:VimtaggerDelete` | Delete the project's tag database.                   |
| `:TagAdd`          | Add a tag to the current file.                       |
| `:TagRemove`       | Remove a tag from the current file.                  |
| `:TagSearch`       | Browse available tags.                               |
| `:TagFindFiles`    | Find files matching selected tags.                   |
| `:TagDoctor`       | Check the tag database for inconsistencies.          |
| `:ReadTaggerfile`  | Reload the tag database from disk.                   |
| `:TagTogglePane`  | Load a pane to delete/edit tags                   |

---

## Configuration

Default configuration:

```lua
require("vimtagger").setup({
    directory = vim.fn.stdpath("data") .. "/vimtagger",
})
```

---

## How It Works

Each project maintains its own independent tag database.

The database filename is derived from the SHA-256 hash of the project's root directory, allowing different projects to maintain separate tag collections without requiring configuration.

Internally, vimtagger maintains two structures:

* **Forward Index**

```
file
 ├── backend
 ├── api
 └── database
```

* **Inverted Index**

```
backend
 ├── main.go
 ├── server.go

api
 ├── server.go
 ├── routes.go
```

The inverted index enables fast tag-based lookups without scanning every file.

---

## Storage

Tag databases are stored in

```
stdpath("data")/vimtagger/
```

Each project is represented by a single JSON file.

---

## Typical Workflow

```text
:VimtaggerInit

:TagAdd backend
:TagAdd api
:TagAdd database

:TagFindFiles
:TagTogglePane
```
