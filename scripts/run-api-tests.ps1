param(
    [string]$BaseUrl = "https://pms.srv1505121.hstgr.cloud/api/v1",
    [string]$Email = "tskh@gmail.com",
    [string]$Password = "Gangsta56"
)

$script:results = @()

function Add-Result {
    param($Name, $Method, $Url, $StatusCode, $ResponseBody, $CurlCmd)
    $script:results += [PSCustomObject]@{
        RequestName  = $Name
        Method       = $Method
        Url          = $Url
        StatusCode   = $StatusCode
        ResponseBody = $ResponseBody
        CurlCmd      = $CurlCmd
    }
}

function Build-Curl {
    param($Method, $Url, $Headers, $Body)
    $curl = "curl --location --request $Method '$Url'"
    foreach ($h in $Headers) {
        $curl += "`n  --header '$($h.Key): $($h.Value)'"
    }
    if ($Body) {
        $bodyEscaped = $Body -replace "'", "'\''"
        $curl += "`n  --data-raw '$bodyEscaped'"
    }
    return $curl
}

function Invoke-Api {
    param($Method, $Uri, $Body, $ContentType, $Headers)
    $params = @{
        Uri = $Uri
        Method = $Method
        Headers = $Headers
        UseBasicParsing = $true
    }
    if ($Body) { $params.Body = $Body; $params.ContentType = $ContentType }
    try {
        $response = Invoke-WebRequest @params
        $sc = [int]$response.StatusCode
        try { $bodyText = $response.Content } catch { $bodyText = "(empty)" }
        return @{ StatusCode = $sc; Content = $bodyText }
    }
    catch {
        $sc = [int]$_.Exception.Response.StatusCode
        try { $bodyText = $_.ErrorDetails.Message } catch { $bodyText = $_.Exception.Message }
        return @{ StatusCode = $sc; Content = $bodyText; Error = $_.Exception.Message }
    }
}

$authToken = $null
$accountId = $null
$policyId = $null
$endorsementId = $null

