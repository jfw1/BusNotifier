Param(
  [int]$StopId = 5000, 
  [string[]]$Routes,
  [switch]$Debug,
  [int]$TimeToBusStop = 5
)

$Timeframe = 3600

function Show-Notification ($title, $body)
{
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    # Toasts templates: https://msdn.microsoft.com/en-us/library/windows/apps/hh761494.aspx
    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText04)
    # Convert to .NET type for XML manipuration
    $toastXml = [xml] $template.GetXml()
    # Customize the toast message
    $toastXml.GetElementsByTagName(“text”)[0].AppendChild($toastXml.CreateTextNode($title)) > $null
    $toastXml.GetElementsByTagName(“text”)[1].AppendChild($toastXml.CreateTextNode($body)) > $null
 
    # Convert back to WinRT type
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($toastXml.OuterXml)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
 
    # Unique Application id/tag and group
    $toast.Tag = “PowerShell UI”
    $toast.Group = “PowerShell UI”
 
    # Create the toats and show the toast. Make sure to include the AppId
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($toast.Tag)
    $notifier.Show($toast);
}

$Bytes = [BitConverter]::GetBytes(0x1F525)
$FireEmoji = [System.Text.Encoding]::UTF32.GetString($Bytes)

$Bytes = [BitConverter]::GetBytes(0x26A0)
$WarningEmoji = [System.Text.Encoding]::UTF32.GetString($Bytes)

$index = 1
$ServiceCount = 0

$StopName = ((Invoke-WebRequest "https://www.metlink.org.nz/api/v1/StopDepartures/$StopId") | ConvertFrom-Json).Stop.Name
Write-Host $StopName

do {
    $ApiResponse = ''
    $ApiResponse = (Invoke-WebRequest "https://www.metlink.org.nz/api/v1/StopDepartures/$StopId") | ConvertFrom-Json

    foreach ($Service in $ApiResponse.Services) {
        $LeaveNow = $false
        if (($Routes -contains $Service.Service.TrimmedCode -or $Routes -eq $null) -and $Service.DisplayDepartureSeconds -le $Timeframe) {
            $ServiceCount += 1
            $MinutesAway = [math]::Round(([int]$Service.DisplayDepartureSeconds)/60)
            $FriendlyTime = ([datetime]$Service.AimedDeparture).ToString("HH:mm")
            $Route = $Service.Service.TrimmedCode
            $Destination =  $Service.DestinationStopName
            
            if ($service.IsRealtime -eq $true) {
                $RealTime = $true 
            }

            else { 
                $RealTime = $false 
            }
        
            #Let the user know if they should leave now, based on the TimeToBusStop parameter, +/- one minute
            if ($MinutesAway -le ($TimeToBusStop + 1) -and $MinutesAway -ge ($TimeToBusStop - 1) -and $TimeToBusStop -ne 0 -and $RealTime -eq $true) {
                $Body = "$FireEmoji Leave now to get the #$Route to $Destination - it's"
                $LeaveNow = $true
            }

            else { 
                $Body = "There is a #$Route to $Destination" 
            }

            if ($RealTime -eq $true) {
                $ScheduledDeparture = [datetime]$Service.AimedDeparture
                $RealTimeDeparture = [datetime]$Service.ExpectedDeparture

                $Delta = $ScheduledDeparture-$RealTimeDeparture
                $Delta = [math]::Round($Delta.Minutes)

                if ($Delta -eq 0) {
                    $Status = 'on time'
                    $Body += " " + $MinutesAway + " minutes away. It's running on time."
                }

                if ($Delta -ge 1) { 
                    $Status = "late" 
                }

                if ($Delta -le -1) {
                    $Status = "early"
                    $Delta = $Delta * -1
                }

                if ($Status -ne 'on time') {
                    $Body += " " + $MinutesAway + " minutes away. It's running " + $Delta + " minutes " + $Status + "."
                }
                
            }

            else { 
                $Body +=  " scheduled to depart at " + $FriendlyTime + "." 
            }
        
            if ($RealTime -eq $true) {
                $LogEntry = "$Route to $Destination - $MinutesAway minutes away"

                if ($LeaveNow -eq $true) { $LogEntry += " (leave now)" }

                Write-Host $LogEntry
                $LeaveNow = $false
            }

            else { 
                Write-Host "$Route to $Destination - scheduled for $FriendlyTime" 
            }
            
            
            if ($Debug -eq $false) {
                Show-Notification -title ("$WarningEmoji Bus Alert: " + $ApiResponse.Stop.Name) -body $Body
                Start-Sleep -Seconds 7
            }
            if ($Debug -eq $true) { 
                $index = -1 
            }
        }
    }   

    if ($Debug -eq $false)
    {
        Write-Host "Sleeping"
        Start-Sleep -Seconds 60
    }

    if ($Debug -eq $true -and $ServiceCount -eq 0)
    {
        Write-Host "No departures for route $routes found"
        break
    }
}
while ($index -gt 0)