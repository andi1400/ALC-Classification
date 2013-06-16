#!/usr/bin/perl -w


###########################################
# This script will go through the corpus (the data created by the preprocessing scripts) and calculate
# information gain values on each featur. It will use the standard Information Gain theory based on conditional entropy.
############################################

use strict;
use Data::Dumper;
use Cwd;

#----------------------------------------------------------------
#	Variablen Deklarationen
#----------------------------------------------------------------

#ordnerstruktur durchlaufen und jeweilige Unterordner abspeichern
my @files;
my @allWords;

#Hashes für die Wörter
my $informationGainPerWord;

#preparation for entropy Calculation
my $wordAppearancePerFile = {};
my $wordAppearancesNonAlc = {};
my $wordAppearancesAlc = {};

#used for storing the finished information gain
my $informationGainPerWordEntropyBased = {};

#counts, how many files there are. Used for H(Y)
my $nonalcCounter = 0;
my $alcCounter = 0;

#globale paths of the system
my $basePath 		= "/home/bas-alc";
my $corpusBasePath 	= $basePath . "/corpus";
my $outputBase 		= $basePath . "/test/output";
my $entropyFile		= $outputBase . "/EntropyInfoGain.info";
my $lexiconFile		= "/home/bas-alc/test/generatedLexicon.TBL";


main();

sub main{
	print "START INFORMATION GAIN\n";
	
	print "collecting files\n";
	collectReducedFileSet();
	
	print "generate a Lexicon from all words\n";
	generateLexicon();
	
	print "initiate the hashes and all that stuff\n";
	initEntropyBaseInfoGain();
	
	print "looping through files\n";
	loopThroughFilesAndAnalyse();
	
	print "calculate the info gain...";
	calcEntropyInfoGain();
	print "\t[finished]\n";
	
	print "writing results to file\n";
	printInformationGain();
	
	print "FINISHED\n";
}





#----------------------------------------------------------------
#	Ordner durchlaufen, um Dateien zu sammeln
#----------------------------------------------------------------

sub collectReducedFileSet
{
	my $filebase = "/home/bas-alc/test/rawData/combined_all";
	
	#1. go through alc folder
	chdir($filebase);
	chdir('alc');
	
	my $filenames = `ls`;
	while($filenames =~ m/.hlb/){
		if($filenames =~ s/(\d+_h_\d+.hlb)//){
			push @files, getcwd() . '/' .  $1; #need an absolute path here
		}
	}
	
	#2. go through nonalc and do the same
	chdir($filebase);
	chdir('nonalc');
	
	$filenames = `ls`;
	while($filenames =~ m/.hlb/){
		if($filenames =~ s/(\d+_h_\d+.hlb)//){
			push @files, getcwd() . '/' .  $1; #need an absolute path here
			print getcwd() . '/' .  $1 . "\ņ";
		}
	}
}

sub generateLexicon()
{
	#read in all words
	foreach my $file (@files){
		open(FILE, "<", $file) or die "could not open $file";
		while(my $line = <FILE>){
			#match any non whitespace and remove it afterwards
			while($line =~ s/(\S+)//){
				my $word = $1;
				#print "checking word $word \n";
				if(!($word ~~ @allWords)){
					#print "found word $word\n";
					push @allWords, $word;
				}
			}
		}
		
		close FILE;
	}
	
	#print all found words into a new lexicon
	open(LEXICON,">",$lexiconFile) or die "Could not open Lexicon $lexiconFile";
	foreach my $word (@allWords){
		print LEXICON "$word\n";
	}
	close LEXICON;
	print "Lexicon written to $lexiconFile\n";
}

sub initEntropyBaseInfoGain{
	#initialize specialised hashes as well as the template hash
	#this is later copied and used for merging into these specialised hashes
	foreach my $word (@allWords){
		$wordAppearancesAlc->{$word} = [];
		$wordAppearancesNonAlc->{$word} = [];
		$wordAppearancePerFile->{$word} = 0;
	}
}

