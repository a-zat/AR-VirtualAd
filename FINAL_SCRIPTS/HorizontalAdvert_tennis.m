clc
clear variables
close all

% import the video and the advertiesment
videoReader = VideoReader('Video/tennis.mp4');
frame = readFrame(videoReader);
[banner, map, alphachannel_banner] = imread('Images/proxy-image.png');

% define the affine transformations
theta = 0; tx = 520; ty = 740; k =  0.6;
tform_translation1 = affine2d([ k*cosd(theta)  sind(theta)  0
                                -sind(theta)  k*cosd(theta) 0
                                     tx           ty        1 ]);
theta2 = 0; tx2 = 520; ty2 = 210; k2 = 0.6;
tform_translation2 = affine2d([ k2*cosd(theta2)   sind(theta2)   0
                                 -sind(theta2)  k2*cosd(theta2)  0
                                       tx2             ty2        1 ]);

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
tform_lines = estimateGeometricTransform(rect_corners, court_corners, 'projective'); % top to side

% define the final transformation (projective*affine)
tform1 = projective2d(tform_translation1.T*tform_lines.T);
tform2 = projective2d(tform_translation2.T*tform_lines.T);

% Create warped images referenced to the world reference frame
bannerW1 = imwarp(banner,tform1,'OutputView',imref);
bannerW2 = imwarp(banner,tform2,'OutputView',imref);
mask1 = imwarp(alphachannel_banner,tform1,'OutputView',imref);
mask2 = imwarp(alphachannel_banner,tform2,'OutputView',imref);

% Create stitched image
alphablend = vision.AlphaBlender('Operation','Binary Mask','MaskSource','Input Port');
frame_edit1 = alphablend(frame,bannerW1,mask1);
frame_edit2 = alphablend(frame_edit1,bannerW2,mask2);

figure, imshow(frame_edit2)


%% Video processing

video_out = VideoWriter('tennis_horizontal_markers');
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
    tform_motion1 = projective2d(tform_prev1.T * tform_moving.T);
    tform_motion2 = projective2d(tform_prev2.T * tform_moving.T);
    
    bannerW1 = imwarp(banner, tform_motion1, 'OutputView', imref);
    mask1_motion = imwarp(alphachannel_banner, tform_motion1, 'OutputView', imref);
    frameEdited1 = alphablend(frame, bannerW1, mask1_motion);
    
    bannerW2 = imwarp(banner, tform_motion2, 'OutputView', imref);
    mask2_motion = imwarp(alphachannel_banner, tform_motion2, 'OutputView', imref);
    frameEdited2 = alphablend(frameEdited1, bannerW2, mask2_motion);
    
    frameEdited = insertMarker(frameEdited2,matchedPts.Location,'+','Color','white');
    % out = insertMarker(frame,pts(validPts, :),'+');
    videoPlayer(frameEdited2);
    writeVideo(video_out, frameEdited);
    
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

% top_view = imwarp(frame, invert(tform_F2));
% 
% figure, imshow(top_view)
% imwrite(top_view,'tennis_topview.jpg')