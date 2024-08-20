#!/path/to/perl

package Device_Container;
use v5.14;
use Data::Dumper qw(Dumper);
use NNRORA;
use JSON;
use Objects;
use StarlinkAPI;

sub new{
   my $class = shift;
   my $self = {
      "starlink" => [],
      "nonik" => [],
      "nnr" => [],
   };
   bless($self, $class);
   return $self;
}

sub initialize_starlink{
   my ($self, $ac) = @_;
   my $json = JSON->new();
   my $sl = StarlinkAPI->new();
   my $response;
   my @devices;

   for(my $i = 0;;$i++){                                        # extract all device information into @devices
      $response = $sl->get_service_lines($i);
      my $decode = $json->decode($response);
      push (@devices, @{$decode->{content}->{results}});       

      if($response =~ m/"isLastPage": "True"/){
         last;
      }
   }

   my @array;
   my @array2;
   for my $device (@devices){                                   # populate container object with device objects (with nicknames)
      if ($device->{nickname} ne "None" && $device->{nickname} ne ""){
         my $obj = Device->new($device);      
         push(@array, $obj);
      }
      else {
         my $obj = Device->new($device);
         push(@array2, $obj);
      }
   }
   $self->{starlink} = \@array;
   $self->{nonik} = \@array2;
}

sub initialize_nnr{
   my ($self, $key, $pattern) = @_;
   my $key = "Name";
   my $pattern = "chi";

   my @output = FetchORA(
      "NNR: Hardware",
      "Comment,Description,Hardware Address,Installed at,Location Code,Name,OS,Port connections,Serial No.,Upstream Path",
      qq~"$key" LIKE '%$pattern%'~
   );

   @output = $self->to_hash(@output);
   my @array;
   for my $device (@output){                            
      my $obj = Device->new($device);
      push(@array, $obj);
   }

   $self->{nnr} = \@array;
}

sub return_results{
   my ($self) = @_;
   my $total = 0;
   my $loc_code = 0;
   my (@linked_device,@failed_device);
   for my $entry (@{$self->{starlink}}){
      if (defined $entry->{"Location Code"}){
         if($entry->{"Location Code"} ne "None found" && $entry->{"Location Code"} ne "undef"){
            $loc_code++;
            push(@linked_device, $entry);
         }
         else{
            push(@failed_device, $entry);
         }
      }
      $total++;
   }
   
   return (\@linked_device,\@failed_device);
}

sub return_noniks{
   my ($self) = @_;
   my @array;
   for my $entry (@{$self->{nonik}}){
      push(@array, $entry);
   }
   return \@array;
}

sub to_hash {
    my ($self, @devices) = @_;
    my @keys = ("Comment", "Description", "Hardware Address",
                "Installed at", "Location Code", "Name",
                "Port connections", "Serial No.", "Upstream Path");
    my @completed_devices;
    for my $device (@devices) {
        my %hash;
        my $i = 0;
        for my $entry (@$device) {
            # Check if $entry is defined and if the index $i is within the bounds of @keys
            if (defined $entry && $i < @keys) {
                $hash{$keys[$i]} = $entry; 
            }
            $i++;
        }
        push(@completed_devices, \%hash);
    }
    return @completed_devices;
}

sub get_location_codes{
   my ($self, $address_container) = @_;
   for my $entry (@{$self->{starlink}}){
      ($entry->{"Location Code"},$entry->{"Address"}) = $address_container->search_ref_id($entry->{"addressReferenceId"});
      if($entry->{"nickname"} =~ m/(\D{3}\d{3}-\d{2})/){
         $entry->{"Location Code"} = $1;
      }
      if($entry->{"nickname"} =~ m/\D{5}\d-\d{2}/){
         $entry->{"Location Code"} = $1;
      }
   }
}

sub test{
   my ($self) = @_;
   my $total = 0;
   my $loc_code = 0;
   for my $entry (@{$self->{nonik}}){
      if($entry->{"nickname"} eq "None" || $entry->{"nickname"} eq "undef"){
         $loc_code++;
         print Dumper $entry;
      }
      $total++;
   }
   print "The number with codes is $loc_code\n";
   print "and the total number is $total.\n";
}

package Address_Container;
use v5.14;
use Data::Dumper qw(Dumper);
use NNRORA;
use JSON;
use Objects;
use StarlinkAPI;

