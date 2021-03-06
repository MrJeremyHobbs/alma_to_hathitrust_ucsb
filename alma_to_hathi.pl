#!/usr/bin/perl

# alma_to_hathi.pl Written by Margaret Briand Wolfe December 17, 2014 for BC Libraries. Modified 2020 for UCSB.

# Build files for Hathi Trust
# XML files are moved into the directory specified in path_xml by untar_hathi.pl
#
# Updated May 2016: For monograph and single-part monograph files print out a title line for each item. Parse the 901 tag for the barcode. For each barcode
# found increment the item count. If there is a description field then assume this item is part of a multi-part monograph. For the serials file print lines 
# at the bib level and not at the item level per Hathi Trust instructions.
#
use LWP::UserAgent;
use POSIX;
use XML::XPath;
use XML::XPath::XMLParser;
#use XML::Simple;
use Data::Dumper;

($my_day, $my_mon, $my_year) = (localtime) [3,4,5];
$pt_day = sprintf("%02d", $my_day);
#$pt_day = 22;
$my_year += 1900;
$my_mon += 1;
$my_date = sprintf("%s%02d%02d", $my_year, $my_mon, $my_day);


# <---------------- LOCAL CODE BEGINS HERE ---------------->
# clean-up
# system('del *.tsv');

# get current working directory
my $dir = getcwd;

# NOTE: you have to run this script twice, once for monos, once for serials.

#Monographs directory
$hathi_dir = "$dir/hathi_ser";
#Serials directory
#$hathi_dir = "$dir/hathi_ser";

# <---------------- LOCAL CODE ENDS HERE ---------------->

$out_mono = "ucsb_hathi_mono.tsv";
$out_multi = "ucsb_hathi_multi.tsv";
$out_ser = "ucsb_hathi_serials.tsv";
$out_log = "ucsb_hathi_log.tsv";

#Open files. If serials directory open serial file and log
#If not open file for monographs and multi-volume monographs 
#Open files in append mode: >>
$ret = $hathi_dir =~ /_ser/;
if ($ret)
{
     $ret = open(OUT_SER, ">>$out_ser");
     if ($ret < 1)
     {
          die ("Cannot open file $out_ser");
     }
     $serial_flg = 1;
}
else
{
     $serial_flg = 0;

     $ret = open(OUT_MONO, ">>$out_mono");
     if ($ret < 1)
     {
          die ("Cannot open file $out_mono");
     }

     $ret = open(OUT_MULTI, ">>$out_multi");
     if ($ret < 1)
     {
          die ("Cannot open file $out_multi");
     }
}


#Open log file to keep count of rejected records (either no OCLC # or no MMS ID
$ret = open(OUT_LOG, ">>$out_log");
if ($ret < 1)
{
     die ("Cannot open file $out_log");
}

$rec_out = $rec_rej = 0;

opendir(Dir, $hathi_dir) or die "cannot open directory $hathi_dir";
@xml_file = grep(/\.xml$/,readdir(Dir));

