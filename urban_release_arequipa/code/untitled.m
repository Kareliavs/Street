      xv = rand(6,1); yv = rand(6,1);
       xv = [xv ; xv(1)]; yv = [yv ; yv(1)];
       x = rand(1000,1); y = rand(1000,1);
       in = inpolygon(x,y,xv,yv);
       plot(xv,yv,x(in),y(in),'.r',x(~in),y(~in),'.b')