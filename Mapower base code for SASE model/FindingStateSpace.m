function [States] = FindingStateSpace(CaseName, Iterations, InitialFailures, LoadGenerationRatio, LoadShedConstant, EstimationError)
%%Notes:
%MaxFailedCapacity value not used yet -- analytical model feature only

%%
define_constants;
%CaseName=CaseName;
FakeCapRate =1;
% Parameter initialization
TrueCaps=[20 80 200 500 800]; % quantized capacity
FakeCaps = TrueCaps;
NumIt = Iterations; % Number of iteration for extracting states..
% Initial load on which the capacity of lines will be determined
mpc1 = loadcase(CaseName);
mpc1=ReadyTheCase(mpc1);
% Seperate the buses with both load and generators into seperate load and generator buses
[mpc1 LoadGenMatch]=SeperateGenAndLoad(mpc1);
[WhichInitialLoad, Generation, Demand, DemandIndex]=FindFullLoadOfGrid(mpc1); % In the case of IEEE 118 topology 6.9 corresponds to using the full generation capacity of the grid
%WhichInitialLoad = 0.2537
clear mpc1; % clear because
mpc1 = loadcase(CaseName);
mpc1=ReadyTheCase(mpc1);
% keep the original values of number of buses and gens and branches before changing
originalNumBus=length(mpc1.bus(:,1));
originalNumGen=length(mpc1.gen(:,1));
originalNumBran=length(mpc1.branch(:,1));
NumBuses = length(mpc1.bus(:,1));
% check if any negative load
for i=1:NumBuses
    if (mpc1.bus(i,3)<0)
        mpc1.bus(i,3) = abs(mpc1.bus(i,3));
    end
end
% Seperate the buses with both load and generators into seperate load and generator buses
[mpc1 LoadGenMatch]=SeperateGenAndLoad(mpc1);
% Find installed capacity of a transmission line and use it as rateA threshold
Capacity=CapFinder(WhichInitialLoad,mpc1,TrueCaps,FakeCaps,originalNumBran);

mpc1.branch(:,6)=Capacity;
CountCaps=zeros(1,length(TrueCaps));
for i=1:length(TrueCaps)
    CountCaps(i)=sum(Capacity==TrueCaps(i));
end
tic
% Reset mpc1
OriginalMPC=mpc1;
NumBranches=231;
% Generate a initial failure table
for i=1:NumIt
    %{ % 2 or 3 failures
    
    b=1+ceil(2*rand);
    b=InitialFailures;
    randomindex=randperm(NumBranches);
    temp=randomindex(1:b);
    IniFidx=randomindex(1:b);
    IniFtable{1,i} = IniFidx;
    clear IniFidx
end
NoCoopPercentageVector = LoadShedConstant;
%DGRatioVector=[0.01 0.5 0.9 0.99];
DGRatioVector = LoadGenerationRatio;
DeltaVector = EstimationError;
% DeltaVector=[0.1 0.2 0.3 0.4 0.45 0.5];

tic
for idx=1:length(NoCoopPercentageVector)
    NoCoopPercentage=NoCoopPercentageVector(idx);
    for DGRatio=DGRatioVector
        clear mpc1;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        mpc1 = OriginalMPC;
        BranchMatrix=mpc1.branch;
        NumBranches=length(BranchMatrix(:,1));
        BusMatrix=mpc1.bus;
        NumBuses=length(BusMatrix(:,1));
        GenMatrix=mpc1.gen;
        NumGens=length(GenMatrix(:,1));
        
        Degrees = DegreeofLines(NumBranches,mpc1); % Find the degree of line
        HopDist = HopDistance(NumBranches,NumBuses,mpc1);% Finds the hop distance between all links
        
        %%%%% Calculating the total demand and generation capacity of the grid%%%%%
        %         =Demand/Generation;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        for alpha=DeltaVector
            clear States;
            StateCounter=0; %counts the number of possible states
            
            StatesCell = cellmat(NumIt, 1, 1000, 14);
            
            parfor s=1:NumIt % for every iteration under the same setting
                %s %print out s
                StatesCell(s, 1) = {DCPowerFlowSimulation(OriginalMPC, NumBranches, NoCoopPercentage, StateCounter, TrueCaps, DGRatio, WhichInitialLoad, Capacity, s, IniFtable, Demand, Degrees, HopDist, DemandIndex, alpha)};

            end
            %Temporary -- turn states cell array back to array
            States = cell2mat(StatesCell); %Turn cells to states matrix
            %         save(strcat('States2012-OPFloading',num2str(100*DGRatio),'.mat'),'States');
            %                save(strcat('States2016-OPFother',num2str(1000*DGRatio),'Alpha',num2str(alpha),...
            %                   'Beta',num2str(NoCoopPercentage), '.mat'), 'States');
            %     save(strcat('States2012-OPF07Beta',num2str(beta),'.mat'),'States');
        end
    end
end
toc
Blackoutsize=zeros(NumBranches,1);
for i=1:length(States(:,1))
    if(States(i,8)==-1)
        Blackoutsize(States(i,1))=Blackoutsize(States(i,1))+1;
    end
end
NumberOfLines = 186;
total_states = zeros(1, NumberOfLines);
stable_states = zeros(1, NumberOfLines);
% counting the occurances of the states
for i = 1:length(States)
    if States(i,1) > 0
        total_states(States(i,1)) = total_states(States(i,1)) + 1;
    end
    if States(i,8) == -1 % check if is the last state or not
        stable_states(States(i,1)) = stable_states(States(i,1)) + 1;
    end
end
% finding the p_stop
cascade_stop = zeros(1, NumberOfLines);
for i = 1:NumberOfLines
    if total_states(i) ~= 0
        cascade_stop(i) = stable_states(i)/total_states(i);
    end
end
stem(3:NumberOfLines,cascade_stop(3:NumberOfLines))
xlabel('Number of failed lines')
ylabel('Probability of cascade-stop')
end
