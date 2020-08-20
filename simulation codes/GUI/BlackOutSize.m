function [Blackoutsize] = BlackOutSize(States, CaseName)

mpc1 = loadcase(CaseName);
mpc1 = S_ReadyTheCase(mpc1);
NumBranches = length(mpc1.branch(:,1));

Blackoutsize=zeros(NumBranches,1);

for i=1:length(States(:,1))

    if(States(i,8)==-1)

        Blackoutsize(States(i,1))=Blackoutsize(States(i,1))+1;

    end

end

bar(Blackoutsize/sum(Blackoutsize));
                
end