foreach $f (@xml_file)
{
   $file="$hathi_dir/$f";
   open (XML,$file) or die "could not open $file";

   #Open XPATH to data
    $xp = XML::XPath->new(filename=>$file);

    if ($xp)
    {
         $line_out = sprintf("%s%s", "Processing file: ", $file);
         print OUT_LOG ("$line_out\n");
    
         $nodeset = $xp->find('/collection/record');
         foreach my $node ($nodeset->get_nodelist) 
         {
              $mms_id = "";
              $i = $no_items = $lost = $missing = 0;
              undef @addl_tags;
              undef @addl_data;
              undef @addl_codes;
              undef @itm_cond;
              undef @itm_desc;

              #Grab all controlfields
              foreach my $ctlfld ($node->findnodes('./controlfield'))
              {
                   $ctl_data = $ctlfld->string_value;
                   $ctl_tag = $ctlfld->findvalue('./@tag'); 

                   #If tag is 001 grab MMS ID
                   if ($ctl_tag eq '001')
                   {
                       $mms_id = $ctl_data;
                   }
              }
              $i = $oclc_len = $issn_len = $desc_len = $gov_doc = 0;
              $oclc_no = $issn = $desc = "";

              #Grab all of the additional tags and corresponding data for this control field
              foreach my $datafld ($node->findnodes('./datafield'))
              {
			      $addl_tags[$i] = $datafld->findvalue('./@tag');
			      $addl_codes[$i] = $datafld->findvalue('./subfield/@code');
			      $addl_data[$i] = $datafld->findvalue('./subfield');

                   if ($addl_tags[$i] eq '901') #Grab necessary item info
                   {
				   $itm_cond[$no_items] = 'CH'; #Assume item is not lost or missing

                        if ($addl_codes[$i] =~ /y/) #item description
                        {
				        #Try to split the item description from the rest of the subfield data. Not really sure how to do this since there is no way of knowing what the
                             #item description contains but try to break on the barcode prefix (14 digits starting with 3, CVB, BC or B)
				        $found_barcode = 0;
                             $ret = $addl_data[$i] =~ /3[0-9]{13}/; #Look for a 14 digit barcode beginning with the number 3
                             if ($ret)
                             {
					     $ret = $addl_data[$i] =~ /3903/; #Look for the 3903 prefix. This is the most common BC barcode prefix.
                                  if ($ret)
                                  {
				                  @subdata = split(/3903/, $addl_data[$i]);
				                  $itm_desc[$no_items] = $subdata[0];
                                       $found_barcode++;
                                  }

                                  if (!$found_barcode)
                                  {
						 $ret = $addl_data[$i] =~ /3815/; #Prefix for some of the St. John's items
                                      if ($ret)
                                      {
				                      @subdata = split(/3815/, $addl_data[$i]);
				                      $itm_desc[$no_items] = $subdata[0];
                                           $found_barcode++;
                                      }
                                  }

                                  if (!$found_barcode)
                                  {
						 $ret = $addl_data[$i] =~ /3013/; #Prefix for some of the St. John's items
                                      if ($ret)
                                      {
				                      @subdata = split(/3013/, $addl_data[$i]);
				                      $itm_desc[$no_items] = $subdata[0];
                                           $found_barcode++;
                                      }
                                  }
                          
                                  if (!$found_barcode)
                                  {
                                       #If here then have a 14 digit barcode beginning with the number 3 but don't know the prefix. 
				                  $itm_desc[$no_items] = $addl_data[$i]; #Grab the whole string for description since can't parse out the barcode
                                       $found_barcode++;
                                  }
                             }

                             if (!$found_barcode)
                             {
                                  $ret = $addl_data[$i] =~ /CVB/;
                                  if ($ret)
                                  {
				                  @subdata = split(/CVB/, $addl_data[$i]);
				                  $itm_desc[$no_items] = $subdata[0];
                                       $found_barcode++;
                                  }
                             }

                             if (!$found_barcode)
                             {
                                  $ret = $addl_data[$i] =~ /BC[0-9]{5}/; #Look for BC barcode
                                  if ($ret)
                                  {
				                  @subdata = split(/BC/, $addl_data[$i]);
				                  $itm_desc[$no_items] = $subdata[0];
                                       $found_barcode++;
                                  }
                             }


                             if (!$found_barcode)
                             {
                                  $ret = $addl_data[$i] =~ /B[0-9]{6}/;
                                  if ($ret)
                                  {
				                  @subdata = split(/B/, $addl_data[$i])
;				                  $itm_desc[$no_items] = $subdata[0];
                                       $found_barcode++;
                                  }
                             }

                             #If here then havent' parsed out the barcode. Just send the whole string as the item description
                             if (!$found_barcode)
                             {
				             $itm_desc[$no_items] = $addl_data[$i];
                             }
                        }

                        if ($addl_codes[$i] =~ 'z') #process status
                        {
		                        $lost = $addl_data[$i] =~ /LOST/;
		                        $missing = $addl_data[$i] =~ /MISSING/;

                             if ($lost || $missing)
                             {
					     $itm_cond[$no_items] = 'LM'; #Set condition to Lost or Missing
                             }
                        }

                        #Don't really need to do anything if addl_code is a x - this is a barcode. It just contributes to the item count as do item desc & process status
                        $no_items++;
                   }

                   $i++;
	                 }

              #Loop through the tags and grab the OCLC number, ISSN's and check to see if government document
              for ($j = 0; $j < $i; $j++)
              {
                   #Get OCLC number
                   if ($addl_tags[$j] eq '035')
                   {
                        $ret = $addl_data[$j] =~ /OCoLC/;
                        if ($ret)
                        {
			                $oclc_no = $addl_data[$j];
                             $oclc_len = length($oclc_no);
                        }
                   }

                   #Is this a journal/issue/serials?
                   if ($addl_tags[$j] eq '022')
                   {
		                   $issn = $addl_data[$j];
                        $issn_len = length($issn);
                        if ($issn_len >= 9)
                        {
                             $no_issns = $issn_len / 9;

                             if ($no_issns >= 2) #More than 1 issn in the list?
                             {
				             for ($k = 0, $l = 0; $k < $no_issns; $k++)
                                  {
					          $issns[$k] = substr($issn, $l, 9);
                                       $l += 9;
                                  }

                                  $no_issns = @issns;

                                  for ($k = 0; $k < $no_issns; $k++)
                                  {
                                       if ($k == 0)
                                       {
					               $issn = $issns[$k];
                                       }
                                       else #Put a comma between each issn in the list
                                       {
						       $issn_len = length($issns[$k]);
                                            #Make sure issn has a length of 9 before using it
                                            if ($issn_len == 9)
                                            {
						            $issn = sprintf("%s%s%s", $issn, "\,", $issns[$k]);
                                            }
                                       }
                                  } 

                                  $issn_len = length($issn);
                             }
                        }
                   }

                   #Check for government document by presence of 074 tag
                   if ($addl_tags[$j] eq '074')
                   {
			           $gov_doc = 1;
                   }

              }

              if ($oclc_len && $mms_id) #Both are required fields. If either one is missing skip this entry.
              {
                   #If here have an MMS ID and OCLC # and no items then just have a bib and holding record in Alma. Still want to send it.
                   #This is always the case for serials since we only count them at the title level.
                   if (!$no_items)
                   {
                       $itm_cond[0] = 'CH';
                       $itm_desc[0] = "";
				  $no_items++;
                   }

                   #Print a record for each item
                   for ($k = 0; $k < $no_items; $k++)
                   {
                   
#Fields Hathi Trust is looking for (tab separated): 
#OCLC No, MMS ID, Holding Status (current holding, withdrawn, lost or missing), Condition, Enumeration (in our desc field), ISSN, Gov Doc #
#The only fields of the above that are required are OCLC # and MMS #/System #. We also provide enumeration since that's the only way I know if this is a multi-volume set and gov doc indicator.
#The rest is too complicated to send. Since it's not required we are not sending it. Maybe when Alma gets easier to pull the information out.
                        if ($serial_flg) #Journal/Issue/Serial
                        {
                             $line_out = sprintf("%s%s%s%s%s%s%s%s%s%s%s", $oclc_no, "\t", $mms_id, "\t", $itm_cond[$k], "\t", "\t", "\t", $issn, "\t", $gov_doc);
                             print OUT_SER ("$line_out\n");
                             $rec_out++;
                        }
                        elsif ($itm_desc[$k]) #multi-part monograph
                        {
                             $line_out = sprintf("%s%s%s%s%s%s%s%s%s%s%s", $oclc_no, "\t", $mms_id, "\t", $itm_cond[$k], "\t", "\t", $itm_desc[$k], "\t", "\t", $gov_doc);
                             print OUT_MULTI ("$line_out\n");
                             $rec_out++;
                        }
                        else #Single monograph
                        {
                             $line_out = sprintf("%s%s%s%s%s%s%s%s%s%s", $oclc_no, "\t", $mms_id, "\t", $itm_cond[$k], "\t", "\t", "\t", "\t", $gov_doc);
                             print OUT_MONO ("$line_out\n");
                             $rec_out++;
                        }
                   }
              }
              else #Record rejected
              {
                   $line_out = sprintf("%s%s%s%s%s%s%s%s%s", $oclc_no, "\t", $mms_id, "\t", "\t", "\t", "\t", "\t", $gov_doc);
                   print OUT_LOG ("$line_out\n");
			      $rec_rej++;
              }
         }
    }
}

$line_out = sprintf("%s%s%s%s", "Records output: ", $rec_out, "Records rejected: ", $rec_rej);
print OUT_LOG ("$line_out\n");

close (OUT_MONO);
close (OUT_MULTI);
close (OUT_SER);
close (OUT_LOG);

print("Done");

exit;
