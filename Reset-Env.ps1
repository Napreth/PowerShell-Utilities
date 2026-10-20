function Reset-Env {
    [CmdletBinding()]
    param()

    if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
        throw 'Reset-Env only supports Windows.'
    }

    $variables = [System.Collections.Generic.Dictionary[string, string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    # Machine first, then User (User takes precedence).
    foreach ($target in @('Machine', 'User')) {
        $scope = [EnvironmentVariableTarget]$target

        foreach ($entry in [Environment]::GetEnvironmentVariables($scope).GetEnumerator()) {
            if ($entry.Key -ine 'Path') {
                $variables[[string]$entry.Key] = [string]$entry.Value
            }
        }
    }

    # Load raw values first to resolve cross-variable references.
    foreach ($entry in $variables.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process')
    }

    # Expand references such as %JAVA_HOME%.
    foreach ($entry in $variables.GetEnumerator()) {
        $value = [Environment]::ExpandEnvironmentVariables($entry.Value)
        [Environment]::SetEnvironmentVariable($entry.Key, $value, 'Process')
    }

    # PATH is additive: Machine PATH + User PATH.
    $paths = foreach ($target in @('Machine', 'User')) {
        $value = [Environment]::GetEnvironmentVariable(
            'Path', [EnvironmentVariableTarget]$target
        )

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            [Environment]::ExpandEnvironmentVariables($value).Trim(';')
        }
    }

    $env:Path = $paths -join ';'
}