# ----- 1. LOGIN -----
Write-Host "1. LOGIN POST /auth/login ... " -NoNewline
$body = "{`"email`":`"$Email`",`"password`":`"$Password`"}"
$r = Invoke-Api -Method Post -Uri "$BaseUrl/auth/login" -Body $body -ContentType "application/json"
if ($r.StatusCode -eq 200) {
    $respObj = $r.Content | ConvertFrom-Json
    $authToken = $respObj.token
    $curl = Build-Curl -Method POST -Url "$BaseUrl/auth/login" -Headers @(@{Key="Content-Type";Value="application/json"}) -Body $body
    Add-Result -Name "Login" -Method "POST" -Url "/auth/login" -StatusCode $r.StatusCode -ResponseBody $r.Content -CurlCmd $curl
    Write-Host "200 OK" -ForegroundColor Green
} else {
    Write-Host "$($r.StatusCode) FAILED: $($r.Error)" -ForegroundColor Red
    exit 1
}

$authHeaders = @{ Authorization = "Bearer $authToken" }

# ----- 2. CREATE ACCOUNT -----
Write-Host "2. CREATE ACCOUNT POST /accounts ... " -NoNewline
$acctBody = "{`"account`":{`"first_name`":`"Alice`",`"last_name`":`"Smith`",`"email`":`"alice.$(Get-Random)@example.com`",`"phone`":`"555-0100`",`"address`":{`"address_line1`":`"123 Main St`",`"city`":`"Austin`",`"state`":`"TX`",`"zip_code`":`"78701`"}}}"
$r = Invoke-Api -Method Post -Uri "$BaseUrl/accounts" -Body $acctBody -ContentType "application/json" -Headers $authHeaders
if ($r.StatusCode -eq 201) {
    $respObj = $r.Content | ConvertFrom-Json
    $accountId = $respObj.data.id
    $curl = Build-Curl -Method POST -Url "$BaseUrl/accounts" -Headers @(@{Key="Content-Type";Value="application/json"};@{Key="Authorization";Value="Bearer {{auth_token}}"}) -Body $acctBody
    Add-Result -Name "Create Account" -Method "POST" -Url "/accounts" -StatusCode $r.StatusCode -ResponseBody $r.Content -CurlCmd $curl
    Write-Host "201 Created" -ForegroundColor Green
} else {
    Write-Host "$($r.StatusCode) FAILED: $($r.Error)" -ForegroundColor Red
    Add-Result -Name "Create Account" -Method "POST" -Url "/accounts" -StatusCode $r.StatusCode -ResponseBody $r.Error -CurlCmd ""
    exit 1
}

# ----- 3. CREATE POLICY -----
Write-Host "3. CREATE POLICY POST /policies ... " -NoNewline
$polBody = "{`"policy`":{`"account_id`":`"$accountId`",`"insurance_type`":`"general_liability`",`"status`":`"active`",`"premium`":120000,`"coverage`":100000000,`"effective_date`":`"2026-06-01`",`"expiration_date`":`"2027-06-01`"}}"
$r = Invoke-Api -Method Post -Uri "$BaseUrl/policies" -Body $polBody -ContentType "application/json" -Headers $authHeaders
if ($r.StatusCode -eq 201) {
    $respObj = $r.Content | ConvertFrom-Json
    $policyId = $respObj.data.id
    $curl = Build-Curl -Method POST -Url "$BaseUrl/policies" -Headers @(@{Key="Content-Type";Value="application/json"};@{Key="Authorization";Value="Bearer {{auth_token}}"}) -Body $polBody
    Add-Result -Name "Create Policy" -Method "POST" -Url "/policies" -StatusCode $r.StatusCode -ResponseBody $r.Content -CurlCmd $curl
    Write-Host "201 Created" -ForegroundColor Green
} else {
    Write-Host "$($r.StatusCode) FAILED: $($r.Error)" -ForegroundColor Red
    Add-Result -Name "Create Policy" -Method "POST" -Url "/policies" -StatusCode $r.StatusCode -ResponseBody $r.Error -CurlCmd ""
    exit 1
}

# ----- 4. GET ALL POLICIES -----
Write-Host "4. GET ALL POLICIES GET /policies ... " -NoNewline
$r = Invoke-Api -Method Get -Uri "$BaseUrl/policies" -Headers $authHeaders
if ($r.StatusCode -eq 200) {
    $curl = Build-Curl -Method GET -Url "$BaseUrl/policies" -Headers @(@{Key="Authorization";Value="Bearer {{auth_token}}"})
    Add-Result -Name "Get All Policies" -Method "GET" -Url "/policies" -StatusCode $r.StatusCode -ResponseBody $r.Content -CurlCmd $curl
    Write-Host "200 OK" -ForegroundColor Green
} else { Write-Host "$($r.StatusCode) FAILED" -ForegroundColor Red; Add-Result -Name "Get All Policies" -Method "GET" -Url "/policies" -StatusCode $r.StatusCode -ResponseBody $r.Error -CurlCmd "" }

# ----- 5. GET POLICY BY ID -----
Write-Host "5. GET POLICY BY ID GET /policies/$policyId ... " -NoNewline
$r = Invoke-Api -Method Get -Uri "$BaseUrl/policies/$policyId" -Headers $authHeaders
if ($r.StatusCode -eq 200) {
    $curl = Build-Curl -Method GET -Url "$BaseUrl/policies/{{created_policy_id}}" -Headers @(@{Key="Authorization";Value="Bearer {{auth_token}}"})
    Add-Result -Name "Get Policy by ID" -Method "GET" -Url "/policies/:id" -StatusCode $r.StatusCode -ResponseBody $r.Content -CurlCmd $curl
    Write-Host "200 OK" -ForegroundColor Green
} else { Write-Host "$($r.StatusCode) FAILED" -ForegroundColor Red; Add-Result -Name "Get Policy by ID" -Method "GET" -Url "/policies/:id" -StatusCode $r.StatusCode -ResponseBody $r.Error -CurlCmd "" }

# ----- 6. UPDATE POLICY (FULL) -----
Write-Host "6. UPDATE POLICY (FULL) PATCH /policies/$policyId ... " -NoNewline
$updBody = "{`"policy`":{`"insurance_type`":`"professional_liability`",`"status`":`"active`",`"premium`":150000,`"coverage`":200000000,`"effective_date`":`"2026-06-01`",`"expiration_date`":`"2027-06-01`"}}"
$r = Invoke-Api -Method Patch -Uri "$BaseUrl/policies/$policyId" -Body $updBody -ContentType "application/json" -Headers $authHeaders
if ($r.StatusCode -eq 200) {
    $curl = Build-Curl -Method PATCH -Url "$BaseUrl/policies/{{created_policy_id}}" -Headers @(@{Key="Content-Type";Value="application/json"};@{Key="Authorization";Value="Bearer {{auth_token}}"}) -Body $updBody
    Add-Result -Name "Update Policy (full)" -Method "PATCH" -Url "/policies/:id" -StatusCode $r.StatusCode -ResponseBody $r.Content -CurlCmd $curl
    Write-Host "200 OK" -ForegroundColor Green
} else { Write-Host "$($r.StatusCode) FAILED" -ForegroundColor Red; Add-Result -Name "Update Policy (full)" -Method "PATCH" -Url "/policies/:id" -StatusCode $r.StatusCode -ResponseBody $r.Error -CurlCmd "" }

