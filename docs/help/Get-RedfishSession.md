---
document type: cmdlet
external help file: PSRedfish-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSRedfish
ms.date: 01/27/2026
PlatyPS schema version: 2024-05-01
title: Get-RedfishSession
---

# Get-RedfishSession

## SYNOPSIS

Retrieves active Redfish sessions from the session cache.

## SYNTAX

### __AllParameterSets

```
Get-RedfishSession [[-BaseUri] <string>] [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Returns all active Redfish sessions that have been created in the current PowerShell session.
Sessions are cached when created by New-RedfishSession and can be retrieved for inspection
or to pass to other Redfish cmdlets.

## EXAMPLES

### EXAMPLE 1

Get-RedfishSession
Returns all active Redfish sessions.

### EXAMPLE 2

Get-RedfishSession -BaseUri 'https://redfish.example.com'
Returns only sessions connected to the specified endpoint.

### EXAMPLE 3

$sessions = Get-RedfishSession
$sessions | Remove-RedfishSession
Gets all sessions and removes them via the pipeline.

## PARAMETERS

### -BaseUri

Optional filter to return only sessions matching a specific BaseUri.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
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

## OUTPUTS

### PSCustomObject or array containing Redfish session objects.

{{ Fill in the Description }}

### System.Management.Automation.PSObject

{{ Fill in the Description }}

### System.Object

{{ Fill in the Description }}

## NOTES

Sessions remain in cache until explicitly removed with Remove-RedfishSession.
Each session contains an HttpClient that should be disposed when no longer needed.


## RELATED LINKS

{{ Fill in the related links here }}

