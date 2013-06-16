#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use Cwd;


###########################################
# Our first approach to try classification on ALC. This script MIGHT NOT BE UP-To-DAT to the current path structures on 
# the alc machine. Thus it demonstrates how to use WEKA from command line to perform classification on given arff files.
# The arff files are manually created in this script.
############################################

#----------------------------------------------------------------
#	Variablen Deklarationen
#----------------------------------------------------------------

#ordnerstruktur durchlaufen und jeweilige Unterordner abspeichern
my @blocks;
my @sessions;
my @files;

#alle features, die später in das ArffFile ausgegeben werden
my @resultSimple;
my @resultSimpleType;
my @resultRandomizedSession;
my @resultNormalizedSession;

#verschiedene Typen
my @differentTypes = ("LT",'RT','DQ','MP','DP','LN','MQ','RR','EC','LS','RA');

#globalen Pfade des Systems
my $basePath 		= "/home/bas-alc";
my $corpusBasePath 	= $basePath . "/corpus";
my $outputBase 		= $basePath . "/test/";
my $currentOutput; 	#aktueller Outputordner, definiert durch timestamp

#halten ArffFiles und Classifier, die durchlaufen werden
my @generatedArff;
my %availableClassifiers = (JRip => 'java -Xmx8096M weka.classifiers.rules.JRip -F 3 -N 2.0 -O 2 -S 1 -s 10 -t CURRENTARFF > CURRENTARFF_JRip.output',
							SMO=>'java -Xmx8096M weka.classifiers.functions.SMO -C 1.0 -L 0.001 -P 1.0E-12 -N 0 -V -1 -W 1 -K "weka.classifiers.functions.supportVector.PolyKernel -C 250007 -E 1.0" -t  CURRENTARFF > CURRENTARFF_SMO.output',
							Bayes => 'java -Xmx8096M weka.classifiers.bayes.NaiveBayes -t CURRENTARFF > CURRENTARFF_NaiveBayes.output',
							ZeroR => 'java -Xmx8096M weka.classifiers.rules.ZeroR -t CURRENTARFF > CURRENTARFF_ZeroR.output',
							DT  => 'java -Xmx8096M weka.classifiers.rules.DecisionTable -X 1 -S "weka.attributeSelection.BestFirst -D 1 -N 5" -t CURRENTARFF > CURRENTARFF_DT.output',
							J48Tree => 'java -Xmx8096M weka.classifiers.trees.J48 -C 0.25 -M 2 -t CURRENTARFF > CURRENTARFF_J48Tree.output',
							Logistic => 'java -Xmx8096M weka.classifiers.functions.Logistic -R 1.0E-8 -M -1 -t CURRENTARFF > CURRENTARFF_Logistic.output'
							);

#----------------------------------------------------------------
#	eigentlicher Aufruf, der das main Programm startet
#----------------------------------------------------------------


main();

sub main{
	print "verarbeite Dateien und erzeuge Daten!\n";
	#gehe in corpus stamm ordener
	defineOutputDir();
	
	#extrahiere Daten aus EMU Ordner
	extrahiereEMU();
	
	#erzeuge simple ARFF just irrequalirities
	print "erzeuge simple.arff\n";
	generateSimpleArffHeader('simple.arff');
	generateSimpleArffOutput('simple.arff');
	
	#erzeuge simple ARFF with types
	print "erzeuge simpleType.arff\n";
	generateSimpleTypeArffHeader('simpleType.arff');
	generateSimpleTypeArffOutput('simpleType.arff');
	
	#erzeuge session with Normalization
	print "erzeuge normalizedSession.arff\n";
	generateSessionArffHeader('normalizedSession.arff');
	generateNormalizedSessionArffOutput('normalizedSession.arff');
	
	#erzeuge session with Randomization
	print "erzeuge randomizedSession.arff\n";
	generateSessionArffHeader('randomizedSession.arff');
	generateRandomizedSessionArffOutput('randomizedSession.arff');
	
	#starte classifiers für die Arff files
	print "starte Klassifizierung\n";	
	
	runClassifiers();
}