# ----- 7. UPDATE POLICY (PARTIAL) -----
Write-Host "7. UPDATE POLICY (PARTIAL) PATCH /policies/$policyId ... " -NoNewline
$partBody = "{`"policy`":{`"status`":`"cancelled`"}}"
$r = Invoke-Api -Method Patch -Uri "$BaseUrl/policies/$policyId" -Body $partBody -ContentType "application/json" -Headers $authHeaders
if ($r.StatusCode -eq 200) {
    $curl = Build-Curl -Method PATCH -Url "$BaseUrl/policies/{{created_policy_id}}" -Headers @(@{Key="Content-Type";Value="application/json"};@{Key="Authorization";Value="Bearer {{auth_token}}"}) -Body $partBody
    Add-Result -Name "Update Policy (partial)" -Method "PATCH" -Url "/policies/:id" -StatusCode $r.StatusCode -ResponseBody $r.Content -CurlCmd $curl
    Write-Host "200 OK" -ForegroundColor Green
} else { Write-Host "$($r.StatusCode) FAILED" -ForegroundColor Red; Add-Result -Name "Update Policy (partial)" -Method "PATCH" -Url "/policies/:id" -StatusCode $r.StatusCode -ResponseBody $r.Error -CurlCmd "" }

# ----- 8. CREATE ENDORSEMENT -----
Write-Host "8. CREATE ENDORSEMENT POST /policies/$policyId/endorsements ... " -NoNewline
$endBody = "{`"endorsement`":{`"endorsement_type`":`"policy_change`",`"premium`":5000,`"description`":`"Added additional insured rider.`"}}"
$r = Invoke-Api -Method Post -Uri "$BaseUrl/policies/$policyId/endorsements" -Body $endBody -ContentType "application/json" -Headers $authHeaders
if ($r.StatusCode -eq 201) {
    $respObj = $r.Content | ConvertFrom-Json
    $endorsementId = $respObj.data.id
    $curl = Build-Curl -Method POST -Url "$BaseUrl/policies/{{created_policy_id}}/endorsements" -Headers @(@{Key="Content-Type";Value="application/json"};@{Key="Authorization";Value="Bearer {{auth_token}}"}) -Body $endBody
    Add-Result -Name "Create Endorsement" -Method "POST" -Url "/policies/:policy_id/endorsements" -StatusCode $r.StatusCode -ResponseBody $r.Content -CurlCmd $curl
    Write-Host "201 Created" -ForegroundColor Green
} else { Write-Host "$($r.StatusCode) FAILED: $($r.Error)" -ForegroundColor Red; Add-Result -Name "Create Endorsement" -Method "POST" -Url "/policies/:policy_id/endorsements" -StatusCode $r.StatusCode -ResponseBody $r.Error -CurlCmd "" }

# ----- 9. GET ALL ENDORSEMENTS -----
Write-Host "9. GET ALL ENDORSEMENTS GET /policies/$policyId/endorsements ... " -NoNewline
$r = Invoke-Api -Method Get -Uri "$BaseUrl/policies/$policyId/endorsements" -Headers $authHeaders
if ($r.StatusCode -eq 200) {
    $curl = Build-Curl -Method GET -Url "$BaseUrl/policies/{{created_policy_id}}/endorsements" -Headers @(@{Key="Authorization";Value="Bearer {{auth_token}}"})
    Add-Result -Name "Get All Endorsements" -Method "GET" -Url "/policies/:policy_id/endorsements" -StatusCode $r.StatusCode -ResponseBody $r.Content -CurlCmd $curl
    Write-Host "200 OK" -ForegroundColor Green
} else { Write-Host "$($r.StatusCode) FAILED: $($r.Error)" -ForegroundColor Red; Add-Result -Name "Get All Endorsements" -Method "GET" -Url "/policies/:policy_id/endorsements" -StatusCode $r.StatusCode -ResponseBody $r.Error -CurlCmd "" }

