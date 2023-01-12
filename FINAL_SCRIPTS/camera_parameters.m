
clc
clear variables
close all

%% Estimate matrix M

p_c = [ 609  767   1
        895  226   1
       1487  235   1
       1764  821   1
        828  340   1
       1551  356   1];

P_W = [  0      0      0    1
         0    23.77    0    1
       10.97  23.77    0    1
       10.97    0      0    1
        0.46  11.89  1.065  1
       10.55  11.89  1.065  1];

for i = 1:6
    G(2*i-1:2*i,:) = [P_W(i,1) P_W(i,2) P_W(i,3) 1    0        0        0     0 -p_c(i,1)*P_W(i,1) -p_c(i,1)*P_W(i,2) -p_c(i,1)*P_W(i,3) -p_c(i,1)
                         0         0        0    0 P_W(i,1) P_W(i,2) P_W(i,3) 1 -p_c(i,2)*P_W(i,1) -p_c(i,2)*P_W(i,2) -p_c(i,2)*P_W(i,3) -p_c(i,2)];
end

%% Estimate parameters


[V,D] = eig(G'*G);
m = V(:,1);

m1 = [m(1); m(5); m(9)];
m2 = [m(2); m(6); m(10)];
m3 = [m(3); m(7); m(11)];
m4 = [m(4); m(8); m(12)];

M = [m1 m2 m3 m4];
A = [m1 m2 m3];

B = A*A';
B = B/B(3,3); % normalize

% Intrinsic parameters
px = B(1,3);
py = B(2,3);
dx = sqrt(B(1,1)-px^2);
dy = sqrt(B(2,2)-py^2);

K = [dx 0 px
     0 dy py
     0  0  1];

% Extrinsic parameters
R = K\A;
t = K\m4;



