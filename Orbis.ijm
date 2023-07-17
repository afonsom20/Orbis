/*
 * Orbis is an ImageJ macro to automatically calculate microbial colony areas.  
 * 
 * Copyright (C) 2023 Afonso Morgado Mota
 * 
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 * You should have received a copy of the GNU General Public License along with this program. If not, see https://www.gnu.org/licenses/.
*/

var thresholdLeft = 0;
var thresholdRight = 255;
var firstImageBrightnessMean = 0;

macro "Orbis" 
{
	/// --- ORBIS v1.0.0 --- ///
	orbisVersion = "1.0.0";
	
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
	function Crop()
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
	}
	
	function PreProcess()
	{
		Crop();
		AdjustBrightness();
		
		// Process image to highlight colony boundaries by removing the background (if user selected it)
		// The rolling radius should be >= to the biggest non-background object, so we make it a bit larger than the detected maxRadius
		if (subtractBackground != "Off")
		{
			if(subtractBackground == "Fast")
				rollingRadius = 0.5 * getWidth();
			else if (subtractBackground == "High Quality");
				rollingRadius = 2 * getWidth();
			
			// Limit the rolling radius to restrict processing time
			if (rollingRadius > 2000)
				rollingRadius = 2000;
			
			// Subtract the background
			run("Subtract Background...", "rolling="+rollingRadius);
		}
		
		EnhanceContrast();
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
	
	function ManualThreshold()
	{
		PreProcess();
	
		run("HSB Stack");
		run("Convert Stack to Images");
		selectWindow("Hue");
		close();
		selectWindow("Saturation");
		close();
		selectWindow("Brightness");
		
		setThreshold(thresholdLeft, thresholdRight);
		
		run("Convert to Mask");
	
		if (brightnessFilter == "stop")
			run("Invert");
	
		run("Close-");
		run("Fill Holes");
	
		// Invert colors to get a black background so the denoising works
		run("Invert");
	
		// Remove noise (if user selected it). In this case it's done after the Auto Threshold, since that's the function that converts the image into binary
		RemoveNoise();
		
		if (colonyDetection == "Hough Circle Transform") 
		{
			// Find the edges, i.e. highlight the circle
			run("Find Edges");	
		}
	}
	
	function AutoThreshold()
	{
		PreProcess();
		
		run("8-bit");
	
		run("Auto Threshold", "method=Huang white");
			
		// Remove noise (if user selected it). In this case it's done after the Auto Threshold, since that's the function that converts the image into binary
		RemoveNoise();
			
		run("Measure");
		pixelAverage = getResult("Mean");
		
		// If most pixels in the image are black, the pixelAverage will be low, and we must invert the image colors for "Fill Holes" to work properly
		if (pixelAverage < 123)
			run("Invert");
		
		// Uniformize the circle boundary and its inside color
		run("Close-");
		run("Fill Holes");
		
		// Find the edges, i.e. highlight the circle
		run("Find Edges");
	}
	
	function ManualPreview()
	{
		PreProcess();
		
		run("Color Threshold...");
		waitForUser("Manual Threshold Preview", "Using the Brightness parameter of the Color Threshold, highlight the colony halo,\nand note the minimum and maximum threshold values selected.\n\nWhen you are satisfied, click OK.");
		
		Dialog.create("Orbis");
		Dialog.addHelp("https://github.com/afonsom20/orbis");
		Dialog.addChoice("Pass filter ticked on?", brightnessFilterChoices)
		Dialog.addSlider("Left (minimum) threshold", 0, 255, 0);
		Dialog.addSlider("Right (maximum) threshold", 0, 255, 255);
		Dialog.show();
		
		passFilterResponse = Dialog.getChoice();
		
		if (passFilterResponse == "No")
		{
			brightnessFilter = "stop";
		}
		else 
		{
			brightnessFilter = "pass";
		}
		
		thresholdLeft = Dialog.getNumber();
		thresholdRight = Dialog.getNumber();
	
		selectWindow("Threshold Color");
		run("Close");
	}
	
	function ProcessImage()
	{
		// Process according to the chosen algorithm
		if (processingMode == "Manual Threshold")
			ManualThreshold();	
		else if (processingMode == "Auto Threshold")
			AutoThreshold();
	}
	
	function AdjustBrightness()
	{
		// Get histogram data, including the "mean" which contains the average pixel value, i.e. the mean brightness
		getStatistics(area, initialMean, min, max, std, histogram);
		
		// If we are still in preview mode it means we are using the first image and should register it as the reference/blank for the brightness
		if (readyToStart == false) 
		{
			// Register the brightness mean of this first image to automatically adjust the brightness on later images 
			firstImageBrightnessMean = initialMean;
		}
		// If we are analysing the images for real, then we compare it to the first image. If it's the same image, not changes will be made to the brightness
		else 
		{	
			if (brightnessNormalization == "No")
				return;
			else if (brightnessNormalization == "Yes")
				brightnessAdjustValue = round(1.0 * (firstImageBrightnessMean - initialMean));
					
			setMinAndMax(-brightnessAdjustValue + 1, 255 - brightnessAdjustValue);
			getStatistics(area, mean, min, max, std, histogram);
		}	
	}
	
	///// END OF PROCESSING FUNCTIONS /////
	
	readyToStart = false;
	while (readyToStart == false) 
	{
		// Create parameters with default values
		processingModeChoices = newArray("Manual Threshold", "Auto Threshold");
		colonyDetectionChoices = newArray("Magic Wand", "Hough Circle Transform");
		crop = 1;
		contrastChoices = newArray("None", "1x", "2x", "3x");
		contrast = 1;
		brightnessFilterChoices = newArray("No", "Yes");
		brightnessFilter = "stop";
		subtractBackgroundChoices = newArray("Fast", "High Quality", "Off");
		denoiseChoices = newArray("None", "Low", "Medium", "High", "Ultra", "Nuclear", "Desperate");
		brightnessNormalizationChoices = newArray("No", "Yes");
		minRadius = 150;
		maxRadius = 500;
		increment = 5;
		resolution = 100;
		circles = 1;
		houghThreshold = 0.0;
		scale = "cm";
		
		// Create initial dialog box
		Dialog.create("Orbis");
		Dialog.addMessage("Welcome to Orbis (v" + orbisVersion + ")! For for more information, click on 'Help' to check the Github repository.");
		Dialog.addHelp("https://github.com/afonsom20/orbis");
		Dialog.addMessage("Please select your preferred processing mode and colony detection method:");
		Dialog.addChoice("Processing mode:", processingModeChoices);
		Dialog.addChoice("Colony detection method:", colonyDetectionChoices);
		Dialog.show();
		
		processingMode = Dialog.getChoice();
		colonyDetection = Dialog.getChoice();
		
		// Create dialogue
		Dialog.create("Orbis");
		Dialog.addHelp("https://github.com/afonsom20/orbis");
		Dialog.addNumber("Crop/zoom factor (1 = no cropping)", crop);
		Dialog.addChoice("Enhance contrast", contrastChoices);
		Dialog.addChoice("Subtract background?", subtractBackgroundChoices);
		Dialog.addChoice("Denoising", denoiseChoices);
		Dialog.addChoice("Brightness normalization", brightnessNormalizationChoices);
		Dialog.addString("Scale units defined in 'Analyze -> 'Set Scale'", "cm");
		
		if (colonyDetection == "Hough Circle Transform") 
		{
			Dialog.addNumber("Minimum circle radius", minRadius);
			Dialog.addNumber("Maximum circle radius", maxRadius);
			Dialog.addNumber("Search increment", increment);
			Dialog.addNumber("Transform resolution", resolution);
			Dialog.addNumber("Hough score threshold", houghThreshold);
		}
		
		Dialog.show();
			
		// Set parameter values
		crop = Dialog.getNumber();
		contrast = Dialog.getChoice();
		subtractBackground = Dialog.getChoice();
		denoise = Dialog.getChoice();
		brightnessNormalization = Dialog.getChoice();
		scale = Dialog.getString();	
		
		if (colonyDetection == "Hough Circle Transform") 
		{
			minRadius = Dialog.getNumber();
			maxRadius = Dialog.getNumber();
			increment = Dialog.getNumber();
			resolution = Dialog.getNumber();
			houghThreshold = Dialog.getNumber();
		}
		
		///// GENERATE PREVIEW /////
		previewChoices = newArray ("Yes", "No");
		
		// Create a dialogue for the user to pick the thresholds in case of Manual processing mode 
		if (processingMode == "Manual Threshold")
		{	
			open(inputDir + imageList[0]);
			
			ManualPreview();
			close("*");
		}
		
		// Get the first image file in the input directory to edit as a preview
		open(inputDir + imageList[0]);
		
		// Register the brightness mean of this first image to automatically adjust the brightness on later images 
		getStatistics(area, mean, min, max, std, histogram);
		firstImageBrightnessMean = mean;
	
		ProcessImage();
		
		Dialog.create("Image Processing Preview");
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
	 	
	 	// Highlight edges of colony (initial pass)
		ProcessImage();
		
		if (colonyDetection == "Hough Circle Transform") 
		{
			// Run plugin to detect circle
			run("Hough Circle Transform","minRadius="+minRadius+", maxRadius="+maxRadius+", inc="+increment+", minCircles=1, maxCircles="+circles+", threshold="+houghThreshold+", resolution="+resolution+", ratio=1.0, bandwidth=10, local_radius=10,  reduce show_mask results_table"); 
	
			openImages = nImages;
			
			// Wait while no images are open, i.e., wait until the plugin to find the circle finishes
			while(openImages==nImages)
				wait(1000); 
			
			// Catch error if the scale units were entered incorrectly
			if (isNaN(getResult("Radius (" + scale + ")"))) 
			{
				exit ("Incorrect scale unit. Go to 'Analyze' -> 'Set Scale' to verify the correct unit, or to change it.");
			}
			
			radii[i] = getResult("Radius (" + scale + ")");
			areas[i] = PI * radii[i] * radii[i];
			
			// Select the output window created by the plugin
			selectWindow("Centroid overlay");
			
			run("Measure");
			pixelAverage = getResult("Mean");
		
			// If most pixels in the image are white, the pixelAverage will be high, and we must invert the image colors for "Fill Holes" to work properly
			if (pixelAverage > 123)
			{
				run("Invert");
			}
		}
		else if (colonyDetection == "Magic Wand")
		{
			// Use the magic wand in the middle of the image
			doWand(getWidth()/2, getHeight()/2);	
			
			// Measure area and register it in the array
			run("Measure");
			areas[i] = getResult("Area");
			
			// De-select the magic wand area and select the whole image
			run("Select All");
			// Find the edges of the colony to save the output image for comparison with the original
			run("Find Edges");
			
			if (processingMode == "Manual threshold") 
			{
				// Invert color to have the edges white instead of black
				run("Invert");
			}
		}
		
		// Get the name of the current open image, which contains the colony edges
		colonyEdges = getTitle();
			
		// Open the original image
		open(inputDir + imageList[i]); 	
		imageToOverlay = getTitle();
		
		// Crop original image to be the same size as the result image
		Crop();
		
		// Overlay the resulting image on top of the original
		run("Add Image...", "image=["+colonyEdges+"] x=0 y=0 opacity=75 zero");
		
		// Save this image - the colony edges overlayed into the original picture - to check if the selection worked correctly
		saveAs("png", outputDir + File.separator + imageNames[i]); //save it
		
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
	
	// Write all output variables and parameters into a string
	if (colonyDetection == "Hough Circle Transform")
	{
		logString = "Date - " + date[2] + "-" + date[1] + "-" + date[0] + "_" + date[3] + ":" + date[4] + ":" + date[5] + "\nOrbis version = " + orbisVersion + "\nColony detection method = " + colonyDetection + "\nCrop/zoom = " + crop + "\nContrast = " + contrast + "\nSubtract background = " + subtractBackground + "\nDenoising = " + denoise + "\nMin. radius = " + minRadius + "\nMax. radius = " + maxRadius + "\nIncrement = " + increment + "\nResolution = " + resolution + "\nLeft (minimum) threshold = " + thresholdLeft + "\nRight (maximum) threshold = " + thresholdRight + "\nCircle number = " + circles + "\nBrightness normalization? = " + brightnessNormalization + "\nScale unit = " + scale + "\nTotal analysis time = " + totalTime + " seconds" + "\nPerformance = " + averageSpeed + " seconds per image (average)";
	}
	else if (colonyDetection == "Magic Wand")
	{
		logString = "Date - " + date[2] + "-" + date[1] + "-" + date[0] + "_" + date[3] + ":" + date[4] + ":" + date[5] + "\nOrbis version = " + orbisVersion + "\nColony detection method = " + colonyDetection + "\nCrop/zoom = " + crop + "\nContrast = " + contrast + "\nSubtract background = " + subtractBackground + "\nDenoising = " + denoise + "\nLeft (minimum) threshold = " + thresholdLeft + "\nRight (maximum) threshold = " + thresholdRight + "\nBrightness normalization? = " + brightnessNormalization + "\nScale unit = " + scale + "\nTotal analysis time = " + totalTime + " seconds" + "\nPerformance = " + averageSpeed + " seconds per image (average)";
	}
	
	// Create the log.txt file with the output logString
	File.saveString(logString, outputDir + File.separator + "log.txt");
}