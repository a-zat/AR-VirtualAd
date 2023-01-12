clc
clear variables
close all

% import the video and the advertiesment
videoReader = VideoReader('Video/tennis.mp4');
frame = readFrame(videoReader);
[banner, map, alphachannel_banner] = imread('Images/bmw_logo.png');

% define the affine transformations
theta = 0; tx = 520; ty = 740; k =  0.3;
tform_int = affine2d([ k*cosd(theta)  sind(theta)  0
                       -sind(theta)  k*cosd(theta) 0
                            tx           ty        1 ]);
                        
% get the matched points for the projective transformation
court_corners = [ 893 221
                 1484 233
                  602 770
                 1769 821];
rect_corners = [  1    1
                498    1
                  1 1080
                498 1080];

% define the reference
imref = imref2d([1080 1920], [1 1920], [1 1080]);

% compute the projective transformation
tform_F = estimateGeometricTransform(rect_corners, court_corners, 'projective'); % top to side

% define the final transformation (projective*affine)
tform_F2 = projective2d(tform_int.T * tform_F.T);

% Create warped images referenced to the world reference frame
bannerW = imwarp(banner,tform_F2,'OutputView',imref);
mask = imwarp(alphachannel_banner, tform_F2, 'OutputView', imref);

% Create stitched image
alphablend = vision.AlphaBlender('Operation','Binary Mask','MaskSource','Input Port');
frame_edit = alphablend(frame, bannerW, mask);

figure, imshow(frame_edit)


%% Video processing

video_out = VideoWriter('tennis_horizontal_bmw');
open(video_out);
videoPlayer = vision.VideoPlayer('Position',[100,100,680,520]);
videoPlayer(frame_edit);
writeVideo(video_out, frame_edit);

frame_prev = frame;
pts_prev  = detectSURFFeatures(rgb2gray(frame_prev));
[features_prev,validPts_prev] = extractFeatures(rgb2gray(frame_prev),pts_prev);
tform_prev = tform_F2;

while hasFrame(videoReader)
    frame = readFrame(videoReader);
    frame_gray = rgb2gray(frame);
    pts = detectSURFFeatures(frame_gray);
    
    % matching part
    [features, validPts] = extractFeatures(frame_gray,pts);
    index_pairs = matchFeatures(features_prev,features);
    matchedPts_prev = validPts_prev(index_pairs(:,1));
    matchedPts = validPts(index_pairs(:,2));
    
    [~, inlierIdx] = estimateGeometricTransform2D(matchedPts_prev,matchedPts,'projective');
    inlierPts = matchedPts(inlierIdx,:);
    inlierPts_prev  = matchedPts_prev(inlierIdx,:);
    
    tform3 = estimateGeometricTransform2D(inlierPts_prev,inlierPts,'projective');
    
    % trasform ad with the new transform
    tform4 = projective2d(tform_prev.T * tform3.T);
    
    bannerW = imwarp(banner, tform4, 'OutputView', imref);
    mask = imwarp(alphachannel_banner, tform4, 'OutputView', imref);
    frameEdited = alphablend(frame, bannerW, mask);
    
%     frameEdited = insertMarker(frameEdited,matchedPts.Location,'+','Color','white');
%     out = insertMarker(frame,pts(validPts, :),'+');
    videoPlayer(frameEdited);
    writeVideo(video_out, frameEdited);
    
    % apply for next frame
    frame_prev = frame;
    pts_prev  = pts;
    features_prev = features;
    validPts_prev = validPts;
    tform_prev = tform4;
end
release(videoPlayer);
close(video_out);


%% Get the top view of the field

% top_view = imwarp(frame, invert(tform_F2));
% 
% figure, imshow(top_view)
% imwrite(top_view,'tennis_topview.jpg')