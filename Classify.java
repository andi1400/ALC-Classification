import weka.attributeSelection.InfoGainAttributeEval;
import weka.attributeSelection.Ranker;
import weka.core.*;
import weka.core.converters.*;
import weka.classifiers.Evaluation;
import weka.classifiers.bayes.NaiveBayes;
import weka.classifiers.functions.Logistic;
import weka.classifiers.functions.MultilayerPerceptron;
import weka.classifiers.functions.SMO;
import weka.classifiers.meta.Vote;
import weka.classifiers.rules.DecisionTable;
import weka.classifiers.rules.JRip;
import weka.classifiers.trees.*;
import weka.classifiers.Classifier;
import weka.experiment.LearningRateResultProducer;
import weka.filters.*;
import weka.filters.supervised.attribute.AttributeSelection;
import weka.filters.unsupervised.attribute.*;
import weka.filters.unsupervised.instance.RemovePercentage;

import java.io.*;
import java.text.DecimalFormat;
import java.text.NumberFormat;
import java.text.SimpleDateFormat;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;
import java.util.Date;

public class Classify {
	public static final Date CURRENT_TIME = new Date();
	public static final String CURRENT_DATE_STRING = new SimpleDateFormat("ddMMyy_HHmm").format(CURRENT_TIME);
	
  
	//HashMap contains the possible folders containing raw data. Initialized once the class is loaded by a static block
	private static HashMap<String, String> paths = new HashMap<String, String>();
	static {
		//absolut path to corpus raw data
		String base = "/home/bas-alc/test/rawData/";
		paths.put("com", base + "combined_all");
		paths.put("sep", base + "separate_all");
//		paths.put("comDQMP", base + "combined_DQ-MP");
//		paths.put("sepDQMP", base + "separate_DQ-MP");
//		paths.put("comDQDPMPRA", base + "combined_DQ-DP-MP-RA");
//		paths.put("sepDQDPMPRA", base + "separate_DQ-DP-MP-RA");
		paths.put("comDQDPMP", base + "combined_DQ-DP-MP");
	}
	
	//HashMap contains all the classifiers that shall be used during this classification
	private HashMap<String, Classifier> usedClassifiers = new HashMap<String, Classifier>();    //used for normal CV
	private HashMap<String, Classifier> usedClassifiersMV3 = new HashMap<String, Classifier>(); //used in Majority vote
	
	//HasMap containing all classes that need to be run through (only necessary, if a class separation is chosen)
	private HashMap<String, String> usedClasses = new HashMap<String, String>();
	
	private String OUTPUT_BASE = "/home/bas-alc/test/output/" + CURRENT_DATE_STRING; //for each testrun there is an output folder with detailed printout
	private String CSV_FILENAME;								//the csv output file for this testrun
	private String pathKey;										//the key used to find the source files
	private String argsString;									//used to preserver args for folder and csv name
	private static String path 				= paths.get("sep");	//per default the separate_all folder is taken as source for references
	private static boolean applyInfoGain 	= false;			//apply filtering by info gain before running classifies
	private static boolean partitioned 		= true;				//partition data by classes
	private static int maxNumSelect 		= -1;	   			//auto select features after info gain
	private static double treshold 			= 1e-10;  			//Info Gain > 0
	private static int validateTimes 		= 10;   			//how often to run cross validate
	private static boolean wordCount 		= false;			//do word count instead of word presence
	private static int minWordCount 		= 1;				//min word count for a word to appear as a feature
	private static boolean MV3 				= false;			//if majority vote function is enabled.
	private static boolean printHeader 		= true;				//if the header is printed for csv, can be set to false with arg -NH, e.g. used for a batch run
	
	private CSV csv;				
	private HashMap<String, Evaluation> classificationResults = new HashMap<String, Evaluation>();
	
	
	public static void main(String[] args){
		Classify classify = new Classify(args);
		classify.run();
	}
	
	public Classify(String[] args){
		//parse all input and set the available classifiers
		checkArgs(args);
		
		//create a list of used classes
		setUsedClasses();
		
		//create the required output structure
		createOutputStructure();
		
		//now initialize all the csv stuff
		initializeCSVOutput();
	}
	
