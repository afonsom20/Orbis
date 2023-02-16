/// --- ORBIS v0.8.4 --- ///
orbisVersion = "0.8.4";

// Let the user decide the input directory
inputDir = getDirectory("Choose source directory");

// Get the date and time to register in the log file
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
date = newArray(6);
date[0] = year;
date[1] = month + 1;
date[2] = dayOfMonth;
date[3] = hour;
date[4] = minute;
date[5] = second;

// Get the files inside the folder chosen as input directory
fileList = getFileList(inputDir);
imageList = newArray(); 

//Filter the imageList to only include files with .tif or .jpg extension
imgExtensions = newArray(".tif", ".TIF", ".jpg", ".JPG", ".png", ".PNG", ".jpeg", ".JPEG", ".fits", ".FITS", ".bmp", ".BMP");

for (i = 0; i < fileList.length; i++) 
{
	for (j = 0; j < imgExtensions.length; j++) 
	{
		if (endsWith(fileList[i], imgExtensions[j]))
		{
			imageList = Array.concat(imageList, fileList[i]);
		}
	}
}

// If the imageList is empty, that means either that: 
// 1 - There are no images in the selected input directory
// 2 - There are images, but they are of unsupported file types
// If either is true, an error dialog is created
if (imageList.length == 0) 
{
	exit("Error - no images found in selected folder, at least of supported file types. Supported extensions: .tif, .jpg, .jpeg, .png, .fits, .bmp");
}

///// PROCESSING FUNCTIONS /////
function PreProcess()
{
	// Select the rectangle and crop the image to contain only the selected area. This saves processing time (smaller image)
	// Define the crop amounts depending on the zoom/crop factor chosen
	if (crop >= 1) 
	{
		cropWidth = (getWidth() / crop) * getHeight()/getWidth(); 
		cropHeight = getHeight() / crop;
		makeRectangle(getWidth() / 2 - cropWidth / 2, getHeight() / 2 - cropHeight / 2, cropWidth, cropHeight); 
		run("Crop");
	}
	
	// Process image to highlight colony boundaries by removing the background (if user selected it)
	// The rolling radius should be >= to the biggest non-background object, so we make it a bit larger than the selected maxRadius
	if (subtractBackground == "Yes")
	{
		rollingRadius = 1.25 * maxRadius;
		run("Subtract Background...", "rolling="+rollingRadius);
	}
}

function RemoveNoise() 
{ 
	// Remove noise (if user selected it)
	if (denoise == "Low")
		run("Remove Outliers...", "radius=0 threshold=10 which=Bright");
	else if (denoise == "Medium")
		run("Remove Outliers...", "radius=2 threshold=10 which=Bright");
	else if (denoise == "High")
		run("Remove Outliers...", "radius=5 threshold=10 which=Bright"); 
	else if (denoise == "Ultra")
		run("Remove Outliers...", "radius=10 threshold=10 which=Bright"); 
	else if (denoise == "Nuclear")
		run("Remove Outliers...", "radius=25 threshold=10 which=Bright"); 
	else if (denoise == "Desperate")
		run("Remove Outliers...", "radius=50 threshold=10 which=Bright"); 
}

function EnhanceContrast()
{
	// Increase image contrast depending on the user's options
 	if (contrast == "1x")
 		run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None* fast_(less_accurate)");
 	else if (contrast == "2x")
 	{
 		run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None* fast_(less_accurate)");
 		run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None* fast_(less_accurate)");
 	}
 	else if (contrast == "3x")
 	{
 		run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None* fast_(less_accurate)");
 		run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None* fast_(less_accurate)");
 		run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None* fast_(less_accurate)");
 	}
 	
}

function EFA()
{
	PreProcess();
	EnhanceContrast();
		
	// Convert into black and white image
 	run("Find Edges");	
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Select All");
	run("Create Mask");
		
	// Remove noise (if the user selected it). Can be done immediately since the image was already converted into binary previously
	RemoveNoise();
	
	// EFA - Fill holes in the circle (if user selected it)
	if (fillHoles == "Yes") 
	{
		run("Close-");
		run("Fill Holes");
	}
	
	// Find the edges, i.e. highlight the circle
	run("Find Edges");
}

