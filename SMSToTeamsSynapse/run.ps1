using namespace System.Net
using namespace System.Web

param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

$body = $request.body
$message = $body.data.payload.text
$from = $body.data.payload.from.phone_number

$fromobj = @{
    type = "TextBlock"
    text = $from
}

$messageobj = @{
    type = "TextBlock"
    text = $message
}

$bodyContent = @(
    $fromObj
    $messageObj
)

$body =[pscustomobject][ordered]@{
    '$schema' = "http://adaptivecards.io/schemas/adaptive-card.json"
    type = "AdaptiveCard"
    version = "1.2"
    body = $bodyContent
}

$attachment = [pscustomobject][ordered]@{
    contentType = "application/vnd.microsoft.card.adaptive"
    contentUrl = $null
    content = $body
}

$jsonMessage = [pscustomobject][Ordered]@{
    type = "message"
    attachments = @($attachment)
}

$webhookJSON = ConvertTo-Json $jsonMessage -Depth 50
$teamsURL = "your teams webhook url"

try {
    Write-Host "Sending Teams Message"
    Invoke-RestMethod -Method post -Uri $teamsURL -Body $webhookJSON -ContentType "application/json"
    Write-Host "Teams Message Sent"
}
catch {
    Write-Warning "Error Sending Teams Message"
    $_.exception.message
}

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = "OK"
    })