#----------------------------------------------------------------
#	Ordner durchlaufen, um Dateien zu sammeln
#----------------------------------------------------------------

sub extrahiereEMU
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
		#leere das FileArray und wechsle in das entsprechende Verzeichnis
		@files = ();
		chdir($session) or die "$session not found\n";
		my $filenames = `ls`;
		while($filenames =~ m/.hlb/){
			if($filenames =~ s/(\d+_h_\d+.hlb)//){
				push @files, $1;
			}
		}
				
		loopThroughFiles();
		#wechsle zurück in den SESxxyy ordner
		chdir('../') or die "cd back in sessions defect\n";
	}
}


#----------------------------------------------------------------
#	Was wird bei den jeweiligen Dateien ausgeführt
#----------------------------------------------------------------

sub loopThroughFiles
{
	#hash für Session mit Normalisierung
	my $irregularitiesNormalizedSession = {};
	initialiseNormalizedSession($irregularitiesNormalizedSession);
	
	#hash für Session mit Randomisierung
	my $irregularitiesRandomizedSession = {};
	initializeRandomizedSession($irregularitiesRandomizedSession);
	
	#Denkhilfe: alle Dateien in einer Session gehören der selben Klasse an.	
	#verarbeite jedes File in der Session%irregularitiesPerSession
	foreach my $file (@files){
		#simple ohne Type
		my $simpleFeature = parseSimple($file);
		push @resultSimple, $simpleFeature;
		
		#simple mit Type
		my $simpleTypeFeature = parseSimpleType($file);
		push @resultSimpleType, $simpleTypeFeature;
		
		#Session mit Normalisierung
		parseNormalizedSession($file, $irregularitiesNormalizedSession);
		
		#Session mit Randomisierung
		parseRandomizedSession($file, $irregularitiesRandomizedSession);
	}
	
	#speichere die Hashs
	push @resultNormalizedSession, $irregularitiesNormalizedSession;
	push @resultRandomizedSession, $irregularitiesRandomizedSession;
}

sub initialiseNormalizedSession
{
	#8 irreg, 1 counter für Normalisierung
	my $irregularitiesNormalizedSession = shift;
	$irregularitiesNormalizedSession->{LN} = [0,0,0,0,0,0,0,0,0]; 
	$irregularitiesNormalizedSession->{RT} = [0,0,0,0,0,0,0,0,0];
	$irregularitiesNormalizedSession->{DQ} = [0,0,0,0,0,0,0,0,0];
	$irregularitiesNormalizedSession->{MP} = [0,0,0,0,0,0,0,0,0];
	$irregularitiesNormalizedSession->{DP} = [0,0,0,0,0,0,0,0,0];
	$irregularitiesNormalizedSession->{LT} = [0,0,0,0,0,0,0,0,0];
	$irregularitiesNormalizedSession->{MQ} = [0,0,0,0,0,0,0,0,0];
	$irregularitiesNormalizedSession->{RR} = [0,0,0,0,0,0,0,0,0];
	$irregularitiesNormalizedSession->{EC} = [0,0,0,0,0,0,0,0,0];
	$irregularitiesNormalizedSession->{LS} = [0,0,0,0,0,0,0,0,0];
	$irregularitiesNormalizedSession->{RA} = [0,0,0,0,0,0,0,0,0];
	$irregularitiesNormalizedSession->{class} = "";
}

