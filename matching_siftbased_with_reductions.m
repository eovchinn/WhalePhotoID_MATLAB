%*********************************************************************************
% This is the main file for matching images of whales (Matlab implementation)
% 
% The script loads all images from the specified folder, considers all possible 
% pairs of images and calculates a matching score between images of each pair.
% 
% The matching score between two images is calculated as follows:
%	1) calculation of SIFT features for each of images 
%	2) considering only those SIFT features which are inside the whale based on manually-created inside-whale mask
%	3) reduction of false positive matches using the kNN-reduction (neighbor sets based reduction)
%	4) reduction of false positive matches using the kNN-angles reduction (spatial configuration based reduction)
%	5) score = number of left pairs of matched features
%
% The both kNN and kNN-angles reduction are implemented as separate scripts modifying global variables.
%
% To run the script, copy it and reduction scripts to a folder, modify the "imgs_folder" variable and other parameters 
% if necessary and evoke it by "matching_siftbased_with_reductions" in the Matlab console. Make sure you change 
% to the folder of the script before evoking it or the script folder is in the PATH, use "addpath" to add path if necessary.
%
% Theodore Alexandrov, Ekaterina Ovchinnikova, theodore@uni-bremen.de, katya@isi.edu
% 05 June 2013
%*********************************************************************************


%%----------------------------- PARAMETERS >>> -----------------------------

% imgs_folder should contain
%	1) images of whales
%	2) subfolder "masks" where for each image "ABC.jpg" from imgs_folder an image with inside-whale mask "ABCMask.jpg" is stored
%		the image with the inside-whale mask has white (255,255,255) pixels in the region inside the whale, and black pixels (0,0,0) everywhere else

% imgs_folder='C:\SCI_TMP\projects\whales\imgs\NOAA-Paula_set2_20120907--kNN_kNNa';
imgs_folder='C:\SCI_TMP\projects\whales\imgs\flickr_Ka_May2013--kNN_kNNa';

% parameters of the gold standard of assigment of whales to classes
%	where the Excel file is stored
classes_fname='C:\SCI_TMP\projects\whales\BmPhotoSubset_ETP_18Jan2012--classes--TA120815.xlsx';
%	what is the name of the Excel-sheet 
classes_sheetname='pic-whale';

% erosion (shrinking) and dilation of the inside-whale mask is used to specify the areas of interest
%	SIFT is calculated for the image inside dilated mask only (to speed up the calculation)
%		not inside eroded mask because at the boundary there is a lot of false matches
%		the "buffer zone" between the dilated and eroded mask is necessary to skip false matches produced at the boundary
%	for matching, only features inside the eroded mask are considered
mask_erosion_rad_percent=0.1; % for finding the radius of erosion adaptively, 0.1 (default) <-> 10%
mask_dilation_rad_percent=0.2; % for finding the radios of dilation adaptively to image size, 0.2 (default) <-> 20%

% parameter for SIFT-matching
%	ratio between euclidean distance of NN2/NN1, default 1.25; smaller value => more sensitive
ubcthresh=1.25;
% parameters for kNN-reduction of matched features
%	how many nearest neighbors for a matched SIFT feature are considered
%	default 5
kNN_k=5; 
% 	how many nearest neighbors can differ in between kNN-neighborhoods of two matched SIFT features
%	default 1, 0 is the most strong reduction, larger values lead to less reduction
KNN_RED_PARAM=1; 
% parameters for kNN-angles reduction of matched features which is applied after kNN-reduction
% 	how many nearetst neighbors for a matcht SIFT feature are considered
%	default 5
kNNangl_k=5;
%	allowed average difference between all angles formed by nearest neighbors in kNN-neighborhoods of two matched SIFT features
%	default 15
KNNANGL_RED_THRESH=15; 
%%----------------------------- <<< PARAMETERS -----------------------------

%% 
timefingerprint=strrep(strrep(strrep(datestr(now),' ','_'),':',''),'-','');

%% load whale classes [should be optional]
[Wclasses,Wfnames]=xlsread(classes_fname,classes_sheetname);
Wfnames=Wfnames(2:end,1);

%% load whale images
imgs_list=dir([imgs_folder '\*.jpg']);
Nimgs=length(imgs_list);

%% initialize data structures for results 
RES_ubcmatch=cell(Nimgs,Nimgs); % matching_results{i,j}={matches,score,F1,F2,D1,D2}, only upper triangle without diagonal
RES_sift=cell(Nimgs,Nimgs);
RES_Nmatches=-1*ones(Nimgs,Nimgs);



