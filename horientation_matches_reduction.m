%*********************************************************************************
% This function performs the horizontal orientation reduction of matched features 
% to reduce the number of false positive matches.
% 
% Input:
%   - F1im: coordinates of centers of matched SIFT features for image1
%           // array of size 2x{number of features}
%   - F2im: the same for image2
%           // array of size 2x{number of features}
% Output:
%   - indices of pairs of SIFT features left after the reduction.
%
%
% Theodore Alexandrov, Ekaterina Ovchinnikova, theodore@uni-bremen.de, katya@isi.edu
% 30 July 2013
%*********************************************************************************

function hori_inds = horientation_matches_reduction(F1im,F2im)

im1x=F1im(1,:);
im2x=F2im(1,:);

[~,im1leftFind]=min(im1x); % index of the left feature in image 1
[~,im1rightFind]=max(im1x); % index of the left feature in image 1

if im2x(im1leftFind) <= im2x(im1rightFind)
    % the matched features in image2 have the same horizontal order
    hori_inds=true(size(im1x));
else
    % the matched features in image2 are flipped horizontally
    hori_inds=false(size(im1x));
end
