%*********************************************************************************
% This function performs the kNN-angles reduction of matched features to reduce the number of false positive matches (spatial configuration based reduction).
% 
% Input:
%   - F1im: coordinates of centers of matched SIFT features for image1
%           // array of size 2x{number of features}
%   - F2im: the same for image2
%           // array of size 2x{number of features}
%   - kNNangl_k: how many nearetst neighbors for a matcht SIFT feature are considered
%           // integer, default=5
%	- KNNANGL_RED_THRESH: allowed average difference between all angles formed by nearest neighbors in kNN-neighborhoods of two matched SIFT features
%           // integer, default=15
%   - kNN_k,KNN_RED_PARAM: see description in kNN_matches_reduction
%
% Output:
%   - indices of pairs of SIFT features left after the reduction.
%
%
% Theodore Alexandrov, Ekaterina Ovchinnikova, theodore@uni-bremen.de, katya@isi.edu
% 05 June 2013
%*********************************************************************************

function kNNangl_inds = kNNangles_matches_reduction(F1im,F2im,kNNangl_k,KNNANGL_RED_THRESH,KNN_RED_PARAM)


%% kNN-reduction
kNNangl_inds=true(size(F1im,2),1); % indices of the matches left after this reduction
order_nums=1:size(F1im,2); % number of features
stop_reduction=false; % flag
maxN=size(F1im,2); 
% progressbar_step=10;

% iterate the reduction process
anglediffs=zeros(kNNangl_k*(kNNangl_k-1)/2,1); % differences between angles will be stored
while ~stop_reduction
    %%---- kNNangles PART ----
    %
    % kNNangles part either removes one pair of features as the worst or
    % stops iterating
    %
    
    N_features=sum(kNNangl_inds); % is changing in this cycle
    
	% consider all features left after the last reduction step
    F1im_r=F1im(:,kNNangl_inds); % image 1
    F2im_r=F2im(:,kNNangl_inds); % image 2
	
	% get the order numbers of features considered at this step
    order_nums_r=order_nums(kNNangl_inds);
	
	% calculate kNN graphs for considered features 
    % //comment to kNNangl_k+1: Matlab's knnsearch searches for neighbors 
    %   _including_ the point itself, whereas we want it for kNNangl_k=5 
    %   to return 5 neighbors, not just 4
    kNN_idx1=knnsearch(F1im_r',F1im_r','K',kNNangl_k+1); % for image 1
%     kNN_idx2=knnsearch(F2im_r',F2im_r','K',kNNangl_k+1); % for image 2
	
	% go over matched features 
    kNNangl_measure=zeros(N_features,1); % for storing kNN-rating (the number of kNN_2 neighbors which are different from kNN_1 neighbors) for each matched feature
    
    % go over features left after the last iteration of the reduction process
    for n=1:N_features
        %>>>DBG
%         if n==11
%             fprintf('');
%         end
        %<<<DBG
        
        kNN_1=kNN_idx1(n,:); % neighbors for n'th feature for image 1
%         kNN_2=kNN_idx2(n,:); % neighbors for n'th feature for image 2
		
        % calculate the angles between the vectors corresponding to kNN's of the matched features
        NN_amount=length(kNN_1);
        anglediffs(:)=0;
        adi=1;
        for NNi=1:NN_amount
            if kNN_1(NNi)==n % don't calculate the angle between n'th and n'th
                continue; 
            end
            for NNj=NNi+1:NN_amount
                if kNN_1(NNj)==n % don't calculate the angle between n'th and n'th
                    continue;
                end
                
%                 fprintf('DBG: %u-%u-%u ', kNN_1(NNi),n,kNN_1(NNj));	% for debuggin
                
                % image 1
                u1=F1im_r(1:2,kNN_1(NNi));
                v1=F1im_r(1:2,kNN_1(NNj));

                c1=F1im_r(1:2,n);
                if norm(u1-c1)==0 | norm(v1-c1)==0 % otherwise division by 0
                    a1=0;
                else
                    cosa1=dot(u1-c1,v1-c1)/(norm(u1-c1)*norm(v1-c1));
                    % the angle between NNi'th and NNj'th features of image1
                    a1=acos( cosa1 )*180/pi;
                end
                
                % image 2
                u2=F2im_r(1:2,kNN_1(NNi)); % NNi'th feature from kNN_1
                v2=F2im_r(1:2,kNN_1(NNj)); % NNj'th feature from kNN_2

                c2=F2im_r(1:2,n);
                if norm(u2-c2)==0 | norm(v2-c2)==0 % otherwise division by 0
                    a2=0;
                else
                    cosa2=dot(u2-c2,v2-c2)/(norm(u2-c2)*norm(v2-c2));

                    % the angle between NNi'th and NNj'th (numbers from kNN_1) features of image2 
                    a2=acos( cosa2 )*180/pi;
                end
                
%                 fprintf('a1=%.0f%% a2=%.0f%%\n',a1,a2);
                
                anglediffs(adi)=abs(a1-a2);
                adi=adi+1;                
            end
        end
        
        anglediffs_sorted=sort(anglediffs(1:adi-1),'descend');
        kNNangl_measure(n)=mean( anglediffs_sorted(1:min(adi-1,NN_amount-1)) ); % consider kNNangl_k differences 
%         kNNangl_measure(n)=mean( anglediffs );
    end

	% check the stop-criterion
	%	if there is a feature so that it has different configurations of neighbors in image1 and image2, then skip it and go to the next iteration
	%	otherwise, stop iterating
    if max(kNNangl_measure)>KNNANGL_RED_THRESH
        [~,worst_ind]=max(kNNangl_measure);
        kNNangl_inds(order_nums_r(worst_ind))=false;
    else
        stop_reduction=true;
    end
    
    %%---- kNN PART ----
    %
    % kNN part checks that the left pairs of features satisfy the kNN
    % constraint
    %
    
    kNNred_inds=kNN_matches_reduction(F1im(:,kNNangl_inds),F2im(:,kNNangl_inds),kNNangl_k,KNN_RED_PARAM);
    
    % update the kNNangl_inds
    kNNangl_inds_truevals=find(kNNangl_inds>0);
    kNNangl_inds_truevals_kNNred=kNNangl_inds_truevals(kNNred_inds);
    kNNangl_inds(:)=false;
    kNNangl_inds(kNNangl_inds_truevals_kNNred)=true;
    
end



