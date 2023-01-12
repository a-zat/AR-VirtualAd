clc
clear variables
close all

% import the video and the advertiesment
videoReader = VideoReader('Video/Football.mp4');
frame = readFrame(videoReader);
[banner, map, alphachannel_banner] = imread('Images/wide_advert.png');

% define the affine transformations
theta1 = 0; tx1 = -2500; ty1 = 200; k1 = 3;
tform_translation1 = affine2d([ k1*cosd(theta1)   sind(theta1)   0
                                 -sind(theta1)  k1*cosd(theta1)  0
                                       tx1             ty1        1 ]);
theta2 = 0; tx2 = 3500; ty2 = 200; k2 = 3;
tform_translation2 = affine2d([ k2*cosd(theta2)   sind(theta2)   0
                                 -sind(theta2)  k2*cosd(theta2)  0
                                       tx2             ty2        1 ]);
                                   
% get the matched points for the projective transformation
goal_dist_rect = [1642 189
                  1894 243
                  1638 316
                  1884 381];
goal_rect = [   1   1
             1920   1
                1 640
             1920 640];

% define the reference
imref = imref2d([1080 1920], [1 1920], [1 1080]);

% compute the projective transformation
tform_goal = estimateGeometricTransform(goal_rect,goal_dist_rect,'projective');

% define the final transformation (projective*affine)
tform1 = projective2d(tform_translation1.T*tform_goal.T);
tform2 = projective2d(tform_translation2.T*tform_goal.T);

% Create warped images referenced to the world reference frame
bannerW1 = imwarp(banner,tform1,'OutputView',imref);
bannerW2 = imwarp(banner,tform2,'OutputView',imref);
mask1 = imwarp(alphachannel_banner,tform1,'OutputView',imref);
mask2 = imwarp(alphachannel_banner,tform2,'OutputView',imref);

% Create stitched image
alphablend = vision.AlphaBlender('Operation','Binary Mask', 'MaskSource', 'Input Port');
frame_edit1 = alphablend(frame, bannerW1, mask1);
frame_edit2 = alphablend(frame_edit1, bannerW2, mask2);

figure, imshow(frame_edit2)

%% Video processing

video_out = VideoWriter('Football_vertical');
open(video_out);
videoPlayer = vision.VideoPlayer('Position',[100,100,680,520]);
videoPlayer(frame_edit2);
writeVideo(video_out, frame_edit2);

frame_prev = frame;
pts_prev  = detectSURFFeatures(rgb2gray(frame_prev));
[features_prev,validPts_prev] = extractFeatures(rgb2gray(frame_prev),pts_prev);
tform_prev1 = tform1;
tform_prev2 = tform2;

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
    tform_motion2 = projective2d(tform_prev2.T*tform_moving.T);
    
    bannerW1_motion = imwarp(banner,tform_motion1,'OutputView',imref);
    mask1_motion = imwarp(alphachannel_banner,tform_motion1,'OutputView',imref);
    frameEdited1 = alphablend(frame,bannerW1_motion, mask1_motion);
    
    bannerW2_motion = imwarp(banner,tform_motion2,'OutputView',imref);
    mask2_motion = imwarp(alphachannel_banner,tform_motion2,'OutputView',imref);
    frameEdited2 = alphablend(frameEdited1,bannerW2_motion,mask2_motion);
    
%     frameEdited = insertMarker(frameEdited,matchedPts.Location,'+','Color','white');
%     out = insertMarker(frame,pts(validPts, :),'+');
    videoPlayer(frameEdited2);
    writeVideo(video_out, frameEdited2);
    
    % apply for next frame
    frame_prev = frame;
    pts_prev  = pts;
    features_prev = features;
    validPts_prev = validPts;
    tform_prev1 = tform_motion1;
    tform_prev2 = tform_motion2;
end
release(videoPlayer);
close(video_out);
