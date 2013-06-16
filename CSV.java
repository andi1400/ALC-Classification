import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.HashMap;
import java.util.Map;

import weka.classifiers.Classifier;

/**
 * A class for managing the csv output for the ALC classification code.
 * For each test run an individual csv will be created. Additionally there is a global CSV file
 * where each testrun is appended to. There are different global csv files per document class and one for 
 * combined classes.
 *
 */
public class CSV {
	//The global csv output file for the combined documents
	private final String GLOBAL_DEBUG_OUTPUT = "/home/bas-alc/test/output/GLOBAL_DEBUG";
	
	
	File fcsv;
	File fdebug;
	PrintWriter csv;
	PrintWriter debug;
	
	//hash map to hold the global csv output files for the per doc class output files.
	//hashed by document class => Printwriter
	HashMap<String, PrintWriter> partitionedFiles = new HashMap<String, PrintWriter>();
	boolean separated = false;
	
	public CSV(String filename, boolean separated){
		this.separated = separated;
		try{
			
			partitionedFiles.put("DP", new PrintWriter(new FileWriter(new File(GLOBAL_DEBUG_OUTPUT + "_DP.csv"), true)));
			partitionedFiles.put("DQ", new PrintWriter(new FileWriter(new File(GLOBAL_DEBUG_OUTPUT + "_DQ.csv"), true)));
			partitionedFiles.put("EC", new PrintWriter(new FileWriter(new File(GLOBAL_DEBUG_OUTPUT + "_EC.csv"), true)));
			partitionedFiles.put("LN", new PrintWriter(new FileWriter(new File(GLOBAL_DEBUG_OUTPUT + "_LN.csv"), true)));
			partitionedFiles.put("LS", new PrintWriter(new FileWriter(new File(GLOBAL_DEBUG_OUTPUT + "_LS.csv"), true)));
			partitionedFiles.put("LT", new PrintWriter(new FileWriter(new File(GLOBAL_DEBUG_OUTPUT + "_LT.csv"), true)));
			partitionedFiles.put("MP", new PrintWriter(new FileWriter(new File(GLOBAL_DEBUG_OUTPUT + "_MP.csv"), true)));
			partitionedFiles.put("MQ", new PrintWriter(new FileWriter(new File(GLOBAL_DEBUG_OUTPUT + "_MQ.csv"), true)));
			partitionedFiles.put("RA", new PrintWriter(new FileWriter(new File(GLOBAL_DEBUG_OUTPUT + "_RA.csv"), true)));
			partitionedFiles.put("RR", new PrintWriter(new FileWriter(new File(GLOBAL_DEBUG_OUTPUT + "_RR.csv"), true)));
			partitionedFiles.put("RT", new PrintWriter(new FileWriter(new File(GLOBAL_DEBUG_OUTPUT + "_RT.csv"), true)));
			
			
			  fcsv = new File(filename);
			  fcsv.createNewFile();
			  csv = new PrintWriter(new FileWriter(this.fcsv, true));
			  
			  fdebug = new File(GLOBAL_DEBUG_OUTPUT + "_COMBINDED.csv");
			  debug = new PrintWriter(new FileWriter(fdebug, true));
		  }catch(IOException e){
			  e.printStackTrace();
		  }
	}
	
	
	public void createCSVHeader(HashMap<String, Classifier> availableClassifiers, boolean mav, String testconfig, boolean printHeader){
		//write to debug which test this is
		if(printHeader)
			writeHeaderToDebug(testconfig + "\n");
		
		//create an empty cell at the beginning of the table
		csv.write(";");
		
		if(printHeader){
			writeHeaderToDebug(";");
		}
		
		//create a field with the name of the classifier in the middle of each 3 cells
		for(Map.Entry<String, Classifier> entry : availableClassifiers.entrySet()){
			csv.write(";" + entry.getKey() + ";;");
			
			if(printHeader)
				writeHeaderToDebug(";" + entry.getKey() + ";;");
		}
		
		if(mav){
			csv.write(";Majority;;");
			
			if(printHeader)
				writeHeaderToDebug(";Majority;;");
		}
		csv.write("\n");
		
		if(printHeader)
			writeHeaderToDebug("\n");
		
		//create the cells, containing the different measures, F-measure - Precision - Correctly Classified Instances
		for(Map.Entry<String, Classifier> entry : availableClassifiers.entrySet()){
			csv.write(";F;P;CCI");
			
			if(printHeader)
				writeHeaderToDebug(";UAR;P;CCI");
		}
		
		//if majority vote enabled, print once more
		if(mav){
			csv.write(";F;P;CCI");
			
			if(printHeader)
				writeHeaderToDebug(";UAR;P;CCI");
		}
		
		
		csv.write("\n");
		
		if(printHeader)
			writeHeaderToDebug("\n");
		
		csv.flush();
		debug.flush();
		for(PrintWriter p : partitionedFiles.values()){
			p.flush();
		}
	}
	  
	public void closeCSVPrinter(boolean printHeader){
		if(printHeader){
			writeHeaderToDebug("\n\n");
		}
		
		csv.close();
		debug.close();
		
		for(PrintWriter p : partitionedFiles.values()){
			p.close();
		}
	}
	
	public void write(String text, String partition){
		csv.write(text);
		csv.flush();
		
		writeToDebug(text, partition);
	}
	
	private void writeToDebug(String text, String partition){
		if(partition != null && !partition.contains("com")){
			partitionedFiles.get(partition).write(text);
			partitionedFiles.get(partition).flush();
		}else{
			debug.write(text);
			debug.flush();
		}
	}
	
	private void writeHeaderToDebug(String toWrite){
		if(separated){
			for(PrintWriter pw : partitionedFiles.values()){
				pw.write(toWrite);
				pw.flush();
			}
		}else{
			debug.write(toWrite);
			debug.flush();
		}
	}

}
