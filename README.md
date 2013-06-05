WhalePhotoID MATLAB
===================

This repository contains a [SIFT](http://www.vlfeat.org/overview/sift.html)-based algorithm for whale photo identification written in MATLAB. 

**ATTENZIONE!** This code is *not* cleaned and *not* optimized.

---

**HOW TO RUN**

Main script for running: `matching_siftbased_with_reduction`

**Input**: directory 'DIRNAME' containing

* whale images in .jpg
*subdirectory 'masks' with inside-whale masks (if there is an image /DIRNAME/ABC.jpg, then there should be a mask /DIRNAME/masks/ABSMask.jpg). 
		The image within the inside-whale mask has white (255,255,255) pixels in the region inside the whale, and black pixels (0,0,0) everywhere else.
*optional - .xls file containing two colums of the form: "whale_image_file_name whale_id" (gold standard)

**Output**: Matches between each two images stored in 'DIRNAME':
		1) dump of Matlab results in .mat
		2) image names and number of matches in .xls
		3) visualization of matches in .png

---

**ALGORITHM DESCRIPTION**
