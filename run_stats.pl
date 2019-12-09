#!/usr/bin/env perl
use warnings;
use strict;
use JSON;
use Data::Dumper;
use File::Basename qw( dirname );
use File::Spec;
use Getopt::Long;
use MongoDB;
use MongoDB::BSON;
use MongoDB::OID;
use DateTime qw ( );


my $SCRIPT_ROOT = dirname($0);


my( $samplesheet, $statsjson, $table, $tocdm ) = ("SampleSheet.csv", "Data/Intensities/BaseCalls/Stats/Stats.json", 0, 0);
GetOptions ("samplesheet=s" => \$samplesheet,
	    "statsjson=s", => \$statsjson,
	    "table"  => \$table,
            "cdm"    => \$tocdm);
    
my $run_folder = File::Spec->rel2abs($ARGV[0]);
my $machine = (split /\//, $run_folder)[-2];


my $samplesheet_path;
unless( $samplesheet eq "NO" ) {
    $samplesheet_path = $run_folder."/".$samplesheet;
}

my $statsjson_path = $run_folder."/".$statsjson;

# Make sure files exist
die "No run folder called at $run_folder" if ! -d $run_folder;
die "SampleSheet does not exist at $samplesheet_path. Use --samplesheet NO if you don't have one..." if $samplesheet_path and ! -s $samplesheet_path;
die "Stats.json does not exist at $statsjson_path." if ! -s $statsjson_path;

# Get stats from Stats.json
my $statsjson_data = `$SCRIPT_ROOT/parse_statsjson.pl $statsjson_path --samplesheet $samplesheet_path`;
my $data = decode_json $statsjson_data;


# Add run folder and machine name
$data->{run_folder} = $run_folder;
$data->{machine} = $machine;

# Parse and add run date from run folder
my $run_date_str = "20".(split /_/, $data->{RunId})[0];
my ($y,$m,$d) = $run_date_str =~ /^([0-9]{4})([0-9]{2})([0-9]{2})\z/;
my $run_date = DateTime->new(year=>$y, month=>$m, day=>$d, time_zone=>'local');
if( $tocdm ) {
    $data->{run_date} = $run_date;
}

# Get additional data from RunParameters.xml
open(RUNPARAM, "$run_folder/RunParameters.xml");
while(<RUNPARAM>) {
    $data->{FlowcellType} = inner($_) if /<ClusterSupportedModes>/;
    $data->{FlowcellType} = inner($_) if /<Chemistry>/;
    $data->{ReadType} = inner($_) if /<ReadType>/;
    $data->{Side} = inner($_) if /<Side>/;

    $data->{R1Len} = inner($_) if /<Read1NumberOfCycles>/;
    $data->{R2Len} = inner($_) if /<Read2NumberOfCycles>/;
    $data->{I1Len} = inner($_) if /<IndexRead1NumberOfCycles>/;
    $data->{I2Len} = inner($_) if /<IndexRead2NumberOfCycles>/;

}

# Get cluster density from RunCompletionStatus.xml
if( -s "$run_folder/RunCompletionStatus.xml" ) {
    open(STATUS, "$run_folder/RunCompletionStatus.xml");
    while(<STATUS>) {
	$data->{ClusterDensity} = inner($_) if /<ClusterDensity>/;
    }
}
    

if( $tocdm ) {
    save_to_cdm($data);
}
else {
    print Dumper($data);
}



sub merge_with_db_data {
    my $new_data = shift;
    my $db_data = shift;
    
    for my $assay ( keys %{$db_data->{samples}} ) {
	for my $sid ( keys %{$db_data->{samples}->{$assay}} ) {
	    unless( defined $new_data->{samples}->{$assay}->{$sid} ) {
		
		$new_data->{samples}->{$assay}->{$sid} = $db_data->{samples}->{$assay}->{$sid}
	    }
	}
    }
}


sub save_to_cdm {
    my $data = shift;
    
    my $client = MongoDB->connect();
    my $RUNS = $client->ns("CMD.runs");

    # Check if run already exists and delete if it does
    my $results = $RUNS->find_one( {'run_folder'=>$data->{run_folder} } );
    if( $results and $results->{run_folder} eq $data->{run_folder} ) {
	$RUNS->delete_one( {'run_folder'=>$data->{run_folder}} );
#	print STDERR "MERGING";
	merge_with_db_data($data, $results);
    }
#    print Dumper($data);
    # Insert new data
    $RUNS->insert_one( $data );    
}


sub inner {
    my $s = shift;
    $s =~ />(.*?)</;
    return $1;
}

