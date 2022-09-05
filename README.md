# Commands 
The alerting framework consists of the following commands:
**SNDALT** - Send an alert
**SNDALTDTL** - Send alert details
**DSPALT** - Display alert details

# Files
**FMPALTCFG** - Alert configuration details - what should happen as a result of the SNDALT command
**FMPALTDTL** - Alert details - records written by the SNDALTDTL command
**FMPALTLOG** - Alert log - a record of the actions taken as a result of the SNDALT command

# Notes
## Event Timestamp
This is a timestamp that *should* represent the time of the singular event. It is used to tie
up multiple records, namely the alert log and alert detail records, to a single event.

## The hash
This is a derived value. It is not stored anywhere. The hash is the first 8 digits of an MD5 hash
of the event timestamp, event, and item. As such it will be a unique identifier of these attributes
and therefore of a single event.