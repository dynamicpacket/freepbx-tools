#!/usr/bin/perl

use strict;
use DBI;
use Digest::MD5 qw(md5 md5_hex md5_base64);
 
#################### SETTINGS ####################

my $monDir = '/var/spool/asterisk/monitor';
my $tmpDir = '/tmp/wav2gsm';
my $dbAstUser = 'root';
my $dbAstPass = '';
my $dbAstHost = 'localhost';
my $dbAstDB = 'asteriskcdrdb';
my $dbAstTable = 'cdr';
my $dbAstField = 'userfield';

my $maxFilesPerRun = 30000;

################## DO NOT TOUCH ##################



my @raw = qx|find $monDir -iname '*.wav'|;
chomp(@raw);
my $i = 0;

my $total = scalar(@raw);

foreach my $file(@raw)
{
	print "\r" if $i;
	my $pDone = 0;
	
	if($i)
	{
		$pDone = sprintf('%0.2f',(($i / $total)*100));
	}
	
	print qq?($pDone\% :: $i of $total) ...?;
	#print qq?$file\n?;
	wav2gsm($file);
	last if ++$i > $maxFilesPerRun;
}

fixMysqlCDRs();

print qq?\ndone!..\n?;

sub fixMysqlCDRs
{
	my $q = qq?update $dbAstTable set $dbAstField = replace($dbAstField,'.wav','.gsm') where $dbAstField like '%.wav';?;
	# connect to mysql and execute query
    my $dbh = DBI->connect("DBI:mysql:database=$dbAstDB;host=$dbAstHost;port=3306", $dbAstUser, $dbAstPass, 
    						{'RaiseError' => 1} )
    	|| die qq?Can't connect to mysql :( \n?;
    	
    $dbh->do($q);
    $dbh->disconnect();
}

sub replaceWavWithGsm
{
	my $origFile = shift;
	my $newFile = shift;
	unlink($origFile);
	$origFile =~ s/\.wav$/\.gsm/i;	
	system(qq?mv $newFile $origFile?);
}

sub wav2gsm
{	
	my $inFile = shift;
	
	if(!-d $tmpDir)
	{
		system(qq?mkdir -p $tmpDir?);
	}
	
	
	my $outFile = $tmpDir . '/' . md5_hex($inFile)  . '.' . time(). ".gsm";
	
	if(!-e $outFile)
	{
		system(qq?sox $inFile -r 8000 $outFile?);
	}
	
	my $oldSize = (-s $inFile);
	my $newSize = (-s $outFile);
		
	if(-e $outFile && $newSize)
	{
		my $perOfSize = (100 - int( 100*($newSize / $oldSize)) );

		print qq?.. compressed $perOfSize\%, old:$oldSize new:$newSize           ?;	
	
		replaceWavWithGsm($inFile,$outFile);
		return $newSize;
	}
	else
	{
		unlink($inFile);
		print qq?.. error reading file, bad wav, deleting           ?;	
	}
	
	return 0;	
}