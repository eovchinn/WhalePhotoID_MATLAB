%*********************************************************************************
% This is a script used in the main file for matching images of whales (Matlab implementation)
% 
% The script performs the kNN-reduction of matched features to reduce the number of false positive matches (neighbor sets based reduction).
%
% The script is called from the main file, has access to global variables, and creates a new global variable "kNNred_inds". 
%
% Theodore Alexandrov, Ekaterina Ovchinnikova, theodore@uni-bremen.de, katya@isi.edu
% 05 June 2013
%*********************************************************************************

m1=matches(1,bothinside_mask); % matches for image 1
m2=matches(2,bothinside_mask); % matches for image 2

%%
F1im=F1(:,m1); % matched features of image 1
D1im=D1(:,m1);
F2im=F2(:,m2); % matched features of image 2
D2im=D2(:,m2);

%% kNN-reduction
kNNred_inds=true(size(F1im,2),1); % indices of the matches left after this reduction
order_nums=1:size(F1im,2); % number of features
stop_reduction=false; % flag
maxN=size(F1im,2); progressbar_step=10;

% iterate the reduction process
while ~stop_reduction
	% consider all features left after the last reduction step
    F1im_r=F1im(1:2,kNNred_inds); % image 1
    F2im_r=F2im(1:2,kNNred_inds); % image 2
	
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
    
    % progress bar
    N=size(F1im,2)-sum(kNNred_inds);
    if ceil(N/maxN*progressbar_step) < ceil((N+1)/maxN*progressbar_step)
        fprintf(1,'%.0f%% ', 100*N/maxN);
    end
    
end

%% features left after reduction
F1im_red=F1im(:,kNNred_inds);
D1im_red=D1im(:,kNNred_inds);
F2im_red=F2im(:,kNNred_inds);
D2im_red=D2im(:,kNNred_inds);


%% plot the features (not only centers of features) left after the reduction
% figure(2)
% subplot(211)
% imshow(Iorig);
% hold on
% % plot(F1im(1,:),F1im(2,:),'rx')
% plot(F1im_red(1,:),F1im_red(2,:),'gx')
% % h1 = vl_plotframe(F1im_red); 
% % h2 = vl_plotframe(F1im_red); 
% % set(h2,'color','y','linewidth',2) ;
% % set(h1,'color','k','linewidth',3) ;
% 
% % h3 = vl_plotsiftdescriptor(D1im_red,F1im_red);      
% % set(h3,'color','g');
% 
% for n=1:size(F1im_red,2)
%     text(F1im_red(1,n),F1im_red(2,n)+size(Iorig,2)*0.01,sprintf('%d',n),'Color','y','FontSize',8);
% end
% 
% subplot(212)
% imshow(Jorig);
% hold on
% % plot(F2im(1,:),F2im(2,:),'rx')
% plot(F2im_red(1,:),F2im_red(2,:),'gx')
% % h1 = vl_plotframe(F2im_red); 
% % h2 = vl_plotframe(F2im_red); 
% % set(h2,'color','y','linewidth',2) ;
% % set(h1,'color','k','linewidth',3) ;
% 
% % h3 = vl_plotsiftdescriptor(D2im_red,F2im_red) ;  
% % set(h3,'color','g') ;
% 
% for n=1:size(F2im_red,2)
%         text(F2im_red(1,n),F2im_red(2,n)+size(Iorig,2)*0.01,sprintf('%d',n),'Color','y','FontSize',8);
% end
% 
% suptitle(sprintf('%d matches found after reduction', sum(kNNred_inds)));

