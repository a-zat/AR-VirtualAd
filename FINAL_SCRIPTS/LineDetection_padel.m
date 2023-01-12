%% Import
clc
clear variables
close all

addpath('Functions/ut_image_processing_functions');
addpath('Functions/ut_graphic_functions');
addpath('Workspaces');
addpath('Images');
addpath('Video');

% Open video and read first frame
videoReader = VideoReader('Video/Padel_2.mp4');
frame = readFrame(videoReader);

%% EDGE DETECTION

% apply template matching to find the positions
frame_gray = rgb2gray(frame);
line_feature = fibermetric(frame_gray,7); % could work also with non-greyscale

% show
figure(2);
imshow(line_feature,[],'InitialMagnification',400);
title('line features = largest eigenvalue of hessian matrix')

%% threshold to find line_elments 
P =100*(1 - 25/256);                                     
Tr = prctile(line_feature,P,[1,2]);                       % define threshold
line_element_map = line_feature>Tr;                       % threshold
figure('units','normalized','position',[0.1 0.1 0.7 0.7]);
imshow(line_element_map,'InitialMagnification',400); 
title('detected line elements')


%% apply template matching for orientation and positions
len = 30;                                           % minimum lenght of line segment
imacc = false(size(frame_gray));                            
line_element_map = imdilate(line_element_map,[0 1 0; 0 1 0; 0 0 0]); 
for deg=0:2:180          %% loop over all angles:
    bline1 = strel('line',len,deg);                  % create a structuring element with angulated line segment
    bline2 = strel('line',len+4,deg);                % create a structuring element with angulated line segment
    imdir = imdilate(imerode(line_element_map,bline1),bline2);  % apply opening: 
    imacc = imacc | imdir;                          % accumulate all found segments
end

% Image after template matching for orientation and positions 
figure('units','normalized','position',[0.1 0.1 0.7 0.7]);
imshow(imacc,[],'InitialMagnification',400);
title('map with line segments')

%% Apply morph. transformaation to keep only the biggest blob (field)
immorph = bwareafilt(imacc, 1);

figure
imshow(immorph,[],'InitialMagnification',400);

% Make lines well connected
SE = strel('diamond', 5);
immorph = imdilate(immorph,SE); % connect all lines and make them roughly same thickness
immorph = bwmorph(immorph,'fill',5); % remove black spots, that would create holes with skeletonization

figure
imshow(immorph,[],'InitialMagnification',400);

%% Skeletonize
imskel = bwskel(immorph,'MinBranchLength',100);
imskel = bwmorph(imskel,'spur',200);

imshow(imskel,[],'InitialMagnification',400);

%% Find bifurcations
imbranchpoints = bwmorph(imskel,'branchpoints');
[r c] = find(imbranchpoints);
branchpoints_list = [r c];

imbranchpoints_show = imdilate(imbranchpoints,ones(5)); 

foo = labeloverlay(im2double(imskel), 2*im2double(imbranchpoints_show),'Colormap',[1 0 0; 0 1 0; 1 1 0],'Transparency',0.1);

figure
imshow(foo,'InitialMagnification',400);
title('found court lines with branchpoints detected') 

% Merge close intersections into a single one
imbranchpoints2 = imdilate(imbranchpoints,ones(10)); 
imbranchpoints2 = bwmorph(imbranchpoints2,'shrink', Inf);
imbranchpoints_show = imdilate(imbranchpoints2,ones(5)); 
foo = labeloverlay(im2double(imskel), 2*im2double(imbranchpoints_show),'Colormap',[1 0 0; 0 1 0; 1 1 0],'Transparency',0.1);

figure
imshow(foo,'InitialMagnification',400);
title('found court lines with branchpoints detected') 

save branchpoint_tennis 'branchpoints_list';
%% Hit and miss

bhit = {
    [0 0 0 0 0 1 0 0 0 ;
     0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 ;
     1 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 ;
     ]};

bmiss = {
    [0 0 0 0 0 0 0 0 1 ;
     0 0 0 0 0 0 0 0 1 ;
     0 0 0 0 0 0 0 0 1 ;
     0 0 0 0 0 0 0 0 1 ;
     0 0 0 0 0 0 0 0 1 ;
     0 0 0 0 0 0 0 0 1 ;
     0 0 0 0 0 0 0 0 1 ;
     0 0 0 0 0 0 0 0 1 ;
     1 1 1 1 1 1 1 1 1 ;
     ]};

for i=2:4
    bhit{i} = rot90(bhit{i-1});
    bmiss{i} = rot90(bmiss{i-1});
end 
 
imcorners = zeros(size(imskel));
for i=1:4, imcorners = imcorners | bwhitmiss(imskel,bhit{i},bmiss{i}); end

imcorners_view = imdilate(imcorners,ones(9));          % dilate the dots

% show image with a color overlay
foo = labeloverlay(im2double(imskel),im2double(imskel)+2*im2double(imcorners_view),'Colormap',[1 0 0; 0 1 0; 1 1 0],'Transparency',0.2);
figure('units','normalized','position',[0.1 0.1 0.7 0.7]);
imshow(foo,[],'InitialMagnification',400);
title('found court lines with corners') 

imcorners = bwmorph(imcorners_view,'shrink', Inf);  
[r c] = find(imcorners);
imcorners_list = [r c];

%% Fill the field region and apply hit and miss
imfilled = imfill(imskel, 'holes');

bhit = { 
    [1 1 1 1 1 1 0 0 0 0 0 ;
     1 1 1 1 1 1 0 0 0 0 0 ;
     1 1 1 1 1 1 0 0 0 0 0 ;
     1 1 1 1 1 1 0 0 0 0 0 ;
     1 1 1 1 1 1 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     ]};

bmiss = {
    [0 0 0 0 0 0 0 0 0 1 1;
     0 0 0 0 0 0 0 0 0 1 1;
     0 0 0 0 0 0 0 0 0 1 1;
     0 0 0 0 0 0 0 0 0 1 1;
     0 0 0 0 0 0 0 0 0 1 1;
     0 0 0 0 0 0 0 0 0 1 1;
     0 0 0 0 0 0 0 0 0 1 1;
     0 0 0 0 0 0 0 0 0 1 1;
     0 0 0 0 0 0 0 0 0 1 1;
     1 1 1 1 1 1 1 1 1 1 1;
     1 1 1 1 1 1 1 1 1 1 1;
     ]};

for i=2:4
    bhit{i} = rot90(bhit{i-1});
    bmiss{i} = rot90(bmiss{i-1});
end 
 

imcorners = zeros(size(imskel));
for i=1:4, imcorners = imcorners | bwhitmiss(imfilled,bhit{i},bmiss{i}); end

[r c] = find(imcorners);
imcorners_list = [r c];

imcorners_view = imdilate(imcorners,ones(9));          % dilate the dots

% show image with a color overlay
foo = labeloverlay(im2double(imfilled),im2double(imskel)+2*im2double(imcorners_view),'Colormap',[1 0 0; 0 1 0; 1 1 0],'Transparency',0.2);
figure('units','normalized','position',[0.1 0.1 0.7 0.7]);
imshow(foo,[],'InitialMagnification',400);
title('found court lines with corners') 

imcorners = bwmorph(imcorners_view,'shrink', Inf);  
[r c] = find(imcorners);
imcorners_list = [r c];

% Save corners for later use
save imcorners_list_tennis 'imcorners_list';
