%*********************************************************************************
% This function performs the kNN-reduction of matched features to reduce the number of false positive matches (neighbor sets based reduction).
% 
% Input:
%   - F1im: coordinates of centers of matched SIFT features for image1
%           // array of size 2x{number of features}
%   - F2im: the same for image2
%           // array of size 2x{number of features}
%   - kNN_k: how many nearest neighbors for a matched SIFT feature are considered
%           // integer, default=5
%   - KNN_RED_PARAM: how many nearest neighbors can differ in between kNN-neighborhoods of two matched SIFT features
%           // integer, default=1, 0 is the most strong reduction, larger values lead to less reduction
% Output:
%   - indices of pairs of SIFT features left after the reduction.
%
%
% Theodore Alexandrov, Ekaterina Ovchinnikova, theodore@uni-bremen.de, katya@isi.edu
% 30 June 2013
%*********************************************************************************

function kNNred_inds = kNN_matches_reduction(F1im,F2im,kNN_k,KNN_RED_PARAM)



%% kNN-reduction
kNNred_inds=true(size(F1im,2),1); % indices of the matches left after this reduction
order_nums=1:size(F1im,2); % number of features
stop_reduction=false; % flag
maxN=size(F1im,2); 
% progressbar_step=10;

% iterate the reduction process
while ~stop_reduction
	% consider all features left after the last reduction step
    F1im_r=F1im(:,kNNred_inds); % image 1
    F2im_r=F2im(:,kNNred_inds); % image 2
	
	% get the order numbers of features considered at this step
    order_nums_r=order_nums(kNNred_inds);
	
	% calculate kNN graphs for considered features 
    % //comment to kNN_k+1: Matlab's knnsearch searches for neighbors
    %   _including_ the point itself, whereas we want it for kNN_k=5 
    %   to return 5 neighbors, not just 4
    kNN_idx1=knnsearch(F1im_r',F1im_r','K',kNN_k+1); % for image 1
    kNN_idx2=knnsearch(F2im_r',F2im_r','K',kNN_k+1); % for image 2
	
	% go over matched features 
    kNN_measure=zeros(size(F1im_r,2),1); % for storing kNN-rating (the number of kNN_2 neighbors which are different from kNN_1 neighbors) for each matched feature
    for n=1:length(kNN_measure) 
        kNN_1=kNN_idx1(n,:); % neighbors for n'th feature for image 1
        kNN_2=kNN_idx2(n,:); % neighbors for n'th feature for image 2
		
		% calculate the number of kNN_2 neighbors which are different from kNN_1 neighbors
        ndiff_neighbors=length(unique([kNN_1,kNN_2]))-length(kNN_1);
        kNN_measure(n)=ndiff_neighbors; 
    end

	% check the stop-criterion
	%	if there is a feature so that it has enough different kNN_1 and kNN_2 neighbors (number > than the threshold) then skip it and go to the next iteration
	%	otherwise, stop iterating
    if max(kNN_measure)>KNN_RED_PARAM 
        [~,worst_ind]=max(kNN_measure);
        kNNred_inds(order_nums_r(worst_ind))=false;
    else
        stop_reduction=true;
    end
    
%     % progress bar
%     N=size(F1im,2)-sum(kNNred_inds);
%     if ceil(N/maxN*progressbar_step) < ceil((N+1)/maxN*progressbar_step)
%         fprintf(1,'%.0f%% ', 100*N/maxN);
%     end
    
end