sub initializeRandomizedSession
{
	my $irregularitiesRandomizedSession = shift;
	$irregularitiesRandomizedSession->{LN} = []; 
	$irregularitiesRandomizedSession->{RT} = [];
	$irregularitiesRandomizedSession->{DQ} = [];
	$irregularitiesRandomizedSession->{MP} = [];
	$irregularitiesRandomizedSession->{DP} = [];
	$irregularitiesRandomizedSession->{LT} = [];
	$irregularitiesRandomizedSession->{MQ} = [];
	$irregularitiesRandomizedSession->{RR} = [];
	$irregularitiesRandomizedSession->{EC} = [];
	$irregularitiesRandomizedSession->{LS} = [];
	$irregularitiesRandomizedSession->{RA} = [];
	$irregularitiesRandomizedSession->{class} = "";
	#wird für perl rand benötigt...berechnet random für 0 bis value ohne den value selbst, also rand(1) = 0.
	$irregularitiesRandomizedSession->{CounterLN} = 0; 
	$irregularitiesRandomizedSession->{CounterRT} = 0;
	$irregularitiesRandomizedSession->{CounterDQ} = 0;
	$irregularitiesRandomizedSession->{CounterMP} = 0;
	$irregularitiesRandomizedSession->{CounterDP} = 0;
	$irregularitiesRandomizedSession->{CounterLT} = 0;
	$irregularitiesRandomizedSession->{CounterMQ} = 0;
	$irregularitiesRandomizedSession->{CounterRR} = 0;
	$irregularitiesRandomizedSession->{CounterEC} = 0;
	$irregularitiesRandomizedSession->{CounterLS} = 0;
	$irregularitiesRandomizedSession->{CounterRA} = 0;
}

#----------------------------------------------------------------
#	Methoden zum Parsen der Files
#----------------------------------------------------------------

#parse eine Datei, um jedes File als Feature OHNE TYP zu repräsentieren
sub parseSimple{
      my $filename = shift;
      my $feature;
      
      #Attribute herausfiltern
      my $line	= recognizeLine($filename);
      my $class = recognizeClass($line);

      #Erkenne die irrequalirites
      if($line =~ m/\d+\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)/){
	 	#schreibe Irregularities in simple result string
	  	$feature = "$1,$2,$3,$4,$5,$6,$7,$8,$class\n";
      }
 
      return $feature;
}

#parse eine Datei, um jedes File als Feature MIT TYP zu repräsentieren
sub parseSimpleType{
      my $filename = shift;
      my $feature;
      
      #Attribute herausfiltern
      my $line	= recognizeLine($filename);
      my $class = recognizeClass($line);
      my $type 	= recognizeItemType($line);

      #Erkenne die irrequalirites
      if($line =~ m/\d+\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)/){
	 	#schreibe Irregularities in simple result string
	  	$feature = "$1,$2,$3,$4,$5,$6,$7,$8,$type,$class\n";
      }
 
      return $feature;
}

#parse Datei per Session, sortiere alles in einen Hash nach Typen zur Normalisierung
sub parseNormalizedSession{
	my ($filename, $hashref) = @_;
	
	#Attribute herausfiltern
    my $line 	= recognizeLine($filename);
    my $class 	= recognizeClass($line);
    my $type 	= recognizeItemType($line);
    
    #setze die Klasse
    $hashref->{class} = $class;

    #Erkenne die irrequalirites
    if($line =~ m/\d+\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)/){
	 	#schreibe Irregularities in den hashref na die richtige stelle
	 	@{$hashref->{$type}}[0] += $1;
	 	@{$hashref->{$type}}[1] += $2;
	 	@{$hashref->{$type}}[2] += $3;
	 	@{$hashref->{$type}}[3] += $4;
	 	@{$hashref->{$type}}[4] += $5;
	 	@{$hashref->{$type}}[5] += $6;
	 	@{$hashref->{$type}}[6] += $7;
	 	@{$hashref->{$type}}[7] += $8;
	 	@{$hashref->{$type}}[8]++;
    }
}