	private void initializeCSVOutput(){
		CSV_FILENAME = OUTPUT_BASE + pathKey + "_" + CURRENT_DATE_STRING + argsString + ".csv";
		csv = new CSV(this.CSV_FILENAME, partitioned);
		csv.createCSVHeader(usedClassifiers, MV3, argsString, printHeader);
	}
	
	/**
	 * parse the arguments passed with the call
	 * 
	 * possible parameters
	 * -I				set information gain
	 * -T NUMBER		set the threshold to NUMBER
	 * -V NUMBER		set cross folds to NUMBER
	 * -NH				do not print the header to the CSV output (e.g. useful for batch tests)
	 * -WC				set mode from word presence to word count
	 * -WCN NUMBER		set the min number of words in word count mode
	 * -P STRING		set the path and thus also the execution mode(separate, combined)
	 * 						allowed values: [com, sep, comDQMP, sepDQMP, comDQDPMPRA, sepDQDPMPRA]
	 * -C STRING		set the used classifiers. Values can be combined in any combination, like SMOJR = SMO and JRip
	 * 						allowed values: [SMO, LO, NB, JR, J48, DT, MP]
	 * -H				print this list
	 * */
	private void checkArgs(String[] args) {
		if(args != null){
			StringBuilder argsStrings = new StringBuilder();
			for(int i = 0; i < args.length; i++){
				argsStrings.append("_" + args[i]);
				if(args[i].toUpperCase().equals("-I")){
					setInformationGain();
				}else if(args[i].toUpperCase().equals("-T")){
					argsStrings.append(args[i+1]);
					setThreshold(args[++i]);
				}else if(args[i].toUpperCase().equals("-V")){
					argsStrings.append(args[i+1]);
					setCrossFold(args[++i]);
				}else if(args[i].toUpperCase().equals("-WC")){
					setWordCount();
				}else if(args[i].toUpperCase().equals("-WCN")){
					argsStrings.append(args[i+1]);
					setWordCountNumber(args[++i]);
				}else if(args[i].toUpperCase().equals("-P")){
					argsStrings.append(args[i+1]);
					setPath(args[++i]);
				}else if(args[i].toUpperCase().equals("-C")){
					argsStrings.append(args[i+1]);
					setClassifiers(args[++i]);
				}else if(args[i].toUpperCase().equals("-NH")){
					Classify.printHeader  = false;
				}else if(args[i].toUpperCase().equals("-H")){
					printHelp();
					System.exit(0);
				}
			}
			
			//preserve arguments
			argsString = argsStrings.toString();
		}
		//set all classifiers if no classifier is set
		if(usedClassifiers.size() == 0){
			setClassifiers("SMOLONBDTJRJ48");
		}
	}
	
	private void setInformationGain(){
		applyInfoGain = true;
		System.out.println("Enabled Information Gain!");
	}
	
	private void setThreshold(String threshold){
		treshold = Double.parseDouble(threshold);
		System.out.println("Information Gain selection treshold: " + treshold);
	}
	
	private void setCrossFold(String number){
		validateTimes = Integer.parseInt(number);
		System.out.println("Set cross validation to " + validateTimes);
	}
	
	private void setWordCount(){
		wordCount = true;
		System.out.println("Using WordCount for features.");
	}
	
	private void setWordCountNumber(String number) {
		minWordCount = Integer.parseInt(number);
		System.out.println("Set min wordCount to " + minWordCount);
	}
	
	/**
	 * Method to set the correct path - and find out if it is a separated test
	 * that is done on the different document classes or if it is a run that is running
	 * on the combined corpus.
	 * @param string
	 */
	private void setPath(String string) {
		pathKey = string;
		
		//check whether the classification is executed on combined data or separate data
		if(pathKey.contains("com"))
			partitioned = false;
		
		//set the requested path and check, whether it's valid
		path = paths.get(pathKey);
		if(path == null){
			System.out.println("invalid command: " + pathKey + ". Path set to separate_all!");
			pathKey = "sep";
			path = paths.get(pathKey);
		}
		System.out.println("partitioned is: " + partitioned + " on path: " + path);		
	}
	
