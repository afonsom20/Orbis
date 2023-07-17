<p align="center">
  <img src="https://user-images.githubusercontent.com/62797431/229082913-834277f7-fd01-448f-b3e2-8d1d750e48d6.png" width="544" height="184">
</p>

# Orbis v1.0.0
Orbis is a Fiji/ImageJ macro designed to process batches of images containing microbial colonies, automatically detecting their boundaries and calculating their areas. 
Not only does Orbis provide more objective and precise values when compared to manual measurements, but it also considerably reduces the time needed for the analysis, due to its fast processing time.
Although it was initially designed to measure the areas of fungal colonies, Orbis also works on bacterial colonies.


## Features
- User-friendly interface with multiple customizable parameters and several steps with visual feedback
- Designed to process multiple images with increased speed and precision due to optimization methods like brightness normalization
- Supports multiple image formats (.tif, .jpg, .jpeg, .png, .fits, .bmp)
- Provides preview functionality to test chosen parameters
- Works on circular and irregularly shaped colonies
- Enables background subtraction, contrast enhancement, and denoising to better highlight colony edges
- Automatically creates a results folder with a date and time stamp, containing the analysed images with the colony outlines, the calculated areas for each image, and a log file

### Examples
<p align="center">
  <img src="https://user-images.githubusercontent.com/62797431/229086494-061b8f57-d8ee-40b9-88e1-b6bed70d3f08.png" width="437" height="200">
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://user-images.githubusercontent.com/62797431/229085345-d427e796-7cf0-4c8f-8d4d-681543102028.png" width="460" height="200">
</p>


## Getting Started
- Download and install Fiji (https://imagej.net/software/fiji/downloads)
- Open Fiji
- Install the Hough Circle Transform plugin (follow instructions here: https://imagej.net/plugins/hough-circle-transform)
- Download the Orbis.ijm macro file from this repository
- Go to Plugins > Macros > Install..., and select the downloaded Orbis.ijm file.
- You should now see Orbis under the Plugins > Macros menu. Click on it to run the macro.

### Usage
Run the Orbis macro from the Plugins > Macros menu. You will be prompted to select the source directory containing your images. 
Then you will be able to customize the processing mode, colony detection method, and other parameters according to your needs.
If you choose the manual processing mode, follow the on-screen instructions to set the threshold values, and then review the image processing preview to confirm if you are satisfied with the treatment.
Once you accept, the macro will process all the images in the selected directory, creating a Results folder containing the processed images, with their colony edges highlightd,
a .csv file with the calculated colony areas for each image, and a log file with information about the run.

## Planned Features and Improvements
- Automatic minimum and maximum cirlce radius detection when using Hough Circle Transform
- More flexible colony detection for the Magic Wand method
- GPU-accelerated image processing
- UI and UX improvements

### Contact
I am welcome to contributions to improve Orbis. Please feel free to submit a pull request or report any issues you encounter. For any questions/comments you can also contact me at afonsomm@gmail.com

### Licence
This project is licensed under the GNU General Public License v3 (GPLv3), available here: https://www.gnu.org/licenses/gpl-3.0.html