sub new{
   my $class = shift;
   my $self = {
      "starlink" => [],
      "nnr" => [],
      "postal" => [],
   };
   bless($self, $class);
   return $self;
}

sub initialize_starlink{
   my ($self, @addresses) = @_;
   my $response;
   my @addresses;
   my $json = JSON->new();
   my $sl = StarlinkAPI->new();

   for(my $i = 0;;$i++){                                        # extract all device information into @addresses
      $response = $sl->get_addresses($i);
      $response =~ s/("metadata": ")(.*?)(")/$1undef$3/g;
      $response =~ s/Hudson"s Hope/Hudson's Hope/g;
      my $decode = $json->decode($response);
      push (@addresses, @{$decode->{content}->{results}});       

      if($response =~ m/"isLastPage": "True"/){
         last;
      }
   }                      

   my @array;
   my @array2;
   for my $address(@addresses){                                # populate container object with address objects
      my $obj = Address->new($address);
      my $obj2 = Address->new($address);
      $obj->fill_instance_vars();
      $obj2->fill_instance_vars();
      $self->get_location_code_by_street($obj);
      $self->get_location_code_by_postal($obj2);
      push(@array, $obj);
      push(@array2, $obj2);
   }
   $self->{starlink} = \@array;
   $self->{postal} = \@array2;
}

sub initialize_nnr{
   my ($self, $key, $pattern) = @_;

   my @output = FetchORA(
      "NNR: Location Codes",
      "City,Street Address,Street Name,Street Number,Postal Code,Geo Lat Lng,Location Code,Comment,RNC Code",
      #qq~"$key" LIKE '%$pattern%'~
   );
   @output = $self->to_hash(@output);

   my @array;
   for my $address (@output){                                
      my $obj = Address->new($address);
      push(@array, $obj);
   }

   $self->{nnr} =  \@array;
}

sub to_hash{
   my ($self, @addresses) = @_;
   my @keys = ("City","Street Address","Street Name",
               "Street Number","Postal Code","Geo Lat Lng",
               "Location Code","Comment","RNC Code");
   my @completed_addresses;
   for my $address (@addresses){
      my %hash;
      my $i = 0;
      for my $entry (@$address){
         $hash{$keys[$i]} = $entry; 
         $i++;
      }
      push(@completed_addresses, \%hash);
   }
   return @completed_addresses;
}

sub get_location_code_by_street{
    my ($self, $obj) = @_;

    # Check if $self->{nnr} is defined and an array reference
    return unless defined $self->{nnr} && ref($self->{nnr}) eq 'ARRAY';

    for my $entry (@{$self->{nnr}}) {
        # Check if $entry and $obj are defined and have the required keys
        next unless defined $entry && defined $obj &&
                    defined $entry->{"Street Number"} && defined $entry->{"Street Name"} &&
                    defined $obj->{"Street Number"} && defined $obj->{"Street Name"};

        if($entry->{"Street Number"} eq $obj->{"Street Number"} && 
           $entry->{"Street Name"} eq $obj->{"Street Name"})
        {
            $obj->{"Location Code"} = $entry->{"Location Code"} if defined $entry->{"Location Code"};
        }
    }
}

sub get_location_code_by_postal{
    my ($self, $obj) = @_;

    # Check if $self->{nnr} is defined and an array reference
    return unless defined $self->{nnr} && ref($self->{nnr}) eq 'ARRAY';

    for my $entry (@{$self->{nnr}}) {
        # Check if $entry and $obj are defined and have the required keys
        next unless defined $entry && defined $obj &&
                    defined $entry->{"Postal Code"} && defined $obj->{"Postal Code"};

        if($entry->{"Postal Code"} eq $obj->{"Postal Code"}) {
            $obj->{"Location Code"} = $entry->{"Location Code"} if defined $entry->{"Location Code"};
        }
    }
}

sub search_ref_id{
   my ($self, $ref_id) = @_;
   for my $entry (@{$self->{starlink}}){
      if($entry->{"addressReferenceId"} eq $ref_id){
         return $entry->{"Location Code"}, $entry->{"Street Address"};
      }
   }
   return "None found", "None Found";
}

