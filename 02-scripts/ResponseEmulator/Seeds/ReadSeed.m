v = [0, 1:2:25, 26, 30, 35, 40, 45];
hs = [0 1:2:15];
tp = [1:1:4];

windspeed =    1;
waveheight =   0;
Tp =           1;

a= find(v==windspeed);
b= find(hs==waveheight);
c= find(tp==Tp);

num2str(Seeds(a,b,c,:))