function ATA()
{
	PreProcess();
	
	run("8-bit");
	
	EnhanceContrast();
	
	if (colonyColor == "Light") 
	{
		run("Auto Threshold", "method=Default white");
	}
	else 
	{
		run("Auto Threshold", "method=Default");
	}
		
	// Remove noise (if user selected it). In this case it's done after the Auto Threshold, since that's the function that converts the image into binary
	RemoveNoise();
		
	// Find the edges, i.e. highlight the circle
	run("Find Edges");
}

function TA()
{
	PreProcess();
	EnhanceContrast();

	run("HSB Stack");
	run("Convert Stack to Images");
	selectWindow("Hue");
	close();
	selectWindow("Saturation");
	close();
	selectWindow("Brightness");
	
	setThreshold(thresholdLeft, thresholdRight);
	
	run("Convert to Mask");

	if (brightnessFilterTA == "stop")
		run("Invert");

	run("Close-");
	run("Fill Holes");

	// Invert colors to get a black background so the denoising works
	run("Invert");

	// Remove noise (if user selected it). In this case it's done after the Auto Threshold, since that's the function that converts the image into binary
	RemoveNoise();

	// Find the edges, i.e. highlight the circle
	run("Find Edges");
}

function PreviewTA()
{
	PreProcess();
	EnhanceContrast();
	
	run("Color Threshold...");
	waitForUser("Orbis TA Preview", "Using the Brightness parameter of the Color Threshold, highlight the colony halo,\nand note the minimum and maximum threshold values selected.\n\nWhen you are satisfied, click OK.");
	
	Dialog.create("Orbis");
	Dialog.addMessage("Threshold Algorithm (TA):");
	Dialog.addHelp("https://github.com/afonsom20/orbis");
	Dialog.addChoice("Pass filter ticked on?", brightnessFilterTAChoices)
	Dialog.addSlider("Left (minimum) threshold", 0, 255, 0);
	Dialog.addSlider("Right (maximum) threshold", 0, 255, 255);
	Dialog.show();
	
	passFilterResponse = Dialog.getChoice();
	
	if (passFilterResponse == "No")
	{
		brightnessFilterTA = "stop";
	}
	else 
	{
		brightnessFilterTA = "pass";
	}
	
	thresholdLeft = Dialog.getNumber();
	thresholdRight = Dialog.getNumber();

	selectWindow("Threshold Color");
	run("Close");
}

///// END OF PROCESSING FUNCTIONS /////

