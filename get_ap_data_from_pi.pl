#!/usr/bin/env perl
#
# This file prints out the details of access points which contain
# the given name or string. Each access point entry is one XML block
#
# The following placeholders need to be updated before the script 
# can be run
# <PI_SERVER> - PI server name/address
# <USERNAME> - PI API username;
# <PASSWORD> - PI API password;
#
# 
#USAGE :
#    perl get_ap_data_from_pi.pl [OPTIONS]
#
#    Get data for access points from PI using the options provided
#
#OPTIIONS :
#    ---name_filter=KEY  : Filter APs based on name which contain KEY
#    --details           : Get detailed data for access points
#
#EXAMPLES :
#
#    * Get AP summarized data for all APs
#        perl get_ap_data_from_pi.pl
#
#    * Get AP summarized data for APs with 'sjc' in name
#        perl get_ap_data_from_pi.pl --name_filter=sjc
#
#    * Get detailed AP data for APs with 'sjc' in their name
#        perl get_ap_data_from_pi.pl --name_filter=sjc --details


use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;
use XML::Simple;
use Getopt::Long;

my $args = {};

eval
{
GetOptions('details' => \$args->{details},
           'name_filter=s' => \$args->{name_filter},
          ) or die ("ERROR in command line arguments\n");
};

if ($@)
{
    usage();
    exit(1);
}

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

#my $now = DateTime->now();

#my $timestamp = $now->strftime('%F %T UTC');

my $pi_server = "198.18.134.53";

my $username = "root";

my $password = "C1sco12345";

die "Please provide PI server name" unless ($pi_server);

die "Pleae provide username and password" unless ($username && $password);

my $api_endpoint = "AccessPoints";

$api_endpoint = "AccessPointDetails" if ($args->{details});

my $api_filter = undef;

$api_filter = "?name=contains($args->{name_filter})" if ($args->{name_filter});

&get_data_for_ap($api_endpoint, $api_filter);

sub get_data_for_ap
{
    my $api_endpoint = shift;
    my $api_filter = shift;

    my $ua = LWP::UserAgent->new();

    my $api_query = "https://$pi_server/webacs/api/v1/data/$api_endpoint";

    $api_query .= "$api_filter" if ($api_filter);

    my $http_request = HTTP::Request->new(GET => $api_query);
    
    $http_request->authorization_basic($username, $password);
    
    my $response = $ua->request($http_request);

    if ($response->is_success) {
        
        my $xml = XML::Simple->new();
    
        my $hashxml = $xml->XMLin($response->decoded_content); 
        
        my $count = $hashxml->{count};

        print "Found $count APs";
        print " matching name $args->{name_filter}" if ($api_filter);
        print "\n";

        for (my $i=0; $i<$count; $i+=100)
        {
        
            my $partial_content_uri = $api_query . (defined($api_filter) ? "&" : "?") . ".full=true&.firstResult=$i&.maxResults=100";

            $http_request->uri($partial_content_uri);
            
            my $part_content = $ua->request($http_request);
        
            if ($part_content->is_success)
            {
                my $content_text = $part_content->decoded_content();
                $content_text =~ s/\<(\/)?queryResponse([^<>])*\>//ig;
                $content_text =~ s/\<\??xml([^<>])*\>//;
                $content_text =~ s/\<entity/\<entity timestamp="$timestamp"/g;
    
                print $content_text;
            }
            else
            {
                #print Data::Dumper->Dump([$part_content],['PT']);

                my $part_response_code = $part_content->{'_rc'};
                open(FH, ">>pi_api_error_log");
                print FH "$timestamp => Got response code $part_response_code for URL below \n";
                print FH "$partial_content_uri\n\n";
                print "$timestamp => Got response code $part_response_code for URL below \n";
                print "$partial_content_uri\n\n";
                close(FH);
            }

        }
    }
    else
    {
        print Data::Dumper->Dump([$response],["RESPONSE ERROR"]);
    }
}

sub usage
{
    print qq[
USAGE :
    perl $0 [OPTIONS]

    Get data for access points from PI using the options provided

OPTIIONS :
    ---name_filter=KEY  : Filter APs based on name which contain KEY 
    --details           : Get detailed data for access points 

EXAMPLES :

    * Get AP summarized data for all APs
        perl $0
    
    * Get AP summarized data for APs with 'sjc' in name
        perl $0 --name_filter=sjc

    * Get detailed AP data for APs with 'sjc' in their name
        perl $0 --name_filter=sjc --details
    
    ]
}
