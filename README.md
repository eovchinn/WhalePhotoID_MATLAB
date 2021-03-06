WhalePhotoID MATLAB
===================

This repository contains a [SIFT](http://www.vlfeat.org/overview/sift.html)-based algorithm for whale photo identification written in MATLAB. 

**ATTENZIONE!** This code is *not* cleaned and *not* optimized.

---

**HOW TO RUN**

Main script for running: `matching_siftbased_with_reduction`

**Input**: directory 'DIRNAME' containing

1. whale images in .jpg
2. subdirectory 'masks' with inside-whale masks (if there is an image /DIRNAME/ABC.jpg, then there should be a mask /DIRNAME/masks/ABSMask.jpg). 
		The image within the inside-whale mask has white (255,255,255) pixels in the region inside the whale, and black pixels (0,0,0) everywhere else.
3. optional - .xls file containing two colums of the form: "whale_image_file_name whale_id" (gold standard)

**Output**: Matches between each two images stored in 'DIRNAME':

1. dump of Matlab results in .mat
2. image names and number of matches in .xls
3. visualization of matches in .png

---

**ALGORITHM DESCRIPTION**

1. For each image find SIFT features (`vl_sift`)
	+ Calculate SIFT features in the dilated inside-whale region, i.e. mask dilated by mask_height * mask_dilation_rad_percent
	+ Find features with centers inside the eroded inside-whale region, i.e. mask eroded by mask_height * mask_erosion_rad_percent
	
2. Find matches of SIFT features for each two images (`vl_ubcmatch`)

3. Reduce number of matches based on kNN_k (parameter) nearest neighbors of each match (`kNN_matches_reduction` with parameters kNN_k, KNN_RED_PARAM)
```
For each two images i1 and i2
	Iterate
		For each match (m1,m2), where m1 is a feature in i1 and m2 is the matched feature in i2
			find kNN_k nearest neighbors of m1 in i1 (NN1) and m2 in i2 (NN2)
			compute how many NN1 are not matched to some NN2 (diff(m1,m2))
		If there is a match (mi,mj) with diff(mi,mj) > KNN_RED_PARAM (parameter)
		Then 
			remove match (mk,mt) with max diff(mk,mt) 
		Else
			stop iteration
```				
4. Reduce number of matches based on pairwise angles between kNNangl_k (parameter) nearest neighbors of each match (`kNNangles_matches_reduction`)
```
For each two images i1 and i2 
	Iterate
		For each match (m1,m2), where m1 is a feature in i1 and m2 is the matched feature in i2
			find kNNangl_k nearest neighbors of m1 in i1 (NN1)
			take matches of the features NN1 in i2 (NM2)
			compute differences between all angles (m11,m1,m12) and (m21,m2,m22), where 
				a) m11, m12 are in NN1 and m21,m22 are in NM2,
				b) m11 is matched to m21, m12 is matched to m11
			compute the average difference over kNNangl_k maximal differences (average_diff(m1,m2))
		If there is a match (mi,mj) with average_diff(mi,mj) > KNNANGL_RED_THRESH (parameter)
		Then 
			remove match (mk,mt) with max average_diff(mk,mt)
			reduce number of matches based on kNNangl_k (parameter) nearest neighbors of each match (`kNN_matches_reduction` with parameters kNNangl_k, KNN_RED_PARAM)
		Else
			stop iteration
```				
5. Remove matched feature configurations that are horizontally flipped (`horientation_matches_reduction`)
```
For each two images i1 and i2
	find the most left and right features (l and r) in i1 that are mapped to some features in i2
	find mappings (l,lm) and (r,rm), where lm and rm are features in i2
	If lm > rm on the horizontal scale
	Then remove all matches between i1 and i2
```
6. For each two images, output matches

---

**NOTE:**

In the real use case, algorithm step 1 is done after an image is uploaded and the whale region is selected. 
For each image, SIFT features (double matrix) are stored in the DB. Other steps are done when matching a new
image with images stored in the DB.

---

**EXAMPLE**

Different whales:

![Fig.](https://raw.github.com/eovchinn/WhalePhotoID_MATLAB/master/imgs/197644226_604058ba71_o--4761279590_aa5069c279_o_features.png)

Same whale:

![Fig.](https://raw.github.com/eovchinn/WhalePhotoID_MATLAB/master/imgs/3899580142_edd4015731_o--3900667385_99c994378f_o_features.png)


