# Command Navigator - keyboard-first PowerShell command tree
# Load once per session: . "$HOME\CommandNavigator.ps1"
# Then run: cmdnav

function cmdnav {
    [CmdletBinding()]
    param()

    $settingsFile = 'settings.json'
    $commandsFile = 'commands.json'
    $projectCommandsFile = 'nav_commands.json'
    $configDir = Join-Path $env:LOCALAPPDATA 'CommandNavigator'

    # Ensure the configuration directory exists
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    # Ensure the configuration files exist in the configuration directory
    foreach ($file in @($commandsFile, $settingsFile)) {
        $destination = Join-Path $configDir $file

        if (-not (Test-Path $destination)) {
            Copy-Item (Join-Path $PSScriptRoot $file) $destination
        }
    }

      # Load commands.json from the script's directory
    $configPath = Join-Path $configDir $commandsFile
    $settingsPath = Join-Path $configDir $settingsFile
    $projectPath = Join-Path (Get-Location).ProviderPath $projectCommandsFile

    # Configuration
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

    $addToHistory = $settings.WriteHistory -ne $false
    $editableCommands = $settings.EditableCommands -ne $false
    $useConsoleEditor = $settings.UseConsoleEditor -ne $false

    # Load shared commands
    $sharedTree = @(
        Get-Content -LiteralPath $configPath -Raw |
        ConvertFrom-Json -AsHashtable
    )

    $tree = @()

    #  Load project-specific commands if available
    if (Test-Path -LiteralPath $projectPath -PathType Leaf) {
        $projectTree = @(
            Get-Content -LiteralPath $projectPath -Raw |
            ConvertFrom-Json -AsHashtable
        )

        $tree += $projectTree

        $tree += @{
            Name     = 'System'
            Children = $sharedTree
        }
    }
    else {
        # Always include shared commands
        $tree = $sharedTree
    }

    $stack = [System.Collections.Generic.List[object]]::new()
    $items = $tree
    $selection = 0
    $filter = ''
    $quit = $false
    $selectedCommand = $null

    # Enter alternate screen and hide cursor
    Write-Host -NoNewline "`e[?1049h`e[?25l"

    try {
        while (-not $quit) {
            $visible = @($items)
            if ($selection -ge $visible.Count) { $selection = [Math]::Max(0, $visible.Count - 1) }
            Clear-Host
            Write-Host ' COMMAND NAVIGATOR' -ForegroundColor Cyan
            $breadcrumb = if ($stack.Count) { ($stack | ForEach-Object { $_.Name }) -join ' / ' } else { 'Home' }
            Write-Host " $breadcrumb" -ForegroundColor DarkCyan
            Write-Host ' ------------------------------------------------'
            if ($filter) { Write-Host " Filter: $filter" -ForegroundColor Yellow }
            if (-not $visible.Count) { Write-Host ' (No matches. Press / to search again.)' -ForegroundColor DarkGray }
            for ($i = 0; $i -lt $visible.Count; $i++) {
                $node = $visible[$i]
                $prefix = if ($node.ContainsKey('Children')) { '[+]' } else { ' > ' }
                $line = " $prefix $($node.Name)"
                if ($i -eq $selection) {
                    $esc = [char]27
                    Write-Host "$esc[30;46m >$line $esc[0m"
                }
                else {
                    Write-Host "  $line" -ForegroundColor Gray
                }
            }
            Write-Host ''
            if ($visible.Count -and -not $visible[$selection].ContainsKey('Children')) {
                Write-Host ' Command:' -ForegroundColor DarkCyan
                Write-Host " $($visible[$selection].Command)" -ForegroundColor Yellow
            }
            Write-Host ''
            Write-Host ' Up/Down  navigate     Enter/Right  open or run'
            Write-Host ' Left     parent       Esc or Q     exit'
            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow' { $selection = [Math]::Max(0, $selection - 1) }
                'DownArrow' { $selection = [Math]::Min([Math]::Max(0, $visible.Count - 1), $selection + 1) }
                'LeftArrow' {
                    if ($stack.Count) {
                        $stack.RemoveAt($stack.Count - 1)
                        $items = $tree
                        foreach ($parent in $stack) { $items = $parent.Children }
                        $selection = 0
                        $filter = ''
                    }
                }
                'Backspace' {
                    if ($stack.Count) {
                        $stack.RemoveAt($stack.Count - 1)
                        $items = $tree
                        foreach ($parent in $stack) { $items = $parent.Children }
                        $selection = 0
                        $filter = ''
                    }
                }
                { $_ -in @('Enter', 'RightArrow') } {
                    if ($visible.Count) {
                        $node = $visible[$selection]
                        if ($node.ContainsKey('Children')) {
                            $stack.Add($node)
                            $items = $node.Children
                            $selection = 0
                            $filter = ''
                        }
                        elseif ($key.Key -eq 'Enter') {
                            $selectedCommand = [string]$node.Command
                            $quit = $true
                        }
                    }
                }
                'Escape' { $quit = $true }
                'Q' { $quit = $true }
            }
        }
    }
    finally {
        # Restore normal screen and show cursor
        Write-Host -NoNewline "`e[?25h`e[?1049l"
    }

    if ($selectedCommand) {
        $command = [string]$selectedCommand

        # Determine if the command is editable based on the node's 'Editable' property or the default editable commands list
        $editable = if ($node.Contains('Editable') -and $null -ne $node.Editable) {
            $node.Editable
        } 
        else {
            $editableCommands
        }

        # Check if the command is editable before entering the editing loop
        if ($editable) {

            Write-Host 'Edit command, then press Enter to execute. Esc to cancel.' -ForegroundColor DarkGray
            $cursor = $command.Length
            $prompt = 'PS> '
            $startX = 0
            $startY = [Console]::CursorTop
            $previousLength = 0

            while ($true) {
                $width = [Console]::BufferWidth

                # Ensure there is enough space for the command to wrap.
                $totalLength = $prompt.Length + [Math]::Max($command.Length, $previousLength)
                $rowsNeeded = [int][Math]::Floor($totalLength / $width) + 1

                if ($startY + $rowsNeeded -gt [Console]::BufferHeight) {
                    $scroll = $startY + $rowsNeeded - [Console]::BufferHeight

                    [Console]::SetCursorPosition(0, [Console]::BufferHeight - 1)
                    [Console]::Write("`n" * $scroll)

                    $startY -= $scroll
                }

                # Redraw the full command, including wrapped lines.
                [Console]::SetCursorPosition($startX, $startY)

                [Console]::Write(
                    $prompt + $command +
                    (' ' * [Math]::Max(0, $previousLength - $command.Length))
                )

                $previousLength = $command.Length

                # Calculate cursor position across wrapped lines.
                $position = $startX + $prompt.Length + $cursor
                $x = $position % $width
                $y = $startY + [int][Math]::Floor($position / $width)

                [Console]::SetCursorPosition($x, $y)

                # Keep your existing keyboard handling below.

                $key = [Console]::ReadKey($true)

                switch ($key.Key) {
                    'Enter' {
                        break
                    }
                    'Escape' {
                        Write-Host ''
                        return
                    }
                    'Backspace' {
                        if ($cursor -gt 0) {
                            $command = $command.Remove($cursor - 1, 1)
                            $cursor--
                        }
                    }
                    'Delete' {
                        if ($cursor -lt $command.Length) {
                            $command = $command.Remove($cursor, 1)
                        }
                    }
                    'LeftArrow' {
                        if ($cursor -gt 0) { $cursor-- }
                    }
                    'RightArrow' {
                        if ($cursor -lt $command.Length) { $cursor++ }
                    }
                    'Home' {
                        $cursor = 0
                    }
                    'End' {
                        $cursor = $command.Length
                    }
                    default {
                        if (-not [char]::IsControl($key.KeyChar)) {
                            $command = $command.Insert(
                                $cursor,
                                [string]$key.KeyChar
                            )
                            $cursor++
                        }
                    }
                }

                if ($key.Key -eq 'Enter') {
                    break
                }
            }
            Write-Host ''
        }

        if ([string]::IsNullOrWhiteSpace($command)) {
            return
        }

        if ($command -match '<[^>]+>') {
            Write-Warning 'Replace command placeholders before executing.'
            return
        }

        # Execute the command within a try-catch block to handle errors gracefully
        try {
            # Add the command to the history if required
            if ($addToHistory) {
                [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($command)
            }

            & ([scriptblock]::Create($command))
        }
        catch {
            Write-Error $_
        }
    }
}

function Edit-ProjectCommands {
    $path = "./$projectCommandsFile"

    if (-not (Test-Path $path)) {
        Copy-Item -Path (Join-Path $PSScriptRoot 'projectCommands.json') -Destination $path
    }

    Open-File -path $path
}

function Open-SharedCommands {
    Open-File -path $configPath
}

function Open-Settings {
    Open-File -path $settingsPath
}

function Open-File(){
    param (
        [string]$path
    )

    if (Test-Path $path) {
        if($useConsoleEditor) {
            edit $path
        }
        else {
            Start-Process -FilePath $path -Verb Open
        }
    }
}

function Open-ConfigFolder {
    Start-Process -FilePath $configDir
}

function Remove-ConfigFolder {
    if (Test-Path $configDir) {
        Remove-Item -LiteralPath $configDir -Recurse -Force
    }
}

# Export the function from the module
Export-ModuleMember -Function cmdnav