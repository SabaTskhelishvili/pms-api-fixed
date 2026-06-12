Add-Type -AssemblyName System.IO.Compression

$resultsPath = "C:\Users\Saba\pms-api-practice\scripts\api_results.json"
$outputPath  = "C:\Users\Saba\pms-api-practice\docs\test_documentation.xlsx"
$results = Get-Content -Raw -LiteralPath $resultsPath | ConvertFrom-Json

$sharedStrings = New-Object System.Collections.Generic.List[string]
$ssIndex = @{}

function Track([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { $s = "" }
    if (-not $ssIndex.ContainsKey($s)) { $ssIndex[$s] = $sharedStrings.Count; $sharedStrings.Add($s) }
    return $ssIndex[$s]
}

function AddFile([System.IO.Compression.ZipArchive]$zip, [string]$name, [string]$content) {
    $e = $zip.CreateEntry($name)
    $w = New-Object System.IO.StreamWriter($e.Open())
    $w.Write($content)
    $w.Close()
}

function MakeSheet($headers, $data, $widths) {
    $colDef = ""
    for ($i = 0; $i -lt $widths.Count; $i++) {
        $colDef += "<col min=""$($i+1)"" max=""$($i+1)"" width=""$($widths[$i])"" customWidth=""1""/>"
    }

    $xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    $xml += '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    $xml += "<cols>$colDef</cols>"
    $xml += '<sheetData>'

    $allRows = @($headers) + $data
    for ($r = 0; $r -lt $allRows.Count; $r++) {
        $rowNum = $r + 1
        $isHeader = ($r -eq 0)
        $style = 0
        if ($isHeader) { $style = 1 }
        $xml += "<row r=""$rowNum"">"
        $cells = $allRows[$r]
        for ($c = 0; $c -lt $cells.Count; $c++) {
            $col = [char](65 + $c)
            $val = $cells[$c]
            if ($val -eq $null) { $val = "" }
            $strVal = "$val"
            $sIdx = Track $strVal
            $xml += "<c r=""$col$rowNum"" s=""$style"" t=""s""><v>$sIdx</v></c>"
        }
        $xml += '</row>'
    }

    $xml += '</sheetData></worksheet>'
    return $xml
}

$mem = New-Object System.IO.MemoryStream
$zip = [System.IO.Compression.ZipArchive]::new($mem, [System.IO.Compression.ZipArchiveMode]::Create)

$ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/></Types>'
AddFile $zip "[Content_Types].xml" $ct

$rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>'
AddFile $zip "_rels/.rels" $rels

$wbRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/></Relationships>'
AddFile $zip "xl/_rels/workbook.xml.rels" $wbRels

$wb = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Test Outlines" sheetId="1" r:id="rId3"/><sheet name="Request Catalog" sheetId="2" r:id="rId4"/></sheets></workbook>'
AddFile $zip "xl/workbook.xml" $wb

$styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0"/></cellXfs></styleSheet>'
AddFile $zip "xl/styles.xml" $styles

# ---- Sheet 1: Test Outlines ----
$s1h = @("Req #", "Endpoint", "Method", "Description", "Test Cases / Expected Results")
$s1d = @(
    @("1", "/auth/login", "POST", "Authenticate user and receive JWT token", "Status 200, response has `token` field, response time <2s, Content-Type application/json"),
    @("2", "/accounts", "POST", "Create a new insurance account", "Status 201, response has `data.id` field, response has `data.first_name` field, response time <2s"),
    @("3", "/policies", "POST", "Create a new policy linked to account", "Status 201, response has `data.id`, `data.policy_number`, `data.status` fields, response time <2s"),
    @("4", "/policies", "GET", "Retrieve all policies (list)", "Status 200, response has `data` array, `meta.total_count` exists, response time <2s"),
    @("5", "/policies/:id", "GET", "Retrieve a single policy by ID", "Status 200, response has `data.id` matching requested ID, `data.status` field, response time <2s"),
    @("6", "/policies/:id", "PATCH", "Fully update a policy (all fields)", "Status 200, updated fields reflect new values, `data.insurance_type` changed, response time <2s"),
    @("7", "/policies/:id", "PATCH", "Partially update a policy (single field)", "Status 200, only changed field is updated, `data.status` changed to `cancelled`, response time <2s"),
    @("8", "/policies/:policy_id/endorsements", "POST", "Create an endorsement on a policy", "Status 201, response has `data.id`, `data.endorsement_type` field, response time <2s"),
    @("9", "/policies/:policy_id/endorsements", "GET", "Retrieve all endorsements for a policy", "Status 200, response has `data` array, each endorsement has `id` field, response time <2s"),
    @("10", "/policies/:id", "DELETE", "Delete a policy", "Status 204, no response body, response time <2s"),
    @("11", "/accounts/:id", "DELETE", "Delete an account", "Status 204, no response body, response time <2s")
)
$s1widths = @(8, 30, 10, 50, 60)
$s1xml = MakeSheet $s1h $s1d $s1widths
AddFile $zip "xl/worksheets/sheet1.xml" $s1xml

# ---- Sheet 2: Request Catalog ----
$s2h = @("Req #", "Request Name", "Method", "Endpoint", "Status Code", "Response Body (Preview)", "cURL Command")
$s2d = @()
foreach ($r in $results) {
    $body = "$($r.ResponseBody)"
    if ($body.Length -gt 150) { $body = $body.Substring(0,150) + "..." }
    $curl = "$($r.CurlCmd)"
    if ($curl.Length -gt 200) { $curl = $curl.Substring(0,200) + "..." }
    $s2d += @(, @("", "$($r.RequestName)", "$($r.Method)", "$($r.Url)", "$($r.StatusCode)", $body, $curl))
}
$s2widths = @(8, 22, 8, 35, 12, 70, 80)
$s2xml = MakeSheet $s2h $s2d $s2widths
AddFile $zip "xl/worksheets/sheet2.xml" $s2xml

# Shared strings
$ssXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="' + $sharedStrings.Count + '" uniqueCount="' + $sharedStrings.Count + '">'
foreach ($s in $sharedStrings) {
    $esc = [System.Security.SecurityElement]::Escape($s)
    $ssXml += "<si><t>$esc</t></si>"
}
$ssXml += '</sst>'
AddFile $zip "xl/sharedStrings.xml" $ssXml

$zip.Dispose()

[System.IO.File]::WriteAllBytes($outputPath, $mem.ToArray())
$mem.Dispose()

Write-Host "Excel created: $outputPath"
Write-Host "  Sheet 1: Test Outlines ($($s1d.Count) data rows)"
Write-Host "  Sheet 2: Request Catalog ($($results.Count) entries)"