sub parseRandomizedSession{
	my ($filename, $hashref) = @_;
	
	#Attribute herausfiltern
    my $line 	= recognizeLine($filename);
    my $class 	= recognizeClass($line);
    my $type 	= recognizeItemType($line);
    my $counterId = "Counter".$type;
    
    #setze die Klasse
    $hashref->{class} = $class;

    #Erkenne die irrequalirites
    if($line =~ m/\d+\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)/){
	 	#schreibe Irregularities in den hashref an die richtige stelle
	 	#TODO use an array here
	 	my $irregularities = "$1,$2,$3,$4,$5,$6,$7,$8,";
	 	push @{$hashref->{$type}}, $irregularities;
	 	#TODO counter hier ueberfluessig, aus Laenge bestimmen
	 	$hashref->{$counterId}++;
    }
}


#gibt die 4. Zeile der Datei zurück, die die Metainformationen enthält
sub recognizeLine
{
	my $dateiname = shift;
	open(INPUTFILE, "<", $dateiname);
	<INPUTFILE>;
	<INPUTFILE>;
	<INPUTFILE>;
	my $fourthLine 	= <INPUTFILE>;
	close(INPUTFILE);
	return $fourthLine;
}

#erkenne den ITEM Typ in HLB file
sub recognizeItemType{
	my $fourthLine = shift; 
	#erkenne den ITEM Typ
    if($fourthLine =~ m/(\w) (\w)\s*$/){
    	
		return $1.$2;
    }else{
    	die "Problem beim Erkennen des Item Typs.";
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

#extract session id out of HLB filename
#TODO use this somewhere
sub getSessionIDFromFilename{
	my $filename = shift;
	
	if($filename =~ m/^\d\d\d(\d{4})/){
		return $1;
	}else{
    	die "Problem beim Erkennen der Session ID aus filename $filename.";
    }
}

#----------------------------------------------------------------
#	Arff Header definieren
#----------------------------------------------------------------
#im Header: my @differentTypes = ('LT','RT','DQ','MP','DP','LN','MQ','RR','EC','LS','RA');
sub generateSessionArffHeader{
	my $arffName = shift;
	
	#öffne die Datei und schreibe die generellen Attribute
	my $dateiname = $currentOutput . '/'.$arffName;
	open(DATEI, ">", $dateiname) or die "Die arff Datei $dateiname konnte nicht zum Schreiben geoeffnet werden :-(\n";
	print DATEI '%This ARFF file was created' . timestamp() . "\n" ;
	print DATEI '%Generating Function: sessionType' . "\n" ;
    print DATEI '@RELATION alc'."\n";
	foreach my $typeString (@differentTypes){
		print DATEI '@ATTRIBUTE '. $typeString . 'hesitation NUMERIC'."\n";
		print DATEI '@ATTRIBUTE '. $typeString . 'pausesKlein NUMERIC'."\n";
		print DATEI '@ATTRIBUTE '. $typeString . 'pausesGross NUMERIC'."\n";
		print DATEI '@ATTRIBUTE '. $typeString . 'delayedPhones NUMERIC'."\n";
		print DATEI '@ATTRIBUTE '. $typeString . 'pronounceErrors NUMERIC'."\n";
		print DATEI '@ATTRIBUTE '. $typeString . 'repetitionStutter NUMERIC'."\n";
		print DATEI '@ATTRIBUTE '. $typeString . 'repairs NUMERIC'."\n";
		print DATEI '@ATTRIBUTE '. $typeString . 'interrupteds NUMERIC'."\n";
	}
	
	#jetzt die klassen
	print DATEI '@ATTRIBUTE class {alc,nonalc}'."\n\n\n";

	#sagen dass jetzt daten kommen
	print DATEI '@DATA'."\n";
	close DATEI;
}

sub generateSimpleArffHeader{
	#öffne die Datei und schreibe die generellen Attribute
	my $arffName = shift;
	my $dateiname = $currentOutput . '/'.$arffName;
	open(DATEI, ">", $dateiname) or die "Die arff Datei $dateiname konnte nicht zum Schreiben geoeffnet werden :-(\n";
	print DATEI '%This ARFF file was created' . timestamp() . "\n" ;
	print DATEI '%Generating Function: simpleArff' . "\n" ;
    print DATEI '@RELATION alc'."\n";
	print DATEI '@ATTRIBUTE hesitation NUMERIC'."\n";
	print DATEI '@ATTRIBUTE pausesKlein NUMERIC'."\n";
	print DATEI '@ATTRIBUTE pausesGross NUMERIC'."\n";
	print DATEI '@ATTRIBUTE delayedPhones NUMERIC'."\n";
	print DATEI '@ATTRIBUTE pronounceErrors NUMERIC'."\n";
	print DATEI '@ATTRIBUTE repetitionStutter NUMERIC'."\n";
	print DATEI '@ATTRIBUTE repairs NUMERIC'."\n";
	print DATEI '@ATTRIBUTE interrupteds NUMERIC'."\n";

	#jetzt die klassen
	print DATEI '@ATTRIBUTE class {alc,nonalc}'."\n\n\n";

	#sagen dass jetzt daten kommen
	print DATEI '@DATA'."\n";
	close DATEI;
}

sub generateSimpleTypeArffHeader{
	#öffne die Datei und schreibe die generellen Attribute
	my $arffName = shift;
	my $dateiname = $currentOutput . '/'.$arffName;
	open(DATEI, ">", $dateiname) or die "Die arff Datei $dateiname konnte nicht zum Schreiben geoeffnet werden :-(\n";
	print DATEI '%This ARFF file was created' . timestamp() . "\n" ;
	print DATEI '%Generating Function: simpleArff' . "\n" ;
    print DATEI '@RELATION alc'."\n";
	print DATEI '@ATTRIBUTE hesitation NUMERIC'."\n";
	print DATEI '@ATTRIBUTE pausesKlein NUMERIC'."\n";
	print DATEI '@ATTRIBUTE pausesGross NUMERIC'."\n";
	print DATEI '@ATTRIBUTE delayedPhones NUMERIC'."\n";
	print DATEI '@ATTRIBUTE pronounceErrors NUMERIC'."\n";
	print DATEI '@ATTRIBUTE repetitionStutter NUMERIC'."\n";
	print DATEI '@ATTRIBUTE repairs NUMERIC'."\n";
	print DATEI '@ATTRIBUTE interrupteds NUMERIC'."\n";
	print DATEI '@ATTRIBUTE textType {LN,RT,DQ,RA,MP,DP,LT,MQ,RR,EC,LS}'."\n\n";

	#jetzt die klassen
	print DATEI '@ATTRIBUTE class {alc,nonalc}'."\n\n\n";

	#sagen dass jetzt daten kommen
	print DATEI '@DATA'."\n";
	close DATEI;
}


#----------------------------------------------------------------
#	Arff Files mit Feautures füllen
#----------------------------------------------------------------

sub generateSimpleArffOutput{
	my $arffName = shift;
	my $dateiname = $currentOutput . '/'.$arffName;
	open(ARFF, ">>", $dateiname) or die "Arff file $dateiname konnte nicht geöffnet werden :-(\n";
	
	#schreibe Daten in das Arff file
	foreach my $result (@resultSimple){
		print ARFF $result;
	}
	
	#schließe file, merke generiertes ARFF file
	close ARFF;
	push @generatedArff, $arffName;
}

sub generateSimpleTypeArffOutput{
	my $arffName = shift;
	my $dateiname = $currentOutput . '/'.$arffName;
	open(ARFF, ">>", $dateiname) or die "Arff file $dateiname konnte nicht geöffnet werden :-(\n";
	
	#schreibe Daten in das Arff file
	foreach my $result (@resultSimpleType){
		print ARFF $result;
	}
	
	#schließe file, merke generiertes ARFF file
	close ARFF;
	push @generatedArff, $arffName;
}

sub generateNormalizedSessionArffOutput{
	my $arffName = shift;
	my $dateiname = $currentOutput . '/'.$arffName;
	open(ARFF, ">>", $dateiname) or die "Arff file $dateiname konnte nicht geöffnet werden :-(\n";
	my $class;
	my $resultLine = '';
	
	#gehe alle ergebnis hashs durch
	#zuerst den Hash in jeder session normalisieren und dann an den ausgabestring hängen.
	foreach my $hashref (@resultNormalizedSession){
		
		#Nun jede zahl im hash normalisieren, dazu erst mal das array der typen durchlaufen damit die Reihenfolge stimmt.
		#im Header:  @differentTypes = ('LT','RT','DQ','MP','DP','LN','MQ','RR','EC','LS','RA');
		foreach my $key (@differentTypes){
		 	my $arrayRefToNormalize = $hashref->{$key};
		 	my $normalizationCounter = @{$hashref->{$key}}[8];
		 	
		 	#die nummern unter key 0-7 normalisieren und ausgeben
		 	for(my $currIndex = 0; $currIndex < 8; $currIndex++){
		 		$resultLine .= @{$arrayRefToNormalize}[$currIndex] / $normalizationCounter . ',';
		 	} 
		 }
		 
		 #Klasse hinten anhängen
		 $resultLine .= $hashref->{class} . "\n";
		 
		 #abschließend den String in die dateiausgeben
		 print ARFF $resultLine;
		
		 #leere die temporäre Schleifenvariable fuer die ausgabe
		 $resultLine = '';
	}
	
	#file schließen und auf Stack ablegen
	close ARFF;
	push @generatedArff, $arffName;
}

sub generateRandomizedSessionArffOutput{
	my $arffName = shift;
	my $dateiname = $currentOutput . '/'.$arffName;
	open(ARFF, ">>", $dateiname) or die "Arff file $dateiname konnte nicht geöffnet werden :-(\n";
	my $class;
	my $resultLine = '';
	
	#gehe alle ergebnis hashs durch
	foreach my $hashref (@resultRandomizedSession){
		
		#Wähle eine featuresequenz pro Typ zufällig aus und hänge sie an
		#im Header:  @differentTypes = ('LT','RT','DQ','MP','DP','LN','MQ','RR','EC','LS','RA');
		foreach my $key (@differentTypes){
			#Bestimme den index aus der Anzahl vorhandener Features für diesen Typen
			#TODO counter key not necessary because array length is used
			my $counterId 	= "Counter".$key;
			my $upperBound	= $hashref->{$counterId};
			my $index 	= int(rand($upperBound));
			#Lese die Featuresequenz aus und hänge sie an
			#TODO hier mit ner loop durch das neue Array laufen und dann comma separiert ausgeben
			$resultLine .= @{$hashref->{$key}}[$index];
		 }
		 
		 #Klasse hinten anhängen
		 $resultLine .= $hashref->{class} . "\n";
		 
		 #abschließend den String in die dateiausgeben
		 print ARFF $resultLine;
		
		 #leere die temporäre Schleifenvariable fuer die ausgabe
		 $resultLine = '';
	}
	
	#file schließen und auf Stack ablegen
	close ARFF;
	push @generatedArff, $arffName;
}

#----------------------------------------------------------------
#	Methoden für die Ausgabe
#----------------------------------------------------------------

sub runClassifiers
{
	chdir($currentOutput);
	foreach my $arff (@generatedArff){
		print "Running classifiers for $arff...\n";
		while((my $key, my $cmd) = each %availableClassifiers){
			print "\t$key running...\n ";
			$cmd =~ s/CURRENTARFF/$arff/g;
			print "command was: $cmd\n";
			system($cmd);
		}
	}	
}

sub defineOutputDir
{
	chdir($outputBase);
	my $timestamp = timestamp();
	mkdir($timestamp);
	$currentOutput = $outputBase . '/'. $timestamp;	
}

sub timestamp
{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$mon++; $year += 1900; $yday++;
	my $timestamp = sprintf("%04d%02d%02d_%02d%02d%02d", $year, $mon, $mday, $hour, $min, $sec);
	return $timestamp;
}