readyToStart = false;
while (readyToStart == false) 
{
	// Create parameters with default values
	processingChoices = newArray("TA", "[Deprecated] - ATA", "[Deprecated] - EFA");
	crop = 1;
	contrastChoices = newArray("None", "1x", "2x", "3x");
	contrast = 1;
	brightnessFilterTAChoices = newArray("No", "Yes");
	brightnessFilterTA = "stop";
	var thresholdLeft = 0;
	var thresholdRight = 255;
	subtractBackgroundChoices = newArray("Yes", "No");
	colonyColorChoices = newArray("Light", "Dark");
	denoiseChoices = newArray("None", "Low", "Medium", "High", "Ultra", "Nuclear", "Desperate");
	fillHolesChoices = newArray ("Yes", "No");
	minRadius = 150;
	maxRadius = 500;
	increment = 5;
	resolution = 100;
	circles = 1;
	threshold = 0.0;
	scale = "cm";
	
	// Create initial dialog box
	Dialog.create("Orbis");
	Dialog.addMessage("Welcome to Orbis (v" + orbisVersion + ")! For for more information, click on 'Help' to check the Github repository.");
	Dialog.addHelp("https://github.com/afonsom20/orbis");
	Dialog.addMessage("Please select your preferred image processing algorithm:");
	Dialog.addChoice("Algorithm", processingChoices);
	Dialog.show();
	
	processingChoice = Dialog.getChoice();
	
	// Create dialog box for chosen algorithm
	// DEPRECATED!!!!! EFA - Edge Finding Algorithm
	if (processingChoice == "[Deprecated] - EFA")
	{
		Dialog.create("Orbis");
		Dialog.addMessage("Edge Finding Algorithm (EFA):");
		Dialog.addHelp("https://github.com/afonsom20/orbis");
		Dialog.addNumber("Crop/zoom factor (1 = no cropping)", crop);
		Dialog.addChoice("Enhance contrast", contrastChoices);
		Dialog.addChoice("Subtract background?", subtractBackgroundChoices);
		Dialog.addChoice("Denoising", denoiseChoices);
		Dialog.addChoice("Fill holes", fillHolesChoices);
		Dialog.addNumber("Minimum circle radius", minRadius);
		Dialog.addNumber("Maximum circle radius", maxRadius);
		Dialog.addNumber("Search increment", increment);
		Dialog.addNumber("Transform resolution", resolution);
		Dialog.addNumber("Hough score threshold", threshold);
		Dialog.addString("Scale units defined in 'Analyze -> 'Set Scale'", "cm");
		Dialog.show();
		
		// Set parameter values
		
		crop = Dialog.getNumber();
		contrast = Dialog.getChoice();
		subtractBackground = Dialog.getChoice();
		denoise = Dialog.getChoice();
		fillHoles = Dialog.getChoice();
		minRadius = Dialog.getNumber();
		maxRadius = Dialog.getNumber();
		increment = Dialog.getNumber();
		resolution = Dialog.getNumber();
		scale = Dialog.getString();	
	}
	// DEPRECATED!!! ATA - Fast Threshold Algorithm
	else if (processingChoice == "[Deprecated] - ATA")
	{
		Dialog.create("Orbis");
		Dialog.addMessage("Auto-Threshold Algorithm (ATA):");
		Dialog.addHelp("https://github.com/afonsom20/orbis");
		Dialog.addNumber("Crop/zoom factor (1 = no cropping)", crop);
		Dialog.addChoice("Colony Color", colonyColorChoices);
		Dialog.addChoice("Enhance contrast", contrastChoices);
		Dialog.addChoice("Subtract background?", subtractBackgroundChoices);
		Dialog.addChoice("Denoising", denoiseChoices);
		Dialog.addNumber("Minimum circle radius", minRadius);
		Dialog.addNumber("Maximum circle radius", maxRadius);
		Dialog.addNumber("Search increment", increment);
		Dialog.addNumber("Transform resolution", resolution);
		Dialog.addNumber("Hough score threshold", threshold);
		Dialog.addString("Scale units defined in 'Analyze -> 'Set Scale'", "cm");
		Dialog.show();
		
		// Set parameter values
		crop = Dialog.getNumber();
		colonyColor = Dialog.getChoice();
		contrast = Dialog.getChoice();
		subtractBackground = Dialog.getChoice();
		denoise = Dialog.getChoice();
		minRadius = Dialog.getNumber();
		maxRadius = Dialog.getNumber();
		increment = Dialog.getNumber();
		resolution = Dialog.getNumber();
		scale = Dialog.getString();	
	}
	// TA - Manual Threshold Algorithm
	else if (processingChoice == "TA")
	{
		Dialog.create("Orbis");
		Dialog.addMessage("Threshold Algorithm (TA):");
		Dialog.addHelp("https://github.com/afonsom20/orbis");
		Dialog.addNumber("Crop/zoom factor (1 = no cropping)", crop);
		Dialog.addChoice("Enhance contrast", contrastChoices);
		Dialog.addChoice("Subtract background?", subtractBackgroundChoices);
		Dialog.addChoice("Denoising", denoiseChoices);
		Dialog.addNumber("Minimum circle radius", minRadius);
		Dialog.addNumber("Maximum circle radius", maxRadius);
		Dialog.addNumber("Search increment", increment);
		Dialog.addNumber("Transform resolution", resolution);
		Dialog.addNumber("Hough score threshold", threshold);
		Dialog.addString("Scale units defined in 'Analyze -> 'Set Scale'", "cm");
		Dialog.show();
		
		// Set parameter values
		crop = Dialog.getNumber();
		contrast = Dialog.getChoice();
		subtractBackground = Dialog.getChoice();
		denoise = Dialog.getChoice();
		minRadius = Dialog.getNumber();
		maxRadius = Dialog.getNumber();
		increment = Dialog.getNumber();
		resolution = Dialog.getNumber();
		scale = Dialog.getString();	
	}
	
	///// GENERATE PREVIEW /////
	// Get the first image file in the input directory
	open(inputDir + imageList[0]);
	previewChoices = newArray ("Yes", "No");
	
	// Process preview image with EFA
	if (processingChoice == "[Deprecated] - EFA") 
	{
		EFA();
	} 
	// Process preview image with TA
	else if (processingChoice == "[Deprecated] - ATA") 
	{
		ATA();
	}
	// Process preview image with TA
	else if (processingChoice == "TA")
	{
		PreviewTA();
		close("*");
		open(inputDir + imageList[0]);
		TA();
	}
	
	Dialog.create("Preview");
	Dialog.addMessage("The preview image was processed with the chosen algorithm and parameters.");
	Dialog.addChoice("Are you satisfied with the image treatment?", previewChoices);
	Dialog.show();
	previewChoice = Dialog.getChoice();
	
	if (previewChoice == "Yes") 
	{
		readyToStart = true;
	}
	
	close("*");

	///// END PREVIEW /////
}