	/**
	 * Parses the string of the set classifiers and instantiates them. Each classifier is intantiated
	 * twice: once for using on its own and once for usage in majority vote.
	 * @param string
	 */
	private void setClassifiers(String string) {
		int counter = 0;
		if(string.toUpperCase().contains("SMO")){
			usedClassifiers.put("SMO", new SMO());
			usedClassifiersMV3.put("SMO", new SMO());
			counter++;
		}
		if(string.toUpperCase().contains("NB")){
			usedClassifiers.put("NaiveBayes", new NaiveBayes());
			usedClassifiersMV3.put("NaiveBayes", new NaiveBayes());
			counter++;
		}
		if(string.toUpperCase().contains("LO")){
			usedClassifiers.put("Logistic", new Logistic());
			usedClassifiersMV3.put("Logistic", new Logistic());
			counter++;
		}
		if(string.toUpperCase().contains("DT")){
			usedClassifiers.put("DecistionTable", new DecisionTable());
			usedClassifiersMV3.put("DecistionTable", new DecisionTable());
			counter++;
		}
		if(string.toUpperCase().contains("J48")){
			usedClassifiers.put("J48", new J48());
			usedClassifiersMV3.put("J48", new J48());
			counter++;
		}
		if(string.toUpperCase().contains("JR")){
			usedClassifiers.put("JRip", new JRip());
			usedClassifiersMV3.put("JRip", new JRip());
			counter++;
		}
//		if(string.toUpperCase().contains("LVQ")){
//			usedClassifiers.put("LVQ", new LVQ());
//			usedClassifiersMV3.put("LVQ", new LVQ());
//			counter++;
//		}
		if(string.toUpperCase().contains("MP")){
			MultilayerPerceptron mp = new MultilayerPerceptron();
			mp.setAutoBuild(true);
			
			MultilayerPerceptron mp2 = new MultilayerPerceptron();
			mp2.setAutoBuild(true);
			
			usedClassifiers.put("MP", mp);
			usedClassifiersMV3.put("MP", mp2);
			counter++;
		}
		if(string.toUpperCase().contains("MV3")){
			System.out.println("Majority vote mode: [Enabled]");
			if(counter % 2 == 0){
				System.out.println("WARNING: equal number of classifier might not work correctly for majority vote!");
			}
			if(counter > 2){
				MV3 = true;
			}
		}
	}
	
	private void printHelp() {
		StringBuilder help = new StringBuilder(); 
		help.append("possible parameters\n");
		help.append("-I\t\tset information gain\n");
		help.append("-T NUMBER\tset the threshold to NUMBER\n");
		help.append("-V NUMBER\tset cross folds to NUMBER\n");
		help.append("-WC\t\tset mode from word presence to word count\n");
		help.append("-WCN NUMBER\tset the min number of words in word count mode\n");
		help.append("-P STRING\tset the path and thus also the execution mode(separate, combined)\n");
		help.append("\tallowed values: [com, sep, comDQMP]\n");
		help.append("-C STRING\tset the used classifiers. Values can be combined in any combination, like SMOJR = SMO and JRip\n");
		help.append("\tallowed values: [SMO, LO, NB, JR, J48, DT, MV3]\n");
		help.append("-NH\tdo not print a header to the csv output");
		help.append("-H\t\thelp");
		
		System.out.println(help.toString());
	}
	
	/**
	 * Depending on the chosen path, set the classes that are used
	 * Could change this to read in the subfolders in the provided path
	 * */
	private void setUsedClasses() {
		if(path.contains("separate_all")){
			String[] classes = {"LT","RT","DQ","MP","DP","LN","MQ","RR","EC","LS","RA"};
			for(String t: classes){
				usedClasses.put(t, path + "/" + t);
			}
		}else if(path.contains("separate_DQ-MP")){
			String[] classes = {"DQ", "MP"};
			for(String t: classes){
				usedClasses.put(t, path + "/" + t);
			}
		}else if(path.contains("separate_DQ-DP-MP-RA")){
			String[] classes = {"DQ", "MP", "DP", "RA"};
			for(String t: classes){
				usedClasses.put(t, path + "/" + t);
			}
		}
	}
	
	private void createOutputStructure(){
		//change the output to include the args string
		OUTPUT_BASE += "_" + argsString + "/";
		
		if(partitioned){
			for(String entry : usedClasses.keySet()){
				String dirname = OUTPUT_BASE + entry;
				new File(dirname).mkdirs();
			}
		}else{
			new File(OUTPUT_BASE + pathKey).mkdirs();
		}
	}
  
