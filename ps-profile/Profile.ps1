using namespace System.Management.Automation
using namespace System.Management.Automation.Language

$env:HOME = "c:\Users\$($env:USERNAME)\"

Import-Module -Name Terminal-Icons
Import-Module PSReadLine
Import-Module posh-git

Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

oh-my-posh --init --shell pwsh --config C:\Users\ggaudreau\AppData\Local\Programs\oh-my-posh\themes\ggaudreau.omp.json | Invoke-Expression

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)
  [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
  $Local:word = $wordToComplete.Replace('"', '""')
  $Local:ast = $commandAst.ToString().Replace('"', '""')
  winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
  }
}

# PowerShell parameter completion shim for the dotnet CLI
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
  param($commandName, $wordToComplete, $cursorPosition)
  dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
  }
}

function GoTo-Repo
{
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Name
  )

  Push-Location $Name
}

function GoTo-Git
{
  Push-Location D:/git
}

Set-Alias -Name k -Value kubectl
Set-Alias -Name j -Value GoTo-Repo
Set-Alias -Name l -Value ls
Set-Alias -Name repos -Value GoTo-Git
Set-Alias -Name tf -Value terraform

function __kubectl_debug
{
  if ($env:BASH_COMP_DEBUG_FILE)
  {
    "$args" | Out-File -Append -FilePath "$env:BASH_COMP_DEBUG_FILE"
  }
}

filter __kubectl_escapeStringWithSpecialChars
{
  $_ -replace '\s|#|@|\$|;|,|''|\{|\}|\(|\)|"|`|\||<|>|&', '`$&'
}


