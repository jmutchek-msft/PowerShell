$csvFiles = Get-ChildItem -Path . -Filter *.csv
$combined = foreach ($csv in $csvFiles) { Import-CSV $csv.FullName | add-member -PassThru -NotePropertyName Workload -NotePropertyValue $csv.BaseName }
$combined | Export-csv -Path .\combined.csv -NoTypeInformation