	/**
	 * This method will invoke the tests.
	 */
	private void run(){		
		try{			
			if(!partitioned){
				singleRun(path, pathKey);
			}else{
				for(Map.Entry<String, String> entry: usedClasses.entrySet()){
					String dirString = entry.getValue();
					String textType = entry.getKey();
					singleRun(dirString, textType);
				}
			}
		}catch(Exception e){
			e.printStackTrace();
		}
		
		//close the printwriter after the execution is done
		csv.closeCSVPrinter(printHeader);
	}
	
	/**
	 * Method to run a test on one document class. This will create the feature set,
	 * apply Information Gain if specified, and run the specified classifiers.
	 * @param dirString
	 * @param texttype
	 * @throws Exception
	 */
	private void singleRun(String dirString, String texttype) throws Exception {
		Instances bowRawData = createBOW(dirString);
		writeToArff(bowRawData, texttype);
		  
		String basedir = OUTPUT_BASE + texttype + "/";
		  
		if(applyInfoGain){
			AttributeSelection selector = new AttributeSelection();
			InfoGainAttributeEval infoGainEval = new InfoGainAttributeEval();
			infoGainEval.setBinarizeNumericAttributes(true);
			
			Ranker simpleRanker = new Ranker();
			//simpleRanker.setNumToSelect(maxNumSelect);
			simpleRanker.setThreshold(treshold);
			
			selector.setEvaluator(infoGainEval);
			selector.setSearch(simpleRanker);
			selector.setInputFormat(bowRawData);
			
			//new method - rerun info gain for ouput
			writeInfoGainValuesNew(texttype, bowRawData);
			
			
			Instances dataInfoApplied = Filter.useFilter(bowRawData, selector); // das brauchen wir weiterhin, info gain applien
			
			//old method - use existing info...
			writeInformationGainValues(simpleRanker, texttype, bowRawData);
			
			writeToArff(dataInfoApplied, texttype, OUTPUT_BASE + texttype + "/bow_java_InfoGain_" + texttype + ".arff");
			
			runClassifiers(dataInfoApplied, basedir, texttype);
		}else{
			//no info gain => run classifiers on raw instances.
			runClassifiers(bowRawData, basedir, texttype);
		}
		  
		
	}
	