Invoke-Command {

  # output of kubectl completion powershell - start


  $Local:kCompletion = {
    param(
      $WordToComplete,
      $CommandAst,
      $CursorPosition
    )

    # Get the current command line and convert into a string
    $Command = $CommandAst.CommandElements
    $Command = "$Command"

    __kubectl_debug ""
    __kubectl_debug "========= starting completion logic =========="
    __kubectl_debug "WordToComplete: $WordToComplete Command: $Command CursorPosition: $CursorPosition"

    # The user could have moved the cursor backwards on the command-line.
    # We need to trigger completion from the $CursorPosition location, so we need
    # to truncate the command-line ($Command) up to the $CursorPosition location.
    # Make sure the $Command is longer then the $CursorPosition before we truncate.
    # This happens because the $Command does not include the last space.
    if ($Command.Length -gt $CursorPosition)
    {
      $Command = $Command.Substring(0, $CursorPosition)
    }
    __kubectl_debug "Truncated command: $Command"

    $ShellCompDirectiveError = 1
    $ShellCompDirectiveNoSpace = 2
    $ShellCompDirectiveNoFileComp = 4
    $ShellCompDirectiveFilterFileExt = 8
    $ShellCompDirectiveFilterDirs = 16

    # Prepare the command to request completions for the program.
    # Split the command at the first space to separate the program and arguments.
    $Program, $Arguments = $Command.Split(" ", 2)
    $RequestComp = "$Program __complete $Arguments"
    __kubectl_debug "RequestComp: $RequestComp"

    # we cannot use $WordToComplete because it
    # has the wrong values if the cursor was moved
    # so use the last argument
    if ($WordToComplete -ne "" )
    {
      $WordToComplete = $Arguments.Split(" ")[-1]
    }
    __kubectl_debug "New WordToComplete: $WordToComplete"


    # Check for flag with equal sign
    $IsEqualFlag = ($WordToComplete -Like "--*=*" )
    if ( $IsEqualFlag )
    {
      __kubectl_debug "Completing equal sign flag"
      # Remove the flag part
      $Flag, $WordToComplete = $WordToComplete.Split("=", 2)
    }

    if ( $WordToComplete -eq "" -And ( -Not $IsEqualFlag ))
    {
      # If the last parameter is complete (there is a space following it)
      # We add an extra empty parameter so we can indicate this to the go method.
      __kubectl_debug "Adding extra empty parameter"
      # We need to use `"`" to pass an empty argument a "" or '' does not work!!!
      $RequestComp = "$RequestComp" + ' `"`"'
    }

    __kubectl_debug "Calling $RequestComp"
    #call the command store the output in $out and redirect stderr and stdout to null
    # $Out is an array contains each line per element
    Invoke-Expression -OutVariable out "$RequestComp" 2>&1 | Out-Null


    # get directive from last line
    [int]$Directive = $Out[-1].TrimStart(':')
    if ($Directive -eq "")
    {
      # There is no directive specified
      $Directive = 0
    }
    __kubectl_debug "The completion directive is: $Directive"

    # remove directive (last element) from out
    $Out = $Out | Where-Object { $_ -ne $Out[-1] }
    __kubectl_debug "The completions are: $Out"

    if (($Directive -band $ShellCompDirectiveError) -ne 0 )
    {
      # Error code.  No completion.
      __kubectl_debug "Received error from custom completion go code"
      return
    }

    $Longest = 0
    $Values = $Out | ForEach-Object {
      #Split the output in name and description
      $Name, $Description = $_.Split("`t", 2)
      __kubectl_debug "Name: $Name Description: $Description"

      # Look for the longest completion so that we can format things nicely
      if ($Longest -lt $Name.Length)
      {
        $Longest = $Name.Length
      }

      # Set the description to a one space string if there is none set.
      # This is needed because the CompletionResult does not accept an empty string as argument
      if (-Not $Description)
      {
        $Description = " "
      }
      @{Name = "$Name"; Description = "$Description" }
    }


    $Space = " "
    if (($Directive -band $ShellCompDirectiveNoSpace) -ne 0 )
    {
      # remove the space here
      __kubectl_debug "ShellCompDirectiveNoSpace is called"
      $Space = ""
    }

    if ((($Directive -band $ShellCompDirectiveFilterFileExt) -ne 0 ) -or
        (($Directive -band $ShellCompDirectiveFilterDirs) -ne 0 ))
    {
      __kubectl_debug "ShellCompDirectiveFilterFileExt ShellCompDirectiveFilterDirs are not supported"

      # return here to prevent the completion of the extensions
      return
    }

    $Values = $Values | Where-Object {
      # filter the result
      $_.Name -like "$WordToComplete*"

      # Join the flag back if we have an equal sign flag
      if ( $IsEqualFlag )
      {
        __kubectl_debug "Join the equal sign flag back to the completion value"
        $_.Name = $Flag + "=" + $_.Name
      }
    }

    if (($Directive -band $ShellCompDirectiveNoFileComp) -ne 0 )
    {
      __kubectl_debug "ShellCompDirectiveNoFileComp is called"

      if ($Values.Length -eq 0)
      {
        # Just print an empty string here so the
        # shell does not start to complete paths.
        # We cannot use CompletionResult here because
        # it does not accept an empty string as argument.
        ""
        return
      }
    }

    # Get the current mode
    $Mode = (Get-PSReadLineKeyHandler | Where-Object { $_.Key -eq "Tab" }).Function
    __kubectl_debug "Mode: $Mode"

    $Values | ForEach-Object {

      # store temporary because switch will overwrite $_
      $comp = $_

      # PowerShell supports three different completion modes
      # - TabCompleteNext (default windows style - on each key press the next option is displayed)
      # - Complete (works like bash)
      # - MenuComplete (works like zsh)
      # You set the mode with Set-PSReadLineKeyHandler -Key Tab -Function <mode>

      # CompletionResult Arguments:
      # 1) CompletionText text to be used as the auto completion result
      # 2) ListItemText   text to be displayed in the suggestion list
      # 3) ResultType     type of completion result
      # 4) ToolTip        text for the tooltip with details about the object

      switch ($Mode)
      {

        # bash like
        "Complete"
        {

          if ($Values.Length -eq 1)
          {
            __kubectl_debug "Only one completion left"

            # insert space after value
            [System.Management.Automation.CompletionResult]::new($($comp.Name | __kubectl_escapeStringWithSpecialChars) + $Space, "$($comp.Name)", 'ParameterValue', "$($comp.Description)")

          }
          else
          {
            # Add the proper number of spaces to align the descriptions
            while ($comp.Name.Length -lt $Longest)
            {
              $comp.Name = $comp.Name + " "
            }

            # Check for empty description and only add parentheses if needed
            if ($($comp.Description) -eq " " )
            {
              $Description = ""
            }
            else
            {
              $Description = "  ($($comp.Description))"
            }

            [System.Management.Automation.CompletionResult]::new("$($comp.Name)$Description", "$($comp.Name)$Description", 'ParameterValue', "$($comp.Description)")
          }
        }

        # zsh like
        "MenuComplete"
        {
          # insert space after value
          # MenuComplete will automatically show the ToolTip of
          # the highlighted value at the bottom of the suggestions.
          [System.Management.Automation.CompletionResult]::new($($comp.Name | __kubectl_escapeStringWithSpecialChars) + $Space, "$($comp.Name)", 'ParameterValue', "$($comp.Description)")
        }

        # TabCompleteNext and in case we get something unknown
        Default
        {
          # Like MenuComplete but we don't want to add a space here because
          # the user need to press space anyway to get the completion.
          # Description will not be shown because that's not possible with TabCompleteNext
          [System.Management.Automation.CompletionResult]::new($($comp.Name | __kubectl_escapeStringWithSpecialChars), "$($comp.Name)", 'ParameterValue', "$($comp.Description)")
        }
      }

    }
  }

  # modified those to add completer for "k"
  Register-ArgumentCompleter -CommandName 'kubectl' -ScriptBlock $Local:kCompletion
  Register-ArgumentCompleter -CommandName 'k' -ScriptBlock $Local:kCompletion

  # output of kubectl completion powershell - end

  $Local:RepoNameCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    Get-ChildItem (Get-Item d:\git[s]).FullName -Filter "*$wordToComplete*" | % {
      [System.Management.Automation.CompletionResult]::new($_.FullName, $_.FullName, "ParameterValue", $_.FullName)
    }
  }

  Register-ArgumentCompleter -CommandName GoTo-Repo -ParameterName Name -ScriptBlock $Local:RepoNameCompleter
  Register-ArgumentCompleter -CommandName r -ParameterName Name -ScriptBlock $Local:RepoNameCompleter
}