sub return_results{
   my ($self) = @_;
   my $total = 0;
   my $loc_code = 0;
   my (@linked_address,@linked_postal,@failed_address,@failed_postal);
   for my $entry (@{$self->{starlink}}){
      if($entry->{"Location Code"} ne "None found" && $entry->{"Location Code"} ne "undef"){
         $loc_code++;
         push(@linked_address, $entry);
      }
      else{
         push(@failed_address, $entry);
      }
      $total++;
   }
   $total = 0;
   $loc_code = 0;
   for my $entry (@{$self->{postal}}){
      if($entry->{"Location Code"} ne "None found" && $entry->{"Location Code"} ne "undef"){
         $loc_code++;
         push(@linked_postal, $entry);
      }
      else{
         push(@failed_postal, $entry);
      }
      $total++;
   }
   return (\@linked_address,\@linked_postal,\@failed_address,\@failed_postal);
}

sub test_address{
   my ($self) = @_;
   my $total = 0;
   my $loc_code = 0;
   for my $entry (@{$self->{starlink}}){
      if($entry->{"Location Code"} ne "None found" && $entry->{"Location Code"} ne "undef"){
         $loc_code++;
         print Dumper $entry;
      }
      $total++;
   }
}

sub test_postal{
   my ($self) = @_;
   my $total = 0;
   my $loc_code = 0;
   for my $entry (@{$self->{postal}}){
      if($entry->{"Location Code"} ne "None found" && $entry->{"Location Code"} ne "undef"){
         $loc_code++;
      }
      $total++;
   }
}

1;











































# ######START OF DEVICES#########
# package Devices;
# sub new{
#    my $class = shift;
#    my $self = {
#       "devices" => [],
#    };
#    bless($self, $class);
#    return $self;
# }

# sub set_devices{
#    my ($self, @devices) = @_;
#    my @completed_devices;
#    for my $device (@devices){
#       if(!($device->{nickname} eq "None")){
#          push (@completed_devices, $device);
#       }
#    }
#    $self->{devices} = \@completed_devices;
# }

# sub dump_all{
#    my ($self) = @_;
#    print Data::Dumper::Dumper($self->{devices});
# }


# ########END OF DEVICES#############

# #######START OF NNR DEVICES##########
# package NNR_Devices;

# sub new{
#    my $class = shift;
#    my $self = {
#       "devices" => [],
#    };
#    bless($self, $class);
#    return $self;
# }

# sub set_devices{
#    my ($self, @devices) = @_;
#    my @keys = ("Comment","Description","Hardware Address",
#                "Installed at","Location Code","Name",
#                "Port connections","Serial No.","Upstream Path");
#    my @completed_devices;
#    for my $device (@devices){
#       my %hash;
#       my $i = 0;
#       for my $entry (@$device){
#          $hash{$keys[$i]} = $entry; 
#          $i++;
#       }
#       push(@completed_devices, \%hash);
#    }
#    $self->{devices} = \@completed_devices;
# }

# sub get_devices{
#    my ($self) = @_;
#    return $self->{devices};
# }

# sub dump_all{
#    my ($self) = @_;
#    print Data::Dumper::Dumper($self->{devices});
# }
# ###########END OF NNR DEVICES#############



# ############START OF ADDRESS##############
# package Address;

# sub new{
#    my $class = shift;
#    my $self = {
#       "addresses" => [],
#    };
#    bless($self, $class);
#    return $self;
# }

# sub set_addresses{
#    my ($self, @addresses) = @_;
#    $self->{addresses} = \@addresses;
# }

# sub dump_all{
#    my ($self) = @_;
#    print Data::Dumper::Dumper ($self->{addresses});
# }
# ################END OF ADDRESS###############

# ##########START OF NNR ADDRESS###############
# package NNR_Address;

# sub new{
#    my $class = shift;
#    my $self = {
#       "addresses" => [],
#    };
#    bless($self, $class);
#    return $self;
# }

# sub set_addresses{
#    my ($self, @addresses) = @_;
#    my @keys = ("City","Street Address","Street Name",
#                "Street Number","Postal Code","Geo Lat Lng",
#                "Location Code","Comment","RNC Code");
#    my @completed_addresses;
#    for my $address (@addresses){
#       my %hash;
#       my $i = 0;
#       for my $entry (@$address){
#          $hash{$keys[$i]} = $entry; 
#          $i++;
#       }
#       push(@completed_addresses, \%hash);
#    }
#    $self->{addresses} = \@completed_addresses;
# }

# sub get_addresses{
#    my ($self) = @_;
#    return ($self->{addresses});
# }

# sub dump_all{
#    my ($self) = @_;
#    print Data::Dumper::Dumper ($self->{addresses});
# }

1;