	/**
	 * One of two helper methods for printing the calculated info gain values. This method will read the values from the ranker,
	 * and thus not recalculate IG. The output will be sorted by descending IG values and be of the form:
	 * WORD\tFeatureID\tIGValue
	 * @param simpleRanker
	 * @param texttype
	 * @param rankedInstances
	 */
	private void writeInformationGainValues(Ranker simpleRanker, String texttype, Instances rankedInstances){
		try{
			PrintWriter infoWriter = new PrintWriter(OUTPUT_BASE + texttype + "/java_InfoGain_Values_Old" + texttype + ".txt");
			
			StringBuilder output = new StringBuilder();
			
			int i = 0;
			System.out.println("WordString\tAttributeID\tInfoGain");
			NumberFormat nf = new DecimalFormat("0.###################################E0");
			nf.setMinimumFractionDigits(25);
			nf.setMaximumFractionDigits(25);
			for(double[] d : simpleRanker.rankedAttributes()){
				output.append(rankedInstances.attribute((int) d[0]).name() + "\t" + d[0] + "\t" + nf.format(d[1]) + "\n");
				i++;
			}
			
			infoWriter.write(output.toString());
			infoWriter.flush();
			infoWriter.close();
		}catch(Exception e){
			System.out.println("Problem outputting info gain");
			e.printStackTrace();
		}
	}
	
	
	/**
	 * Another method for printing information gain values. This method will recalcualte the IG for printing. The output
	 * will not be sorted and is in the order if WEKA's feature ids.
	 * 
	 * Output:
	 * WORD\tIGValue
	 * 
	 * @param texttype
	 * @param unfilteredData
	 */
	private void writeInfoGainValuesNew(String texttype, Instances unfilteredData){
		System.out.print("Reapplying InfoGain for calculation and output...");
		System.out.println("");
		try{
			PrintWriter infoWriter = new PrintWriter(OUTPUT_BASE + texttype + "/java_InfoGain_Values_New_" + texttype + ".txt");
			
			InfoGainAttributeEval infoGainEval = new InfoGainAttributeEval();
			infoGainEval.setBinarizeNumericAttributes(true);
			
			//run the info gain
			infoGainEval.buildEvaluator(unfilteredData);
			
			StringBuilder result = new StringBuilder();
			StringBuilder zeroList = new StringBuilder();
			
			for(int i = 0; i < unfilteredData.numAttributes(); i++){
				if(infoGainEval.evaluateAttribute(i) > 0){
					result.append(unfilteredData.attribute(i).name() + ":\t" + infoGainEval.evaluateAttribute(i) + "\n");
				}else{
					zeroList.append(unfilteredData.attribute(i).name() + ":\t" + infoGainEval.evaluateAttribute(i) + "\n");
				}
			}
			
			infoWriter.write(result.append(zeroList).toString());
			infoWriter.flush();
			infoWriter.close();
			
			
		}catch(Exception e){
			System.out.println("Problem outputting info gain");
			e.printStackTrace();
		}
		
		
		System.out.println("\t[FINISHED]");		
	}
	
	
	/**
	 * Method to create the BOW features using the WEKA text directory loader.
	 * 
	 * See the document on bow featue creation for more details on how this works.
	 * 
	 * @param dirString
	 * @return
	 */
	public Instances createBOW(String dirString){
	  	try{
		// convert the directory into a dataset
	    TextDirectoryLoader loader = new TextDirectoryLoader();    
	    loader.setDirectory(new File(dirString));
	    Instances dataRaw = loader.getDataSet();
	    
	    
	    // apply the StringToWordVector to create bow representation of the textsd
	    StringToWordVector filter = new StringToWordVector();
	    
	    //WARNING: If you don't set this weka will only use 1000 features by default!!
	    filter.setWordsToKeep(20000);
	    filter.setLowerCaseTokens(false);
	    //check if WC enabled and then set the property
	    if(wordCount){
	    	filter.setOutputWordCounts(true);
	    	filter.setMinTermFreq(minWordCount);
	    }
	    
	    filter.setInputFormat(dataRaw);
	    Instances dataFiltered = Filter.useFilter(dataRaw, filter);
	    
	    //find out how many features the BOW contains#
	    System.out.println("StringToWordVector generated Instances with " + dataFiltered.numAttributes() + " different attributes");
	    
	    //randomize set, because now its sorted by class
	    dataFiltered.randomize(new Random(1));
	    return dataFiltered;	
	  	}
	  	catch(Exception e){
	  		System.out.println("Problem creating BOW");
	  		e.printStackTrace();
	  	}
	    return null;    
	  }

  /************************
   * Some Helper methods for writing instances objects to arff files
   ************************/
  public void writeToArff(Instances dataFiltered, String texttype, boolean inRootDir){
	  String filename = OUTPUT_BASE + texttype + "/bow_java_" + texttype + ".arff";
	  if(inRootDir){
		  filename = OUTPUT_BASE + "bow_java_" + texttype + ".arff";
	  }
	  writeToArff(dataFiltered, texttype, filename);
  }
  
  public void writeToArff(Instances dataFiltered, String texttype){
	  String filename = OUTPUT_BASE + texttype + "/bow_java_" + texttype + ".arff";
	  writeToArff(dataFiltered, texttype, filename);
  }
  
  public void writeToArff(Instances dataFiltered, String texttype, String filename){
	//writing it to an arff
    try{
    	// Create file
    	File arffOutput = new File(filename);
    	arffOutput.createNewFile();
    	FileWriter fstream = new FileWriter(arffOutput);
    	BufferedWriter out = new BufferedWriter(fstream);
    	out.write(dataFiltered.toString());
    	//Close the output stream
    	out.close();
    	System.out.println("Written to file " + filename);
	}catch (Exception e){//Catch exception if any
	  System.err.println("Error: " + e.getMessage());
	}
  }
  
  public void runClassifiers(Instances dataFiltered, String basedir, String texttype) throws Exception{
	  if(MV3){
		  runClassifiersMajorityVote(dataFiltered, basedir, texttype);
	  }else{
		  runClassifiersCrossValidate(dataFiltered, basedir, texttype);
	  }
  }

  /******************************
   * Run all classifiers with static training and test set. Perform Majority vote
   ******************************/

