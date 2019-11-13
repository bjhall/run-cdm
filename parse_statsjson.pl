#!/usr/bin/perl -w
use strict;
use JSON;
use Data::Dumper;
use Getopt::Long;

my( $samplesheet, $table );
GetOptions ("samplesheet=s" => \$samplesheet,
	    "table"  => \$table);

# Read Stats.json    
my $stat = read_json($ARGV[0]);

# Read samplesheet.csv
my %sheet;
if( $samplesheet ) {
    %sheet = read_samplesheet($samplesheet);
}

my %data;

# Save some basic info
$data{Flowcell} = $stat->{Flowcell};
$data{RunNumber} = $stat->{RunNumber};
$data{RunId} = $stat->{RunId};

my %sample;
foreach my $lane ( @{ $stat->{"ConversionResults"} } ) {

    # Sum up total number of clusters of flowcell
    $data{TotalClustersRaw} += $lane->{TotalClustersRaw};
    $data{TotalClustersPF} += $lane->{TotalClustersPF};
    $data{Yield} += $lane->{Yield};
    
    foreach my $sample ( @{ $lane->{DemuxResults} } ) {
	my $id = $sample->{SampleName};

	if( $sheet{$id} ) {
	    if( $sheet{$id}->{ASSAY} eq "myeloid" and $sheet{$id}->{ID} =~ /^N/ ) {
		$sheet{$id}->{ASSAY} = "myeloid-nextera";
	    }
	    $sample{$sheet{$id}->{ASSAY}}->{$sheet{$id}->{ID}}->{nreads} += $sample->{NumberReads}."\n";
	}
	else {
	    $sample{unknown_assay}->{$id}->{nreads} += $sample->{NumberReads}."\n";
	}
    }
}

$data{samples} = \%sample;    

if( $table ) {
    foreach my $assay ( keys %{ $data{samples} } ) {
	foreach my $sid ( keys %{ $data{samples}->{$assay} } ) {
	    my $s = $data{samples}->{$assay}->{$sid};
	    print $sid."\t".$assay."\t".($s->{nreads} or 0)."\n";
	}
    }    
}
else {
    # FIXME: print json
    print encode_json(\%data);
}


sub read_samplesheet {
    my $fn = shift;

    open( my $cvs, $fn );

    my $data = 0;
    while( <$cvs> !~ /^\[Data\]/ ) { }

    my $head_str = <$cvs>;
    chomp $head_str;
    $head_str =~ s/\r//g;
    my @head = split /,/, $head_str;

    my %data;
    my $i = 0;
    while( <$cvs> ) {
	chomp;
	$_ =~ s/\r//g;
	next if /^\s*$/; # Skip empty lines
	my @d = split /,/;
	for my $i ( 1..$#d ) {
	    $data{ $d[0] }->{ $head[$i] } = $d[$i];
	}
	if( $data{$d[0]}->{Description} ) {
	    my @a = split /_/, $data{$d[0]}->{Description};
	
	    $data{ $d[0] }->{ID} = $a[1];
	    $data{ $d[0] }->{ASSAY} = $a[0];
	    $data{ $d[0] }->{ORDER} = $i;
	} else {
	    $data{ $d[0] }->{ID} = $d[0];
	    $data{ $d[0] }->{ASSAY} = 'unknown';
	}
	    
	$i++;
    }
    return %data;
}



sub read_json {
    my $fn = shift;
    
    open( JSON, $fn );
    my @json = <JSON>;
    my $decoded = decode_json( join("", @json ) );
    close JSON;
    
    return $decoded;
}

