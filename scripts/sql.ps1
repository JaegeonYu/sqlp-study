# Interactive SQL*Plus session as STUDY (working directory = repository root)
#   .\scripts\sql.ps1
#   SQL> @weeks/week00-setup/02_lab.sql
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
docker exec -it -w /workspace sqlp-oracle sqlplus -L "study/study@//localhost:1521/FREEPDB1"
