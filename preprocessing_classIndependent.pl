#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use Cwd;

###########################################
# A script that goes through the ALC corpus and extracts the text from the .hlb files. It will create
# one output file for .hlb file - having the same name - that contains the text as plain text. Additionally
# at the end dummy words for the irregularity featues will be appended (e.g. '#stutters#'). The files will be written 
# to a folder structure that is convenient to WEKA StringToWordVector class that can be used for BOW creation.
#
# Type of output: will create the raw data of the corpus as a whole - for the combined test.
#
############################################

#----------------------------------------------------------------
#	Variablen Deklarationen
#----------------------------------------------------------------

#ordnerstruktur durchlaufen und jeweilige Unterordner abspeichern
my @blocks;
my @sessions;
my @files;

#die orginalfilenames nachher wiederverwenden
my $originalFilenames = {};

#globalen Pfade des Systems
my $basePath 		 = "/home/bas-alc";
my $corpusBasePath 	 = $basePath . "/corpus";
my $outputPathAlc 	 = $basePath . "/test/rawDataMappingProblem/combined_all/alc/";
my $outputPathNonalc = $basePath . "/test/rawDataMappingProblem/combined_all/nonalc/";


main();

sub main{
	collectFiles();
	loopThroughFilesAndExtractText();
	
}


#----------------------------------------------------------------
#	Ordner durchlaufen, um Dateien zu sammeln
#----------------------------------------------------------------

sub collectFiles
{
	chdir($corpusBasePath);
	#leere das BlockArray und wechsle in das entsprechende Verzeichnis
	chdir("EMU/LAB") or die "path EMU/LAB not found!!!!!\n";
	@blocks = ();
	my $blockpath = `ls`;
	while($blockpath =~ m/BLOCK/){
		if($blockpath =~ s/(BLOCK\d+)//){
			push @blocks, $1;
		}
	}
	
	loopThroughBlocks();
	#wechsle zurück in den bas-alc ordner
	chdir('../../..') or die "cd back in dvds defect\n";
}

sub loopThroughBlocks
{
	foreach my $block (@blocks){
		#leere das SessionArray und wechsle in das entsprechende Verzeichnis
		@sessions = ();
		chdir($block) or die "$block not found!!!\n";
		my $sessionpath = `ls`;
		while($sessionpath =~ m/SES/){
			if($sessionpath =~ s/(SES\d+)//){
				push @sessions, $1;
			}
		}
		
		loopThroughSessions();
		#wechsle zurück in den BLOCKxy ordner
		chdir('../')or die "cd back in blocks defect\n";
	}
}

sub loopThroughSessions
{
	foreach my $session (@sessions){
		chdir($session) or die "$session not found\n";
		my $filenames = `ls`;
		while($filenames =~ m/.hlb/){
			if($filenames =~ s/(\d+_h_\d+.hlb)//){
				my $originalFilename = $1;
				
				my $originalFilenameQualified = getcwd() . '/' . $originalFilename;
				push @files, $originalFilenameQualified; #need an absolute path here
				
				$originalFilenames->{$originalFilenameQualified} = $originalFilename;
			}
		}
				
		#wechsle zurück in den SESxxyy ordner
		chdir('../') or die "cd back in sessions defect\n";
	}
}

#----------------------------------------------------------------
#	Was wird bei den jeweiligen Dateien ausgeführt
#----------------------------------------------------------------

sub loopThroughFilesAndExtractText{
	print "Now looping through all (" . scalar @files . ") HLB files to converting them to continuous text...";
	
	foreach my $filename (@files){
		convertFile($filename);
	}
	
	print "\tFINISHED\n";
}

sub convertFile{
	my $filename = shift;
	my $rc = open(FILE,"<",$filename);
	
	if(!defined($rc)){
		print "Problem opening file " . $filename . "\n";
		return;
	}
	<FILE>;
	<FILE>;
	<FILE>;
	my $fourthLine = <FILE>;
	my $class = recognizeClass($fourthLine);
	<FILE>;
	<FILE>;
	
	
	
	my $contiousText = '';
	
	#Now save the file into a contious text string
	while(<FILE>){
		#stop if the line contains only whitespaces because then the phonetics follow...
		if($_ =~ m/^\s+$/){
			last;  #stop processing this file.
		}
		
		#get the word from this line
		my $word = extractWord($_);
		
		#on garbage continue
		if($word eq '#GARBAGE#'){
			next;
		}
		
		#now temp save this word for writing to file
		$contiousText .= $word . ' ';
	}
	
	#now save the string to a new file, ordered by its class, while conversving the old name
	my $outputFilenameQualified;
	my $outputFilenameUnqualified = $originalFilenames->{$filename};
	
	if($class eq "alc"){
		$outputFilenameQualified = $outputPathAlc . $outputFilenameUnqualified;
	}else{
		$outputFilenameQualified = $outputPathNonalc . $outputFilenameUnqualified;
	}
	
	my $rc2 = open(OUTFILE,">", $outputFilenameQualified);
	
	if(!defined($rc2)){
			print "Problem opening output file " . $outputFilenameQualified . "\n";
			return;
	}
	
	print OUTFILE $contiousText;
	close(OUTFILE);
}

####################################################
#Helper methods
####################################################


#erkenne die Klasse des Files 
sub recognizeClass{
	  my $fourthLine = shift;
	  my $class;
	  #erkenne die Klasse
      if($fourthLine =~ m/\w+ \w+ \w+ \w+ \w+ \w+ \w+ (a|na|cna)/){
			#konvertiere klasse von a => alc und von na => nonalc
			if($1 eq 'a'){
				$class = 'alc';
			}elsif($1 eq 'na'){
				$class = 'nonalc';
			}elsif($1 eq 'cna'){
				$class = 'nonalc';
			}else{
				die "Fehler die Klasse zu erkennen in $fourthLine. Exiting...\n";
			}
			return $class;
      }else{
			print "No Class recognized, skipping.\n";
			print "Recognization string was " . $fourthLine . "\n";
      }
}

#extracts the word from this line
sub extractWord{
	my $line = $_;
	
	if($line =~ s/^\d+\s(\S+)\s//){
		return $1;
	}
}