%%
% disp('DBG: #image1=2')	% for debugging
for i=1:Nimgs % go over all images
    img1_name=imgs_list(i).name;
    img1mask_name=strrep(img1_name,'.jpg','Mask.jpg');
    
    % load the first image
    Iorig=imread([imgs_folder '\' img1_name]);
    % convert to gray-scale if necessary
    if size(Iorig,3)>1
        I=rgb2gray(Iorig);
    else
        I=Iorig;
    end
    I=imadjust(I,stretchlim(I,[0.001 0.999]),[]); % increase the contrast
    I=single(I); % conversion to single is recommended for vl_sift
    
    % load inside-whale mask
    Imask=imread([imgs_folder '\masks\' img1mask_name]);
    Imask=Imask>128;
	
    % calculate eroded and dilated inside-whale masks
    Ivertsize_mask=sum( sum(Imask,2)>0 ); % number of non-zero pixels projected onto the vertical
    Ierode_rad=ceil(Ivertsize_mask*mask_erosion_rad_percent);
    Imask_er=imerode(Imask,strel('disk',Ierode_rad));
    Idilat_rad=ceil(Ivertsize_mask*mask_dilation_rad_percent);
    Imask_dil=imdilate(Imask,strel('disk',Idilat_rad));
    
    % consider the image only inside the dilated inside-mask
    I(Imask_dil==0)=0;
    
    
    %**********************
    % calculate SIFT features for the first image (key algorithm, external library)
    tic;
    [F1 D1] = vl_sift(I);
    ela_siftI=toc;
    %**********************
    
    % find the whale class [should be optional]
    img1_name_base=regexprep(img1_name,'\.jpg','','ignorecase');
    img1_name_base=regexprep(img1_name_base,'\.png','','ignorecase');
    img1_name_base=regexprep(img1_name_base,'\$','.','ignorecase'); % otherwise regexpi doesn't work
    foundinnames=~cellfun(@isempty,regexpi(Wfnames,img1_name_base));
    IWc=Wclasses(foundinnames); % whale class
    
	% go through other whale images to be compared with the first image
%     disp('DBG: #image2=11')	% for debugging
    for j=i+1:Nimgs
        img2_name=imgs_list(j).name;
        img2mask_name=strrep(img2_name,'.jpg','Mask.jpg');
        fprintf('%s <-> %s ...',img1_name, img2_name);
        
        % load the second image
        Jorig=imread([imgs_folder '\' img2_name]);
        % convert to gray-scale if necessary
        if size(Jorig,3)>1
            J=rgb2gray(Jorig);
        else
            J=Jorig;
        end
        J=imadjust(J,stretchlim(J,[0.001 0.999]),[]); % enhance the contrast
        J=single(J); % conversion to single is recommended for vl_sift
        
        
        % load inside-whale mask
        Jmask=imread([imgs_folder '\masks\' img2mask_name]);
        Jmask=Jmask>128;
		
        % calculate the eroded and dilated inside-whale mask
        Jvertsize_mask=sum( sum(Jmask,2)>0 ); % number of non-zero pixels projected onto the vertical
        Jerode_rad=ceil(Jvertsize_mask*mask_erosion_rad_percent);
        Jmask_er=imerode(Jmask,strel('disk',Jerode_rad));
        Jdilat_rad=ceil(Jvertsize_mask*mask_dilation_rad_percent);
        Jmask_dil=imdilate(Jmask,strel('disk',Jdilat_rad));
        
        % consider the image only inside the inside-mask-dilated
        J(Jmask_dil==0)=0;
        
        % find the whale class
        img2_name_base=regexprep(img2_name,'\.jpg','','ignorecase');
        img2_name_base=regexprep(img2_name_base,'\.png','','ignorecase');
        img2_name_base=regexprep(img2_name_base,'\$','.','ignorecase'); % otherwise regexpi doesn't work
        foundinnames=~cellfun(@isempty,regexpi(Wfnames,img2_name_base));
        JWc=Wclasses(foundinnames); % whale class

        %**********************
        tic;
        % calculate SIFT features for the second image (key algorithm, external library)
        [F2 D2] = vl_sift(J);
        fprintf('S! ...');

        % matching of SIFT features (key algorithm, external library)
        [matches score] = vl_ubcmatch(D1,D2,ubcthresh);
        fprintf('M! ...');
        ela=toc+ela_siftI;
        %**********************
        
        %%
        % find matching features with centers inside the eroded inside-whale mask for both images
        matches_coords_img1=[F1(1,matches(1,:)); F1(2,matches(1,:))]';
        matches_coords_img2=[F2(1,matches(2,:)); F2(2,matches(2,:))]';
        bothinside_mask=false(size(matches_coords_img1,1),1);
        for k=1:length(bothinside_mask)
            if Imask_er(round(matches_coords_img1(k,2)),round(matches_coords_img1(k,1)))==1 & ...
                    Jmask_er(round(matches_coords_img2(k,2)),round(matches_coords_img2(k,1)))==1
                bothinside_mask(k)=true;
            end
        end
        matches_inside=matches(:,bothinside_mask);
        score_inside=score(bothinside_mask);
        matches_coords_img1_inside=matches_coords_img1(bothinside_mask,:);
        matches_coords_img2_inside=matches_coords_img2(bothinside_mask,:);

        %% FIGURE 1, MATCHING-REDUCTION PROCESS: plot matches before the kNN-reduction
        figure(1)
        clf
        subplot(211);
        imshow(Iorig);
        hold on
        plot(F1(1,matches(1,bothinside_mask)),F1(2,matches(1,bothinside_mask)),'go','MarkerSize',2)
        
        subplot(212);
        imshow(Jorig);
        hold on
        plot(F2(1,matches(2,bothinside_mask)),F2(2,matches(2,bothinside_mask)),'go','MarkerSize',2)
        
        %% reduce matches by using kNN-reduction
		% 	kNN-reduction iteratively finds a pair of the worst matched features, skips them, next iteration
		% 		the worst is the pair with smallest intersection of sets of kNN_k-nearest neighbors
		%		the iteration continues while there are matches with intersection less than kNN-KNN_RED_PARAM 
        
		%*** SCRIPT, be careful, a script in Matlab changes global variables >>> 
		%	creates kNNred_inds
        kNN_matches_reduction
        %<<<SCRIPT ***
        
		matches_inside_kNN=matches_inside(:,kNNred_inds);
        matches_img1_kNN=matches_coords_img1_inside(kNNred_inds,:);
        matches_img2_kNN=matches_coords_img2_inside(kNNred_inds,:);
        
        fprintf('\n %u matches skept after kNN reduction\n', sum(~kNNred_inds))
        
        %% FIGURE 1, MATCHING-REDUCTION PROCESS: plot the features left after the kNN-reduction
        figure(1)
        subplot(211)
        plot(F1im_red(1,:),F1im_red(2,:),'yo','MarkerSize',4)
        for n=1:size(F1im_red,2)
            text(F1im_red(1,n)+size(Iorig,1)*0.01,F1im_red(2,n)+size(Iorig,2)*0.01,sprintf('%d',n),'Color','y','FontSize',8);
        end
        
        subplot(212)
        plot(F2im_red(1,:),F2im_red(2,:),'yo','MarkerSize',4)
        for n=1:size(F2im_red,2)
            text(F2im_red(1,n)+size(Iorig,2)*0.01,F2im_red(2,n)+size(Iorig,2)*0.01,sprintf('%d',n),'Color','y','FontSize',8);
        end
        
        
        %% reduce matches by using kNN-angles reduction
		%	kNN-angles reduction iteratively finds a pair of the worst matched features and skips them
		%		the worst is the pair with largest average difference between angles of kNN-features (see the script for details)
		%		the iteration continues while there are matches with average difference larger than KNNANGL_RED_THRESH grad

		%*** SCRIPT, be careful, a script in Matlab changes global variables >>> 
        %	creates kNNangl_inds
        kNNangles_matches_reduction
        %<<<SCRIPT ***

        matches_inside_kNNangl=matches_inside_kNN(:,kNNangl_inds);
        matches_img1_kNNangl=matches_img1_kNN(kNNangl_inds,:);
        matches_img2_kNNangl=matches_img2_kNN(kNNangl_inds,:);
        
        fprintf('%u matches skept after kNN-angles reduction\n', sum(~kNNangl_inds))
        
        %% FIGURE 1, MATCHING-REDUCTION PROCESS: plot the feature left after the kNN-angles reduction
        figure(1)
        subplot(211)
        plot(F1im_red(1,:),F1im_red(2,:),'r.','MarkerSize',4)
        
        subplot(212)
        plot(F2im_red(1,:),F2im_red(2,:),'r.','MarkerSize',4)

		% super title for the whole plot
        suptitle(sprintf('%u > %u (kNN) > %u (kNNa)', sum(bothinside_mask), sum(kNNred_inds), sum(kNNangl_inds)));
        
        %%
        % store the resulting figure
        featfname=sprintf('%s\\%s--%s_features.png',imgs_folder,strrep(img1_name,'.jpg',''),strrep(img2_name,'.jpg',''));
%         saveas(gcf,resfname);
        set(gcf,'PaperPositionMode','auto')
        set(gcf,'InvertHardcopy','off')
        print('-dpng',featfname,'-r120','-opengl');        
        

        %% FIGURE 2, OVERVIEW: plot matching pixels
        figure(2)
        subplot(221);
        set(gca, 'OuterPosition', [-0.02 0.65 0.55 0.55]) % shrink a little
        imshow(Iorig);
        str1=sprintf('%s (%dx%d)', img1_name,size(Iorig,1),size(Iorig,2));
        if ~isempty(IWc)
            str2=sprintf(', #%d', IWc);
        else
            str2=sprintf(', #?');
        end
        title([str1 str2],'interpreter','none');

        subplot(222);
        set(gca, 'OuterPosition', [0.45 0.65 0.55 0.55]) % shrink a little
        imshow(Jorig);
        str1=sprintf('%s (%dx%d)', img2_name,size(Jorig,1),size(Jorig,2));
        if ~isempty(JWc)
            str2=sprintf(', #%d', JWc);
        else
            str2=sprintf(', #?');
        end
        title([str1 str2],'interpreter','none');
        
        %
        subplot(223);
        set(gca, 'OuterPosition', [-0.02 0.05 0.55 0.55]) % shrink a little
        imshow(uint8(I));
        hold on;
        % plot boundaries of the eroded mask (inside-whale)
        [B,L]=bwboundaries(Imask_er);
        for k = 1:length(B)
            boundary = B{k};
            hold on;plot(boundary(:,2), boundary(:,1), 'y', 'LineWidth', 0.5)
        end
        % plot matches
        plot(matches_img1_kNNangl(:,1),matches_img1_kNNangl(:,2),'gx');
        if ~isempty(score)
            title('processed, matching points')
        else
            title('processed')
        end

        subplot(224);
        set(gca, 'OuterPosition', [0.45 0.05 0.55 0.55]) % shrink a little
        imshow(uint8(J));
        hold on;
        % plot boundaries of the eroded mask (inside-whale)
        [B,L]=bwboundaries(Jmask_er);
        for k = 1:length(B)
            boundary = B{k};
            hold on;plot(boundary(:,2), boundary(:,1), 'y', 'LineWidth', 0.5)
        end
        % plot matches
        plot(matches_img2_kNNangl(:,1),matches_img2_kNNangl(:,2),'rx');
        if ~isempty(score)
            title('processed, matching points')
        else
            title('processed')
        end

        % add the title
        if ~isempty(score)
            sscore=sort(score);
            str1=sprintf('%u matches[%.2f,kNN] found, shortest distances: ', size(matches_img1_kNNangl,1),ubcthresh);
            suptitle(sprintf('%s (%.1fs)',str1,ela));
        else
            suptitle(sprintf('no matches[%.2f] found (%.1fs)',ubcthresh,ela))
        end

        % store the resulting figure
        resfname=sprintf('%s\\%s--%s.png',imgs_folder,strrep(img1_name,'.jpg',''),strrep(img2_name,'.jpg',''));

        set(gcf,'PaperPositionMode','auto')
        set(gcf,'InvertHardcopy','off')
        print('-dpng',resfname,'-r120','-opengl');
		
		% store matching results
        RES_ubcmatch{i,j}={matches,score,bothinside_mask,matches_inside,matches_inside_kNN,matches_inside_kNNangl};
        RES_sift{i,j}={F1,F2,D1,D2};
        RES_Nmatches(i,j)=length(matches_inside_kNNangl);
        RES_Nmatches_inside(i,j)=length(matches_inside_kNNangl);
        
        if i>10
            disp('');
        end
        
        fprintf('\n');
        
%         pause
    end
end % for i=1:Nimgs % go over all images

%% store .mat  containing matching results for all images
allresfname=sprintf('%s\\matchingresults_%s.mat',imgs_folder,timefingerprint);
siftresfname=sprintf('%s\\siftresults_%s.mat',imgs_folder,timefingerprint);
save(allresfname,'imgs_folder','timefingerprint','Wclasses','Wfnames','imgs_list','Nimgs', 'ubcthresh','RES_ubcmatch','RES_Nmatches','RES_Nmatches_inside')
save(siftresfname,'imgs_folder','timefingerprint','Wclasses','Wfnames','imgs_list','Nimgs', 'RES_sift')

%% store .xls containing summary of matching results for all images
imgsnames_xls=sprintf('%s\\imgsnames_%s.xls',imgs_folder,timefingerprint);
RESNmatches_xls=sprintf('%s\\RESNmatches_%s.xls',imgs_folder,timefingerprint);
imgnames=cell(length(imgs_list),1);
for i=1:length(imgs_list)
    imgnames{i}=imgs_list(i).name;
end
xlswrite(imgsnames_xls,imgnames)
xlswrite(RESNmatches_xls,RES_Nmatches_inside)

