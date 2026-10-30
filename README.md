# CommandNavigator

A keyboard-first command tree for PowerShell. Organize frequently used commands into folders, select a command in the terminal, edit it, and press **Enter** to run it.

CommandNavigator supports two command sources:

- **Shared commands** bundled with the module in `commands.json`.
- **Project commands** from `command.json` in the **exact current working directory** (no search through parent folders).

## Preview

![CommandNavigator terminal menu showing the System command tree](images/preview.png)

## Requirements

- Windows Terminal or another console that supports keyboard navigation and ANSI terminal sequences.
- **PowerShell 7+** (the JSON loader uses `ConvertFrom-Json -AsHashtable`).
- Any external tools referenced in commands, such as `git`, `docker`, or `az`, must be installed separately.

## Install

Once the module is published to PowerShell Gallery:

```powershell
Install-PSResource CommandNavigator -Scope CurrentUser
```

Then open PowerShell and run:

```powershell
cmdnav
```

If the package is not yet published, import it from a local checkout instead:

```powershell
Import-Module .\CommandNavigator.psd1 -Force
cmdnav
```

> **Execution policy:** Windows may block downloaded unsigned `.psm1` files under `RemoteSigned`. Review and trust the source before using `Unblock-File`. Organization-enforced policies can take precedence. Modules installed from PowerShell Gallery may behave differently from files downloaded as ZIPs.

## Use the navigator

The main screen shows a tree of categories. Navigate to a command, select it, then edit the prefilled command line if needed before executing it. The command runs in PowerShell and its output appears in your terminal.

| Key | Action |
| --- | --- |
| `Up` / `Down` | Move selection |
| `Enter` | Open a category or select a command |
| `Right` | Open a category |
| `Left` / `Backspace` | Return to the parent category |
| `Esc` / `Q` | Exit the menu |

When the selected command is presented for editing, use the editor's cursor keys, Backspace, and Delete. Press **Enter** to execute or **Esc** to cancel. Your exact key behavior depends on the installed CommandNavigator version.

## Configure shared commands

The module ships with a `commands.json` file alongside `CommandNavigator.psm1`. Locate the installed module directory:

```powershell
$module = Get-Module CommandNavigator -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1

$module.ModuleBase
```

Open the bundled shared command file with your Windows default application:

```powershell
Invoke-Item (Join-Path $module.ModuleBase 'commands.json')
```

Shared commands are available from any working directory. A command node has `Name` and `Command`; a folder node has `Name` and `Children`. The **JSON root must be an array**:

```json
[
  {
    "Name": "Git",
    "Children": [
      { "Name": "Status", "Command": "git status" },
      { "Name": "Recent commits", "Command": "git log --oneline -10" }
    ]
  },
  {
    "Name": "Docker",
    "Children": [
      { "Name": "List containers", "Command": "docker ps -a" }
    ]
  }
]
```

After editing, save valid JSON and launch `cmdnav` again to load the updated tree.

> **Updates can overwrite edits to the bundled `commands.json`.** Back up custom shared commands or maintain a fork if you change the file inside the installed module. A separate per-user override file is not part of the current design.

## Configure project commands

Create a file named **`command.json`** (singular) in your project root:

```text
MyProject/
├── command.json
├── src/
└── README.md
```

Example `command.json`:

```json
[
  {
    "Name": "Build",
    "Command": "dotnet build"
  },
  {
    "Name": "Tests",
    "Command": "dotnet test"
  },
  {
    "Name": "Git",
    "Children": [
      { "Name": "Status", "Command": "git status" },
      { "Name": "Current branch", "Command": "git branch --show-current" }
    ]
  }
]
```

From the project directory:

```powershell
Set-Location C:\Projects\MyProject
cmdnav
```

The menu shows project commands in addition to shared commands. **Only the exact current directory is checked.** Running from `MyProject\src` does *not* load `MyProject\command.json`.

Commit your project's `command.json` to its own Git repository if you want the team to share those commands. Review commands before executing them; JSON entries contain executable PowerShell text.

## Configure settings

The module includes `settings.json` in its module directory. To open it:

```powershell
Invoke-Item (Join-Path $module.ModuleBase 'settings.json')
```

Example contents:

```json
{
  "WriteHistory": false
}
```

| Setting | Default | Behavior |
| --- | --- | --- |
| `WriteHistory` | `false` | When `true`, CommandNavigator adds selected commands to PSReadLine history using `AddToHistory()`; when `false`, it does not explicitly add them. |

This setting does **not** disable PowerShell's normal history recording of the `cmdnav` invocation or commands entered directly at the prompt. Do not store secrets in commands if you enable history recording.

Save the file and launch `cmdnav` again for your changes to be used. Note that module updates can replace the bundled settings file; keep a backup of customized settings.

## JSON tips

- Use double quotes around JSON keys and string values.
- Escape literal double quotes inside command strings as `\"`, or use PowerShell single-quoted strings inside JSON strings.
- Keep `Children` as an array: `[ ... ]`.
- A node should define **either** `Children` **or** `Command`, not both.
- Verify JSON syntax with:

```powershell
Get-Content .\command.json -Raw | ConvertFrom-Json | Out-Null
```

## Updating

If installed from PowerShell Gallery:

```powershell
Update-PSResource CommandNavigator
```

Restart PowerShell to load the new module version. Remember that module updates may replace bundled `commands.json` and `settings.json`.

## Development and publishing

For contributors working from the repository:

```powershell
Import-Module .\CommandNavigator.psd1 -Force
Test-ModuleManifest .\CommandNavigator.psd1
```

Keep `.git`, build output, and private configuration out of PowerShell Gallery packages. Stage only the module's release files, and increment the version in `CommandNavigator.psd1` before publishing a new version.

## Security

CommandNavigator executes commands stored in JSON files. Review shared and project command files, especially from untrusted repositories, before running commands. Avoid embedding passwords, tokens, or other secrets. Use the principle of least privilege for commands that modify system or cloud resources.
