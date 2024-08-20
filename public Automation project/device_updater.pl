#!/path/to/perl

use v5.14;
use lib '.';
use Objects;
use Containers;
use IDAS;
use Data::Dumper qw(Dumper);
 
my $dc = Device_Container->new();
my $ac = Address_Container->new();
my $IDAS = IDAS->new();

open(LINKED, ">", "linked.txt");
open(FAILED, ">", "failed.txt");

########START NNR RETRIEVAL###############

my $key = "Name";
my $pattern = "vic";
# $key decides which entry to filter based on
# $pattern devices which string must be present
$dc->initialize_nnr($key, $pattern);

$key = "City";
$pattern = "VICTORIA";
# $key decides which entry to filter based on
# $pattern devices which string must be present  
$ac->initialize_nnr($key, $pattern);                                         

#########END NNR RETRIEVAL##########

########START STARLINK RETRIEVAL#############

$ac->initialize_starlink();

$dc->initialize_starlink();

########END STARLINK RETRIEVAL############

###########START POLISHING###########

$dc->get_location_codes($ac);

############END POLISHING############

###########PRINTING##############
# $dc->test();
# $ac->test_address();
# $ac->test_postal();
# $ac->test2();
# $dc->print();
# $ac->print();

close(LINKED);
close(FAILED);

my ($linked_device,$failed_device) = $dc->return_results();
# my ($linked_address,$linked_postal,$failed_address,$failed_postal) = $ac->return_results();
my $noniks = $dc->return_noniks();

my @linked_device_strings;
my $i = 0;
for my $entry (@$linked_device){
   $i++;
   $entry->emailify();
   push(@linked_device_strings, $entry->to_csv($i));
}
unshift @linked_device_strings,"Number,Nickname,Service Line Number,Address Reference Id,Location Code";
my $linked_device_summary = IDAS->csv2html(\@linked_device_strings);

my @failed_device_strings;
$i = 0;
for my $entry (@$failed_device){
   $i++;
   $entry->emailify();
   push(@failed_device_strings, $entry->to_csv($i));
}
unshift @failed_device_strings,"Number,Nickname,Service Line Number,Address Reference Id,Location Code";
my $failed_device_summary = IDAS->csv2html(\@failed_device_strings);

my @nonik_strings;
$i = 0;
for my $entry (@$noniks){
   $i++;
   $entry->emailify();
   push(@nonik_strings, $entry->nonik_to_csv($i));
}
unshift @nonik_strings,"Number,Service Line Number";
my $nonik_summary = IDAS->csv2html(\@nonik_strings);

# my @linked_address_strings;
# $i = 0;
# for my $entry (@$linked_address){
#    $i++;
#    $entry->emailify();
#    push(@linked_address_strings, $entry->to_csv($i));
# }
# unshift @linked_address_strings,"Number,Street Address,Postal Code,Location Code,Address Reference Id,Geo Lat Lng";
# my $linked_address_summary = IDAS->csv2html(\@linked_address_strings);

# my @failed_address_strings;
# $i = 0;
# for my $entry (@$failed_address){
#    $i++;
#    $entry->emailify();
#    push(@failed_address_strings, $entry->to_csv($i));
# }
# unshift @failed_address_strings,"Number,Street Address,Postal Code,Location Code,Address Reference Id,Geo Lat Lng";
# my $failed_address_summary = IDAS->csv2html(\@failed_address_strings);

# my @linked_postal_strings;
# $i = 0;
# for my $entry (@$linked_postal){
#    $i++;
#    $entry->emailify();
#    push(@linked_postal_strings, $entry->to_csv($i));
# }
# unshift @linked_postal_strings,"Number,Street Address,Postal Code,Location Code,Address Reference Id,Geo Lat Lng";
# my $linked_postal_summary = IDAS->csv2html(\@linked_postal_strings);

# my @failed_postal_strings;
# $i = 0;
# for my $entry (@$failed_postal){
#    $i++;
#    $entry->emailify();
#    push(@failed_postal_strings, $entry->to_csv($i));
# }
# unshift @failed_postal_strings,"Number,Street Address,Postal Code,Location Code,Address Reference Id,Geo Lat Lng";
# my $failed_postal_summary = IDAS->csv2html(\@failed_postal_strings);

$IDAS->sendMail(Subject => 'Address Summary'
               ,To => 'hijames986@gmail.com'
               ,From => 'James Hodson'
               ,Body => "Devices which successfully found location codes searching by Address Reference Id:"
                        ."<br><br>".$linked_device_summary."<br><br>"
                        ."Devices which failed to find location codes searching by Address Reference Id:"
                        ."<br><br>".$failed_device_summary."<br><br>"
                        ."Devices without nicknames:"
                        ."<br><br>".$nonik_summary."<br><br>"
                        # ."Addresses which successfully found location codes searching by postal code:"
                        # ."<br><br>".$linked_postal_summary."<br><br>"
                        # ."Addresses which failed to find location codes searching by postal code:"
                        # ."<br><br>".$failed_postal_summary."<br><br>"
                        # ."Addresses which successfully found location codes searching by street name and number:"
                        # ."<br><br>".$linked_address_summary."<br><br>"
                        # ."Addresses which failed to find location codes searching by street name and number:"
                        # ."<br><br>".$failed_address_summary."<br><br>"
               );
say "email sent.";
1;