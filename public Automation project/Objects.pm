#!/path/to/perl


package Device;
use v5.14;
use lib '.';
use Containers;
use Data::Dumper qw(Dumper);

sub new{
   my $class = shift;
   my $self = {
      "Name" => "undef",
      "Hardware Address" => "undef",
      "Serial No." => "undef",
      "OS" => "undef",
      "Description" => "undef",
      "Installed at" => "undef",
      "Comment" => "undef",
      "Port connections" => "undef",
      "Location Code" => "undef",
      "Address" => "undef",
      "Upstream Path" => "undef",
   };

   if (@_) {
      my $array_ref = shift @_;
      for my $hash ($array_ref){
         for my $key (keys %$hash){
            $self->{$key} = $hash->{$key};
         }
      }
   }

   bless($self, $class);
   return $self;
}

sub emailify {
    my ($self) = @_;

    # Check if {"Address"} and {"Nickname"} are defined
    if (defined $self->{"Address"}) {
        $self->{"Address"} =~ s/,/;/g;
    }
    if (defined $self->{"Nickname"}) {
        $self->{"Nickname"} =~ s/,/;/g;
    }
}


sub to_csv {
    my ($self, $count) = @_;
    my $string = "";

    # Check if each field is defined before concatenating it into $string
    $string .= defined $count ? "$count," : ",";
    $string .= defined $self->{"nickname"} ? "$self->{nickname}," : ",";
    $string .= defined $self->{"serviceLineNumber"} ? "$self->{serviceLineNumber}," : ",";
    $string .= defined $self->{"addressReferenceId"} ? "$self->{addressReferenceId}," : ",";
    $string .= defined $self->{"Location Code"} ? "$self->{'Location Code'}" : "";

    return $string;
}

sub nonik_to_csv{
   my ($self, $count) = @_;
   my $string = "";

   $string .= defined $count ? "$count," : ",";
   $string .= defined $self->{"serviceLineNumber"} ? "$self->{serviceLineNumber}," : ",";

   return $string;
}

sub print{
   my ($self) = @_;
   print Dumper $self;
}

package Address;
use v5.14;
use lib '.';
use Containers;
use Data::Dumper qw(Dumper);

sub new{
   my $class = shift;
   my $self = {
      "Location Code" => "undef",
      "Street Address" => "undef",
      "Street Number" => "undef",
      "Street Name" => "undef",
      "City" => "undef",
      "Postal Code" => "undef",
      "Geo Lat Lng" => "undef",
      "RNC Code" => "undef",
      "Comment" => "undef",
   };

   if (@_) {
      my $array_ref = shift @_;
      for my $hash ($array_ref){
         for my $key (keys %$hash){
            $self->{$key} = $hash->{$key};
         }
      }
   }

   bless($self, $class);
   return $self;
}

sub fill_instance_vars{
   my ($self) = @_;
   $self->{"Geo Lat Lng"} = ($self->{"latitude"}.",".$self->{"longitude"});            # Replace latitude longitude
   $self->{"Postal Code"} = $self->{"postalCode"} =~ s/\s//gr;                         # Delete space in postal code
   $self->{"City"} = uc($self->{locality});                                            # Set City
   $self->{"Street Address"} = uc($self->{"addressLines"}->[0]).", ".$self->{"City"};  # Assemble full Street Address
   $self->{"Street Number"} = ($self->{"Street Address"} =~ m/^(\d+)/) ? $1 : "None";  # Extract Street Number
   $self->{"Street Name"} = ($self->{"Street Address"} =~ m/^\d+ (.+?),/) ? $1 : "None";   # Extract Street Name
   $self->format_street_name();     



   delete @{$self}{"latitude","longitude","postalCode", "locality",                    # Delete uneccessary hash entries
                  "addressLines","region","regionCode","administrativeArea",
                  "administrativeAreaCode","formattedAddress"};
}

sub format_street_name{
   my ($self) = @_;
   $self->{"Street Name"} =~ s/STREET/ST/;
   $self->{"Street Name"} =~ s/ROAD/RD/;
   $self->{"Street Name"} =~ s/PLACE/PL/;
   $self->{"Street Name"} =~ s/AVENUE/AVE/;
   $self->{"Street Name"} =~ s/DRIVE/DR/;
   $self->{"Street Name"} =~ s/CRESCENT/CRES/;
   $self->{"Street Name"} =~ s/COURT/CT/;
   $self->{"Street Name"} =~ s/TERRACE/TERR/;
   $self->{"Street Name"} =~ s/LANE/LN/;

   $self->{"Street Name"} =~ s/NORTH$/N/;
   $self->{"Street Name"} =~ s/EAST$/E/;
   $self->{"Street Name"} =~ s/SOUTH$/S/;
   $self->{"Street Name"} =~ s/WEST$/W/;
   $self->{"Street Name"} =~ s/SOUTHEAST$/SE/;
   $self->{"Street Name"} =~ s/SOUTHWEST$/SW/;
}

sub emailify{
   my ($self) = @_;
   $self->{"Street Address"} =~ s/,/;/g;
   $self->{"Geo Lat Lng"} =~ s/,/;/g;
   $self->{"Postal Code"} =~ s/,/;/g;
}

sub to_csv{
   my ($self, $count) = @_;
   my $string = ($count.",".$self->{"Street Address"}.",".$self->{"Postal Code"}
   .",".$self->{"Location Code"}.",".$self->{"addressReferenceId"}.",".$self->{"Geo Lat Lng"});
   return $string;
}

sub print{
   my ($self) = @_;
   say $self->{"Street Name"};
}

1;