#----------------------------------------------------------------
#	Was wird bei den jeweiligen Dateien ausgeführt
#----------------------------------------------------------------

sub loopThroughFilesAndAnalyse{
	print "\nNow looping through all (" . scalar @files . ") HLB files to see the word occurences...";
	
	foreach my $filename (@files){
		analyseFile($filename);
	}
	print "\tFINISHED\n";
}

sub analyseFile{
	my $filename = shift;
	open(FILE,"<",$filename) or die "problem opening file $filename";
	
	#get the current class from its path	
	my $class = recognizeClass($filename);
	
	#read in each line of the file, which contains several words
	#normally each file should have one line only!
	#create a copy of the hash containing all words with counter 0
	my %tempHash = %{$wordAppearancePerFile};
	while(<FILE>){
		analyseLineForEntropyPreparation($_, \%tempHash);
	}
	mergeTempHashToGlobalHash($class, \%tempHash);
	close(FILE);
}

#erkenne die Klasse des Files 
sub recognizeClass{
	  my $filename = shift;
	  my $class;
	  
	  #recognize the class and increase the counter, how many alc and nonalc files there are
	  if($filename =~ m/nonalc/){
	  	$class = 'nonalc';
	  	$nonalcCounter++;
	  }else{
	  	$class = 'alc';
	  	$alcCounter++;
	  }
	  
	  return $class;
}

sub mergeTempHashToGlobalHash{
	my ($class, $localHash) = @_;
	my $globalHash;
	
	#choose the corect hash, which the local shall be merged with
	#in this case the hash is not copied, as the refereces are assigned!
	if($class eq "alc"){
		$globalHash = $wordAppearancesAlc;
	}else{
		$globalHash = $wordAppearancesNonAlc;
	}
	
	#merging of the two hashes
	#increment a counter for each word, how often it has occured in the file.
	#Therefore, for each word in a hash there is an array for occurances
	#example:	word->[7,5,1,3,0] would mean:
	#			word did not appear in 7 files
	#			word appeared once only in 5 files
	#			word appeared two times in 1 file
	#			word apperead 3 times in 2 files
	#			word did not appear 4 times in any file
	while(my ($word, $value) = each %{$localHash}){
			@{$globalHash->{$word}}[$value]++;
	}
}

sub analyseLineForEntropyPreparation{
	my ($line, $tempHash) = @_;
	
	#what happens with those characters? => umlauts are "ubertreiben and stutters: <"ah">
	while($line =~ s/(\S+)//){
		my $word = $1;
		
		if($word eq '#GARBAGE#'){
			return; #skip garbage
		}
		$tempHash->{$word}++;
	}
}

#----------------------------------------------------------------
#	calculate information gain per word 
#----------------------------------------------------------------

