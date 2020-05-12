function States = DCPowerFlowSimulation(OriginalMPC, NumBranches, NoCoopPercentage, StateCounter, TrueCaps, DGRatio, WhichInitialLoad, Capacity, s, IniFtable, Demand, Degrees, HopDist, DemandIndex, alpha, States)
ListOfFailures=zeros(1,NumBranches); % List of failures in one scenario of cascade

%%%%%%%%%%%%% convert the loads in the power grid to dispatchable loads
mpc1 = OriginalMPC;

for i=1:length(mpc1.bus(:,1))
    if(mpc1.bus(i,2)==1)
        mpc1.bus(i,3)=mpc1.bus(i,3)*DGRatio*WhichInitialLoad;
    end
end
%%%%%%%%%%%%%%%%%%%% Power Grid Status after failure %%%%%%%%%%%%%%%%%%%%%
BranchMatrix=mpc1.branch;
BusMatrix=mpc1.bus;
GenMatrix=mpc1.gen;
NumBranches=length(BranchMatrix(:,1));
NumBuses=length(BusMatrix(:,1));
NumGens=length(GenMatrix(:,1));


LSCooPercent=ones(length(mpc1.bus(:,1)),1);
for i=1:length(mpc1.bus(:,1))
    LSCooPercent(i)=LSCooPercent(i)*(1-NoCoopPercentage);
end
%%% A filter to make sure gens' values in the vector are 0
for i=1:length(mpc1.bus(:,1))
    if(mpc1.bus(i,2)==2 || mpc1.bus(i,2)==3)
        LSCooPercent(i)=0;
    end
end

mpc1=MakePartialLSContGrid(mpc1,LSCooPercent);
mpc1.branch(:,6)=2*Capacity;
TotalPowerLine=zeros(1,NumBranches);
TotalGenDem=zeros(1,NumBuses);

AdjMatrix=zeros(NumBuses,NumBuses);
for j=1:NumBranches
    AdjMatrix(mpc1.branch(j,1),mpc1.branch(j,2))=1;
    AdjMatrix(mpc1.branch(j,2),mpc1.branch(j,1))=1;
end

%%%%%%%%%%%%%%%%%% Initial failure, Add failures %%%%%%%%%%%%%%%%%%%%%%%%%%%
IniFidx=IniFtable{1,s};

% Start with failure of k-th link
NewCapM=0;
for i=1:length(IniFidx)
    k=IniFidx(i);
    [AdjMatrix, mpc1]=cutMultiLines(AdjMatrix,mpc1,k);
    ListOfFailures(k)=1; % where ever there is 1 means failure
    if NewCapM<Capacity(k)
        NewCapM=Capacity(k);
    end
end

%Whenever a failure or load shed happens we save the
%state of the grid
StateCounter=StateCounter+1;
%Capacity(IniFidx)
capalogcell{StateCounter} = Capacity(IniFidx);
States(StateCounter,1)=sum(ListOfFailures); % This state has only one total failure in the topology
States(StateCounter,2)=NewCapM; % Total Capacity of failed ones
States(StateCounter,3)=-1; % Amount of load shed happend because of the failure in previous step (To Be assigned)
States(StateCounter,4)=-1; % Amount of load shed in comparing to previous step
States(StateCounter,5)=Demand; % Initial load(Demand) over the system
States(StateCounter,6)=Degrees(k); % degree of the failed link
States(StateCounter,7)=HopDist(k,k); % Average hop distance of failures
States(StateCounter,8)=0; % needs to be fillout based on the next failures that may happen to see
%  if this state is steady state or not
States(StateCounter,9)=Capacity(k); % min capacity of failed ones
States(StateCounter,10)=Capacity(k); % max capacity of failed ones
States(StateCounter,11)=k; % Index of the failed one
States(StateCounter,12)=Capacity(k); % Capacity of the failed one
States(StateCounter,13)=0; % Time of the failure event
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

moreFailures=1; % Is any failure happened in previous step?
while(moreFailures)
    moreFailures=0; % to see we will have more failures or not
    %%%%%%%%%%%%%%%% Find the connected components%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    SG = sparse(AdjMatrix);
    [SS, Components]  = graphconncomp(SG,'DIRECTED',false);
    numC=zeros(1,SS);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% Run the OPF for every island of the power grid due to failure%%%%%%%%%
    [G,P,VB]=islandedGrid(mpc1,Components,SS);
    TotalPowerLine=P;
    TotalGenDem=G;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%% Check the load shed amount %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    Served=0;
    for i=1:NumBuses
        if(DemandIndex(i)==1)
            Served=Served+abs(TotalGenDem(i));
        end
    end
    TotalShed=round(Demand-Served);
    States(StateCounter,3)=TotalShed;
    if(States(StateCounter,13)==0) % if this is the first failure
        States(StateCounter,4)=TotalShed;
    else
        States(StateCounter,4)=States(StateCounter,3)-States(StateCounter-1,3);
    end
    %%%%% Set the new generation values as the initial gen and demand of buses%
    for i=1:NumGens
        mpc1.gen(i,2)=TotalGenDem(i);
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%% Check for more failure %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    currentTime=States(StateCounter,13);
    [FailedIndex, FailedIndices, moreFailures, LinkProb]=...
        FindMultiFailedLinks(TotalPowerLine,2*Capacity,mpc1,ListOfFailures,alpha);
    if(moreFailures==1)
        StateCounter = StateCounter+1;
        capalogcell{StateCounter} = Capacity(FailedIndices);
        ListOfFailures(FailedIndices)=1;
        [AdjMatrix, mpc1] = cutMultiLines(AdjMatrix,mpc1,FailedIndices);
    end
    
    if(moreFailures==1) % If we have failure we need to save a new state
        A=find(ListOfFailures>0);
        Cap=0;
        Deg=0;
        Hop=0;
        for m=1:length(A)
            Cap=Cap+Capacity(A(m));
            Deg=Deg+Degrees(A(m))/length(A);
            for n=1:length(A)
                Hop=Hop+HopDist(m,n)/length(A);
            end
        end
        States(StateCounter,1)=sum(ListOfFailures); % This state has only one total failure in the topology
        States(StateCounter,2)=Cap; % Total Capacity of failed ones
        States(StateCounter,3)=-1; % Amount of load shed happend because of the failure in previous step (To Be assigned)
        States(StateCounter,4)=-1; % Amount of load shed in comparing to previous step
        States(StateCounter,5)=Demand; % Initial load(Demand) over the system
        States(StateCounter,6)=Deg; % degree of the failed link
        States(StateCounter,7)=Hop; % Average hop distance of failures
        States(StateCounter,8)=0; % needs to be fillout based on the next failures that may happen to see
        %  if this state is steady state or not
        States(StateCounter,11)=FailedIndex; % Index of the failed one
        States(StateCounter,12)=Capacity(FailedIndex); % Capacity of the failed one
        %States(StateCounter,13)=Ftime; % Time of the failure event
        %min and max
        MinCap=max(TrueCaps);
        MaxCap=0;
        for g=1:NumBranches
            if (ListOfFailures(g)==1)
                if(Capacity(g)<=MinCap)
                    MinCap=Capacity(g);
                end
                if(Capacity(g)>=MaxCap)
                    MaxCap=Capacity(g);
                end
            end
        end
        States(StateCounter,9)=MinCap; % min capacity of failed ones
        States(StateCounter,10)=MaxCap; % max capacity of failed ones
        States(StateCounter-1,8)=StateCounter;
    else
        States(StateCounter,8)=-1; % It means previous state was a steady state
    end
end
end