function gitp(
  [Parameter(Mandatory)]$message,
  
  [Parameter()]
  [Switch]$OpenPr
)
{
  git add . :/
  git commit -m $message
  git push

  if ($OpenPr.ToBool())
  {
    $branchName = git branch --show-current

    $taskId = $branchName -split '-' | select -Skip 1 -First 1

    $parameters = @()

    $taskIdInt = 0
    
    if ([int]::TryParse($taskId, [ref]$taskIdInt))
    {
      $parameters += "--work-items"
      $parameters += $taskIdInt
    }

    $description = $message

    $parameters += "--description"

    if ($description -like "*, *")
    {
      $description -split ", " | foreach { "- $_" } | % { $parameters += $_ }
    }
    else
    {
      $parameters += $description
    }

    $repoName = $(git rev-parse --show-toplevel) -split '/' | Select-Object -Last 1

    Write-Host $taskId $taskIdInt 

    az repos pr create -d $description -r $repoName -s "$branchName" -t master --title $message @parameters 
  }
}

function master()
{
  git checkout master
  git pull
}

function main()
{
  git checkout main
  git pull
}

function ConvertTo-Base64
{
  param(
    [Parameter(Mandatory)]
    [string]$value
  )

  Write-Output ([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($value)))
}

function ConvertFrom-Base64
{
  param(
    [Parameter(Mandatory)]
    [string]$value
  )

  Write-Output ([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($value)))
}

function codeise()
{
  code --user-data-dir $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("~/.vscode-powershellise") $args
}