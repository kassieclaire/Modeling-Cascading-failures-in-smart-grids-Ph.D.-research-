function [Blackoutsize] = BlackOutSize(States)
Blackoutsize=zeros(231,1);
for i=1:length(States(:,1))
    if(States(i,8)==-1)
        Blackoutsize(States(i,1))=Blackoutsize(States(i,1))+1;
    end
end
bar(Blackoutsize);
loglog(1:231,Blackoutsize);
                
end