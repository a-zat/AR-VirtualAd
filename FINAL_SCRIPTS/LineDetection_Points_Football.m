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
videoReader = VideoReader('Football.mp4');
frame = readFrame(videoReader);

% frame = imresize(frame,0.5);

%% EDGE DETECTION

% apply template matching to find the positions
frame_gray = rgb2gray(frame);
line_feature = fibermetric(frame_gray,7); % could work also with non-greyscale

% show
figure(2);
imshow(line_feature,[],'InitialMagnification',400);
title('line features = largest eigenvalue of hessian matrix')

%% threshold to find line_elments 
P =100*(1 - 20/256);                                      
Tr = prctile(line_feature,P,[1,2]);                       
line_element_map = line_feature>Tr;                   
figure('units','normalized','position',[0.1 0.1 0.7 0.7]);
imshow(line_element_map,'InitialMagnification',400); 
title('detected line elements')


%% apply template matching for orientation and positions
len = 10;                                          
imacc = false(size(frame_gray));                            
line_element_map = imdilate(line_element_map, [0 1 0; 0 1 0; 0 0 0]);
for deg=0:2:180          
    bline1 = strel('line',len,deg);                  % create a structuring element with angulated line segment
    bline2 = strel('line',len+4,deg);                  % create a structuring element with angulated line segment
    imdir = imdilate(imerode(line_element_map,bline1),bline2);  % apply openin
     imacc = imacc | imdir;                          % accumulate all found segments
end

% Image after template matching for orientation and positions 
figure('units','normalized','position',[0.1 0.1 0.7 0.7]);
imshow(imacc,[],'InitialMagnification',400);
title('map with line segments')

%% Morphological processing
% Remove holes
immorph = ~bwareaopen(~imacc, 1000);

figure
imshow(immorph,[],'InitialMagnification',400);

% Erosion
SE = strel('diam', 2);
immorph = imerode(immorph,SE);

% Keep only the biggest blob
immorph = bwareafilt(immorph, 1);
immorph = bwmorph(immorph,'thicken',1);

figure
imshow(immorph,[],'InitialMagnification',400);

% Fill open region on the top
locations = [ones(1,size(immorph,2)); 1:size(immorph,2)]';
immorph = imfill(immorph, locations);  % fill top part

figure
imshow(immorph,[],'InitialMagnification',400);

% Take negative image
imneg = ~immorph;
SE = strel('diam', 5);
imneg = imerode(imneg,SE); % erode negative image
imneg = bwmorph(imneg,'open',20);

%figure
%imshow(imneg,[],'InitialMagnification',400);

imneg = bwareaopen(imneg, 1000);
figure
imshow(imneg,[],'InitialMagnification',400);

% imneg = imneg - bwareafilt(imneg, 2, 'smallest');
imneg = bwareafilt(imneg, 3, 'largest');

figure
imshow(imneg,[],'InitialMagnification',400);

immorph2 = ~imneg;

figure
imshow(immorph2,[],'InitialMagnification',400);

%% Skeletonization
immorph4 = bwmorph(immorph, 'fill');
imskel = bwskel(immorph4,'MinBranchLength',100);
imskel = bwmorph(imskel,'spur',50);

imshow(imskel,[],'InitialMagnification',400);


%% Hit and miss

immorph3 = ~imneg;

SE = strel('sphere', 6);
immorph3 = imerode(immorph3,SE); % erode negative image

bhit_acute = ... 
    [0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 1 1 1 1 1;
     0 0 0 0 0 1 1 1 1 1 1 ;
     0 0 0 0 0 0 1 1 1 1 1 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     ];

bmiss_acute = ...
    [1 1 1 1 1 1 1 1 1 1 1 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     1 1 1 1 1 1 1 1 1 0 0 ;
     1 1 1 1 1 1 0 0 0 0 0 ;
     1 1 0 0 0 0 0 0 0 0 0 ;
     1 1 0 0 0 0 0 0 0 0 0 ;
     1 1 0 0 0 0 0 0 0 0 0 ;
     1 1 1 1 1 1 0 0 0 0 0 ;
     1 1 1 1 1 1 1 1 1 0 0 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     ];
 
bhit_obtuse = ...
    [0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     1 1 1 0 0 0 0 0 0 0 0 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     0 0 1 1 1 1 1 1 1 1 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     ];

bmiss_obtuse = ...
    [1 1 1 1 1 1 1 1 1 1 1 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     0 0 0 1 1 1 1 1 1 1 1 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     1 0 0 0 0 0 0 0 0 0 1 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     ];
 
bhit = {bhit_acute, bhit_obtuse};
bmiss = {bmiss_acute, bmiss_obtuse};

imcorners = zeros(size(immorph3));
for i=1:2, imcorners = imcorners | bwhitmiss(immorph3,bhit{i},bmiss{i}); end

% Bottom margin is wrongly detected
imcorners(1080,:) = 0;
imcorners(1079,:) = 0;

[r c] = find(imcorners);
imcorners_list = [r c];

imcorners_view = imdilate(imcorners,ones(11));          % dilate the dots

% show image with a color overlay
foo = labeloverlay(im2double(immorph3),im2double(imskel)+2*im2double(imcorners_view),'Colormap',[1 0 0; 0 1 0; 1 1 0],'Transparency',0.2);
figure('units','normalized','position',[0.1 0.1 0.7 0.7]);
imshow(foo,[],'InitialMagnification',400);
title('found court lines with corners') 




%%

bhit_acute = ... 
    [0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 1 1 1 1 1;
     0 0 0 0 0 1 1 1 1 1 1 ;
     0 0 0 0 0 0 1 1 1 1 1 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     ];

bmiss_acute = ...
    [1 1 1 1 1 1 1 1 1 1 1 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     1 1 1 1 1 1 1 1 1 0 0 ;
     1 1 1 1 1 1 0 0 0 0 0 ;
     1 1 1 1 0 0 0 0 0 0 0 ;
     1 1 1 1 0 0 0 0 0 0 0 ;
     1 1 1 1 0 0 0 0 0 0 0 ;
     1 1 1 1 1 1 0 0 0 0 0 ;
     1 1 1 1 1 1 1 1 1 0 0 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     ];
 
bhit_obtuse = ...
    [0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 1 1 1 1 1 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     ];

bmiss_obtuse = ...
    [1 1 1 1 1 1 1 1 1 1 1 ;
     0 0 0 0 1 1 1 0 0 0 0 ;
     0 0 0 0 0 1 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     0 0 0 0 0 0 0 0 0 0 0 ;
     1 1 0 0 0 0 0 0 0 0 0 ;
     1 1 1 1 1 1 1 0 0 0 0 ;
     1 1 1 1 1 1 1 1 1 1 1 ;
     ];