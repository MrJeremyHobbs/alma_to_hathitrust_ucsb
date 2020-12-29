# Alma_to_HathiTrust (UCSB)
This script facilitates the yearly holdings submission process for UCSB and HathiTrust.

The script was originally written by Boston College and has been modified to fit our campus needs.

Original repo and documentation: https://developers.exlibrisgroup.com/blog/publishing-records-from-alma-to-hathi-trust-1/

# Files

### clean_up.bat
This file deletes all .tsv files in the script folder. Only run at the beginning of the process.

### untar.py
This script unzips the bib extract files from Alma and places them in the "tars" folder.

### alma_to_hathi.pl
This script takes raw marc data and turns it into .tsv files for submissions to HathiTrust.
The script has to be re-run for each folder of marc files.
Also, it has to be run separately for mono holdings and holdings files.