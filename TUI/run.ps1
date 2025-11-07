#Requires -Version 5.1

<#
.SYNOPSIS
    Management System TUI Launcher for PowerShell

.DESCRIPTION
    Launches the Management System TUI with automatic dependency management
    and virtual environment activation. Creates and manages a Python virtual
    environment in the project root directory.

.PARAMETER Dev
    Run in development mode with hot reload using textual's dev server

.PARAMETER Help
    Display this help message

.EXAMPLE
    .\run.ps1
    Launches the TUI in normal mode

.EXAMPLE
    .\run.ps1 -Dev
    Launches the TUI in development mode with hot reload

.NOTES
    File Name      : run.ps1
    Prerequisite   : Python 3.10 or higher
    Virtual Env    : Created at <project-root>/.venv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Dev,

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

$ErrorActionPreference = "Stop"
$OriginalErrorActionPreference = $ErrorActionPreference

# Path Configuration
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = (Get-Item $SCRIPT_DIR).Parent.Parent.FullName
$VENV_DIR = Join-Path $PROJECT_ROOT ".venv"
$REQUIREMENTS = Join-Path $SCRIPT_DIR "requirements.txt"
$MAIN_PY = Join-Path $SCRIPT_DIR "main.py"
$PROFILES_DIR = Join-Path (Split-Path -Parent $SCRIPT_DIR) "profiles"

# Python Configuration
$REQUIRED_PYTHON_MAJOR = 3
$REQUIRED_PYTHON_MINOR = 10

# ============================================================================
# COLOR OUTPUT FUNCTIONS
# ============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewline
    )

    $params = @{
        ForegroundColor = $Color
        Object = $Message
    }

    if ($NoNewline) {
        $params.NoNewline = $true
    }

    Write-Host @params
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput -Message "✓ $Message" -Color Green
}

function Write-WarningMsg {
    param([string]$Message)
    Write-ColorOutput -Message "⚠  $Message" -Color Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-ColorOutput -Message "✗ $Message" -Color Red
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput -Message "  $Message" -Color Cyan
}

function Write-Banner {
    Write-Host ""
    Write-ColorOutput -Message "Management System TUI Launcher" -Color Green
    Write-Host ""
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Show-Help {
    Get-Help $MyInvocation.ScriptName -Detailed
    exit 0
}

function Test-ExecutionPolicy {
    $policy = Get-ExecutionPolicy
    if ($policy -eq "Restricted") {
        Write-ErrorMsg "Execution policy is Restricted"
        Write-Host ""
        Write-Info "To allow this script to run, execute the following command:"
        Write-ColorOutput -Message "  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -Color Yellow
        Write-Host ""
        Write-Info "Then try running this script again."
        exit 1
    }
}

function Set-UTF8Encoding {
    # Ensure UTF-8 encoding for proper unicode rendering
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $env:PYTHONIOENCODING = "utf-8"
    } catch {
        Write-WarningMsg "Could not set UTF-8 encoding: $_"
    }
}

function Test-CommandExists {
    param([string]$Command)

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            return $true
        }
        return $false
    } finally {
        $ErrorActionPreference = $oldPreference
    }
}

# ============================================================================
# PYTHON ENVIRONMENT FUNCTIONS
# ============================================================================

function Get-PythonCommand {
    # Try to find Python in order of preference
    $pythonCommands = @("python", "python3", "py")

    foreach ($cmd in $pythonCommands) {
        if (Test-CommandExists $cmd) {
            return $cmd
        }
    }

    return $null
}

