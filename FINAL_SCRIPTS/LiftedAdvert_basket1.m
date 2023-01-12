clc
clear variables
close all

% import the video and the advertiesment
videoReader = VideoReader('Video/basket.mp4');
frame = readFrame(videoReader);
[banner, map, alphachannel_banner] = imread('Images/wide_advert.png');

% define the affine transformations
theta1 = 0; tx1 = 3000; ty1 = 2200; k1 = 6;
tform_translation1 = affine2d([ k1*cosd(theta1)   sind(theta1)   0
                                 -sind(theta1)  k1*cosd(theta1)  0
                                       tx1             ty1        1 ]);

% get the matched points for the projective transformation
backboard_dist = [1770 102
                  1836 143
                  1761 215
                  1829 266];
backboard_rect = [   1   1
                  1920   1
                     1 1280
                  1920 1280];
              
% define the reference
imref = imref2d([1080 1920], [1 1920], [1 1080]);

% compute the projective transformation
tform_backboard = estimateGeometricTransform(backboard_rect,backboard_dist,'projective');

% define the final transformation (projective*affine)
tform1 = projective2d(tform_translation1.T*tform_backboard.T);

% Create warped images referenced to the world reference frame
bannerW1 = imwarp(banner,tform1,'OutputView',imref);
mask1 = imwarp(alphachannel_banner,tform1,'OutputView',imref,'interp','cubic');

% Create stitched image
alphablend = vision.AlphaBlender('Operation','Binary Mask', 'MaskSource', 'Input Port');
frame_edit1 = alphablend(frame, bannerW1, mask1);

figure, imshow(frame_edit1)


%% Video processing

video_out = VideoWriter('Basket_vertical');
open(video_out);
videoPlayer = vision.VideoPlayer('Position',[100,100,680,520]);
videoPlayer(frame_edit1);
writeVideo(video_out, frame_edit1);

frame_prev = frame;
pts_prev  = detectSURFFeatures(rgb2gray(frame_prev)); %,'ROI',objectRegion);
[features_prev,validPts_prev] = extractFeatures(rgb2gray(frame_prev),pts_prev);
tform_prev1 = tform1;

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
    
    tform_moving = estimateGeometricTransform2D(inlierPts_prev,inlierPts,'projective');
    
    % trasform ad with the new transform
    tform_motion1 = projective2d(tform_prev1.T*tform_moving.T);
    
    bannerW1_motion = imwarp(banner,tform_motion1,'OutputView',imref);
    mask1_motion = imwarp(alphachannel_banner,tform_motion1,'OutputView',imref);
    frameEdited1 = alphablend(frame,bannerW1_motion, mask1_motion);
    
%     frameEdited = insertMarker(frameEdited,matchedPts.Location,'+','Color','white');
%     out = insertMarker(frame,pts(validPts, :),'+');
    videoPlayer(frameEdited1);
    writeVideo(video_out, frameEdited1);
    
    % apply for next frame
    frame_prev = frame;
    pts_prev  = pts;
    features_prev = features;
    validPts_prev = validPts;
    tform_prev1 = tform_motion1;
end
release(videoPlayer);
close(video_out);
