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
# THIS SCRIPT WILL REMOVE ALL TESTS THAT WHERE ONLY PERFORMED IN EITHER ALC OR NONALC CLASS FROM THE CORPUS!
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
my $outputPathAlc 	 = $basePath . "/test/rawData/combined_all/alc/";
my $outputPathNonalc = $basePath . "/test/rawData/combined_all/nonalc/";


#diese werden ignoriert und gefiltert
my @unmapped = ('002','003','004','005','006','007','009','011','016','017','018','021','022','025','027','028','033','035','037','039','040','043','044','045','047','052','053','054','056','057','058');


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
	my $itmNumber 	= recognizeItemNr($fourthLine);
	<FILE>;
	<FILE>;
	
	#skip the unmapped ones
	if($class eq 'nonalc'){
		if($itmNumber ~~ @unmapped){
			return;
		}
	}else{
		if($itmNumber eq '004'){
			print "skip 004";
			return;
		}
	}
	
	
	
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

#erkenne item nummer um sie zu skippen
sub recognizeItemNr{
	my $fourthLine = shift;
	
	if($fourthLine =~ m/^\w*\s\w*\s\w*\s\w*\s\w*\s(\d*)/){
		return $1;
    }else{
    	die "Problem beim Erkennen der Item Nummer.";
    } 
}


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