  /**
   * Method to run the classifiers if majority vote is enabled. If cross validation is disabled
   * it will run it with a static training/test set. If it is enabled cross validation
   * provided by weka will be used.
   * 
   * @param dataFiltered
   * @param basedir
   * @param texttype
   * @throws Exception
   */
  public void runClassifiersMajorityVote(Instances dataFiltered, String basedir, String texttype) throws Exception{
	  //partition data in training and test set.
	  Instances[] sets = getTrainingTest(dataFiltered, texttype);
	  Instances trainingSet = sets[0];
	  Instances testSet 	= sets[1];
	  
	  
	  if(validateTimes == 1){
		  //train all classifiers against the training set, and test them with the test set.
		  //also print the results to debug output and csv
		  trainAndEvaluateClassifiersAlone(testSet, trainingSet, basedir, texttype);
	  }else{  //cross validate
		  runClassifiersCrossValidate(dataFiltered, basedir, texttype);
	  }
	  
	  
	  
	  //1. create the majority classifier
	  System.out.println("Now running MV3");
	  Vote v = new Vote();  // works like a usual classifier, but votes over e.g. 3
	 
	  //2. put all new classifier objects in an array for later use in majority vote
	  Classifier[] votingClassifiers = new Classifier[usedClassifiersMV3.size()];
	  int i = 0;
	  for(Map.Entry<String, Classifier> singleClassifier : usedClassifiersMV3.entrySet()){
		  votingClassifiers[i] = singleClassifier.getValue();
		  i++;
	  }
	  System.out.println("Now have rebuildt classifiers for MV3: " + usedClassifiersMV3.size() + " classifiers and they are new.");
	  
	  
	  //3. use these classifiers for the majority vote
	  v.setClassifiers(votingClassifiers);
	  
	  //4. say we want to use MAJORITY as voting rule
	  v.setCombinationRule(new SelectedTag(Vote.MAJORITY_VOTING_RULE, Vote.TAGS_RULES));
	  
	  System.out.print("Training classifiers... ");
	  Evaluation eval = null;
	  if(validateTimes > 1){
			//5. train all the classifiers and test them with cross validation
			eval = new Evaluation(dataFiltered);
			eval.crossValidateModel(v, dataFiltered, validateTimes, new Random());
			System.out.println("\t[FINISHED]");
	  }else{
		  	//5a. train all the classifiers
			v.buildClassifier(trainingSet);
			System.out.println("\t[FINISHED]");
			  
			//5b. test the classifiers in majority vote mode
			eval = new Evaluation(trainingSet);
			eval.evaluateModel(v, testSet); 
	  }
	 
	  //6. write it to the classifier debug file
	  String outputFilename = basedir + "MAV.output";
	  outputResult("MAV", eval, outputFilename);
	  
	  //7. add to CSV file
	  NumberFormat nf = NumberFormat.getPercentInstance();
	  NumberFormat nfNormal = NumberFormat.getInstance();
	  nfNormal.setMaximumFractionDigits(2);
	  nf.setMaximumFractionDigits(2);
	  double unweightedAverageRecall =(eval.recall(0) + eval.recall(1))/2;
	  csv.write(";" + nf.format(unweightedAverageRecall) + ";" + nf.format(eval.weightedPrecision()) + ";" + nfNormal.format(eval.pctCorrect()) + "%", texttype);
	  csv.write("\n", texttype);
  }
  
