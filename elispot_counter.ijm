

run("Close All");

#@ File (label = "Choose source directory", style = "directory" ) dir1 
#@ File (label = "Choose output directory", style = "directory" ) dir2 
#@ Integer (label = "Kernel size for Large Spot Filter", style = "spinner", value=5000) BigSpotSize 
#@ Integer (label = "Intensity Threshold for Large Spots", style = "spinner", value=22) bigSpotThresh
#@ Integer (label = "Intensity Threshold for Small Spots", style = "spinner", value=10) smallSpotThresh
#@ Boolean (label = "Backgound subtraction", value=true) doBackgroundSub
#@ Boolean (label = "Allow small Spots", value=true) allowSmallSpots 
#@ Boolean (label = "Save Masks", value=true) saveMasks

var backgroundThreshold = 250; //hardcoded but check if wrong - this is for determinging the well region

flist = getFileList(dir1);

//Open image files
run("Image Sequence...", "open="+dir1+" sort");

//Register stack to make sure all wells centered
run("StackReg", "transformation=[Rigid Body]");


//Setup results table 
Table_Heading = "Elispot Counts";
columns = "Well,nSpots,TotalArea";
columns = split(columns,",");
table = generateTable(Table_Heading,columns);


regI = getTitle();

//project to get background image
run("Z Project...", "projection=[Median]");
meanI = getTitle();

//get difference of each image from the background
imageCalculator("Difference create 32-bit stack", regI,meanI);

run("8-bit");
if(doBackgroundSub){
	run("Subtract Background...", "rolling=50 stack");
}


//get well boundary 
getWellSoon(meanI);

selectWindow(regI);

//run through Stack if images
for(s=1;s<=nSlices;s++){
	selectWindow(regI);
	Stack.setSlice(s);
	well = getFilename();

	run("Duplicate...","title="+well);
	run("Duplicate...","title="+well+"tmp");
	
	tmpWell=getTitle();

	//filter and get large spots
	run("8-bit");
	run("Gray Scale Attribute Filtering", "operation=[Bottom Hat] attribute=Area minimum="+BigSpotSize+" connectivity=4");	
	setThreshold(bigSpotThresh,255);
	run("Convert to Mask");
	rename("BigSpots");

	//not sure if necessary - but allowing smaller spots
	if(allowSmallSpots){
		selectWindow(tmpWell);
		run("Gray Scale Attribute Filtering", "operation=[Bottom Hat] attribute=Area minimum="+50+" connectivity=4");	
		setThreshold(smallSpotThresh,255);	
		run("Convert to Mask");
		rename("smallSpots");
		imageCalculator("OR create", "BigSpots","smallSpots");
		
	}
	
	rename("allSpots");
	
	//make Boundary ROI
	selectWindow("well_well_well");
	run("Analyze Particles...", "size=10-Infinity display clear add");
	selectWindow("allSpots");
	roiManager("Select",0);

	//Analyse spots within well ROI
	run("Clear Results");
	run("Analyze Particles...", "size=10-Infinity display clear add");
	selectImage(well);
	roiManager("Show All without Labels");
	nSpots = roiManager("Count");
	totalArea = 0;
	print("nSpots = " + nSpots);
	
	if(nSpots>0 && nResults()>0) {
		for(i=0;i<nSpots;i++){
			a = getResult("Area",i);
			totalArea = totalArea + a;
		}
		res = newArray(well,nSpots,totalArea);
		
	}else{
		res = newArray(well,0,0);
	}

	
	logResults(table,res);
	if(saveMasks){
		roiManager("Set Color", "blue");
		roiManager("Set Line Width", 0);
		run("Flatten");
		saveAs("TIF",dir2+File.separator()+well+"_mask.tif");		
	}

	//cleanUp(
	close(well);
	close("*_mask.tif");
	close("*spots");
	close(well+"tmp");
	close(tmpWell);
	
	selectWindow(regI);	
	
}


saveTable(Table_Heading);
exit("DONE! Check table is saved");


function getWellSoon(meanI){
	/*Function to find the well region 
	Threshold hard-coded*/	
	selectWindow(meanI);
	
	run("8-bit");
	//setThreshold(0,209);//250
	setThreshold(0,backgroundThreshold);
	run("Convert to Mask");
	run("Keep Largest Region");
	rename("well_well_well");
	
	close(meanI);
	
}

function getFilename(){
	/*convenience function return filename from stack*/ 
	a = getInfo("image.subtitle");
	a1 = indexOf(a,"(");
	a2 = indexOf(a,")");	
	f = substring(a,a1+1,a2);
	return f;
}


//Generate a custom table
//Give it a title and an array of headings
//Returns the name required by the logResults function
function generateTable(tableName,column_headings){
	if(isOpen(tableName)){
		selectWindow(tableName);
		run("Close");
	}
	tableTitle=tableName;
	tableTitle2="["+tableTitle+"]";
	run("Table...","name="+tableTitle2+" width=600 height=250");
	newstring = "\\Headings:"+column_headings[0];
	for(i=1;i<column_headings.length;i++){
			newstring = newstring +" \t " + column_headings[i];
	}
	print(tableTitle2,newstring);
	return tableTitle2;
}


//Log the results into the custom table
//Takes the output table name from the generateTable funciton and an array of resuts
//No checking is done to make sure the right number of columns etc. Do that yourself
function logResults(tablename,results_array){
	resultString = results_array[0]; //First column
	//Build the rest of the columns
	for(i=1;i<results_array.length;i++){
		resultString = toString(resultString + " \t " + results_array[i]);
	}
	//Populate table
	print(tablename,resultString);
}



function saveTable(temp_tablename){
	selectWindow(temp_tablename);
	saveAs("Text",dir2+temp_tablename+".txt");
}
