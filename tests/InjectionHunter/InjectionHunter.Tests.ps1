[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Suppress false positives in Pester code blocks')]
param()


Describe 'Injection Hunter security checks' {

    BeforeAll {
        $injectionHunterPath = (Get-Module InjectionHunter -ListAvailable).Path
    }
    BeforeDiscovery {
        $modulePath = Resolve-Path (Join-Path $PSScriptRoot '..\..\src')
        # Exclude class files as they have inter-dependencies that can't be analyzed in isolation
        $files = Get-ChildItem -Path $modulePath -Recurse -Include '*.ps1' -Exclude '*.Tests.*' | Where-Object { $_.DirectoryName -notmatch 'Classes' }
    }

    It '<_.BaseName> Function should contains no Injection Hunter violations' -ForEach $files {
        $requestParam = @{
            Path           = $_
            Recurse        = $true
            CustomRulePath = $injectionHunterPath
        }
        $results = Invoke-ScriptAnalyzer @requestParam | ForEach-Object {
            "Problem in $($_.ScriptName) at line $($_.Line) with message: $($_.Message)"
        }

        $results | Should -BeNullOrEmpty
    }
}