# ----- 10. DELETE ENDORSEMENT -----
$delEndUrl = if ($endorsementId) { "$BaseUrl/policies/$policyId/endorsements/$endorsementId" } else { "$BaseUrl/endorsements/dummy" }
Write-Host "10. DELETE ENDORSEMENT DELETE $delEndUrl ... " -NoNewline
$r = Invoke-Api -Method Delete -Uri $delEndUrl -Headers $authHeaders
if ($r.StatusCode -eq 204) {
    $curl = Build-Curl -Method DELETE -Url "$BaseUrl/policies/{{created_policy_id}}/endorsements/{{created_endorsement_id}}" -Headers @(@{Key="Authorization";Value="Bearer {{auth_token}}"})
    Add-Result -Name "Delete Endorsement" -Method "DELETE" -Url "/policies/:policy_id/endorsements/:id" -StatusCode $r.StatusCode -ResponseBody "(empty - 204 No Content)" -CurlCmd $curl
    Write-Host "204 No Content" -ForegroundColor Green
} else { Write-Host "$($r.StatusCode) FAILED: $($r.Error)" -ForegroundColor Red; Add-Result -Name "Delete Endorsement" -Method "DELETE" -Url "/policies/:policy_id/endorsements/:id" -StatusCode $r.StatusCode -ResponseBody $r.Error -CurlCmd "" }

# ----- 11. DELETE POLICY -----
Write-Host "11. DELETE POLICY DELETE /policies/$policyId ... " -NoNewline
$r = Invoke-Api -Method Delete -Uri "$BaseUrl/policies/$policyId" -Headers $authHeaders
if ($r.StatusCode -eq 204) {
    $curl = Build-Curl -Method DELETE -Url "$BaseUrl/policies/{{created_policy_id}}" -Headers @(@{Key="Authorization";Value="Bearer {{auth_token}}"})
    Add-Result -Name "Delete Policy" -Method "DELETE" -Url "/policies/:id" -StatusCode $r.StatusCode -ResponseBody "(empty - 204 No Content)" -CurlCmd $curl
    Write-Host "204 No Content" -ForegroundColor Green
} else { Write-Host "$($r.StatusCode) FAILED" -ForegroundColor Red; Add-Result -Name "Delete Policy" -Method "DELETE" -Url "/policies/:id" -StatusCode $r.StatusCode -ResponseBody $r.Error -CurlCmd "" }

# ----- 12. GET ALL ACCOUNTS -----
Write-Host "12. GET ALL ACCOUNTS GET /accounts ... " -NoNewline
$r = Invoke-Api -Method Get -Uri "$BaseUrl/accounts" -Headers $authHeaders
if ($r.StatusCode -eq 200) {
    $curl = Build-Curl -Method GET -Url "$BaseUrl/accounts" -Headers @(@{Key="Authorization";Value="Bearer {{auth_token}}"})
    Add-Result -Name "Get All Accounts" -Method "GET" -Url "/accounts" -StatusCode $r.StatusCode -ResponseBody $r.Content -CurlCmd $curl
    Write-Host "200 OK" -ForegroundColor Green
} else { Write-Host "$($r.StatusCode) FAILED" -ForegroundColor Red; Add-Result -Name "Get All Accounts" -Method "GET" -Url "/accounts" -StatusCode $r.StatusCode -ResponseBody $r.Error -CurlCmd "" }

# ----- 13. DELETE ACCOUNT -----
Write-Host "13. DELETE ACCOUNT DELETE /accounts/$accountId ... " -NoNewline
$r = Invoke-Api -Method Delete -Uri "$BaseUrl/accounts/$accountId" -Headers $authHeaders
if ($r.StatusCode -eq 204) {
    $curl = Build-Curl -Method DELETE -Url "$BaseUrl/accounts/{{created_account_id}}" -Headers @(@{Key="Authorization";Value="Bearer {{auth_token}}"})
    Add-Result -Name "Delete Account" -Method "DELETE" -Url "/accounts/:id" -StatusCode $r.StatusCode -ResponseBody "(empty - 204 No Content)" -CurlCmd $curl
    Write-Host "204 No Content" -ForegroundColor Green
} else { Write-Host "$($r.StatusCode) FAILED" -ForegroundColor Red; Add-Result -Name "Delete Account" -Method "DELETE" -Url "/accounts/:id" -StatusCode $r.StatusCode -ResponseBody $r.Error -CurlCmd "" }

# ----- EXPORT -----
$script:results | Export-Csv -LiteralPath "C:\Users\Saba\pms-api-practice\scripts\api_results.csv" -NoTypeInformation
$script:results | ConvertTo-Json -Depth 5 | Out-File -LiteralPath "C:\Users\Saba\pms-api-practice\scripts\api_results.json"

Write-Host ""
Write-Host "===== RESULTS ====="
$script:results | Format-Table RequestName, Method, StatusCode -AutoSize

Write-Host ""
Write-Host "Credentials:" -ForegroundColor Cyan
Write-Host "  Email: $Email"
Write-Host "  Password: $Password"
Write-Host "  Token: $($authToken.Substring(0, [Math]::Min(40, $authToken.Length)))..."
Write-Host "  Account ID: $accountId"
Write-Host "  Policy ID: $policyId"
Write-Host "  Endorsement ID: $endorsementId"
