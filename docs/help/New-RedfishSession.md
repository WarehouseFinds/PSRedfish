---
document type: cmdlet
external help file: PSRedfish-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSRedfish
ms.date: 01/30/2026
PlatyPS schema version: 2024-05-01
title: New-RedfishSession
---

# New-RedfishSession

## SYNOPSIS

Creates a new Redfish session to a DMTF Redfish® API endpoint with enhanced performance.

## SYNTAX

### __AllParameterSets

```
New-RedfishSession [-BaseUri] <string> [-Credential] <pscredential> [-AuthMethod <string>]
 [-SkipCertificateCheck] [-TimeoutSeconds <int>] [-MaxConnectionsPerServer <int>]
 [-ConnectionLifetimeMinutes <int>] [-EnableMetrics] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Establishes an authenticated session to a Redfish API endpoint using either Basic authentication
or Redfish session-based authentication.
Session-based authentication is more secure and recommended.
Returns a session object that can be used with other Redfish cmdlets.
Uses optimized .NET HttpClient with connection pooling for high performance.

## EXAMPLES

### EXAMPLE 1

$cred = Get-Credential
$session = New-RedfishSession -BaseUri 'https://redfish.example.com' -Credential $cred
Creates a new Redfish session using session-based authentication (default).

### EXAMPLE 2

$session = New-RedfishSession -BaseUri 'https://redfish.example.com' -Credential $cred -EnableMetrics
$session.Metrics.GetStatistics()
Creates a session with performance metrics enabled.

### EXAMPLE 3

$session = New-RedfishSession -BaseUri 'https://192.168.1.100' -Credential $cred -SkipCertificateCheck -MaxConnectionsPerServer 20
Creates a high-performance session with 20 concurrent connections allowed.

## PARAMETERS

### -AuthMethod

Authentication method to use.
Valid values are 'Session' (default) and 'Basic'.
Session authentication creates a Redfish session and uses X-Auth-Token.
Basic authentication uses HTTP Basic Auth for each request.

```yaml
Type: System.String
DefaultValue: Session
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

### -BaseUri

The base URI of the Redfish API endpoint (e.g., https://redfish.example.com).

```yaml
Type: System.String
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

### -ConnectionLifetimeMinutes

How long to keep connections alive in the pool.
Default is 5 minutes.
Helps with load balancer scenarios.

```yaml
Type: System.Int32
DefaultValue: 5
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

### -Credential

PSCredential object containing the username and password for authentication.

```yaml
Type: System.Management.Automation.PSCredential
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -EnableMetrics

Enable collection of performance metrics for this session.
Access metrics via $session.Metrics.GetStatistics()

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

### -MaxConnectionsPerServer

Maximum number of concurrent connections to the server.
Default is 10.
Increase for high-throughput scenarios.

```yaml
Type: System.Int32
DefaultValue: 10
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

### -SkipCertificateCheck

If specified, skips SSL certificate validation.
Use with caution in production environments.

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

### -TimeoutSeconds

The timeout in seconds for HTTP requests.
Default is 30 seconds.

```yaml
Type: System.Int32
DefaultValue: 30
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

## OUTPUTS

### RedfishSession object representing the Redfish session with HttpClient and session details.

{{ Fill in the Description }}

### RedfishSession

{{ Fill in the Description }}

## NOTES

The session object contains an HttpClient instance that should be disposed when no longer needed.
Use Remove-RedfishSession to properly clean up the session.
Connection pooling is automatically enabled for better performance.


## RELATED LINKS

{{ Fill in the related links here }}