///// RESULTS FOLDER /////

// Initialize result arrays
radii = newArray(imageList.length - 1);
areas = newArray(imageList.length - 1);
imageNames = newArray(imageList.length - 1);
speed = newArray(imageList.length - 1);

// Create Results folder inside of the input directory
outputDir = inputDir + File.separator + "Results" + File.separator + date[2] + "-" + date[1] + "-" + date[0] + "_" + date[3] + "-" + date[4] + "-" + date[5];
File.makeDirectory(inputDir + File.separator + "Results"); // first we create the Results directory (if it doesn't existe yet)...
File.makeDirectory(outputDir); // ... and then we create the output directory with the day and time

///// END OF RESULTS FOLDER CREATION /////

// Run this code for every file (image) in the input folder
for (i = 0; i < imageList.length; i++) 
{
	// Close all images
	close("*");
	
	// Get the time at which the image analysis starts to calculate processing speed (endTime - startTime)
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	startHour = hour;
	startMinute = minute;
	startSecond = second;
	
	// Open the image
	open(inputDir + imageList[i]); 
	
	// Register its name
	imageNames[i] = File.name; 
 	
 	// EFA - Highlight edges of colony (initial pass)
 	if (processingChoice == "[Deprecated] - EFA")
 	{
 	 	EFA();
	}
	// ATA - Run Auto Threshold to highlight colony 
	else if (processingChoice == "[Deprecated] - ATA") 
	{
		ATA();
	}
	else if (processingChoice == "TA")
	{
		TA();
	}
	
	// Run plugin to detect circle
	run("Hough Circle Transform","minRadius="+minRadius+", maxRadius="+maxRadius+", inc="+increment+", minCircles=1, maxCircles="+circles+", threshold="+threshold+", resolution="+resolution+", ratio=1.0, bandwidth=10, local_radius=10,  reduce show_mask results_table"); 
	
	openImages = nImages;
	
	// Wait while no images are open, i.e., wait until the plugin to find the circle finishes
	while(openImages==nImages)
		wait(1000); 
	
	// Select the output window created by the plugin
	selectWindow("Centroid overlay");
	
	// Save this image (to check if the selection worked correctly)
	saveAs("png", outputDir + File.separator + imageNames[i]); //save it
	
	// Catch error if the scale units were entered incorrectly
	if (isNaN(getResult("Radius (" + scale + ")"))) 
	{
		exit ("Incorrect scale unit. Go to 'Analyze' -> 'Set Scale' to verify the correct unit, or to change it.");
	}
	
	radii[i] = getResult("Radius (" + scale + ")");
	areas[i] = PI * radii[i] * radii[i];
	
	// Close all images
	close("*"); 
	
	// Get the time at which the image analysis end to calculate processing speed (endTime - startTime)
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	endHour = hour;
	endMinute = minute;
	endSecond = second;
	
	// Calculate image processing speed  
	hoursPassed = endHour - startHour;
	minutesPassed = endMinute - startMinute;
	secondsPassed = endSecond - startSecond;
	
	if (minutesPassed <= 0)
	{		
		hoursPassed -= 1;
		minutesPassed += 60;
	}
	
	if (secondsPassed <= 0)
	{
		minutesPassed -= 1;
		secondsPassed += 60;
	}
	
	// Store speed value in array
	speed[i] = secondsPassed + 60 * minutesPassed + 3600 * hoursPassed;
}

