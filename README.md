# CommandNavigator

**Run your favorite PowerShell commands without memorizing them.** CommandNavigator is a keyboard-driven menu that lets you browse commands, edit them when needed, and run them from your current directory.

![CommandNavigator preview](images/preview.png)

## Get started

Install with PowerShell 7+:

```powershell
Install-PSResource CommandNavigator -Scope CurrentUser
cmdnav
```

Run `cmdnav` whenever you want to open the command menu.

## Using the menu

1. Use **Up / Down** to highlight a folder or command.
2. Press **Enter** or **Right** to open a folder or select a command.
3. If the command is editable, change it at the `PS>` prompt and press **Enter** to execute.
4. Your command runs in the current PowerShell session and directory. Its output remains visible after the menu closes.

| Key | Action |
| --- | --- |
| `↑` / `↓` | Move through commands |
| `Enter` / `→` | Open a folder or select a command |
| `←` / `Backspace` | Go back to the parent folder |
| `Esc` / `Q` | Close the menu |

While editing a command, use **Left / Right**, **Home / End**, **Backspace / Delete**, and normal typing. Long commands wrap across terminal lines. Press **Enter** to run or **Esc** to cancel. Some commands run immediately without editing.

## What's in the menu?

The default shared commands include:

- **Network** — IP configuration, network adapters, DNS cache.
- **System** — Computer information, running processes, Windows services.
- **Command Navigator** — Create or edit project commands, open shared commands, edit settings, open the configuration folder, or reset configuration.

You can add your own commands to the shared menu or create different commands for each project.

## Your own commands

### Shared commands (available everywhere)

In `cmdnav`, open **Command Navigator → System commands** to edit your shared command list. These commands appear regardless of your current directory.

For example, add a Git folder to `commands.json`:

```json
[
  {
    "Name": "Git",
    "Children": [
      { "Name": "Status", "Command": "git status" },
      { "Name": "Current branch", "Command": "git branch --show-current" }
    ]
  }
]
```

This is an example of the JSON structure; add it alongside your existing folders rather than replacing them unless you want to.

### Project commands (only in the current directory)

1. Open PowerShell in your project folder.
2. Run `cmdnav`.
3. Select **Command Navigator → Create or edit project commands**.
4. CommandNavigator creates `nav_commands.json` if needed and opens it for editing.

The starter file includes two example commands: **List first 10 items** and **Echo Hello World**. Replace or extend them with your project's build, test, Git, or deployment commands.

Project commands are loaded only from the **exact current directory**; parent directories are not searched. When a project file exists, the shared menu appears under **System**.

### Run without editing

Add `"Editable": false` to a command to execute it directly when selected:

```json
{
  "Name": "Git status",
  "Command": "git status",
  "Editable": false
}
```

If `Editable` is omitted, the global **EditableCommands** setting applies.

## Settings and configuration

Choose **Command Navigator → Settings** to change these options:

| Setting | Default | What it does |
| --- | --- | --- |
| `WriteHistory` | `false` | Adds selected commands to PSReadLine history when enabled |
| `EditableCommands` | `true` | Opens the command editor by default |
| `UseConsoleEditor` | `true` | Opens JSON files in the terminal using Microsoft Edit (`edit`); set to `false` to use the Windows default application |

Shared commands and settings are stored in:

```text
%LOCALAPPDATA%\CommandNavigator\
├── commands.json
└── settings.json
```

CommandNavigator copies the bundled defaults here on first use. **Module updates preserve your customizations.** Use **Open config dir** to browse these files.

**Reset configuration** deletes your saved shared commands and settings. Defaults are recreated the next time you run `cmdnav`, so back up any customizations first.

## Update

```powershell
Update-PSResource CommandNavigator
```

Restart PowerShell or reload the module to use the updated version. If a release adds new configuration options, compare your saved settings with the latest bundled defaults.

> **Safety:** Commands in JSON files execute PowerShell code. Review project command files before running them, especially in repositories you don't trust.
