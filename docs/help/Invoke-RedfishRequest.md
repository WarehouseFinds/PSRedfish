---
document type: cmdlet
external help file: PSRedfish-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSRedfish
ms.date: 01/30/2026
PlatyPS schema version: 2024-05-01
title: Invoke-RedfishRequest
---

# Invoke-RedfishRequest

## SYNOPSIS

Invokes a request against a Redfish API endpoint with retry logic and enhanced error handling.

## SYNTAX

### __AllParameterSets

```
Invoke-RedfishRequest [-Session] <psobject> [-Uri] <string> [-Method <string>] [-Body <Object>]
 [-ContentType <string>] [-TimeoutSeconds <int>] [-MaxRetries <int>] [-RetryDelayMilliseconds <int>]
 [-NoRetry] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Executes an HTTP request (GET, POST, PATCH, PUT, DELETE) against a Redfish API endpoint
using an established session.
Supports both relative and absolute URIs.
Includes automatic retry logic for transient failures and structured error objects.
Uses .NET HttpClient for optimal performance.

## EXAMPLES

### EXAMPLE 1

$systems = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems'
Gets the list of computer systems.

### EXAMPLE 2

$body = @{ AssetTag = 'SERVER-001' }
Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems/1' -Method PATCH -Body $body
Updates the AssetTag property of a system with automatic retry on transient failures.

### EXAMPLE 3

$result = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems/1' -NoRetry
Gets system information without retry logic.

## PARAMETERS

### -Body

The request body as a hashtable or PSCustomObject.
Will be converted to JSON.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- cf
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ContentType

The Content-Type header for the request.
Default is 'application/json'.

```yaml
Type: System.String
DefaultValue: application/json
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -MaxRetries

Maximum number of retry attempts for transient failures.
Default is 3.
Set to 0 to disable retries.

```yaml
Type: System.Int32
DefaultValue: 3
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Method

The HTTP method to use.
Default is GET.

```yaml
Type: System.String
DefaultValue: GET
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -NoRetry

Disable retry logic for this request.
Useful for operations that should fail fast.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -RetryDelayMilliseconds

Initial delay between retries in milliseconds.
Default is 1000 (1 second).
Delay increases exponentially with each retry.

```yaml
Type: System.Int32
DefaultValue: 1000
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Session

The Redfish session object created by New-RedfishSession.

```yaml
Type: System.Management.Automation.PSObject
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TimeoutSeconds

Override the session's default timeout for this specific request.

```yaml
Type: System.Int32
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Uri

The URI to request.
Can be relative (e.g., '/redfish/v1/Systems') or absolute.
If relative, it will be appended to the session's BaseUri.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases:
- '@odata.id'
- Path
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -WhatIf

Runs the command in a mode that only reports what would happen without performing the actions.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- wi
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

{{ Fill in the Description }}

## OUTPUTS

### PSCustomObject containing the response data from the Redfish API.

{{ Fill in the Description }}

### System.Management.Automation.PSObject

{{ Fill in the Description }}

## NOTES

For DELETE operations that return no content, returns $null.
Automatically retries on HTTP 408, 429, 503, 504 status codes.
Throws structured RedfishException objects for easier error handling.


## RELATED LINKS

{{ Fill in the related links here }}