// After processing all images in the input folder, create a table with the data
Table.create("Colony Areas");
Table.setColumn("Name", imageNames);
Table.setColumn("Radius (" + scale + ")", radii);
Table.setColumn("Area (" + scale + ")", areas);

selectWindow("Colony Areas");

// Save the table to a .csv file
saveAs("text", outputDir + File.separator + "colony_areas.csv");

// Saves log with input values and performance data
Array.getStatistics(speed, min, max, averageSpeed, stdDev);

// Also get the total 
totalTime = 0;
for (i = 0; i < speed.length; i++) 
{
	totalTime += speed[i];
}


if (processingChoice == "[Deprecated] - EFA")
{
	logString = "Date - " + date[2] + "-" + date[1] + "-" + date[0] + "_" + date[3] + ":" + date[4] + ":" + date[5] + "\nOrbis version = " + orbisVersion + "\nProcessing algorithm = " + processingChoice + "\nCrop/zoom = " + crop + "\nContrast = " + contrast + "\nSubtract background? = " + subtractBackground + "\nDenoising = " + denoise + "\nFill holes = " + fillHoles +"\nMin. radius = " + minRadius + "\nMax. radius = " + maxRadius + "\nIncrement = " + increment + "\nResolution = " + resolution + "\nThreshold = " + threshold + "\nCircle number = " + circles + "\nScale unit = " + scale + "\nTotal analysis time = " + totalTime + " seconds" + "\nPerformance = " + averageSpeed + " seconds per image (average)";
}
else if (processingChoice == "[Deprecated] - ATA")
{
	logString = "Date - " + date[2] + "-" + date[1] + "-" + date[0] + "_" + date[3] + ":" + date[4] + ":" + date[5] + "\nOrbis version = " + orbisVersion + "\nProcessing algorithm = " + processingChoice + "\nCrop/zoom = " + crop + "\nColony color = " + colonyColor + "\nContrast = " + contrast + "\nSubtract background? = " + subtractBackground + "\nDenoising = " + denoise + "\nMin. radius = " + minRadius + "\nMax. radius = " + maxRadius + "\nIncrement = " + increment + "\nResolution = " + resolution + "\nThreshold = " + threshold + "\nCircle number = " + circles + "\nScale unit = " + scale + "\nTotal analysis time = " + totalTime + " seconds" + "\nPerformance = " + averageSpeed + " seconds per image (average)";
}
else if (processingChoice == "TA")
{
	logString = "Date - " + date[2] + "-" + date[1] + "-" + date[0] + "_" + date[3] + ":" + date[4] + ":" + date[5] + "\nOrbis version = " + orbisVersion + "\nProcessing algorithm = " + processingChoice + "\nCrop/zoom = " + crop + "\nContrast = " + contrast + "\nSubtract background? = " + subtractBackground + "\nDenoising = " + denoise + "\nMin. radius = " + minRadius + "\nMax. radius = " + maxRadius + "\nIncrement = " + increment + "\nResolution = " + resolution + "\nLeft (minimum) threshold = " + thresholdLeft + "\nRight (maximum) threshold = " + thresholdRight + "\nCircle number = " + circles + "\nScale unit = " + scale + "\nTotal analysis time = " + totalTime + " seconds" + "\nPerformance = " + averageSpeed + " seconds per image (average)";
}

File.saveString(logString, outputDir + File.separator + "log.txt");