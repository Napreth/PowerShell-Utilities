function Clear-Proxy {
    [CmdletBinding()]
    param()

    $names = @(
        'HTTP_PROXY', 'HTTPS_PROXY', 'SOCKS_PROXY',
        'ALL_PROXY', 'FTP_PROXY', 'NO_PROXY'
    )

    foreach ($name in $names) {
        [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        [Environment]::SetEnvironmentVariable($name.ToLowerInvariant(), $null, 'Process')
    }
}
