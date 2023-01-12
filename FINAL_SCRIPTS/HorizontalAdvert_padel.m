clc
clear variables
close all

%import the video and the advertiesment
videoReader = VideoReader('Video/Padel.mp4');
frame = readFrame(videoReader);
[banner, map, alphachannel_banner] = imread('Images/wide_advert.png');

% define the affine transformations
theta1 = 0; tx1 = 850; ty1 = 200; k1 = 0.75;
tform_translation1 = affine2d([ k1*cosd(theta1)   sind(theta1)   0
                                 -sind(theta1)  k1*cosd(theta1)  0
                                       tx1             ty1        1 ]);
theta2 = 0; tx2 = 850; ty2 = 800; k2 = 0.75;
tform_translation2 = affine2d([ k2*cosd(theta2)   sind(theta2)   0
                                 -sind(theta2)  k2*cosd(theta2)  0
                                       tx2             ty2        1 ]);

% get the matched points for the projective transformation
lines_dist_rect = [ 762 247
                   1170 235
                    708 835
                   1309 807];
lines_rect = [  1    1
              771    1
                1 1080
              771 1080];
                
% define the reference
imref = imref2d([1080 1920], [1 1920], [1 1080]);

% compute the projective transformation
tform_lines = estimateGeometricTransform(lines_rect,lines_dist_rect,'projective');

% define the final transformation (projective*affine)
tform1 = projective2d(tform_translation1.T*tform_lines.T);
tform2 = projective2d(tform_translation2.T*tform_lines.T);

% define the background masking
blue_mask1 = 0.45*frame(:,:,3)>frame(:,:,1) & frame(:,:,3)>150 & bannerW1(:,:,1)~=0;
blue_mask2 = 0.45*frame(:,:,3)>frame(:,:,1) & frame(:,:,3)>150 & bannerW2(:,:,1)~=0;

% Create warped images referenced to the world reference frame
bannerW1 = imwarp(banner,tform1,'OutputView',imref);
bannerW2 = imwarp(banner,tform2,'OutputView',imref);

% Create stitched image
alphablend = vision.AlphaBlender('Operation','Binary Mask','MaskSource','Input Port');
frame_edit1 = alphablend(frame, bannerW1, blue_mask1);
frame_edit2 = alphablend(frame_edit1, bannerW2, blue_mask2);

figure, imshow(frame_edit2)


%% Video processing

video_out = VideoWriter('Padel_Horizontal');
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
    
    % trasform ad with hte new transform
    tform_motion1 = projective2d(tform_prev1.T*tform_moving.T);
    tform_motion2 = projective2d(tform_prev2.T*tform_moving.T);
    
    bannerW1_motion = imwarp(banner,tform_motion1,'OutputView',imref);
    blue_mask1 = 0.45*frame(:,:,3)>frame(:,:,1) & frame(:,:,3)>150 & bannerW1_motion(:,:,1)~=0;
    frameEdited1 = alphablend(frame,bannerW1_motion, blue_mask1);
    
    bannerW2_motion = imwarp(banner,tform_motion2,'OutputView',imref);
    blue_mask2 = 0.45*frame(:,:,3)>frame(:,:,1) & frame(:,:,3)>150 & bannerW2_motion(:,:,1)~=0;
    frameEdited2 = alphablend(frameEdited1,bannerW2_motion,blue_mask2);
    
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


%% Get the top view of the field

% top_view = imwarp(frame, invert(tform_lines));
% 
% figure, imshow(top_view)
% imwrite(top_view,'padel_topview.jpg')