  /**
   * The method for unnning the classifiers without majority vote.
   * @param testSet
   * @param trainingSet
   * @param basedir
   * @param texttype
   * @throws Exception
   */
  private void trainAndEvaluateClassifiersAlone(Instances testSet, Instances trainingSet, String basedir, String texttype) throws Exception{
	  csv.write(texttype, texttype);
	  for(Map.Entry<String, Classifier> singleClassifier : usedClassifiers.entrySet()){
		  System.out.print("Now running " + singleClassifier.getKey());
		  
		  //1. train classifier
		  Classifier usedClassifier = singleClassifier.getValue();
		  usedClassifier.buildClassifier(trainingSet);
		  
		  //2. test classifier on test set
		  Evaluation eval = new Evaluation(trainingSet);
		  eval.evaluateModel(singleClassifier.getValue(), testSet);
		  
		  //3. save the results
		  classificationResults.put(singleClassifier.getKey(), eval);
		  System.out.print("\t[FINISHED]\n");
		  
		  //4. output the result to the single classifiers debug file
		  String outputFilename = basedir + singleClassifier.getKey() + ".output";
		  outputResult(singleClassifier.getKey(), eval, outputFilename);
		  
		  //5. add to CSV file
		  NumberFormat nf = NumberFormat.getPercentInstance();
		  NumberFormat nfNormal = NumberFormat.getInstance();
		  nfNormal.setMaximumFractionDigits(2);
		  nf.setMaximumFractionDigits(2);
		  double unweightedAverageRecall =(eval.recall(0) + eval.recall(1))/2;
		  csv.write(";" + nf.format(unweightedAverageRecall) + ";" + nf.format(eval.weightedPrecision()) + ";" + nfNormal.format(eval.pctCorrect()) + "%", texttype);
	  }
  }
  
  
  /**
   * Create test and training set with a static 80/20 split. Will randomize the data set before splitting.
   * @param dataFiltered the raw data input
   * @param texttype the texttype that is included in the raw data
   * @return an array of instances, which has training set as first and test set as second entry.
   */
  private Instances[] getTrainingTest(Instances dataFiltered, String texttype){
	  //randomize instances
	  dataFiltered.randomize(new Random());
	  
	  Instances trainingSet = new Instances(dataFiltered);
	  Instances testSet = new Instances(dataFiltered);
	  
	  int trainSize = (80 * dataFiltered.numInstances()) / 100;
	  int testSize = dataFiltered.numInstances() - trainSize;
	  
	  trainingSet = new Instances(dataFiltered, 0, trainSize);
	  testSet = new Instances(dataFiltered, trainSize, testSize);
	  
	  //write out all arff files
	  writeToArff(testSet, texttype + "_test_", true);
	  writeToArff(trainingSet, texttype + "_train_", true);
	  
	  Instances[] sets = new Instances[2];
	  sets[0] = trainingSet;
	  sets[1] = testSet;
	  
	  return sets;
  }
  
  /**
   * Run all classifiers with the cross validation algorithm
   * @param dataFiltered
   * @param basedir
   * @param texttype
   * @throws Exception
   */
  public void runClassifiersCrossValidate(Instances dataFiltered, String basedir, String texttype) throws Exception{	  	  
	  csv.write(texttype, texttype);
	  
	  for(Map.Entry<String, Classifier> singleClassifier : usedClassifiers.entrySet()){
		  System.out.print("Now running " + singleClassifier.getKey());
		  Evaluation eval = new Evaluation(dataFiltered);
		  eval.crossValidateModel(singleClassifier.getValue(), dataFiltered, Classify.validateTimes, new Random(1));
		  
		  classificationResults.put(singleClassifier.getKey(), eval);
		  System.out.print("\t[FINISHED]\n");
		  
		  String outputFilename = basedir + singleClassifier.getKey() + ".output";
		  outputResult(singleClassifier.getKey(), eval, outputFilename);
		  
		  //add to CSV file
		  NumberFormat nf = NumberFormat.getPercentInstance();
		  NumberFormat nfNormal = NumberFormat.getInstance();
		  nfNormal.setMaximumFractionDigits(2);
		  nf.setMaximumFractionDigits(2);
		  double unweightedAverageRecall =(eval.recall(0) + eval.recall(1))/2;
		  csv.write(";" + nf.format(unweightedAverageRecall) + ";" + nf.format(eval.weightedPrecision()) + ";" + nfNormal.format(eval.pctCorrect()) + "%", texttype);
	  }
	  if(!MV3)
		  csv.write("\n", texttype);
  }
 
  /**
   * Method for generating a debug output file for a single run on a single classifier. Will extract the data from the evaluation
   * object.
   * @param classifierName
   * @param eval
   * @param filename
   * @throws Exception
   */
  public void outputResult(String classifierName, Evaluation eval, String filename) throws Exception{
	    File f = new File(filename);
	    f.createNewFile();
	    PrintWriter out = new PrintWriter(f);
	  
	  	out.println("\n\n------------------------------------------------");
	  	out.println("Ergebnis - " + classifierName);
	    out.println(eval.toSummaryString());
	    out.println("F-Measure\tPrecision\tRecall");
	    out.println(eval.weightedFMeasure() + "\t" + eval.weightedPrecision() + "\t" + eval.weightedRecall());
	    out.println(eval.toMatrixString());
	    
	    out.close();
  }
  
  
  
  
  
  




}