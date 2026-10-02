# Format the latest trace file for the given identifier with TKPROF
#   .\scripts\tkprof.ps1 week00
param([Parameter(Mandatory = $true)][string]$Id)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
docker exec sqlp-oracle bash /workspace/scripts/container/tkprof-inner.sh $Id
