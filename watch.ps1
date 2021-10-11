#Requires -version 2.0

function Get-StringHash([String] $InputString)
{
    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write($InputString)
    $writer.Flush()
    $stringAsStream.Position = 0

    $hash = Get-FileHash -Algorithm "SHA256" -InputStream $stringAsStream | Select-Object Hash

    $hash.Hash
}

try
{
    $query = "select * from __InstanceCreationEvent within 1 where TargetInstance isa 'Win32_PnPEntity'"
    Register-WMIEvent -Query $query -SourceIdentifier "PnPEntityInstanceCreated"
    write-host (get-date -format s) "Started listening..."
    do
    {
        $newEvent = Wait-Event -SourceIdentifier "PnPEntityInstanceCreated"
        $deviceName = $newEvent.SourceEventArgs.NewEvent.TargetInstance.Name
        $deviceId = $newEvent.SourceEventArgs.NewEvent.TargetInstance.DeviceID
        $deviceIdHash = Get-StringHash $deviceId
        
        write-host (get-date -format s) "New device: { Name: $deviceName, DeviceID: $deviceId, DeviceID Hash: $deviceIdHash }"

        $scriptFolder = "$PSScriptRoot\$deviceIdHash"
        if (Test-Path -Path $scriptFolder)
        {
            write-host (get-date -format s) "Folder $scriptFolder exists: entering"
            Get-ChildItem $scriptFolder -Filter "*.ps1" |
            Foreach-Object {
                write-host (get-date -format s) "Running $_.FullName..."
                & $_.FullName
                write-host (get-date -format s) "Done!"
            }
        }
        else
        {
            write-host (get-date -format s) "Folder $scriptFolder does not exist: skipping"
        }
    
        Remove-Event -SourceIdentifier "PnPEntityInstanceCreated"
    }
    while ($true)
}
finally {
    Unregister-Event -SourceIdentifier "PnPEntityInstanceCreated"
    write-host (get-date -format s) "Stopped listening."
}