function Test-PythonVersion {
    param([string]$PythonCmd)

    try {
        $versionOutput = & $PythonCmd --version 2>&1
        $versionString = $versionOutput -replace 'Python ', ''
        $versionParts = $versionString.Split('.')

        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]

        $versionInfo = @{
            Command = $PythonCmd
            Version = $versionString
            Major = $major
            Minor = $minor
            Valid = ($major -gt $REQUIRED_PYTHON_MAJOR) -or `
                    ($major -eq $REQUIRED_PYTHON_MAJOR -and $minor -ge $REQUIRED_PYTHON_MINOR)
        }

        return $versionInfo
    } catch {
        Write-ErrorMsg "Failed to get Python version: $_"
        return $null
    }
}

function Initialize-VirtualEnvironment {
    param([string]$PythonCmd)

    # Check if virtual environment exists
    if (-not (Test-Path $VENV_DIR)) {
        Write-Info "Creating virtual environment at $VENV_DIR..."

        try {
            & $PythonCmd -m venv $VENV_DIR
            if ($LASTEXITCODE -ne 0) {
                throw "Python venv creation failed with exit code $LASTEXITCODE"
            }
            Write-Success "Virtual environment created"
        } catch {
            Write-ErrorMsg "Failed to create virtual environment: $_"
            Write-Info "Try running: $PythonCmd -m pip install --user virtualenv"
            exit 1
        }
    } else {
        Write-Success "Virtual environment found at $VENV_DIR"
    }
}

function Enable-VirtualEnvironment {
    # Determine the activation script path based on OS
    $activateScript = Join-Path $VENV_DIR "Scripts\Activate.ps1"

    if (-not (Test-Path $activateScript)) {
        # Try alternate location (for Linux/WSL Python)
        $activateScript = Join-Path $VENV_DIR "bin\Activate.ps1"

        if (-not (Test-Path $activateScript)) {
            Write-ErrorMsg "Virtual environment activation script not found"
            Write-Info "Expected location: $activateScript"
            Write-Info "The virtual environment may be corrupted. Delete $VENV_DIR and try again."
            exit 1
        }
    }

    try {
        # Activate the virtual environment
        . $activateScript

        # Verify activation
        if ($env:VIRTUAL_ENV) {
            Write-Success "Virtual environment activated"
            return $true
        } else {
            Write-ErrorMsg "Virtual environment activation failed"
            return $false
        }
    } catch {
        Write-ErrorMsg "Failed to activate virtual environment: $_"
        Write-Info "You may need to adjust your execution policy."
        Write-Info "Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
        exit 1
    }
}

function Test-Dependencies {
    # Test if textual package is installed
    $testScript = "import textual"

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    try {
        $result = python -c $testScript 2>&1
        $success = $LASTEXITCODE -eq 0
        $ErrorActionPreference = $oldPreference
        return $success
    } catch {
        $ErrorActionPreference = $oldPreference
        return $false
    }
}

function Install-Dependencies {
    Write-Info "Installing dependencies from $REQUIREMENTS..."
    Write-Host ""

    try {
        python -m pip install --upgrade pip | Out-Null
        python -m pip install -r $REQUIREMENTS

        if ($LASTEXITCODE -ne 0) {
            throw "Pip install failed with exit code $LASTEXITCODE"
        }

        Write-Host ""
        Write-Success "Dependencies installed successfully"
        return $true
    } catch {
        Write-Host ""
        Write-ErrorMsg "Failed to install dependencies: $_"
        Write-Info "Try manually running: python -m pip install -r $REQUIREMENTS"
        return $false
    }
}

function Test-DependenciesPrompt {
    if (-not (Test-Dependencies)) {
        Write-WarningMsg "Dependencies not installed"
        Write-Host ""

        $response = Read-Host "Install dependencies now? (y/N)"
        Write-Host ""

        if ($response -eq 'y' -or $response -eq 'Y') {
            if (-not (Install-Dependencies)) {
                exit 1
            }
        } else {
            Write-ErrorMsg "Dependencies required to run TUI"
            Write-Info "Install manually with: python -m pip install -r $REQUIREMENTS"
            exit 1
        }
    } else {
        Write-Success "Dependencies installed"
    }
}

# ============================================================================
# ENVIRONMENT VALIDATION FUNCTIONS
# ============================================================================

function Test-Terminal {
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Success "PowerShell $($psVersion.Major).$($psVersion.Minor)"

    # Check for Windows Terminal or modern terminal emulator
    if ($env:WT_SESSION) {
        Write-Info "Running in Windows Terminal"
    } elseif ($env:ConEmuPID) {
        Write-Info "Running in ConEmu"
    } elseif ($Host.Name -eq "ConsoleHost") {
        Write-WarningMsg "Running in basic Windows Console"
        Write-Info "For best experience, use Windows Terminal"
    }

    # Set TERM environment variable if not set
    if (-not $env:TERM) {
        $env:TERM = "xterm-256color"
    }
}

function Test-ProfilesDirectory {
    # Discover profiles directory with precedence:
    # 1) $env:PROFILES_DIR if it contains YAML
    # 2) <repo-root>/ms-config/tenants
    # 3) <repo-root>/ms-config/infrastructure
    # 4) <management-system>/profiles
    # 5) <repo-root>/profiles
    $repoRoot = (Get-Item $PROJECT_ROOT).Parent.FullName

    function Test-HasYaml([string]$dir) {
        if (-not (Test-Path $dir -PathType Container)) { return $false }
        $file = Get-ChildItem -Path $dir -Include *.yml,*.yaml -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
        return [bool]$file
    }

    $selected = $null
    if ($env:PROFILES_DIR -and (Test-HasYaml $env:PROFILES_DIR)) {
        $selected = $env:PROFILES_DIR
    } else {
        $candidates = @(
            (Join-Path $repoRoot "ms-config\tenants"),
            (Join-Path $repoRoot "ms-config\infrastructure"),
            (Join-Path $PROJECT_ROOT "profiles"),
            (Join-Path $repoRoot "profiles")
        )
        foreach ($cand in $candidates) {
            if (Test-HasYaml $cand) { $selected = $cand; break }
        }
    }

    if ($selected) {
        $env:PROFILES_DIR = $selected
        Write-Success "Using profiles directory: $selected"
    } else {
        Write-WarningMsg "No profiles directory with YAML found"
        Write-Info "Searched ms-config/tenants, ms-config/infrastructure, and profiles"
        Write-Info "Profile management features will be limited"
    }
}

function Test-MainScript {
    if (-not (Test-Path $MAIN_PY)) {
        Write-ErrorMsg "Main script not found at $MAIN_PY"
        Write-Info "Are you running this script from the correct directory?"
        exit 1
    }
}

function Test-Requirements {
    if (-not (Test-Path $REQUIREMENTS)) {
        Write-ErrorMsg "Requirements file not found at $REQUIREMENTS"
        exit 1
    }
}

# ============================================================================
# TUI LAUNCH FUNCTIONS
# ============================================================================

function Start-TUI {
    param([bool]$DevMode)

    Write-Host ""
    Write-ColorOutput -Message "Starting TUI..." -Color Green
    Write-Host ""

    try {
        if ($DevMode) {
            Write-Info "Running in development mode with hot reload..."
            Write-Host ""

            # Check if textual dev command is available
            $testCmd = python -m textual --help 2>&1
            if ($LASTEXITCODE -eq 0) {
                python -m textual run --dev $MAIN_PY
            } else {
                Write-WarningMsg "Textual dev tools not available, running in normal mode"
                python $MAIN_PY
            }
        } else {
            python $MAIN_PY
        }

        $exitCode = $LASTEXITCODE

        Write-Host ""
        if ($exitCode -eq 0) {
            Write-Success "TUI exited successfully"
        } else {
            Write-WarningMsg "TUI exited with code $exitCode"
        }

        exit $exitCode
    } catch {
        Write-Host ""
        Write-ErrorMsg "Failed to start TUI: $_"
        exit 1
    }
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================

function Main {
    # Display help if requested
    if ($Help) {
        Show-Help
    }

    # Display banner
    Write-Banner

    # Test execution policy
    Test-ExecutionPolicy

    # Set UTF-8 encoding
    Set-UTF8Encoding

    # Validate required files exist
    Test-Requirements
    Test-MainScript

    # Find Python
    $pythonCmd = Get-PythonCommand
    if (-not $pythonCmd) {
        Write-ErrorMsg "Python is not installed or not in PATH"
        Write-Host ""
        Write-Info "Please install Python 3.10 or higher from:"
        Write-ColorOutput -Message "  https://www.python.org/downloads/" -Color Cyan
        Write-Host ""
        Write-Info "Make sure to check 'Add Python to PATH' during installation"
        exit 1
    }

    # Check Python version
    $pythonInfo = Test-PythonVersion -PythonCmd $pythonCmd
    if (-not $pythonInfo) {
        exit 1
    }

    if (-not $pythonInfo.Valid) {
        Write-ErrorMsg "Python $REQUIRED_PYTHON_MAJOR.$REQUIRED_PYTHON_MINOR or higher required (found $($pythonInfo.Version))"
        Write-Host ""
        Write-Info "Please upgrade Python from:"
        Write-ColorOutput -Message "  https://www.python.org/downloads/" -Color Cyan
        exit 1
    }

    Write-Success "Python $($pythonInfo.Version) found"

    # Initialize and activate virtual environment
    Initialize-VirtualEnvironment -PythonCmd $pythonInfo.Command
    $venvActivated = Enable-VirtualEnvironment

    if (-not $venvActivated) {
        exit 1
    }

    # Check and install dependencies
    Test-DependenciesPrompt

    # Validate terminal environment
    Test-Terminal

    # Check for profiles directory (warning only)
    Test-ProfilesDirectory

    # Launch TUI
    Start-TUI -DevMode:$Dev
}

# ============================================================================
# ERROR HANDLING AND CLEANUP
# ============================================================================

trap {
    Write-Host ""
    Write-ErrorMsg "An unexpected error occurred: $_"
    Write-Info "Stack trace:"
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

# Execute main function
try {
    Main
} catch {
    Write-Host ""
    Write-ErrorMsg "Fatal error: $_"
    exit 1
}
