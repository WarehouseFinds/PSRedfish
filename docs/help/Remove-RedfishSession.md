---
document type: cmdlet
external help file: PSRedfish-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSRedfish
ms.date: 01/30/2026
PlatyPS schema version: 2024-05-01
title: Remove-RedfishSession
---

# Remove-RedfishSession

## SYNOPSIS

Removes a Redfish session and disposes of associated resources.

## SYNTAX

### __AllParameterSets

```
Remove-RedfishSession [-Session] <Object> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Properly disposes of a Redfish session by cleaning up the HttpClient and removing
the session from the session cache.
This ensures proper resource cleanup and
prevents memory leaks.

## EXAMPLES

### EXAMPLE 1

Remove-RedfishSession -Session $session
Removes the specified Redfish session and cleans up resources.

### EXAMPLE 2

$session | Remove-RedfishSession
Removes the Redfish session from the pipeline.

## PARAMETERS

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

### -Session

The Redfish session object to remove.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
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

### System.Object

{{ Fill in the Description }}

## OUTPUTS

## NOTES

Always call this function when done with a Redfish session to ensure proper cleanup.
Disposing the HttpClient will close any open connections.


## RELATED LINKS

{{ Fill in the related links here }}