sub calcEntropyInfoGain{
	
	my $classEntropy = calcClassEntropy();
	
	while(my ($word, $arrayAlc) = each %{$wordAppearancesAlc}){
		my $arrayNonAlc = $wordAppearancesNonAlc->{$word};
		
		my $maxIndexAlc 	= (scalar @{$arrayAlc}) - 1;
		#print Dumper($arrayNonAlc);
		my $maxIndexNonAlc 	= (scalar @{$arrayNonAlc}) - 1;
		my $maxIndex 		= $maxIndexAlc >= $maxIndexNonAlc ? $maxIndexAlc : $maxIndexNonAlc;
		
		
		#calculating the probability of an occurance value for this word
		
		#calculate the counter only
		my $occuranceNormalizationCounter = 0;
		for ( my $i = 0; $i <= $maxIndex; $i++){
			if(@{$arrayAlc}[$i]){
				$occuranceNormalizationCounter += @{$arrayAlc}[$i];
			}
			if(@{$arrayNonAlc}[$i]){
				$occuranceNormalizationCounter += @{$arrayNonAlc}[$i];
			}
		}
		
		my $occuranceProbabilty = [];
		#H(Y|X)
		my $conditionalEntropy = 0;
		for ( my $j = 0; $j <= $maxIndex; $j++){
			my $occurance = 0;
			
			if(@{$arrayAlc}[$j]){
				$occurance += @{$arrayAlc}[$j];
			}else{
				@{$arrayAlc}[$j] = 0;
			}
			if(@{$arrayNonAlc}[$j]){
				$occurance += @{$arrayNonAlc}[$j];
			}else{
				@{$arrayNonAlc}[$j] = 0;
			}
			
			#represents P(X=x_j)
			@{$occuranceProbabilty}[$j] = $occurance / $occuranceNormalizationCounter;
			
			my $classNormalizationCounter = @{$arrayAlc}[$j] + @{$arrayNonAlc}[$j];
			if($classNormalizationCounter == 0){
				next;
			}
			
			my $PofY_alc = @{$arrayAlc}[$j] / $classNormalizationCounter;
			my $PofY_nonAlc = @{$arrayNonAlc}[$j] / $classNormalizationCounter;
			my $PofY_alc_log;
			my $PofY_nonAlc_log;
			
			#log(0) is not defined. As it would be multiplied with 0 anyway, set this vlue to 0
			# cant match both values in one if, as only one log can be 0
			if($PofY_alc == 0){
				$PofY_alc_log = 0;
			}else{
				$PofY_alc_log = log($PofY_alc) / log(2);
			}
			if($PofY_nonAlc == 0){
				$PofY_nonAlc_log = 0;
			}else{
				$PofY_nonAlc_log = log($PofY_nonAlc) / log(2);
			}
			
			#H(Y| X=x_j)
			my $preciseCondEntropy = ($PofY_alc * $PofY_alc_log) + ($PofY_nonAlc * $PofY_nonAlc_log);
			#P(X=x_j) * H(Y| X=x_j)
			$conditionalEntropy += @{$occuranceProbabilty}[$j] * $preciseCondEntropy;
		}
		#H(Y|X)
		$conditionalEntropy *= -1;
		
		#calculate the information Gain for this word
		# I(Y,X) = H(Y) - H(Y|X)
		my $infoGain = $classEntropy - $conditionalEntropy;
		$informationGainPerWordEntropyBased->{$word} = $infoGain;
	}

}

sub calcClassEntropy{
	#TODO think about if this is a correct representation on a per file basis as it is now
	# might be better to calc these prob on a per word basis
	my $probabilityAlc = $alcCounter / ($alcCounter + $nonalcCounter);
	my $probabilityNonAlc = $nonalcCounter / ($alcCounter + $nonalcCounter);
	
	#First component of the info gain: The entropy of a given class Y_i
	#H(Y) = - [(  P(Y = alc) * log2(P(Y = alc))  )  + (  P(Y = alc) * log2(P(Y = alc))  )]
	#see http://en.wikipedia.org/wiki/Entropy_(information_theory) for details
	my $entropyComponentAlc = $probabilityAlc * ((log $probabilityAlc) / (log 2));
	my $entropyComponentNonAlc = $probabilityAlc * ((log $probabilityAlc) / (log 2));
	#now calculate entropy on class variable:
	my $classEntropy = - ($entropyComponentAlc + $entropyComponentNonAlc);
	print "The Entropy of our class variable is $classEntropy \n";
	return $classEntropy;
}



#----------------------------------------------------------------
#	outut
#----------------------------------------------------------------


my($word, $delta, $occAlc, $normAlc, $occNonAlc, $normNonAlc);

format MYENTROPY = 
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<< | @<<<<<<<<<<<<<<<<<<<<<<<<<<<
$word, $delta
.

sub printInformationGain{
	open(ENTROPY,">", $entropyFile);
	
	select(ENTROPY);
	$~ = "MYENTROPY";
	foreach my $key (reverse sort { $informationGainPerWordEntropyBased->{$a} <=> $informationGainPerWordEntropyBased->{$b} } keys (%{$informationGainPerWordEntropyBased})){
		
		$word = $key;
		$delta = $informationGainPerWordEntropyBased->{$key};
		
		write;
	}

	close(ENTROPY);
	select(STDOUT);	
}




