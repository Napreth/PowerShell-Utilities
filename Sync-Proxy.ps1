function Sync-Proxy {
    [CmdletBinding()]
    param()

    if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
        throw 'Sync-Proxy only supports Windows.'
    }

    $settings = Get-ItemProperty `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' `
        -ErrorAction Stop

    Clear-Proxy

    if (-not $settings.ProxyEnable -or
        [string]::IsNullOrWhiteSpace($settings.ProxyServer)) {

        if ($settings.AutoConfigURL) {
            Write-Warning 'PAC proxy configuration cannot be converted to proxy environment variables.'
        }

        return
    }

    $proxies = @{}
    $server = $settings.ProxyServer.Trim()

    # Supported formats:
    #   127.0.0.1:7890
    #   http=127.0.0.1:7890;https=127.0.0.1:7890;socks=127.0.0.1:7891
    foreach ($part in ($server -split '[;\s]+' | Where-Object { $_ })) {
        if ($part -match '^(http|https|socks)=(.+)$') {
            $proxies[$Matches[1].ToLowerInvariant()] = $Matches[2]
        }
        elseif ($part -notmatch '=') {
            $proxies['default'] = $part
        }
    }

    $defaultProxy = $proxies['default']

    foreach ($protocol in @('http', 'https', 'socks')) {
        $address = if ($proxies.ContainsKey($protocol)) {
            $proxies[$protocol]
        }
        elseif ($protocol -ne 'socks') {
            $defaultProxy
        }
        else {
            $null
        }

        if (-not $address) {
            continue
        }

        if ($address -match '^[a-z][a-z0-9+.-]*://') {
            $url = $address
        }
        else {
            $scheme = if ($protocol -eq 'socks') { 'socks5' } else { 'http' }
            $url = "${scheme}://${address}"
        }

        # curl requires lowercase http_proxy.
        $name = if ($protocol -eq 'http') { 'http_proxy' }
                else { "${protocol}_PROXY" }

        [Environment]::SetEnvironmentVariable($name, $url, 'Process')

        # ALL_PROXY is more widely supported than SOCKS_PROXY.
        if ($protocol -eq 'socks') {
            $env:ALL_PROXY = $url
        }
    }

    # Translate Windows ProxyOverride to NO_PROXY.
    $bypass = [System.Collections.Generic.List[string]]::new()
    $override = [string]$settings.ProxyOverride

    # WinINet normally bypasses loopback addresses.
    if ($override -notmatch '<-loopback>') {
        $bypass.AddRange([string[]]@(
            'localhost', 'loopback', '127.0.0.1', '::1'
        ))
    }

    foreach ($entry in ($override -split ';')) {
        $item = $entry.Trim()

        if (-not $item -or $item -eq '<-loopback>') {
            continue
        }

        if ($item -eq '<local>') {
            Write-Verbose '<local> cannot be represented exactly by NO_PROXY.'
            continue
        }

        if ($item -match '^\*\.([^*?]+)$') {
            $item = ".$($Matches[1])"
        }
        elseif ($item -match '[*?]' -and $item -ne '*') {
            Write-Warning "Unsupported NO_PROXY wildcard: $item"
            continue
        }

        $bypass.Add($item)
    }

    if ($bypass.Count -gt 0) {
        $env:NO_PROXY = ($bypass | Select-Object -Unique) -join ','
    }
}
